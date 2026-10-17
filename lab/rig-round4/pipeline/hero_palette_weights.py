# Blender: compare one shared four-bone palette per local discontinuity patch.
import ast
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
module = ast.parse((pipeline / "hero_local_weights.py").read_text())
module.body = [node for node in module.body if isinstance(node, (ast.Import, ast.ImportFrom, ast.FunctionDef))]
helpers = {"__file__": str(pipeline / "hero_local_weights.py")}
exec(compile(module, "hero_local_weights.py", "exec"), helpers)
for name in ("duskblade", "ashwarden"):
    assert os.getloadavg()[0] < 50 and shutil.disk_usage(lane).free / 2**30 >= 100
    folder = lane / "chars" / name
    output = folder / "rig-local-palette"
    assert not output.exists(), "Preserve an existing experiment"
    bpy.ops.wm.open_mainfile(filepath=str(folder / "rig-local-weights" / f"{name}.blend"))
    arm = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
    body = next(obj for obj in bpy.data.objects if obj.type == "MESH" and obj.find_armature() == arm)
    co = np.array([vertex.co[:] for vertex in body.data.vertices])
    edges = np.array([edge.vertices[:] for edge in body.data.edges])
    a, b = edges.T
    rest = np.linalg.norm(co[a] - co[b], axis=1)
    degree = np.maximum(np.bincount(a, minlength=len(co)) + np.bincount(b, minlength=len(co)), 1)[:, None]
    adjacency = [[] for _ in co]
    for u, v in edges:
        adjacency[u].append(v)
        adjacency[v].append(u)
    original = helpers["weights"](body)
    current = original.copy()
    best = current.copy()
    best_count = len(edges)
    history = []
    for iteration in range(6):
        assert os.getloadavg()[0] < 50 and shutil.disk_usage(lane).free / 2**30 >= 100
        bad = helpers["bad_edges"](arm, body, edges, rest)
        count = int(bad.sum())
        history.append({"iteration": iteration, "bad_edges": count})
        print("PALETTE ROUND", name, iteration, count, flush=True)
        if count < best_count:
            best_count, best = count, current.copy()
        if count == 0 or iteration == 5:
            break
        mask = np.zeros(len(co), dtype=bool)
        mask[edges[bad].ravel()] = True
        for _ in range(3):
            mask[edges[mask[a] | mask[b]].ravel()] = True
        unseen = set(np.flatnonzero(mask).tolist())
        patches = []
        while unseen:
            todo = [unseen.pop()]
            patch = []
            while todo:
                vertex = todo.pop()
                patch.append(vertex)
                for neighbour in adjacency[vertex]:
                    if neighbour in unseen:
                        unseen.remove(neighbour)
                        todo.append(neighbour)
            patches.append(np.array(patch))
        allowed = np.ones_like(current, dtype=bool)
        palettes = []
        for patch in patches:
            support = np.argsort(current[patch].sum(0))[-4:]
            allowed[patch] = False
            allowed[np.ix_(patch, support)] = True
            palettes.append({"vertices": len(patch), "bones": [body.vertex_groups[int(k)].name for k in support]})
        history[-1]["patches"] = palettes
        for _ in range(24):
            neighbours = np.zeros_like(current)
            np.add.at(neighbours, a, current[b])
            np.add.at(neighbours, b, current[a])
            current[mask] = .5 * current[mask] + .5 * neighbours[mask] / degree[mask]
            current[~allowed] = 0
            totals = current.sum(1, keepdims=True)
            assert np.all(totals > 1e-8)
            current /= totals
        current = helpers["apply"](body, current)
    helpers["apply"](body, best)
    output.mkdir()
    (output / "repair.json").write_text(json.dumps({"source": "rig-local-weights", "history": history,
        "selected_bad_edges_at_17_samples_per_clip": best_count,
        "changed_vertices": int((np.abs(best - original).max(1) > 1e-5).sum()),
        "limitation": "A local palette can still produce a boundary discontinuity; inspect the dense exported check"}, indent=2) + "\n")
    arm.animation_data.action = bpy.data.actions["idle"]
    bpy.context.scene.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=str(output / f"{name}.blend"))
    bpy.ops.export_scene.gltf(filepath=str(output / f"{name}.glb"), export_format="GLB",
                              export_animations=True, export_animation_mode="ACTIONS")
    sys.argv = [str(pipeline / "check_candidate_batch.py"), "--", f"chars/{name}/rig-local-palette"]
    runpy.run_path(str(pipeline / "check_candidate_batch.py"), run_name="__main__")
    print("PALETTE EXPORT DONE", name, flush=True)
