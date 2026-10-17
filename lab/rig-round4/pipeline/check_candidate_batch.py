# Engine only: run with Blender and name/rig-folder arguments.
# Add --self-check before one candidate to verify the detached-prop negative control.
import json
import os
from pathlib import Path
import runpy
import shutil
import sys

import bpy

pipeline = Path(__file__).resolve().parent
lane = pipeline.parent


def check_structure(arm, body):
    totals = [sum(group.weight for group in vertex.groups) for vertex in body.data.vertices]
    unweighted = sum(total < 1e-3 for total in totals)
    influences = max(sum(group.weight > 1e-6 for group in vertex.groups) for vertex in body.data.vertices)
    assert unweighted == 0 and influences <= 4, (unweighted, influences)
    assert all(abs(total - 1) < .002 for total in totals), "Weights are not normalised"
    # The glTF importer creates display meshes referenced by pose bones.
    shapes = {bone.custom_shape for bone in arm.pose.bones if bone.custom_shape}
    props = [obj for obj in bpy.context.scene.objects
             if obj.type == "MESH" and obj is not body and obj not in shapes]
    for prop in props:
        assert prop.parent == arm and prop.parent_type == "BONE", (prop.name, "Detached prop")
        assert prop.parent_bone in arm.data.bones, (prop.name, "Missing attachment bone")
        assert all(value == value and abs(value) < 1e6 for row in prop.matrix_world for value in row), (prop.name, "Invalid prop transform")
    return {"bones": len(arm.data.bones), "vertices": len(body.data.vertices),
            "unweighted": unweighted, "max_influences": influences,
            "props": [{"name": prop.name, "bone": prop.parent_bone} for prop in props]}


def main():
    candidates = sys.argv[sys.argv.index("--") + 1:]
    control = "--self-check" in candidates
    if control:
        candidates.remove("--self-check")
        assert len(candidates) == 1, "Use one candidate with a prop for the control"
    results = []
    for candidate in candidates:
        parts = candidate.split("/")
        if len(parts) == 2:
            parts.insert(0, "mobs")
        assert len(parts) == 3 and parts[0] in ("chars", "mobs")
        assert all(part and part.replace("-", "").isalnum() for part in parts)
        root, name, directory = parts
        folder = lane / root / name / directory
        free = shutil.disk_usage(lane).free / 2**30
        print("CHECK", candidate, "load", os.getloadavg()[0], "free GiB", round(free, 2), flush=True)
        assert os.getloadavg()[0] < 50 and free >= 100, "Resource floor reached"
        glb = folder / (name + ".glb")
        if control:
            bpy.ops.wm.read_factory_settings(use_empty=True)
            bpy.ops.import_scene.gltf(filepath=str(glb), merge_vertices=True)
        else:
            sys.argv = [str(pipeline / "check_deformation.py"), "--", str(folder / "reimport-deformation.json"), str(glb)]
            runpy.run_path(str(pipeline / "check_deformation.py"), run_name="__main__")
        arm = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
        body = next(obj for obj in bpy.data.objects if obj.type == "MESH" and obj.find_armature() == arm)
        report = {"candidate": candidate, **check_structure(arm, body)}
        if control:
            assert len(report["props"]) == 1 and any(bone.custom_shape for bone in arm.pose.bones)
            prop = bpy.data.objects[report["props"][0]["name"]]
            prop.parent = None
            try:
                check_structure(arm, body)
            except AssertionError as error:
                assert "Detached prop" in str(error), str(error)
            else:
                raise AssertionError("Detached prop was accepted")
            print("CONTROL PASS: imported display shape accepted; detached prop rejected", flush=True)
            return
        (folder / "structure.json").write_text(json.dumps(report, indent=2) + "\n")
        results.append(report)
        print("STRUCTURE", json.dumps(report), flush=True)
    print("INSPECTION DONE", len(results), flush=True)


main()
