#!/usr/bin/env python3
"""Cheap binding/serialisation controls; no native process or GPU result."""
import copy
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
spec = importlib.util.spec_from_file_location('first_metal_fixture', Path(__file__).with_name('test_native_mip_metal.py'))
fixture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fixture)


class MetalDeliveryTests(unittest.TestCase):
    def test_complete_comparison_is_json_serialisable_and_scope_is_explicit(self):
        before = fixture.inspect('\n'.join(fixture.synthetic('baseline')), 'baseline')
        after = fixture.inspect('\n'.join(fixture.synthetic('candidate')), 'candidate')
        result = json.loads(json.dumps(fixture.verify.compare_metal(before, after)))
        self.assertEqual(result['profile'], 'macos-arm64-metal-v1')
        self.assertEqual(result['explicit_barrier_events'], 0)
        self.assertIn('desktop Metal RD component only', result['scope'])
        self.assertIn('remain separate', result['row_pitch_coverage'])
        changed = copy.deepcopy(after)
        changed['native_traits']['vigil-astc:0']['native_transfer_align'] = 128
        with self.assertRaisesRegex(ValueError, 'traits changed'):
            fixture.verify.compare_metal(before, changed)

    def test_rejection_error_is_required_once_and_baseline_cannot_emit_it(self):
        lines = fixture.synthetic('candidate')
        index = next(i for i, line in enumerate(lines) if line.startswith('ERROR:'))
        for changed in (lines[:index] + lines[index + 1:], lines + [lines[index]]):
            with self.assertRaisesRegex(ValueError, 'native Metal error'):
                fixture.inspect('\n'.join(changed), 'candidate')
        with self.assertRaisesRegex(ValueError, 'native Metal error'):
            fixture.inspect('\n'.join(fixture.synthetic('baseline') + [lines[index]]), 'baseline')

    def test_native_astc_block_bytes_cannot_be_forged(self):
        lines = fixture.synthetic('candidate')
        index = next(i for i, line in enumerate(lines)
                     if line.startswith('GV_MIP_START case=vigil-astc ') and 'block_bytes=16' in line)
        lines[index] = lines[index].replace('block_bytes=16', 'block_bytes=32')
        with self.assertRaises(ValueError):
            fixture.inspect('\n'.join(lines), 'candidate')

    def test_contract_preserves_original_bytes_and_both_first_lock_histories(self):
        contract = json.loads((HERE / 'metal-contract.json').read_text())
        self.assertEqual(contract['first_metal_fixture_commit'], 'e413def4e0987b53ac1a608606b5af7354500a16')
        self.assertEqual(hashlib.sha256(Path(fixture.__file__).read_bytes()).hexdigest(),
                         contract['first_metal_fixture_sha256'])
        for path, expected in contract['protected_files'].items():
            with self.subTest(path=path):
                self.assertEqual(hashlib.sha256((ROOT / path).read_bytes()).hexdigest(), expected)
        self.assertEqual(contract['metal_sources'], fixture.adapter.METAL_SOURCES)
        self.assertFalse(contract['backend_contract']['synthetic_row_pitch_override'])
        self.assertEqual(contract['backend_contract']['synthetic_offset_alignment'], 512)
        self.assertEqual(contract['physical_formats'], [
            {'format': 'ASTC_4x4_UNORM', 'format_id': 156, 'usage': 193},
            {'format': 'RGBA8', 'format_id': 36, 'usage': 193}])

    def test_observer_refuses_repeated_or_ambiguous_instrumentation(self):
        for variant in ('baseline', 'candidate'):
            source = fixture.source_anchors(variant)
            instrumented = fixture.adapter.instrument(source, variant)
            with self.assertRaisesRegex(ValueError, 'already present'):
                fixture.adapter.instrument(instrumented, variant)
            anchor = ('const ' if variant == 'candidate' else '') + 'uint32_t required_align = _texture_alignment(texture);'
            with self.assertRaisesRegex(ValueError, 'ambiguous'):
                fixture.adapter.instrument(source.replace(anchor, anchor + '\n' + anchor), variant)

    def test_observer_cli_fails_closed_before_unknown_native_source_write(self):
        with tempfile.TemporaryDirectory() as temp:
            tree = Path(temp)
            target = tree / 'servers/rendering/rendering_device.cpp'
            target.parent.mkdir(parents=True)
            target.write_bytes(b'unknown native source; never compiled')
            argv = ['metal_observer.py', '--source-dir', str(tree)]
            with mock.patch.object(sys, 'argv', argv), \
                    mock.patch.object(fixture.adapter, 'METAL_SOURCES', {}):
                with self.assertRaisesRegex(ValueError, 'exact allocator-only'):
                    fixture.adapter.main()
            self.assertEqual(target.read_bytes(), b'unknown native source; never compiled')
            with mock.patch.object(sys, 'argv', argv), \
                    mock.patch.object(fixture.adapter, 'ORIGINAL_OBSERVER_SHA256', '0' * 64):
                with self.assertRaisesRegex(ValueError, 'original mip observer differs'):
                    fixture.adapter.main()


if __name__ == '__main__':
    unittest.main()
