# Fixed pose/camera before-after of the elbow housing; no candidate writes.
import ast,math,sys,json
from pathlib import Path
import bpy,numpy as np
from mathutils import Vector,Quaternion
HERE=Path(__file__).parent;sys.path.insert(0,str(HERE));import gravewarden_round4_motion as mo
LAB=Path('/Users/jamesto/Coding/glassvow/.claude/worktrees/asset-manager-lab');out=HERE/'housing-close';assert not out.exists();out.mkdir()
d=np.load(LAB/'mobs/gravewarden/rig-round4-recessed8/exact-split.npz');m=json.loads((HERE/'measure.json').read_text());body=mo.Body(d['p'],d['f'],d['lab'],m);pose=mo.clips(body)['walk'].pose(10)
helper=LAB/'pipeline/char_rig.py';tree=ast.parse(helper.read_text());funcs=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='q'];h={'Vector':Vector,'Quaternion':Quaternion,'math':math};exec(compile(ast.Module(body=funcs,type_ignores=[]),str(helper),'exec'),h)
for tag,variant in [('before','rig-round4-recessed8-release-ground'),('after','rig-round4-housing1')]:
 bpy.ops.wm.open_mainfile(filepath=str(LAB/'mobs/gravewarden'/variant/'gravewarden.blend'));scene=bpy.context.scene;arm=next(o for o in scene.objects if o.type=='ARMATURE');arm.animation_data.action=None
 for pb in arm.pose.bones:pb.rotation_quaternion=h['q'](pb,pose.get(pb.name,[]))
 hips=arm.pose.bones['Hips'];hips.location=hips.bone.matrix_local.to_3x3().inverted()@Vector(pose['loc']);bpy.context.view_layer.update()
 scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=800;scene.render.resolution_y=640;scene.render.resolution_percentage=100
 scene.world=bpy.data.worlds.new('HousingClose');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.2,.2,.2,1)
 for loc,energy in [((3,-4,5),700),((-3,-1,3),350)]:
  bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=energy;o.data.size=4;o.rotation_euler=(Vector((0,0,.7))-o.location).to_track_quat('-Z','Y').to_euler()
 bpy.ops.object.camera_add(location=(-3,-4,2));o=bpy.context.object;o.rotation_euler=(Vector((-.35,-.05,.8))-o.location).to_track_quat('-Z','Y').to_euler();o.data.type='ORTHO';o.data.ortho_scale=1.9;scene.camera=o
 scene.render.filepath=str(out/(tag+'.png'));bpy.ops.render.render(write_still=True)
print('HOUSING CLOSE DONE',out,flush=True)
