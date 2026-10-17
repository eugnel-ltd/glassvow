"""Inspect exact exterior triangle intersections at the named walk/cast poses.
Use the preserved source split; no bounding volume is used for the intersection verdict.
Blender -b --factory-startup --python this.py --
"""
import json,sys
from pathlib import Path
import bpy,numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
HERE=Path(__file__).parent;sys.path.insert(0,str(HERE))
import gravewarden_round4_motion as mo,round4_segments as seg
LAB=Path('/Users/jamesto/Coding/glassvow/.claude/worktrees/asset-manager-lab')
source=LAB/'mobs/gravewarden/rig-round4-recessed8';d=np.load(source/'exact-split.npz')
p,f,lab=d['p'],d['f'],d['lab'];m=json.loads((HERE/'measure.json').read_text());body=mo.Body(p,f,lab,m);clips=mo.clips(body)
def shell(name,pose):
    faces=f[lab==seg.PIECES.index(name)];g=mo.deform(body.bones,pose)[name];q=p@g[:3,:3].T+g[:3,3]
    return BVHTree.FromPolygons([Vector(v) for v in q],faces.tolist(),all_triangles=True)
pairs=[('walk',1,'RightUpperLeg','RightUpperArm'),('walk',14,'LeftLowerArm','LeftFoot'),('cast',4,'RightLowerArm','RightFoot')]
rows=[]
for clip,frame,a,b in pairs:
    pose=clips[clip].pose(frame)
    hits=shell(a,pose).overlap(shell(b,pose))
    resthits=shell(a,{}).overlap(shell(b,{}))
    fixes=[]
    for delta in (-8.,-16.):
        trial=dict(pose)
        for side in mo.SIDES:trial[side+'UpperArm']=[(mo.X,pose[side+'UpperArm'][0][1]+delta)]
        trialhits=shell(a,trial).overlap(shell(b,trial))
        fixes.append({'shoulder_delta_deg':delta,'surface_triangle_intersections':len(trialhits),'new_against_rest':len(set(trialhits)-set(resthits))})
    rows.append({'clip':clip,'frame':frame,'pair':[a,b],'surface_triangle_intersections':len(hits),'rest_intersections':len(resthits),'new_against_rest':len(set(hits)-set(resthits)),'local_clearance_trials':fixes,'pose':pose})
print('ACTUAL INTERSECTIONS',json.dumps(rows),flush=True)
(HERE/'clearance-actual.json').write_text(json.dumps(rows,indent=2)+'\n')
# One fixed close camera shows every named worst pose before/after a local shoulder offset.
import ast,math
from mathutils import Quaternion
bpy.ops.wm.open_mainfile(filepath=str(source/'gravewarden.blend'))
arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
arm.animation_data.action=None
src=LAB/'pipeline/char_rig.py';tree=ast.parse(src.read_text());funcs=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='q']
h={'Vector':Vector,'Quaternion':Quaternion,'math':math};exec(compile(ast.Module(body=funcs,type_ignores=[]),str(src),'exec'),h)
scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=640;scene.render.resolution_y=480;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('ClearanceWorld');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.25,.25,.25,1)
for location,energy,size in [((3,-4,5),700,4),((-3,-1,3),350,3)]:
    bpy.ops.object.light_add(type='AREA',location=location);light=bpy.context.object;light.data.energy=energy;light.data.shape='DISK';light.data.size=size;light.rotation_euler=(Vector((0,0,.5))-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(3,-4,2));camera=bpy.context.object;target=Vector((0,-.05,.48));camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=2.5;scene.camera=camera
out=HERE/'clearance-close';assert not out.exists();out.mkdir()
for row in rows:
    selected=min(row['local_clearance_trials'],key=lambda r:(r['new_against_rest'],abs(r['shoulder_delta_deg'])))
    for tag,delta in [('before',0.),('after',selected['shoulder_delta_deg'])]:
        pose=dict(row['pose'])
        for side in mo.SIDES:pose[side+'UpperArm']=[(mo.X,pose[side+'UpperArm'][0][1]+delta)]
        for pb in arm.pose.bones:pb.rotation_quaternion=h['q'](pb,pose.get(pb.name,[]))
        hips=arm.pose.bones['Hips'];hips.location=hips.bone.matrix_local.to_3x3().inverted()@Vector(pose['loc']);bpy.context.view_layer.update()
        scene.render.filepath=str(out/(row['clip']+'-'+str(row['frame'])+'-'+tag+'.png'));bpy.ops.render.render(write_still=True)
print('CLEARANCE CLOSE DONE',str(out),flush=True)

