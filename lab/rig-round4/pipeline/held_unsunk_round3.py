"""Inspect and build the isolated round-three held-arm candidate."""
import ast
import hashlib
import json
import os
from pathlib import Path
import sys

import bpy
import numpy as np

LAB = Path('/Users/jamesto/Coding/glassvow/.claude/worktrees/asset-manager-lab')
OUT = LAB / 'mobs/unsunkSelf/rig-round3-held-articulated'
SOURCE = LAB / 'mobs/unsunkSelf/tripo/body-a.glb'


def helpers():
    path = LAB / 'pipeline/char_rig.py'
    tree = ast.parse(path.read_text(), filename=str(path))
    tree.body = [node for node in tree.body if not (
        isinstance(node, ast.Expr) and isinstance(node.value, ast.Call)
        and isinstance(node.value.func, ast.Name) and node.value.func.id == 'main')]
    scope = {'__file__': str(path), '__name__': 'held_unsunk_helpers'}
    sys.argv = [str(path), '--', str(LAB / 'pipeline/held_unsunk_round3.json')]
    exec(compile(tree, str(path), 'exec'), scope)
    return scope


def inspect(h):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    body = h['import_glb'](str(SOURCE))
    h['fit'](body, h['H'])
    co = h['verts'](body)
    edges = np.array([edge.vertices[:] for edge in body.data.edges])
    faces = np.array([poly.vertices[:] for poly in body.data.polygons])
    adj = [[] for _ in co]
    for a, b in edges:
        adj[a].append(int(b))
        adj[b].append(int(a))
    unseen = set(range(len(co)))
    components = []
    while unseen:
        todo = [unseen.pop()]
        found = []
        while todo:
            a = todo.pop()
            found.append(a)
            for b in adj[a]:
                if b in unseen:
                    unseen.remove(b)
                    todo.append(b)
        points = co[found] / h['H']
        components.append({'vertices': len(found), 'min': points.min(0).tolist(),
                           'max': points.max(0).tolist()})
    components.sort(key=lambda item: -item['vertices'])
    slices = []
    norm = co / h['H']
    for height in np.arange(.50, .86, .025):
        selected = norm[np.abs(norm[:, 2] - height) < .0125]
        if len(selected):
            slices.append({'z': round(float(height), 3), 'n': len(selected),
                           'min': selected.min(0).tolist(), 'max': selected.max(0).tolist()})
    report = {'source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
              'height_m': h['H'], 'vertices': len(co), 'edges': len(edges),
              'faces': len(faces), 'bounds': [co.min(0).tolist(), co.max(0).tolist()],
              'components': components, 'slices': slices}
    OUT.mkdir(exist_ok=True)
    np.savez_compressed(OUT / 'source-geometry.npz', co=co, edges=edges, faces=faces)
    (OUT / 'source-geometry.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report), flush=True)


def smooth(lo, hi, value):
    t = np.clip((value - lo) / (hi - lo), 0, 1)
    return t * t * (3 - 2 * t)


def weights(h, body, arm):
    """Blend measured sleeve regions into the continuous robe, without mesh edits."""
    p = h['verts'](body) / h['H']
    x, y, z = p.T
    names = [bone.name for bone in arm.data.bones]
    col = {name: i for i, name in enumerate(names)}
    W = np.zeros((len(p), len(names)))
    upper = smooth(.46, .69, z)
    head = smooth(.75, .83, z)
    W[:, col['Hips']] = 1 - upper
    W[:, col['Spine']] = upper * (1 - head)
    W[:, col['Head']] = upper * head
    for side, sign in (('Left', 1), ('Right', -1)):
        joints = [np.array(arm.data.bones[side + part].head_local) / h['H']
                  for part in ('UpperArm', 'LowerArm', 'Hand')]
        joints.append(np.array(arm.data.bones[side + 'Hand'].tail_local) / h['H'])
        sh, el, wr, tip = joints
        distances, params = [], []
        for a, b in zip(joints[:-1], joints[1:]):
            t = np.clip((p - a) @ (b - a) / np.dot(b - a, b - a), 0, 1)
            distances.append(np.linalg.norm(p - a - t[:, None] * (b - a), axis=1))
            params.append(t)
        D = np.array(distances).T
        # ponytail: the fused sleeves allow modest joint motion; a free-arm silhouette needs retopology.
        front = 1 - smooth(-.115, -.055, y)
        flank = smooth(.065, .112, x * sign)
        side_mask = smooth(-.025, .025, x * sign)
        zone = smooth(.44, .56, z) * (1 - smooth(.715, .79, z))
        reach = 1 - smooth(.035, .090, D.min(1))
        amount = zone * np.maximum(front, flank * .75) * reach * side_mask
        hand_zone = (1 - smooth(.045, .072, np.abs(x))) * (1 - smooth(-.132, -.112, y))
        hand_zone *= smooth(.525, .551, z) * (1 - smooth(.593, .625, z))
        amount = np.maximum(amount, hand_zone * side_mask)
        nearest = np.exp(-(D / .038) ** 2)
        nearest[:, 0] *= 1 - smooth(.15, .9, params[1])
        nearest[:, 2] *= smooth(.45, .95, params[1])
        nearest /= np.maximum(nearest.sum(1, keepdims=True), 1e-12)
        nearest = nearest * (1 - hand_zone[:, None])
        nearest[:, 2] += hand_zone
        W *= (1 - amount[:, None])
        for index, part in enumerate(('UpperArm', 'LowerArm', 'Hand')):
            W[:, col[side + part]] += amount * nearest[:, index]
    # The central, physically fused clasp follows the same rigid hand transform on both sides.
    clasp = (np.abs(x) < .031) & (y < -.143) & (z > .548) & (z < .598)
    W[clasp] = 0
    W[clasp, col['LeftHand']] = .5
    W[clasp, col['RightHand']] = .5
    order = np.argsort(W, axis=1)
    np.put_along_axis(W, order[:, :-4], 0, axis=1)
    W /= W.sum(1, keepdims=True)
    assert np.isfinite(W).all() and np.allclose(W.sum(1), 1)
    body.parent = arm
    mod = body.modifiers.new('Held arm deformation', 'ARMATURE')
    mod.object = arm
    groups = [body.vertex_groups.new(name=name) for name in names]
    for i, row in enumerate(W):
        for j in np.flatnonzero(row > 1e-6):
            groups[j].add([i], float(row[j]), 'REPLACE')
    report = {name: {'dominant_vertices': int((W.argmax(1) == j).sum()),
                     'vertices_above_0_1': int((W[:, j] > .1).sum())} for j, name in enumerate(names)}
    report['clasp_vertex_count'] = int(clasp.sum())
    (OUT / 'weights.json').write_text(json.dumps(report, indent=2) + '\n')
    return np.flatnonzero(clasp).tolist()


def solve_arms(h, arm, offset, angle):
    from mathutils import Vector, Matrix
    torso = arm.pose.bones['Spine'].matrix @ arm.data.bones['Spine'].matrix_local.inverted()
    centre = Vector(h['spec']['contact_centre']) * h['H']
    rotation = Matrix.Rotation(angle, 4, 'X')
    contact = Matrix.Translation(centre + Vector(offset) * h['H']) @ rotation @ Matrix.Translation(-centre)
    for side in ('Left', 'Right'):
        upper, lower, hand = [arm.pose.bones[side + part] for part in ('UpperArm', 'LowerArm', 'Hand')]
        sh, el, wr = [pb.bone.head_local.copy() for pb in (upper, lower, hand)]
        goal = contact @ wr
        delta = goal - sh
        distance = delta.length
        ulen, llen = (el - sh).length, (wr - el).length
        assert abs(ulen - llen) + 1e-5 < distance < ulen + llen - 1e-5, 'Unreachable hand target'
        direction = delta.normalized()
        pole = el - sh - direction * (el - sh).dot(direction)
        assert pole.length > 1e-5
        along = (ulen * ulen - llen * llen + distance * distance) / (2 * distance)
        elbow = sh + direction * along + pole.normalized() * (ulen * ulen - along * along) ** .5
        for pb, start, end, original in ((upper, sh, elbow, el - sh), (lower, elbow, goal, wr - el)):
            turn = original.rotation_difference(end - start).to_matrix().to_4x4()
            matrix = Matrix.Translation(start) @ turn @ pb.bone.matrix_local.to_3x3().to_4x4()
            pb.matrix = torso @ matrix
            bpy.context.view_layer.update()
        hand.matrix = torso @ contact @ hand.bone.matrix_local
        bpy.context.view_layer.update()
        assert max(pb.location.length for pb in (upper, lower, hand)) < 1e-5, 'IK changed limb lengths'


def build(h):
    from mathutils import Vector
    bpy.ops.wm.read_factory_settings(use_empty=True)
    body = h['import_glb'](str(SOURCE))
    body.name = 'unsunkSelf'
    h['fit'](body, h['H'])
    source_co = h['verts'](body).copy()
    J, chain = h['custom_chain']()
    arm = h['build_armature'](J, chain)
    clasp = weights(h, body, arm)
    scene = bpy.context.scene
    scene.render.fps = 30
    X, Z = h['X'], h['Z']
    motions = {
        'idle': [(1, {}, (0, 0, 0), 0), (30, {'Head': [(X, -1.5)]}, (0, -.002, .003), 0), (60, {}, (0, 0, 0), 0)],
        'walk': [(1, {'Spine': [(Z, 1)]}, (.002, 0, .002), 0), (9, {}, (0, -.003, .004), 0),
                 (17, {'Spine': [(Z, -1)]}, (-.002, 0, .002), 0), (25, {}, (0, -.003, .004), 0),
                 (33, {'Spine': [(Z, 1)]}, (.002, 0, .002), 0)],
        'attack': [(1, {}, (0, 0, 0), 0), (9, {'Spine': [(Z, 3)]}, (0, .012, .006), -.04),
                   (14, {'Spine': [(X, 3), (Z, -3)]}, (0, -.035, .012), .08),
                   (18, {'Spine': [(X, 3), (Z, -3)]}, (0, -.035, .012), .08), (32, {}, (0, 0, 0), 0)],
        'cast': [(1, {}, (0, 0, 0), 0), (13, {'Head': [(X, -4)]}, (0, -.012, .075), -.14),
                 (24, {'Head': [(X, -4)]}, (0, -.012, .075), -.14), (38, {}, (0, 0, 0), 0)],
        'hurt': [(1, {}, (0, 0, 0), 0), (5, {'Spine': [(X, -6)], 'Head': [(X, 5)]}, (0, .009, .018), -.06),
                 (18, {}, (0, 0, 0), 0)],
        'death': [(1, {}, (0, 0, 0), 0), (14, {'Spine': [(X, 10)], 'Head': [(X, 10)]}, (0, .006, -.015), .05),
                  (30, {'Hips': [(X, 78)], 'Spine': [(X, 8)], 'Head': [(X, 12)]}, (0, .005, -.022), .08),
                  (42, {'Hips': [(X, 78)], 'Spine': [(X, 8)], 'Head': [(X, 12)]}, (0, .005, -.022), .08)]}
    actions, evidence = [], []
    for name, keys in motions.items():
        action = h['clip'](arm, name, [(frame, pose) for frame, pose, _, _ in keys])
        arm.animation_data.action = action
        # Sample the original body curves before baking any keys into this action.
        samples = []
        for frame in range(keys[0][0], keys[-1][0] + 1):
            scene.frame_set(frame)
            rotations = {pb.name: pb.rotation_quaternion.copy() for pb in arm.pose.bones}
            i = min(next((i for i in range(len(keys) - 1) if frame <= keys[i + 1][0]), len(keys) - 2), len(keys) - 2)
            a, b = keys[i], keys[i + 1]
            t = smooth(0, 1, (frame - a[0]) / (b[0] - a[0]))
            offset = np.array(a[2]) * (1 - t) + np.array(b[2]) * t
            angle = a[3] * (1 - t) + b[3] * t
            samples.append((frame, rotations, offset, angle))
        clearance, contact_error, max_offset = [], [], 0
        previous = {}
        for frame, rotations, offset, angle in samples:
            scene.frame_set(frame)
            for pb in arm.pose.bones:
                pb.location = (0, 0, 0)
                pb.scale = (1, 1, 1)
                pb.rotation_quaternion = rotations[pb.name]
            bpy.context.view_layer.update()
            solve_arms(h, arm, offset, angle)
            eval_body = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
            mesh = eval_body.to_mesh()
            floor = min((eval_body.matrix_world @ v.co).z for v in mesh.vertices)
            eval_body.to_mesh_clear()
            hips = arm.pose.bones['Hips']
            hips.location += hips.bone.matrix_local.to_3x3().inverted() @ Vector((0, 0, .002 - floor))
            for pb in arm.pose.bones:
                if pb.name in previous and previous[pb.name].dot(pb.rotation_quaternion) < 0:
                    pb.rotation_quaternion.negate()
                previous[pb.name] = pb.rotation_quaternion.copy()
                pb.keyframe_insert('rotation_quaternion', frame=frame)
            hips.keyframe_insert('location', frame=frame)
            bpy.context.view_layer.update()
            centre = Vector(h['spec']['contact_centre']) * h['H']
            world_contacts = [arm.pose.bones[side + 'Hand'].matrix @ arm.data.bones[side + 'Hand'].matrix_local.inverted() @ centre
                              for side in ('Left', 'Right')]
            contact_error.append((world_contacts[0] - world_contacts[1]).length)
            max_offset = max(max_offset, float(np.linalg.norm(offset) * h['H']))
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        for key in curve.keyframe_points:
                            key.interpolation = 'LINEAR'
        actions.append(action)
        evidence.append({'clip': name, 'frames': len(samples), 'max_contact_error_m': max(contact_error),
                         'max_hand_target_offset_m': max_offset})
    assert np.array_equal(h['verts'](body), source_co), 'Source proportions changed'
    arm.animation_data.action = actions[0]
    scene.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'unsunkSelf.blend'))
    bpy.ops.export_scene.gltf(filepath=str(OUT / 'unsunkSelf.glb'), export_format='GLB',
                              export_animations=True, export_animation_mode='ACTIONS')
    (OUT / 'build.json').write_text(json.dumps({'bones': len(arm.data.bones), 'source_coordinates_unchanged': True,
        'clasp_vertices': clasp, 'clips': evidence, 'held_object': None,
        'limitation': 'Hands and sleeves remain fused to the robe. Contact is a paired clasp, not a separate prop. No finger separation or independent hand release.'}, indent=2) + '\n')
    print('BUILD', json.dumps(evidence), flush=True)


def verify(h, render=False):
    """Check the exported file, including a counterfactual with the arm joints disabled."""
    from mathutils import Vector
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.fps = 30
    bpy.ops.import_scene.gltf(filepath=str(OUT / 'unsunkSelf.glb'), merge_vertices=True)
    arm = next(obj for obj in bpy.data.objects if obj.type == 'ARMATURE')
    body = next(obj for obj in bpy.data.objects if obj.type == 'MESH' and obj.find_armature() == arm)
    assert len(arm.data.bones) == 9
    names = [side + part for side in ('Left', 'Right') for part in ('UpperArm', 'LowerArm', 'Hand')]
    source = np.load(OUT / 'source-geometry.npz')['co']
    imported = h['verts'](body)
    nearest_error = max(float(np.linalg.norm(source - point, axis=1).min()) for point in imported)
    assert nearest_error < 1e-6, ('Rest geometry changed', nearest_error)
    assert len(body.data.polygons) == 7333
    centre = Vector(h['spec']['contact_centre']) * h['H']
    reports = []
    def posed():
        evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
        mesh = evaluated.to_mesh()
        points = np.array([evaluated.matrix_world @ v.co for v in mesh.vertices])
        evaluated.to_mesh_clear()
        return points
    peaks = {'idle': 30, 'walk': 9, 'attack': 14, 'cast': 18, 'hurt': 5, 'death': 35}
    actions = {a.name: a for a in bpy.data.actions}
    assert set(actions) == set(peaks)
    for name, action in actions.items():
        arm.animation_data.action = action
        first, last = action.frame_range
        start, stop = round(first * 8), round(last * 8)
        errors, angles, hand_local = [], {bone: [] for bone in names}, []
        for tick in range(start, stop + 1):
            scene.frame_set(tick // 8, subframe=tick % 8 / 8)
            contacts = [arm.pose.bones[side + 'Hand'].matrix @ arm.data.bones[side + 'Hand'].matrix_local.inverted() @ centre
                        for side in ('Left', 'Right')]
            errors.append((contacts[0] - contacts[1]).length)
            torso = arm.pose.bones['Spine'].matrix @ arm.data.bones['Spine'].matrix_local.inverted()
            hand_local.append(tuple(torso.inverted() @ contacts[0] - centre))
            for bone in names:
                q = arm.pose.bones[bone].rotation_quaternion.normalized()
                angles[bone].append(float(2 * np.arccos(np.clip(abs(q.w), 0, 1)) * 180 / np.pi))
        scene.frame_set(peaks[name])
        actual = posed()
        saved = {bone: arm.pose.bones[bone].rotation_quaternion.copy() for bone in names}
        for bone in names:
            arm.pose.bones[bone].rotation_quaternion.identity()
        bpy.context.view_layer.update()
        disabled = posed()
        displacement = np.linalg.norm(actual - disabled, axis=1)
        for bone in names:
            arm.pose.bones[bone].rotation_quaternion = saved[bone]
        bpy.context.view_layer.update()
        report = {'clip': name, 'duration_seconds': float((last - first) / scene.render.fps),
                  'samples': len(errors), 'max_clasp_error_m': max(errors),
                  'max_joint_rotation_degrees': {bone: max(values) for bone, values in angles.items()},
                  'hand_local_min_m': np.min(hand_local, axis=0).tolist(),
                  'hand_local_max_m': np.max(hand_local, axis=0).tolist(),
                  'arm_disabled_max_displacement_m': float(displacement.max()),
                  'arm_disabled_vertices_over_1mm': int((displacement > .001).sum())}
        assert max(errors) < .001, report
        if name in ('attack', 'cast'):
            assert min(max(angles[side + 'LowerArm']) for side in ('Left', 'Right')) > 8, report
            assert displacement.max() > .04 and (displacement > .001).sum() > 150, report
        reports.append(report)
    output = {'rest_coordinate_max_error_m': nearest_error, 'triangles': len(body.data.polygons),
              'imported_vertices': len(imported), 'clips': reports,
              'limitation': 'Geometric checks do not certify collisions, fingers, free-arm reach or a production engine import.'}
    (OUT / 'reimport-articulation.json').write_text(json.dumps(output, indent=2) + '\n')
    print('ARTICULATION', json.dumps(output), flush=True)
    if not render:
        return
    h['stage']()
    scene.render.resolution_x, scene.render.resolution_y = 256, 320
    scene.render.image_settings.file_format = 'PNG'
    frames = {'idle': [1, 30, 60], 'walk': [1, 9, 17], 'attack': [1, 9, 14],
              'cast': [1, 13, 24], 'hurt': [1, 5, 18], 'death': [1, 14, 35]}
    for name in ('idle', 'walk', 'attack', 'cast', 'hurt', 'death'):
        action = actions[name]
        points = h['pose_bounds'](arm, action, [body])
        for view, direction in (('front', (0, -1, .05)), ('side', (1, -.15, .05))):
            h['frame_camera'](points, direction)
            for frame in frames[name]:
                scene.frame_set(frame)
                h['shot'](str(OUT / f'review-{name}-{view}-{frame:02}.png'))
    print('REVIEW DONE', flush=True)


def main():
    mode = sys.argv[sys.argv.index('--') + 1]
    h = helpers()
    if mode == 'inspect':
        inspect(h)
    elif mode == 'build':
        build(h)
    elif mode in ('verify', 'review'):
        verify(h, render=mode == 'review')
    else:
        raise ValueError(mode)


main()
