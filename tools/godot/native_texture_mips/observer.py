#!/usr/bin/env python3
"""Opt-in actual RD request/copy/barrier hooks; never part of the shipping patch."""
import argparse
import hashlib
import json
from pathlib import Path

KNOWN = {
    'ac38319ac1cf7da23889580b158d4a5e89fd4e4552d73760f0a2081ed076a4d3': 'baseline',
    '14b79a01e2a99a6f4923ab3d1b4f620e4e86b071734da239b5820a95623e0968': 'candidate',
}


def one(text, old, new):
    if text.count(old) != 1:
        raise ValueError('observer anchor missing or ambiguous: ' + old[:80])
    return text.replace(old, new)


def instrument(source, variant):
    if 'GV_MIP_' in source:
        raise ValueError('mip observer already present')
    prefix, rest = source.split('Error RenderingDevice::_texture_initialize(', 1)
    body, tail = rest.split('Error RenderingDevice::texture_update(', 1)
    decl = ('const ' if variant == 'candidate' else '') + 'uint32_t required_align = _texture_alignment(texture);'
    body = one(body, decl, '''uint32_t required_align = _texture_alignment(texture);
\tconst String gv_case = (this != singleton) ? OS::get_singleton()->get_environment("GLASSVOW_MIP_CASE") : String();
\tconst bool gv_padded = !gv_case.is_empty() && gv_case.ends_with("-padded");
\tif (gv_padded) { required_align = MAX(required_align, 512u); }''')
    step = ('const ' if variant == 'candidate' else '') + 'uint32_t pitch_step = driver->api_trait_get(RDD::API_TRAIT_TEXTURE_DATA_ROW_PITCH_STEP);'
    body = one(body, step, '''uint32_t pitch_step = driver->api_trait_get(RDD::API_TRAIT_TEXTURE_DATA_ROW_PITCH_STEP);
\t\t\t\tif (gv_padded) { pitch_step = MAX(pitch_step, 256u); }''')
    block = ('const ' if variant == 'candidate' else '') + 'uint32_t block_size = get_compressed_image_format_block_byte_size(texture->format);'
    body = one(body, block, block + '''
\tif (!gv_case.is_empty()) {
\t\tprint_line(vformat("GV_MIP_START case=%s layer=%d format=%d width=%d height=%d depth=%d mips=%d payload=%d pitch_step=%d align=%d block_w=%d block_h=%d block_bytes=%d pixel_size=%d rshift=%d forced=%d", gv_case, p_layer, texture->format, texture->width, texture->height, texture->depth, texture->mipmaps, p_data.size(), gv_padded ? MAX(uint32_t(driver->api_trait_get(RDD::API_TRAIT_TEXTURE_DATA_ROW_PITCH_STEP)), 256u) : uint32_t(driver->api_trait_get(RDD::API_TRAIT_TEXTURE_DATA_ROW_PITCH_STEP)), required_align, block_w, block_h, block_size, pixel_size, pixel_rshift, gv_padded ? 1 : 0));
\t}''')
    if variant == 'baseline':
        acquire = '\t\t\ttransfer_worker = _acquire_transfer_worker(staging_local_offset, required_align, staging_worker_offset);'
        request = 'batch=0 bytes=%d first_mip=0 mip_count=%d", gv_case, p_layer, staging_local_offset, texture->mipmaps'
        copy_values = '0, mm_i, z, staging_buffer_offset, staging_local_offset, pitch, logic_width, logic_height, width, height, mipmap_offset + (tight_mip_size / depth) * z'
        batch_id = '0'
    else:
        acquire = '\t\tTransferWorker *transfer_worker = _acquire_transfer_worker(upload.bytes, required_align, staging_worker_offset);'
        request = 'batch=%d bytes=%d first_mip=%d mip_count=%d", gv_case, p_layer, batch_i, upload.bytes, upload.first_mipmap, upload.mipmap_count'
        copy_values = 'batch_i, slice.mipmap, slice.z, staging_buffer_offset, slice.staging_offset, slice.pitch, slice.logic_width, slice.logic_height, slice.width, slice.height, slice.source_offset'
        batch_id = 'batch_i'
    body = one(body, acquire, '\t\tif (!gv_case.is_empty()) { print_line(vformat("GV_MIP_REQUEST case=%s layer=%d ' + request + ')); }\n' + acquire)
    call = 'driver->command_copy_buffer_to_texture(transfer_worker->command_buffer, transfer_worker->staging_buffer, texture->driver_id, p_dst_layout, copy_region);'
    body = one(body, call, '''if (!gv_case.is_empty()) {
\t\t\t\tprint_line(vformat("GV_MIP_COPY case=%s layer=%d batch=%d mip=%d z=%d offset=%d local=%d pitch=%d width=%d height=%d padded_w=%d padded_h=%d source=%d", gv_case, p_layer, ''' + copy_values + '''));
\t\t\t}
\t\t\t''' + call)
    for phase, anchor in [('begin', 'driver->command_pipeline_barrier(transfer_worker->command_buffer, RDD::PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT, RDD::PIPELINE_STAGE_COPY_BIT, {}, {}, tb, {});'),
                          ('end', 'transfer_worker->texture_barriers.push_back(tb);')]:
        hook = 'if (!gv_case.is_empty()) { print_line(vformat("GV_MIP_BARRIER case=%s layer=%d batch=%d phase=' + phase + ' first_mip=%d mip_count=%d", gv_case, p_layer, ' + batch_id + ', tb.subresources.base_mipmap, tb.subresources.mipmap_count)); }\n\t\t\t'
        body = one(body, anchor, hook + anchor)
    wait = '_wait_for_transfer_worker(transfer_worker);'
    body = one(body, wait, wait + '\n\t\t\tif (!gv_case.is_empty()) { print_line(vformat("GV_MIP_WAIT case=%s layer=%d batch=%d", gv_case, p_layer, ' + batch_id + ')); }')
    return prefix + 'Error RenderingDevice::_texture_initialize(' + body + 'Error RenderingDevice::texture_update(' + tail


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-dir', type=Path, required=True)
    args = parser.parse_args()
    path = args.source_dir/'servers/rendering/rendering_device.cpp'
    before = path.read_bytes()
    source_sha = hashlib.sha256(before).hexdigest()
    if source_sha not in KNOWN:
        raise SystemExit('observer needs exact allocator-only or allocator-plus-mip source')
    updated = instrument(before.decode(), KNOWN[source_sha]).encode()
    path.write_bytes(updated)
    print(json.dumps({'variant': KNOWN[source_sha], 'source_before_sha256': source_sha,
        'source_after_sha256': hashlib.sha256(updated).hexdigest(),
        'observer_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'scope': 'opt-in local RD hooks; padded cases force identical conservative traits'}))


if __name__ == '__main__':
    main()
