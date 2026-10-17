# Blender read-only: compare original and repaired source skin, recording each changed clip's worst pose.
# blender -b --python-exit-code 1 --python robe_clip_diff.py -- old.blend new.blend output.json
import json
import sys
from pathlib import Path
import bpy
import numpy as np
old, new, output = map(Path, sys.argv[sys.argv.index('--') + 1:][:3])
assert not output.exists()
clips = ('idle', 'walk', 'attack', 'cast', 'hurt')
def sample(path):
    bpy.ops.wm.open_mainfile(filepath=str(path))
    scene = bpy.context.scene
    arm = next(o for o in scene.objects if o.type == 'ARMATURE')
    body = next(o for o in scene.objects if o.type == 'MESH' and o.find_armature() == arm)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.select_all(action='DESELECT')
    body.select_set(True)
    bpy.ops.object.vertex_group_limit_total(limit=4)
    bpy.ops.object.vertex_group_normalize_all(lock_active=False)
    rows = {}
    for clip in clips:
        action = bpy.data.actions[clip]
        arm.animation_data.action = action
        first, last = map(int, action.frame_range)
        values = []
        for f in range(first, last + 1):
            scene.frame_set(f)
            ev = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
            mesh = ev.to_mesh()
            co = np.array([v.co[:] for v in mesh.vertices])
            m = np.array(ev.matrix_world)
            values.append(co @ m[:3, :3].T + m[:3, 3])
            ev.to_mesh_clear()
        rows[clip] = (first, scene.render.fps, np.array(values))
    return rows
before, after = sample(old), sample(new)
report = {}
for clip in clips:
    first, fps, a = before[clip]
    assert (first, fps) == after[clip][:2]
    b = after[clip][2]
    assert a.shape == b.shape
    distances = np.linalg.norm(b - a, axis=2)
    f, vertex = np.unravel_index(distances.argmax(), distances.shape)
    report[clip] = {'max_m': float(distances.max()), 'p99_m': float(np.percentile(distances, 99)),
                    'vertices_over_1cm': int((distances.max(0) > .01).sum()),
                    'worst_source_frame': int(first + f), 'worst_seconds': float(f / fps),
                    'worst_vertex': int(vertex), 'fps': fps}
output.write_text(json.dumps({'old': str(old), 'new': str(new), 'clips': report}, indent=2) + '\n')
print('CLIP DISPLACEMENT', json.dumps(report), flush=True)
