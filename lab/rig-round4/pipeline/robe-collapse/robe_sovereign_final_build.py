# Blender: build a robe-collapse candidate source from a pick source and an offline collapse solve.
# The pick source is only read; the result is saved as a new file in a new folder.
#   blender -b pick-source.blend --python-exit-code 1 --python robe_collapse_build.py -- solve.npz out.blend report.json
import json
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Vector

solve, out, report_path = sys.argv[sys.argv.index("--") + 1:][:3]
out = Path(out)
assert not out.exists(), "Never replace an existing candidate"
source = bpy.data.filepath
assert Path(source).resolve() != out.resolve()
d = np.load(solve)
names = [str(n) for n in d["names"]]
parents = [str(p) or None for p in d["parents"]]
rest_mine = {n: m for n, m in zip(names, d["rest"])}
W, pose, solve_verts = d["weights"], d["pose"], d["verts"]
skirt = [n for n in names if n.startswith("Skirt")]
others = ("idle", "walk", "attack", "cast", "hurt")
scene = bpy.context.scene
assert scene.render.fps == 30, "Use an original 30 FPS candidate"
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
body = next(o for o in bpy.data.objects if o.type == "MESH" and o.find_armature() == arm)
assert np.allclose(np.array(arm.matrix_world), np.eye(4), atol=1e-6), "Armature must sit at the origin"
mw = np.array(body.matrix_world)
N = len(body.data.vertices)
assert N == len(W) == solve_verts.shape[1], (N, W.shape, solve_verts.shape)


def activate(obj, mode="OBJECT"):
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode=mode)


def sample(action, frames):
    arm.animation_data.action = action
    rows = []
    for f in frames:
        scene.frame_set(f)
        ev = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
        mesh = ev.to_mesh()
        co = np.empty(len(mesh.vertices) * 3)
        mesh.vertices.foreach_get("co", co)
        ev.to_mesh_clear()
        rows.append(co.reshape(-1, 3) @ mw[:3, :3].T + mw[:3, 3])
    return np.array(rows)


def frames_of(action):
    first, last = (int(x) for x in action.frame_range)
    return list(range(first, last + 1))


# The bake applies this export limit first, so the comparison baseline uses it too.
activate(body)
bpy.ops.object.vertex_group_limit_total(limit=4)
bpy.ops.object.vertex_group_normalize_all(lock_active=False)
before = {c: sample(bpy.data.actions[c], frames_of(bpy.data.actions[c])) for c in others}

# Skirt controls: radial chains parented to Hips, rest matrices from the solve.
activate(arm, "EDIT")
eb = arm.data.edit_bones
for n in names:
    r, i = rest_mine[n], names.index(n)
    b = eb.get(n) or eb.new(n)
    b.head = Vector(r[:3, 3])
    b.tail = Vector(r[:3, 3] + r[:3, 1] * float(d["lengths"][i]))
    b.align_roll(Vector(r[:3, 2]))
    b.parent = eb[parents[i]] if parents[i] else None
    b.use_connect = False
    b.use_deform = True
activate(arm)
rest_bl = {n: np.array(arm.data.bones[n].matrix_local) for n in names}
# Reset only the prop's rest geometry to its measured palm/shaft material alignment.
prop_obj = next(o for o in bpy.data.objects if o.type == "MESH" and o is not body and o.parent == arm and o.parent_type == "BONE")
arm.data.pose_position = "REST"; bpy.context.view_layer.update()
prop_inv = np.linalg.inv(np.array(prop_obj.matrix_world))
local_prop = np.c_[d["prop_verts"], np.ones(len(d["prop_verts"]))] @ prop_inv.T
for vertex, co in zip(prop_obj.data.vertices, local_prop):vertex.co=co[:3]
arm.data.pose_position = "POSE"; bpy.context.view_layer.update()
rest_error = max(float(np.abs(rest_bl[n] - rest_mine[n]).max()) for n in skirt)

# Weights from the solve (already limited to four and normalised).
for j, n in enumerate(names):
    vg = body.vertex_groups.get(n) or body.vertex_groups.new(name=n)
    vg.remove(list(range(N)))
    for i in np.nonzero(W[:, j] > 1e-6)[0]:
        vg.add([int(i)], float(W[i, j]), "REPLACE")

# Other clips: the skirt sits at rest on their first and last keys, so no death pose leaks into them.
for c in others:
    act = bpy.data.actions[c]
    arm.animation_data.action = act
    for n in skirt:
        pb = arm.pose.bones[n]
        pb.rotation_mode = "QUATERNION"
        pb.location, pb.rotation_quaternion, pb.scale = (0, 0, 0), (1, 0, 0, 0), (1, 1, 1)
        for f in (frames_of(act)[0], frames_of(act)[-1]):
            for path in ("location", "rotation_quaternion", "scale"):
                pb.keyframe_insert(path, frame=f)

# Death: one key per frame from the solve. Each bone's skin transform P @ inv(rest) is kept exactly,
# using Blender's own rest matrices; location only on Hips and the skirt, scale only on the skirt.
old = bpy.data.actions["death"]
old_range = tuple(old.frame_range)
bpy.data.actions.remove(old)
act = bpy.data.actions.new("death")
act.use_fake_user = True
arm.animation_data.action = act
inv = np.linalg.inv
prev_q, worst_loc, worst_scale = {}, 0.0, 0.0
for k in range(len(pose)):
    f = k + 1
    Pbl = {n: pose[k][j] @ inv(rest_mine[n]) @ rest_bl[n] for j, n in enumerate(names)}
    for j, n in enumerate(names):
        p = parents[j]
        base = rest_bl[n] if p is None else Pbl[p] @ inv(rest_bl[p]) @ rest_bl[n]
        loc, rot, scl = Matrix((inv(base) @ Pbl[n]).tolist()).decompose()
        if n in prev_q and prev_q[n].dot(rot) < 0:
            rot.negate()
        prev_q[n] = rot
        pb = arm.pose.bones[n]
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = rot
        pb.keyframe_insert("rotation_quaternion", frame=f)
        if n == "Hips" or n in skirt:
            pb.location = loc
            pb.keyframe_insert("location", frame=f)
        else:
            worst_loc = max(worst_loc, loc.length)
        if n in skirt:
            pb.scale = scl
            pb.keyframe_insert("scale", frame=f)
        else:
            worst_scale = max(worst_scale, max(abs(s - 1) for s in scl))
act.frame_range = (1, len(pose))
for layer in act.layers:
    for strip in layer.strips:
        for bag in strip.channelbags:
            for curve in bag.fcurves:
                for key in curve.keyframe_points:
                    key.interpolation = "LINEAR"
assert worst_loc < 1e-3 and worst_scale < 1e-3, (worst_loc, worst_scale)

# Evidence: the death in Blender matches the solve; the other clips deform as before.
death = sample(act, list(range(1, len(pose) + 1)))
death_error = float(np.linalg.norm(death - solve_verts, axis=2).max())
after = {c: sample(bpy.data.actions[c], frames_of(bpy.data.actions[c])) for c in others}
clips = {}
for c in others:
    dist = np.linalg.norm(after[c] - before[c], axis=2)
    clips[c] = {"frames": len(dist), "max_m": round(float(dist.max()), 5), "p99_m": round(float(np.percentile(dist, 99)), 5),
                "verts_over_1cm": int((dist.max(0) > .01).sum())}
# The existing PropPivot lies on the shaft at the hand tip. Keep that grip and full prop size.
import importlib.util
module_path = Path(__file__).with_name("sovereign_staff_continuity.py")
spec = importlib.util.spec_from_file_location("staff", module_path)
staff = importlib.util.module_from_spec(spec); spec.loader.exec_module(staff)
staff.self_check()
prop = next(o for o in bpy.data.objects if o.type == "MESH" and o is not body and o.parent == arm and o.parent_type == "BONE")
prop_bone = prop.parent_bone
arm.animation_data.action = bpy.data.actions["idle"]
scene.frame_set(1)
arm.data.pose_position = "REST"; bpy.context.view_layer.update()
rest_prop = np.array([v.co[:] for v in prop.data.vertices])
prop_matrix = np.array(prop.matrix_world)
rest_prop = rest_prop @ prop_matrix[:3, :3].T + prop_matrix[:3, 3]
arm.data.pose_position = "POSE"; bpy.context.view_layer.update()
r0 = np.array(arm.data.bones[prop_bone].matrix_local)
offsets = rest_prop - r0[:3, 3]
axis0 = np.linalg.svd(rest_prop - rest_prop.mean(0), full_matrices=False)[2][0]
prop_report = {}
for c in (*others, "death"):
    action = bpy.data.actions[c]; arm.animation_data.action = action
    first, last = map(float, action.frame_range)
    times = [first + i / 8 for i in range(round((last - first) * 8) + 1)]
    previous, direction, prior_q = None, None, None
    rows = []
    # Collect the unmodified grip trajectory before writing any correction keys.
    base_poses = []
    for f in times:
        scene.frame_set(int(f), subframe=f % 1)
        base_poses.append(np.array(arm.pose.bones[prop_bone].matrix))
    for f, base_pose in zip(times, base_poses):
        scene.frame_set(int(f), subframe=f % 1)
        rotation, direction, low = staff.solve(base_pose, base_pose[:3, :3], r0[:3, :3], offsets, axis0, .055, previous, direction)
        M = base_pose.copy(); M[:3, :3] = rotation
        parent = arm.pose.bones[prop_bone].parent
        base = np.array(parent.matrix) @ np.linalg.inv(np.array(parent.bone.matrix_local)) @ r0
        loc, q, scale = Matrix((np.linalg.inv(base) @ M).tolist()).decompose()
        assert loc.length < 1e-4 and max(abs(s-1) for s in scale) < 1e-4, (c, f, "Grip moved or prop scaled")
        if prior_q is not None and prior_q.dot(q) < 0:q.negate()
        pb=arm.pose.bones[prop_bone];pb.rotation_mode="QUATERNION";pb.rotation_quaternion=q
        pb.keyframe_insert("rotation_quaternion",frame=f)
        previous,prior_q=rotation,q.copy()
        # The palm triangle was bound rigidly to Hand; the corresponding material shaft vertex is at PropPivot.
        rows.append({"frame":f,"surface_min_z":low})
    prop_report[c]={"samples":len(rows),"min_surface_z":min(r["surface_min_z"] for r in rows),"grip_translation_max":0,"scale":1}
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    if '"' + prop_bone + '"' in curve.data_path:
                        for key in curve.keyframe_points:key.interpolation="LINEAR"
arm.animation_data.action = bpy.data.actions["idle"]
scene.frame_set(1)
out.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(out))
report = {"source": source, "solve": solve, "out": str(out), "skirt_bones": len(skirt),
          "skirt_rest_error": rest_error, "old_death_range": old_range, "death_frames": len(pose),
          "death_vs_solve_max_m": round(death_error, 5), "dropped_location_max_m": worst_loc,
          "dropped_scale_max": worst_scale, "other_clips_vs_pick": clips, "staff_repair": prop_report}
Path(report_path).write_text(json.dumps(report, indent=2) + "\n")
print("ROBE COLLAPSE BUILD", json.dumps(report), flush=True)
