# Blender: locate cape failure edges and compare source and reimported bone transforms.
import json
from pathlib import Path
import sys

import bpy
import numpy as np

pipeline = Path(__file__).resolve().parent
lane = pipeline.parent
name = sys.argv[sys.argv.index("--") + 1]
assert name in ("duskblade", "ashwarden")
folder = lane / "chars" / name / "rig-cape-bones"
reports = json.loads((folder / "reimport-deformation.json").read_text())
frame = next(row["worst_frame"] for row in reports if row["clip"] == "death")
output = folder / "boundary-diagnostic.json"
assert not output.exists()
bpy.ops.wm.open_mainfile(filepath=str(folder / f"{name}.blend"))
arm = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
arm.animation_data.action = bpy.data.actions["death"]
action = arm.animation_data.action
# Both formats start the exported clip at t=0; account for each importer's frame origin.
first = float(action.frame_range[0])
source_frame = first + (frame - 1) / 24 * bpy.context.scene.render.fps
bpy.context.scene.frame_set(int(source_frame), subframe=source_frame % 1)
source = {}
for bone_name in ("CapeUpper", "CapeLower"):
    bone = arm.pose.bones[bone_name]
    source[bone_name] = (arm.matrix_world @ bone.matrix).copy()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(folder / f"{name}.glb"), merge_vertices=True)
arm = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
body = next(obj for obj in bpy.data.objects if obj.type == "MESH" and obj.find_armature() == arm)
arm.animation_data.action = bpy.data.actions["death"]
bpy.context.scene.frame_set(int(frame), subframe=frame % 1)
differences = {}
for bone_name, matrix in source.items():
    actual = arm.matrix_world @ arm.pose.bones[bone_name].matrix
    differences[bone_name] = {"translation_m": (matrix.translation - actual.translation).length,
                              "rotation_rad": matrix.to_quaternion().rotation_difference(actual.to_quaternion()).angle,
                              "scale": (matrix.to_scale() - actual.to_scale()).length}
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
mask = np.clip((world[:, 1] - (.20 - .19 * world[:, 2])) / .06, 0, 1)
mask *= np.clip((1.34 - world[:, 2]) / .16, 0, 1)
mask = mask * mask * (3 - 2 * mask)
rows = []
for index in sorted(bad, key=lambda index: posed[index] / lengths[index], reverse=True)[:12]:
    endpoints = []
    for vertex in edges[index]:
        endpoints.append({"vertex": int(vertex), "world_rest": world[vertex].tolist(), "cape_mask": float(mask[vertex]),
                          "weights": {body.vertex_groups[group.group].name: group.weight
                                      for group in body.data.vertices[vertex].groups}})
    rows.append({"edge": int(index), "rest_m": float(lengths[index]), "posed_m": float(posed[index]), "endpoints": endpoints})
result = {"clip": "death", "frame": frame, "fps": 24, "bad_edges": len(bad),
          "exported_bone_differences": differences, "worst_edges": rows}
output.write_text(json.dumps(result, indent=2) + "\n")
print("CAPE BOUNDARY", name, json.dumps(result), flush=True)
