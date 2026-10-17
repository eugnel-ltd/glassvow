"""Small read-only glTF accessor reader for local geometry inspection."""
import json
import struct
import numpy as np
from pathlib import Path


def load(path):
    data = Path(path).read_bytes()
    offset, document, binary = 12, None, None
    while offset < len(data):
        length, kind = struct.unpack_from('<II', data, offset)
        chunk = data[offset + 8:offset + 8 + length]
        if kind == 0x4e4f534a:
            document = json.loads(chunk)
        elif kind == 0x004e4942:
            binary = chunk
        offset += 8 + length
    def acc(index):
        a = document['accessors'][index]
        view = document['bufferViews'][a['bufferView']]
        dtype = np.dtype({5121: 'u1', 5123: '<u2', 5125: '<u4', 5126: '<f4'}[a['componentType']])
        components = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}[a['type']]
        return np.ndarray((a['count'], components), dtype, buffer=binary, offset=view.get('byteOffset', 0) + a.get('byteOffset', 0), strides=(view.get('byteStride', dtype.itemsize * components), dtype.itemsize)).copy()
    return document, acc

if __name__ == '__main__':
    for name in ('gravewarden', 'shade'):
        doc, acc = load(Path(__file__).parent / f'{name}.glb')
        p = doc['meshes'][0]['primitives'][0]
        at = p['attributes']
        # glTF Y up -> Blender Z up.
        co = acc(at['POSITION'])[:, [0, 2, 1]] * [1, -1, 1]
        weights, joints = acc(at['WEIGHTS_0']), acc(at['JOINTS_0'])
        names = [doc['nodes'][i]['name'] for i in doc['skins'][0]['joints']]
        labels = np.array([names[i] for i in joints[np.arange(len(joints)), weights.argmax(1)]])
        print(name)
        for label in sorted(set(labels)):
            v = co[labels == label]
            print(label, len(v), np.round(v.min(0), 3), np.round(v.max(0), 3), np.round(v.mean(0), 3))
        for z in np.arange(0, co[:, 2].max(), .1):
            v = co[(co[:,2] >= z) & (co[:,2] < z + .1) & (co[:,0] > .5)]
            if len(v): print('RIGHT SLICE', round(z,2), len(v), np.round(v.min(0), 3), np.round(v.max(0), 3), np.round(v.mean(0),3))
