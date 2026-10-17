"""One bounded housing repair. Preserve death staging and all original candidates.
Bridge the exact moving elbow rim with its original stone UVs. Recess only the harmful
medial right cuff lip. Marked shoulder socket contact remains unchanged.
"""
import ast,json,os,shutil,sys,math
from pathlib import Path
import bpy,numpy as np
from mathutils import Vector,Quaternion
LAB=Path('/Users/jamesto/Coding/glassvow/.claude/worktrees/asset-manager-lab');HERE=Path(__file__).parent;sys.path.insert(0,str(HERE))
import gravewarden_round4_motion as mo,round4_segments as seg
print('GATE',os.getloadavg()[0],shutil.disk_usage(LAB).free/2**30,flush=True);assert os.getloadavg()[0]<30 and shutil.disk_usage(LAB).free>=100*2**30
source=LAB/'mobs/gravewarden/rig-round4-recessed8-release-ground';out=LAB/'mobs/gravewarden/rig-round4-housing1';assert not out.exists()
bpy.ops.wm.open_mainfile(filepath=str(source/'gravewarden.blend'));scene=bpy.context.scene;assert scene.render.fps==120
arm=next(o for o in scene.objects if o.type=='ARMATURE');obj=next(o for o in scene.objects if o.type=='MESH' and o.find_armature()==arm);me=obj.data
m=json.loads((HERE/'measure.json').read_text());data=np.load(LAB/'mobs/gravewarden/rig-round4-recessed8/exact-split.npz');p,f,lab=data['p'],data['f'],data['lab'];base=mo.Body(p,f,lab,m)
# The original shell faces precede the reversed lining. Keep per-corner UVs intact.
outer_count=len(f);outer=list(me.polygons[:outer_count]);uv=me.uv_layers.active
assert all(len(face.vertices)==3 for face in outer)
collar_verts=[];collar_faces=[];collar_uv=[];collar_bones=[];moved=[];housing=[]
for side in mo.SIDES:
    k=seg.PIECES.index(side+'LowerArm');sf=f[lab==k];edges=np.concatenate([sf[:,[0,1]],sf[:,[1,2]],sf[:,[2,0]]]);key,count=np.unique(np.sort(edges,1),axis=0,return_counts=True)
    rim=key[count==1];c=np.array(m[side]['elbow']);r=m[side]['elbow_cut_radius'];original=p[rim]+[0,0,.08]
    radial=np.hypot(original[:,:,1]-c[1],original[:,:,2]-c[2]);keep=(abs(radial-r)<.006).all(1)&(original[:,:,2]<c[2]+.005).all(1)
    # Map exact split vertex positions to the UV on this child's shell.
    lookup={}
    for face in outer:
        if not all(obj.vertex_groups[me.vertices[i].groups[0].group].name==side+'LowerArm' for i in face.vertices):continue
        for li,vi in zip(face.loop_indices,face.vertices):lookup[tuple(np.round(me.vertices[vi].co[:],6))]=tuple(uv.data[li].uv)
    for ia,ib in rim[keep]:
        a,b=p[ia],p[ib];a0=a+[0,0,.08];b0=b+[0,0,.08]
        # Recess the upper edge beneath the fixed cuff. The exterior limb is not scaled.
        topa=c+(a0-c)*.96;topb=c+(b0-c)*.96
        coords=[a,b,topb,topa];n=len(collar_verts);collar_verts.extend(coords);collar_faces.extend([(n,n+1,n+2),(n,n+2,n+3)])
        ua=lookup.get(tuple(np.round(a,6)),(.5,.5));ub=lookup.get(tuple(np.round(b,6)),ua)
        collar_uv.extend([(ua,ub,ub),(ua,ub,ua)]);collar_bones.extend([side+'LowerArm']*4)
# Move the local medial cuff lip out of the right thigh's swept volume. Apply to lining twins too.
for vertex in me.vertices:
    name=obj.vertex_groups[vertex.groups[0].group].name
    q=vertex.co
    if name=='RightUpperArm' and q.z<.67 and q.x>-.67:
        w=min(1.,max(0.,(.67-q.z)/.06))*min(1.,max(0.,(q.x+.67)/.06))
        if w>0:q.x-=.025*w;moved.append(vertex.index)
# The marked shoulder pairs lie at the carved socket seam. Preserve that sliding contact:
# there is no visible exterior break or coplanar flashing in the marked close views. Full
# counts remain in housing-classification/full-counts.json; they are not silently filtered.
# Join a separate collar mesh so the original surface and its UVs remain untouched.
new=bpy.data.meshes.new('Overlapping elbow stone collars');new.from_pydata([list(x) for x in collar_verts],[],collar_faces);new.update();collar=bpy.data.objects.new('Elbow collars',new);bpy.context.collection.objects.link(collar)
new.materials.append(me.materials[0]);layer=new.uv_layers.new(name='UVMap')
for face,coords in zip(new.polygons,collar_uv):
    for li,coord in zip(face.loop_indices,coords):layer.data[li].uv=coord
for side in mo.SIDES:
    vg=collar.vertex_groups.new(name=side+'LowerArm');vg.add([i for i,n in enumerate(collar_bones) if n==side+'LowerArm'],1.,'REPLACE')
bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);collar.select_set(True);bpy.context.view_layer.objects.active=obj;bpy.ops.object.join()
# Preserve existing death action byte-for-byte and its grounded samples. Author the other five
# clips at the source's 120 FPS, using the same neutral alignment in each clip (no walk-only offset).
helper=LAB/'pipeline/char_rig.py';tree=ast.parse(helper.read_text());funcs=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='q'];h={'Vector':Vector,'Quaternion':Quaternion,'math':math};exec(compile(ast.Module(body=funcs,type_ignores=[]),str(helper),'exec'),h)
def fingerprint(action):
 return [[curve.data_path,curve.array_index,[[float(x) for x in key.co] for key in curve.keyframe_points]] for layer in action.layers for strip in layer.strips for bag in strip.channelbags for curve in bag.fcurves]
death_before=fingerprint(bpy.data.actions['death']);clips=mo.clips(base);ground_rows={}
for name in ('idle','walk','attack','cast','hurt'):
    old=bpy.data.actions.get(name)
    if old:arm.animation_data.action=None;bpy.data.actions.remove(old)
    clip=clips[name];act=bpy.data.actions.new(name);act.use_fake_user=True;arm.animation_data_create();arm.animation_data.action=act;rows=[]
    for frame in range(clip.frames[0],clip.frames[-1]+1):
        pose=clip.pose(frame)
        for pb in arm.pose.bones:pb.rotation_quaternion=h['q'](pb,pose.get(pb.name,[]));pb.keyframe_insert('rotation_quaternion',frame=frame*4)
        hips=arm.pose.bones['Hips'];hips.location=hips.bone.matrix_local.to_3x3().inverted()@Vector(pose['loc']);hips.keyframe_insert('location',frame=frame*4)
        scene.frame_set(frame*4);bpy.context.view_layer.update();ev=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh();minimum=min((ev.matrix_world@v.co).z for v in mesh.vertices);ev.to_mesh_clear();correction=.002-minimum
        hips.location+=hips.bone.matrix_local.to_3x3().inverted()@Vector((0,0,correction));hips.keyframe_insert('location',frame=frame*4);rows.append({'frame':frame,'correction_m':correction})
    for layer0 in act.layers:
      for strip in layer0.strips:
       for bag in strip.channelbags:
        for curve in bag.fcurves:
         for key in curve.keyframe_points:key.interpolation='LINEAR'
    ground_rows[name]=rows
assert death_before==fingerprint(bpy.data.actions['death'])
# Remove the old diagnostic crouch; exactly six semantic clips remain.
old=bpy.data.actions.get('crouch')
if old:arm.animation_data.action=None;bpy.data.actions.remove(old)
out.mkdir();arm.animation_data.action=bpy.data.actions['idle'];scene.frame_set(4)
bpy.ops.wm.save_as_mainfile(filepath=str(out/'gravewarden.blend'));bpy.ops.export_scene.gltf(filepath=str(out/'gravewarden.glb'),export_format='GLB',export_animations=True,export_animation_mode='ACTIONS')
(out/'repair.json').write_text(json.dumps({'source':str(source),'collar_triangles':len(collar_faces),'right_medial_lip_vertices':moved,'fixed_shoulder_housing_vertices':housing,'death_keys_unchanged':True,'ground_rows':ground_rows},indent=2)+'\n')
print('HOUSING REPAIR DONE',str(out),len(collar_faces),'collar triangles',flush=True)
