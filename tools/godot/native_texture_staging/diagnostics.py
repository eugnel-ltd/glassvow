#!/usr/bin/env python3
"""Bounded stdout transport for only this component's generated native logs."""
import argparse
import json
from pathlib import Path
import re
import sys


def emit_summary(root, stream=None):
    """Transport only bounded typed device/format observations, never raw files."""
    stream = stream or sys.stdout
    root = Path(root)
    if root.is_symlink():
        return
    root = root.resolve()
    budget = 16384

    def line(value):
        nonlocal budget
        value = re.sub(r'https?://\S+', '[URL omitted]', str(value))
        value = re.sub(r'(?i)\b(?:authorization|password|secret|token)\s*[:=]\s*.*', '[credential field omitted]', value)
        value = ''.join(c for c in value if c.isprintable())[:512]
        encoded = ('native-staging observation | ' + value + '\n').encode()
        if len(encoded) <= budget:
            stream.write(encoded.decode())
            budget -= len(encoded)

    def owned(relative, limit):
        path = root / relative
        if (any(p.is_symlink() for p in [path, *path.parents] if p != root.parent)
                or not path.is_file() or not path.resolve().is_relative_to(root) or path.stat().st_size > limit):
            return None
        return path

    def typed_device(device):
        if isinstance(device, dict):
            return {k: device[k] for k in ('os', 'display', 'vendor', 'name', 'arm64', 'x86_64')
                    if isinstance(device.get(k), (str, bool))}
        return {}

    def read_json(relative):
        path = owned(relative, 131072)
        try:
            value = json.loads(path.read_text()) if path else {}
            return value if isinstance(value, dict) else {}
        except (OSError, ValueError):
            return {}

    venue = read_json('venue/result.json')
    line('stock ' + json.dumps({k: venue[k] for k in ('profile', 'status', 'component_status')
                              if isinstance(venue.get(k), str)}))
    line('stock device ' + json.dumps(typed_device(venue.get('device'))))
    expected = {'ETC2_RGB8': 146, 'ETC2_RGBA8': 150, 'EAC_RG11': 154,
                'ASTC_4x4_UNORM': 156, 'RGBA8': 36, 'RG8_LA8': 15}
    for item in venue.get('formats', [])[:6] if isinstance(venue.get('formats'), list) else []:
        if (isinstance(item, dict) and item.get('format') in expected
                and item.get('format_id') == expected[item['format']] and item.get('usage') == 193
                and type(item.get('supported')) is bool):
            line('stock format ' + json.dumps({k: item[k] for k in ('format', 'format_id', 'usage', 'supported')}))
    cases = {'etc2-rgb-odd': 146, 'etc2-rgba-wood': 150, 'eac-rg11-normal': 154, 'astc4-material': 156,
             'astc4-padded': 156, 'rgba8-depth-padded': 36, 'la8-control': 15}
    for variant in ('baseline', 'candidate'):
        command = read_json('component/rd-' + variant + '/command.json')
        profile = command.get('native_profile', {})
        line(variant + ' native device ' + json.dumps(typed_device(profile.get('device') if isinstance(profile, dict) else {})))
        path = owned('component/rd-' + variant + '/native.log', 1048576)
        if not path:
            continue
        count = 0
        for entry in path.read_text(errors='replace').splitlines():
            if not entry.startswith('GV_STAGING_CAPABILITY '):
                continue
            try:
                item = json.loads(entry[len('GV_STAGING_CAPABILITY '):])
                if (count < 7 and isinstance(item, dict) and item.get('case') in cases
                        and item.get('native_format') == cases[item['case']] and item.get('usage_flags') == 193
                        and isinstance(item.get('format'), str) and type(item.get('supported')) is bool):
                    line(variant + ' native query ' + json.dumps({k: item[k] for k in
                         ('case', 'format', 'native_format', 'usage_flags', 'supported')}))
                    count += 1
            except (ValueError, KeyError, TypeError):
                continue


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
    parser.add_argument('--summary', action='store_true')
    args = parser.parse_args()
    (emit_summary if args.summary else emit)(args.root)
