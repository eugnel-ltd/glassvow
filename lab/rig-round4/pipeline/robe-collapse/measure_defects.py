# Measure the four coordinator defects on an offline collapse solve.
#   python3 measure_defects.py <character> <rest.npz> <out.json>
# 1 arm: shoulder-to-wrist bone chain and sleeve surface length against rest, every frame, plus sleeve edge stretch.
# 2 volume: enclosed mesh volume (signed tetrahedra from the origin) against rest, every frame.
# 3 curl: bend at the waist (robe axis to Hips) and at each trunk joint, and the largest joint's share.
# 4 early support loss: head and shoulder heights over the first 0.6 s.
import importlib.util
import json
import sys
from pathlib import Path

import numpy as np

here = Path(__file__).parent
spec = importlib.util.spec_from_file_location("c", here / "collapse.py"); c = importlib.util.module_from_spec(spec); spec.loader.exec_module(c)
spec = importlib.util.spec_from_file_location("m", here / "collapse_motions.py"); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
character, rest_path, out = sys.argv[1:4]
cfg = m.CONFIG[character]
rig = c.Rig(rest_path)
chains, zw = c.build_skirt(rig, cfg)
c.skirt_weights(rig, chains, zw, cfg)
frames = c.run(rig, cfg, chains, list(range(1, cfg["length"] + 1)))
T, V0 = rig.tris, rig.verts


def volume(v):
    p = v[T]
    return float(np.einsum("ij,ij->i", p[:, 0], np.cross(p[:, 1], p[:, 2])).sum() / 6)


def angle(a, b):
    return float(np.degrees(np.arccos(np.clip(c.unit(a) @ c.unit(b), -1, 1))))


edges = np.unique(np.sort(np.r_[T[:, [0, 1]], T[:, [1, 2]], T[:, [2, 0]]], axis=1), axis=0)
report = {"arm": {}, "volume": {}, "curl": [], "early": []}
for side in ("Right", "Left"):
    up, lo, hand = side + "UpperArm", side + "LowerArm", side + "Hand"
    L1, L2 = rig.length[up], rig.length[lo]
    sleeve = (rig.W[up] + rig.W[lo] + rig.W[hand]) > .5
    root, elbow, wrist = rig.head(up), rig.head(lo), rig.head(hand)
    s = np.array([np.linalg.norm(c.seg_dist(p, root, elbow)[1] - root) if c.seg_dist(p, root, elbow)[0] <= c.seg_dist(p, elbow, wrist)[0]
                  else L1 + np.linalg.norm(c.seg_dist(p, elbow, wrist)[1] - elbow) for p in V0])
    bins = np.linspace(0, L1 + L2, 22)
    slices = [g for g in (np.nonzero(sleeve & (s >= a) & (s < b))[0] for a, b in zip(bins, bins[1:])) if len(g) >= 3]
    path = lambda v: float(np.linalg.norm(np.diff([v[g].mean(0) for g in slices], axis=0), axis=1).sum())
    e = edges[sleeve[edges[:, 0]] & sleeve[edges[:, 1]]]
    e0 = np.linalg.norm(V0[e[:, 0]] - V0[e[:, 1]], axis=1)
    rest_path = path(V0)
    rows = []
    for fr in frames:
        P, v = fr["P"], fr["verts"]
        bone = (np.linalg.norm(P[lo][:3, 3] - P[up][:3, 3]) + np.linalg.norm(P[hand][:3, 3] - P[lo][:3, 3])) / (L1 + L2)
        r = np.linalg.norm(v[e[:, 0]] - v[e[:, 1]], axis=1) / np.maximum(e0, 1e-6)
        rows.append({"frame": fr["frame"], "bone": round(float(bone), 4), "sleeve": round(path(v) / rest_path, 4),
                     "edge_p99": round(float(np.percentile(r, 99)), 3), "edge_max": round(float(r.max()), 3)})
    report["arm"][side] = {"sleeve_verts": int(sleeve.sum()), "rest_sleeve_m": round(rest_path, 4), "rows": rows,
                           "sleeve_range": [min(x["sleeve"] for x in rows), max(x["sleeve"] for x in rows)],
                           "bone_range": [min(x["bone"] for x in rows), max(x["bone"] for x in rows)]}
vr = volume(V0)
ratios = [volume(fr["verts"]) / vr for fr in frames]
worst = int(np.argmin(ratios))
report["volume"] = {"rest_m3": round(vr, 5), "per_frame": [round(x, 4) for x in ratios], "end": round(ratios[-1], 4),
                    "worst": round(ratios[worst], 4), "worst_frame": frames[worst]["frame"]}
for fr in frames:
    P, nd = fr["P"], fr["nodes"]
    robe = nd[:, 0].mean(0) - nd[:, 2].mean(0)  # hem centre to waist centre
    joints = {"waist": angle(robe, P["Hips"][:3, 1]), "Hips-Spine": angle(P["Hips"][:3, 1], P["Spine"][:3, 1]),
              "Spine-Chest": angle(P["Spine"][:3, 1], P["Chest"][:3, 1]),
              "Chest-UpperChest": angle(P["Chest"][:3, 1], P["UpperChest"][:3, 1]),
              "UpperChest-Neck": angle(P["UpperChest"][:3, 1], P["Neck"][:3, 1])}
    total = sum(joints.values())
    big = max(joints, key=joints.get)
    report["curl"].append({"frame": fr["frame"], **{k: round(x, 1) for k, x in joints.items()}, "total": round(total, 1),
                           "largest": big, "largest_share": round(joints[big] / max(total, 1e-6), 3)})
    if fr["frame"] <= 18:
        report["early"].append({"frame": fr["frame"], "head_z": round(float(P["Head"][2, 3]), 3),
                                "head_y": round(float(P["Head"][1, 3]), 3), "head_x": round(float(P["Head"][0, 3]), 3),
                                "shoulders_z": round(float((P["LeftUpperArm"][2, 3] + P["RightUpperArm"][2, 3]) / 2), 3),
                                "hips_z": round(float(P["Hips"][2, 3]), 3)})
end = frames[-1]
skirt = sum(rig.W[b] for ch in chains for b in ch["bones"]) > .5
head = (rig.W["Head"] + rig.W["Neck"]) > .5
report["end"] = {"head_dir": end["P"]["Head"][:3, 1].round(3).tolist(), "head_min_z": round(float(end["verts"][head, 2].min()), 3),
                 "min_z_all_frames": round(min(float(fr["verts"][:, 2].min()) for fr in frames), 4),
                 "skirt_min_z_all_frames": round(min(float(fr["verts"][skirt, 2].min()) for fr in frames), 4),
                 "body_min_z_all_frames": round(min(float(fr["verts"][~skirt, 2].min()) for fr in frames), 4)}
Path(out).write_text(json.dumps(report, indent=1) + "\n")
mid = [r for r in report["curl"] if 24 <= r["frame"] <= 36]
print("arm R bone", report["arm"]["Right"]["bone_range"], "sleeve", report["arm"]["Right"]["sleeve_range"],
      "edge p99 max", max(r["edge_p99"] for r in report["arm"]["Right"]["rows"]), "edge max", max(r["edge_max"] for r in report["arm"]["Right"]["rows"]))
print("volume end", report["volume"]["end"], "worst", report["volume"]["worst"], "at", report["volume"]["worst_frame"])
print("curl f24-36 max share", max(r["largest_share"] for r in mid), [(r["frame"], r["largest"], r["largest_share"]) for r in mid if r["frame"] % 3 == 0])
print("early", [(r["frame"], r["head_z"], r["head_y"], r["shoulders_z"], r["hips_z"]) for r in report["early"] if r["frame"] in (1, 4, 6, 8, 10, 12, 14, 18)])
print("end", report["end"])
