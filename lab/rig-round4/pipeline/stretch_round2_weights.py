# Blender: source.blend --python this_file -- settings.json
# Smooth only the specified surface patches. Preserve every bone animation.
import json
from pathlib import Path
import sys

import bpy
import numpy as np

settings = json.loads(Path(sys.argv[sys.argv.index('--') + 1]).read_text())
arm = next(obj for obj in bpy.data.objects if obj.type == 'ARMATURE')
body = next(obj for obj in bpy.data.objects if obj.type == 'MESH' and obj.find_armature() == arm)
vertices = body.data.vertices
assert all(group.name in arm.data.bones for group in body.vertex_groups), 'Non-bone groups require separate handling'
assert all(sum(g.weight > 1e-6 for g in vertex.groups) <= 4 for vertex in vertices), 'Use a four-influence source'
assert {action.name for action in bpy.data.actions} == {'idle', 'walk', 'attack', 'cast', 'hurt', 'death'}
assert not arm.animation_data.nla_tracks, 'NLA timing requires separate handling'
positions = np.array([(body.matrix_world @ vertex.co)[:] for vertex in vertices])
weights = np.zeros((len(vertices), len(body.vertex_groups)))
for vertex in vertices:
    for group in vertex.groups:
        weights[vertex.index, group.group] = group.weight
edges = np.array([edge.vertices[:] for edge in body.data.edges])
a, b = edges.T
degree = np.bincount(a, minlength=len(vertices)) + np.bincount(b, minlength=len(vertices))
blend = np.zeros(len(vertices))
for centre, radius in settings['patches']:
    t = np.clip(1 - np.linalg.norm(positions - centre, axis=1) / radius, 0, 1)
    blend = np.maximum(blend, t * t * (3 - 2 * t))
original = weights.copy()
bone_filter = settings.get('allowed_bones') or settings.get('removed_bones')
if bone_filter:
    names = settings.get('allowed_bones') or [g.name for g in body.vertex_groups if g.name not in settings['removed_bones']]
    allowed = [body.vertex_groups[name].index for name in names]
    if settings.get('gate_bones'):
        # Filter only vertices that the gate bones dominate (a long sleeve, not the robe it joins).
        share = original[:, [body.vertex_groups[name].index for name in settings['gate_bones']]].sum(axis=1)
        low, high = settings['gate_range']
        t = np.clip((share - low) / (high - low), 0, 1)
        blend *= t * t * (3 - 2 * t)
    target = np.zeros_like(weights)
    target[:, allowed] = weights[:, allowed]
    target /= np.maximum(target.sum(axis=1, keepdims=True), 1e-12)
    strength = np.minimum(1, blend * 2)
    weights += strength[:, None] * (target - weights)
for _ in range(settings.get('iterations', 8)):
    sums = np.zeros_like(weights)
    np.add.at(sums, a, weights[b])
    np.add.at(sums, b, weights[a])
    weights += .5 * blend[:, None] * (sums / np.maximum(degree, 1)[:, None] - weights)
    if bone_filter:
        raise AssertionError('Use zero smoothing iterations with the local bone filter')
# Match the engine's four-influence skinning before ground contact is measured.
keep = np.argsort(weights, axis=1)[:, -4:]
limited = np.zeros_like(weights)
np.put_along_axis(limited, keep, np.take_along_axis(weights, keep, axis=1), axis=1)
weights = limited / np.maximum(limited.sum(axis=1, keepdims=True), 1e-12)
weights[blend == 0] = original[blend == 0]
assert np.isfinite(weights).all() and np.allclose(weights.sum(axis=1), 1, atol=.002)
assert np.array_equal(weights[blend == 0], original[blend == 0]), 'Untargeted weights changed'
for group in body.vertex_groups:
    group.remove(list(range(len(vertices))))
for index, row in enumerate(weights):
    for group in np.flatnonzero(row):
        body.vertex_groups[int(group)].add([index], float(row[group]), 'REPLACE')
# Contact candidates use 120 FPS to sample quarter frames. Restore 30 FPS for grounding.
assert bpy.context.scene.render.fps == 120, 'Use a grounded quarter-frame source'
factor = 4
for action in bpy.data.actions:
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    assert not curve.modifiers and not curve.sampled_points, 'Use baked keyframes without curve modifiers'
                    for key in curve.keyframe_points:
                        key.co.x /= factor
                        key.handle_left.x /= factor
                        key.handle_right.x /= factor
    if action.use_frame_range:
        action.frame_start /= factor
        action.frame_end /= factor
bpy.context.scene.render.fps = 30
output = Path(settings['source_output'])
assert not output.exists(), 'Preserve an existing trial'
output.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(output))
print('LOCAL WEIGHTS', int((blend > 0).sum()), 'vertices; peak change', float(np.abs(weights - original).max()), flush=True)
