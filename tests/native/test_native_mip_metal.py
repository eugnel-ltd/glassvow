#!/usr/bin/env python3
"""Synthetic Metal contract controls; no native execution or GPU PASS is claimed.

The first lock deliberately falls back to the existing observer/verifier on e628:
it exposes their real forced-pitch and barrier assumptions before an additive
Metal entry point exists, rather than failing solely on a missing import.
"""
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
HERE = ROOT / 'tools/godot/native_texture_mips'


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


verify = load('metal_mip_verify', HERE / 'verify.py')
observer = load('metal_original_observer', HERE / 'observer.py')
sys.modules['observer'] = observer
adapter_path = HERE / 'metal_observer.py'
adapter = load('metal_observer_adapter', adapter_path) if adapter_path.is_file() else observer


def inspect(text, variant):
    return getattr(verify, 'inspect_metal', verify.inspect)(text, variant)


def event(marker, item):
    return marker + ' ' + ' '.join(f'{key}={value}' for key, value in item.items())


def source_anchors(variant):
    """Exact instrumentation anchors only; this is not a compilable native fixture."""
    const = 'const ' if variant == 'candidate' else ''
    acquire = ('\t\tTransferWorker *transfer_worker = _acquire_transfer_worker(upload.bytes, required_align, staging_worker_offset);'
               if variant == 'candidate' else
               '\t\t\ttransfer_worker = _acquire_transfer_worker(staging_local_offset, required_align, staging_worker_offset);')
    return '\n'.join([
        'Error RenderingDevice::_texture_initialize(',
        const + 'uint32_t required_align = _texture_alignment(texture);',
        const + 'uint32_t pitch_step = driver->api_trait_get(RDD::API_TRAIT_TEXTURE_DATA_ROW_PITCH_STEP);',
        const + 'uint32_t block_size = get_compressed_image_format_block_byte_size(texture->format);',
        acquire,
        'driver->command_copy_buffer_to_texture(transfer_worker->command_buffer, transfer_worker->staging_buffer, texture->driver_id, p_dst_layout, copy_region);',
        'driver->command_pipeline_barrier(transfer_worker->command_buffer, RDD::PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT, RDD::PIPELINE_STAGE_COPY_BIT, {}, {}, tb, {});',
        'transfer_worker->texture_barriers.push_back(tb);',
        '_wait_for_transfer_worker(transfer_worker);',
        'Error RenderingDevice::texture_update('])


def synthetic(variant):
    """Construct complete natural-row Metal observations, never captured GPU data."""
    lines = []; count = 0
    for name, (w, h, d, mips, layers) in verify.CASES.items():
        rgba, padded = name.startswith('rgba8'), name.endswith('-padded')
        format_id = 36 if rgba else 156
        lines.append('GV_MIP_CAPABILITY ' + json.dumps({'case': name,
            'format': 'RGBA8' if rgba else 'ASTC_4x4', 'format_id': format_id,
            'supported': True, 'usage': 193, 'width': w, 'height': h,
            'depth': d, 'mips': mips,
            'validated_upload_format': 'RGBA8' if rgba else 'ASTC_4x4'}))
        for layer in range(layers):
            start = {'case': name, 'layer': layer, 'format': format_id,
                'width': w, 'height': h, 'depth': d, 'mips': mips,
                'pitch_step': 1, 'align': 512 if padded else (4 if rgba else 16),
                'block_w': 1 if rgba else 4, 'block_h': 1 if rgba else 4,
                'block_bytes': 1 if rgba else 16, 'pixel_size': 4 if rgba else 1,
                'rshift': 0, 'forced': int(padded)}
            payload = verify.layout(start, 'baseline')[0]; start['payload'] = payload
            if name == 'atomic-reject' and variant == 'candidate':
                lines.append('ERROR: One padded texture mip exceeds the bounded staging request.')
                lines.append('GV_MIP_REJECT ' + json.dumps({'case': name, 'valid': False, 'bytes': payload}))
                continue
            lines.append(event('GV_MIP_METAL_TRAITS', {'case': name, 'layer': layer,
                'native_pitch_step': 1, 'native_transfer_align': 1, 'honors_barriers': 0}))
            lines.append(event('GV_MIP_START', start))
            _, requests, copies = verify.layout(start, variant)
            lines.extend(event('GV_MIP_REQUEST', {'case': name, 'layer': layer, **item}) for item in requests)
            lines.extend(event('GV_MIP_COPY', {'case': name, 'layer': layer, **item,
                'offset': item['local'] + 2 * start['align']}) for item in copies)
            lines.extend(event('GV_MIP_WAIT', {'case': name, 'layer': layer, 'batch': batch})
                         for batch in range(len(requests) - 1))
            pattern = bytes((i * 37 + layer * 17) % 251 for i in range(251))
            digest = hashlib.sha256((pattern * ((payload + 250) // 251))[:payload]).hexdigest()
            lines.append('GV_MIP_READBACK ' + json.dumps({'case': name, 'layer': layer,
                'format': 'RGBA8' if rgba else 'ASTC_4x4', 'format_id': format_id,
                'created_format': format_id, 'created_mipmaps': mips,
                'width': w, 'height': h, 'depth': d, 'mips': mips,
                'source_bytes': payload, 'actual_bytes': payload,
                'source_sha256': digest, 'actual_sha256': digest, 'equal': True}))
            count += 1
    return lines + ['GV_MIP_DONE ' + str(count)]


class MetalContractTests(unittest.TestCase):
    def rejects(self, lines, message=None):
        with self.assertRaisesRegex(ValueError, message or '.'):
            inspect('\n'.join(lines), 'candidate')

    def test_observer_uses_native_rows_and_retains_offset_stress(self):
        for variant in ('baseline', 'candidate'):
            with self.subTest(variant=variant):
                result = adapter.instrument(source_anchors(variant), variant)
                self.assertNotIn('pitch_step = MAX(pitch_step, 256u)', result)
                self.assertNotIn('gv_padded ? MAX(uint32_t(driver->api_trait_get', result)
                self.assertIn('required_align = MAX(required_align, 512u)', result)
                self.assertIn('GV_MIP_METAL_TRAITS', result)
                self.assertIn('API_TRAIT_HONORS_PIPELINE_BARRIERS', result)
                for marker in ('START', 'REQUEST', 'COPY', 'BARRIER', 'WAIT'):
                    self.assertIn('GV_MIP_' + marker, result)

    def test_valid_tight_row_metal_keeps_all_cases_and_exact_zero_barriers(self):
        try:
            before = inspect('\n'.join(synthetic('baseline')), 'baseline')
            after = inspect('\n'.join(synthetic('candidate')), 'candidate')
        except ValueError as error:
            self.fail('Natural Metal rows with exact zero explicit barriers were rejected: ' + str(error))
        self.assertEqual(len(before['cases']), 9)
        self.assertEqual(len(after['cases']), 8)
        for key, requests in (
                ('vigil-astc:0', [4194304, 1398128]),
                ('vigil-astc-padded:0', [4194304, 1399824]),
                ('astc4-odd-padded:0', [4112]),
                ('rgba8-depth-padded:0', [7684]),
                ('single-exact-cap:0', [4194304])):
            self.assertEqual([r['bytes'] for r in after['cases'][key]['requests']], requests)
        self.assertFalse(any(line.startswith('GV_MIP_BARRIER ') for line in synthetic('candidate')))

    def test_missing_duplicate_or_forged_native_traits_fail(self):
        for mode in ('missing', 'duplicate', 'pitch', 'transfer', 'barrier'):
            lines = synthetic('candidate')
            index = next(i for i, line in enumerate(lines) if line.startswith('GV_MIP_METAL_TRAITS '))
            if mode == 'missing': lines.pop(index)
            elif mode == 'duplicate': lines.insert(index, lines[index])
            else:
                field, value = {'pitch': ('native_pitch_step', 256),
                    'transfer': ('native_transfer_align', 128), 'barrier': ('honors_barriers', 1)}[mode]
                lines[index] = lines[index].replace(field + '=1' if mode != 'barrier' else field + '=0', field + '=' + str(value))
            with self.subTest(mode=mode): self.rejects(lines)

    def test_corrupt_actual_alignment_request_offset_copy_and_wait_fail(self):
        for marker, old, new in (
                ('START', 'align=512', 'align=256'),
                ('START', 'pitch_step=1', 'pitch_step=256'),
                ('REQUEST', 'bytes=1398128', 'bytes=1398127'),
                ('COPY', 'offset=8', 'offset=9'),
                ('COPY', 'source=0', 'source=1'),
                ('WAIT', 'batch=0', 'batch=1')):
            lines = synthetic('candidate')
            index = next(i for i, line in enumerate(lines) if line.startswith('GV_MIP_' + marker + ' ') and old in line)
            lines[index] = lines[index].replace(old, new, 1)
            with self.subTest(marker=marker): self.rejects(lines)

    def test_any_explicit_barrier_unknown_record_or_partial_rejection_fails(self):
        for line in (
                'GV_MIP_BARRIER case=vigil-astc layer=0 batch=0 phase=begin first_mip=0 mip_count=1',
                'GV_MIP_FORGED case=vigil-astc layer=0',
                'GV_MIP_WAIT case=atomic-reject layer=0 batch=0'):
            self.rejects(synthetic('candidate') + [line])

    def test_readback_usage_format_and_unexpected_errors_fail(self):
        for field, value in (('actual_sha256', '0' * 64), ('equal', False), ('created_format', 36)):
            lines = synthetic('candidate')
            index = next(i for i, line in enumerate(lines) if line.startswith('GV_MIP_READBACK ') and 'vigil-astc' in line)
            item = json.loads(lines[index].split(' ', 1)[1]); item[field] = value
            lines[index] = 'GV_MIP_READBACK ' + json.dumps(item)
            with self.subTest(field=field): self.rejects(lines)
        lines = synthetic('candidate')
        index = next(i for i, line in enumerate(lines) if line.startswith('GV_MIP_CAPABILITY '))
        item = json.loads(lines[index].split(' ', 1)[1]); item['usage'] = 49
        lines[index] = 'GV_MIP_CAPABILITY ' + json.dumps(item)
        self.rejects(lines)
        for diagnostic in ('ERROR: injected native failure', ' SCRIPT ERROR: injected failure',
                           'Parse Error: injected failure'):
            self.rejects(synthetic('candidate') + [diagnostic])

    def test_original_observer_and_embedded_script_are_frozen(self):
        self.assertEqual(hashlib.sha256((HERE / 'observer.py').read_bytes()).hexdigest(),
            '37d7ecbb90016c38238b0dc79f02c1c68aab3b63ee01fdd31b723ace570dba57')
        probe = load('metal_frozen_probe', HERE / 'probe.py')
        self.assertEqual(hashlib.sha256(probe.SCRIPT.encode()).hexdigest(),
            '8f905cfe509b994fcdfe7ea9598e4537aea6923cbf23f94ff893534343e582c1')


if __name__ == '__main__':
    unittest.main()
