#!/usr/bin/env python3
"""Compile the full verbatim native initializer against a recording CPU driver.

This exercises actual request/copy/barrier/control flow, not only an arithmetic
model. Real RenderingDevice/backend readback remains a separate hosted proof.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--build-dir', type=Path, required=True)
    args = parser.parse_args()
    data = args.source.read_bytes()
    source = data.decode()
    copies = 'static _ALWAYS_INLINE_ void _copy_region(' + source.split(
        'static _ALWAYS_INLINE_ void _copy_region(', 1)[1].split(
        'uint32_t RenderingDevice::_texture_layer_count', 1)[0]
    method = 'Error RenderingDevice::_texture_initialize(' + source.split(
        'Error RenderingDevice::_texture_initialize(', 1)[1].split(
        'Error RenderingDevice::texture_update(', 1)[0]
    template = Path(__file__).with_name('texture_mip_batches.cpp.in')
    code = template.read_text().replace('// EXACT_NATIVE_COPY_FUNCTIONS', copies)
    code = code.replace('// EXACT_NATIVE_INITIALIZE', method)
    args.build_dir.mkdir(parents=True, exist_ok=False)
    unit, binary = args.build_dir/'native.cpp', args.build_dir/'native-contract'
    unit.write_text(code)
    command = ['c++', '-std=c++17', '-Wall', '-Wextra', '-Werror', '-Wno-misleading-indentation',
               '-O1', '-fsanitize=address,undefined', '-fno-omit-frame-pointer', str(unit), '-o', str(binary)]
    built = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=60)
    (args.build_dir/'compile.log').write_text(built.stdout)
    if built.returncode:
        print(built.stdout, end='')
        return built.returncode
    ran = subprocess.run([str(binary)], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=30)
    (args.build_dir/'native.log').write_text(ran.stdout)
    report = {'source_sha256': hashlib.sha256(data).hexdigest(),
              'runner_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              'fixture_sha256': hashlib.sha256(template.read_bytes()).hexdigest(),
              'unit_sha256': hashlib.sha256(unit.read_bytes()).hexdigest(),
              'compiler_command': command, 'compile_exit': built.returncode, 'native_exit': ran.returncode,
              'scope': 'full native initializer with recording CPU driver; not an actual renderer'}
    (args.build_dir/'result.json').write_text(json.dumps(report, indent=2)+'\n')
    print(ran.stdout, end='')
    return ran.returncode


if __name__ == '__main__':
    sys.exit(main())
