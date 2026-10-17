# Read-only GLB check: reimport and measure deformation/contact at sixteenths of an imported scene frame; includes midpoints between repaired eighth-frame keys.
# Blender -b --factory-startup --python-exit-code 1 --python robe_export_check.py -- candidate.glb output.json
import json
import sys
from pathlib import Path

import bpy
import numpy as np

model, output, solve_path = map(Path, sys.argv[sys.argv.index('--') + 1:][:3])
solve = np.load(solve_path)
assert not output.exists(), output
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = 30
bpy.ops.import_scene.gltf(filepath=str(model), merge_vertices=True)
arm = next(o for o in scene.objects if o.type == 'ARMATURE')
body = next(o for o in scene.objects if o.type == 'MESH' and o.find_armature() == arm)
shapes = {b.custom_shape for b in arm.pose.bones if b.custom_shape}
props = [o for o in scene.objects if o.type == 'MESH' and o is not body and o not in shapes]
assert props and all(o.parent == arm and o.parent_type == 'BONE' for o in props), 'Invalid prop attachment'
rest = np.array([v.co[:] for v in body.data.vertices])
edges = np.array([e.vertices[:] for e in body.data.edges])
lengths0 = np.linalg.norm(rest[edges[:, 0]] - rest[edges[:, 1]], axis=1)
weights = [{body.vertex_groups[g.group].name: g.weight for g in v.groups if g.weight > 1e-6} for v in body.data.vertices]
assert all(1 <= len(w) <= 4 and abs(sum(w.values()) - 1) < .002 for w in weights)
region_keys = {'skirt': ('Skirt',), 'hands': ('Hand', 'LowerArm'), 'head': ('Head', 'Neck'),
               'torso': ('Spine', 'Chest'), 'shoulders': ('Shoulder', 'UpperArm')}
regions = {region: np.array([sum(value for name, value in w.items() if any(k in name for k in keys)) > .5
                            for w in weights]) for region, keys in region_keys.items()}

def posed(obj):
    ev = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = ev.to_mesh()
    v = np.array([p.co[:] for p in mesh.vertices])
    matrix = np.array(ev.matrix_world)
    ev.to_mesh_clear()
    return v, v @ matrix[:3, :3].T + matrix[:3, 3]

# Match the exact three palm-material vertices and shaft-material vertex in imported rest space.
arm.data.pose_position = 'REST'; bpy.context.view_layer.update()
body_rest = posed(body)[1]
prop = props[0]
prop_rest = posed(prop)[1]
base_rest = np.load(Path(__file__).with_name('rest-sovereign.npz'))['verts']
palm_points = base_rest[solve['grip_face']]
palm_ids = np.array([np.linalg.norm(body_rest-q,axis=1).argmin() for q in palm_points])
assert np.max(np.linalg.norm(body_rest[palm_ids]-palm_points,axis=1))<1e-4
shaft_expected = solve['prop_verts'][int(solve['shaft_grip_vertex'])]
shaft_vertex = int(np.linalg.norm(prop_rest-shaft_expected,axis=1).argmin())
assert np.linalg.norm(prop_rest[shaft_vertex]-shaft_expected)<1e-4
shaft_local = np.array(prop.data.vertices[shaft_vertex].co[:])
arm.data.pose_position = 'POSE'; bpy.context.view_layer.update()
reports = []
for action in bpy.data.actions:
    arm.animation_data_create()
    arm.animation_data.action = action
    first, last = map(float, action.frame_range)
    # Include the exact endpoint as well as the same eighth-frame grid used by check_deformation.py.
    times = sorted(set([first, last] + [k / 16 for k in range(int(np.ceil(first * 16)), int(np.floor(last * 16)) + 1)]))
    integer, subframe, bad_rows = [], [], []
    for f in times:
        scene.frame_set(int(f), subframe=f % 1)
        v, world = posed(body)
        assert np.isfinite(v).all()
        lengths = np.linalg.norm(v[edges[:, 0]] - v[edges[:, 1]], axis=1)
        bad = np.nonzero((lengths0 > 1e-6) & (lengths > 3 * lengths0) & (lengths > .03))[0]
        prop_world = [posed(o)[1] for o in props]
        prop_min = min(float(v[:, 2].min()) for v in prop_world)
        shaft_point = (np.array(prop.matrix_world) @ np.r_[shaft_local,1])[:3]
        palm_centre = world[palm_ids].mean(0)
        grip_gap = float(np.linalg.norm(palm_centre-shaft_point))
        hand_bone = arm.pose.bones['RightHand']
        hand_matrix = np.array(arm.matrix_world) @ np.array(hand_bone.matrix)
        shaft_in_hand = (np.linalg.inv(hand_matrix) @ np.r_[shaft_point,1])[:3]
        near_floor = np.abs(world[:, 2]) <= .01
        row = {'import_frame': f, 'elapsed_seconds': (f - first) / scene.render.fps,
               'authored_frame_30fps': 1 + (f - first) * 30 / scene.render.fps,
               'same_shaft_vertex': int(shaft_vertex), 'material_grip_barycentre_error_m':grip_gap, 'same_shaft_point_in_hand_frame':shaft_in_hand.tolist(), 'prop_object_scale':list(prop.scale), 'palm_material_world':palm_centre.tolist(), 'shaft_material_world':shaft_point.tolist(), 'severe': len(bad), 'body_min_z': float(world[:, 2].min()), 'prop_min_z': prop_min,
               'absolute_floor_contact_vertices': {name: int(near_floor[mask].sum()) for name, mask in regions.items()},
               'prop_absolute_floor_contact_vertices': sum(int((np.abs(v[:, 2]) <= .01).sum()) for v in prop_world)}
        (integer if abs(f - round(f)) < 1e-7 else subframe).append(row)
        if len(bad):
            row = dict(row)
            row['edges'] = [{'vertices': edges[i].tolist(), 'rest_m': float(lengths0[i]), 'posed_m': float(lengths[i]),
                             'weights': [weights[j] for j in edges[i]]} for i in bad]
            bad_rows.append(row)
    def summary(rows):
        return {'samples': len(rows), 'max_severe': max((r['severe'] for r in rows), default=None),
                'body_min_z': min((r['body_min_z'] for r in rows), default=None),
                'prop_min_z': min((r['prop_min_z'] for r in rows), default=None), 'grip_gap_min_m':min((r['material_grip_barycentre_error_m'] for r in rows),default=None), 'grip_gap_max_m':max((r['material_grip_barycentre_error_m'] for r in rows),default=None)}
    report = {'clip': action.name, 'range': [first, last], 'import_fps': scene.render.fps,
              'integer_import_frames': summary(integer), 'fractional_import_frames': summary(subframe),
              'integer_rows': integer, 'fractional_rows': subframe, 'bad_rows': bad_rows}
    reports.append(report)
    print('EXPORTED CHECK', json.dumps({k: v for k, v in report.items() if not k.endswith('_rows')}), flush=True)
output.write_text(json.dumps({'model': str(model), 'reports': reports}, indent=2) + '\n')
assert len(reports) == 6
assert all(r['integer_import_frames']['max_severe'] == 0 and r['fractional_import_frames']['max_severe'] == 0 for r in reports), 'Deformation criterion failed; see bad_rows'
assert all(min(r['integer_import_frames']['body_min_z'], r['fractional_import_frames']['body_min_z']) >= -.001 for r in reports), 'Body penetrates the floor'
assert all(min(r['integer_import_frames']['prop_min_z'], r['fractional_import_frames']['prop_min_z']) >= 0 for r in reports), 'Prop penetrates the floor'
print('EXPORTED FLOOR/DEFORMATION CRITERIA PASS; FINGER WRAP NEEDS VISUAL REVIEW', flush=True)
