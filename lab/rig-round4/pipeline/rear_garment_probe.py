# Blender: test rear garment weights without changing the source candidates.
import json
import os
from pathlib import Path
import runpy
import shutil
import sys

import bpy
import numpy as np

pipeline = Path(__file__).resolve().parent
lane = pipeline.parent
smooth = runpy.run_path(str(pipeline / "smooth_probe.py"))["smooth_weights"]


def rear_garment(body, intercept):
    co = np.array([(body.matrix_world @ vertex.co)[:] for vertex in body.data.vertices])
    groups = list(body.vertex_groups)
    old = np.zeros((len(co), len(groups)))
    for vertex in body.data.vertices:
        for group in vertex.groups:
            old[vertex.index, group.group] = group.weight
    # The measured cape slopes rearwards towards its hem. Blend across a 6 cm band.
    blend = np.clip((co[:, 1] - (intercept - .19 * co[:, 2])) / .06, 0, 1)
    blend *= np.clip((1.52 - co[:, 2]) / .12, 0, 1)
    blend = blend * blend * (3 - 2 * blend)
    target = np.zeros_like(old)
    names = {group.name: group.index for group in groups}
    levels = [("Hips", .9), ("Spine", 1.026), ("Chest", 1.152), ("UpperChest", 1.278)]
    for vertex, height in enumerate(co[:, 2]):
        k = int(np.clip(np.searchsorted([level[1] for level in levels], height) - 1, 0, 2))
        a, b = levels[k:k + 2]
        fraction = float(np.clip((height - a[1]) / (b[1] - a[1]), 0, 1))
        target[vertex, names[a[0]]] = 1 - fraction
        target[vertex, names[b[0]]] = fraction
    weights = old * (1 - blend[:, None]) + target * blend[:, None]
    for group in groups:
        group.remove(list(range(len(co))))
    for vertex, row in enumerate(weights):
        for group in np.flatnonzero(row > 1e-5):
            groups[group].add([vertex], float(row[group]), "REPLACE")
    print("REAR GARMENT", body.name, "affected", int((blend > 0).sum()), flush=True)


def main():
    results = []
    for name in ("duskblade", "ashwarden"):
        for intercept, passes in ((.245, 4), (.20, 4), (.20, 12)):
            assert os.getloadavg()[0] < 50 and shutil.disk_usage(lane).free / 2**30 >= 100
            bpy.ops.wm.read_factory_settings(use_empty=True)
            bpy.ops.import_scene.gltf(filepath=str(lane / "chars" / name / "rig" / f"{name}.glb"), merge_vertices=True)
            arm = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
            body = next(obj for obj in bpy.data.objects if obj.type == "MESH" and obj.find_armature() == arm)
            rear_garment(body, intercept)
            smooth(body, passes)
            report = pipeline / f"{name}-rear-{intercept}-{passes}.json"
            sys.argv = [str(pipeline / "check_deformation.py"), "--", str(report)]
            runpy.run_path(str(pipeline / "check_deformation.py"), run_name="__main__")
            clips = json.loads(report.read_text())
            row = {"name": name, "intercept": intercept, "passes": passes,
                   "stretch": {clip["clip"]: clip["max_stretched_edges"] for clip in clips}}
            results.append(row)
            print("REAR RESULT", json.dumps(row), flush=True)
    (pipeline / "rear-garment-results.json").write_text(json.dumps(results, indent=2) + "\n")


if __name__ == "__main__":
    main()
