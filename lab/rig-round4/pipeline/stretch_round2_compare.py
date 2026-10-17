# Compare exported bone rotation and scale samples. Ground translation may change.
import json
from pathlib import Path
import struct
import sys

import numpy as np


def load(path):
    data = Path(path).read_bytes()
    length, kind = struct.unpack_from('<II', data, 12)
    document = json.loads(data[20:20 + length])
    offset = 20 + length
    size, kind = struct.unpack_from('<II', data, offset)
    binary = data[offset + 8:offset + 8 + size]
    def values(index):
        accessor = document['accessors'][index]
        view = document['bufferViews'][accessor['bufferView']]
        assert accessor['componentType'] == 5126
        count = {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4}[accessor['type']]
        return np.ndarray((accessor['count'], count), dtype='<f4', buffer=binary,
                          offset=view.get('byteOffset', 0) + accessor.get('byteOffset', 0),
                          strides=(view.get('byteStride', count * 4), 4)).copy()
    node_names = [node.get('name') for node in document['nodes']]
    assert len(node_names) == len(set(node_names)), 'Duplicate node names'
    clips = {}
    for animation in document['animations']:
        assert animation['name'] not in clips, 'Duplicate animation names'
        channels = {}
        for channel in animation['channels']:
            target = channel['target']
            if target['path'] == 'translation' and document['nodes'][target['node']]['name'] == 'Hips':
                continue
            sampler = animation['samplers'][channel['sampler']]
            key = document['nodes'][target['node']]['name'], target['path']
            assert key not in channels, 'Duplicate channels'
            channels[key] = values(sampler['input']), values(sampler['output']), sampler.get('interpolation', 'LINEAR')
        clips[animation['name']] = channels
    return clips


first, second = map(load, sys.argv[1:])
assert first.keys() == second.keys()
for clip, channels in first.items():
    assert channels.keys() == second[clip].keys(), clip
    for key, (times, values, interpolation) in channels.items():
        other_times, other_values, other_interpolation = second[clip][key]
        assert interpolation == other_interpolation, (clip, key, 'interpolation')
        assert times.shape == other_times.shape and np.allclose(times, other_times, atol=1e-6), (clip, key, 'times')
        assert values.shape == other_values.shape and np.allclose(values, other_values, atol=2e-6), (clip, key, 'values')
print('BONE ROTATION AND SCALE PASS', len(first), 'clips')
