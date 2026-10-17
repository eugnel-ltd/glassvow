"""Preserve recessed8 geometry; replace only death release timing in a separate candidate."""
import ast,json,os,shutil,sys
from pathlib import Path
import bpy,numpy as np
from mathutils import Vector
HERE=Path(__file__).parent;sys.path.insert(0,str(HERE))
import round4_segments as seg,gravewarden_round4_motion as mo,contact_death as cd
LAB=Path('/Users/jamesto/Coding/glassvow/.claude/worktrees/asset-manager-lab')
source=LAB/'mobs/gravewarden/rig-round4-recessed8';out=LAB/'mobs/gravewarden/rig-round4-recessed8-release'
print('GATE',os.getloadavg()[0],shutil.disk_usage(LAB).free/2**30,flush=True)
assert os.getloadavg()[0]<30 and shutil.disk_usage(LAB).free>=100*2**30
assert not out.exists()
bpy.ops.wm.open_mainfile(filepath=str(source/'gravewarden.blend'))
arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');body=next(o for o in bpy.context.scene.objects if o.type=='MESH' and o.find_armature()==arm)
scene=bpy.context.scene;scene.render.fps=30
d=np.load(source/'exact-split.npz');co,faces,lab=d['p'],d['f'],d['lab']
# Landmarks remain the original measured pivots, not the translated gauntlet bounds.
m=json.loads((LAB/'pipeline/gravewarden-recessed8/measure.json').read_text())
base=mo.Body(co,faces,lab,m);clip=cd.build(mo,base)
helper_source=LAB/'pipeline/char_rig.py';tree=ast.parse(helper_source.read_text());funcs=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='q']
from mathutils import Quaternion
import math
h={'Quaternion':Quaternion,'Vector':Vector,'math':math};exec(compile(ast.Module(body=funcs,type_ignores=[]),str(helper_source),'exec'),h)
old=bpy.data.actions.get('death');arm.animation_data.action=None;bpy.data.actions.remove(old)
act=bpy.data.actions.new('death');act.use_fake_user=True;arm.animation_data.action=act
rows=[]
for frame in range(1,50):
    pose=clip.pose(frame)
    for pb in arm.pose.bones:
        pb.rotation_quaternion=h['q'](pb,pose.get(pb.name,[]));pb.keyframe_insert('rotation_quaternion',frame=frame)
    hips=arm.pose.bones['Hips'];hips.location=hips.bone.matrix_local.to_3x3().inverted()@Vector(pose['loc']);hips.keyframe_insert('location',frame=frame)
    scene.frame_set(frame);bpy.context.view_layer.update();ev=body.evaluated_get(bpy.context.evaluated_depsgraph_get());me=ev.to_mesh();low=min((ev.matrix_world@v.co).z for v in me.vertices);ev.to_mesh_clear()
    correction=.002-low;hips.location+=hips.bone.matrix_local.to_3x3().inverted()@Vector((0,0,correction));hips.keyframe_insert('location',frame=frame)
    rows.append({'frame':frame,'correction_m':correction,'elbows':[pose[s+'LowerArm'][0][1] for s in mo.SIDES]})
for layer in act.layers:
    for strip in layer.strips:
        for bag in strip.channelbags:
            for curve in bag.fcurves:
                for key in curve.keyframe_points:key.interpolation='LINEAR'
out.mkdir();arm.animation_data.action=bpy.data.actions['idle'];scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(out/'gravewarden.blend'))
bpy.ops.export_scene.gltf(filepath=str(out/'gravewarden.glb'),export_format='GLB',export_animations=True,export_animation_mode='ACTIONS')
(out/'release.json').write_text(json.dumps({'source':str(source),'geometry':'Unchanged','rows':rows},indent=2)+'\n')
print('RELEASE PATCH DONE',str(out),flush=True)
