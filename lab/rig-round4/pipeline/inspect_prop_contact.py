# Blender: measure a book's nearest distance from vertices assigned to its hand.
import json
from pathlib import Path

import bpy
from mathutils import Vector, kdtree

lane = Path(__file__).resolve().parent.parent
path = lane / "mobs/uncrossedSelf/rig-smooth/uncrossedSelf.blend"
bpy.ops.wm.open_mainfile(filepath=str(path))
arm = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
body = next(obj for obj in bpy.data.objects if obj.type == "MESH" and obj.find_armature() == arm)
arm.animation_data.action = bpy.data.actions["idle"]
bpy.context.scene.frame_set(1)
prop = next(obj for obj in bpy.data.objects if obj.type == "MESH" and obj.parent_bone == "LeftHand")
hand = body.vertex_groups["LeftHand"].index
vertices = [vertex for vertex in body.data.vertices if any(group.group == hand and group.weight > .5 for group in vertex.groups)]
assert vertices
hand_tree = kdtree.KDTree(len(vertices))
for index, vertex in enumerate(vertices):
    hand_tree.insert(body.matrix_world @ vertex.co, index)
hand_tree.balance()
nearest = min(((hand_tree.find(prop.matrix_world @ vertex.co), prop.matrix_world @ vertex.co) for vertex in prop.data.vertices), key=lambda pair: pair[0][2])
(point, index, distance), prop_point = nearest
shift = point - prop_point
report = {"hand_vertices": len(vertices), "gap_metres": distance, "hand_point": list(point),
          "book_point": list(prop_point), "suggested_shift_metres": list(shift)}
print("PROP CONTACT", json.dumps(report), flush=True)
(lane / "pipeline/book-contact-measurement.json").write_text(json.dumps(report, indent=2) + "\n")
