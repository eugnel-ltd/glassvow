#!/usr/bin/env python3
"""Verify actual RD requests, per-slice copies and GPU byte readback logs."""
import argparse
import hashlib
import json
from pathlib import Path

REQUEST = 'GV_STAGING_REQUEST '
COPY = 'GV_STAGING_COPY '
READBACK = 'GV_STAGING_READBACK '
CAPABILITY = 'GV_STAGING_CAPABILITY '
EXPECTED_LAYERS = {
    'etc2-rgb-odd': 2, 'etc2-rgba-wood': 2, 'eac-rg11-normal': 1,
    'astc4-material': 1, 'astc4-padded': 2, 'rgba8-depth-padded': 1,
    'la8-control': 2,
}
# Exact ed1 DataFormat enum plus native block width/height, pixel size and shift.
# Direct RD textures never use TextureStorage's decompression fallback.
EXPECTED_FORMATS = {
    'etc2-rgb-odd': (146, 4, 4, 1, 1),
    'etc2-rgba-wood': (150, 4, 4, 1, 0),
    'eac-rg11-normal': (154, 4, 4, 1, 0),
    'astc4-material': (156, 4, 4, 1, 0),
    'astc4-padded': (156, 4, 4, 1, 0),
    'rgba8-depth-padded': (36, 1, 1, 4, 0),
    'la8-control': (15, 1, 1, 2, 0),
}


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def step(value, alignment):
    return (value + alignment - 1) // alignment * alignment


def fields(text):
    result = {}
    for pair in text.split():
        key, value = pair.split('=', 1)
        result[key] = value if key == 'case' else int(value)
    return result


def inspect(path, variant):
    raw = path.read_bytes()
    text = raw.decode(errors='replace')
    require('SCRIPT ERROR' not in text and 'Parse Error' not in text,
            variant + ': script diagnostics invalidate the run')
    requests, copies, readbacks, capabilities = {}, {}, {}, {}
    for line in text.splitlines():
        if line.startswith(CAPABILITY):
            item = json.loads(line[len(CAPABILITY):])
            require(item['case'] not in capabilities, variant + ': duplicate format support query')
            capabilities[item['case']] = item
        elif line.startswith(REQUEST):
            item = fields(line[len(REQUEST):])
            key = item['case'], item['layer']
            require(key not in requests, variant + ': duplicate request')
            requests[key] = item
        elif line.startswith(COPY):
            item = fields(line[len(COPY):])
            copies.setdefault((item['case'], item['layer']), []).append(item)
        elif line.startswith(READBACK):
            item = json.loads(line[len(READBACK):])
            key = item['case'], item['layer']
            require(key not in readbacks, variant + ': duplicate readback')
            readbacks[key] = item
    expected = {(case, layer) for case, count in EXPECTED_LAYERS.items() for layer in range(count)}
    require(set(capabilities) == set(EXPECTED_LAYERS), variant + ': incomplete actual format support evidence')
    require(set(requests) == set(copies) == set(readbacks) == expected,
            variant + ': missing or unexpected actual request/copy/readback case')
    require('GV_STAGING_DONE 11' in text, variant + ': complete probe exit marker absent')
    result = {}
    for key in sorted(expected):
        request, readback = requests[key], readbacks[key]
        capability = capabilities[key[0]]
        native_format, block_w, block_h, pixel_size, rshift = EXPECTED_FORMATS[key[0]]
        require(capability['supported'] is True and capability['usage_flags'] > 0,
                variant + ': requested physical format is unsupported')
        require(capability['native_format'] == request['format'] == readback['requested_native_format']
                == readback['created_native_format'] == native_format,
                variant + ': requested/created/native physical format differs')
        require(capability['format'] == readback['format'], variant + ': format name differs')
        require(tuple(request[name] for name in ['block_w', 'block_h', 'pixel_size', 'rshift'])
                == (block_w, block_h, pixel_size, rshift), variant + ': native block layout differs')
        require(readback['equal'] is True, variant + ': GPU byte equality failed')
        require(readback['source_sha256'] == readback['actual_sha256'],
                variant + ': byte digest equality failed')
        require(readback['source_bytes'] == readback['actual_bytes'] == request['payload'],
                variant + ': payload byte count differs from actual request/readback')
        for name in ['width', 'height', 'depth', 'mips']:
            require(readback[name] == request[name], variant + ': resource metadata mismatch')
        require(request['pitch_step'] > 0 and request['align'] > 0,
                variant + ': missing actual driver alignment traits')
        if key[0].endswith('-padded'):
            require(request['forced'] == 1 and request['pitch_step'] >= 256 and request['align'] >= 512,
                    variant + ': requested nonunit test configuration not active')
        else:
            require(request['forced'] == 0, variant + ': unexpected forced configuration')
        width, height, depth = request['width'], request['height'], request['depth']
        actual_offset, minimal_offset, payload = 0, 0, 0
        index = 0
        for mip in range(request['mips']):
            padded_w = step(width, request['block_w'])
            padded_h = step(height, request['block_h'])
            pitch = step((padded_w * request['pixel_size'] * request['block_w']) >> request['rshift'],
                         request['pitch_step'])
            minimum_slice = pitch * (padded_h // request['block_h'])
            old_slice = (pitch * padded_h) >> request['rshift']
            native_slice = minimum_slice if variant == 'candidate' else old_slice
            tight_slice = (padded_w * padded_h * request['pixel_size']) >> request['rshift']
            for z in range(depth):
                actual_offset = step(actual_offset, request['align'])
                minimal_offset = step(minimal_offset, request['align'])
                require(index < len(copies[key]), variant + ': omitted mip/depth copy')
                event = copies[key][index]
                require((event['mip'], event['z']) == (mip, z), variant + ': copy order mismatch')
                require((event['width'], event['height'], event['padded_w'], event['padded_h']) ==
                        (width, height, padded_w, padded_h), variant + ': copy dimensions mismatch')
                require(event['pitch'] == pitch and event['local'] == actual_offset,
                        variant + ': actual copy pitch/offset differs')
                require(event['reserved'] == native_slice, variant + ': actual per-slice reservation differs')
                require(event['offset'] % request['align'] == 0, variant + ': worker offset is misaligned')
                actual_offset += native_slice
                minimal_offset += minimum_slice
                payload += tight_slice
                index += 1
            width, height, depth = max(1, width >> 1), max(1, height >> 1), max(1, depth >> 1)
        require(index == len(copies[key]), variant + ': unexpected extra copy event')
        require(payload == request['payload'], variant + ': full mip/depth payload is incomplete')
        require(actual_offset == request['reserved'], variant + ': request omits slice reservations')
        if variant == 'candidate':
            require(actual_offset == minimal_offset, 'candidate reserves unused block rows')
        elif request['block_h'] > 1:
            require(actual_offset > minimal_offset, 'baseline native excess was not reproduced')
        else:
            require(actual_offset == minimal_offset, 'uncompressed baseline control differs')
        result[key[0] + ':' + str(key[1])] = {
            'payload': payload, 'request': actual_offset, 'minimal_request': minimal_offset,
            'copy_events': index, 'source_sha256': readback['source_sha256'],
            'actual_sha256': readback['actual_sha256'], 'readback_equal': True,
            'pitch_step': request['pitch_step'], 'alignment': request['align'],
            'native_format': native_format, 'format_supported': True,
        }
    return {'log_sha256': hashlib.sha256(raw).hexdigest(), 'cases': result}


def compare(baseline, candidate):
    require(set(baseline['cases']) == set(candidate['cases']), 'variant cases differ')
    for key, before in baseline['cases'].items():
        after = candidate['cases'][key]
        for field in ['payload', 'source_sha256', 'actual_sha256', 'copy_events',
                      'pitch_step', 'alignment', 'minimal_request', 'native_format', 'format_supported']:
            require(before[field] == after[field], key + ': variant evidence differs for ' + field)
        require(after['request'] <= before['request'], key + ': reservation grew')
    return {'scope': 'Actual Linux software-Vulkan RD component; not Metal/iOS template qualification',
            'baseline': baseline, 'candidate': candidate, 'status': 'PASS'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline', type=Path, required=True)
    parser.add_argument('--candidate', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    report = compare(inspect(args.baseline, 'baseline'), inspect(args.candidate, 'candidate'))
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    print('Native RD request/copy/readback evidence: PASS (11 layers per variant)')


if __name__ == '__main__':
    main()
