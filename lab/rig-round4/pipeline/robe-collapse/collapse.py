# Offline robe-collapse death: skirt controls, skirt weights and a per-frame staged collapse.
# Pure numpy, so the motion can be iterated without Blender. Coordinates are the armature space
# of the exported rest data (armature at the origin): x is the character's left, -y its front, z up.
#   python3 collapse.py <character> <rest.npz> <out-dir> [--preview]
import json
import math
import sys
from pathlib import Path

import numpy as np

X, Y, Z = np.eye(3)


def rot(axis, deg):
    axis = np.asarray(axis, float)
    axis = axis / np.linalg.norm(axis)
    a = math.radians(deg)
    k = np.array([[0, -axis[2], axis[1]], [axis[2], 0, -axis[0]], [-axis[1], axis[0], 0]])
    return np.eye(3) + math.sin(a) * k + (1 - math.cos(a)) * k @ k


def between(a, b):
    """Smallest rotation taking direction a to direction b."""
    a, b = a / np.linalg.norm(a), b / np.linalg.norm(b)
    v, c = np.cross(a, b), float(a @ b)
    if c < -0.999999:
        return rot(np.cross(a, X if abs(a[0]) < .9 else Y), 180)
    k = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    return np.eye(3) + k + k @ k / (1 + c)


def unit(v):
    return v / max(np.linalg.norm(v), 1e-9)


def smooth(t):
    t = min(max(t, 0.0), 1.0)
    return t * t * (3 - 2 * t)


EASE = {"lin": lambda t: t, "in": lambda t: t * t, "out": lambda t: 1 - (1 - t) ** 2, "io": smooth}


def track(keys, f):
    """keys: [(frame, value, ease)], the ease shapes the segment arriving at that key."""
    if f <= keys[0][0]:
        return np.asarray(keys[0][1], float)
    for (f0, v0, _), (f1, v1, ease) in zip(keys, keys[1:]):
        if f <= f1:
            t = EASE[ease]((f - f0) / (f1 - f0))
            return (1 - t) * np.asarray(v0, float) + t * np.asarray(v1, float)
    return np.asarray(keys[-1][1], float)


class Rig:
    def __init__(self, path):
        d = np.load(path)
        self.d = d
        self.names = [str(n) for n in d["names"]]
        self.parent = {n: (str(p) or None) for n, p in zip(self.names, d["parents"])}
        self.rest = {n: m for n, m in zip(self.names, d["rest"])}
        self.length = {n: float(x) for n, x in zip(self.names, d["lengths"])}
        self.deform = {n: bool(x) for n, x in zip(self.names, d["deform"])}
        self.connect = {n: bool(x) for n, x in zip(self.names, d["connect"])}
        self.verts = d["verts"]
        self.tris = d["tris"]
        self.W = {n: d["weights"][:, i] for i, n in enumerate(self.names)}
        self.props = [(str(b), d[f"prop_verts_{i}"], d[f"prop_tris_{i}"]) for i, b in enumerate(d["prop_bones"])]

    def add(self, name, parent, matrix, length):
        self.names.append(name)
        self.parent[name], self.rest[name], self.length[name] = parent, matrix, length
        self.deform[name], self.connect[name] = True, False
        self.W[name] = np.zeros(len(self.verts))

    def head(self, n):
        return self.rest[n][:3, 3]

    def tail(self, n):
        return self.rest[n][:3, 3] + self.rest[n][:3, 1] * self.length[n]

    def rel(self, n):
        p = self.parent[n]
        return self.rest[n] if p is None else np.linalg.inv(self.rest[p]) @ self.rest[n]


def basis_rot(rig, n, rots):
    """char_rig.q(): world-axis rotations expressed in the bone's rest frame, first in the list applied last."""
    r = rig.rest[n][:3, :3]
    out = np.eye(3)
    for axis, deg in rots:
        out = out @ rot(r.T @ np.asarray(axis, float), deg)
    return out


def power(R, t):
    """Rotation R scaled to the fraction t of its angle."""
    a = math.acos(float(np.clip((np.trace(R) - 1) / 2, -1, 1)))
    if a < 1e-6 or t == 0:
        return np.eye(3)
    axis = np.array([R[2, 1] - R[1, 2], R[0, 2] - R[2, 0], R[1, 0] - R[0, 1]])
    if np.linalg.norm(axis) < 1e-6:  # half turn: the axis is the eigenvector of (R + I) / 2
        axis = np.linalg.eigh((R + np.eye(3)) / 2)[1][:, -1]
    return rot(axis, math.degrees(a) * t)


def mat(r, t=(0, 0, 0)):
    m = np.eye(4)
    m[:3, :3], m[:3, 3] = r, t
    return m


def swing(fk, direction):
    """Rotate a bone's FK matrix about its head so its Y axis points along direction."""
    m = fk.copy()
    m[:3, :3] = between(fk[:3, 1], direction) @ fk[:3, :3]
    return m


def two_bone(root, target, l1, l2, pole, soft=0.0):
    d = target - root
    dist = float(np.linalg.norm(d))
    near = l1 + l2 - soft
    if soft > 0 and dist > near:  # soft IK: the reach eases towards full length, so a straight joint never snaps
        dist = near + soft * (1 - math.exp(-(dist - near) / soft))
    dist = float(np.clip(dist, abs(l1 - l2) + 1e-4, l1 + l2 - 1e-4))
    u = unit(d)
    v = unit(pole - (pole @ u) * u)
    ca = (l1 * l1 + dist * dist - l2 * l2) / (2 * l1 * dist)
    knee = root + l1 * (ca * u + math.sqrt(max(0.0, 1 - ca * ca)) * v)
    return knee, root + dist * u


def seg_dist(p, a, b):
    s = b - a
    t = float(np.clip((p - a) @ s / max(s @ s, 1e-12), 0, 1))
    q = a + t * s
    return float(np.linalg.norm(p - q)), q


# ---------------------------------------------------------------- skirt controls and weights
def build_skirt(rig, cfg):
    """Radial two-bone chains on the robe surface below the waist, parented to Hips."""
    v, n = rig.verts, cfg["chains"]
    hips = rig.head("Hips")
    zw = hips[2] + cfg.get("waist_offset", 0.0)
    cy = hips[1]
    arm = sum(rig.W[b] for b in rig.names if any(k in b for k in ("Shoulder", "Arm", "Hand")))
    phi = np.arctan2(v[:, 0], -(v[:, 1] - cy))
    rad = np.hypot(v[:, 0], v[:, 1] - cy)
    zk = zw * cfg.get("knee_fraction", .5)
    chains = []
    for k in range(n):
        a = 2 * math.pi * k / n
        wedge = (np.abs((phi - a + math.pi) % (2 * math.pi) - math.pi) < math.pi / n) & (arm < .5)
        def surface(z, band=.05):
            m = wedge & (np.abs(v[:, 2] - z) < band)
            return float(np.percentile(rad[m], 70)) if m.sum() > 3 else float(np.percentile(rad[wedge & (v[:, 2] < zw)], 70))
        out = np.array([math.sin(a), -math.cos(a), 0.0])
        pts = [np.array([0, cy, 0]) + surface(z) * out + np.array([0, 0, z]) for z in (zw, zk, cfg.get("hem_z", .02))]
        names = []
        # A runs down the surface from the waist to knee height; B points straight down from there to
        # the floor plane, so scaling B along its length never pushes the inner hem cap below the floor.
        for s, (h, t) in enumerate(((pts[0], pts[1]), (pts[1], pts[1] * np.array([1, 1, 0])))):
            yaxis = unit(t - h)
            zaxis = unit(out - (out @ yaxis) * yaxis)
            m = mat(np.column_stack([np.cross(yaxis, zaxis), yaxis, zaxis]), h)
            name = f"Skirt{k}{'AB'[s]}"
            rig.add(name, "Hips", m, float(np.linalg.norm(t - h)))
            names.append(name)
        chains.append({"angle": a, "out": out, "bones": names})
    return chains, zw


def skirt_weights(rig, chains, zw, cfg):
    v, n = rig.verts, len(chains)
    hips = rig.head("Hips")
    arm_bones = [b for b in rig.names if any(k in b for k in ("Shoulder", "Arm", "Hand"))]
    leg_bones = [b for b in rig.names if any(k in b for k in ("Leg", "Foot", "Toes")) and not b.startswith("Skirt")]
    arm = sum(rig.W[b] for b in arm_bones)
    region = (v[:, 2] < zw + cfg.get("waist_band", .05)) & (arm < .5)
    if not cfg.get("keep_feet"):  # legs equal Hips in every other robed clip; only the skirt may follow them
        for b in leg_bones:
            rig.W["Hips"] += np.where(~region, rig.W[b], 0)
            rig.W[b] = np.where(~region, 0, rig.W[b])
    shoe = np.zeros(len(v))
    if cfg.get("keep_feet"):
        r0, r1 = cfg["shoe_radius"]
        for side in ("Left", "Right"):
            d = np.array([seg_dist(p, rig.head(side + "Foot"), rig.tail(side + "Toes"))[0] for p in v])
            shoe = np.maximum(shoe, 1 - np.clip((d - r0) / (r1 - r0), 0, 1))
        shoe *= v[:, 2] < cfg.get("shoe_z", .14)
    phi = (np.arctan2(v[:, 0], -(v[:, 1] - hips[1])) % (2 * math.pi)) / (2 * math.pi) * n
    k0 = np.floor(phi).astype(int) % n
    k1 = (k0 + 1) % n
    a = phi - np.floor(phi)
    t = np.clip((zw - v[:, 2]) / zw, 0, 1)
    lo, hi = cfg.get("mid_blend", (.38, .68))
    s = np.array([smooth((x - lo) / (hi - lo)) for x in t])
    h = 1 - np.array([smooth(x / cfg.get("hips_fade", .16)) for x in t])
    # The hem cap's centre has no direction of its own: it follows its owner chains and the chains opposite them.
    rr = np.hypot(v[:, 0], v[:, 1] - hips[1])
    centre = np.array([1 - smooth(x / cfg.get("cap_radius", .18)) for x in rr]) * (v[:, 2] < zw * cfg.get("knee_fraction", .5))
    moved = 0
    # Only the Hips and leg share moves to the skirt (a skirt bone at rest equals Hips), so every other
    # clip deforms as before; arm and other trunk weights stay where they were.
    for i in np.nonzero(region)[0]:
        keep = {b: rig.W[b][i] for b in rig.names if rig.W[b][i] > 0 and b != "Hips" and b not in leg_bones}
        share = rig.W["Hips"][i] + sum(rig.W[b][i] for b in leg_bones)
        legs = {b: rig.W[b][i] for b in leg_bones if rig.W[b][i] > 0}
        f = shoe[i] if sum(legs.values()) > .05 else 0.0
        for b in rig.names:
            rig.W[b][i] = keep.get(b, 0.0)
        rig.W["Hips"][i] += share * (1 - f) * h[i]
        # Each owner chain shares c / 2 of its weight with the chain opposite it: a radial flare cancels
        # in each pair, and the weights stay continuous from one sector to the next.
        spread = {}
        for kk, wa in ((k0[i], 1 - a[i]), (k1[i], a[i])):
            spread[kk] = spread.get(kk, 0) + (1 - centre[i] / 2) * wa
            spread[(kk + n // 2) % n] = spread.get((kk + n // 2) % n, 0) + centre[i] / 2 * wa
        for kk, wa in spread.items():
            A, B = chains[kk]["bones"]
            rig.W[A][i] += share * (1 - f) * (1 - h[i]) * wa * (1 - s[i])
            rig.W[B][i] += share * (1 - f) * (1 - h[i]) * wa * s[i]
        for b, w in legs.items():
            rig.W[b][i] += share * f * w / sum(legs.values())
        moved += 1
    # Top four influences, normalised: the export limit, applied here so the preview matches.
    M = np.column_stack([rig.W[b] for b in rig.names])
    order = np.argsort(-M, axis=1)
    keep = np.zeros_like(M, dtype=bool)
    np.put_along_axis(keep, order[:, :4], True, axis=1)
    M = np.where(keep, M, 0)
    M /= np.maximum(M.sum(1, keepdims=True), 1e-9)
    for j, b in enumerate(rig.names):
        rig.W[b] = M[:, j]
    return {"reweighted": int(moved), "shoe_verts": int((shoe > .5).sum())}


# ---------------------------------------------------------------- pose evaluation
def fk_all(rig, basis):
    P = {}
    for n in rig.names:  # parents precede children in export order; skirt bones were appended after Hips
        p = rig.parent[n]
        P[n] = (rig.rest[n] if p is None else P[p] @ rig.rel(n)) @ basis.get(n, np.eye(4))
    return P


def set_world(rig, P, basis, n, M):
    """Record the basis that puts bone n at armature-space matrix M, given its parent's pose."""
    p = rig.parent[n]
    base = rig.rest[n] if p is None else P[p] @ rig.rel(n)
    basis[n] = np.linalg.inv(base) @ M
    P[n] = M


def fk_of(rig, P, n):
    p = rig.parent[n]
    return rig.rest[n] if p is None else P[p] @ rig.rel(n)


def skin(rig, P, mask=None):
    v = rig.verts if mask is None else rig.verts[mask]
    vh = np.c_[v, np.ones(len(v))]
    out = np.zeros((len(v), 3))
    for n in rig.names:
        w = rig.W[n] if mask is None else rig.W[n][mask]
        if not rig.deform[n] or not w.any():
            continue
        S = P[n] @ np.linalg.inv(rig.rest[n])
        out += w[:, None] * (vh @ S[:3].T)
    return out


# ---------------------------------------------------------------- the staged collapse
def pose_frame(rig, cfg, f, state):
    """FK curves, leg and arm IK and the floor lift for one frame. Returns P and basis."""
    m = cfg["motion"]
    basis = {}
    for n, keys in m["fk"].items():
        rots = [(axis, float(deg)) for axis, deg in zip((X, Y, Z), track(keys, f))]
        basis[n] = mat(basis_rot(rig, n, rots))
    loc = track(m["hips_loc"], f) + np.array([0, 0, state.get("lift", 0.0)])
    roll = m.get("roll")
    if roll and f >= roll["start"] and "pivot" in state:
        # Topple about the support point, not the pelvis centre: the roll added since the start
        # swings the pelvis round the pivot (the support knee where the roll began).
        turn = rot(roll["axis"], float(track(m["fk"]["Hips"], f) @ roll["axis"] - state["roll0"]))
        start = state["hips0"]
        loc = loc + (state["pivot"] + turn @ (start - state["pivot"])) - start
    basis["Hips"][:3, 3] = rig.rest["Hips"][:3, :3].T @ loc
    P = fk_all(rig, basis)
    hips = P["Hips"]
    turn = hips[:3, :3] @ rig.rest["Hips"][:3, :3].T  # body rotation from rest
    # Legs: ankle targets blend from the floor (planted) to the pelvis frame (folded legs ride along).
    for side, leg in m["legs"].items():
        up, lo, foot = side + "UpperLeg", side + "LowerLeg", side + "Foot"
        world = track(leg["ankle"], f)
        if "ride_from" not in state.setdefault(side, {}) and f >= leg["ride"][0]:
            state[side]["ride_from"] = np.linalg.inv(hips) @ np.r_[world, 1]
        ride = smooth((f - leg["ride"][0]) / (leg["ride"][1] - leg["ride"][0]))
        target = world if ride <= 0 else (1 - ride) * world + ride * (hips @ state[side]["ride_from"])[:3]
        target[2] = max(target[2], leg["min_ankle_z"])
        pole = turn @ unit(np.asarray(leg["pole"], float))
        root = fk_of(rig, P, up)[:3, 3]
        w = float(track(leg.get("ik", [(1, [1], "lin")]), f)[0])  # 0: the rest leg, 1: soft IK to the target
        fk_ankle = (fk_of(rig, P, up) @ rig.rel(lo) @ np.r_[0, rig.length[lo], 0, 1])[:3]
        knee, ankle = two_bone(root, (1 - w) * fk_ankle + w * target, rig.length[up], rig.length[lo], pole, w * leg.get("soft", 0.0))
        set_world(rig, P, basis, up, swing(fk_of(rig, P, up), knee - root))
        set_world(rig, P, basis, lo, swing(fk_of(rig, P, lo), ankle - knee))
        point = float(track(leg["point"], f)[0])  # 0: foot flat as at rest, 1: foot follows the shin
        fk = fk_of(rig, P, foot)
        tuck = unit(np.asarray(leg.get("tuck", (0, -.35, -.94)), float))
        aim = unit((1 - point) * rig.rest[foot][:3, 1] + point * (turn @ tuck if f >= leg["ride"][0] else tuck))
        reach = rig.length[foot] + rig.length[side + "Toes"]
        tip = ankle[2] + reach * aim[2]
        if tip < leg.get("min_toe_z", .03):  # level the foot: the toes rest on the floor, never below it
            flat_dir = unit(aim * np.array([1, 1, 0]) if np.linalg.norm(aim[:2]) > .2 else unit(ankle - knee) * np.array([1, 1, 0]))
            sa = np.clip((leg.get("min_toe_z", .03) - ankle[2]) / reach, -1, 1)
            aim = flat_dir * math.sqrt(1 - sa * sa) + np.array([0, 0, sa])
        set_world(rig, P, basis, foot, swing(fk, aim))
        for n in (side + "Toes",):
            P[n] = P[foot] @ rig.rel(n)
    if roll and f >= roll["start"] - 1 and "pivot" not in state:
        knee = P[roll["support"]][:3, 3] * np.array([1, 1, 0])  # the floor under the support knee
        state["pivot"], state["hips0"] = knee, P["Hips"][:3, 3].copy()
        state["roll0"] = float(track(m["fk"]["Hips"], f) @ roll["axis"])
    # Arms: FK, then an IK blend toward a floor target (catch) or a landing path.
    for side, a in m["arms"].items():
        w = float(track(a["ik"], f)[0])
        if w <= 0:
            continue
        up, lo, hand = side + "UpperArm", side + "LowerArm", side + "Hand"
        root = fk_of(rig, P, up)[:3, 3]
        fk_hand = P[hand][:3, 3]
        if "target" in a:
            target = np.asarray(track(a["target"], f), float)
        else:  # lock the hand where it is when the blend starts
            target = state.setdefault("lock_" + side, fk_hand.copy())
        target = (1 - w) * fk_hand + w * target
        pole = unit(np.asarray(a["pole"], float))
        pole = pole if a.get("pole_world") else turn @ pole
        mask = state.setdefault("mask_" + side, (rig.W[hand] + rig.W[lo]) > .3)
        tries = 8 if a.get("plant") else 1
        for it in range(tries):
            elbow, wrist = two_bone(root, target, rig.length[up], rig.length[lo], pole)
            set_world(rig, P, basis, up, swing(fk_of(rig, P, up), elbow - root))
            set_world(rig, P, basis, lo, swing(fk_of(rig, P, lo), wrist - elbow))
            if not a.get("plant"):
                break
            # Palm flat: the hand turns level along the forearm, then the wrist rises until it rests on the floor.
            flat = unit((wrist - elbow) * np.array([1, 1, 0]))
            aim = unit((1 - w) * fk_of(rig, P, hand)[:3, 1] + w * flat)
            set_world(rig, P, basis, hand, swing(fk_of(rig, P, hand), aim))
            gap = cfg["floor"]["solid"] - skin(rig, P, mask)[:, 2].min()
            if gap <= 1e-4 or it == tries - 1:
                break
            target = target + np.array([0, 0, gap])
        for n in (hand, "PropPivot") if side + "Hand" == cfg.get("prop_hand") else (() if a.get("plant") else (hand,)):
            P[n] = P[rig.parent[n]] @ rig.rel(n) @ basis.get(n, np.eye(4))
    return P, basis


def prop_world(rig, P, prop_bone, verts):
    S = P[prop_bone] @ np.linalg.inv(rig.rest[prop_bone])
    return verts @ S[:3, :3].T + S[:3, 3]


def run(rig, cfg, chains, frames):
    m = cfg["motion"]
    skirt_bones = {b for b in rig.names if b.startswith("Skirt")}
    skirt_w = sum(rig.W[b] for b in skirt_bones)
    solid = skirt_w < .5
    cloth = ~solid
    floor = cfg["floor"]
    dt = 1 / (30 * cfg["substeps"])
    nodes = None
    vel = None
    prop_bone, prop_verts, _ = rig.props[0]
    pivot0 = rig.rest[prop_bone]
    pend = None
    out, report = [], []
    prev_P = None
    for f in frames:
        state = cfg.setdefault("_state", {})
        P, basis = pose_frame(rig, cfg, f, state)
        # Floor lift: the pelvis may only rise, never sink, so the authored drop stays authored.
        sv = skin(rig, P, solid)
        low = sv[:, 2].min()
        state["low_owner"] = state.get("low_owner", []) + [(f, round(float(low), 3), str(np.array(rig.names)[np.column_stack([rig.W[n][solid] for n in rig.names])[int(sv[:, 2].argmin())].argmax()]))]
        if low < floor["solid"]:
            state["lift"] = state.get("lift", 0.0) + floor["solid"] - low
            P, basis = pose_frame(rig, cfg, f, state)
        lift = state.get("lift", 0.0)
        state["lift"] = max(0.0, lift - cfg.get("lift_decay", .004))  # release a lift once the body is clear
        state.setdefault("low", []).append(round(float(low), 4))
        # Skirt drape with temporal state (position-based, damped spring to a hanging target).
        hipsR = P["Hips"][:3, :3] @ rig.rest["Hips"][:3, :3].T
        ahead = hipsR @ np.array([0, -1.0, 0])
        yaw = rot(Z, math.degrees(math.atan2(ahead[0], -ahead[1])))
        caps = []
        for side in ("Left", "Right"):
            caps.append((P[side + "UpperLeg"][:3, 3], P[side + "LowerLeg"][:3, 3], cfg["capsule"]["thigh"]))
            caps.append((P[side + "LowerLeg"][:3, 3], P[side + "Foot"][:3, 3], cfg["capsule"]["shin"]))
        caps.append((P["Hips"][:3, 3], P["Neck"][:3, 3], cfg["capsule"]["torso"]))
        roots = np.array([(P["Hips"] @ np.linalg.inv(rig.rest["Hips"]) @ np.r_[rig.head(c["bones"][0]), 1])[:3] for c in chains])
        dr = cfg["drape"]
        cmin, bmin, g = dr["compress"], dr.get("hem_compress", .3), dr["hang"]
        lie = smooth((f - dr["lie"][0]) / (dr["lie"][1] - dr["lie"][0])) if "lie" in dr else 0.0
        # Skirt frame S, shared by every chain so the hem cap moves as one piece: plumb (yaw only) while
        # upright; lying, the robe keeps its rest shape at full length, its axis along the floor in the
        # direction of the legs and tilted up so its lower side rests on the floor.
        down = hipsR @ -Z
        flat = unit(down * [1, 1, 0]) if np.linalg.norm(down[:2]) > .05 else unit(ahead * [1, 1, 0])
        t = math.radians(dr.get("lie_tilt", 12))
        S = yaw @ power(yaw.T @ between(down, flat * math.cos(t) + Z * math.sin(t)) @ hipsR, lie)
        bell = math.radians(dr.get("bell", 0)) * (1 - lie)
        sag = smooth((lie - .6) / .4)  # only once the cross-section stands near vertical
        # Folded legs: the lower robe (every B bone together) turns about the vertical towards the shins.
        shin = sum(P[k + "Foot"][:3, 3] - P[k + "LowerLeg"][:3, 3] for k in ("Left", "Right")) * [1, 1, 0]
        axis = (S @ -Z) * [1, 1, 0]
        turn = math.degrees(math.atan2(np.cross(axis, shin)[2], axis @ shin))
        SB = rot(Z, float(np.clip(turn, -dr.get("fold", 0), dr.get("fold", 0))) * sag) @ S
        dirs = []
        for c, r in zip(chains, roots):
            A, B = c["bones"]
            a = unit((1 - g) * hipsR @ rig.rest[A][:3, 1] + g * S @ rig.rest[A][:3, 1])
            # Bell: as the waist comes down the upper skirt flares out, so the robe pools instead of shrinking.
            b = bell * smooth((rig.head(A)[2] - r[2]) / (.5 * rig.head(A)[2]))
            dirs.append((unit(a * math.cos(b) + S @ c["out"] * math.sin(b)), SB @ rig.rest[B][:3, 1]))
        LA = [rig.length[c["bones"][0]] for c in chains]
        LB = [rig.length[c["bones"][1]] for c in chains]

        def hem(i, n1):
            dB = dirs[i][1]
            low = n1[2] + dB[2] * bmin * LB[i]
            if low < floor["cloth"]:
                n1 = n1 + np.array([0, 0, floor["cloth"] - low])
            sB = float(np.clip((n1[2] - floor["cloth"]) / max(-dB[2] * LB[i], 1e-6), bmin, 1))
            return n1, n1 + dB * sB * LB[i]

        if nodes is None:
            nodes = np.array([[r, *hem(i, r + dirs[i][0] * LA[i])] for i, r in enumerate(roots)])
            vel = np.zeros_like(nodes)
            prev_roots = roots
        k, damp = cfg["drape"]["stiffness"], cfg["drape"]["damping"]
        for s in range(cfg["substeps"]):
            u = (s + 1) / cfg["substeps"]
            r = (1 - u) * prev_roots + u * roots
            for i in range(len(chains)):
                old = nodes[i].copy()
                goal = r[i] + dirs[i][0] * LA[i]
                acc = k * (goal - nodes[i][1]) - damp * vel[i][1]
                n1 = nodes[i][1] + vel[i][1] * dt + acc * dt * dt
                for _ in range(4):
                    for a0, a1, rad in caps:
                        dist, q = seg_dist(n1, a0, a1)
                        if dist < rad:
                            n1 = q + unit(n1 - q) * rad
                    d = n1 - r[i]
                    n1 = r[i] + unit(d) * float(np.clip(np.linalg.norm(d), cmin * LA[i], LA[i]))
                    n1, n2 = hem(i, n1)
                nodes[i] = [r[i], n1, n2]
                vel[i] = (nodes[i] - old) / dt
        prev_roots = roots
        # Lying cloth sags: the upper side of the robe drops towards its lower side and spreads sideways.
        # Flatten and spread are given at the knee and the hem level: a hem flatter and narrower than the
        # knee closes the hem mouth. A shape of this frame only, never fed back into the spring state, so
        # the robe can stand up again without a jump.
        flat = sag > 0 and "flatten" in dr
        if flat:
            nodes_spring = nodes.copy()
            side = unit(np.cross(SB @ -Z, Z))
            # Only the half-difference to the opposite chain changes, plus one shift for every chain so the
            # lower side keeps its contact: each opposite pair keeps a common mean, so the hem cap that
            # follows the pairs stays whole.
            d = (nodes[:, 1:] - nodes[(np.arange(len(chains)) + len(chains) // 2) % len(chains), 1:]) / 2
            nodes[:, 1:] += side * ((d @ side) * np.array(dr.get("spread", 0)) * sag)[..., None]
            nodes[:, 1:, 2] -= np.array(dr["flatten"]) * sag * (d[..., 2] - d[..., 2].min(0))
        for attempt in range(3):
            for i, (c, nd) in enumerate(zip(chains, nodes)):
                A, B = c["bones"]
                M = swing(fk_of(rig, P, A), nd[1] - nd[0])
                M[:3, 3] = nd[0]
                M[:3, 1] *= np.linalg.norm(nd[1] - nd[0]) / LA[i]
                set_world(rig, P, basis, A, M)
                M = swing(mat(SB @ rig.rest[B][:3, :3], nd[1]), nd[2] - nd[1])  # tilts only when the hem is shaped
                M[:3, 1] *= np.linalg.norm(nd[2] - nd[1]) / LB[i]  # Y scale: bunched cloth
                set_world(rig, P, basis, B, M)
            if attempt == 2 or not dr.get("chain_lift", True):
                break
            # Cloth outside a tilted chain's line can swing below the floor: lift the knee and hem nodes of every
            # chain together (one chain alone would tear the hem cap, which follows opposite pairs of chains).
            # The lift carries into the next frame, so the correction stays continuous.
            gap = floor["solid"] - skin(rig, P, cloth)[:, 2].min()
            if gap <= 1e-4:
                break
            nodes[:, 1:, 2] += gap
            if flat:
                nodes_spring[:, 1:, 2] += gap
        shaped = nodes.copy()
        if flat:
            nodes = nodes_spring
        # Lantern or staff: a damped pendulum on the prop pivot, kept above the floor.
        piv = P[prop_bone]
        pv = prop_world(rig, P, prop_bone, prop_verts)
        if cfg.get("prop_mode") == "hang":
            centre0 = prop_verts.mean(0) - pivot0[:3, 3]
            ell = np.linalg.norm(centre0)
            if pend is None:
                pend = [piv[:3, 3] + centre0, np.zeros(3)]
            for s in range(cfg["substeps"]):
                acc = np.array([0, 0, -9.8]) - cfg["prop_damping"] * pend[1]
                old = pend[0].copy()
                pend[0] = pend[0] + pend[1] * dt + acc * dt * dt
                pend[0] = piv[:3, 3] + unit(pend[0] - piv[:3, 3]) * ell
                lowest = cfg["floor"].get("prop_centre", .1)
                if pend[0][2] < lowest and piv[2, 3] - ell < lowest:  # rests on the floor: keep the centre's height
                    dz = lowest - piv[2, 3]
                    h = unit((pend[0] - piv[:3, 3]) * np.array([1, 1, 0]))
                    pend[0] = piv[:3, 3] + h * math.sqrt(max(ell * ell - dz * dz, 0)) + np.array([0, 0, dz])
                pend[1] = (pend[0] - old) / dt
            M = piv.copy()
            M[:3, :3] = between(unit(pivot0[:3, :3] @ (np.linalg.inv(pivot0[:3, :3]) @ centre0)), pend[0] - piv[:3, 3]) @ pivot0[:3, :3]
            set_world(rig, P, basis, prop_bone, M)
            for tilt in range(0, 95, 5):
                pv = prop_world(rig, P, prop_bone, prop_verts)
                if pv[:, 2].min() >= floor["prop"]:
                    break
                side = unit(np.cross(P["Hips"][:3, 2], pend[0] - piv[:3, 3]))
                M2 = M.copy()
                M2[:3, :3] = rot(side, tilt + 5) @ M[:3, :3]
                set_world(rig, P, basis, prop_bone, M2)
            pv = prop_world(rig, P, prop_bone, prop_verts)
            if pv[:, 2].min() < floor["prop"] + .01:  # resting on the floor: friction stops the swing
                pend[1] *= cfg.get("prop_friction", .3)
        vv = skin(rig, P)
        out.append({"frame": f, "basis": {n: basis.get(n, np.eye(4)) for n in rig.names}, "P": P, "verts": vv,
                    "prop": pv, "lift": lift, "nodes": shaped})
        prev_P = P
    return out


# ---------------------------------------------------------------- measurement and preview
def measure(rig, frames, chains, cfg):
    edges = np.unique(np.sort(np.r_[rig.tris[:, [0, 1]], rig.tris[:, [1, 2]], rig.tris[:, [2, 0]]], axis=1), axis=0)
    rest_len = np.linalg.norm(rig.verts[edges[:, 0]] - rig.verts[edges[:, 1]], axis=1)
    skirt = sum(rig.W[b] for c in chains for b in c["bones"]) > .5
    hem = skirt & (rig.verts[:, 2] < .06)
    regions = {"skirt": skirt, "hands": sum(rig.W[b] for b in rig.names if "Hand" in b or "LowerArm" in b) > .5,
               "head": (rig.W["Head"] + rig.W["Neck"]) > .5,
               "torso": sum(rig.W[b] for b in ("Spine", "Chest", "UpperChest")) > .5,
               "shoulders": sum(rig.W[b] for b in rig.names if "Shoulder" in b or "UpperArm" in b) > .5,
               "feet": sum(rig.W[b] for b in rig.names if "Foot" in b or "Toes" in b) > .5}
    rows, prev, prev2 = [], None, None
    for fr in frames:
        v = fr["verts"]
        L = np.linalg.norm(v[edges[:, 0]] - v[edges[:, 1]], axis=1)
        severe = int(((rest_len > 1e-6) & (L > 3 * rest_len) & (L > .03)).sum())
        stretch = float(np.max(L / np.maximum(rest_len, 1e-6)))
        jump = float(np.linalg.norm(v[hem] - prev[hem], axis=1).max()) if prev is not None else 0.0
        pop = float(np.linalg.norm(v[hem] - 2 * prev[hem] + prev2[hem], axis=1).max()) if prev2 is not None else 0.0
        prev2 = prev
        contact = {k: int((v[m, 2] < v[:, 2].min() + .01).sum()) for k, m in regions.items()}
        rows.append({"frame": fr["frame"], "min_z": round(float(v[:, 2].min()), 4), "prop_min_z": round(float(fr["prop"][:, 2].min()), 4),
                     "hips_z": round(float(fr["P"]["Hips"][2, 3]), 3), "lift": round(fr["lift"], 4),
                     "hem_r": round(float(np.percentile(np.hypot(v[hem, 0] - fr["P"]["Hips"][0, 3], v[hem, 1] - fr["P"]["Hips"][1, 3]), 90)), 3),
                     "severe": severe, "max_stretch": round(stretch, 2), "hem_jump": round(jump, 4), "hem_pop": round(pop, 4),
                     "contact": {k: n for k, n in contact.items() if n}})
        prev = v
    return rows


VIEWS = {"front": (2.2, -3.2, .9), "back": (-2.2, 3.2, .9), "side": (3.6, 0, .9)}


def render(rig, frames, path, view="front", every=4, size=300, cols=4):
    from PIL import Image, ImageDraw
    allv = np.concatenate([fr["verts"] for fr in frames] + [fr["prop"] for fr in frames])
    centre = (allv.min(0) + allv.max(0)) / 2
    extent = np.linalg.norm(allv.max(0) - allv.min(0))
    picks = frames[::every] + ([frames[-1]] if (len(frames) - 1) % every else [])
    rows = (len(picks) + cols - 1) // cols
    sheet = Image.new("RGB", (size * cols, size * rows), (40, 44, 52))
    light = unit(np.array([.4, -.6, .8]))
    d = unit(np.array(VIEWS[view]))
    right = -unit(np.cross(d, Z))
    up = np.cross(right, -d)
    up = -up if up[2] < 0 else up
    scale = size / (extent * 1.0)
    to2d = lambda q: ((q - centre) @ right * scale + size / 2, size / 2 - (q - centre) @ up * scale)
    for k, fr in enumerate(picks):
        img = Image.new("RGB", (size, size), (52, 56, 66))
        dr = ImageDraw.Draw(img)
        for x0 in np.linspace(-2, 2, 17):
            for p0, p1 in (((x0, -2, 0), (x0, 2, 0)), ((-2, x0, 0), (2, x0, 0))):
                dr.line([to2d(np.array(p0)), to2d(np.array(p1))], fill=(70, 74, 86))
        for verts, tris, colour in ((fr["verts"], rig.tris, (170, 140, 90)), (fr["prop"], rig.props[0][2], (230, 200, 90))):
            p = verts[tris]
            nrm = np.cross(p[:, 1] - p[:, 0], p[:, 2] - p[:, 0])
            nrm /= np.maximum(np.linalg.norm(nrm, axis=1, keepdims=True), 1e-12)
            depth = (p.mean(1) - centre) @ d
            shade = np.clip(np.abs(nrm @ light) * .75 + .25, 0, 1)
            for i in np.argsort(depth):
                dr.polygon([to2d(q) for q in p[i]], fill=tuple(int(x * shade[i]) for x in colour))
        dr.text((6, 6), f"{view} f{fr['frame']}", fill=(255, 255, 255))
        sheet.paste(img, ((k % cols) * size, (k // cols) * size))
    sheet.save(path)
    return path


if __name__ == "__main__":
    character, rest_path, out_dir = sys.argv[1:4]
    import importlib.util
    spec = importlib.util.spec_from_file_location("motions", Path(__file__).with_name("collapse_motions.py"))
    motions = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(motions)
    cfg = motions.CONFIG[character]
    rig = Rig(rest_path)
    chains, zw = build_skirt(rig, cfg)
    info = skirt_weights(rig, chains, zw, cfg)
    frames = run(rig, cfg, chains, list(range(1, cfg["length"] + 1)))
    rows = measure(rig, frames, chains, cfg)
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    (out / f"{character}-metrics.json").write_text(json.dumps({"skirt": info, "rows": rows}, indent=1))
    for r in rows[::2]:
        print(r)
    print("skirt", info, "max severe", max(r["severe"] for r in rows), "max hem jump", max(r["hem_jump"] for r in rows),
          "max lift", max(r["lift"] for r in rows), "min prop z", min(r["prop_min_z"] for r in rows))
    if "--preview" in sys.argv:
        for view in VIEWS:
            print(render(rig, frames, out / f"{character}-{view}.png", view))
    np.savez_compressed(out / f"{character}-solve.npz", names=np.array(rig.names),
                        parents=np.array([rig.parent[n] or "" for n in rig.names]),
                        rest=np.array([rig.rest[n] for n in rig.names]), lengths=np.array([rig.length[n] for n in rig.names]),
                        weights=np.column_stack([rig.W[n] for n in rig.names]),
                        pose=np.array([[fr["P"][n] for n in rig.names] for fr in frames]),
                        verts=np.array([fr["verts"] for fr in frames], dtype=np.float32))
