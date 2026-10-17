# Read-only adaptation of robe_export_check_30fps.py: compare the same prop in source, baked and GLB scenes.
# blender -b --factory-startup --python-exit-code 1 --python sovereign_prop_diagnosis.py -- lab-root output.json
import json
import sys
from pathlib import Path
import bpy
import numpy as np

lab, output = map(Path, sys.argv[sys.argv.index('--') + 1:][:2])
assert not output.exists()
models = {
    'source': lab / 'mobs/sovereign/rig-round4-collapse-port1-source/sovereign.blend',
    'baked': lab / 'mobs/sovereign/rig-round4-collapse-port1/sovereign.blend',
    'reimport': lab / 'mobs/sovereign/rig-round4-collapse-port1/sovereign.glb',
    'base_source': lab / 'mobs/sovereign/rig-round3-hem-source/sovereign.blend',
    'base_glb': lab / 'mobs/sovereign/rig-round3-hem/sovereign.glb',
}
tests = [('death', f) for f in (28, 28.125, 28.25, 28.375, 28.5, 28.625, 28.75, 28.875, 29)]
tests += [('attack', 1), ('cast', 1), ('hurt', 1), ('idle', 57.5), ('walk', 16)]

def posed(obj):
    # Same evaluated mesh and matrix_world path as the established export checker.
    ev = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = ev.to_mesh()
    v = np.array([p.co[:] for p in mesh.vertices])
    matrix = np.array(ev.matrix_world)
    ev.to_mesh_clear()
    return v @ matrix[:3, :3].T + matrix[:3, 3]

def curves(action):
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                yield from bag.fcurves

reports = {}
for label, model in models.items():
    if model.suffix == '.blend':
        bpy.ops.wm.open_mainfile(filepath=str(model))
    else:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.context.scene.render.fps = 30
        bpy.ops.import_scene.gltf(filepath=str(model), merge_vertices=True)
    scene = bpy.context.scene
    arm = next(o for o in scene.objects if o.type == 'ARMATURE')
    body = next(o for o in scene.objects if o.type == 'MESH' and o.find_armature() == arm)
    shapes = {b.custom_shape for b in arm.pose.bones if b.custom_shape}
    props = [o for o in scene.objects if o.type == 'MESH' and o is not body and o not in shapes]
    assert len(props) == 1, [o.name for o in props]
    prop = props[0]
    assert prop.parent == arm and prop.parent_type == 'BONE'
    rows = []
    for clip, authored_frame in tests:
        if label.startswith('base') and clip == 'death':
            continue
        action = next(a for a in bpy.data.actions if a.name == clip)
        arm.animation_data.action = action
        seconds = (authored_frame - 1) / 30
        scene_frame = float(action.frame_range[0]) + seconds * scene.render.fps
        scene.frame_set(int(scene_frame), subframe=scene_frame % 1)
        world = posed(prop)
        low = int(world[:, 2].argmin())
        bone = arm.pose.bones[prop.parent_bone]
        rows.append({'clip': clip, 'authored_frame_30fps': authored_frame, 'seconds': seconds,
                     'scene_frame': scene_frame, 'fps': scene.render.fps, 'prop_min_z': float(world[low, 2]),
                     'lowest_vertex_index': low, 'lowest_world_vertex': world[low].tolist(),
                     'world_vertices': world.tolist(), 'prop_matrix_world': np.array(prop.matrix_world).tolist(),
                     'parent_pose_matrix': np.array(bone.matrix).tolist(),
                     'parent_matrix_basis': np.array(bone.matrix_basis).tolist(),
                     'parent_rotation_mode': bone.rotation_mode,
                     'parent_quaternion': list(bone.rotation_quaternion), 'parent_scale': list(bone.scale)})
    keys = []
    death = next(a for a in bpy.data.actions if a.name == 'death')
    centre = float(death.frame_range[0]) + 27.5 / 30 * scene.render.fps
    for curve in curves(death):
        if not any(f'"{n}"' in curve.data_path for n in ('PropPivot', 'RightHand', 'RightLowerArm', 'RightUpperArm', 'RightShoulder', 'UpperChest', 'Chest', 'Spine', 'Hips')):
            continue
        neighbours = [{'frame': float(k.co.x), 'value': float(k.co.y), 'interpolation': k.interpolation}
                      for k in curve.keyframe_points if abs(k.co.x - centre) <= 2 * scene.render.fps / 30]
        keys.append({'path': curve.data_path, 'index': curve.array_index, 'keys': neighbours})
    reports[label] = {'model': str(model), 'prop': prop.name, 'parent_bone': prop.parent_bone,
                      'mesh_vertices': len(prop.data.vertices), 'matrix_parent_inverse': np.array(prop.matrix_parent_inverse).tolist(),
                      'rows': rows, 'nearby_death_keys': keys}
    print('PROP DIAGNOSIS', label, [(r['clip'], r['authored_frame_30fps'], round(r['prop_min_z'], 5)) for r in rows], flush=True)
output.write_text(json.dumps(reports, indent=1) + '\n')
print('PROP DIAGNOSIS SAVED', output, flush=True)
