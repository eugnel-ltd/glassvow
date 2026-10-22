#!/usr/bin/env python3
"""Compile exact upstream reservation/copy statements and test their contract.

This CPU-native first regression is independent of a Godot build. It does not
claim renderer evidence: the hosted RD observer/probe supplies that separately.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time


NATIVE_TEST = r'''
#include <algorithm>
#include <cstdint>
#include <cstring>
#include <iostream>
#include <numeric>
#include <string>
#include <vector>

#define _ALWAYS_INLINE_ inline
#define STEPIFY(value, step) (((value) + (step) - 1) / (step) * (step))

namespace RDD { enum { API_TRAIT_TEXTURE_DATA_ROW_PITCH_STEP }; }
struct Driver {
    uint32_t step;
    uint32_t api_trait_get(int) const { return step; }
};

// EXACT_NATIVE_COPY_FUNCTIONS

static uint32_t reserve(uint32_t width, uint32_t height, uint32_t pixel_size,
        uint32_t block_w, uint32_t block_h, uint32_t pixel_rshift, Driver *driver) {
    (void)block_h; // The old upstream reservation ignores the block height.
    // EXACT_NATIVE_RESERVATION
    return to_allocate;
}

static uint32_t align_offset(uint32_t staging_local_offset, uint32_t required_align) {
    // EXACT_NATIVE_ALIGNMENT
    return staging_local_offset;
}

struct Case {
    const char *name;
    uint32_t width, height, mip_count, depth, layers;
    uint32_t pixel_size, block_w, block_h, shift, block_bytes;
    uint32_t pitch_step, transfer_alignment;
};

static int failures = 0;
static uint32_t checks = 0;
static void check(bool ok, const std::string &message) {
    checks++;
    if (!ok) { failures++; std::cerr << "FAIL: " << message << '\n'; }
}

static void run_case(const Case &c) {
    Driver driver{c.pitch_step};
    uint32_t required_align = std::lcm(c.block_bytes, c.transfer_alignment);
    for (uint32_t layer = 0; layer < c.layers; layer++) {
        uint32_t width = c.width, height = c.height, depth = c.depth;
        uint32_t native_total = 0, expected_total = 0;
        for (uint32_t mip = 0; mip < c.mip_count; mip++) {
            uint32_t padded_w = STEPIFY(width, c.block_w);
            uint32_t padded_h = STEPIFY(height, c.block_h);
            uint32_t columns = padded_w / c.block_w;
            uint32_t rows = padded_h / c.block_h;
            uint32_t tight_row_bytes = columns * c.block_bytes;
            uint32_t expected_pitch = STEPIFY(tight_row_bytes, c.pitch_step);
            uint32_t expected_slice = expected_pitch * rows;
            uint32_t actual_slice = reserve(padded_w, padded_h, c.pixel_size,
                    c.block_w, c.block_h, c.shift, &driver);
            std::string at = std::string(c.name) + " layer=" + std::to_string(layer)
                    + " mip=" + std::to_string(mip);
            check(actual_slice == expected_slice,
                    at + " reservation must cover block rows exactly (got="
                    + std::to_string(actual_slice) + ", expected="
                    + std::to_string(expected_slice) + ")");
            // The old allocation is larger: still check actual copied bytes,
            // every padding byte, both canaries and each depth-slice boundary.
            std::vector<uint8_t> source(tight_row_bytes * rows);
            for (size_t i = 0; i < source.size(); i++) {
                source[i] = uint8_t((i * 37 + mip * 11 + layer * 17) % 251);
            }
            for (uint32_t z = 0; z < depth; z++) {
                native_total = align_offset(native_total, required_align);
                expected_total = STEPIFY(expected_total, required_align);
                check(native_total == expected_total, at + " depth-start alignment");
                size_t span = std::max(actual_slice, expected_slice);
                std::vector<uint8_t> destination(span + 64, 0xcd);
                _copy_region_block_or_regular(source.data(), destination.data() + 32,
                        0, 0, padded_w, padded_w, padded_h, c.block_w,
                        c.block_h, expected_pitch, c.pixel_size, c.block_bytes);
                bool same = true, padding = true;
                for (uint32_t row = 0; row < rows; row++) {
                    same = same && std::memcmp(source.data() + row * tight_row_bytes,
                            destination.data() + 32 + row * expected_pitch,
                            tight_row_bytes) == 0;
                    for (uint32_t x = tight_row_bytes; x < expected_pitch; x++) {
                        padding = padding && destination[32 + row * expected_pitch + x] == 0xcd;
                    }
                }
                check(same, at + " byte-identical compressed/uncompressed copy");
                check(padding, at + " row padding remains untouched");
                check(std::all_of(destination.begin(), destination.begin() + 32,
                        [](uint8_t v) { return v == 0xcd; }), at + " prefix canary");
                check(std::all_of(destination.begin() + 32 + expected_slice,
                        destination.end(), [](uint8_t v) { return v == 0xcd; }),
                        at + " exact copied span and suffix canary");
                native_total += actual_slice;
                expected_total += expected_slice;
            }
            width = std::max(1u, width >> 1);
            height = std::max(1u, height >> 1);
            depth = std::max(1u, depth >> 1);
        }
        check(native_total == expected_total,
                std::string(c.name) + " whole mip/depth chain reservation");
        std::cout << "CASE " << c.name << " layer=" << layer << " request="
                << native_total << " expected=" << expected_total << '\n';
    }
}

int main() {
    const Case cases[] = {
        {"ETC2 RGB odd blocks", 17,13,5,5,2, 1,4,4,1,8, 1,1},
        {"ETC2 RGBA wood layer", 2048,1024,12,1,2, 1,4,4,0,16, 1,1},
        {"EAC RG11 stone normal", 1024,768,11,1,1, 1,4,4,0,16, 1,1},
        {"ASTC4 nonunit pitch", 53,31,6,3,2, 1,4,4,0,16, 256,512},
        {"ASTC8 nonunit pitch", 37,19,6,3,2, 1,8,8,2,16, 256,512},
        {"RGBA8 unchanged", 23,17,5,3,2, 4,1,1,0,4, 256,512},
        {"LA8 unchanged", 3,17,5,1,2, 2,1,1,0,2, 1,1},
    };
    for (const Case &c : cases) { run_case(c); }
    std::cout << "Native reservation/copy checks=" << checks << " failures=" << failures << '\n';
    return failures ? 1 : 0;
}
'''


def extract(source):
    method = source.split('Error RenderingDevice::_texture_initialize(', 1)[1]
    method = method.split('Error RenderingDevice::texture_update(', 1)[0]
    reservation = method.split('uint32_t pitch = ', 1)[1].split('if (copy_pass)', 1)[0]
    reservation = 'uint32_t pitch = ' + reservation
    assert 'uint32_t to_allocate' in reservation and 'driver->api_trait_get' in reservation
    alignment = method.split('if (required_align > 0)', 1)[1].split('uint32_t pitch = ', 1)[0]
    alignment = 'if (required_align > 0)' + alignment
    copies = source.split('static _ALWAYS_INLINE_ void _copy_region(', 1)[1]
    copies = 'static _ALWAYS_INLINE_ void _copy_region(' + copies.split('uint32_t RenderingDevice::_texture_layer_count', 1)[0]
    assert copies.count('static _ALWAYS_INLINE_ void ') == 2
    return reservation, alignment, copies


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--build-dir', type=Path, required=True)
    parser.add_argument('--compiler', default='c++')
    args = parser.parse_args()
    source_bytes = args.source.read_bytes()
    reservation, alignment, copies = extract(source_bytes.decode())
    code = NATIVE_TEST.replace('// EXACT_NATIVE_RESERVATION', reservation)
    code = code.replace('// EXACT_NATIVE_ALIGNMENT', alignment)
    code = code.replace('// EXACT_NATIVE_COPY_FUNCTIONS', copies)
    args.build_dir.mkdir(parents=True, exist_ok=False)
    unit = args.build_dir / 'native.cpp'
    binary = args.build_dir / 'native-contract'
    unit.write_text(code)
    command = [args.compiler, '-std=c++17', '-Wall', '-Wextra', '-Werror', '-O1',
               '-fsanitize=address,undefined', '-fno-omit-frame-pointer', str(unit), '-o', str(binary)]
    start = time.monotonic()
    compiled = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                              text=True, timeout=60)
    (args.build_dir / 'compile.log').write_text(compiled.stdout)
    if compiled.returncode:
        print(compiled.stdout, end='')
        return compiled.returncode
    ran = subprocess.run([str(binary)], stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                         text=True, timeout=30)
    (args.build_dir / 'native.log').write_text(ran.stdout)
    report = {'source': str(args.source), 'source_sha256': hashlib.sha256(source_bytes).hexdigest(),
              'fixture_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              'generated_cpp_sha256': hashlib.sha256(unit.read_bytes()).hexdigest(),
              'compiler_command': command, 'compile_exit': compiled.returncode,
              'native_exit': ran.returncode, 'seconds': time.monotonic() - start,
              'scope': 'exact extracted native reservation/alignment/copy functions; CPU, not full RD/driver evidence'}
    (args.build_dir / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
    print(ran.stdout, end='')
    return ran.returncode


if __name__ == '__main__':
    sys.exit(main())
