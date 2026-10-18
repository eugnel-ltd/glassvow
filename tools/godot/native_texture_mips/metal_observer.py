#!/usr/bin/env python3
"""Additive Metal3 observer: native tight rows and retained offset stress.

No driver copy or production patch is changed. The original Vulkan observer and
its 256-byte row-pitch controls remain byte-frozen and separately required.
"""
import argparse
import hashlib
import json
from pathlib import Path

import observer

ORIGINAL_OBSERVER_SHA256 = '37d7ecbb90016c38238b0dc79f02c1c68aab3b63ee01fdd31b723ace570dba57'
METAL_SOURCES = {
    'drivers/metal/rendering_context_driver_metal.cpp': 'a82d1f4637439327b5c95c74e116d0ca30148331206f1c2da277ef5d01e10ced',
    'drivers/metal/rendering_device_driver_metal3.cpp': 'efb4727ff7cca2fc2f3caa4d4e7be92215446a0041b0e32ca386edc0c917471f',
    'drivers/metal/rendering_device_driver_metal.h': 'a2fbb56762efcb67a17d24dbe42a7b0819a53c3ad5b62780b869849ebff75f54',
    'drivers/metal/rendering_device_driver_metal.cpp': '3e1332160b0baacbbcb8499e13441564c71336730441aff9d22a39765c35b393',
    'drivers/metal/metal3_objects.cpp': '801b417c2a3642cc839eb6f6c410cdc012d43f4bf1bbd079c5029094be22cd1e',
    'drivers/metal/metal_objects_shared.h': '106aa1a090b350eac0027445440143693abae501a2e6197ca395545edf2a044e',
    'drivers/metal/pixel_formats.cpp': '3cf8c5be5b4bc05c8e8daf89a80dbb2ea91ea1673a259b810da65a14090daa42',
    'servers/rendering/rendering_device_driver.cpp': 'e33892c5c721d008dd277e19848dce62bec84754d99bf3ea342df0939fa41f91',
}


def instrument(source, variant):
    updated = observer.instrument(source, variant)
    # Metal3 derives tight rows from logical extent, not region.row_pitch.
    # Retain 512-byte mip/depth offsets without inventing another native pitch.
    updated = observer.one(updated,
        '\n\t\t\t\tif (gv_padded) { pitch_step = MAX(pitch_step, 256u); }', '')
    updated = observer.one(updated,
        'gv_padded ? MAX(uint32_t(driver->api_trait_get(RDD::API_TRAIT_TEXTURE_DATA_ROW_PITCH_STEP)), 256u) : uint32_t(driver->api_trait_get(RDD::API_TRAIT_TEXTURE_DATA_ROW_PITCH_STEP))',
        'uint32_t(driver->api_trait_get(RDD::API_TRAIT_TEXTURE_DATA_ROW_PITCH_STEP))')
    anchor = '\tif (!gv_case.is_empty()) {\n\t\tprint_line(vformat("GV_MIP_START '
    return observer.one(updated, anchor,
        '\tif (!gv_case.is_empty()) {\n'
        '\t\tprint_line(vformat("GV_MIP_METAL_TRAITS case=%s layer=%d native_pitch_step=%d native_transfer_align=%d honors_barriers=%d", gv_case, p_layer, uint32_t(driver->api_trait_get(RDD::API_TRAIT_TEXTURE_DATA_ROW_PITCH_STEP)), uint32_t(driver->api_trait_get(RDD::API_TRAIT_TEXTURE_TRANSFER_ALIGNMENT)), uint32_t(driver->api_trait_get(RDD::API_TRAIT_HONORS_PIPELINE_BARRIERS))));\n'
        '\t\tprint_line(vformat("GV_MIP_START ')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-dir', type=Path, required=True)
    args = parser.parse_args()
    digest = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
    if digest(Path(observer.__file__)) != ORIGINAL_OBSERVER_SHA256:
        raise ValueError('original mip observer differs')
    for path, expected in METAL_SOURCES.items():
        if digest(args.source_dir / path) != expected:
            raise ValueError('Metal source contract differs: ' + path)
    path = args.source_dir / 'servers/rendering/rendering_device.cpp'
    before = path.read_bytes(); source_sha = hashlib.sha256(before).hexdigest()
    if source_sha not in observer.KNOWN:
        raise ValueError('Metal observer requires exact allocator-only or bounded-mip source')
    variant = observer.KNOWN[source_sha]
    updated = instrument(before.decode(), variant).encode()
    path.write_bytes(updated)
    print(json.dumps({'variant': variant, 'source_before_sha256': source_sha,
        'source_after_sha256': hashlib.sha256(updated).hexdigest(),
        'observer_sha256': digest(Path(__file__)),
        'original_observer_sha256': ORIGINAL_OBSERVER_SHA256,
        'metal_sources': METAL_SOURCES,
        'profile': 'macos-arm64-metal-v1',
        'scope': 'native tight rows; retained 512-byte offset stress; no Vulkan 256-byte row-pitch claim'}))


if __name__ == '__main__':
    main()
