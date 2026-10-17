# Blender: inspect connected surfaces and rear garment weights in hero exports.
import json
from pathlib import Path
import sys

import bpy
import numpy as np

lane = Path(__file__).resolve().parent.parent
for name in sys.argv[sys.argv.index("--") + 1:]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    path = lane / "chars" / name / "rig" / f"{name}.glb"
    bpy.ops.import_scene.gltf(filepath=str(path), merge_vertices=True)
    arm = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
    body = next(obj for obj in bpy.data.objects if obj.type == "MESH" and obj.find_armature() == arm)
    co = np.array([(body.matrix_world @ vertex.co)[:] for vertex in body.data.vertices])
    # Imported armatures are rotated into Z-up by Blender; use world coordinates.
    neighbours = [[] for _ in co]
    for edge in body.data.edges:
        a, b = edge.vertices
        neighbours[a].append(b)
        neighbours[b].append(a)
    seen, components = set(), []
    for start in range(len(co)):
        if start in seen:
            continue
        seen.add(start)
        queue, vertices = [start], []
        while queue:
            vertex = queue.pop()
            vertices.append(vertex)
            for adjacent in neighbours[vertex]:
                if adjacent not in seen:
                    seen.add(adjacent)
                    queue.append(adjacent)
        points = co[vertices]
        components.append({"count": len(vertices), "lo": points.min(0).round(3).tolist(),
                           "hi": points.max(0).round(3).tolist()})
    print("REGION", name, "components", json.dumps(sorted(components, key=lambda item: -item["count"])[:15]), flush=True)
    for low, high in ((.2, .5), (.5, .8), (.8, 1.1), (1.1, 1.4), (1.4, 1.6)):
        slab = co[(co[:, 2] >= low) & (co[:, 2] < high)]
        print("SLAB", name, low, high, "y percentiles", np.percentile(slab[:, 1], (0, 25, 50, 75, 90, 100)).round(3).tolist(), flush=True)
    for bone in arm.data.bones:
        point = arm.matrix_world @ bone.head_local
        if bone.name in ("Hips", "Spine", "Chest", "UpperChest", "Neck", "Head"):
            slab = co[(np.abs(co[:, 0]) < .10) & (np.abs(co[:, 2] - point.z) < .035)]
            print("CENTRE", name, bone.name, "y range", np.percentile(slab[:, 1], (5, 50, 95)).round(4).tolist(), flush=True)
        print("BONE", name, bone.name, tuple(round(value, 3) for value in point), flush=True)
