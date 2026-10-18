#!/usr/bin/env python3
"""Metal-specific coverage adapter; original observer/production patch stay exact."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

SPEC = importlib.util.spec_from_file_location('gv_original_staging_observer', Path(__file__).with_name('observer.py'))
observer = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(observer)


def instrument(source):
    output = observer.instrument(source)
    # Metal advertises tight block rows and derives that same layout at blit.
    # The Vulkan-only artificial row pitch is not valid Metal native coverage.
    forced = '\t\t\t\tif (gv_staging_forced) {\n\t\t\t\t\tpitch_step = MAX(pitch_step, 256u);\n\t\t\t\t}\n'
    output = observer.one(output, forced, '')
    reported = 'gv_staging_forced ? MAX(uint32_t(driver->api_trait_get(RDD::API_TRAIT_TEXTURE_DATA_ROW_PITCH_STEP)), 256u) : uint32_t(driver->api_trait_get(RDD::API_TRAIT_TEXTURE_DATA_ROW_PITCH_STEP))'
    output = observer.one(output, reported, 'uint32_t(driver->api_trait_get(RDD::API_TRAIT_TEXTURE_DATA_ROW_PITCH_STEP))')
    anchor = '\n\t\t\tif (!gv_staging_case.is_empty()) {\n\t\t\t\tprint_line(vformat("GV_STAGING_REQUEST '
    traits = '''\t\t\t\tprint_line(vformat("GV_STAGING_METAL_TRAITS case=%s layer=%d row_pitch_step=%d transfer_alignment=%d honors_pipeline_barriers=%d forced_row_padding=0 forced_offset_alignment=%d", gv_staging_case, p_layer, uint32_t(driver->api_trait_get(RDD::API_TRAIT_TEXTURE_DATA_ROW_PITCH_STEP)), uint32_t(driver->api_trait_get(RDD::API_TRAIT_TEXTURE_TRANSFER_ALIGNMENT)), uint32_t(driver->api_trait_get(RDD::API_TRAIT_HONORS_PIPELINE_BARRIERS)), gv_staging_forced ? 1 : 0));
'''
    guard, request = anchor.split('\t\t\t\tprint_line', 1)
    return observer.one(output, anchor, guard + traits + '\t\t\t\tprint_line' + request)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-dir', type=Path, required=True)
    args = parser.parse_args()
    path = args.source_dir / 'servers/rendering/rendering_device.cpp'
    data = path.read_bytes()
    before = hashlib.sha256(data).hexdigest()
    if before not in observer.KNOWN:
        raise SystemExit('Metal adapter requires exact uninstrumented source')
    updated = instrument(data.decode()).encode()
    path.write_bytes(updated)
    print(json.dumps({'profile': 'macos-arm64-metal-v1', 'variant': observer.KNOWN[before],
        'source_before_sha256': before, 'source_after_sha256': hashlib.sha256(updated).hexdigest(),
        'observer_sha256': hashlib.sha256(Path(observer.__file__).read_bytes()).hexdigest(),
        'adapter_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'forced_256_gpu_row_padding': 'NOT_RUN', 'forced_512_offset_alignment': 'retained',
        'scope': 'natural Metal rows; no GPU equivalence to original CPU/Vulkan forced256 coverage'}))
