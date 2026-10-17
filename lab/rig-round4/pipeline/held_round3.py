"""Build and verify a round-three held-arm candidate from a held_*_round3.json spec.

blender -b --factory-startup --python-exit-code 1 --python held_round3.py -- spec.json inspect|build|verify
Generalises held_unsunk_round3.py, which stays the provenance of the unsunkSelf candidate. Every
character-specific value lives in the spec: bones, the rigid held region, weight zones and motions.
The held object and both fists are one rigid region weighted equally to both hand bones; both hands
share one contact transform, so the object cannot bend and the grip cannot slide. Arms reach it by
analytic two-bone IK from the shoulders, so the elbows and wrists articulate.
"""
import hashlib
import heapq
import json
from pathlib import Path
import sys

import bpy
import numpy as np

LAB = Path('/Users/jamesto/Coding/glassvow/.claude/worktrees/asset-manager-lab')
ARGS = sys.argv[sys.argv.index('--') + 1:]
SPEC_PATH = Path(ARGS[0])
SPEC = json.loads(SPEC_PATH.read_text())
OUT = Path(SPEC['out_dir'])
SOURCE = Path(SPEC['body_glb'])
NAME = SPEC['name']
ARMS = [side + part for side in ('Left', 'Right') for part in ('UpperArm', 'LowerArm', 'Hand')]


def helpers():
    import ast
    path = LAB / 'pipeline/char_rig.py'
    tree = ast.parse(path.read_text(), filename=str(path))
    tree.body = [node for node in tree.body if not (
        isinstance(node, ast.Expr) and isinstance(node.value, ast.Call)
        and isinstance(node.value.func, ast.Name) and node.value.func.id == 'main')]
    scope = {'__file__': str(path), '__name__': 'held_round3_helpers'}
    saved, sys.argv = sys.argv, [str(path), '--', str(SPEC_PATH)]
    exec(compile(tree, str(path), 'exec'), scope)
    sys.argv = saved
    return scope


def smooth(lo, hi, value):
    t = np.clip((value - lo) / (hi - lo), 0, 1)
    return t * t * (3 - 2 * t)


def components(co, edges):
    label = np.full(len(co), -1)
    adj = [[] for _ in co]
    for a, b in edges:
        adj[a].append(int(b))
        adj[b].append(int(a))
    sizes = []
    for seed in range(len(co)):
        if label[seed] >= 0:
            continue
        label[seed], todo, count = len(sizes), [seed], 0
        while todo:
            a = todo.pop()
            count += 1
            for b in adj[a]:
                if label[b] < 0:
                    label[b] = label[seed]
                    todo.append(b)
        sizes.append(count)
    return label, sizes


def inspect(h):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    body = h['import_glb'](str(SOURCE))
    h['fit'](body, h['H'])
    co = h['verts'](body)
    edges = np.array([edge.vertices[:] for edge in body.data.edges])
    faces = np.array([poly.vertices[:] for poly in body.data.polygons])
    label, sizes = components(co, edges)
    parts = [{'vertices': size, 'min': (co[label == i] / h['H']).min(0).tolist(),
              'max': (co[label == i] / h['H']).max(0).tolist()} for i, size in enumerate(sizes)]
    report = {'source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(), 'height_m': h['H'],
              'vertices': len(co), 'edges': len(edges), 'faces': len(faces),
              'bounds': [co.min(0).tolist(), co.max(0).tolist()], 'component_count': len(sizes),
              'components': sorted(parts, key=lambda item: -item['vertices'])[:12]}
    OUT.mkdir(parents=True, exist_ok=True)
    np.savez_compressed(OUT / 'source-geometry.npz', co=co, edges=edges, faces=faces, label=label)
    (OUT / 'source-geometry.json').write_text(json.dumps(report, indent=2) + '\n')
    print('INSPECT', json.dumps(report), flush=True)


def held_region(p, edges):
    """Vertices in front of the y cut and above the z cut, connected to the seed by such vertices."""
    cfg = SPEC['held_region']
    mask = (p[:, 1] < cfg['y_below']) & (p[:, 2] > cfg['z_above'])
    gap = np.where(mask, np.linalg.norm(p - np.array(cfg['seed']), axis=1), np.inf)
    assert gap.min() < .05, 'Held-region seed is outside the mask'
    keep = np.zeros(len(p), bool)
    keep[gap.argmin()] = True
    todo = [int(gap.argmin())]
    adj = [[] for _ in p]
    for a, b in edges[mask[edges[:, 0]] & mask[edges[:, 1]]]:
        adj[a].append(b)
        adj[b].append(a)
    while todo:
        for b in adj[todo.pop()]:
            if not keep[b]:
                keep[b] = True
                todo.append(b)
    # Tripo leaves loose decal triangles on prop faces (they sit on sparse, large faces, so test the
    # same depth mask plus vertex proximity); they must travel with the prop.
    label, sizes = components(p, edges)
    for part, size in enumerate(sizes):
        members = np.flatnonzero(label == part)
        if size <= 20 and not keep[members].any() and mask[members].all():
            gap = np.linalg.norm(p[members][:, None] - p[keep][None], axis=2).min(1)
            if gap.max() < .06:
                keep[members] = True
    return keep


def surface_distance(p, edges, sources, radius):
    dist = np.full(len(p), np.inf)
    dist[sources] = 0
    adj = [[] for _ in p]
    for a, b in edges:
        w = float(np.linalg.norm(p[a] - p[b]))
        adj[a].append((b, w))
        adj[b].append((a, w))
    heap = [(0.0, int(v)) for v in np.flatnonzero(sources)]
    heapq.heapify(heap)
    while heap:
        d, a = heapq.heappop(heap)
        if d > dist[a] or d > radius:
            continue
        for b, w in adj[a]:
            if d + w < dist[b]:
                dist[b] = d + w
                heapq.heappush(heap, (d + w, b))
    return dist


def weights(h, body, arm):
    p = h['verts'](body) / h['H']
    edges = np.array([edge.vertices[:] for edge in body.data.edges])
    x, y, z = p.T
    names = [bone.name for bone in arm.data.bones]
    col = {name: i for i, name in enumerate(names)}
    cfg = SPEC['arm_weights']
    W = np.zeros((len(p), len(names)))
    upper, head = smooth(.46, .69, z), smooth(.75, .83, z)
    W[:, col['Hips']] = 1 - upper
    W[:, col['Spine']] = upper * (1 - head)
    W[:, col['Head']] = upper * head
    for side, sign in (('Left', 1), ('Right', -1)):
        joints = [np.array(arm.data.bones[side + part].head_local) / h['H'] for part in ('UpperArm', 'LowerArm', 'Hand')]
        joints.append(np.array(arm.data.bones[side + 'Hand'].tail_local) / h['H'])
        distances, params = [], []
        for a, b in zip(joints[:-1], joints[1:]):
            t = np.clip((p - a) @ (b - a) / np.dot(b - a, b - a), 0, 1)
            distances.append(np.linalg.norm(p - a - t[:, None] * (b - a), axis=1))
            params.append(t)
        D = np.array(distances).T
        # ponytail: sleeves stay fused to the robe; spatial zones limit how far an arm drags the body.
        front = 1 - smooth(*cfg['front'], y)
        flank = smooth(*cfg['flank'], x * sign)
        zone = smooth(cfg['zone'][0], cfg['zone'][1], z) * (1 - smooth(cfg['zone'][2], cfg['zone'][3], z))
        amount = zone * np.maximum(front, flank * .75) * (1 - smooth(*cfg['reach'], D.min(1)))
        amount *= smooth(-.025, .025, x * sign)
        nearest = np.exp(-(D / cfg['sigma']) ** 2)
        nearest[:, 0] *= 1 - smooth(.15, .9, params[1])
        nearest[:, 2] *= smooth(.45, .95, params[1])
        nearest /= np.maximum(nearest.sum(1, keepdims=True), 1e-12)
        W *= 1 - amount[:, None]
        for index, part in enumerate(('UpperArm', 'LowerArm', 'Hand')):
            W[:, col[side + part]] += amount * nearest[:, index]
    held = held_region(p, edges)
    contact = np.zeros(len(names))
    contact[[col['LeftHand'], col['RightHand']]] = .5
    feather = surface_distance(p, edges, held, SPEC['held_feather'])
    blend = np.where(held, 1, 1 - smooth(0, SPEC['held_feather'], np.nan_to_num(feather, posinf=9)))
    # Large held-object moves amplify any weight step between neighbours. Relax the arm/body field
    # first, then lay the held contact and its surface-distance feather on top, so the rigid border
    # keeps its smooth feather instead of gaining a new step.
    a, b = edges.T
    degree = np.maximum(np.bincount(a, minlength=len(p)) + np.bincount(b, minlength=len(p)), 1)[:, None]
    for _ in range(SPEC.get('smooth_passes', 0)):
        total = np.zeros_like(W)
        np.add.at(total, a, W[b])
        np.add.at(total, b, W[a])
        W = .5 * W + .5 * total / degree
    W = W * (1 - blend[:, None]) + blend[:, None] * contact
    order = np.argsort(W, axis=1)
    np.put_along_axis(W, order[:, :-4], 0, axis=1)
    W /= W.sum(1, keepdims=True)
    assert np.isfinite(W).all() and np.allclose(W.sum(1), 1)
    assert np.allclose(W[held][:, [col['LeftHand'], col['RightHand']]], .5), 'Held region is not rigid'
    body.parent = arm
    mod = body.modifiers.new('Held arm deformation', 'ARMATURE')
    mod.object = arm
    groups = [body.vertex_groups.new(name=name) for name in names]
    for i, row in enumerate(W):
        for j in np.flatnonzero(row > 1e-6):
            groups[j].add([i], float(row[j]), 'REPLACE')
    report = {name: {'dominant_vertices': int((W.argmax(1) == j).sum()),
                     'vertices_above_0_1': int((W[:, j] > .1).sum())} for j, name in enumerate(names)}
    report['held_vertices'] = int(held.sum())
    report['feathered_vertices'] = int(((blend > 1e-3) & ~held).sum())
    report['held_bounds_fraction_of_height'] = [p[held].min(0).tolist(), p[held].max(0).tolist()]
    (OUT / 'weights.json').write_text(json.dumps(report, indent=2) + '\n')
    np.save(OUT / 'held-vertices.npy', np.flatnonzero(held))
    return held


def contact_matrix(h, offset, degrees):
    from mathutils import Euler, Matrix, Vector
    centre = Vector(SPEC['contact_centre']) * h['H']
    turn = Euler([np.radians(value) for value in degrees], 'XYZ').to_matrix().to_4x4()
    return Matrix.Translation(centre + Vector(offset) * h['H']) @ turn @ Matrix.Translation(-centre)


def solve_arms(arm, contact):
    """Two-bone IK to the wrists carried by the contact transform, in the torso's rest frame."""
    from mathutils import Matrix
    torso = arm.pose.bones['Spine'].matrix @ arm.data.bones['Spine'].matrix_local.inverted()
    for side in ('Left', 'Right'):
        upper, lower, hand = [arm.pose.bones[side + part] for part in ('UpperArm', 'LowerArm', 'Hand')]
        sh, el, wr = [pb.bone.head_local.copy() for pb in (upper, lower, hand)]
        goal = contact @ wr
        delta = goal - sh
        distance = delta.length
        ulen, llen = (el - sh).length, (wr - el).length
        assert abs(ulen - llen) + 1e-5 < distance < ulen + llen - 1e-5, (side, 'Unreachable hand target')
        direction = delta.normalized()
        pole = el - sh - direction * (el - sh).dot(direction)
        assert pole.length > 1e-5
        along = (ulen * ulen - llen * llen + distance * distance) / (2 * distance)
        elbow = sh + direction * along + pole.normalized() * (ulen * ulen - along * along) ** .5
        for pb, start, end, original in ((upper, sh, elbow, el - sh), (lower, elbow, goal, wr - el)):
            turn = original.rotation_difference(end - start).to_matrix().to_4x4()
            pb.matrix = torso @ Matrix.Translation(start) @ turn @ pb.bone.matrix_local.to_3x3().to_4x4()
            bpy.context.view_layer.update()
        hand.matrix = torso @ contact @ hand.bone.matrix_local
        bpy.context.view_layer.update()
        assert max(pb.location.length for pb in (upper, lower, hand)) < 1e-5, 'IK changed limb lengths'


def build(h):
    from mathutils import Vector
    bpy.ops.wm.read_factory_settings(use_empty=True)
    body = h['import_glb'](str(SOURCE))
    body.name = NAME
    h['fit'](body, h['H'])
    source_co = h['verts'](body).copy()
    J, chain = h['custom_chain']()
    arm = h['build_armature'](J, chain)
    held = weights(h, body, arm)
    scene = bpy.context.scene
    scene.render.fps = 30
    axes = {'X': h['X'], 'Y': h['Y'], 'Z': h['Z']}
    actions, evidence = [], []
    for name, raw in SPEC['motions'].items():
        keys = [(frame, {bone: [(axes[a], d) for a, d in rots] for bone, rots in pose.items()},
                 np.array(offset, float), np.array(degrees, float)) for frame, pose, offset, degrees in raw]
        action = h['clip'](arm, name, [(frame, pose) for frame, pose, _, _ in keys])
        arm.animation_data.action = action
        # Sample the torso curves before baking any keys into this action.
        samples = []
        for frame in range(keys[0][0], keys[-1][0] + 1):
            scene.frame_set(frame)
            i = next(i for i in range(len(keys) - 1) if frame <= keys[i + 1][0])
            a, b = keys[i], keys[i + 1]
            t = smooth(0, 1, (frame - a[0]) / (b[0] - a[0]))
            samples.append((frame, {pb.name: pb.rotation_quaternion.copy() for pb in arm.pose.bones},
                            a[2] * (1 - t) + b[2] * t, a[3] * (1 - t) + b[3] * t))
        previous, max_offset, max_turn = {}, 0.0, 0.0
        for frame, rotations, offset, degrees in samples:
            scene.frame_set(frame)
            for pb in arm.pose.bones:
                pb.location, pb.scale, pb.rotation_quaternion = (0, 0, 0), (1, 1, 1), rotations[pb.name]
            bpy.context.view_layer.update()
            solve_arms(arm, contact_matrix(h, offset, degrees))
            evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
            mesh = evaluated.to_mesh()
            floor = min((evaluated.matrix_world @ v.co).z for v in mesh.vertices)
            evaluated.to_mesh_clear()
            hips = arm.pose.bones['Hips']
            hips.location += hips.bone.matrix_local.to_3x3().inverted() @ Vector((0, 0, .002 - floor))
            for pb in arm.pose.bones:
                if pb.name in previous and previous[pb.name].dot(pb.rotation_quaternion) < 0:
                    pb.rotation_quaternion.negate()
                previous[pb.name] = pb.rotation_quaternion.copy()
                pb.keyframe_insert('rotation_quaternion', frame=frame)
            hips.keyframe_insert('location', frame=frame)
            max_offset = max(max_offset, float(np.linalg.norm(offset) * h['H']))
            max_turn = max(max_turn, float(np.abs(degrees).max()))
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        for key in curve.keyframe_points:
                            key.interpolation = 'LINEAR'
        actions.append(action)
        evidence.append({'clip': name, 'frames': len(samples), 'max_held_offset_m': max_offset,
                         'max_held_turn_degrees': max_turn})
    assert np.array_equal(h['verts'](body), source_co), 'Source proportions changed'
    arm.animation_data.action = actions[0]
    scene.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / (NAME + '.blend')))
    bpy.ops.export_scene.gltf(filepath=str(OUT / (NAME + '.glb')), export_format='GLB',
                              export_animations=True, export_animation_mode='ACTIONS')
    (OUT / 'build.json').write_text(json.dumps({
        'spec': str(SPEC_PATH), 'bones': len(arm.data.bones), 'source_coordinates_unchanged': True,
        'held_vertices': int(held.sum()), 'clips': evidence,
        'limitation': SPEC['limitation']}, indent=2) + '\n')
    print('BUILD', json.dumps(evidence), flush=True)


def verify(h):
    """Measure the exported GLB, including a counterfactual with the arm joints held at rest."""
    from mathutils import Vector, kdtree
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.fps = 30
    bpy.ops.import_scene.gltf(filepath=str(OUT / (NAME + '.glb')), merge_vertices=True)
    arm = next(obj for obj in bpy.data.objects if obj.type == 'ARMATURE')
    body = next(obj for obj in bpy.data.objects if obj.type == 'MESH' and obj.find_armature() == arm)
    assert len(arm.data.bones) == 9
    geometry = np.load(OUT / 'source-geometry.npz')
    source = geometry['co']
    imported = h['verts'](body)
    tree = kdtree.KDTree(len(source))
    for i, point in enumerate(source):
        tree.insert(point, i)
    tree.balance()
    matches = [tree.find(point) for point in imported]
    rest_error = max(match[2] for match in matches)
    # build() asserts exact source coordinates before export; 10 µm allows GLB float round-trip only.
    assert rest_error < 1e-5, ('Rest geometry changed', rest_error)
    assert len(body.data.polygons) == len(geometry['faces'])
    held_source = set(np.load(OUT / 'held-vertices.npy').tolist())
    held = np.array([match[1] in held_source for match in matches])
    edges = np.array([edge.vertices[:] for edge in body.data.edges])
    rest_lengths = np.linalg.norm(imported[edges[:, 0]] - imported[edges[:, 1]], axis=1)
    measured = rest_lengths > .005
    centre = Vector(SPEC['contact_centre']) * h['H']

    def posed():
        evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
        mesh = evaluated.to_mesh()
        co = np.empty(len(mesh.vertices) * 3)
        mesh.vertices.foreach_get('co', co)
        world = np.array(evaluated.matrix_world)
        evaluated.to_mesh_clear()
        return co.reshape(-1, 3) @ world[:3, :3].T + world[:3, 3]

    def rigid_residual(rest, moved):
        a, b = rest - rest.mean(0), moved - moved.mean(0)
        u, _, vt = np.linalg.svd(a.T @ b)
        if np.linalg.det(u @ vt) < 0:
            u[:, -1] *= -1
        return float(np.linalg.norm(a @ (u @ vt) - b, axis=1).max())

    actions = {action.name: action for action in bpy.data.actions}
    assert set(actions) == set(SPEC['peaks'])
    reports = []
    for name, action in actions.items():
        arm.animation_data.action = action
        first, last = action.frame_range
        errors, residuals, ratios, worst = [], [], [], (0.0, None, None)
        angles = {bone: [] for bone in ARMS}
        held_path = []
        for tick in range(round(first * 8), round(last * 8) + 1):
            scene.frame_set(tick // 8, subframe=tick % 8 / 8)
            contacts = [arm.pose.bones[side + 'Hand'].matrix @ arm.data.bones[side + 'Hand'].matrix_local.inverted() @ centre
                        for side in ('Left', 'Right')]
            errors.append((contacts[0] - contacts[1]).length)
            torso = arm.pose.bones['Spine'].matrix @ arm.data.bones['Spine'].matrix_local.inverted()
            held_path.append(tuple(torso.inverted() @ contacts[0] - centre))
            for bone in ARMS:
                q = arm.pose.bones[bone].rotation_quaternion.normalized()
                angles[bone].append(float(2 * np.degrees(np.arccos(np.clip(abs(q.w), 0, 1)))))
            points = posed()
            residuals.append(rigid_residual(imported[held], points[held]))
            ratio = np.linalg.norm(points[edges[:, 0]] - points[edges[:, 1]], axis=1)[measured] / rest_lengths[measured]
            ratios.append(float(ratio.max()))
            if ratio.max() > worst[0]:
                k = int(np.flatnonzero(measured)[ratio.argmax()])
                worst = (float(ratio.max()), tick / 8, (imported[edges[k]].mean(0) / h['H']).round(3).tolist())
        scene.frame_set(SPEC['peaks'][name])
        actual = posed()
        saved = {bone: arm.pose.bones[bone].rotation_quaternion.copy() for bone in ARMS}
        for bone in ARMS:
            arm.pose.bones[bone].rotation_quaternion.identity()
        bpy.context.view_layer.update()
        displacement = np.linalg.norm(actual - posed(), axis=1)
        for bone in ARMS:
            arm.pose.bones[bone].rotation_quaternion = saved[bone]
        bpy.context.view_layer.update()
        peak = {bone: max(values) for bone, values in angles.items()}
        report = {'clip': name, 'duration_seconds': float((last - first) / scene.render.fps), 'samples': len(errors),
                  'max_two_hand_contact_error_m': max(errors), 'max_held_rigid_residual_m': max(residuals),
                  'max_edge_stretch_ratio': max(ratios), 'worst_stretch': {'ratio': worst[0], 'frame': worst[1],
                                                                            'edge_centre_fraction_of_height': worst[2]},
                  'max_joint_rotation_degrees': peak,
                  'held_path_min_m': np.min(held_path, axis=0).tolist(), 'held_path_max_m': np.max(held_path, axis=0).tolist(),
                  'peak_frame': SPEC['peaks'][name], 'arm_disabled_max_displacement_m': float(displacement.max()),
                  'arm_disabled_vertices_over_1mm': int((displacement > .001).sum())}
        failed = []
        if max(errors) >= .001 or max(residuals) >= .001:
            failed.append('held contact not rigid')
        if name in ('attack', 'cast'):
            lower = [peak[side + 'LowerArm'] for side in ('Left', 'Right')]
            if not (max(lower) > 8 and min(lower) > 4 and min(peak[s + 'UpperArm'] for s in ('Left', 'Right')) > 4):
                failed.append('arm joints barely move')
            if not (displacement.max() > .04 and (displacement > .001).sum() > 150):
                failed.append('arm joints do not drive the mesh')
        report['failed'] = failed
        reports.append(report)
    output = {'candidate': str(OUT / (NAME + '.glb')), 'rest_coordinate_max_error_m': rest_error,
              'triangles': len(body.data.polygons), 'imported_vertices': len(imported),
              'held_vertices_imported': int(held.sum()), 'clips': reports,
              'limitation': 'Geometric checks do not certify collisions, fingers, free-arm reach or a production engine import.'}
    output['passed'] = not any(report['failed'] for report in reports)
    (OUT / 'reimport-articulation.json').write_text(json.dumps(output, indent=2) + '\n')
    print('ARTICULATION', json.dumps(output), flush=True)
    assert output['passed'], [(report['clip'], report['failed']) for report in reports if report['failed']]


def main():
    h = helpers()
    {'inspect': inspect, 'build': build, 'verify': verify}[ARGS[1]](h)


main()
