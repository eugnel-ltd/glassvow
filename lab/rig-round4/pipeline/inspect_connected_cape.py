# Blender: locate connected-cape failures in the exported mesh without changing the candidate.
import json
import os
from pathlib import Path
import shutil

import bpy
import numpy as np

lane = Path(__file__).resolve().parent.parent
folder = lane / "chars" / "ashwarden" / "rig-cape-connected"
output = folder / "connected-boundary.json"
assert not output.exists(), "Preserve an existing measurement"
assert os.getloadavg()[0] < 50 and shutil.disk_usage(lane).free / 2**30 >= 100
reports = json.loads((folder / "reimport-deformation.json").read_text())
frame = next(row["worst_frame"] for row in reports if row["clip"] == "death")
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(folder / "ashwarden.glb"), merge_vertices=True)
arm = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
body = next(obj for obj in bpy.data.objects if obj.type == "MESH" and obj.find_armature() == arm)
arm.animation_data.action = bpy.data.actions["death"]
bpy.context.scene.frame_set(int(frame), subframe=frame % 1)
rest = np.array([vertex.co[:] for vertex in body.data.vertices])
world = np.array([(body.matrix_world @ vertex.co)[:] for vertex in body.data.vertices])
evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
mesh = evaluated.to_mesh()
pose = np.array([vertex.co[:] for vertex in mesh.vertices])
evaluated.to_mesh_clear()
edges = np.array([edge.vertices[:] for edge in body.data.edges])
a, b = edges.T
lengths = np.linalg.norm(rest[a] - rest[b], axis=1)
posed = np.linalg.norm(pose[a] - pose[b], axis=1)
bad = np.flatnonzero((lengths > 1e-6) & (posed > 3 * lengths) & (posed > .03))
assert np.isfinite(pose).all() and len(bad) == next(row["max_stretched_edges"] for row in reports if row["clip"] == "death")
weights = [{body.vertex_groups[group.group].name: group.weight for group in vertex.groups}
           for vertex in body.data.vertices]
rows = []
for index in sorted(bad, key=lambda index: posed[index] / lengths[index], reverse=True):
    endpoints = [{"vertex": int(vertex), "rest_world": world[vertex].tolist(), "weights": weights[vertex]}
                 for vertex in edges[index]]
    rows.append({"edge": int(index), "rest_m": float(lengths[index]), "posed_m": float(posed[index]),
                 "endpoints": endpoints})
counts = {"touches_cape": 0, "both_full_cape": 0, "crosses_cape_boundary": 0, "outside_cape": 0}
for row in rows:
    masses = [sum(value for name, value in endpoint["weights"].items() if name in ("CapeUpper", "CapeLower"))
              for endpoint in row["endpoints"]]
    counts["touches_cape" if max(masses) > 1e-6 else "outside_cape"] += 1
    counts["both_full_cape"] += int(min(masses) > .999)
    counts["crosses_cape_boundary"] += int(min(masses) < .999 and max(masses) > 1e-6)
output.write_text(json.dumps({"clip": "death", "frame": frame, "fps": 24,
    "bad_edges": len(bad), "classification": counts, "edges": rows}, indent=2) + "\n")
print("CONNECTED CAPE BOUNDARY", json.dumps(counts), flush=True)
print("WORST CONNECTED EDGE", json.dumps(rows[0]), flush=True)
