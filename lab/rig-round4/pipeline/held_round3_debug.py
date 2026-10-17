"""List the edges a clip stretches past the batch threshold (3x and 3 cm) at one frame. No renders."""
import json
from pathlib import Path
import sys

import bpy
import numpy as np

args = sys.argv[sys.argv.index('--') + 1:]
spec = json.loads(Path(args[0]).read_text())
clip, frame = args[1], float(args[2])
out = Path(spec['out_dir'])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(out / (spec['name'] + '.glb')), merge_vertices=True)
arm = next(obj for obj in bpy.data.objects if obj.type == 'ARMATURE')
body = next(obj for obj in bpy.data.objects if obj.type == 'MESH' and obj.find_armature() == arm)
rest = np.array([v.co[:] for v in body.data.vertices])
edges = np.array([e.vertices[:] for e in body.data.edges])
arm.animation_data.action = bpy.data.actions[clip]
bpy.context.scene.frame_set(int(frame), subframe=frame % 1)
evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
mesh = evaluated.to_mesh()
posed = np.array([evaluated.matrix_world @ v.co for v in mesh.vertices])
evaluated.to_mesh_clear()
before = np.linalg.norm(rest[edges[:, 0]] - rest[edges[:, 1]], axis=1)
after = np.linalg.norm(posed[edges[:, 0]] - posed[edges[:, 1]], axis=1)
bad = np.flatnonzero((before > 1e-6) & (after > before * 3) & (after > .03))
names = {g.index: g.name for g in body.vertex_groups}
print('stretched', len(bad))
for k in bad[np.argsort(-(after[bad] / before[bad]))][:10]:
    print(f'ratio {after[k] / before[k]:.2f} rest {before[k]:.4f}m')
    for v in edges[k]:
        groups = sorted(((names[g.group], round(g.weight, 2)) for g in body.data.vertices[v].groups), key=lambda t: -t[1])
        print('   ', np.round(rest[v] / 1.8, 3).tolist(), groups)
