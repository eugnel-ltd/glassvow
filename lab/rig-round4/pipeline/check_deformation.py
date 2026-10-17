# Measure a saved Blender rig or reimported GLB at eight samples per frame.
# blender -b file.blend --python-exit-code 1 --python check_deformation.py -- output.json
# blender -b --factory-startup --python-exit-code 1 --python check_deformation.py -- output.json file.glb
import json
from pathlib import Path
import sys

import bpy
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:]
if len(args) > 1:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=args[1], merge_vertices=True)
arm = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
body = next(obj for obj in bpy.data.objects if obj.type == "MESH" and obj.find_armature() == arm)
scene = bpy.context.scene
rest = np.array([vertex.co[:] for vertex in body.data.vertices])
edges = np.array([edge.vertices[:] for edge in body.data.edges])
rest_lengths = np.linalg.norm(rest[edges[:, 0]] - rest[edges[:, 1]], axis=1)
reports = []
for action in bpy.data.actions:
    arm.animation_data_create()
    arm.animation_data.action = action
    first, last = (int(round(value)) for value in action.frame_range)
    counts, heights, worst = [], [], (0, first)
    for eighth in range(first * 8, last * 8 + 1):
        scene.frame_set(eighth // 8, subframe=(eighth % 8) / 8)
        evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
        mesh = evaluated.to_mesh()
        positions = np.array([vertex.co[:] for vertex in mesh.vertices])
        assert positions.shape == rest.shape and np.isfinite(positions).all(), (action.name, eighth, "Invalid posed vertices")
        assert all(np.isfinite(value) for row in evaluated.matrix_world for value in row), "Invalid body transform"
        lengths = np.linalg.norm(positions[edges[:, 0]] - positions[edges[:, 1]], axis=1)
        count = int(((rest_lengths > 1e-6) & (lengths > rest_lengths * 3) & (lengths > .03)).sum())
        heights.append(min((evaluated.matrix_world @ vertex.co).z for vertex in mesh.vertices))
        counts.append(count)
        if count > worst[0]:
            worst = (count, eighth / 8)
        evaluated.to_mesh_clear()
    reports.append({"clip": action.name, "min_z": min(heights), "max_min_z": max(heights),
                    "max_stretched_edges": worst[0], "worst_frame": worst[1], "samples": len(heights)})
    print("DEFORMATION", json.dumps(reports[-1]), flush=True)
Path(args[0]).write_text(json.dumps(reports, indent=2) + "\n")
assert len(reports) == 6, len(reports)
