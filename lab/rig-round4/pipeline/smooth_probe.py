# Blender: compare weight smoothing on exported candidates without replacing them.
# smooth_probe.py -- selection.json results.json
import json
import os
from pathlib import Path
import runpy
import shutil
import sys

import bpy
import numpy as np


def smooth_weights(body, repeat):
    groups = list(body.vertex_groups)
    weights = np.zeros((len(body.data.vertices), len(groups)))
    for vertex in body.data.vertices:
        for group in vertex.groups:
            weights[vertex.index, group.group] = group.weight
    a, b = np.array([edge.vertices[:] for edge in body.data.edges]).T
    degree = np.maximum(np.bincount(a, minlength=len(weights)) + np.bincount(b, minlength=len(weights)), 1)[:, None]
    for _ in range(repeat):
        neighbours = np.zeros_like(weights)
        np.add.at(neighbours, a, weights[b])
        np.add.at(neighbours, b, weights[a])
        weights = .5 * weights + .5 * neighbours / degree
    for group in groups:
        group.remove(list(range(len(weights))))
    for vertex, row in enumerate(weights):
        for group in np.flatnonzero(row > 1e-5):
            groups[group].add([vertex], float(row[group]), "REPLACE")
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.vertex_group_limit_total(limit=4)
    bpy.ops.object.vertex_group_normalize_all(lock_active=False)


def main():
    pipeline = Path(__file__).resolve().parent
    selection, output = sys.argv[sys.argv.index("--") + 1:]
    results = []
    for item in json.loads(Path(selection).read_text()):
        for repeat in (0, 4, 12, 30):
            assert os.getloadavg()[0] < 50 and shutil.disk_usage(pipeline).free / 2**30 >= 100
            bpy.ops.wm.read_factory_settings(use_empty=True)
            bpy.ops.import_scene.gltf(filepath=item["glb"], merge_vertices=True)
            arm = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
            body = next(obj for obj in bpy.data.objects if obj.type == "MESH" and obj.find_armature() == arm)
            smooth_weights(body, repeat)
            report = Path(output).with_name(f"{item['name']}-smooth-{repeat}.json")
            sys.argv = [str(pipeline / "check_deformation.py"), "--", str(report)]
            runpy.run_path(str(pipeline / "check_deformation.py"), run_name="__main__")
            clips = json.loads(report.read_text())
            row = {"name": item["name"], "repeat": repeat,
                   "stretch": {clip["clip"]: clip["max_stretched_edges"] for clip in clips}}
            results.append(row)
            print("SMOOTH", json.dumps(row), flush=True)
    Path(output).write_text(json.dumps(results, indent=2) + "\n")


if __name__ == "__main__":
    main()
