# Blender: measure one diffusion round before and after four-influence pruning.
import ast
import json
import os
from pathlib import Path
import shutil
import sys

import bpy
import numpy as np

pipeline = Path(__file__).resolve().parent
lane = pipeline.parent
output = pipeline / "hero-pruning-diagnostic.json"
assert not output.exists(), "Preserve an existing diagnostic"
module = ast.parse((pipeline / "hero_local_weights.py").read_text())
module.body = [node for node in module.body if isinstance(node, (ast.Import, ast.ImportFrom, ast.FunctionDef))]
helpers = {"__file__": str(pipeline / "hero_local_weights.py")}
exec(compile(module, "hero_local_weights.py", "exec"), helpers)
results = []
for name in ("duskblade", "ashwarden"):
    assert os.getloadavg()[0] < 50 and shutil.disk_usage(lane).free / 2**30 >= 100
    folder = lane / "chars" / name / "rig-local-weights"
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(folder / f"{name}.glb"), merge_vertices=True)
    arm = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
    body = next(obj for obj in bpy.data.objects if obj.type == "MESH" and obj.find_armature() == arm)
    groups = [group.name for group in body.vertex_groups]
    original = helpers["weights"](body)
    co = np.array([vertex.co[:] for vertex in body.data.vertices])
    edges = np.array([edge.vertices[:] for edge in body.data.edges])
    a, b = edges.T
    rest = np.linalg.norm(co[a] - co[b], axis=1)
    degree = np.maximum(np.bincount(a, minlength=len(co)) + np.bincount(b, minlength=len(co)), 1)[:, None]
    reports = json.loads((folder / "reimport-deformation.json").read_text())
    arm.animation_data_create()

    def assign(array):
        for group in body.vertex_groups:
            group.remove(list(range(len(array))))
        for vertex, row in enumerate(array):
            for index in np.flatnonzero(row > 1e-8):
                body.vertex_groups[index].add([vertex], float(row[index]), "REPLACE")
        bpy.context.view_layer.update()

    def lengths():
        evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
        mesh = evaluated.to_mesh()
        try:
            points = np.array([vertex.co[:] for vertex in mesh.vertices])
            assert np.isfinite(points).all()
            return np.linalg.norm(points[a] - points[b], axis=1)
        finally:
            evaluated.to_mesh_clear()

    bad = helpers["bad_edges"](arm, body, edges, rest)
    mask = np.zeros(len(co), dtype=bool)
    mask[edges[bad].ravel()] = True
    for _ in range(3):
        mask[edges[mask[a] | mask[b]].ravel()] = True
    full = original.copy()
    for _ in range(24):
        neighbours = np.zeros_like(full)
        np.add.at(neighbours, a, full[b])
        np.add.at(neighbours, b, full[a])
        full[mask] = .5 * full[mask] + .5 * neighbours[mask] / degree[mask]
    limited = helpers["apply"](body, full)
    for report in reports:
        if report["max_stretched_edges"] == 0:
            continue
        arm.animation_data.action = bpy.data.actions[report["clip"]]
        frame = report["worst_frame"]
        bpy.context.scene.frame_set(int(frame), subframe=frame % 1)
        posed = {}
        for label, array in (("original", original), ("diffused", full), ("pruned", limited)):
            assign(array)
            posed[label] = lengths()
        flags = {label: (rest > 1e-6) & (values > 3 * rest) & (values > .03)
                 for label, values in posed.items()}
        selected = flags["original"] | flags["diffused"] | flags["pruned"]
        details = []
        for index in np.flatnonzero(selected):
            vertices = edges[index]
            endpoints = []
            for vertex in vertices:
                endpoints.append({"id": int(vertex), "rest": co[vertex].tolist(),
                    "original": {groups[k]: float(original[vertex, k]) for k in np.flatnonzero(original[vertex] > .01)},
                    "diffused": {groups[k]: float(full[vertex, k]) for k in np.flatnonzero(full[vertex] > .01)},
                    "pruned": {groups[k]: float(limited[vertex, k]) for k in np.flatnonzero(limited[vertex] > .01)}})
            details.append({"edge": int(index), "rest_length": float(rest[index]),
                "posed_lengths": {label: float(values[index]) for label, values in posed.items()}, "vertices": endpoints})
        row = {"name": name, "clip": report["clip"], "frame": frame,
               "severe_edges": {label: int(values.sum()) for label, values in flags.items()},
               "introduced_by_pruning": int((flags["pruned"] & ~flags["diffused"]).sum()), "edges": details}
        results.append(row)
        print("PRUNING DIAGNOSTIC", name, report["clip"], row["severe_edges"], flush=True)
output.write_text(json.dumps(results, indent=2) + "\n")
print("PRUNING DIAGNOSTIC DONE", flush=True)
