# Blender: measure exported support geometry separately from the cape and body minimum.
import json
import math
import os
from pathlib import Path
import shutil
import sys

import bpy
import numpy as np

lane = Path(__file__).resolve().parent.parent
candidates = sys.argv[sys.argv.index("--") + 1:]
assert candidates
for candidate in candidates:
    parts = candidate.split("/")
    assert len(parts) == 3 and parts[0] == "chars"
    assert all(part and part.replace("-", "").isalnum() for part in parts)
    folder = lane.joinpath(*parts)
    output = folder / "support-contact.json"
    assert not output.exists(), "Preserve an existing measurement"
    assert os.getloadavg()[0] < 50 and shutil.disk_usage(lane).free / 2**30 >= 100
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(folder / f"{parts[1]}.glb"), merge_vertices=True)
    arm = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
    body = next(obj for obj in bpy.data.objects if obj.type == "MESH" and obj.find_armature() == arm)
    scene = bpy.context.scene
    assert scene.render.fps == 24
    regions = {"feet": [], "lower_legs": [], "cape": []}
    names = {group.index: group.name for group in body.vertex_groups}
    for vertex in body.data.vertices:
        weights = {names[group.group]: group.weight for group in vertex.groups}
        for region, bones in (
            ("feet", ("LeftFoot", "RightFoot")),
            ("lower_legs", ("LeftLowerLeg", "RightLowerLeg")),
            ("cape", ("CapeUpper", "CapeLower")),
        ):
            if sum(weights.get(name, 0) for name in bones) > .5:
                regions[region].append(vertex.index)
    assert len(regions["feet"]) > 10 and len(regions["lower_legs"]) > 10
    assert not set(regions["cape"]) & set(regions["feet"])
    rows = []
    for clip in ("idle", "walk", "attack", "cast", "hurt", "death"):
        action = bpy.data.actions[clip]
        arm.animation_data.action = action
        first, last = action.frame_range
        for sample in range(33):
            frame = first + (last - first) * sample / 32
            scene.frame_set(math.floor(frame), subframe=frame % 1)
            evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
            mesh = evaluated.to_mesh()
            try:
                points = np.array([(evaluated.matrix_world @ vertex.co)[:] for vertex in mesh.vertices])
            finally:
                evaluated.to_mesh_clear()
            assert len(points) == len(body.data.vertices) and np.isfinite(points).all()
            heights = {name: float(points[ids, 2].min()) for name, ids in regions.items() if ids}
            heights["body"] = float(points[:, 2].min())
            # A one-metre world translation must move every measured minimum by one metre.
            shifted = points + np.array((0, 0, 1))
            assert abs(float(shifted[:, 2].min()) - heights["body"] - 1) < 1e-6
            knees = {side: float((arm.matrix_world @ arm.pose.bones[f"{side}LowerLeg"].matrix).translation.z)
                     for side in ("Left", "Right")}
            rows.append({"clip": clip, "fraction": sample / 32, "frame": frame,
                         "minimum_z_m": heights, "knee_joint_z_m": knees})
    report = {"candidate": candidate, "fps": scene.render.fps,
              "regions": {name: len(ids) for name, ids in regions.items()},
              "definition": "Vertices with more than half of their weight on the named region bones; knee values are joint origins, not a surface contact measure",
              "world_translation_control": "passed", "samples": rows}
    output.write_text(json.dumps(report, indent=2) + "\n")
    endpoint = next(row for row in rows if row["clip"] == "death" and row["fraction"] == 1)
    print("SUPPORT CONTACT", candidate, json.dumps(endpoint), flush=True)
