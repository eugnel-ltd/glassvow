# Rig, skin and animate a Tripo humanoid GLB in Blender, headless.
#   blender -b --factory-startup --python char_rig.py -- spec.json
# Spec keys: name, body_glb, out_dir, height, rotate_z, prop_glb, prop_hand,
# prop_grip ("top"|"bottom"), prop_length, prop_rot (deg XYZ), attack ("slash"|"swing"),
# joints (overrides, metres, character space: x right of viewer, -y forward, z up),
# arm_relax (deg the upper arms drop from the A-pose in every clip, default 25),
# cast_hand ("off"|"prop": which hand the humanoid cast raises), probe (true: render a
# measuring grid of the fitted body and stop), plan ("humanoid"|"custom").
# plan "custom" (creatures): bones = [[name, head, tail, parent, role], ...], points as
# fractions of height; the root bone is "Hips". plan "quad": the same, measured from the mesh (hip_z). Roles drive the clips: root, spine, neck, head,
# tail, sway, armL/armR (+2 lower), legL/legR (+2), legFL/legFR/legHL/legHR (+2, +3).
# attack ("lunge"|"slam"|"butt") and death ("side"|"slump") pick the custom clip styles.
# The character faces -Y. Its right side is -X. Humanoid bone names follow Godot's
# SkeletonProfileHumanoid so Godot can retarget clips between characters.
import bpy, json, math, os, sys
import numpy as np
from mathutils import Vector, Quaternion, kdtree

spec = json.load(open(sys.argv[sys.argv.index("--") + 1]))
OUT = spec["out_dir"]
os.makedirs(OUT, exist_ok=True)
H = float(spec.get("height", 1.8))
FPS = 30
PLAN = spec.get("plan", "humanoid")
ROLE, KIND = {}, {}  # custom plans: bone -> animation role, bone -> weight class
FRAME = 1.0  # review cameras widen for bodies longer or wider than a standing humanoid


def log(*a):
    print("RIG", *a, flush=True)


def only(objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]


def import_glb(path):
    before = set(bpy.data.objects)
    # glTF splits vertices at every UV seam; merged, the mesh is closer to manifold for heat
    # weighting, and seam twins cannot take different weights and crack open (UVs stay per loop).
    bpy.ops.import_scene.gltf(filepath=path, merge_vertices=True)
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    only(meshes)
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    for o in new:
        if o.name in bpy.data.objects and o is not obj:
            bpy.data.objects.remove(o)
    only([obj])
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj


def verts(obj):
    a = np.empty(len(obj.data.vertices) * 3)
    obj.data.vertices.foreach_get("co", a)
    return a.reshape(-1, 3)


def fit(obj, size, axis=2, rotate_z=0.0, ground=True):
    """Scale so the extent along `axis` is `size`; centre x/y; feet on z=0."""
    obj.rotation_mode = "XYZ"  # the glTF importer leaves QUATERNION, which ignores rotation_euler
    obj.rotation_euler = (0, 0, math.radians(rotate_z))
    only([obj])
    bpy.ops.object.transform_apply(rotation=True)
    v = verts(obj)
    lo, hi = v.min(0), v.max(0)
    s = size / (hi[axis] - lo[axis])
    obj.scale = (s, s, s)
    obj.location = (-(lo[0] + hi[0]) / 2 * s, -(lo[1] + hi[1]) / 2 * s, -lo[2] * s if ground else -(lo[2] + hi[2]) / 2 * s)
    bpy.ops.object.transform_apply(location=True, scale=True)


PROPORTIONS = {"Hips": .50, "Spine": .57, "Chest": .64, "UpperChest": .71, "Neck": .80, "Head": .85,
               "HeadTop": 1.0, "shoulder_z": .785, "root_z": .77, "shoulder_slab": (.76, .80),
               "arm_slab": (.28, .74), "leg_z": .48}  # adult hero; chibi mobs override in spec


def landmarks(v, over, sym=None):
    """Joint positions. Hands and feet are measured; the spine uses proportions (spec
    "proportions", fractions of H; "shoulder_x" fixes the shoulder instead of measuring it).
    "joints_sym" sets Left joints at (x, y, z) and Right at (-x, y, z), fractions of H."""
    z, x, y = v[:, 2], v[:, 0], v[:, 1]
    fr = dict(PROPORTIONS, **spec.get("proportions", {}))

    def slab(z0, z1, cond=None):
        m = (z >= z0 * H) & (z < z1 * H)
        return v[m if cond is None else m & cond]

    def mid_y(z0, z1):
        s = slab(z0, z1, np.abs(x) < 0.08 * H)
        return float(np.median(s[:, 1])) if len(s) else 0.0

    J = {}
    for name in ("Hips", "Spine", "Chest", "UpperChest", "Neck", "Head", "HeadTop"):
        fz = fr[name]
        J[name] = Vector((0, mid_y(fz - .02, fz + .02), fz * H))
    sh = slab(*fr["shoulder_slab"])
    half_w = float(np.percentile(np.abs(sh[:, 0]), 97)) if len(sh) else .2 * H
    sx = fr["shoulder_x"] * H if "shoulder_x" in fr else .62 * half_w
    arm = slab(*fr["arm_slab"])
    for side, sign in (("Left", 1), ("Right", -1)):
        b = arm[arm[:, 0] * sign > 0]
        ext = (b[:, 0] * sign).max()
        tip = Vector(b[(b[:, 0] * sign) > ext - .035 * H].mean(0))
        shoulder = Vector((sign * sx, J["UpperChest"].y, fr["shoulder_z"] * H))
        wrist = tip + (shoulder - tip).normalized() * .075 * H
        J[side + "ShoulderRoot"] = Vector((sign * .04 * H, J["UpperChest"].y, fr["root_z"] * H))
        J[side + "UpperArm"] = shoulder
        J[side + "LowerArm"] = shoulder.lerp(wrist, .5) + Vector((0, .01 * H, 0))
        J[side + "Hand"] = wrist
        J[side + "HandTip"] = tip
        f = slab(0, .06, x * sign > .01 * H)
        ankle_x = float(np.median(f[:, 0])) if len(f) else sign * .08 * H
        toe_y = float(f[:, 1].min()) if len(f) else -.1 * H
        heel_y = float(np.median(f[:, 1])) if len(f) else 0
        J[side + "UpperLeg"] = Vector((ankle_x * .92, J["Hips"].y, fr["leg_z"] * H))
        J[side + "Foot"] = Vector((ankle_x, heel_y, .06 * H))
        J[side + "LowerLeg"] = J[side + "UpperLeg"].lerp(J[side + "Foot"], .5) + Vector((0, -.012 * H, 0))
        J[side + "Toes"] = Vector((ankle_x, heel_y + (toe_y - heel_y) * .65, .02 * H))
        J[side + "ToesTip"] = Vector((ankle_x, toe_y, .02 * H))
    for k, p in (sym or {}).items():
        J["Left" + k] = Vector(p) * H
        J["Right" + k] = Vector((-p[0], p[1], p[2])) * H
    for k, p in over.items():
        J[k] = Vector(p)
    return J


CHAIN = [  # bone, head joint, tail joint, parent
    ("Hips", "Hips", "Spine", None), ("Spine", "Spine", "Chest", "Hips"),
    ("Chest", "Chest", "UpperChest", "Spine"), ("UpperChest", "UpperChest", "Neck", "Chest"),
    ("Neck", "Neck", "Head", "UpperChest"), ("Head", "Head", "HeadTop", "Neck"),
]
for s in ("Left", "Right"):
    CHAIN += [
        (s + "Shoulder", s + "ShoulderRoot", s + "UpperArm", "UpperChest"),
        (s + "UpperArm", s + "UpperArm", s + "LowerArm", s + "Shoulder"),
        (s + "LowerArm", s + "LowerArm", s + "Hand", s + "UpperArm"),
        (s + "Hand", s + "Hand", s + "HandTip", s + "LowerArm"),
        (s + "UpperLeg", s + "UpperLeg", s + "LowerLeg", "Hips"),
        (s + "LowerLeg", s + "LowerLeg", s + "Foot", s + "UpperLeg"),
        (s + "Foot", s + "Foot", s + "Toes", s + "LowerLeg"),
        (s + "Toes", s + "Toes", s + "ToesTip", s + "Foot"),
    ]


def custom_chain():
    """plan "custom": joints and chain straight from spec["bones"] (fractions of H)."""
    J, chain = {}, []
    for name, h, t, parent, role in spec["bones"]:
        J[name + ".h"], J[name + ".t"] = Vector(h) * H, Vector(t) * H
        chain.append((name, name + ".h", name + ".t", parent))
        ROLE[name] = role
        base = role.rstrip("23")
        KIND[name] = {"armL": "arm", "armR": "arm", "legL": "leg", "legR": "leg", "legFL": "fore", "legFR": "fore",
                      "legHL": "hind", "legHR": "hind", "tail": "tail", "sway": "part"}.get(base, "trunk")
    if "Hips" not in ROLE:
        raise SystemExit("custom plan needs a root bone named Hips")
    return J, chain


def quad_bones(v, hz):
    """plan "quad": bones for a four-legged body facing -Y, measured from the fitted mesh.
    Feet are the four ground clusters (front = smaller y); the head is the front tip, the tail
    the back tip. hz is the shoulder and hip height (fraction of H). Returns spec-style bones."""
    x, y, z = v[:, 0] / H, v[:, 1] / H, v[:, 2] / H
    g = z < .05
    cut = (y[g].min() + y[g].max()) / 2
    foot = {}
    for side, sx in (("L", 1), ("R", -1)):
        for end, front in (("F", True), ("H", False)):
            m = g & (x * sx > 0) & ((y < cut) if front else (y >= cut))
            foot[end + side] = (float(np.median(x[m])), float(np.median(y[m])), float(y[m].min()))
    yf = (foot["FL"][1] + foot["FR"][1]) / 2
    yh = (foot["HL"][1] + foot["HR"][1]) / 2
    tip = float(y.min())
    zh = float(np.median(z[y < tip + .12]))
    base = min(tip + .22, yf - .05)
    P = lambda a, b, c: [round(a, 3), round(b, 3), round(c, 3)]
    bones = [["Hips", P(0, yh, hz), P(0, yh + (yf - yh) / 3, hz), None, "root"],
             ["Spine", P(0, yh + (yf - yh) / 3, hz), P(0, yh + 2 * (yf - yh) / 3, hz), "Hips", "spine"],
             ["Chest", P(0, yh + 2 * (yf - yh) / 3, hz), P(0, yf, hz), "Spine", "spine"],
             ["Neck", P(0, yf, hz), P(0, base, zh), "Chest", "neck"],
             ["Head", P(0, base, zh), P(0, tip, zh), "Neck", "head"]]
    for key, (fx, fy, toe) in foot.items():
        end, side = key
        root = "Chest" if end == "F" else "Hips"
        name = ("Front" if end == "F" else "Hind") + ("Left" if side == "L" else "Right")
        bend = .04 if end == "F" else -.05  # elbows point back, stifles forward
        role = "leg" + end + side
        bones += [[name + "Leg", P(fx * .9, fy, hz - .04), P(fx, fy + bend, hz * .5), root, role],
                  [name + "Shin", P(fx, fy + bend, hz * .5), P(fx, fy, .1), name + "Leg", role + "2"],
                  [name + "Paw", P(fx, fy, .1), P(fx, toe, .02), name + "Shin", role + "3"]]
    back = y > yh + .12
    if back.sum() > len(y) * .01:
        end_y = float(y.max())
        pts = [(0.0, yh + .1, hz)]
        for f in (1 / 3, 2 / 3):
            yi = yh + .1 + (end_y - yh - .1) * f
            m = back & (np.abs(y - yi) < .05)
            pts.append((float(np.median(x[m])), yi, float(np.median(z[m]))) if m.any() else (0.0, yi, hz))
        k = int(np.argmax(y))
        pts.append((float(x[k]), end_y, float(z[k])))
        parent = "Hips"
        for i in range(3):
            bones.append([f"Tail{i + 1}", P(*pts[i]), P(*pts[i + 1]), parent, "tail"])
            parent = f"Tail{i + 1}"
    return bones


def build_armature(J, chain):
    data = bpy.data.armatures.new("Skeleton")
    arm = bpy.data.objects.new(spec["name"] + "_rig", data)
    bpy.context.collection.objects.link(arm)
    only([arm])
    bpy.ops.object.mode_set(mode="EDIT")
    eb = data.edit_bones
    for name, h, t, parent in chain:
        b = eb.new(name)
        b.head, b.tail = J[h], J[t]
        flat = abs((J[t] - J[h]).normalized().y) > .7  # a bone along the facing axis cannot roll to -Y
        b.align_roll(Vector((0, 0, 1)) if flat or name.endswith(("Foot", "Toes")) else Vector((0, -1, 0)))
        if parent:
            b.parent = eb[parent]
            b.use_connect = (b.parent.tail - b.head).length < 1e-4
    hand = spec.get("prop_hand")
    if hand:  # a prop pivot, so a lantern can swing on its chain
        p = eb.new("PropPivot")
        p.head = J[hand + "Tip"]
        p.tail = J[hand + "Tip"] + Vector((0, 0, -.08 * H))
        p.align_roll(Vector((0, -1, 0)))
        p.parent = eb[hand]
        p.use_deform = False  # moves the prop only; as a deform bone it took cape weights
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def skin(body, arm):
    only([body, arm])
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    n = len(body.data.vertices)
    w = np.zeros(n)
    for vx in body.data.vertices:
        w[vx.index] = sum(g.weight for g in vx.groups)
    bad = int((w < 1e-3).sum())
    log("unweighted", bad, "of", n)
    if bad > n * .01:  # heat weighting failed on a non-manifold mesh: weight a closed proxy and copy
        proxy = body.copy()
        proxy.data = body.data.copy()
        bpy.context.collection.objects.link(proxy)
        proxy.modifiers.clear()
        for g in list(proxy.vertex_groups):
            proxy.vertex_groups.remove(g)
        import bmesh  # an open shell (Gloomslime's bell) has no inside for the bones: cap its openings first
        bm = bmesh.new()
        bm.from_mesh(proxy.data)
        holes = [e for e in bm.edges if e.is_boundary]
        bmesh.ops.holes_fill(bm, edges=holes, sides=0)
        bm.to_mesh(proxy.data)
        bm.free()
        log("proxy: capped", len(holes), "open edges")
        only([proxy])
        rm = proxy.modifiers.new("remesh", "REMESH")
        rm.mode, rm.voxel_size = "VOXEL", .012 * H
        bpy.ops.object.modifier_apply(modifier="remesh")
        only([proxy, arm])
        bpy.context.view_layer.objects.active = arm
        bpy.ops.object.parent_set(type="ARMATURE_AUTO")
        for g in list(body.vertex_groups):
            body.vertex_groups.remove(g)
        for g in proxy.vertex_groups:
            body.vertex_groups.new(name=g.name)
        dt = body.modifiers.new("dt", "DATA_TRANSFER")
        dt.object, dt.use_vert_data, dt.data_types_verts = proxy, True, {"VGROUP_WEIGHTS"}
        dt.vert_mapping, dt.layers_vgroup_select_src, dt.layers_vgroup_select_dst = "POLYINTERP_NEAREST", "ALL", "NAME"
        only([body])
        bpy.ops.object.modifier_move_to_index(modifier="dt", index=0)
        bpy.ops.object.modifier_apply(modifier="dt")
        bpy.data.objects.remove(proxy)
        for vx in body.data.vertices:
            w[vx.index] = sum(g.weight for g in vx.groups)
        bad = int((w < 1e-3).sum())
        log("unweighted after proxy", bad, "of", n)
    if bad > n * .01:  # heat failed on the proxy too (Gloomslime: an open shell has no inside)
        geodesic_weights(body, arm)
        bad = 0
    if bad:  # stragglers stay at rest and stretch into slivers: copy the nearest weighted vertex
        good = [vx for vx in body.data.vertices if w[vx.index] >= 1e-3]
        kd = kdtree.KDTree(len(good))
        for i, vx in enumerate(good):
            kd.insert(vx.co, i)
        kd.balance()
        for vx in body.data.vertices:
            if w[vx.index] < 1e-3:
                for g in good[kd.find(vx.co)[1]].groups:
                    body.vertex_groups[g.group].add([vx.index], g.weight, "REPLACE")
        log("filled", bad, "unweighted from the nearest weighted vertex")
    tidy_weights(body, arm)
    if spec.get("weights") == "rigid":
        rigid_split(body)
    return bad


def rigid_split(body):
    """weights "rigid" (stone): every face follows one bone (the vote of its vertices' strongest
    bones) and the mesh is cut between bones, so pieces part at their seams. Gravewarden's fists
    are fused to its feet in one island; blended or per-vertex weights stretched a skin between."""
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(body.data)
    dl = bm.verts.layers.deform.active
    top = {v: max(v[dl].items(), key=lambda kv: kv[1])[0] for v in bm.verts if len(v[dl])}
    fb = {}
    for f in bm.faces:
        votes = [top[v] for v in f.verts if v in top]
        fb[f] = max(set(votes), key=votes.count)
    for _ in range(4):  # mode filter: a few stray faces would fly off as shards
        new = {}
        for f in bm.faces:
            votes = [fb[f]] + [fb[g] for e in f.edges for g in e.link_faces if g is not f]
            new[f] = max(set(votes), key=votes.count)
        fb = new
    seen = set()
    for f0 in bm.faces:  # a same-bone patch under 40 faces joins the bone around it
        if f0 in seen:
            continue
        patch, todo, rim = [], [f0], []
        seen.add(f0)
        while todo:
            f = todo.pop()
            patch.append(f)
            for e in f.edges:
                for g in e.link_faces:
                    if g is f:
                        continue
                    if fb[g] != fb[f0]:
                        rim.append(fb[g])
                    elif g not in seen:
                        seen.add(g)
                        todo.append(g)
        if len(patch) < 40 and rim:
            for f in patch:
                fb[f] = max(set(rim), key=rim.count)
    cut = [e for e in bm.edges if len(e.link_faces) == 2 and fb[e.link_faces[0]] != fb[e.link_faces[1]]]
    bmesh.ops.split_edges(bm, edges=cut)
    for f in bm.faces:
        for v in f.verts:
            v[dl].clear()
            v[dl][fb[f]] = 1.0
    bm.to_mesh(body.data)
    bm.free()
    log("rigid: cut", len(cut), "edges between bones")


def world_co(body):
    mw = np.array(body.matrix_world)
    return np.array([v.co for v in body.data.vertices]) @ mw[:3, :3].T + mw[:3, 3]


def bone_dist(body, arm, bones):
    """(verts, bones) distance from each vertex to each bone segment, world space."""
    co = world_co(body)
    head = np.array([arm.matrix_world @ b.head_local for b in bones])
    tail = np.array([arm.matrix_world @ b.tail_local for b in bones])
    seg = tail - head
    t = np.clip(np.einsum("vkc,kc->vk", co[:, None] - head, seg) / np.maximum((seg * seg).sum(1), 1e-12), 0, 1)
    return np.linalg.norm(head + t[..., None] * seg - co[:, None], axis=2)


def geodesic_weights(body, arm, margin=.04 * H, blend=6):
    """Weights when heat fails. Each bone seeds the surface patch nearest it; labels then spread
    over the mesh by edge length (Dijkstra), so a skirt flank goes to the body it hangs from, not
    to the arm hanging beside it (straight-line distance gave it the arm: Gloomslime's cast flew
    its hem up like wings). A few averaging passes blend the labels at the joints."""
    import heapq
    bones = [b for b in arm.data.bones if b.use_deform]
    D = bone_dist(body, arm, bones)
    nv = len(D)
    near = D.argmin(1)
    reach = D[np.arange(nv), near]
    best = np.full(len(bones), np.inf)
    np.minimum.at(best, near, reach)
    dist = np.where(reach <= best[near] + margin, 0.0, np.inf)
    lab = near.copy()  # a vertex no seed reaches keeps its straight-line nearest bone
    co = world_co(body)
    adj = [[] for _ in range(nv)]
    for e in body.data.edges:
        a, b = e.vertices
        w = float(np.linalg.norm(co[a] - co[b]))
        adj[a].append((b, w))
        adj[b].append((a, w))
    heap = [(0.0, v) for v in np.nonzero(dist == 0)[0]]
    heapq.heapify(heap)
    while heap:
        d, v = heapq.heappop(heap)
        if d > dist[v]:
            continue
        for u, w in adj[v]:
            if d + w < dist[u]:
                dist[u], lab[u] = d + w, lab[v]
                heapq.heappush(heap, (d + w, u))
    W = np.eye(len(bones))[lab]
    ea, eb = np.array([e.vertices[:] for e in body.data.edges]).T
    deg = np.maximum(np.bincount(ea, minlength=nv) + np.bincount(eb, minlength=nv), 1)[:, None]
    for _ in range(blend):
        s = np.zeros_like(W)
        np.add.at(s, ea, W[eb])
        np.add.at(s, eb, W[ea])
        W = .5 * W + .5 * s / deg
    for g in list(body.vertex_groups):
        body.vertex_groups.remove(g)
    groups = [body.vertex_groups.new(name=b.name) for b in bones]
    for v in range(nv):
        for k in np.nonzero(W[v] > .01)[0]:
            groups[k].add([v], float(W[v, k]), "REPLACE")
    log("geodesic weights on all", nv, "verts (heat failed);", int((dist == 0).sum()), "seeds")


def limb(name):
    if name in KIND:
        return KIND[name]
    return "arm" if any(k in name for k in ("Shoulder", "Arm", "Hand")) else \
        "leg" if any(k in name for k in ("Leg", "Foot", "Toes")) else "trunk"


def tidy_weights(body, arm, loose=.1 * H, iters=20):
    """Repairs for heat weights on Tripo meshes, measured on Duskblade and Ashwarden (15 Oct 2026).
    - A vertex whose nearest bone is an arm never follows a leg bone, and the reverse: claw tips
      fused to a cape edge had taken a thigh at 1.0. Creatures extend this to every limb class
      (fore, hind, tail, part): a vertex follows only its nearest bone's class and the trunk.
    - Loose cloth far from every bone (a cape hem) is smoothed, so two legs swinging apart do
      not tear neighbouring hem vertices (edges stretched x6 in a walk).
    Tried and dropped: a distance cap (2.5 x nearest) and smoothing inside it. Both raised the
    stretched-edge count in death and attack (hard limits make weight steps between neighbours).
    Also dropped on Leviathan: whole-mesh smoothing (5 passes) raised its reimport count 3 -> 52,
    a hard Lure weight box 3 -> 4 (the box border is a new 0-to-1 step), and a Lure-and-parent-only
    mask 3 -> 7 (the step moved to the lure border). Loose passes 0 gave 53; 40 kept 1. A continuous
    top-4 cut (subtract the 5th weight) gave 2: it inflates the rest when the 5th is large.
    The fix was the joint: the Lure head had sat in the crown, so the crown took Lure weight.
    A distance fade (1.5 to 3 x nearest) changed nothing on Tidecaller's hood: every bone was
    within 1.3 x the nearest there."""
    bones = [b for b in arm.data.bones if b.use_deform]
    vg = body.vertex_groups
    for b in bones:
        if b.name not in vg:
            vg.new(name=b.name)
    col = {b.name: k for k, b in enumerate(bones)}
    nv = len(body.data.vertices)
    co = world_co(body)
    D = bone_dist(body, arm, bones)
    near = D.argmin(1)
    reach = D[np.arange(nv), near]
    kind = np.array([limb(b.name) for b in bones])
    A = np.ones_like(D, dtype=bool)
    for lb in set(kind) - {"trunk"}:
        A[kind[near] == lb] &= np.isin(kind, (lb, "trunk"))
    A[np.arange(nv), near] = True
    W = np.zeros((nv, len(bones)))
    names = {g.index: g.name for g in vg}
    for vx in body.data.vertices:
        for g in vx.groups:
            if names[g.group] in col:
                W[vx.index, col[names[g.group]]] = g.weight
    fade = spec.get("class_fade")  # per recipe: a cross-class weight fades from 1 at the class border to 0 at
    F = A if not fade else np.where(A, 1., np.clip(   # fade x the nearest distance; the hard cut seamed
        (fade - D / np.maximum(reach, .02 * H)[:, None]) / (fade - 1), 0, 1))  # Mirelurker's touching leg roots
    dropped = int(((W > 1e-3) & (F < 1e-3)).sum())
    W *= F
    empty = W.sum(1) < 1e-3
    W[empty, near[empty]] = 1.0
    mask = reach > loose
    a, b = np.array([e.vertices[:] for e in body.data.edges]).T
    deg = np.bincount(a, minlength=nv) + np.bincount(b, minlength=nv)
    for _ in range(iters):
        s = np.zeros_like(W)
        np.add.at(s, a, W[b])
        np.add.at(s, b, W[a])
        W[mask] = .5 * W[mask] + .5 * s[mask] / np.maximum(deg[mask], 1)[:, None]
    W **= float(spec.get("weight_power", 1))  # per recipe: >1 shrinks the 5th weight the top-4 cut drops
    rf = spec.get("root_fade")  # per recipe, fraction of H: a limb's root bone fades out behind its head joint
    if rf:                      # and is 0 at rf x H behind it (Waylayer's tunic took 0.4-0.8 thigh above the hip)
        for k, bone in enumerate(bones):
            if kind[k] != "trunk" and (bone.parent is None or limb(bone.parent.name) == "trunk"):
                head = np.array(arm.matrix_world @ bone.head_local)
                axis = np.array(arm.matrix_world @ bone.tail_local) - head
                W[:, k] *= np.clip(1 + (co - head) @ (axis / np.linalg.norm(axis)) / (rf * H), 0, 1)
        lost = W.sum(1) < 1e-6
        W[lost, near[lost]] = 1.0
    for key, kd in (("midline_arms", "arm"), ("midline_legs", "leg")):  # per recipe, fraction of H:
        mid = spec.get(key)  # near x = 0 limb weight moves to the trunk bone the limb hangs from. Tidecaller's
        if not mid:          # hood back and Waylayer's tunic front took Left and Right about equally, and the
            continue         # top-4 cut kept one side at random. Legs move the thigh only: chibi feet are near x = 0.
        f = np.clip(1 - np.abs(co[:, 0]) / (mid * H), 0, 1)
        for k, bone in enumerate(bones):
            root = bone.parent
            while root and limb(root.name) == kd:
                root = root.parent
            if kind[k] == kd and root and root.name in col and (kd == "arm" or bone.parent == root):
                W[:, col[root.name]] += W[:, k] * f
                W[:, k] *= 1 - f
    W /= np.maximum(W.sum(1, keepdims=True), 1e-9)
    boxed = 0
    for name, lo, hi in spec.get("weight_boxes", []):  # [bone, [x,y,z] min, max], fractions of H; Left mirrors to Right
        sides = [(name, 1)] + ([(name.replace("Left", "Right"), -1)] if name.startswith("Left") else [])
        for nm, s in sides:
            p = co / H * np.array([s, 1, 1])
            m = np.all((p >= lo) & (p <= hi), axis=1)
            W[m] = 0
            W[m, col[nm]] = 1
            boxed += int(m.sum())
    if boxed:
        log("weight boxes took", boxed, "verts")
    for g in list(vg):
        vg.remove(g)
    groups = [vg.new(name=b.name) for b in bones]
    for v in range(nv):
        for k in np.nonzero(W[v] > .01)[0]:
            groups[k].add([v], float(W[v, k]), "REPLACE")
    log("tidy: dropped", dropped, "arm/leg cross weights; smoothed", int(mask.sum()), "loose verts")


def attach_prop(arm, J, config=None):
    config = spec if config is None else config
    prop = import_glb(config["prop_glb"])
    prop.name = spec["name"] + "_prop_" + config["prop_hand"]
    fit(prop, float(config.get("prop_length", .5 * H)), ground=False)
    v = verts(prop)
    grip_z = {"top": v[:, 2].max(), "bottom": v[:, 2].min(), "centre": 0}[config.get("prop_grip", "bottom")]
    distance = np.abs(v[:, 2] - grip_z)
    grip = v[distance <= max(.04 * H, float(distance.min()) + 1e-6)].mean(0)
    prop.location = (-grip[0], -grip[1], -grip[2])
    only([prop])
    bpy.ops.object.transform_apply(location=True)
    prop.rotation_euler = [math.radians(d) for d in config.get("prop_rot", (0, 0, 0))]
    bpy.ops.object.transform_apply(rotation=True)
    hand = config["prop_hand"]
    prop.location = J[hand + "Tip"] + Vector(config.get("prop_offset", (0, 0, 0)))
    bpy.ops.object.transform_apply(location=True)
    only([prop, arm])
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    pivot = "PropPivot" if hand == spec.get("prop_hand") else hand
    arm.data.bones.active = arm.data.bones[pivot]
    bpy.ops.object.mode_set(mode="OBJECT")
    only([prop, arm])
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="BONE", keep_transform=True)
    return prop


# ---- animation: rotations are authored about WORLD axes and converted to each bone's rest frame.
# Character faces -Y. For a bone pointing down (leg, hanging arm) -X swings it forward;
# for a bone pointing up (spine) +X bows it forward. Z turns, Y leans sideways.
X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)


def q(pb, rots):
    rest = pb.bone.matrix_local.to_3x3().inverted()
    out = Quaternion()
    for axis, deg in rots:
        out = out @ Quaternion((rest @ Vector(axis)).normalized(), math.radians(deg))
    return out


def fwd(pb, rots):
    """Creatures: (X, deg) on a limb swings it forward whatever way the bone points at rest.
    World X does that only for a hanging bone; an arm held out sideways twists on its own length
    (Gloomslime's slam stretched 454 edges). Applied per bone after mirror(), so mirror stays exact.
    Humanoid clips and tails keep world X."""
    if PLAN == "humanoid" or limb(pb.name) in ("trunk", "tail"):
        return rots
    a = (pb.bone.tail_local - pb.bone.head_local).normalized().cross(Vector((0, -1, 0)))
    if a.length < .3:  # a bone along the facing axis has no clear forward swing
        return rots
    a = tuple(a.normalized())
    return [(a, -d) if ax == X else (ax, d) for ax, d in rots]


def mirror(pose):
    """Swap Left/Right and mirror the motion across the X=0 plane."""
    out = {}
    for k, v in pose.items():
        k2 = k.replace("Left", "@").replace("Right", "Left").replace("@", "Right")
        if k == "loc":
            out[k] = (-v[0], v[1], v[2])
        else:
            out[k2] = [(a, d if a == X else -d) for a, d in v]
    return out


def clip(arm, name, keys):
    """keys: [(frame, pose)]. A loop repeats its first pose as its last key."""
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    arm.animation_data_create()
    arm.animation_data.action = act
    pbs = arm.pose.bones
    names = [pb.name for pb in pbs]  # key every bone, so no pose leaks from the previous clip
    relax = float(spec.get("arm_relax", 25 if PLAN == "humanoid" else 0))  # skin in the A-pose, play with arms nearer the sides
    base = {"LeftUpperArm": [(Y, relax)], "RightUpperArm": [(Y, -relax)]}
    for f, pose in keys:
        for pb in pbs:
            pb.rotation_mode = "QUATERNION"
        for n in names:
            pb = pbs[n]
            pb.rotation_quaternion = q(pb, fwd(pb, pose.get(n, [])) + base.get(n, []))  # last in the list = applied first
            pb.keyframe_insert("rotation_quaternion", frame=f)
        hips = pbs["Hips"]
        d = Vector(pose.get("loc", (0, 0, 0)))
        hips.location = hips.bone.matrix_local.to_3x3().inverted() @ (d * H)
        hips.keyframe_insert("location", frame=f)
    act.frame_range = (keys[0][0], keys[-1][0])
    arm.animation_data.action = None
    log("clip", name, "frames", keys[0][0], keys[-1][0])
    return act


def clips(arm):
    """Poses are authored with the prop in the LEFT hand and mirrored for a right-hand prop.
    +Y adducts a left arm (in), -Y raises it sideways. +Z turns the torso to its left."""
    side = (lambda p: p) if spec.get("prop_hand", "LeftHand") == "LeftHand" else mirror
    rest = {}
    breathe = {"Chest": [(X, 2)], "UpperChest": [(X, 2)], "Head": [(X, -2)],
               "LeftUpperArm": [(Y, 2)], "RightUpperArm": [(Y, -2)], "loc": (0, 0, -.004)}
    out = [clip(arm, "idle", [(1, rest), (30, breathe), (60, rest)])]
    step = {"LeftUpperLeg": [(X, -24)], "LeftLowerLeg": [(X, 10)], "RightUpperLeg": [(X, 20)],
            "RightLowerLeg": [(X, 28)], "LeftUpperArm": [(X, 16)], "RightUpperArm": [(X, -16)],
            "Hips": [(Z, -5)], "Chest": [(X, 4), (Z, 8)], "loc": (0, 0, -.012)}
    passing = {"LeftUpperLeg": [(X, 4)], "LeftLowerLeg": [(X, 6)], "RightUpperLeg": [(X, -6)],
               "RightLowerLeg": [(X, 34)], "Chest": [(X, 4)], "loc": (0, 0, .006)}
    out.append(clip(arm, "walk", [(1, step), (8, passing), (16, mirror(step)), (24, mirror(passing)), (32, step)]))
    hurt = {"Spine": [(X, -10)], "Chest": [(X, -8)], "Head": [(X, -14)], "LeftUpperArm": [(Y, -14), (X, 10)],
            "RightUpperArm": [(Y, 14), (X, 10)], "LeftUpperLeg": [(X, 6)], "RightUpperLeg": [(X, 6)], "loc": (0, .03, -.01)}
    out.append(clip(arm, "hurt", [(1, rest), (5, hurt), (16, rest)]))
    knee = float(spec.get("kneel_bend", 1))  # per recipe: AshAcolyte's robe tore over the folded legs
    kneel = {"Spine": [(X, 18)], "Chest": [(X, 14)], "Head": [(X, 20)], "LeftUpperLeg": [(X, -70 * knee)],
             "LeftLowerLeg": [(X, 110 * knee)], "RightUpperLeg": [(X, -10 * knee)], "RightLowerLeg": [(X, 100 * knee)],
             "LeftUpperArm": [(X, -10)], "RightUpperArm": [(X, -10)], "loc": (0, 0, -.22)}
    bend = float(spec.get("fall_bend", 1))  # per recipe: DrownedOne's short trunk tore folding 110 degrees
    fall = dict(kneel, Spine=[(X, 50 * bend)], Chest=[(X, 30 * bend)], Head=[(X, 30 * bend)],
                LeftUpperArm=[(X, -40)], RightUpperArm=[(X, -40)], loc=(0, -.12, -.32))
    out.append(clip(arm, "death", [(1, rest), (14, kneel), (30, fall), (40, fall)]))
    lift = float(spec.get("arm_lift", 1))  # per recipe: AshAcolyte's chest tore under the raised arm
    cast = side({"RightUpperArm": [(X, -75 * lift)], "RightLowerArm": [(X, -30)], "LeftUpperArm": [(X, 10)],
                 "Chest": [(X, -6)], "Head": [(X, -6)], "loc": (0, 0, .01)})
    if spec.get("cast_hand") == "prop":  # an ember bowl is lifted, not the empty hand
        cast = mirror(cast)
    out.append(clip(arm, "cast", [(1, rest), (10, cast), (22, cast), (32, rest)]))
    if spec.get("attack") == "swing":  # lantern: draw it back, then heave it round and up in front
        wind = {"LeftUpperArm": [(X, 35 * lift), (Y, -10)], "Spine": [(Z, 18)], "PropPivot": [(X, 40)],
                "RightUpperLeg": [(X, -8)], "loc": (0, .01, -.02)}
        hit = {"LeftUpperArm": [(X, -100 * lift)], "LeftLowerArm": [(X, -15)], "Spine": [(Z, -22), (X, 10)],
               "PropPivot": [(X, -50)], "LeftUpperLeg": [(X, -18)], "LeftLowerLeg": [(X, 12)], "loc": (0, -.04, -.02)}
    else:  # blade: raise it over the lead shoulder, then cut down across the body
        wind = {"LeftUpperArm": [(X, -140 * lift), (Y, -15)], "LeftLowerArm": [(X, -30)], "Spine": [(Z, 15)],
                "Chest": [(Z, 10), (X, -6)], "loc": (0, .01, 0)}
        hit = {"LeftUpperArm": [(X, -50 * lift), (Y, 40)], "LeftLowerArm": [(X, -10)], "Spine": [(Z, -20), (X, 10)],
               "Chest": [(Z, -10), (X, 6)], "LeftUpperLeg": [(X, -20)], "LeftLowerLeg": [(X, 15)],
               "RightUpperLeg": [(X, 10)], "loc": (0, -.04, -.03)}
    out.append(clip(arm, "attack", [(1, rest), (9, side(wind)), (14, side(hit)), (20, side(hit)), (32, rest)]))
    return out


def rp(table):
    """A creature pose from per-role rotations, e.g. {"spine": [(X, 4)], "legFL": [(X, -20)]}.
    "root" is the Hips bone; "loc" moves the root (fractions of H). Every spine bone bends,
    so a bend spreads along the trunk. -X lifts a forward bone and bends an upright one back."""
    out = {"loc": table.get("loc", (0, 0, 0))}
    for b, r in ROLE.items():
        if r in table:
            out[b] = list(table[r])
    return out


def custom_clips(arm):
    roles = set(ROLE.values())
    quad, biped, arms = "legFL" in roles, "legL" in roles, "armL" in roles
    rest = {}
    out = [clip(arm, "idle", [
        (1, rest),
        (20, rp({"spine": [(X, 2)], "head": [(X, -3)], "tail": [(Z, 7)], "sway": [(Y, 5)],
                 "armL": [(Y, 3)], "armR": [(Y, -3)], "loc": (0, 0, -.006)})),
        (40, rp({"spine": [(X, 1)], "head": [(X, 2)], "tail": [(Z, -7)], "sway": [(Y, -5)], "loc": (0, 0, -.003)})),
        (60, rest)])]
    if quad:  # diagonal pairs: left fore with right hind
        a = rp({"legFL": [(X, -22)], "legHR": [(X, -18)], "legFR": [(X, 18)], "legHL": [(X, 20)],
                "spine": [(Z, 3)], "tail": [(Z, -8)], "head": [(X, 3)], "loc": (0, 0, -.01)})
        p = rp({"legFR": [(X, -4)], "legFR2": [(X, 35)], "legHL": [(X, -4)], "legHL2": [(X, 35)], "loc": (0, 0, .012)})
    elif biped:
        a = rp({"legL": [(X, -24)], "legL2": [(X, 10)], "legR": [(X, 20)], "legR2": [(X, 28)],
                "armL": [(X, 14)], "armR": [(X, -14)], "root": [(Z, -5)], "sway": [(Y, 6)], "loc": (0, 0, -.012)})
        p = rp({"legL": [(X, 4)], "legR": [(X, -6)], "legR2": [(X, 34)], "loc": (0, 0, .008)})
    else:  # no legs: waddle from side to side, with a small hop at each passing
        a = rp({"root": [(Y, 7)], "spine": [(Y, -2)], "armL": [(X, -14)], "armR": [(X, 14)], "sway": [(Y, -6)]})
        p = rp({"spine": [(X, 3)], "loc": (0, -.01, .035)})
    out.append(clip(arm, "walk", [(1, a), (8, p), (16, mirror(a)), (24, mirror(p)), (32, a)]))
    out.append(clip(arm, "hurt", [(1, rest), (5, rp({
        "spine": [(X, -6)], "neck": [(X, -6)], "head": [(X, -10)], "tail": [(X, 12)], "sway": [(X, 10)],
        "armL": [(Y, -16)], "armR": [(Y, 16)], "loc": (0, .03, -.01)})), (16, rest)]))
    cast = rp({"spine": [(X, -6)], "neck": [(X, -18 if quad else -6)], "head": [(X, -14)], "tail": [(X, 18)],
               "sway": [(X, -12)], "armL": [(Y, -float(spec.get("cast_lift", 70)))],
               "armR": [(Y, float(spec.get("cast_lift", 70)))], "armL2": [(X, -20)], "armR2": [(X, -20)],
               "loc": (0, 0, .012)})
    out.append(clip(arm, "cast", [(1, rest), (10, cast), (22, cast), (32, rest)]))
    style = spec.get("attack", "lunge" if quad else "slam" if arms else "butt")
    if style == "lunge":  # crouch, then spring forward and snap the head down
        wind = rp({"spine": [(X, -4)], "neck": [(X, -10)], "head": [(X, -10)], "legFL": [(X, 10)], "legFR": [(X, 10)],
                   "legHL": [(X, -12)], "legHR": [(X, -12)], "tail": [(X, 15)], "loc": (0, .05, -.05)})
        hit = rp({"spine": [(X, 6)], "neck": [(X, 8)], "head": [(X, 22)], "legFL": [(X, -30)], "legFR": [(X, -26)],
                  "legHL": [(X, 18)], "legHR": [(X, 18)], "tail": [(X, -5)], "loc": (0, -.16, -.02)})
    elif style == "slam":  # both arms up over the head, then down onto the target
        lift = float(spec.get("slam_lift", 150))  # a distance-weighted blob tears its front past ~70
        wind = rp({"spine": [(X, -10)], "head": [(X, -8)], "armL": [(X, -lift), (Y, 10)], "armR": [(X, -lift), (Y, -10)],
                   "armL2": [(X, -20)], "armR2": [(X, -20)], "sway": [(X, -10)], "loc": (0, .03, .01)})
        hit = rp({"spine": [(X, 22)], "head": [(X, 10)], "armL": [(X, -45)], "armR": [(X, -45)],
                  "sway": [(X, 14)], "legL": [(X, -14)], "legR": [(X, 8)], "loc": (0, -.08, -.05)})
    else:  # "butt": rear back, then ram forward with the head
        wind = rp({"spine": [(X, -14)], "head": [(X, -10)], "sway": [(X, -12)], "legL": [(X, 8)], "legR": [(X, 8)],
                   "loc": (0, .06, -.03)})
        hit = rp({"spine": [(X, 20)], "head": [(X, 14)], "sway": [(X, 18)], "legL": [(X, -20)], "legR": [(X, 10)],
                  "loc": (0, -.14, -.01)})
    out.append(clip(arm, "attack", [(1, rest), (9, wind), (14, hit), (20, hit), (32, rest)]))
    if spec.get("death", "side" if quad else "slump") == "side":  # fold, then roll onto the right flank
        sag = rp({"spine": [(X, 6)], "head": [(X, 18)], "legFL2": [(X, 30)], "legFR2": [(X, 30)],
                  "legHL": [(X, -15)], "legHR": [(X, -15)], "loc": (0, 0, -.1)})
        down = rp({"root": [(Y, 80)], "head": [(X, 12)], "tail": [(X, -10)], "legFL": [(X, -10)],
                   "legHL": [(X, 10)], "loc": (0, 0, -float(spec.get("death_drop", .38)))})
    else:  # slump forward and sink
        knee = {"legL": [(X, -60)], "legL2": [(X, 100)], "legR": [(X, -60)], "legR2": [(X, 100)]}
        sag = rp({"spine": [(X, 10)], "head": [(X, 15)], "sway": [(X, 12)], "loc": (0, 0, -.06)})
        down = rp(dict(knee, spine=[(X, 22)], head=[(X, 25)], root=[(Y, 18)], sway=[(X, 35)],
                       armL=[(Y, -25), (X, -15)], armR=[(Y, 25), (X, -15)],
                       loc=(0, -.04, -float(spec.get("death_drop", .25)))))
    out.append(clip(arm, "death", [(1, rest), (14, sag), (30, down), (40, down)]))
    return out


# ---- review renders
def camera(loc, look, ortho=None):
    cam = bpy.data.objects.get("ReviewCam") or bpy.data.objects.new("ReviewCam", bpy.data.cameras.new("ReviewCam"))
    if cam.name not in bpy.context.scene.objects:
        bpy.context.collection.objects.link(cam)
    cam.location = loc
    cam.rotation_euler = (Vector(look) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    cam.data.type = "ORTHO" if ortho else "PERSP"
    if ortho:
        cam.data.ortho_scale = ortho
    cam.data.lens = 50
    bpy.context.scene.camera = cam


def pose_bounds(arm, action, meshes):
    arm.animation_data.action = action
    first, last = action.frame_range
    points = []
    for index in range(8):
        bpy.context.scene.frame_set(round(first + (last - first) * index / 7))
        graph = bpy.context.evaluated_depsgraph_get()
        for obj in meshes:
            evaluated = obj.evaluated_get(graph)
            points.extend(evaluated.matrix_world @ Vector(corner) for corner in evaluated.bound_box)
    return points


def frame_camera(points, direction):
    lo = Vector(tuple(min(point[axis] for point in points) for axis in range(3)))
    hi = Vector(tuple(max(point[axis] for point in points) for axis in range(3)))
    centre = (lo + hi) / 2
    direction = Vector(direction).normalized()
    rotation = (-direction).to_track_quat("-Z", "Y")
    right, up = rotation @ Vector((1, 0, 0)), rotation @ Vector((0, 1, 0))
    width = 2 * max(abs((point - centre).dot(right)) for point in points)
    height = 2 * max(abs((point - centre).dot(up)) for point in points)
    scene = bpy.context.scene
    aspect = scene.render.resolution_x / scene.render.resolution_y
    camera(centre + direction * max((hi - lo).length * 3, H), centre,
           ortho=max(height, width / aspect) * 1.12)


def stage():
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.film_transparent = False
    sc.render.resolution_x, sc.render.resolution_y = 512, 640
    sc.render.fps = FPS
    w = bpy.data.worlds.new("w")
    sc.world = w
    if w.node_tree is None:
        w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (.32, .32, .34, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    for name, rot, e in (("key", (50, 0, -30), 2.2), ("fill", (60, 0, 140), .8)):
        l = bpy.data.objects.new(name, bpy.data.lights.new(name, "SUN"))
        l.data.energy = e
        l.rotation_euler = [math.radians(a) for a in rot]
        bpy.context.collection.objects.link(l)


def shot(path):
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path


def sheet(paths, cols, out):
    imgs = [bpy.data.images.load(p) for p in paths]
    w, h = imgs[0].size
    rows = (len(imgs) + cols - 1) // cols
    canvas = np.ones((rows * h, cols * w, 4), dtype=np.float32)
    for i, im in enumerate(imgs):
        px = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)
        r, c = divmod(i, cols)
        canvas[(rows - 1 - r) * h:(rows - r) * h, c * w:(c + 1) * w] = px
    o = bpy.data.images.new("sheet", cols * w, rows * h, alpha=True)
    o.pixels = canvas.ravel()
    o.filepath_raw, o.file_format = out, "PNG"
    o.save()
    for im in imgs:
        bpy.data.images.remove(im)
    for p in paths:
        os.remove(p)


def overlay(J, v):
    mat = bpy.data.materials.new("marker")
    if mat.node_tree is None:
        mat.use_nodes = True
    mat.node_tree.nodes["Principled BSDF"].inputs["Emission Color"].default_value = (1, 0, 0, 1)
    mat.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = 5
    marks = []
    for k, p in J.items():
        bpy.ops.mesh.primitive_uv_sphere_add(radius=.012 * H, location=(p.x, v[:, 1].min() - .05 * H, p.z))
        m = bpy.context.object
        m.data.materials.append(mat)
        marks.append(m)
    camera((0, -4 * H, .5 * H), (0, 0, .5 * H), ortho=1.15 * H * FRAME)
    shot(os.path.join(OUT, "joints.png"))
    for m, p in zip(marks, J.values()):  # side: markers in front of the +X flank, forward is image left
        m.location = (v[:, 0].max() + .05 * H, p.y, p.z)
    camera((4 * H, 0, .5 * H), (0, 0, .5 * H), ortho=1.15 * H * FRAME)
    shot(os.path.join(OUT, "joints-side.png"))
    for m in marks:
        bpy.data.objects.remove(m)


def probe():
    """Front and side ortho shots of the fitted body with a 0.1 H grid, to read joints from.
    Bold lines every 0.5 H; x = 0 and y = 0 are the bold centre lines; side view: -y is left."""
    W, Hp = 512, 640
    ppm = Hp / (1.15 * H * FRAME)
    tiles = []
    for loc, tag in (((0, -4 * H, .5 * H), "f"), ((4 * H, 0, .5 * H), "s")):
        camera(loc, (0, 0, .5 * H), ortho=1.15 * H * FRAME)
        p = shot(os.path.join(OUT, f"_probe{tag}.png"))
        im = bpy.data.images.load(p)
        px = np.array(im.pixels[:], dtype=np.float32).reshape(Hp, W, 4)
        for k in range(-30, 31):
            a = .6 if k % 5 == 0 else .25
            r = int(round(Hp / 2 + (k * .1 * H - .5 * H) * ppm))  # z = k/10 H, rows count up from the bottom
            c = int(round(W / 2 + k * .1 * H * ppm))  # x (front) or y (side) = k/10 H
            if 0 <= r < Hp:
                px[r, :, :3] = px[r, :, :3] * (1 - a) + a
            if 0 <= c < W:
                px[:, c, :3] = px[:, c, :3] * (1 - a) + a
        tiles.append(px)
        bpy.data.images.remove(im)
        os.remove(p)
    canvas = np.concatenate(tiles, axis=1)
    o = bpy.data.images.new("probe", canvas.shape[1], canvas.shape[0], alpha=True)
    o.pixels = canvas.ravel()
    o.filepath_raw, o.file_format = os.path.join(OUT, "probe.png"), "PNG"
    o.save()
    log("probe", os.path.join(OUT, "probe.png"), "frame", round(FRAME, 2))


def main():
    global FRAME
    bpy.ops.wm.read_factory_settings(use_empty=True)
    body = import_glb(spec["body_glb"])
    body.name = spec["name"]
    fit(body, H, rotate_z=float(spec.get("rotate_z", 0)))
    v = verts(body)
    FRAME = max(1.0, float(np.ptp(v[:, :2], axis=0).max()) / (.9 * H))
    log("tris", sum(len(p.vertices) - 2 for p in body.data.polygons), "verts", len(v),
        "extent", [round(float(e) / H, 2) for e in np.ptp(v, axis=0)])
    stage()
    if spec.get("probe"):
        probe()
        return
    if PLAN == "quad":
        spec["bones"] = quad_bones(v, float(spec.get("hip_z", .5)))
        json.dump(spec["bones"], open(os.path.join(OUT, "bones.json"), "w"), indent=1)
    if PLAN == "humanoid":
        J, chain = landmarks(v, spec.get("joints", {}), spec.get("joints_sym")), CHAIN
    else:
        J, chain = custom_chain()
    overlay(J, v)
    arm = build_armature(J, chain)
    bad = skin(body, arm)
    if spec.get("prop_glb"):
        attach_prop(arm, J)
    for prop_spec in spec.get("props", []):
        attach_prop(arm, J, prop_spec)
    only([body])
    bpy.ops.object.vertex_group_limit_total(limit=4)
    bpy.ops.object.vertex_group_normalize_all(lock_active=False)
    if spec.get("motion") in ("robe", "float", "swim"):
        import runpy
        motion = runpy.run_path(os.path.join(os.path.dirname(__file__), "candidate_motions.py"))
        acts = motion["robed" if spec["motion"] == "robe" else "drift"](arm, globals())
    else:
        acts = clips(arm) if PLAN == "humanoid" else custom_clips(arm)
    meshes = [obj for obj in bpy.data.objects if obj.type == "MESH"]
    arm.animation_data.action = acts[0]
    bpy.context.scene.frame_set(int(acts[0].frame_range[0]))
    graph = bpy.context.evaluated_depsgraph_get()
    points = [obj.evaluated_get(graph).matrix_world @ Vector(corner)
              for obj in meshes for corner in obj.evaluated_get(graph).bound_box]
    paths = []
    for i, ang in enumerate((0, 90, 180, 270)):
        a = math.radians(ang)
        frame_camera(points, (math.sin(a), -math.cos(a), .1))
        paths.append(shot(os.path.join(OUT, f"_v{i}.png")))
    sheet(paths, 4, os.path.join(OUT, "views.png"))
    views = (((2.2, -3.2, .42), "q"), ((4, 0, .05), "s"))
    for act in acts:
        points = pose_bounds(arm, act, meshes)
        f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
        frames = [round(f0 + (f1 - f0) * i / 7) for i in range(8)]
        paths = []
        for direction, tag in views:
            frame_camera(points, direction)
            for i, f in enumerate(frames):
                bpy.context.scene.frame_set(f)
                paths.append(shot(os.path.join(OUT, f"_{act.name}{tag}{i}.png")))
        sheet(paths, 8, os.path.join(OUT, f"clip-{act.name}.png"))
    arm.animation_data.action = acts[0]
    bpy.context.scene.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, spec["name"] + ".blend"))
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, spec["name"] + ".glb"), export_format="GLB",
                              export_animations=True, export_animation_mode="ACTIONS")
    log("done unweighted", bad, "clips", [a.name for a in acts])


main()
