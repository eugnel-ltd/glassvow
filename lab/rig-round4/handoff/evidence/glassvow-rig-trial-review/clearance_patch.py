"""Preserve frozen death and geometry. Add walk/cast trials with local walk arm clearance."""
import ast,json,os,shutil,sys,math
from pathlib import Path
import bpy,numpy as np
from mathutils import Vector,Quaternion
from mathutils.bvhtree import BVHTree
HERE=Path(__file__).parent;sys.path.insert(0,str(HERE))
import gravewarden_round4_motion as mo,round4_segments as seg
LAB=Path('/Users/jamesto/Coding/glassvow/.claude/worktrees/asset-manager-lab')
source=LAB/'mobs/gravewarden/rig-round4-recessed8-release-ground';out=LAB/'mobs/gravewarden/rig-round4-clearance1'
print('GATE',os.getloadavg()[0],shutil.disk_usage(LAB).free/2**30,flush=True)
assert os.getloadavg()[0]<30 and shutil.disk_usage(LAB).free>=100*2**30
assert not out.exists()
bpy.ops.wm.open_mainfile(filepath=str(source/'gravewarden.blend'))
arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');obj=next(o for o in bpy.context.scene.objects if o.type=='MESH' and o.find_armature()==arm)
scene=bpy.context.scene;assert scene.render.fps==120
rest_data=LAB/'mobs/gravewarden/rig-round4-recessed8/exact-split.npz';d=np.load(rest_data);p,f,lab=d['p'],d['f'],d['lab'];m=json.loads((HERE/'measure.json').read_text());body=mo.Body(p,f,lab,m);clips=mo.clips(body)
src=LAB/'pipeline/char_rig.py';tree=ast.parse(src.read_text());funcs=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='q'];h={'Vector':Vector,'Quaternion':Quaternion,'math':math};exec(compile(ast.Module(body=funcs,type_ignores=[]),str(src),'exec'),h)
# Actual exterior shells. Joint fillers are intentionally inside adjoining sculpt pieces.
arm_names=[s+n for s in mo.SIDES for n in ('UpperArm','LowerArm')]
leg_names=[s+n for s in mo.SIDES for n in ('UpperLeg','LowerLeg','Foot')]+['Chest']
def trees(pose):
    matrices=mo.deform(body.bones,pose);result={}
    for name in arm_names+leg_names:
        faces=f[lab==seg.PIECES.index(name)];g=matrices[name];q=p@g[:3,:3].T+g[:3,3]
        result[name]=BVHTree.FromPolygons([Vector(v) for v in q],faces.tolist(),all_triangles=True)
    return result
rest=trees({});baseline={(a,b):set(rest[a].overlap(rest[b])) for a in arm_names for b in leg_names}
reports={}
for name in ('walk','cast'):
    clip=clips[name];act=bpy.data.actions.new(name);act.use_fake_user=True;arm.animation_data_create();arm.animation_data.action=act;rows=[]
    for frame in range(clip.frames[0],clip.frames[-1]+1):
        pose=clip.pose(frame)
        if name=='walk':
            for side in mo.SIDES:pose[side+'UpperArm']=[(mo.X,pose[side+'UpperArm'][0][1]-8.)]
        bvh=trees(pose);hits={}
        for a in arm_names:
            for b in leg_names:
                pairs=set(bvh[a].overlap(bvh[b]))-baseline[(a,b)]
                if pairs:hits[a+'/'+b]=len(pairs)
        for pb in arm.pose.bones:
            pb.rotation_quaternion=h['q'](pb,pose.get(pb.name,[]));pb.keyframe_insert('rotation_quaternion',frame=frame*4)
        hips=arm.pose.bones['Hips'];hips.location=hips.bone.matrix_local.to_3x3().inverted()@Vector(pose['loc']);hips.keyframe_insert('location',frame=frame*4)
        scene.frame_set(frame*4);bpy.context.view_layer.update();ev=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh();height=min((ev.matrix_world@v.co).z for v in mesh.vertices);ev.to_mesh_clear()
        correction=.002-height;hips.location+=hips.bone.matrix_local.to_3x3().inverted()@Vector((0,0,correction));hips.keyframe_insert('location',frame=frame*4)
        rows.append({'frame':frame,'actual_new_surface_crossings':hits,'ground_correction_m':correction})
    for layer in act.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points:key.interpolation='LINEAR'
    reports[name]=rows
    print('ACTUAL CLEARANCE',name,json.dumps([r for r in rows if r['actual_new_surface_crossings']]),flush=True)
# Proposed diagnostic blend only. This action does not establish runtime integration.
# Raw idle/walk mismatch and the closed walk seam are reported separately below.
walk=clips['walk'];idle=mo.stance(mo.vector({}));idle['loc']=(0.,0.,.002)
def walk_pose(frame):
    pose=walk.pose(frame)
    for side in mo.SIDES:pose[side+'UpperArm']=[(mo.X,pose[side+'UpperArm'][0][1]-8.)]
    return pose
def blend(a,b,w):
    out={}
    for n in body.names:
        aa=np.array([d for _,d in a.get(n,[])]);bb=np.array([d for _,d in b.get(n,[])])
        axes=[ax for ax,_ in b.get(n,a.get(n,[]))]
        if len(aa)!=len(bb):
            aa=np.zeros(len(axes)) if not len(aa) else aa;bb=np.zeros(len(axes)) if not len(bb) else bb
        out[n]=[(axis,float(x+(y-x)*w)) for axis,x,y in zip(axes,aa,bb)]
    out['loc']=tuple(np.array(a['loc'])+(np.array(b['loc'])-a['loc'])*w)
    return out
entry=walk_pose(1);exit_pose=walk_pose(33);poses=[]
raw={n:{'idle_angles':[float(d) for _,d in idle.get(n,[])],'walk_entry_angles':[float(d) for _,d in entry.get(n,[])],
        'walk_exit_angles':[float(d) for _,d in exit_pose.get(n,[])]} for n in body.names}
loop_error=max(float(np.linalg.norm(mo.deform(body.bones,entry)[n]-mo.deform(body.bones,exit_pose)[n])) for n in body.names)
assert loop_error<1e-7,'Walk seam changed'
for frame in range(1,9):
    w=(frame-1)/7;w=w*w*(3-2*w);poses.append(blend(idle,entry,w))
poses.extend(walk_pose(frame) for frame in range(1,34))
for frame in range(1,9):
    w=frame/8;w=w*w*(3-2*w);poses.append(blend(exit_pose,idle,w))
act=bpy.data.actions.new('walk_transition');act.use_fake_user=True;arm.animation_data.action=act
for frame,pose in enumerate(poses,1):
    for pb in arm.pose.bones:
        pb.rotation_quaternion=h['q'](pb,pose.get(pb.name,[]));pb.keyframe_insert('rotation_quaternion',frame=frame*4)
    hips=arm.pose.bones['Hips'];hips.location=hips.bone.matrix_local.to_3x3().inverted()@Vector(pose['loc']);hips.keyframe_insert('location',frame=frame*4)
for layer in act.layers:
    for strip in layer.strips:
        for bag in strip.channelbags:
            for curve in bag.fcurves:
                for key in curve.keyframe_points:key.interpolation='LINEAR'
out.mkdir();arm.animation_data.action=bpy.data.actions['idle'];scene.frame_set(4)
bpy.ops.wm.save_as_mainfile(filepath=str(out/'gravewarden.blend'))
bpy.ops.export_scene.gltf(filepath=str(out/'gravewarden.glb'),export_format='GLB',export_animations=True,export_animation_mode='ACTIONS')
(out/'actual-clearance.json').write_text(json.dumps({'source':str(source),'walk_shoulder_delta_deg':-8,'geometry':'Unchanged','death':'Unchanged','rows':reports,
 'transition':'Proposed diagnostic 8-frame blend; no verified runtime blend integration','raw_endpoint_angles':raw,'walk_loop_matrix_error':loop_error},indent=2)+'\n')
print('CLEARANCE PATCH DONE',str(out),flush=True)
