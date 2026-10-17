# Gravewarden round 4: skeleton, rigid forward kinematics and clips, in numpy.
# The Blender build keys exactly these poses, so contact and arcs can be checked without Blender:
#   python3 -I gravewarden_round4_motion.py fitted.npz out-dir
# Poses rotate each bone about armature axes through its head, in its parent's posed frame (the
# same convention as char_rig.q). X pitches: -X swings a hanging limb forward (-Y), +X leans the
# upright chest forward. Every limb joint is a hinge about X: the shoulder is a turret whose cut is
# normal to X, so it slides in its own plane; the elbow cut is a cylinder about its hinge axis,
# so pitch slides the rim along it; the hip, knee and ankle are planar cuts filled by balls.
import json
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import round4_segments as seg  # noqa: E402

X = (1, 0, 0)
Y = (0, 1, 0)
Z = (0, 0, 1)
GROUND = .002  # ground_candidate.py keeps the lowest vertex here
CONTACT = .01  # a piece is in contact within 1 cm of the ground


def skeleton(m):
    """(bone, head, tail, parent) in metres. Pivots are the measured joint centres."""
    bones = [("Hips", (0, 0, seg.HIP_Z), (0, 0, .75), None),
             ("Chest", (0, .05, seg.WAIST_Z), (0, .05, 1.6), "Hips"),
             ("Finial", (0, .38, seg.FINIAL_Z), (0, .38, 2.4), "Chest")]
    for side, d in m.items():
        sh, el = d["shoulder"], d["elbow"]
        lx, ly = d["leg_axis"]
        bones += [(side + "UpperArm", tuple(sh), tuple(el), "Chest"),
                  (side + "LowerArm", tuple(el), (el[0], el[1], .25), side + "UpperArm"),
                  (side + "UpperLeg", (lx, ly, seg.HIP_Z), (lx, ly, seg.KNEE_Z), "Hips"),
                  (side + "LowerLeg", (lx, ly, seg.KNEE_Z), (lx, ly, seg.ANKLE_Z), side + "UpperLeg"),
                  (side + "Foot", (lx, ly, seg.ANKLE_Z), (lx, ly - .22, .06), side + "LowerLeg")]
    return bones


def fillers(m):
    """Dark stone fillers, each skinned to the parent bone of its joint and hidden at rest:
    (name, kind, centre, radius, parent, x span). Balls fill the planar hip, knee and ankle cuts;
    a drum coaxial with the elbow hinge fills the opening side of the cylindrical elbow cut."""
    out = []
    for side, d in m.items():
        lx, ly = d["leg_axis"]
        lr = d["leg_radius"]
        out += [(side + "Elbow", "drum", tuple(d["elbow"]), d["elbow_drum_radius"], side + "UpperArm", tuple(d["elbow_drum_x"])),
                (side + "Hip", "drum", (lx, ly, seg.HIP_Z), seg.HIP_SOCKET_R * .93, "Hips", (lx - lr * .72, lx + lr * .72)),
                (side + "Knee", "drum", (lx, ly, seg.KNEE_Z), seg.KNEE_CUFF_R * .93, side + "UpperLeg", (lx - lr * .7, lx + lr * .7)),
                (side + "Ankle", "ball", (lx, ly, seg.ANKLE_Z), .82 * lr, side + "LowerLeg", None)]
    return out


def rot(axis, deg):
    a = np.asarray(axis, float) / np.linalg.norm(axis)
    t = np.radians(deg)
    k = np.array([[0, -a[2], a[1]], [a[2], 0, -a[0]], [-a[1], a[0], 0]])
    return np.eye(3) + np.sin(t) * k + (1 - np.cos(t)) * k @ k


def deform(bones, pose):
    """bone -> 4x4 deform matrix (world from rest). Rotations listed first apply last."""
    out = {}
    for name, head, _, parent in bones:
        r = np.eye(3)
        for axis, deg in pose.get(name, []):
            r = r @ rot(axis, deg)
        h = np.asarray(head, float)
        g = np.eye(4)
        g[:3, :3] = r
        g[:3, 3] = h - r @ h
        if parent is None:
            g[:3, 3] += pose.get("loc", (0, 0, 0))
        out[name] = (out[parent] @ g) if parent else g
    return out


class Body:
    """Rigid piece points (face corners plus filler samples) and their bones."""

    def __init__(self, co, tris, lab, m):
        self.m, self.bones = m, skeleton(m)
        pts = co[tris].reshape(-1, 3)
        bone = np.repeat(np.array(seg.PIECES)[lab], 3)
        u, v = np.meshgrid(np.linspace(0, np.pi, 9), np.linspace(0, 2 * np.pi, 17))
        unit = np.c_[(np.sin(u) * np.cos(v)).ravel(), (np.sin(u) * np.sin(v)).ravel(), np.cos(u).ravel()]
        a, t = np.meshgrid(np.linspace(0, 2 * np.pi, 25), np.linspace(0, 1, 9))
        ball_pts, ball_bone = [], []
        for _, kind, c, r, parent, span in fillers(m):
            if kind == "ball":
                q = np.asarray(c) + r * unit
            else:
                q = np.c_[span[0] + (span[1] - span[0]) * t.ravel(), c[1] + r * np.cos(a.ravel()), c[2] + r * np.sin(a.ravel())]
            ball_pts.append(q)
            ball_bone += [parent] * len(q)
        self.p = np.vstack([pts] + ball_pts)
        self.bone = np.concatenate([bone, ball_bone])
        self.ball = np.r_[np.zeros(len(pts), bool), np.ones(len(ball_bone), bool)]
        self.names = [b[0] for b in self.bones]

    def posed(self, pose):
        d = deform(self.bones, pose)
        out = np.empty_like(self.p)
        for name in self.names:
            on = self.bone == name
            out[on] = self.p[on] @ d[name][:3, :3].T + d[name][:3, 3]
        return out

    def low(self, pose, names):
        q = self.posed(pose)
        return float(q[np.isin(self.bone, names), 2].min())

    def grounded(self, pose):
        """Set the root height so the lowest point sits at GROUND, as the bake will."""
        pose = dict(pose)
        loc = list(pose.get("loc", (0, 0, 0)))
        loc[2] = 0
        pose["loc"] = tuple(loc)
        loc[2] = GROUND - float(self.posed(pose)[:, 2].min())
        pose["loc"] = tuple(loc)
        return pose


class Volumes:
    """Rest volumes of the blocks that can collide: leg pieces as vertical cylinders about the
    measured leg axis, sabatons and fists as boxes. A shell point of another piece that enters a
    volume in a pose, and was not inside it at rest (the fused, hidden overlaps), is a collision.
    Fillers are meant to sit inside other pieces, so they never count."""

    SHRINK = .01  # ignore grazing contact under 1 cm

    def __init__(self, body):
        self.body = body
        self.vol = {}
        for side, d in body.m.items():
            lx, ly = d["leg_axis"]
            for n in ("UpperLeg", "LowerLeg"):
                z = body.p[(body.bone == side + n) & ~body.ball][:, 2]
                self.vol[side + n] = ("cyl", np.array([lx, ly]), d["leg_radius"] - self.SHRINK, z.min() + self.SHRINK, z.max() - self.SHRINK)
            for n in ("Foot", "LowerArm"):
                q = body.p[(body.bone == side + n) & ~body.ball]
                self.vol[side + n] = ("box", q.min(0) + self.SHRINK, q.max(0) - self.SHRINK)
        self.rest = {k: self._inside(k, body.p) for k in self.vol}

    def _inside(self, name, local):
        v = self.vol[name]
        if v[0] == "cyl":
            r = v[2] - np.hypot(local[:, 0] - v[1][0], local[:, 1] - v[1][1])
            return np.minimum(r, np.minimum(local[:, 2] - v[3], v[4] - local[:, 2]))
        return np.minimum((local - v[1]).min(1), (v[2] - local).min(1))

    def collisions(self, pose, skip_elbow=True):
        """(volume, entering piece) -> max new depth in m. The elbow pair is measured separately
        (elbow_clearance): the fist box holds the tower's cuff band, which a box cannot follow."""
        b = self.body
        d = deform(b.bones, pose)
        world = b.posed(pose)
        out = {}
        for name in self.vol:
            g = d[name]
            local = (world - g[:3, 3]) @ g[:3, :3]
            new = (self._inside(name, local) > 0) & (self.rest[name] <= 0) & ~b.ball & (b.bone != name)
            if skip_elbow and name.endswith("LowerArm"):
                new &= b.bone != name.replace("Lower", "Upper")
            if new.any():
                depth = self._inside(name, local)
                for other in np.unique(b.bone[new]):
                    on = new & (b.bone == other)
                    out[(name, str(other))] = round(float(depth[on].max()), 3)
        return out


def elbow_clearance(body, side, el, step=3):
    """Closest approach (m) between the fist shell and the tower shell when the elbow pitches to
    `el`, counting only point pairs at least 3 cm apart at rest. The cylinder cut keeps it open
    over the measured range; it closes where the outer faces meet."""
    b = body
    c = np.asarray(b.m[side]["elbow"])
    near = np.linalg.norm(b.p - c, axis=1) < .45
    fist = b.p[(b.bone == side + "LowerArm") & ~b.ball & near][::step]
    tower = b.p[(b.bone == side + "UpperArm") & ~b.ball & near][::step]
    r = rot(X, el)
    posed = (fist - c) @ r.T + c
    best = np.inf
    for i in range(0, len(posed), 400):
        dr = np.linalg.norm(fist[i:i + 400, None] - tower[None], axis=2)
        dp = np.linalg.norm(posed[i:i + 400, None] - tower[None], axis=2)
        dp[dr < .03] = np.inf
        best = min(best, float(dp.min()))
    return best


def bisect(f, lo, hi, it=40):
    """Root of a monotonic f on [lo, hi]."""
    flo = f(lo)
    for _ in range(it):
        mid = (lo + hi) / 2
        if (f(mid) > 0) == (flo > 0):
            lo, flo = mid, f(mid)
        else:
            hi = mid
    return (lo + hi) / 2


# --- Clips -------------------------------------------------------------------------------------
# A key is (frame, spec). Specs name world-meaningful channels; stance() turns them into bones.
# The whole reliquary moves as one through the Hips: P pitches it (+ forward), R rolls it (+ drops
# the left hip), W yaws it (+ turns the left side back). The Chest piece holds the pelvis block
# that the thigh tops sit in, so the Chest hardly moves against the Hips (cx stays within 2
# degrees). Each thigh keeps zero pitch against the pelvis plus its own small offset t, and
# cancels the roll so the leg stays plumb (the walk is the only clip that rolls). Knees (k) bend;
# each sabaton keeps its world pitch (toe, + lifts the heel) and does not yaw with the body. Arms
# are (shoulder, elbow) pitches. The root x and y keep each planted ankle on its target, and the
# bake sets the height.
SIDES = ("Left", "Right")
CHANNELS = ["P", "R", "W", "tL", "tR", "kL", "kR", "toeL", "toeR", "shL", "elL", "shR", "elR", "cx", "fin"]


def pair(v):
    return tuple(v) if isinstance(v, (tuple, list)) else (v, v)


def vector(spec):
    t, k, toe = pair(spec.get("t", 0)), pair(spec.get("k", 0)), pair(spec.get("toe", 0))
    arm = spec.get("arm", (0, 0))
    arm = arm if isinstance(arm[0], (tuple, list)) else (arm, arm)
    return np.array([spec.get("P", 0), spec.get("R", 0), spec.get("W", 0), *t, *k, *toe,
                     *arm[0], *arm[1], spec.get("cx", 0), spec.get("fin", 0)], float)


def stance(v):
    """Channel vector -> pose (bone rotation lists, no root location)."""
    ch = dict(zip(CHANNELS, v))
    pose = {"Hips": [(Z, ch["W"]), (X, ch["P"]), (Y, ch["R"])], "Chest": [(X, ch["cx"])],
            "Finial": [(X, ch["fin"])]}
    for s in SIDES:
        c = s[0]
        t, k = ch["t" + c], ch["k" + c]
        pose[s + "UpperLeg"] = [(Y, -ch["R"]), (X, t)]
        pose[s + "LowerLeg"] = [(X, k)]
        pose[s + "Foot"] = [(X, -(ch["P"] + t + k)), (Z, -ch["W"]), (X, ch["toe" + c])]
        pose[s + "UpperArm"] = [(X, ch["sh" + c])]
        pose[s + "LowerArm"] = [(X, ch["el" + c])]
    return pose


def pchip(xs, ys, x):
    """Monotone cubic through keys (rows of ys): no overshoot, flat at extrema and clip ends."""
    xs, ys = np.asarray(xs, float), np.asarray(ys, float)
    h = np.diff(xs)
    d = np.diff(ys, axis=0) / h[:, None]
    m = np.zeros_like(ys)
    for i in range(1, len(xs) - 1):
        w1, w2 = 2 * h[i] + h[i - 1], h[i] + 2 * h[i - 1]
        same = d[i - 1] * d[i] > 0
        m[i] = np.where(same, (w1 + w2) / np.where(same, w1 / np.where(same, d[i - 1], 1) + w2 / np.where(same, d[i], 1), 1), 0)
    i = int(min(max(np.searchsorted(xs, x, side="right") - 1, 0), len(xs) - 2))
    s = (x - xs[i]) / h[i]
    return ((2 * s ** 3 - 3 * s ** 2 + 1) * ys[i] + (s ** 3 - 2 * s ** 2 + s) * h[i] * m[i]
            + (-2 * s ** 3 + 3 * s ** 2) * ys[i + 1] + (s ** 3 - s ** 2) * h[i] * m[i + 1])


class Clip:
    """Keys -> one exact pose per integer frame. The build keys every frame with linear
    interpolation, so Blender plays these poses and the bake only re-solves the height.
    `treadmill` (m per frame) makes an in-place travel cycle: each planted ankle slides back at
    that speed while it is down, and a key's `plant` names the sides that are down."""

    def __init__(self, body, keys, treadmill=0.0):
        self.body, self.keys, self.speed = body, keys, treadmill
        self.frames = [f for f, _ in keys]
        self.v = np.array([vector(s) for _, s in keys])
        heads = dict((b[0], np.asarray(b[1], float)) for b in body.bones)
        self.rest_ankle = {s: heads[s + "Foot"] for s in SIDES}
        self._xy = {}
        self._targets()
        self.grip_from = min((f for f, sp in keys if sp.get("grip")), default=None)
        self._grip = None

    def spec_at(self, frame):
        i = max(0, int(np.searchsorted(self.frames, frame, side="right")) - 1)
        return self.keys[i][1]

    def angles(self, frame):
        return pchip(self.frames, self.v, frame)

    def ankles(self, pose):
        d = deform(self.body.bones, dict(pose, loc=(0, 0, 0)))
        return {s: (d[s + "Foot"] @ np.r_[self.rest_ankle[s], 1])[:3] for s in SIDES}

    def _targets(self):
        """Root x, y per frame. A planted sabaton rolls without slipping: the sabaton point that
        is lowest in a frame keeps the ground position it had in the frame before (so a lifting
        heel pivots on the toe edge, and a flat sabaton stays put). On the treadmill that point
        slides back (+Y) by `speed` a frame. A loop's residual closure error is spread over the
        cycle. A side that has just touched down keeps where it lands."""
        b = self.body
        foot = {s: (b.bone == s + "Foot") & ~b.ball for s in SIDES}
        rows, before, down = [], None, set()
        for f in range(self.frames[0], self.frames[-1] + 1):
            plant = set(self.spec_at(f).get("plant", SIDES))
            pose = stance(self.angles(f))
            d = deform(b.bones, dict(pose, loc=(0, 0, 0)))
            if before is None:
                a = self.ankles(pose)
                root = np.mean([self.rest_ankle[s][:2] - a[s][:2] for s in plant], 0)
            else:
                moved = []
                for s in plant & down:
                    g = d[s + "Foot"]
                    c = b.p[foot[s]][np.argmin(b.p[foot[s]] @ g[2, :3])]
                    moved.append((before[s + "Foot"] @ np.r_[c, 1])[:2] - (g @ np.r_[c, 1])[:2] + (0, self.speed))
                root = rows[-1] + (np.mean(moved, 0) if moved else 0)
            rows.append(root)
            before, down = d, plant
        rows = np.array(rows)
        if self.speed:
            rows -= np.outer(np.linspace(0, 1, len(rows)), rows[-1] - rows[0])
        self._xy = {f: rows[i] for i, f in enumerate(range(self.frames[0], self.frames[-1] + 1))}

    def pose(self, frame):
        spec = self.spec_at(frame)
        pose = stance(self.angles(frame))
        xy = self._xy[frame]
        pose["loc"] = (xy[0], xy[1], 0)
        if spec.get("grip") and frame > self.grip_from:
            if self._grip is None:  # the fists plant where they land on the first grip frame
                landed = self.pose(self.grip_from)
                self._grip = {s: contact_point(self.body, landed, s) for s in SIDES}
            pose = grip(self.body, pose, self._grip)
        return self.body.grounded(pose)


def grip(body, pose, targets):
    """Re-solve shoulder and elbow pitch so each planted fist's contact point keeps its ground
    position (target y, at its rest height above the lowest point of the rest of the body).
    Both joints hinge about X, so the arm is a planar two-link chain in the chest's frame: solved
    in closed form, taking the more folded of the two legal bends (elbow at most -2 degrees).
    Returns the pose; pose["grip_miss"] is the largest distance (m) left to a target."""
    b = body
    q = b.posed(pose)
    ground = q[~np.isin(b.bone, [s + n for s in SIDES for n in ("UpperArm", "LowerArm")]), 2].min()
    d = deform(b.bones, pose)
    heads = dict((n, np.asarray(h, float)) for n, h, _, _ in b.bones)
    pose, miss = dict(pose), 0.0
    for s in SIDES:
        point, y_t, dz = targets[s]
        g = d["Chest"]
        # Target in the chest's rest frame (rotations about X keep x).
        want = g[:3, :3].T @ (np.array([0.0, y_t, ground + dz]) - g[:3, 3])
        sh0, el0 = heads[s + "UpperArm"][1:], heads[s + "LowerArm"][1:]
        u1, u2, t = el0 - sh0, point[1:] - el0, want[1:] - sh0
        l1, l2, dist = np.linalg.norm(u1), np.linalg.norm(u2), np.linalg.norm(t)
        ang = lambda v: np.degrees(np.arctan2(v[1], v[0]))
        c = np.clip((dist ** 2 - l1 ** 2 - l2 ** 2) / (2 * l1 * l2), -1, 1)
        rel0 = ang(u2) - ang(u1)  # forearm direction against the upper arm at rest
        best = None
        for bend in (np.degrees(np.arccos(c)), -np.degrees(np.arccos(c))):
            el = bend - rel0
            el = (el + 180) % 360 - 180
            if el > -2:
                continue
            # Shoulder: the chain end must point at the target.
            k1 = l1 + l2 * np.cos(np.radians(bend))
            k2 = l2 * np.sin(np.radians(bend))
            sh = ang(t) - np.degrees(np.arctan2(k2, k1)) - ang(u1)
            sh = (sh + 180) % 360 - 180
            if best is None or el < best[1]:  # under load the elbow folds forward
                best = (sh, el)
        if best is None:  # only a hyperextended solution reaches: hold the elbow at -2
            best = (pose[s + "UpperArm"][0][1], -2.0)
        pose[s + "UpperArm"], pose[s + "LowerArm"] = [(X, best[0])], [(X, best[1])]
        w = deform(b.bones, pose)[s + "LowerArm"]
        hit = w[:3, :3] @ point + w[:3, 3]
        miss = max(miss, float(np.hypot(hit[1] - y_t, hit[2] - ground - dz)))
    pose["grip_miss"] = miss
    return pose


def contact_point(body, pose, side):
    """The fist's lowest centimetre in this pose: rest coordinates, world y, height above the
    fist's lowest point."""
    q = body.posed(pose)
    on = (body.bone == side + "LowerArm") & ~body.ball
    low = on & (q[:, 2] < q[on, 2].min() + .01)
    return body.p[low].mean(0), float(q[low, 1].mean()), float(q[low, 2].mean() - q[on, 2].min())


def lift_fists(body, vol, spec):
    """Flex each elbow forward, 1 degree at a time, until its fist clears its own sabaton and leg.
    Returns the spec with the new arm angles."""
    v = vector(spec)
    for s in SIDES:
        e = CHANNELS.index("el" + s[0])
        for _ in range(40):
            hits = vol.collisions(stance(v))
            if not any(s + "LowerArm" in pair_ and any(n.startswith(s) and n[len(s):] in ("Foot", "LowerLeg", "UpperLeg") for n in pair_)
                       for pair_ in hits):
                break
            v[e] -= 1
    out = dict(spec)
    out["arm"] = (tuple(v[9:11]), tuple(v[11:13]))
    return out


def clips(body):
    """name -> Clip at 30 FPS. Frame ranges match the previous candidates."""
    vol = Volumes(body)
    out = {}
    out["idle"] = [(1, {}), (20, {"P": .6, "arm": (-1.5, -1)}), (35, {"P": 1, "arm": (-2.5, -2)}),
                   (50, {"P": .3, "arm": (-.8, -1)}), (60, {})]
    out["attack"] = [(1, {}),
                     (6, {"P": -3, "k": 5, "arm": (-45, -15)}),
                     (12, {"P": -9, "k": 8, "arm": (-150, -25)}),
                     (14, {"P": -10, "k": 9, "arm": (-156, -28)}),
                     (16, {"P": 3, "k": 12, "arm": (-112, -18)}),
                     (17, {"P": 12, "k": 16, "arm": (-74, -4)}),
                     (19, {"P": 13, "k": 17, "arm": (-72, -2)}),
                     (21, {"P": 10, "k": 14, "arm": (-79, -8)}),
                     (24, {"P": 11.5, "k": 15, "arm": (-73, -4)}),
                     (32, {})]
    out["cast"] = [(1, {}), (7, {"P": 2, "k": 8, "arm": (6, -8)}),
                   (14, {"P": -8, "k": 4, "arm": (-110, -22)}),
                   (18, {"P": -10, "k": 4, "arm": (-116, -26)}),
                   (22, {"P": -9, "k": 4, "arm": (-112, -23)}),
                   (32, {})]
    out["hurt"] = [(1, {}), (4, {"P": -10, "k": 6, "arm": (-12, -14)}),
                   (8, {"P": 3, "k": 4, "arm": (5, -6)}),
                   (12, {"P": -1, "k": 1, "arm": (0, -1)}), (16, {})]
    for name in list(out):
        out[name] = Clip(body, [(f, lift_fists(body, vol, s)) for f, s in out[name]])
    out["walk"] = walk(body, vol)
    out["death"] = death(body, vol)
    return {n: out[n] for n in ("idle", "walk", "attack", "cast", "hurt", "death")}


def walk(body, vol, swivel=14.0, roll=5.0, knee=18.0):
    """In-place stride, 32 frames. The reliquary swivels on its planted sabaton: the yaw carries
    the other leg forward while the planted one slides back on the treadmill, so both feet travel
    a real step. A roll onto the planted side, with the thighs counter-rolled, lifts the swinging
    sabaton, and its knee bends. The sabatons do not yaw. The Tripo legs stand 9 cm apart front to
    back, so the swivel is centred on the yaw that puts both ankles level: the body faces a few
    degrees off its path, and the legs stay plumb (angling one leg back instead would hold the
    ankle cut open all the time). Left is down over frames 1-17, right over 17-33."""
    probe = Clip(body, [(1, {}), (2, {})])
    a = probe.ankles(stance(vector({})))
    dx, dy = a["Left"][:2] - a["Right"][:2]
    centre = float(np.degrees(np.arctan2(-dy, dx)))

    def key(w, r, kl, kr, arm_l, arm_r, plant):
        return dict(W=centre + w, R=r, k=(kl, kr), arm=(arm_l, arm_r), plant=plant)
    both = SIDES
    keys = [(1, key(-swivel, 0, 2, 2, (-9, -6), (9, -2), both)),
            (2, key(-swivel * .97, roll * .1, 2, 3, (-9, -6), (9, -2), ("Left",))),
            (9, key(0, roll, 3, knee, (0, -4), (0, -4), ("Left",))),
            (17, key(swivel, 0, 2, 2, (9, -2), (-9, -6), both)),
            (18, key(swivel * .97, -roll * .1, 3, 2, (9, -2), (-9, -6), ("Right",))),
            (25, key(0, -roll, knee, 3, (0, -4), (0, -4), ("Right",))),
            (33, key(-swivel, 0, 2, 2, (-9, -6), (9, -2), both))]
    keys = [(f, lift_fists(body, vol, s)) for f, s in keys]
    probe = Clip(body, keys)
    # Treadmill speed: the planted ankle's travel against the root over each stance.
    travel = 0.0
    for s, f0, f1 in (("Left", 1, 17), ("Right", 17, 33)):
        travel += probe.ankles(stance(probe.angles(f1)))[s][1] - probe.ankles(stance(probe.angles(f0)))[s][1]
    return Clip(body, keys, treadmill=travel / 32)


def topple(p0, p1, w0=.9, height=2.4):
    """Pitch per frame (30 FPS) of a rigid block of `height` falling about its base edge from p0
    degrees, moving at w0 rad/s, until it reaches p1: theta'' = 3g/(2h) sin(theta)."""
    th, w, dt, out, t = np.radians(p0), w0, 1 / 3000, [], 0.0
    while th < np.radians(p1):
        w += 3 * 9.81 / (2 * height) * np.sin(th) * dt
        th += w * dt
        t += dt
        if t * 30 >= len(out) + 1:
            out.append(float(np.degrees(th)))
    return out


def death(body, vol, ankle=-20.0, knee=10.0, extra=0.0, ankle_end=-24.0, brake=5, rebound=1.0, reach=16.0):
    """Hit, a recoil, then the reliquary topples forward; the arms reach down and the fists land
    first, take the load and slow the fall (the elbows give over `brake` frames while the knees
    give and the ankles go slack); then the door frame lands, the body rocks back `rebound`
    degrees and settles, and the last 6 frames are still. The toes stay down throughout.
    Measured on the mesh: the legs cannot buckle the pelvis down. Flexing a hip 10-20 degrees
    drives the shin 4.5-9 cm into the skirt, and bending a knee with the thighs locked to the
    pelvis swings the shin back and lifts the body. So the pitch rides on the sabaton toes: each
    heel lifts once the ankle has flexed `ankle` degrees against the shin, which raises the root
    a little as the mass passes over the toes. A straight arm hanging plumb reaches the ground at
    about 55 degrees of pitch, well before the door frame (about 70 degrees with the toes down),
    so the fists can land first and the frame comes down onto them as the knees give and the
    ankles go slack. Arms swing only about X (turret shoulder), so the fists cannot slip outward.
    `rel` in a spec is the ankle angle against the shin; toe (world pitch) follows from it."""
    def flex(spec):
        spec = dict(spec)
        rel = spec.pop("rel", None)
        if rel is not None:
            spec["toe"] = max(0.0, spec.get("P", 0) + spec.get("t", 0) + spec.get("k", 0) + rel)
        return spec

    arms = np.isin(body.bone, [s + n for s in SIDES for n in ("UpperArm", "LowerArm")])
    fist = np.isin(body.bone, ["LeftLowerArm", "RightLowerArm"]) & ~body.ball
    feet = np.isin(body.bone, ["LeftFoot", "RightFoot"]) & ~body.ball
    chest = body.bone == "Chest"

    def gap(spec, lower, upper):
        q = body.posed(dict(stance(vector(flex(spec))), loc=(0, 0, 0)))
        return q[lower, 2].min() - q[upper, 2].min()

    # The fists land when straight arms, `reach` degrees ahead of plumb, reach the toes' level.
    # Then the knees give until the frame lands, while the body sinks `extra` degrees of pitch
    # onto the fists and the ankles flex to `ankle_end`. Landing the fists earlier (less reach)
    # folds the elbows past -60 degrees, where the left elbow cut starts to pinch.
    # A straight arm: shoulder, elbow pivot and fist bottom in line. At rest the fist bottom sits
    # off the line (each arm is built slightly bent backward), so straight is an elbow bend of
    # -rel0; from there the load folds the elbow forward smoothly. (Landing on the -2 degree stop
    # instead would make the elbow snap through straight as the load comes on.)
    heads = dict((n, np.asarray(h, float)) for n, h, _, _ in body.bones)
    ang = lambda v: np.degrees(np.arctan2(v[1], v[0]))
    off, rel0 = {}, {}
    for s_ in SIDES:
        on = (body.bone == s_ + "LowerArm") & ~body.ball
        bottom = body.p[on][np.argmin(body.p[on][:, 2])]
        u1 = (heads[s_ + "LowerArm"] - heads[s_ + "UpperArm"])[1:]
        rel0[s_] = ang(bottom[1:] - heads[s_ + "LowerArm"][1:]) - ang(u1)
        off[s_] = -90 - ang(u1)  # shoulder pitch that hangs the straight arm plumb

    def reach_arm(p, r, w=1.0):
        """Straight arms r[side] degrees ahead of plumb at body pitch p, blended from rest by w."""
        return tuple((-p - r[s_] + off[s_] * w, -rel0[s_] * w) for s_ in SIDES)

    r = {s_: reach for s_ in SIDES}
    p_fist = bisect(lambda p: gap({"P": p, "k": knee, "rel": ankle, "arm": reach_arm(p, r)}, fist, feet), 20, 80)
    toe_fist = p_fist + knee + ankle
    p_end, k_end = p_fist + extra, knee
    for _ in range(5):  # knee that lands the frame, with the ankle at ankle_end
        k_end = bisect(lambda k: gap({"P": p_end, "k": k, "rel": ankle_end}, chest, feet), 0, 70)
    toe_end = p_end + k_end + ankle_end
    keys = [(1, {}), (4, {"P": -6, "k": 3, "arm": (-2, -8)}), (8, {"P": 4, "k": 4, "arm": (-6, -8)})]
    fall = topple(4, p_fist)  # every frame of the fall before the fists land
    for i, pitch in enumerate(fall):
        u = (pitch - 4) / (p_fist - 4)
        k = 4 + (knee - 4) * u
        w = u * u * (3 - 2 * u)
        # The arms hang plumb as the body tips (they swing freely), then reach `reach` degrees
        # ahead and straighten as the ground nears.
        keys.append((9 + i, {"P": pitch, "k": k, "rel": max(-(pitch + k), ankle),
                             "arm": reach_arm(pitch, {s_: r[s_] * u * u for s_ in SIDES}, w)}))
    keys = [(f, lift_fists(body, vol, flex(sp))) for f, sp in keys]
    f1 = 9 + len(fall)
    arm = reach_arm(p_fist, r)
    keys.append((f1, dict(flex({"P": p_fist, "k": knee, "rel": ankle, "arm": arm}), grip=True)))
    # Braked descent onto the planted fists: the arms take the load, so it slows as the frame nears.
    for j in range(1, brake + 1):
        v = 1 - (1 - j / brake) ** 2
        keys.append((f1 + j, {"P": p_fist + extra * v, "k": knee + (k_end - knee) * v,
                              "toe": toe_fist + (toe_end - toe_fist) * v, "arm": arm, "grip": True}))
    f2 = f1 + brake
    end = {"P": p_end, "k": k_end, "toe": toe_end, "arm": arm}
    # Impact: the body rocks back on the frame edge and settles (a damped wobble), then holds.
    for j, dp in ((3, -rebound), (6, .4 * rebound), (9, -.12 * rebound), (11, 0.0)):
        keys.append((f2 + j, dict(end, P=p_end + dp, toe=end["toe"] + dp, grip=True)))
    keys.append((f2 + 17, dict(end, grip=True)))
    return Clip(body, keys)


def com(body, pose):
    """Area-weighted centroid of the posed shell: a stand-in for the centre of mass."""
    q = body.posed(pose)[~body.ball].reshape(-1, 3, 3)
    w = .5 * np.linalg.norm(np.cross(q[:, 1] - q[:, 0], q[:, 2] - q[:, 0]), axis=1)
    return (q.mean(1) * w[:, None]).sum(0) / w.sum()


def inside_hull(p, pts):
    """Is p (x, y) inside the convex hull of pts (n, 2)? Monotone chain."""
    pts = sorted(map(tuple, np.round(pts, 4)))
    cross = lambda o, a, b: (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lower, upper = [], []
    for q in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], q) <= 0:
            lower.pop()
        lower.append(q)
    for q in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], q) <= 0:
            upper.pop()
        upper.append(q)
    hull = lower[:-1] + upper[:-1]
    return all(cross(hull[i], hull[(i + 1) % len(hull)], p) >= 0 for i in range(len(hull)))


def contact_timeline(body, clip, vol=None):
    groups = {"feet": ["LeftFoot", "RightFoot"], "knees": ["LeftLowerLeg", "RightLowerLeg"],
              "fists": ["LeftLowerArm", "RightLowerArm"], "chest": ["Chest"]}
    rows = []
    for frame in range(clip.frames[0], clip.frames[-1] + 1):
        p = clip.pose(frame)
        q = body.posed(p)
        row = {"frame": frame, "root": [round(float(x), 4) for x in p["loc"]], "min_z": round(float(q[:, 2].min()), 4),
               "elbow": [round(float(p[s + "LowerArm"][0][1]), 1) for s in SIDES]}
        for name, bones in groups.items():
            row[name] = round(float(q[np.isin(body.bone, bones) & ~body.ball, 2].min()), 4)
        down = q[:, 2] < GROUND + CONTACT
        row["support"] = sorted(set(body.bone[down].tolist()))
        c = com(body, p)
        row["com_over_support"] = bool(inside_hull(c[:2], q[down][:, :2])) if down.sum() >= 3 else False
        for s in SIDES:
            a = deform(body.bones, p)[s + "Foot"] @ np.r_[clip.rest_ankle[s], 1]
            row["ankle" + s[0]] = [round(float(x), 4) for x in a[:3]]
        if vol is not None:
            row["collisions"] = {"/".join(k): d for k, d in vol.collisions(p).items()}
        rows.append(row)
    return rows


def main(npz, out):
    d = np.load(npz)
    co, tris = d["p"], d["f"]
    m, lab = seg.main(npz)
    body = Body(co, tris, lab, m)
    vol = Volumes(body)
    cl = clips(body)
    out = Path(out)
    out.mkdir(exist_ok=True)
    summary = {}
    for name, clip in cl.items():
        tl = contact_timeline(body, clip, vol)
        touching = {g: [r["frame"] for r in tl if r[g] - r["min_z"] < CONTACT] for g in ("feet", "knees", "fists", "chest")}
        worst = max(((dep, r["frame"], k) for r in tl for k, dep in r["collisions"].items()), default=None)
        elbows = [e for r in tl for e in r["elbow"]]
        summary[name] = {"keys": clip.frames, "treadmill_m_per_s": round(clip.speed * 30, 3),
                         "root_z": [min(r["root"][2] for r in tl), max(r["root"][2] for r in tl)],
                         "contact_frames": touching, "worst_collision": worst, "elbow_range": [min(elbows), max(elbows)]}
        (out / f"{name}-timeline.json").write_text(json.dumps(tl, indent=1) + "\n")
    print(json.dumps(summary, indent=1))
    return body, cl


if __name__ == "__main__":
    main(*sys.argv[1:3])
