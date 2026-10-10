"""The ravine's cliff kit (R3.3, issue #660): six modular strata pieces, one
recipe per kind, placed along the river's banks by rule
(`presentation/map/landscape/ravine_cliffs.gd`).

Axes (Blender): x runs along the river, -y faces the water, +y runs back into
the bank, z = 0 is the bank's rim. A piece is a stack of strata, each layer a
slab whose front steps back from the water as it rises (the journey camera
looks down the ravine, so the ledges are what it sees), from below the water
(`BASE`) to a lip just above the rim; the layers under the lip run back into
the bank, where the ground hides them. Neighbours overlap, so a piece's ends
are ragged.
"""
import math

import sculpt as S

# Deep enough that, scaled up where the rim stands high (`ravine_cliffs.gd`),
# the foot reaches under the water; shallow enough that where the rim stands
# low the foot stays inside the journey camera's slab (5 m below the land's
# zero, `MapJourneyCameraContract.LAND_LOW`).
BASE = -4.0
BACK = 2.2
# Behind the lip the top layer ends here, so the rim stands as a rock edge.
LIP_BACK = 0.9
# Nothing is kept further back into the bank than this.
KEEP_BACK = 1.3
RECIPES = {
    "cliff-wall": {
        "description": "Strata wall: even ledges stepping back from the water",
        "seed": 7901, "budget": (950, 1200), "width": 3.2, "top": 0.25, "layer": (0.35, 0.7),
        "front": (-1.15, -0.25), "shape": "even"},
    "cliff-notch": {
        "description": "Strata wall cut by a deep weathered band, the layer above it overhanging",
        "seed": 7911, "budget": (950, 1200), "width": 2.8, "top": 0.3, "layer": (0.3, 0.8),
        "front": (-1.1, -0.2), "shape": "notch"},
    "cliff-buttress": {
        "description": "Strata wall with a jutting buttress whose facets turn toward the camera",
        "seed": 7921, "budget": (950, 1200), "width": 3.0, "top": 0.35, "layer": (0.35, 0.75),
        "front": (-1.2, -0.3), "shape": "buttress"},
    "cliff-bend": {
        "description": "Strata wall curved outward, for the outside of the river's bends",
        "seed": 7931, "budget": (950, 1200), "width": 3.1, "top": 0.25, "layer": (0.35, 0.7),
        "front": (-1.15, -0.25), "shape": "bend"},
    "cliff-step": {
        "description": "Low broken strata step where the rim stands low over the water",
        "seed": 7941, "budget": (950, 1200), "width": 2.9, "top": -0.35, "layer": (0.3, 0.6),
        "front": (-1.0, -0.15), "shape": "step"},
    "cliff-tall": {
        "description": "Tall strata wall with a high lip and an overhanging top ledge",
        "seed": 7951, "budget": (950, 1200), "width": 3.4, "top": 0.45, "layer": (0.4, 0.8),
        "front": (-1.25, -0.35), "shape": "tall"},
}


def _offset(shape, x, half):
    """How far the front stands out toward the water (-y) at `x` by shape."""
    if shape == "buttress":
        return -0.55 * max(0.0, 1.0 - abs(x) / (half * 0.42)) ** 1.5
    if shape == "bend":
        return -0.45 * (1.0 - (x / half) ** 2)
    return 0.0


def _layers(recipe, rng):
    low, high = recipe["layer"]
    bounds = []
    z = BASE
    while z < recipe["top"] - 0.05:
        thickness = rng.uniform(low, high)
        if recipe["top"] - (z + thickness) < low * 0.6:
            thickness = recipe["top"] - z
        bounds.append((z, z + thickness))
        z += thickness
    return bounds


def sculpt(kind, recipe, picture):
    """The kind's sculpt (high detail), painted for the bake."""
    rng = S.rng(recipe["seed"])
    half = recipe["width"] * 0.5
    front_low, front_high = recipe["front"]
    bounds = _layers(recipe, rng)
    notch = len(bounds) // 2
    slabs = []
    for index, (z0, z1) in enumerate(bounds):
        share = (z0 - BASE) / (recipe["top"] - BASE)
        front = front_low + (front_high - front_low) * share ** 0.85 + rng.uniform(-0.12, 0.12)
        if recipe["shape"] == "notch" and index == notch:
            front += 0.5
        if recipe["shape"] == "notch" and index == notch + 1:
            front -= 0.15
        if recipe["shape"] == "tall" and index == len(bounds) - 2:
            front -= 0.3
        last = index == len(bounds) - 1
        back = LIP_BACK if last else BACK
        left = -half * rng.uniform(0.86, 1.0)
        right = half * rng.uniform(0.86, 1.0)
        points = [(left, back), (left + rng.uniform(-0.1, 0.1), front + rng.uniform(0.0, 0.3))]
        steps = 12
        for i in range(1, steps):
            x = left + (right - left) * i / steps
            wobble = 0.1 * math.sin(x * 2.3 + index * 1.7) + rng.uniform(-0.06, 0.06)
            points.append((x, front + wobble + _offset(recipe["shape"], x, half)))
        points.append((right + rng.uniform(-0.1, 0.1), front + rng.uniform(0.0, 0.3)))
        points.append((right, back))
        slabs.append(S.prism("%s layer %d" % (kind, index), points, z0, z1 + 0.01))
    obj = S.join(slabs, kind + " sculpt")
    # What lies deep in the bank is never seen: the triangles go to the face.
    S.cut(obj, [((0.0, KEEP_BACK, 0.0), (0.0, 1.0, 0.0))])
    S.remesh(obj, 0.045)
    S.displace(obj, recipe["seed"], cracks=(0.07, 0.8, 0.07), swell=(0.06, 1.0),
        grain=(0.012, 0.06), squash=(1.0, 1.0, 0.3), joints=[z1 for _, z1 in bounds[:-1]],
        joint=(0.05, 0.035))
    obj.data.materials.clear()
    obj.data.materials.append(S.paint_material(kind + " paint", picture, 1.6, cavity=0.5, edge=0.18))
    return obj
