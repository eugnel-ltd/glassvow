#!/usr/bin/env python3
"""Metal venue/dispatch/coverage controls with synthetic data; no GPU or build."""
import copy
import hashlib
import importlib.util
import inspect
import json
import os
from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest
from unittest.mock import patch

from metal_staging_fixtures import graph

ROOT = Path(__file__).resolve().parents[2]
DIRECTORY = ROOT / 'tools/godot/native_texture_staging'
MAC = 'macos-arm64-metal-v1'
HEAD = '1' * 40
HOST = {'system': 'Darwin', 'machine': 'arm64', 'boot_sha256': 'a' * 64,
        'job': {'GITHUB_RUN_ID': '123', 'GITHUB_RUN_ATTEMPT': '1', 'GITHUB_JOB': 'metal',
                'RUNNER_NAME': 'synthetic', 'ImageOS': 'macos15', 'ImageVersion': 'synthetic'}}


def load(name):
    path = DIRECTORY / (name + '.py')
    if not path.exists():
        return None
    spec = importlib.util.spec_from_file_location('gv_metal_contract_' + name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


CONTROLLER, VERIFIER = load('run_component'), load('verify')


def venue():
    return {'schema': 1, 'profile': MAC, 'head': HEAD, 'status': 'CAPABILITY_SUPPORTED',
        'component_status': 'NOT_RUN', 'errors': [], 'version': '4.7.2.stable.official.ed1daf0bf',
        'query_source_sha256': 'beecc87040c9fa5e5ae139a485730acf71392bcca69c39c3d31f6b1b4e3d44fb',
        'mac_host_binding': copy.deepcopy(HOST),
        'host': {'system': 'Darwin', 'uname_machine': 'arm64', 'python_machine': 'arm64', 'translated': False},
        'backend_startup': 'Metal 3.2 - Forward Mobile - Using Device #0: Apple - Apple Synthetic Test GPU',
        'device': {'schema': 1, 'os': 'macOS', 'display': 'macos', 'arm64': True, 'x86_64': False,
                   'vendor': 'Apple', 'name': 'Apple Synthetic Test GPU'},
        'formats': [dict(format=name, format_id=value, usage=193, supported=True)
            for name, value in [('ETC2_RGB8', 146), ('ETC2_RGBA8', 150), ('EAC_RG11', 154),
                                ('ASTC_4x4_UNORM', 156), ('RGBA8', 36), ('RG8_LA8', 15)]]}


class ExpensiveBoundary(BaseException):
    pass


class MetalProfileTests(unittest.TestCase):
    def test_actual_controller_rejects_unqualified_metal_before_source_download(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            builder = root / 'builder/build.py'
            builder.parent.mkdir()
            manifest = root / 'helpers.json'
            hashes = {}
            for name in ['build.py', 'verify.py', 'processes.py']:
                path = builder.with_name(name)
                path.write_bytes(b'synthetic-unexecuted-helper')
                hashes[name] = hashlib.sha256(path.read_bytes()).hexdigest()
            manifest.write_text(json.dumps(hashes))
            receipt = root / 'venue.json'
            receipt.write_text(json.dumps(dict(venue(), status='INCONCLUSIVE')))
            args = SimpleNamespace(builder=builder, builder_manifest=manifest,
                source_archive=None, work=root / 'work', output=root / 'output',
                profile=MAC, head=HEAD, venue_receipt=receipt)
            fake = SimpleNamespace(SOURCE_SHA=CONTROLLER.SOURCE,
                SOURCE_ARCHIVE_SHA256=CONTROLLER.ARCHIVE_SHA,
                FLAGS=['disable_path_overrides=no'], download=lambda _p: (_ for _ in ()).throw(ExpensiveBoundary()))
            with patch.object(CONTROLLER, 'load', return_value=fake):
                try:
                    CONTROLLER.run(args)
                except (ValueError, AssertionError):
                    pass
                except ExpensiveBoundary:
                    self.fail('actual controller reached a source download before qualified same-host Metal evidence')
                else:
                    self.fail('unqualified Metal receipt was silently accepted')

    def test_same_host_profile_refuses_replayed_or_mismatched_stock_evidence(self):
        metal = load('metal')
        self.assertIsNotNone(metal, 'maintained Mac profile/receipt binding is missing')
        with tempfile.TemporaryDirectory() as temporary:
            receipt = Path(temporary) / 'venue.json'
            good = venue()
            receipt.write_text(json.dumps(good))
            with patch.object(metal.capability, 'mac_host_binding', return_value=HOST):
                self.assertEqual(metal.verify_venue(receipt, HEAD)['device']['name'], good['device']['name'])
                for key, value in [('head', '2' * 40), ('profile', 'linux-x86_64-lavapipe-v1'),
                    ('status', 'INCONCLUSIVE'), ('version', 'custom_build'),
                    ('mac_host_binding', dict(HOST, boot_sha256='b' * 64)),
                    ('backend_startup', good['backend_startup'].replace('Metal', 'Vulkan')),
                    ('formats', [dict(good['formats'][0], usage=1)] + good['formats'][1:])]:
                    receipt.write_text(json.dumps(dict(good, **{key: value})))
                    with self.assertRaises(ValueError):
                        metal.verify_venue(receipt, HEAD)

    def test_mac_builder_retains_exact_flags_and_refuses_ambiguous_binary(self):
        builder = load('mac_builder')
        self.assertIsNotNone(builder, 'additive Mac builder is missing before paired execution')
        for flag in ['platform=macos', 'arch=arm64', 'target=template_debug', 'metal=yes',
            'vulkan=no', 'opengl3=no', 'accesskit=no', 'generate_bundle=no', 'tests=yes',
            'disable_path_overrides=no', 'disable_3d=yes', 'modules_enabled_by_default=no',
            'module_gdscript_enabled=yes', 'module_glslang_enabled=yes',
            'module_text_server_fb_enabled=yes', 'optimize=speed', 'debug_symbols=no', '-j2']:
            self.assertIn(flag, builder.FLAGS)
        self.assertFalse(any(flag.startswith(('x11=', 'wayland=')) for flag in builder.FLAGS))
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'bin').mkdir()
            path = root / 'bin/godot.macos.template_debug.arm64'
            path.write_bytes(b'synthetic-file-never-executed')
            path.chmod(0o700)
            self.assertEqual(builder.select_binary(root), path)
            extra = path.with_name(path.name + '.second')
            extra.write_bytes(path.read_bytes())
            extra.chmod(0o700)
            with self.assertRaises(ValueError):
                builder.select_binary(root)

    def test_metal_graph_keeps_all_layers_bytes_and_valid_offset_stress(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for variant in ['baseline', 'candidate']:
                path = root / (variant + '.log')
                path.write_text(graph(variant))
                kwargs = {'profile': MAC} if 'profile' in inspect.signature(VERIFIER.inspect).parameters else {}
                result = VERIFIER.inspect(path, variant, **kwargs)
                self.assertEqual(len(result['cases']), 11)
                self.assertEqual(result['coverage']['forced_256_gpu_row_padding'], 'NOT_RUN')
                self.assertEqual(result['coverage']['forced_512_offset_alignment'], 'PASS')
                broken = graph(variant).replace('forced_row_padding=0', 'forced_row_padding=1', 1)
                path.write_text(broken)
                with self.assertRaises(AssertionError):
                    VERIFIER.inspect(path, variant, **kwargs)
                path.write_text(graph(variant).replace('"equal": true', '"equal": false', 1))
                with self.assertRaises(AssertionError):
                    VERIFIER.inspect(path, variant, **kwargs)

    def test_structured_diagnostics_print_only_owned_allowlisted_capability_and_queries(self):
        diagnostics = load('diagnostics')
        emit = getattr(diagnostics, 'emit_summary', None)
        self.assertTrue(callable(emit), 'bounded actual device/format summary transport is missing')
        import io
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'venue').mkdir()
            sentinel = ''.join(chr(code) for code in range(65, 84))
            result = dict(venue(), secret=sentinel)
            (root / 'venue/result.json').write_text(json.dumps(result))
            folder = root / 'component/rd-baseline'
            folder.mkdir(parents=True)
            (folder / 'native.log').write_text(graph('baseline') +
                'authorization=' + sentinel + ' https://signed.invalid/private\n')
            stream = io.StringIO()
            emit(root, stream)
            text = stream.getvalue()
            self.assertIn('Apple Synthetic Test GPU', text)
            self.assertIn('ETC2_RGB8', text)
            self.assertIn('usage', text)
            self.assertNotIn(sentinel, text)
            self.assertNotIn('signed.invalid', text)
            self.assertLessEqual(len(text.encode()), 16384)


if __name__ == '__main__':
    unittest.main(verbosity=2)
