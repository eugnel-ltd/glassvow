# Adapted from robe_export_check_30fps.py: reimport the actual GLB and evaluate all meshes.
# Blender -b --factory-startup --python-exit-code 1 --python this.py -- candidate.glb new-report.json
import json
import sys
from pathlib import Path
import bpy
import numpy as np

model,output=map(Path,sys.argv[sys.argv.index('--')+1:][:2])
assert not output.exists(),output
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene;scene.render.fps=30
bpy.ops.import_scene.gltf(filepath=str(model),merge_vertices=True)
arm=next(o for o in scene.objects if o.type=='ARMATURE')
shapes={b.custom_shape for b in arm.pose.bones if b.custom_shape}
meshes=[o for o in scene.objects if o.type=='MESH' and o not in shapes]
assert meshes and all(o.find_armature()==arm for o in meshes),'Unexpected mesh attachment'

def posed(obj):
    ev=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh()
    local=np.array([v.co[:] for v in mesh.vertices]);matrix=np.array(ev.matrix_world)
    ev.to_mesh_clear()
    return local,local@matrix[:3,:3].T+matrix[:3,3]

masks={}
for obj in meshes:
    weights=[{obj.vertex_groups[g.group].name:g.weight for g in v.groups if g.weight>1e-6} for v in obj.data.vertices]
    assert all(1<=len(w)<=4 and abs(sum(w.values())-1)<.002 for w in weights)
    rest=np.array([v.co[:] for v in obj.data.vertices])
    groups={name:np.array([w.get(name,0)>.5 for w in weights]) for name in ('Chest','Finial','LeftLowerArm','RightLowerArm','LeftFoot','RightFoot')}
    groups['front_ornament_region']=groups['Chest']&(rest[:,1]<-.35)&(rest[:,2]>1.15)
    edges=np.array([e.vertices[:] for e in obj.data.edges]);lengths=np.linalg.norm(rest[edges[:,0]]-rest[edges[:,1]],axis=1)
    masks[obj.name]=(groups,edges,lengths)

action=next(a for a in bpy.data.actions if a.name=='death')
arm.animation_data_create();arm.animation_data.action=action
first,last=map(float,action.frame_range)
times=sorted(set([first,last]+[k/8 for k in range(int(np.ceil(first*8)),int(np.floor(last*8))+1)]))
rows=[]
for frame in times:
    scene.frame_set(int(frame),subframe=frame%1)
    minima={'all':float('inf')};severe=0
    for obj in meshes:
        local,world=posed(obj);assert np.isfinite(world).all()
        groups,edges,lengths0=masks[obj.name]
        lengths=np.linalg.norm(local[edges[:,0]]-local[edges[:,1]],axis=1)
        severe+=int(((lengths0>1e-6)&(lengths>3*lengths0)&(lengths>.03)).sum())
        minima['all']=min(minima['all'],float(world[:,2].min()))
        for name,on in groups.items():
            if on.any():minima[name]=min(minima.get(name,float('inf')),float(world[on,2].min()))
    rows.append({'import_frame':frame,'elapsed_seconds':(frame-first)/30,'severe':severe,'minimum_world_z_m':minima})
report={'model':str(model),'method':'Blender GLB reimport at 30 FPS, actual evaluated world-space vertices of every mesh',
        'meshes':{o.name:len(o.data.vertices) for o in meshes},'death_rows':rows,'final':rows[-1],
        'all_mesh_min_z_m':min(r['minimum_world_z_m']['all'] for r in rows)}
output.write_text(json.dumps(report,indent=2)+'\n')
print('EXPORTED FLOOR',json.dumps({k:v for k,v in report.items() if k!='death_rows'}),flush=True)
assert max(r['severe'] for r in rows)==0,'Exported deformation criterion failed; see report'
assert report['all_mesh_min_z_m']>=-.001,'Exported mesh penetrates floor; see report'
print('EXPORTED FLOOR PASS',flush=True)
