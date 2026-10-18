#!/usr/bin/env python3
"""Install identical, opt-in RD request/copy instrumentation in hosted builds."""
import argparse
import hashlib
import json
from pathlib import Path

KNOWN = {
    'cb319128c2650189dc3ebff5aad7e70ac73b0bd4c4d0c58993f06d4d002ddc62': 'baseline',
    'ac38319ac1cf7da23889580b158d4a5e89fd4e4552d73760f0a2081ed076a4d3': 'candidate',
}


def one(text, old, new):
    if text.count(old) != 1:
        raise ValueError('upstream observer anchor is missing or ambiguous')
    return text.replace(old, new)


def instrument(source):
    # These hooks only run after the probe script selects an explicit case.
    if 'GV_STAGING_REQUEST ' in source or 'GV_STAGING_COPY ' in source:
        raise ValueError('native staging source is already instrumented')
    prefix, rest = source.split('Error RenderingDevice::_texture_initialize(', 1)
    source, tail = rest.split('Error RenderingDevice::texture_update(', 1)
    source = one(source,
        '\tuint32_t required_align = _texture_alignment(texture);\n',
        '''\tuint32_t required_align = _texture_alignment(texture);
\tconst String gv_staging_case = (this != singleton) ? OS::get_singleton()->get_environment("GLASSVOW_STAGING_CASE") : String();
\tconst bool gv_staging_forced = !gv_staging_case.is_empty() && gv_staging_case.ends_with("-padded");
\tif (gv_staging_forced) {
\t\trequired_align = MAX(required_align, 512u);
\t}
''')
    source = one(source,
        '\t\t\t\tuint32_t pitch_step = driver->api_trait_get(RDD::API_TRAIT_TEXTURE_DATA_ROW_PITCH_STEP);\n',
        '''\t\t\t\tuint32_t pitch_step = driver->api_trait_get(RDD::API_TRAIT_TEXTURE_DATA_ROW_PITCH_STEP);
\t\t\t\tif (gv_staging_forced) {
\t\t\t\t\tpitch_step = MAX(pitch_step, 256u);
\t\t\t\t}
''')
    source = one(source,
        '\t\t\ttransfer_worker = _acquire_transfer_worker(staging_local_offset, required_align, staging_worker_offset);\n',
        '''\t\t\tif (!gv_staging_case.is_empty()) {
\t\t\t\tprint_line(vformat("GV_STAGING_REQUEST case=%s layer=%d format=%d width=%d height=%d depth=%d mips=%d payload=%d reserved=%d pitch_step=%d align=%d block_w=%d block_h=%d pixel_size=%d rshift=%d forced=%d", gv_staging_case, p_layer, texture->format, texture->width, texture->height, texture->depth, texture->mipmaps, p_data.size(), staging_local_offset, gv_staging_forced ? MAX(uint32_t(driver->api_trait_get(RDD::API_TRAIT_TEXTURE_DATA_ROW_PITCH_STEP)), 256u) : uint32_t(driver->api_trait_get(RDD::API_TRAIT_TEXTURE_DATA_ROW_PITCH_STEP)), required_align, block_w, block_h, pixel_size, pixel_rshift, gv_staging_forced ? 1 : 0));
\t\t\t}
\t\t\ttransfer_worker = _acquire_transfer_worker(staging_local_offset, required_align, staging_worker_offset);
''')
    source = one(source,
        '\t\t\t\t\tdriver->command_copy_buffer_to_texture(transfer_worker->command_buffer, transfer_worker->staging_buffer, texture->driver_id, p_dst_layout, copy_region);\n',
        '''\t\t\t\t\tif (!gv_staging_case.is_empty()) {
\t\t\t\t\t\tprint_line(vformat("GV_STAGING_COPY case=%s layer=%d mip=%d z=%d offset=%d local=%d pitch=%d width=%d height=%d padded_w=%d padded_h=%d reserved=%d", gv_staging_case, p_layer, mm_i, z, staging_buffer_offset, staging_local_offset, pitch, logic_width, logic_height, width, height, to_allocate));
\t\t\t\t\t}
\t\t\t\t\tdriver->command_copy_buffer_to_texture(transfer_worker->command_buffer, transfer_worker->staging_buffer, texture->driver_id, p_dst_layout, copy_region);
''')
    return prefix + 'Error RenderingDevice::_texture_initialize(' + source + 'Error RenderingDevice::texture_update(' + tail


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-dir', type=Path, required=True)
    args = parser.parse_args()
    path = args.source_dir / 'servers/rendering/rendering_device.cpp'
    data = path.read_bytes()
    before = hashlib.sha256(data).hexdigest()
    if before not in KNOWN:
        raise SystemExit('observer requires one exact uninstrumented baseline/candidate RD source')
    updated = instrument(data.decode()).encode()
    path.write_bytes(updated)
    print(json.dumps({'observer_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'variant': KNOWN[before], 'source_before_sha256': before,
        'source_after_sha256': hashlib.sha256(updated).hexdigest(),
        'scope': 'test-only opt-in hooks; padded cases impose conservative pitch/alignment identically'}))


if __name__ == '__main__':
    main()
