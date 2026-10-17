"""Read-only geometry and pivot measurements for the isolated rig redesign."""
import json
import os
from pathlib import Path
import shutil
import bpy
import numpy as np

LAB = Path('/Users/jamesto/Coding/glassvow/.claude/worktrees/asset-manager-lab')
assert shutil.disk_usage(LAB).free >= 100 * 2**30 and os.getloadavg()[0] < 30
for name, variant in [('gravewarden', 'rig-round3-capped2'), ('shade', 'rig-round3-lunge3')]:
    bpy.ops.wm.open_mainfile(filepath=str(LAB / 'mobs' / name / variant / f'{name}.blend'))
    arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    body = next(o for o in bpy.data.objects if o.type == 'MESH' and o.find_armature() == arm)
    me = body.data
    co = np.array([v.co[:] for v in me.vertices])
    labels = np.array([body.vertex_groups[max(v.groups, key=lambda g: g.weight).group].name for v in me.vertices])
    print('CHARACTER', name, 'FPS', bpy.context.scene.render.fps, 'verts', len(co), flush=True)
    print('BONES', json.dumps({b.name: {'head': list(b.head_local), 'tail': list(b.tail_local), 'parent': b.parent.name if b.parent else None} for b in arm.data.bones}))
    print('PARTS', json.dumps({n: {'count': int((labels == n).sum()), 'min': co[labels == n].min(0).tolist(), 'max': co[labels == n].max(0).tolist()} for n in sorted(set(labels))}))
    print('SLICES', json.dumps([{'z': [lo, lo+.1], 'x_quartiles': np.percentile(co[(co[:,2]>=lo)&(co[:,2]<lo+.1), 0], [0,10,25,50,75,90,100]).tolist()} for lo in np.arange(0, co[:,2].max(), .1) if ((co[:,2]>=lo)&(co[:,2]<lo+.1)).any()]))
    print('CLIPS', [(a.name, list(a.frame_range)) for a in bpy.data.actions])
    out = LAB / 'pipeline' / 'rig-mechanics-probe'
    out.mkdir(exist_ok=True)
    me.calc_loop_triangles()
    np.savez_compressed(str(out / f'{name}.npz'), positions=co, triangles=np.array([t.vertices[:] for t in me.loop_triangles]), labels=labels)
    print('DUMP', out / f'{name}.npz', flush=True)
