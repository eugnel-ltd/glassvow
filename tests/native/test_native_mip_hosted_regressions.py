#!/usr/bin/env python3
"""Replay archived native data and inspect fixture setup without an engine.

Event-only replay isolates request arithmetic. It never qualifies the original
failed attempt: its complete logs retain ERROR and the strict CLI rejects them.
"""
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
HERE = ROOT / 'tools/godot/native_texture_mips'
FIXTURES = Path(__file__).with_name('fixtures') / 'mip-hosted-117746266505'


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


verify = load('hosted_mip_verify', HERE / 'verify.py')
probe = load('hosted_mip_probe', HERE / 'probe.py')
runtime = load('hosted_runtime_fixture', Path(__file__).with_name('test_native_mip_runtime_config.py'))


def captured(variant):
    return (FIXTURES / (variant + '.log')).read_text()


def event_lines(variant):
    return [line for line in captured(variant).splitlines() if line.startswith('GV_MIP_')]


class BeforeEngine(Exception):
    pass


class HostedRegressions(unittest.TestCase):
    def test_archived_logs_are_bound_and_keep_the_actual_error(self):
        provenance = json.loads((FIXTURES / 'provenance.json').read_text())
        for name, digest in provenance['files'].items():
            self.assertEqual(hashlib.sha256((FIXTURES / name).read_bytes()).hexdigest(), digest)
            self.assertIn('ERROR: Could not load global script cache.', (FIXTURES / name).read_text())

    def test_standalone_project_has_valid_empty_global_class_cache_before_launch(self):
        self.assertNotIn('class_name ', probe.SCRIPT)
        for variant in ('baseline', 'candidate'):
            with self.subTest(variant=variant), tempfile.TemporaryDirectory() as temp:
                directory = Path(temp)
                binary = directory / 'binary'
                binary.write_bytes(b'fixture placeholder; never executed')
                icd = directory / 'lavapipe.json'
                icd.write_text(json.dumps({'ICD': {'library_path': 'libvulkan_lvp.so'}}))
                output = directory / 'output'
                with mock.patch.dict(probe.os.environ, {'VK_DRIVER_FILES': str(icd)}), \
                        mock.patch.object(probe.subprocess, 'Popen', side_effect=BeforeEngine):
                    with self.assertRaises(BeforeEngine):
                        probe.run(binary, output, variant)
                cache = output / 'project/.godot/global_script_class_cache.cfg'
                self.assertTrue(cache.is_file(), 'standalone template lacks its required global-class cache')
                self.assertEqual(cache.read_text(), 'list=[]\n')
                inputs = json.loads((output / 'probe-input.json').read_text())
                self.assertEqual(inputs['global_class_cache_sha256'], hashlib.sha256(cache.read_bytes()).hexdigest())

    def test_saved_backend_alignment_preserves_exact_supported_control_coverage(self):
        before = verify.inspect('\n'.join(event_lines('baseline')), 'baseline')
        after = verify.inspect('\n'.join(event_lines('candidate')), 'candidate')
        report = verify.compare(before, after)
        self.assertEqual(report['status'], 'INCONCLUSIVE_ASTC_UNSUPPORTED')
        self.assertEqual(set(after['cases']), {'rgba8-mip-surrogate:0', 'rgba8-depth-padded:0'})
        old = before['cases']['rgba8-mip-surrogate:0']
        new = after['cases']['rgba8-mip-surrogate:0']
        self.assertEqual([r['bytes'] for r in old['requests']], [5592580])
        self.assertEqual([r['bytes'] for r in new['requests']], [4194304, 1398276])
        self.assertEqual(new['alignment'], 128)
        depth = after['cases']['rgba8-depth-padded:0']
        self.assertEqual([r['bytes'] for r in depth['requests']], [17664])
        self.assertEqual(depth['alignment'], 512)

    def test_corrupt_recorded_profile_request_copy_and_readback_fail(self):
        for marker, old, new in (
                ('START', 'align=128', 'align=256'),
                ('REQUEST', 'bytes=1398276', 'bytes=1398100'),
                ('COPY', 'source=5242880', 'source=5242881'),
                ('COPY', 'offset=1048576', 'offset=1048577')):
            with self.subTest(marker=marker, old=old):
                lines = event_lines('candidate')
                index = next(i for i, line in enumerate(lines) if line.startswith('GV_MIP_' + marker + ' ') and old in line)
                lines[index] = lines[index].replace(old, new, 1)
                with self.assertRaises(ValueError):
                    verify.inspect('\n'.join(lines), 'candidate')
        lines = event_lines('candidate')
        index = next(i for i, line in enumerate(lines) if line.startswith('GV_MIP_READBACK '))
        item = json.loads(lines[index].split(' ', 1)[1])
        item['actual_sha256'] = '0' * 64
        lines[index] = 'GV_MIP_READBACK ' + json.dumps(item)
        with self.assertRaisesRegex(ValueError, 'actual GPU bytes differ'):
            verify.inspect('\n'.join(lines), 'candidate')

    def test_aligned_absolute_offset_cannot_change_within_one_batch(self):
        lines = event_lines('candidate')
        index = next(i for i, line in enumerate(lines) if line.startswith('GV_MIP_COPY ') and 'offset=1048576 ' in line)
        lines[index] = lines[index].replace('offset=1048576 ', 'offset=1048704 ', 1)
        with self.assertRaisesRegex(ValueError, 'worker offset'):
            verify.inspect('\n'.join(lines), 'candidate')

    def test_strict_cli_rejects_captured_and_added_native_errors(self):
        for text in (captured('baseline'), 'Vulkan llvmpipe\nERROR: injected native failure\n' + '\n'.join(event_lines('baseline'))):
            with self.subTest(error=text.splitlines()[0]), tempfile.TemporaryDirectory() as temp:
                directory = Path(temp)
                manifest, contract = runtime.manifest()
                manifest['observer_sha256'] = hashlib.sha256((HERE / 'observer.py').read_bytes()).hexdigest()
                (directory / 'build.json').write_text(json.dumps(manifest))
                for variant in ('baseline', 'candidate'):
                    target = directory / variant
                    target.mkdir()
                    (target / 'native.log').write_text(text if variant == 'baseline' else captured(variant))
                    (target / 'probe-input.json').write_text(json.dumps({
                        'variant': variant, 'binary_sha256': manifest['builds'][variant]['binary_sha256'],
                        'script_sha256': hashlib.sha256(probe.script_for(variant).encode()).hexdigest(),
                        'icd_sha256': 'f' * 64,
                        'global_class_cache_sha256': hashlib.sha256(b'list=[]\n').hexdigest()}))
                    (directory / (variant + '-instrument.log')).write_text(json.dumps({
                        'variant': variant, 'observer_sha256': manifest['observer_sha256'],
                        'source_before_sha256': contract['allocator_baseline_rd_sha256' if variant == 'baseline' else 'candidate_rd_sha256'],
                        'source_after_sha256': 'a' * 64}))
                output = directory / 'result.json'
                argv = ['verify.py', '--baseline', str(directory / 'baseline'), '--candidate',
                        str(directory / 'candidate'), '--build-manifest', str(directory / 'build.json'),
                        '--output', str(output)]
                with mock.patch.object(sys, 'argv', argv), mock.patch.dict(sys.modules, {'probe': probe}):
                    with self.assertRaisesRegex(ValueError, 'unexpected native error'):
                        verify.main()
                self.assertFalse(output.exists(), 'native ERROR must not produce a qualified report')


if __name__ == '__main__':
    unittest.main()
