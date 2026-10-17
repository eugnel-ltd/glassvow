"""Mark full triangle crossings, retain counts, and identify their relation to the measured joints."""
import json,sys,os,shutil,ast,math
from pathlib import Path
import bpy,numpy as np
from mathutils import Vector,Quaternion
from mathutils.bvhtree import BVHTree
HERE=Path(__file__).parent;sys.path.insert(0,str(HERE))
import gravewarden_round4_motion as mo,round4_segments as seg
LAB=Path('/Users/jamesto/Coding/glassvow/.claude/worktrees/asset-manager-lab');source=LAB/'mobs/gravewarden/rig-round4-recessed8'
print('GATE',os.getloadavg()[0],shutil.disk_usage(LAB).free/2**30,flush=True);assert os.getloadavg()[0]<30 and shutil.disk_usage(LAB).free>=100*2**30
out=HERE/'housing-classification';assert not out.exists();out.mkdir()
d=np.load(source/'exact-split.npz');p,f,lab=d['p'],d['f'],d['lab'];m=json.loads((HERE/'measure.json').read_text());body=mo.Body(p,f,lab,m);clips=mo.clips(body)
# Use the unshifted neutral arm alignment. The previous constant walk offset is superseded.
arm_names=[s+n for s in mo.SIDES for n in ('UpperArm','LowerArm')];targets=[s+n for s in mo.SIDES for n in ('UpperLeg','LowerLeg','Foot')]+['Chest']
faces={n:f[lab==seg.PIECES.index(n)] for n in arm_names+targets}
def trees(pose):
    dm=mo.deform(body.bones,pose);return {n:BVHTree.FromPolygons([Vector(v) for v in (p@dm[n][:3,:3].T+dm[n][:3,3])],faces[n].tolist(),all_triangles=True) for n in faces}
rest=trees({});rest_pairs={(a,b):set(rest[a].overlap(rest[b])) for a in arm_names for b in targets}
rows=[]
for name in ('walk','cast'):
 for frame in range(clips[name].frames[0],clips[name].frames[-1]+1):
  pose=clips[name].pose(frame);bvh=trees(pose);groups=[]
  for a in arm_names:
   for b in targets:
    pairs=bvh[a].overlap(bvh[b])
    if not pairs:continue
    marks=[]
    for i,j in pairs:
     ca=p[faces[a][i]].mean(0);cb=p[faces[b][j]].mean(0);side='Left' if a.startswith('Left') else 'Right';sh=np.array(m[side]['shoulder'])
     socket=(b=='Chest' and abs(ca[0]-sh[0])<.065 and abs(cb[0]-sh[0])<.065 and np.hypot(*(ca[1:]-sh[1:]))<.36)
     marks.append({'triangles':[int(i),int(j)],'rest_centres':[ca.tolist(),cb.tolist()],
       'class':'shoulder_socket_candidate' if socket else 'external_shell_candidate','same_pair_at_rest':(i,j) in rest_pairs[a,b]})
    groups.append({'pair':[a,b],'full_count':len(pairs),'same_pairs_at_rest':sum(x['same_pair_at_rest'] for x in marks),'socket_candidates':sum(x['class']=='shoulder_socket_candidate' for x in marks),'crossings':marks})
  rows.append({'clip':name,'frame':frame,'groups':groups})
(out/'full-counts.json').write_text(json.dumps({'scope':'All recorded triangle crossings; joint-region candidates require visual confirmation; no containment proof','rows':rows},indent=2)+'\n')
# Render the worst exterior candidate and the worst shoulder socket count from each clip.
bpy.ops.wm.open_mainfile(filepath=str(source/'gravewarden.blend'));arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');arm.animation_data.action=None
src=LAB/'pipeline/char_rig.py';tree=ast.parse(src.read_text());funcs=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='q'];h={'Vector':Vector,'Quaternion':Quaternion,'math':math};exec(compile(ast.Module(body=funcs,type_ignores=[]),str(src),'exec'),h)
scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=800;scene.render.resolution_y=640;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('JointInspection');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.2,.2,.2,1)
for loc,energy in [((3,-4,5),700),((-3,-1,3),350)]:
 bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=energy;o.data.size=4;o.rotation_euler=(Vector((0,0,.7))-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(-3,-4,2));camera=bpy.context.object;target=Vector((-.35,-.05,.8));camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=1.9;scene.camera=camera
mat=bpy.data.materials.new('Marked harmful-shell candidates');mat.diffuse_color=(1,.03,.01,1);mat.use_nodes=True;bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(1,.03,.01,1);bs.inputs['Emission Color'].default_value=(1,.02,0,1);bs.inputs['Emission Strength'].default_value=.6
socketmat=mat.copy();socketmat.name='Marked socket candidates';socketmat.diffuse_color=(.03,.8,1,1);bs=socketmat.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(.02,.8,1,1);bs.inputs['Emission Color'].default_value=(0,.5,1,1)
for name in ('walk','cast'):
 candidates=[r for r in rows if r['clip']==name];row=max(candidates,key=lambda r:sum(g['full_count']-g['socket_candidates'] for g in r['groups']))
 pose=clips[name].pose(row['frame'])
 for pb in arm.pose.bones:pb.rotation_quaternion=h['q'](pb,pose.get(pb.name,[]))
 arm.pose.bones['Hips'].location=arm.pose.bones['Hips'].bone.matrix_local.to_3x3().inverted()@Vector(pose['loc']);bpy.context.view_layer.update();dm=mo.deform(body.bones,pose);markers=[]
 for g in row['groups']:
  for crossing in g['crossings']:
   for part,centre in zip(g['pair'],crossing['rest_centres']):
    c=dm[part][:3,:3]@np.array(centre)+dm[part][:3,3]
    bpy.ops.mesh.primitive_uv_sphere_add(segments=8,ring_count=4,radius=.012,location=c);o=bpy.context.object;o.data.materials.append(socketmat if crossing['class']=='shoulder_socket_candidate' else mat);markers.append(o)
 scene.render.filepath=str(out/(name+'-f'+str(row['frame'])+'-marked.png'));bpy.ops.render.render(write_still=True)
 for o in markers:bpy.data.objects.remove(o,do_unlink=True)
 print('MARKED',name,row['frame'],flush=True)
print('HOUSING PROBE DONE',str(out),flush=True)
