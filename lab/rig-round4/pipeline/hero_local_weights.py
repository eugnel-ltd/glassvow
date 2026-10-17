# Blender: repair local weight discontinuities, with a fixed eight-round budget.
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


def weights(body):
    array = np.zeros((len(body.data.vertices), len(body.vertex_groups)))
    for vertex in body.data.vertices:
        for group in vertex.groups:
            array[vertex.index, group.group] = group.weight
    return array


def apply(body, array):
    # Match the four-influence export contract during every round.
    keep = np.argpartition(array, -4, axis=1)[:, -4:]
    limited = np.zeros_like(array)
    np.put_along_axis(limited, keep, np.take_along_axis(array, keep, axis=1), axis=1)
    limited /= np.maximum(limited.sum(1, keepdims=True), 1e-12)
    for group in body.vertex_groups:
        group.remove(list(range(len(array))))
    for vertex, row in enumerate(limited):
        for index in np.flatnonzero(row > 1e-6):
            body.vertex_groups[index].add([vertex], float(row[index]), "REPLACE")
    return limited


def bad_edges(arm, body, edges, lengths):
    marked = np.zeros(len(edges), dtype=bool)
    for action in bpy.data.actions:
        arm.animation_data.action = action
        first, last = action.frame_range
        for frame in np.linspace(first, last, 17):
            bpy.context.scene.frame_set(int(frame), subframe=float(frame % 1))
            evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
            mesh = evaluated.to_mesh()
            points = np.array([vertex.co[:] for vertex in mesh.vertices])
            evaluated.to_mesh_clear()
            posed = np.linalg.norm(points[edges[:, 0]] - points[edges[:, 1]], axis=1)
            assert np.isfinite(points).all()
            marked |= (lengths > 1e-6) & (posed > lengths * 3) & (posed > .03)
    return marked


for name in ("duskblade", "ashwarden"):
    assert os.getloadavg()[0] < 50 and shutil.disk_usage(lane).free / 2**30 >= 100
    folder = lane / "chars" / name
    output = folder / "rig-local-weights"
    assert not output.exists(), "Preserve an existing experiment"
    bpy.ops.wm.open_mainfile(filepath=str(folder / "rig-aligned-surface" / f"{name}.blend"))
    arm = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
    body = next(obj for obj in bpy.data.objects if obj.type == "MESH" and obj.find_armature() == arm)
    rest = np.array([vertex.co[:] for vertex in body.data.vertices])
    edges = np.array([edge.vertices[:] for edge in body.data.edges])
    lengths = np.linalg.norm(rest[edges[:, 0]] - rest[edges[:, 1]], axis=1)
    a, b = edges.T
    degree = np.maximum(np.bincount(a, minlength=len(rest)) + np.bincount(b, minlength=len(rest)), 1)[:, None]
    original = weights(body)
    current = original.copy()
    history = []
    changed = np.zeros(len(rest), dtype=bool)
    for iteration in range(8):
        assert os.getloadavg()[0] < 50 and shutil.disk_usage(lane).free / 2**30 >= 100
        bad = bad_edges(arm, body, edges, lengths)
        history.append(int(bad.sum()))
        print("LOCAL ROUND", name, iteration, history[-1], flush=True)
        if not bad.any():
            break
        mask = np.zeros(len(rest), dtype=bool)
        mask[edges[bad].ravel()] = True
        for _ in range(3):
            touching = mask[a] | mask[b]
            mask[edges[touching].ravel()] = True
        changed |= mask
        for _ in range(24):
            neighbours = np.zeros_like(current)
            np.add.at(neighbours, a, current[b])
            np.add.at(neighbours, b, current[a])
            current[mask] = .5 * current[mask] + .5 * neighbours[mask] / degree[mask]
        current = apply(body, current)
    output.mkdir()
    (output / "repair.json").write_text(json.dumps({"source": "rig-aligned-surface", "rounds": history,
        "changed_vertices": int(changed.sum()), "total_vertices": len(rest),
        "maximum_weight_change": float(np.abs(current - original).max()),
        "limit": "Local weight continuity only; no guarantee of anatomical deformation or cloth dynamics"}, indent=2) + "\n")
    arm.animation_data.action = bpy.data.actions["idle"]
    bpy.context.scene.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=str(output / f"{name}.blend"))
    bpy.ops.export_scene.gltf(filepath=str(output / f"{name}.glb"), export_format="GLB",
                              export_animations=True, export_animation_mode="ACTIONS")
    sys.argv = [str(pipeline / "check_candidate_batch.py"), "--", f"chars/{name}/rig-local-weights"]
    runpy.run_path(str(pipeline / "check_candidate_batch.py"), run_name="__main__")
    print("LOCAL EXPORT DONE", name, flush=True)
