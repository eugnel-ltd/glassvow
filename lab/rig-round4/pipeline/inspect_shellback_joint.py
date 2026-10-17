# Blender: render the same claw-root region on source and repaired exported models.
import ast
import json
import os
from pathlib import Path
import shutil
import sys

import bpy
from mathutils import Vector

pipeline = Path(__file__).resolve().parent
lane = pipeline.parent
folder = lane / "mobs/shellback"
source = pipeline / "char_rig.py"
module = ast.parse(source.read_text(), filename=str(source))
assert module.body[-1].value.func.id == "main"
module.body.pop()
for variant in ("rig", "rig-smooth-contact"):
    assert os.getloadavg()[0] < 50 and shutil.disk_usage(lane).free / 2**30 >= 100
    settings = folder / "rig.json"
    sys.argv = [str(source), "--", str(settings)]
    helpers = {"__file__": str(source)}
    exec(compile(module, str(source), "exec"), helpers)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(folder / variant / "shellback.glb"), merge_vertices=True)
    arm = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
    body = next(obj for obj in bpy.data.objects if obj.type == "MESH" and obj.find_armature() == arm)
    print("JOINT BONES", variant, [bone.name for bone in arm.data.bones], flush=True)
    helpers["stage"]()
    arm.animation_data_create()
    for clip in ("idle", "death"):
        action = bpy.data.actions[clip]
        arm.animation_data.action = action
        bpy.context.scene.frame_set(int(action.frame_range[1]))
        graph = bpy.context.evaluated_depsgraph_get()
        evaluated = body.evaluated_get(graph)
        mesh = evaluated.to_mesh()
        points = [evaluated.matrix_world @ vertex.co for vertex in mesh.vertices]
        evaluated.to_mesh_clear()
        helpers["frame_camera"](points, (4, 0, .05))
        path = folder / variant / f"joint-{clip}-side.png"
        assert not path.exists()
        helpers["shot"](str(path))
        # A larger side image permits a direct crop without altering the pose.
        bpy.context.scene.render.resolution_x = 1024
        bpy.context.scene.render.resolution_y = 1280
        path = folder / variant / f"joint-{clip}-detail.png"
        assert not path.exists()
        helpers["shot"](str(path))
        bpy.context.scene.render.resolution_x = 512
        bpy.context.scene.render.resolution_y = 640
print("SHELLBACK JOINT VIEWS DONE", flush=True)
