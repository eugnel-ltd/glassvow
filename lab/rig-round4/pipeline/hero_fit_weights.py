# Blender: fit four influences to sampled deformation, without changing authored motions.
import ast
from itertools import combinations
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
    output = folder / "rig-fitted-weights"
    assert not output.exists(), "Preserve an existing experiment"
    bpy.ops.wm.open_mainfile(filepath=str(folder / "rig-local-weights" / f"{name}.blend"))
    arm = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
    body = next(obj for obj in bpy.data.objects if obj.type == "MESH" and obj.find_armature() == arm)
    groups = list(body.vertex_groups)
    assert all(group.name in arm.pose.bones for group in groups)
    co = np.array([vertex.co[:] for vertex in body.data.vertices])
    homogeneous = np.column_stack((co, np.ones(len(co))))
    edges = np.array([edge.vertices[:] for edge in body.data.edges])
    a, b = edges.T
    rest = np.linalg.norm(co[a] - co[b], axis=1)
    degree = np.maximum(np.bincount(a, minlength=len(co)) + np.bincount(b, minlength=len(co)), 1)[:, None]
    original = helpers["weights"](body)
    transforms = []
    for action in bpy.data.actions:
        arm.animation_data.action = action
        for frame in np.linspace(*action.frame_range, 17):
            bpy.context.scene.frame_set(int(frame), subframe=float(frame % 1))
            matrices = []
            for group in groups:
                bone = arm.pose.bones[group.name]
                matrix = body.matrix_world.inverted() @ arm.matrix_world @ bone.matrix @ bone.bone.matrix_local.inverted() @ arm.matrix_world.inverted() @ body.matrix_world
                matrices.append(np.array(matrix)[:3])
            matrices = np.array(matrices)
            transformed = np.einsum("bij,nj->nbi", matrices, homogeneous)
            predicted = np.einsum("nb,nbi->ni", original, transformed)
            evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
            mesh = evaluated.to_mesh()
            actual = np.array([vertex.co[:] for vertex in mesh.vertices])
            evaluated.to_mesh_clear()
            error = float(np.abs(actual - predicted).max())
            assert error < 2e-5, ("Skinning reconstruction differs", error)
            transforms.append(transformed)
    deformation = np.transpose(np.array(transforms), (1, 2, 0, 3))
    del transforms
    motion = (deformation - co[:, None, None, :]).reshape(len(co), len(groups), -1)

    def severe(array):
        positions = np.einsum("nb,nbsd->nsd", array, deformation)
        lengths = np.linalg.norm(positions[a] - positions[b], axis=2)
        return ((rest[:, None] > 1e-6) & (lengths > 3 * rest[:, None]) & (lengths > .03)).any(1)

    current = original.copy()
    best = current.copy()
    best_count = int(severe(current).sum())
    history = [best_count]
    for iteration in range(4):
        assert os.getloadavg()[0] < 50 and shutil.disk_usage(lane).free / 2**30 >= 100
        bad = severe(current)
        if not bad.any():
            break
        mask = np.zeros(len(co), dtype=bool)
        mask[edges[bad].ravel()] = True
        for _ in range(3):
            mask[edges[mask[a] | mask[b]].ravel()] = True
        full = current.copy()
        for _ in range(24):
            neighbours = np.zeros_like(full)
            np.add.at(neighbours, a, full[b])
            np.add.at(neighbours, b, full[a])
            full[mask] = .5 * full[mask] + .5 * neighbours[mask] / degree[mask]
        ids = np.flatnonzero(mask)
        # Search only the eight strongest local influences; all candidate palettes have four entries.
        palette = np.argsort(full[ids], axis=1)[:, -8:]
        features = np.take_along_axis(motion[ids], palette[:, :, None], axis=1)
        target = np.einsum("nb,nbd->nd", full[ids], motion[ids])
        gram = np.einsum("nid,njd->nij", features, features)
        rhs = np.einsum("nid,nd->ni", features, target)
        target_norm = np.einsum("nd,nd->n", target, target)
        fitted = current[ids].copy()
        delta = np.einsum("nb,nbd->nd", fitted, motion[ids]) - target
        loss = np.einsum("nd,nd->n", delta, delta)
        for support in combinations(range(8), 4):
            support = np.array(support)
            g = gram[:, support][:, :, support]
            h = rhs[:, support]
            kkt = np.zeros((len(ids), 5, 5))
            kkt[:, :4, :4] = g + np.eye(4)[None] * 1e-7
            kkt[:, :4, 4] = 1
            kkt[:, 4, :4] = 1
            values = np.concatenate((h, np.ones((len(ids), 1))), axis=1)
            weights = np.linalg.solve(kkt, values[..., None])[..., 0][:, :4]
            weights = np.maximum(weights, 0)
            weights /= weights.sum(1, keepdims=True)
            candidate_loss = np.einsum("ni,nij,nj->n", weights, g, weights) - 2 * np.einsum("ni,ni->n", weights, h) + target_norm
            better = candidate_loss < loss
            chosen = palette[:, support]
            fitted[better] = 0
            rows = np.flatnonzero(better)
            fitted[rows[:, None], chosen[rows]] = weights[rows]
            loss[better] = candidate_loss[better]
        current[ids] = fitted
        assert np.isfinite(current).all() and np.allclose(current.sum(1), 1)
        assert np.count_nonzero(current > 1e-6, axis=1).max() <= 4
        count = int(severe(current).sum())
        history.append(count)
        print("FITTED ROUND", name, iteration, count, flush=True)
        if count < best_count:
            best_count, best = count, current.copy()
    helpers["apply"](body, best)
    output.mkdir()
    (output / "repair.json").write_text(json.dumps({"source": "rig-local-weights", "bad_edge_union": history,
        "selected_bad_edge_union": best_count, "sampled_poses": deformation.shape[2],
        "maximum_influences": 4, "limitation": "A sampled fit does not prove continuous deformation or cloth quality"}, indent=2) + "\n")
    arm.animation_data.action = bpy.data.actions["idle"]
    bpy.context.scene.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=str(output / f"{name}.blend"))
    bpy.ops.export_scene.gltf(filepath=str(output / f"{name}.glb"), export_format="GLB",
                              export_animations=True, export_animation_mode="ACTIONS")
    sys.argv = [str(pipeline / "check_candidate_batch.py"), "--", f"chars/{name}/rig-fitted-weights"]
    runpy.run_path(str(pipeline / "check_candidate_batch.py"), run_name="__main__")
    print("FITTED EXPORT DONE", name, flush=True)
