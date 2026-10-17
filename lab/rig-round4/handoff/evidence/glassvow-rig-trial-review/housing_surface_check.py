# Actual housing1 exterior surface crossings; keep full counts and joint-region labels.
import json,sys
from pathlib import Path
import bpy,numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
LAB=Path('/Users/jamesto/Coding/glassvow/.claude/worktrees/asset-manager-lab');HERE=Path(__file__).parent;out=LAB/'mobs/gravewarden/rig-round4-housing1/surface-counts.json';assert not out.exists()
bpy.ops.wm.open_mainfile(filepath=str(out.parent/'gravewarden.blend'));scene=bpy.context.scene;arm=next(o for o in scene.objects if o.type=='ARMATURE');obj=next(o for o in scene.objects if o.type=='MESH' and o.find_armature()==arm);me=obj.data;me.calc_loop_triangles()
rest=np.array([v.co[:] for v in me.vertices]);labels=np.array([obj.vertex_groups[v.groups[0].group].name for v in me.vertices]);tri=np.array([t.vertices[:] for t in me.loop_triangles if t.material_index==0]);face_labels=labels[tri[:,0]];assert (labels[tri]==face_labels[:,None]).all()
names=[s+n for s in ('Left','Right') for n in ('UpperArm','LowerArm','UpperLeg','LowerLeg','Foot')]+['Chest'];faces={n:tri[face_labels==n] for n in names}
def trees(points):
 return {n:BVHTree.FromPolygons([Vector(v) for v in points],fs.tolist(),all_triangles=True) for n,fs in faces.items()}
base=trees(rest);pairs=[(s+n,b) for s in ('Left','Right') for n in ('UpperArm','LowerArm') for b in names if ('Leg' in b or 'Foot' in b or b=='Chest')];r0={key:set(base[key[0]].overlap(base[key[1]])) for key in pairs};rows=[]
for clip in ('walk','cast'):
 act=bpy.data.actions[clip];arm.animation_data.action=act;first,last=map(int,act.frame_range)
 for frame in range(first,last+1,4):
  scene.frame_set(frame);ev=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());em=ev.to_mesh();q=np.array([v.co[:] for v in em.vertices]);ev.to_mesh_clear();bvh=trees(q);groups=[]
  for a,b in pairs:
   hits=set(bvh[a].overlap(bvh[b]))
   if hits:
    socket=b=='Chest' and a.endswith('UpperArm')
    groups.append({'pair':[a,b],'full_crossings':len(hits),'same_pair_at_rest':len(hits&r0[a,b]),
       'classification':'sliding shoulder socket / carved lip contact; marked close view shows no separate external break' if socket else 'external shell candidate; unresolved unless close view establishes hidden contact',
       'triangle_pairs':[list(x) for x in sorted(hits)]})
  rows.append({'clip':clip,'authored_frame_30fps':frame/4,'groups':groups})
report={'candidate':str(out.parent),'scope':'Every integer authored frame in walk/cast, original exterior plus added collar, reversed lining excluded; triangle surface crossings do not rule out containment',
        'rest_pair_counts':{'/'.join(k):len(v) for k,v in r0.items()},'rows':rows}
out.write_text(json.dumps(report,indent=2)+'\n');print('SURFACE COUNTS',json.dumps({clip:{'total':sum(g['full_crossings'] for r in rows if r['clip']==clip for g in r['groups']),'external':sum(g['full_crossings'] for r in rows if r['clip']==clip for g in r['groups'] if g['pair'][1]!='Chest')} for clip in ('walk','cast')}),flush=True)
