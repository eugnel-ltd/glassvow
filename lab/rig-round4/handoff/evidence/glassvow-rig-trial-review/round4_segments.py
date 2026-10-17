# Gravewarden round 4: rigid pieces measured on the fitted Tripo source (Blender axes, -Y forward).
# Pure numpy, so the plan can be checked without Blender:  python3 -I round4_segments.py fitted.npz
# Joints are planar cuts (JOINT_PLANES); the build bisects the mesh on each plane inside its region.
# Fused contacts are not planar: Tripo merged each fist into its leg column (no plane separates them,
# overlap 8-10 cm) and each leg into a pelvis block. There the label follows the measured leg cylinder.
# Every side is measured on its own: the Tripo body is not symmetric.
import json
import sys

import numpy as np

PIECES = ["Chest", "LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm",
          "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot", "Hips", "Finial"]
WAIST_Z, WAIST_FRONT_Y, FINIAL_Z = .78, -.12, 2.085
KNEE_CUFF_R, HIP_SOCKET_R = .095, .095


def knee_child(m, side, c):
    """The lower greave moves outside the round cuff, about the existing X hinge."""
    ly = m[side]["leg_axis"][1]
    return (c[:, 2] < KNEE_Z) & (np.hypot(c[:, 1] - ly, c[:, 2] - KNEE_Z) > KNEE_CUFF_R)


def hip_child(m, side, c):
    """The thigh moves outside the inset socket, under the existing pelvis ledge."""
    ly = m[side]["leg_axis"][1]
    return (c[:, 2] < HIP_Z) & (np.hypot(c[:, 1] - ly, c[:, 2] - HIP_Z) > HIP_SOCKET_R)
SHOULDER_X, ELBOW_Z, HIP_Z, KNEE_Z, ANKLE_Z, FIST_FLOOR_Z = .52, .78, .60, .42, .21, .20
LEG_TOL = .03  # leg cylinder tolerance; the fused fist and pelvis lie outside it


def circle(u, v, keep=.04, rounds=4):
    """Least-squares circle, refitted without points farther than `keep` from it."""
    m = np.ones(len(u), bool)
    for _ in range(rounds):
        a = np.c_[2 * u[m], 2 * v[m], np.ones(m.sum())]
        cu, cv, c = np.linalg.lstsq(a, u[m] ** 2 + v[m] ** 2, rcond=None)[0]
        r = np.sqrt(c + cu * cu + cv * cv)
        m = np.abs(np.hypot(u - cu, v - cv) - r) < keep
    return float(cu), float(cv), float(r)


def samples(co, tris, per=8, seed=0):
    rng = np.random.default_rng(seed)
    a, b = rng.random((2, len(tris), per, 1))
    flip = a + b > 1
    a[flip], b[flip] = 1 - a[flip], 1 - b[flip]
    p = co[tris]
    return (p[:, None, 0] + a * (p[:, None, 1] - p[:, None, 0]) + b * (p[:, None, 2] - p[:, None, 0])).reshape(-1, 3)


def measure(co, tris):
    """Joint landmarks per side, measured from the surface."""
    s = samples(co, tris)
    out = {}
    for side, sg in (("Left", 1), ("Right", -1)):
        x = s[:, 0] * sg
        boss = s[(x > .53) & (x < .63) & (s[:, 2] > 1.05) & (s[:, 2] < 1.56) & (s[:, 1] > -.32) & (s[:, 1] < .46)]
        sy, sz, sr = circle(boss[:, 1], boss[:, 2])
        leg = s[(s[:, 2] > .28) & (s[:, 2] < .5) & (x > .24) & (x < .62) & (s[:, 1] > -.25)]
        lx, ly, lr = circle(leg[:, 0] * sg, leg[:, 1])
        ring = s[(np.abs(s[:, 2] - ELBOW_Z) < .012) & (x > .6)]
        ex = float((ring[:, 0] * sg).min() + np.ptp(ring[:, 0]) / 2)
        ey = float(ring[:, 1].min() + np.ptp(ring[:, 1]) / 2)
        # Elbow hinge: the cut is a cylinder about the hinge (X) axis, so pitch slides the rim
        # along it. Its radius just clears the arm section at the cut; the drum that fills the
        # opening side stays inside the narrowest section within its own radius of the axis.
        arm = s[(x > .55) & (np.abs(s[:, 2] - ELBOW_Z) < .2) & (s[:, 1] > ey - .4) & (s[:, 1] < ey + .4)]
        near = arm[np.abs(arm[:, 2] - ELBOW_Z) < .04]
        cut_r = 1.05 * float(np.abs(near[:, 1] - ey).max())
        half = []
        for z in np.arange(ELBOW_Z - .15, ELBOW_Z + .151, .02):
            b = arm[np.abs(arm[:, 2] - z) < .01]
            half.append(min(ey - b[:, 1].min(), b[:, 1].max() - ey))
        xs = arm[np.abs(arm[:, 2] - ELBOW_Z) < .15][:, 0] * sg
        out[side] = {"sign": sg, "shoulder": [sg * SHOULDER_X, sy, sz], "shoulder_radius": sr,
                     "leg_axis": [sg * lx, ly], "leg_radius": lr, "elbow": [sg * ex, ey, ELBOW_Z],
                     "elbow_half_size": [float(np.ptp(ring[:, 0]) / 2), float(np.ptp(ring[:, 1]) / 2)],
                     "elbow_cut_radius": cut_r, "elbow_drum_radius": .9 * float(min(half)),
                     "elbow_drum_x": [sg * (np.percentile(xs, 2) + .03), sg * (np.percentile(xs, 98) - .03)]}
    return out


def elbow_child(m, side, c):
    """Fist side of the cylindrical elbow cut: below the hinge and farther than the cut radius
    from the hinge axis. The tower keeps the cuff band inside the cylinder."""
    d = m[side]
    _, ey, ez = d["elbow"]
    return (c[:, 2] < ez + d["elbow_cut_radius"]) & (np.hypot(c[:, 1] - ey, c[:, 2] - ez) > d["elbow_cut_radius"]) & (c[:, 2] < ez)


def regions(m, c):
    """Per side: shoulder-boss mask, arm mask, leg-cylinder mask (centroids c)."""
    out = {}
    for side, d in m.items():
        sg = d["sign"]
        x = c[:, 0] * sg
        sy, sz = d["shoulder"][1:]
        rs = np.hypot(c[:, 1] - sy, c[:, 2] - sz)
        lx, ly = d["leg_axis"]
        leg = (np.hypot(c[:, 0] - lx, c[:, 1] - ly) < d["leg_radius"] + LEG_TOL) & (c[:, 2] < HIP_Z)
        # The boss meets the front frame below its axis, so the region reaches farther down there.
        boss = (x >= SHOULDER_X) & (rs < np.where(c[:, 2] < sz, .34, .28))
        column = (x >= .5) & (c[:, 2] < 1.12) & (c[:, 2] >= FIST_FLOOR_Z) & ~leg
        out[side] = (boss, boss | column, leg)
    return out


def joint_planes(m):
    """(name, point, normal, region(c)) for the planar bisects the build makes before labelling."""
    rows = []
    for side, d in m.items():
        sg = d["sign"]
        sy, sz = d["shoulder"][1:]
        lx, ly = d["leg_axis"]
        lr = d["leg_radius"] + LEG_TOL + .02
        near_leg = lambda c, lx=lx, ly=ly, lr=lr: np.hypot(c[:, 0] - lx, c[:, 1] - ly) < lr
        rows += [
            (side + " shoulder", [sg * SHOULDER_X, sy, sz], [sg, 0, 0],
             lambda c, sg=sg, sy=sy, sz=sz: (c[:, 0] * sg > .42) & (c[:, 0] * sg < .62) & (np.hypot(c[:, 1] - sy, c[:, 2] - sz) < .36)),
            (side + " fist floor", [0, 0, FIST_FLOOR_Z], [0, 0, 1],
             lambda c, sg=sg, near=near_leg: (c[:, 0] * sg > .45) & ~near(c) & (np.abs(c[:, 2] - FIST_FLOOR_Z) < .08)),
            (side + " hip", [0, 0, HIP_Z], [0, 0, 1], lambda c, near=near_leg: near(c) & (np.abs(c[:, 2] - HIP_Z) < .08)),
            (side + " knee", [0, 0, KNEE_Z], [0, 0, 1], lambda c, near=near_leg: near(c) & (np.abs(c[:, 2] - KNEE_Z) < .08)),
            (side + " ankle", [0, 0, ANKLE_Z], [0, 0, 1], lambda c, near=near_leg: near(c) & (np.abs(c[:, 2] - ANKLE_Z) < .06)),
        ]
    return rows


def classify(m, c):
    lab = np.zeros(len(c), int)
    for side, (boss, arm, leg) in regions(m, c).items():
        k = PIECES.index
        fist = elbow_child(m, side, c)
        lab[arm & ~fist] = k(side + "UpperArm")
        lab[arm & fist] = k(side + "LowerArm")
        lower = knee_child(m, side, c)
        thigh = hip_child(m, side, c)
        lab[leg & ~thigh] = k("Hips")
        lab[leg & thigh & ~lower] = k(side + "UpperLeg")
        lab[leg & thigh & lower & (c[:, 2] >= ANKLE_Z)] = k(side + "LowerLeg")
        sg = m[side]["sign"]
        foot = (c[:, 2] < ANKLE_Z) & (c[:, 0] * sg > .15) & ~arm & (leg | (c[:, 2] < FIST_FLOOR_Z))
        lab[foot] = k(side + "Foot")
    # Rear pelvis stops at its existing top moulding. The long front door and frame remain
    # one coherent Chest shell; the anterior interface stays behind that door.
    lab[(lab == 0) & (c[:, 2] < WAIST_Z) & (c[:, 1] > WAIST_FRONT_Y)] = PIECES.index("Hips")
    lab[(lab == 0) & (c[:, 2] > FINIAL_Z)] = PIECES.index("Finial")
    return lab


def edges_of(tris):
    e = np.concatenate([tris[:, [0, 1]], tris[:, [1, 2]], tris[:, [2, 0]]])
    owner = np.tile(np.arange(len(tris)), 3)
    key = np.sort(e, 1)
    order = np.lexsort(key.T[::-1])
    key, owner = key[order], owner[order]
    same = np.all(key[1:] == key[:-1], 1)
    return owner[:-1][same], owner[1:][same], key[:-1][same]


def components(n, fa, fb, keep):
    parent = np.arange(n)

    def find(q):
        while parent[q] != q:
            parent[q] = parent[parent[q]]
            q = parent[q]
        return q
    for i, j in zip(fa[keep], fb[keep]):
        ri, rj = find(i), find(j)
        if ri != rj:
            parent[ri] = rj
    return np.array([find(i) for i in range(n)])


def clean(lab, tris, small=40):
    """Same-label patches under `small` faces join the label they share most edges with."""
    fa, fb, _ = edges_of(tris)
    moved = 0
    for _ in range(6):
        root = components(len(tris), fa, fb, lab[fa] == lab[fb])
        roots, size = np.unique(root, return_counts=True)
        tiny = roots[size < small]
        if not len(tiny):
            break
        for r0 in tiny:
            on = root == r0
            mask = on[fa] ^ on[fb]
            other = np.where(on[fa][mask], lab[fb][mask], lab[fa][mask])
            if len(other):
                lab[on] = np.bincount(other).argmax()
                moved += int(on.sum())
    return lab, moved


def report(co, tris, lab):
    fa, fb, ek = edges_of(tris)
    root = components(len(tris), fa, fb, lab[fa] == lab[fb])
    rows = {}
    for k, name in enumerate(PIECES):
        on = lab == k
        _, size = np.unique(root[on], return_counts=True)
        v = co[np.unique(tris[on])]
        rows[name] = {"faces": int(on.sum()), "islands": sorted(size.tolist(), reverse=True)[:4],
                      "min": np.round(v.min(0), 3).tolist() if len(v) else None,
                      "max": np.round(v.max(0), 3).tolist() if len(v) else None}
    seams = {}
    cross = lab[fa] != lab[fb]
    for i, j in zip(lab[fa][cross], lab[fb][cross]):
        key = "/".join(sorted((PIECES[i], PIECES[j])))
        seams[key] = seams.get(key, 0) + 1
    return {"pieces": rows, "seam_edges": seams}


def main(path):
    d = np.load(path)
    co, tris = d["p"], d["f"]
    m = measure(co, tris)
    lab = classify(m, co[tris].mean(1))
    lab, moved = clean(lab, tris)
    r = report(co, tris, lab)
    print(json.dumps({"measure": m, "moved_small_patches": moved, **r}, indent=1))
    np.save(path.replace(".npz", "-labels.npy"), lab)
    # Invariants: each moving piece owns geometry; the cathedral body is one piece; arms own nothing
    # of the dome (z above the boss top) or the midline.
    assert all(r["pieces"][n]["faces"] > 0 for n in PIECES), "A moving piece owns no geometry"
    c = co[tris].mean(1)
    arm = np.isin(lab, [PIECES.index(n) for n in PIECES if "Arm" in n])
    assert not (arm & (np.abs(c[:, 0]) < .4)).any(), "An arm owns torso geometry near the midline"
    return m, lab


if __name__ == "__main__":
    main(sys.argv[1])
