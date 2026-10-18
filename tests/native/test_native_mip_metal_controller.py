#!/usr/bin/env python3
"""Mock the shared execution boundary; constructed observations are not GPU proof."""
import argparse
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import types
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
HERE = ROOT / 'tools/godot/native_texture_mips'


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


controller = load('vigil_metal_controller', HERE / 'metal.py')
fixture = load('controller_metal_fixture', Path(__file__).with_name('test_native_mip_metal.py'))
probe = load('controller_frozen_probe', HERE / 'probe.py')


def manifests():
    contract = json.loads((HERE / 'metal-contract.json').read_text())
    original = json.loads((HERE / 'contract.json').read_text())
    identity = {'observer_sha256': 'e' * 64, 'script_sha256': {
        name: hashlib.sha256(probe.script_for(name).encode()).hexdigest() for name in ('baseline', 'candidate')}}
    dependency = {'name': 'allocator.patch', 'sha256': original['prerequisite_patch_sha256']}
    production = {'name': 'mip.patch', 'sha256': original['production_patch_sha256']}
    build = {'status': 'pass', 'profile': contract['profile'], 'source_sha': original['source_pins'][0],
        'source_archive_sha256': 'e607e9985e1c201bc9cdc1aec8a120f0c3f53b9603f1f828e2b748534a2471ef',
        'observer_sha256': identity['observer_sha256'], 'patch_sha256': production['sha256'],
        'prerequisite_patches': [dependency], 'runtime_test_configuration': {
            'purpose': 'desktop_metal_component_proof', 'path_overrides': True,
            'scons_option': 'disable_path_overrides=no', 'shipping_template_qualification': False},
        'flags': ['mock Metal flags; no compiler'], 'source_head': 'f' * 40, 'builds': {}}
    for variant in ('baseline', 'candidate'):
        build['builds'][variant] = {'binary': '/never-executed/' + variant,
            'binary_sha256': 'd' * 64, 'unmodified_source_tree_sha256': 'a' * 64,
            'pre_observer_source_tree_sha256': 'b' * 64, 'instrumented_source_tree_sha256': 'c' * 64,
            'applied_patches': [dependency] + ([production] if variant == 'candidate' else []),
            'observer_receipt': {'variant': variant, 'profile': contract['profile'],
                'observer_sha256': identity['observer_sha256'],
                'original_observer_sha256': contract['protected_files']['tools/godot/native_texture_mips/observer.py'],
                'source_before_sha256': original['allocator_baseline_rd_sha256' if variant == 'baseline' else 'candidate_rd_sha256'],
                'source_after_sha256': contract['instrumented_rd_sha256'][variant], 'metal_sources': contract['metal_sources']}}
    return contract, original, identity, build


class ControllerTests(unittest.TestCase):
    def test_foreign_prerequisite_source_or_observer_receipts_fail(self):
        contract, original, identity, build = manifests()
        controller.validate_build(build, contract, original, identity)
        for field in ('patch', 'prerequisite', 'source', 'observer'):
            changed = copy.deepcopy(build)
            if field == 'patch': changed['builds']['candidate']['applied_patches'][-1]['sha256'] = '0' * 64
            elif field == 'prerequisite': changed['prerequisite_patches'] = []
            elif field == 'source': changed['source_archive_sha256'] = '0' * 64
            else: changed['builds']['candidate']['observer_receipt']['source_after_sha256'] = '0' * 64
            with self.subTest(field=field), self.assertRaises(ValueError):
                controller.validate_build(changed, contract, original, identity)

    def exercise(self, directory, defect=None):
        contract, original, identity, build = manifests()
        args = argparse.Namespace(head='f' * 40, venue_receipt=directory / 'venue.json',
            prerequisite_patch=directory / 'allocator.patch', source_archive=directory / 'source.tar.gz',
            work=directory / 'build', output=directory / 'output')
        calls = []

        def write(path, data):
            path.write_text(json.dumps(data) + '\n')

        def compile_pair(options, shared):
            self.assertEqual(options.baseline_patches, [args.prerequisite_patch])
            self.assertEqual(options.observer, HERE / 'metal_observer.py')
            args.output.mkdir()
            write(args.output / 'build-manifest.json', build)

        def run_probe(binary, output, receipt, head, script):
            variant = binary.name; calls.append(variant); output.mkdir()
            self.assertEqual(script, probe.script_for(variant))
            text = '\n'.join(fixture.synthetic(variant))
            if defect == 'error' and variant == 'baseline': text += '\nERROR: injected native failure\n'
            (output / 'native.log').write_text(text)
            command = {'script_sha256': identity['script_sha256'][variant], 'commands': [
                {'log': 'native.log', 'log_sha256': hashlib.sha256(text.encode()).hexdigest()}]}
            if defect == 'log-hash': command['commands'][0]['log_sha256'] = '0' * 64
            write(output / 'command.json', command)
            return command

        def provenance(manifest, commands, receipt, head, expected_scripts):
            self.assertEqual(expected_scripts, identity['script_sha256'])
            self.assertNotEqual(expected_scripts['baseline'], expected_scripts['candidate'])
            return {'scope': 'mocked provenance; no native execution'}

        support = types.SimpleNamespace(ARCHIVE=build['source_archive_sha256'], FLAGS=build['flags'],
            verify_venue=mock.Mock(), read_json=lambda path: json.loads(path.read_text()),
            run_probe=run_probe, verify_provenance=provenance)
        shared = types.SimpleNamespace(write_json=write)
        real_digest = controller.digest

        def digest(path):
            return original['prerequisite_patch_sha256'] if path == args.prerequisite_patch else real_digest(path)

        with mock.patch.object(controller, 'inputs', return_value=(contract, original, probe, identity)), \
                mock.patch.object(controller, 'load_shared', return_value=(types.SimpleNamespace(build=compile_pair), support, shared)), \
                mock.patch.object(controller, 'digest', side_effect=digest):
            if defect:
                with self.assertRaises(ValueError): controller.run(args)
                self.assertFalse((args.output / 'actual-rd-proof.json').exists())
                self.assertEqual(json.loads((args.output / 'component-run.json').read_text())['status'], 'failed_or_inconclusive')
                self.assertEqual(calls, ['baseline'])
            else:
                self.assertEqual(controller.run(args), 0)
                self.assertEqual(calls, ['baseline', 'candidate'])
                report = json.loads((args.output / 'actual-rd-proof.json').read_text())
                self.assertEqual(report['explicit_barrier_events'], 0)
                self.assertEqual(report['provenance']['scope'], 'mocked provenance; no native execution')

    def test_thin_shared_pair_preserves_distinct_frozen_scripts(self):
        with tempfile.TemporaryDirectory() as temp: self.exercise(Path(temp))

    def test_unexpected_error_or_corrupt_process_log_stops_before_candidate(self):
        for defect in ('error', 'log-hash'):
            with self.subTest(defect=defect), tempfile.TemporaryDirectory() as temp:
                self.exercise(Path(temp), defect)


if __name__ == '__main__':
    unittest.main()
