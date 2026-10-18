#!/usr/bin/env python3
"""Bounded stdout transport for only this component's generated native logs."""
import argparse
from pathlib import Path
import re
import sys


def emit(root, stream=None):
    stream = stream or sys.stdout

    def line(value):
        value = ''.join(char for char in str(value) if char == '\t' or char.isprintable())
        value = re.sub(r'https?://\S+', '[URL omitted]', value)
        value = re.sub(r'(?i)\b(?:authorization|password|secret|token)\s*[:=]\s*.*',
                       '[credential field omitted]', value)
        print('native-staging diagnostic | ' + value[:1024], file=stream, flush=True)

    root = Path(root)
    if root.is_symlink():
        line('Symlink evidence root refused')
        return
    root = root.resolve()
    for variant in ('baseline', 'candidate'):
        directory = root / ('rd-' + variant)
        path = directory / 'native.log'
        if (directory.is_symlink() or path.is_symlink() or not path.is_file() or
                not path.resolve().is_relative_to(root)):
            line(variant + ': native.log unavailable within evidence root')
            continue
        size = path.stat().st_size
        line(f'{variant}: native.log last <=8192 bytes/80 lines; file_bytes={size}')
        with path.open('rb') as log:
            log.seek(max(0, size - 8192))
            tail = log.read(8192).decode(errors='replace')
        for entry in tail.splitlines()[-80:]:
            line(entry)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    emit(parser.parse_args().root)
