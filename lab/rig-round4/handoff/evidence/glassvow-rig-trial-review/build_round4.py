"""Build an isolated rigid Gravewarden trial. Preserve all source and selected candidates.
Run with Blender --background --factory-startup --python-exit-code 1 --python this.py -- spec.json.
"""
import ast
import json
import math
import os
from pathlib import Path
import shutil
import sys

import bpy
import numpy as np
from mathutils import Vector, Quaternion

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import round4_segments as seg
import gravewarden_round4_motion as mo
import round4_death_preview as preview
if os.environ.get('GV_RECESSED_REACH') == '1':
    import contact_death as preview

LAB = Path('/Users/jamesto/Coding/glassvow/.claude/worktrees/asset-manager-lab')
spec = json.loads(Path(sys.argv[sys.argv.index('--')+1]).read_text())
OUT = Path(spec['out_dir'])
assert not OUT.exists(), 'Preserve an existing trial'
load,free=os.getloadavg()[0],shutil.disk_usage(LAB).free
print('RESOURCE GATE',json.dumps({'path':str(LAB),'load_1m':load,'free_bytes':free,'free_GiB':free/2**30}),flush=True)
assert load<30 and free>=100*2**30, (str(LAB),load,free,free/2**30)
source=LAB/'pipeline/char_rig.py'
module=ast.parse(source.read_text(),filename=str(source)); module.body.pop()
h={'__file__':str(source)}; exec(compile(module,str(source),'exec'),h)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
body=h['import_glb'](spec['body_glb']); h['fit'](body,2.4)
me=body.data; me.calc_loop_triangles()
p=np.array([v.co[:] for v in me.vertices]); tris=np.array([t.vertices[:] for t in me.loop_triangles]); m=seg.measure(p,tris)
uvl=me.uv_layers.active
# Per-corner position, UV and smooth normal; clip interpolation preserves all three.
polys=[]
for t in me.loop_triangles:
    polys.append(np.array([list(me.vertices[me.loops[l].vertex_index].co)+list(uvl.data[l].uv)+list(me.corner_normals[l].vector) for l in t.loops],float))
cut_counts={}
def cut(polys,name,sdf,region):
    out=[]; count=0
    for poly in polys:
        c=poly[:,:3].mean(0)
        values=np.array([sdf(v[:3]) for v in poly])
        if not region(c[None])[0] or not (values.min() < -1e-8 and values.max() > 1e-8):
            out.append(poly); continue
        count+=1
        for sign in (-1,1):
            q=[]
            for i,a in enumerate(poly):
                b=poly[(i+1)%len(poly)]; fa,fb=values[i],values[(i+1)%len(poly)]
                if sign*fa>=-1e-9: q.append(a)
                if fa*fb < -1e-16:
                    lo,hi=0.,1.
                    for _ in range(35):
                        mid=(lo+hi)/2; fm=sdf((a+(b-a)*mid)[:3])
                        if (fm>0)==(fa>0): lo=mid
                        else: hi=mid
                    q.append(a+(b-a)*(lo+hi)/2)
            for i in range(1,len(q)-1):
                tri=np.array([q[0],q[i],q[i+1]])
                if np.linalg.norm(np.cross(tri[1,:3]-tri[0,:3],tri[2,:3]-tri[0,:3]))>1e-12: out.append(tri)
    cut_counts[name]=count
    return out
for name,point,normal,region in seg.joint_planes(m):
    if name.endswith((' hip',' knee')):
        continue  # The old planar cuts become coaxial cuff/socket boundaries below.
    point,normal=np.array(point),np.array(normal)
    polys=cut(polys,name,lambda p,point=point,normal=normal:float((p-point)@normal),region)
for side,d in m.items():
    lx,ly=d['leg_axis'];lr=d['leg_radius']
    for joint,z,r in [('hip',seg.HIP_Z,seg.HIP_SOCKET_R),('knee',seg.KNEE_Z,seg.KNEE_CUFF_R)]:
        polys=cut(polys,side+' '+joint+' cuff',lambda p,ly=ly,z=z,r=r:float(np.hypot(p[1]-ly,p[2]-z)-r),lambda c,lx=lx,ly=ly,lr=lr,z=z:(np.hypot(c[:,0]-lx,c[:,1]-ly)<lr+.05)&(c[:,2]<z)&(c[:,2]>z-.2))
for side,d in m.items():
    ey,ez=d['elbow'][1:]; radius=d['elbow_cut_radius']; sg=d['sign']
    polys=cut(polys,side+' elbow cylinder',lambda p,ey=ey,ez=ez,r=radius:float(np.hypot(p[1]-ey,p[2]-ez)-r),lambda c,sg=sg,ez=ez:(c[:,0]*sg>.5)&(c[:,2]<ez)&(c[:,2]>ez-.4))
# The front door is excluded from the waist bisect.
polys=cut(polys,'rear waist ledge',lambda p:float(p[2]-seg.WAIST_Z),lambda c:(c[:,1]>seg.WAIST_FRONT_Y)&(np.abs(c[:,0])<.56)&(abs(c[:,2]-seg.WAIST_Z)<.12))
polys=cut(polys,'concealed anterior waist boundary',lambda p:float(p[1]-seg.WAIST_FRONT_Y),lambda c:(c[:,2]<seg.WAIST_Z)&(c[:,2]>.5)&(np.abs(c[:,0])<.56))
polys=cut(polys,'finial base',lambda p:float(p[2]-seg.FINIAL_Z),lambda c:(c[:,2]>2)&(np.abs(c[:,0])<.2))
arr=np.array(polys); points=arr[:,:,:3].reshape(-1,3); fs=np.arange(len(points)).reshape(-1,3)
lab=seg.classify(m,arr[:,:,:3].mean(1))
# Join coincident positions for adjacency cleanup, then split corners again for rigid weights.
unique,inv=np.unique(np.round(points,7),axis=0,return_inverse=True)
lab,moved=seg.clean(lab,inv[fs],small=12)
if os.environ.get('GV_RECESSED_REACH') == '1':
    # Minimal geometry revision: translate the complete rigid gauntlet by 8 cm, without scale.
    # The shoulder, elbow pivot, cathedral and all UV coordinates stay fixed.
    for side in mo.SIDES:
        mask=lab==seg.PIECES.index(side+'LowerArm')
        arr[mask,:,2]-=.08
    points=arr[:,:,:3].reshape(-1,3)
    unique,inv=np.unique(np.round(points,7),axis=0,return_inverse=True)
mesh=bpy.data.meshes.new('ArticulatedStone'); mesh.from_pydata(points.tolist(),[],fs.tolist()); mesh.update()
for material in me.materials: mesh.materials.append(material)
body.data=mesh
uv=mesh.uv_layers.new(name='UVMap')
for i,v in enumerate(arr[:,:,3:5].reshape(-1,2)): uv.data[i].uv=v
norm=arr[:,:,5:8].reshape(-1,3); norm/=np.maximum(np.linalg.norm(norm,axis=1)[:,None],1e-9)
for f in mesh.polygons:f.use_smooth=True
mesh.normals_split_custom_set(norm.tolist())
bones=mo.skeleton(m)
J={}; chain=[]
for n,head,tail,parent in bones:
    J[n+'h'],J[n+'t']=Vector(head),Vector(tail); chain.append((n,n+'h',n+'t',parent))
arm=h['build_armature'](J,chain)
for name in seg.PIECES: body.vertex_groups.new(name=name)
for k,name in enumerate(seg.PIECES):
    ids=fs[lab==k].ravel().tolist()
    if ids:body.vertex_groups[name].add(ids,1.,'REPLACE')
mod=body.modifiers.new('Rigid joints','ARMATURE'); mod.object=arm; body.parent=arm
# Inward stone faces cover the exposed back of the original fused shell without spanning gaps.
cap_source=LAB/'pipeline/gravewarden_round3_cap.py'
cap_ast=ast.parse(cap_source.read_text());cap_functions=[n for n in cap_ast.body if isinstance(n,ast.FunctionDef) and n.name in ('base_image','dark_block')]
cap_scope={'np':np};exec(compile(ast.Module(body=cap_functions,type_ignores=[]),str(cap_source),'exec'),cap_scope)
stone_box,stone_swatch=cap_scope['dark_block'](cap_scope['base_image'](mesh.materials[0]))
dark=mesh.materials[0].copy();dark.name='Recessed original stone';dark.use_backface_culling=True
mesh.materials.append(dark)
import bmesh
bm=bmesh.new();bm.from_mesh(mesh);dl=bm.verts.layers.deform.verify()
inner={v:bm.verts.new(v.co) for v in list(bm.verts)}
for old,new in inner.items():
    for group,weight in old[dl].items():new[dl][group]=weight
outer=list(bm.faces)
bm_uv=bm.loops.layers.uv.active
u0,v0,du,dv=stone_box
for f in outer:
    nf=bm.faces.new([inner[v] for v in reversed(f.verts)]);nf.material_index=len(mesh.materials)-1
    for loop,coord in zip(nf.loops,[(u0,v0),(u0+du,v0),(u0+du/2,v0+dv)]):loop[bm_uv].uv=coord
bm.to_mesh(mesh);bm.free();mesh.update()
# Joint drums and balls are separate rigid pieces joined into the same skinned mesh.
fillers=[]
def stone_uv(obj):
    layer=obj.data.uv_layers.active or obj.data.uv_layers.new(name='UVMap')
    for loop in layer.data:loop.uv=(u0+du/2,v0+dv/2)
    for face in obj.data.polygons:face.use_smooth=True
for name,kind,c,r,parent,span in mo.fillers(mo.Body(unique,inv[fs],lab,m).m):
    if kind=='ball':
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,radius=r,location=c)
    else:
        bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=r,depth=abs(span[1]-span[0]),location=((span[0]+span[1])/2,c[1],c[2]),rotation=(0,math.pi/2,0))
    obj=bpy.context.object;obj.name=name;h['only']([obj]);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    obj.data.materials.append(dark);stone_uv(obj);vg=obj.vertex_groups.new(name=parent);vg.add(list(range(len(obj.data.vertices))),1,'REPLACE');fillers.append(obj)
if os.environ.get('GV_RECESSED_REACH') == '1':
    for side,d in m.items():
        ex,ey,ez=d['elbow']
        radius=d['elbow_drum_radius']*.72
        bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=radius,depth=.16,location=(ex,ey,ez-.18))
        obj=bpy.context.object;obj.name=side+'RecessedForearm';h['only']([obj]);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
        obj.data.materials.append(dark);stone_uv(obj);vg=obj.vertex_groups.new(name=side+'LowerArm');vg.add(list(range(len(obj.data.vertices))),1,'REPLACE');fillers.append(obj)
# Small recessed connector under the existing rear moulding; it cannot cover an exterior tear.
bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,location=(0,.045,.74));obj=bpy.context.object;obj.scale=(.34,.13,.105);h['only']([obj]);bpy.ops.object.transform_apply(location=True,scale=True)
obj.data.materials.append(dark);stone_uv(obj);vg=obj.vertex_groups.new(name='Hips');vg.add(list(range(len(obj.data.vertices))),1,'REPLACE');fillers.append(obj)
h['only']([body]+fillers);bpy.context.view_layer.objects.active=body;bpy.ops.object.join()
# Recompute contact from the exact built split. A separate action repeats the first crouch
# unchanged, so the capture isolates joint geometry from the new spent-pose motion.
base=mo.Body(unique,inv[fs],lab,m)
cl={'idle':mo.Clip(base,[(1,{}),(2,{})]),'death':preview.build(mo,base)}
if os.environ.get('GV_RECESSED_REACH') == '1':
    other=mo.clips(base)
    clearance={}
    volumes=mo.Volumes(base)
    for name in ('attack','cast'):
        rows=[]
        for frame in range(other[name].frames[0],other[name].frames[-1]+1):
            pose=other[name].pose(frame)
            hit={'/'.join(pair):depth for pair,depth in volumes.collisions(pose).items() if 'Arm' in '/'.join(pair)}
            rows.append({'frame':frame,'arm_collisions_m':hit})
        clearance[name]=rows
    print('REACH CLEARANCE',json.dumps({name:max((depth for row in rows for depth in row['arm_collisions_m'].values()),default=0.) for name,rows in clearance.items()}),flush=True)
cl['crouch']=mo.Clip(base,[(1,dict(P=45,t=-33,k=58,cx=6,arm=(-37,-48))),
                            (2,dict(P=45,t=-33,k=58,cx=6,arm=(-37,-48)))])
clips={n:cl[n] for n in ('idle','crouch','death')}
scene=bpy.context.scene;scene.render.fps=30
acts=[];fk_errors=[];timelines={}
rest=np.array([v.co[:] for v in body.data.vertices]);owner=np.array([body.vertex_groups[v.groups[0].group].name for v in body.data.vertices])
for name,clip in clips.items():
    act=bpy.data.actions.new(name);act.use_fake_user=True;arm.animation_data_create();arm.animation_data.action=act
    rows=[]
    for frame in range(clip.frames[0],clip.frames[-1]+1):
        pose=clip.pose(frame)
        for pb in arm.pose.bones:
            pb.rotation_mode='QUATERNION';pb.rotation_quaternion=h['q'](pb,pose.get(pb.name,[]));pb.keyframe_insert('rotation_quaternion',frame=frame)
        hips=arm.pose.bones['Hips'];hips.location=hips.bone.matrix_local.to_3x3().inverted()@Vector(pose['loc']);hips.keyframe_insert('location',frame=frame)
        scene.frame_set(frame);bpy.context.view_layer.update()
        dm=mo.deform(bones,pose);expected=np.empty_like(rest)
        for bone in np.unique(owner):
            on=owner==bone;expected[on]=rest[on]@dm[bone][:3,:3].T+dm[bone][:3,3]
        ev=body.evaluated_get(bpy.context.evaluated_depsgraph_get());evmesh=ev.to_mesh();actual=np.array([v.co[:] for v in evmesh.vertices]);ev.to_mesh_clear()
        error=float(np.linalg.norm(actual-expected,axis=1).max());fk_errors.append(error)
        # Set the true built surface on the floor, without a separate bake job.
        correction=.002-float(actual[:,2].min());hips.location+=hips.bone.matrix_local.to_3x3().inverted()@Vector((0,0,correction));hips.keyframe_insert('location',frame=frame)
        rows.append({'frame':frame,'source_root':list(pose['loc']),'bake_correction_m':correction,'numpy_blender_max_m':error})
    for layer in act.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points:key.interpolation='LINEAR'
    acts.append(act);timelines[name]=rows
assert max(fk_errors)<.001, max(fk_errors)
# char_rig initialisation creates OUT. The entry guard proved it did not exist before this job.
assert OUT.is_dir() and not any(OUT.iterdir()), 'Unexpected output in this trial'
arm.animation_data.action=acts[0];scene.frame_set(1);bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'gravewarden.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'gravewarden.glb'),export_format='GLB',export_animations=True,export_animation_mode='ACTIONS')
(OUT/'build.json').write_text(json.dumps({'cuts':cut_counts,'moved_small_faces':moved,'bones':[b[0] for b in bones],'numpy_blender_max_m':max(fk_errors),'timeline':timelines},indent=2)+'\n')
if os.environ.get('GV_RECESSED_REACH') == '1':
    (OUT/'reach-clearance.json').write_text(json.dumps(clearance,indent=2)+'\n')
    (OUT/'contact-events.json').write_text(json.dumps(cl['death'].contact_events,indent=2)+'\n')
np.savez(OUT/'exact-split.npz',p=unique,f=inv[fs],lab=lab)
print('ROUND4 FIRST PREVIEW',str(OUT),'FK max metres',max(fk_errors),flush=True)
