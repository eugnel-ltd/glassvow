# Blender: inspect connected rear cloth regions before changing any skin weights.
import json
from pathlib import Path
import sys

import bpy
import numpy as np

pipeline = Path(__file__).resolve().parent
lane = pipeline.parent
name = sys.argv[sys.argv.index('--') + 1]
assert name in ('duskblade', 'ashwarden')
bpy.ops.wm.open_mainfile(filepath=str(lane / 'chars' / name / 'rig-fitted-weights' / f'{name}.blend'))
arm = next(obj for obj in bpy.data.objects if obj.type == 'ARMATURE')
body = next(obj for obj in bpy.data.objects if obj.type == 'MESH' and obj.find_armature() == arm)
co = np.array([(body.matrix_world @ vertex.co)[:] for vertex in body.data.vertices])
adjacency = [set() for _ in co]
for edge in body.data.edges:
    a, b = edge.vertices
    adjacency[a].add(b)
    adjacency[b].add(a)
rows = []
for height in (.9, 1.1, 1.25, 1.35):
    allowed = co[:, 2] < height
    remaining = set(np.flatnonzero(allowed).tolist())
    components = []
    while remaining:
        pending = [remaining.pop()]
        component = set(pending)
        while pending:
            vertex = pending.pop()
            neighbours = adjacency[vertex] & remaining
            remaining -= neighbours
            component |= neighbours
            pending.extend(neighbours)
        ids = sorted(component)
        if len(ids) < 10:
            continue
        components.append({'vertices': len(ids), 'minimum': co[ids].min(0).tolist(),
                           'maximum': co[ids].max(0).tolist(), 'centroid': co[ids].mean(0).tolist(),
                           'seeds': int(np.count_nonzero((co[ids, 1] > .23) & (co[ids, 2] < .65)))})
    rows.append({'height': height, 'components': sorted(components, key=lambda row: row['vertices'], reverse=True)})
output = lane / 'chars' / name / 'cape-topology-height.json'
assert not output.exists()
output.write_text(json.dumps(rows, indent=2) + '\n')
print('CAPE TOPOLOGY', name, json.dumps(rows), flush=True)
