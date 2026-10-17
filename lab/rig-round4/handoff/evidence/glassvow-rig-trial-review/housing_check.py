# Reuse the established Blender reimport/evaluated-mesh check on all six semantic clips.
import json,sys
from pathlib import Path
import bpy,numpy as np
model,output=map(Path,sys.argv[sys.argv.index('--')+1:][:2]);assert not output.exists()
bpy.ops.wm.read_factory_settings(use_empty=True);scene=bpy.context.scene;scene.render.fps=30
bpy.ops.import_scene.gltf(filepath=str(model),merge_vertices=True)
arm=next(o for o in scene.objects if o.type=='ARMATURE');shapes={b.custom_shape for b in arm.pose.bones if b.custom_shape};meshes=[o for o in scene.objects if o.type=='MESH' and o not in shapes]
assert meshes and all(o.find_armature()==arm for o in meshes)
rest={}
for o in meshes:
 p=np.array([v.co[:] for v in o.data.vertices]);e=np.array([x.vertices[:] for x in o.data.edges]);rest[o.name]=(e,np.linalg.norm(p[e[:,0]]-p[e[:,1]],axis=1))
 weights=[{o.vertex_groups[g.group].name:g.weight for g in v.groups if g.weight>1e-6} for v in o.data.vertices];assert all(1<=len(w)<=4 and abs(sum(w.values())-1)<.002 for w in weights)
reports=[]
for name in ('idle','walk','attack','cast','hurt','death'):
 action=next(a for a in bpy.data.actions if a.name==name);arm.animation_data_create();arm.animation_data.action=action;first,last=map(float,action.frame_range)
 times=sorted(set([first,last]+[k/8 for k in range(int(np.ceil(first*8)),int(np.floor(last*8))+1)]));rows=[]
 for frame in times:
  scene.frame_set(int(frame),subframe=frame%1);minimum=float('inf');severe=0
  for o in meshes:
   ev=o.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh();p=np.array([v.co[:] for v in mesh.vertices]);matrix=np.array(ev.matrix_world);world=p@matrix[:3,:3].T+matrix[:3,3];ev.to_mesh_clear();assert np.isfinite(world).all();e,l0=rest[o.name];ll=np.linalg.norm(p[e[:,0]]-p[e[:,1]],axis=1);severe+=int(((l0>1e-6)&(ll>3*l0)&(ll>.03)).sum());minimum=min(minimum,float(world[:,2].min()))
  rows.append({'frame':frame,'severe':severe,'minimum_world_z_m':minimum})
 report={'clip':name,'samples':len(rows),'max_severe':max(x['severe'] for x in rows),'min_world_z_m':min(x['minimum_world_z_m'] for x in rows),'rows':rows};reports.append(report)
 print('EXPORTED SIX',json.dumps({k:v for k,v in report.items() if k!='rows'}),flush=True)
output.write_text(json.dumps({'model':str(model),'method':'Blender GLB reimport, all evaluated mesh vertices, 30 FPS integer and eighth frames','reports':reports},indent=2)+'\n')
assert all(r['max_severe']==0 for r in reports),'Severe deformation; see report'
assert all(r['min_world_z_m']>=-.001 for r in reports),'Floor penetration; see report'
print('ALL SIX EXPORTED PASS',flush=True)
