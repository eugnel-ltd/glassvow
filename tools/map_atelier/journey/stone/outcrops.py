"""Act I's five granite outcrops (R3.3, issue #660): one recipe per kind.

Granite weathers into rounded blocks along its joints: each kind is a few
rounded masses fused, cut by its joint planes, and cracked along them
(`sculpt.py`). Blender Z is up; the ground line is z = 0 and every kind sinks
a little below it, so it sits on a slope without a gap.

The first three take the places of the R1 slate kinds they replace (the same
footprint circle and height, `kit.gd` `PROFILES`); the tor anchors the islands
between the road loops, the boulder scatters.
"""
import sculpt as S

# A block: size (x, y, z), centre, turn (radians, XYZ), how round its edges.
RECIPES = {
    "granite-bank": {
        "description": "Broad low granite mound: three rounded blocks on a flat joint top, a fallen piece at its foot",
        "seed": 7801, "budget": (1100, 1400), "voxel": 0.025,
        "blocks": [
            ((2.3, 1.5, 1.25), (-0.25, 0.0, 0.45), (0.03, -0.04, 0.12), 0.28),
            ((1.5, 1.25, 1.0), (0.85, 0.15, 0.3), (0.0, 0.06, -0.35), 0.3),
            ((1.25, 0.95, 0.7), (-0.45, 0.05, 1.15), (0.06, -0.08, 0.4), 0.3),
            ((0.8, 0.7, 0.5), (1.3, -0.5, 0.05), (0.1, 0.0, 0.8), 0.35),
        ],
        "cuts": [((0.0, 0.0, 1.62), (0.06, 0.03, 1.0)), ((1.6, 0.0, 0.0), (1.0, 0.15, 0.05)),
                 ((0.0, -0.84, 0.0), (0.05, -1.0, 0.35))],
        "joints": (),
    },
    "granite-ridge": {
        "description": "Long low granite ridge: four jointed blocks falling away to one end",
        "seed": 7811, "budget": (1000, 1300), "voxel": 0.025,
        "blocks": [
            ((1.3, 0.95, 0.95), (-1.3, 0.05, 0.3), (0.0, 0.04, 0.1), 0.3),
            ((1.4, 1.1, 1.1), (-0.1, 0.0, 0.4), (0.05, 0.0, -0.1), 0.3),
            ((1.2, 0.9, 0.85), (1.1, -0.05, 0.25), (0.0, -0.05, 0.25), 0.3),
            ((0.7, 0.6, 0.5), (1.85, 0.1, 0.05), (0.0, 0.0, 0.6), 0.35),
        ],
        "cuts": [((0.0, 0.0, 0.98), (0.12, 0.02, 1.0)), ((0.0, 0.52, 0.0), (0.05, 1.0, 0.2))],
        "joints": (),
    },
    "granite-shard": {
        "description": "Upright granite pillar split from its bed, a leaning slab against it",
        "seed": 7821, "budget": (800, 1000), "voxel": 0.022,
        "blocks": [
            ((0.85, 0.65, 2.3), (0.0, 0.0, 0.95), (0.12, 0.05, 0.2), 0.18),
            ((0.55, 0.45, 1.25), (0.55, 0.15, 0.45), (-0.1, 0.2, -0.3), 0.25),
            ((0.5, 0.45, 0.4), (-0.45, -0.25, 0.05), (0.0, 0.0, 0.5), 0.35),
        ],
        "cuts": [((0.0, 0.0, 2.0), (0.35, 0.1, 1.0)), ((0.0, -0.33, 0.0), (0.0, -1.0, 0.1))],
        "joints": (),
    },
    "granite-tor": {
        "description": "Stacked granite tor: three blocks on level joints, a boulder shed at its side",
        "seed": 7831, "budget": (1300, 1500), "voxel": 0.028,
        "blocks": [
            ((2.5, 1.9, 0.95), (0.0, 0.0, 0.35), (0.0, 0.0, 0.1), 0.25),
            ((1.9, 1.5, 0.85), (0.15, 0.1, 1.2), (0.03, -0.02, -0.25), 0.28),
            ((1.25, 1.0, 0.7), (-0.1, 0.05, 1.95), (0.06, 0.04, 0.35), 0.32),
            ((0.9, 0.8, 0.7), (-1.35, -0.35, 0.15), (0.0, 0.0, 0.6), 0.4),
        ],
        "cuts": [((0.0, 0.0, 2.28), (0.08, -0.05, 1.0)), ((1.25, 0.0, 0.0), (1.0, -0.2, 0.0))],
        "joints": (0.82, 1.62),
    },
    "granite-boulder": {
        "description": "A single rounded granite boulder with a split face and a chip beside it",
        "seed": 7841, "budget": (800, 950), "voxel": 0.02,
        "blocks": [
            ((1.5, 1.15, 1.05), (0.0, 0.0, 0.32), (0.05, 0.04, 0.2), 0.4),
            ((0.6, 0.5, 0.4), (0.78, -0.38, 0.0), (0.0, 0.0, 1.0), 0.4),
        ],
        "cuts": [((0.0, 0.0, 0.92), (0.2, 0.1, 1.0)), ((0.72, 0.0, 0.0), (1.0, 0.2, 0.1))],
        "joints": (),
    },
}
# Every kind's foot: what lies below this is cut away (the ground hides it).
SINK = -0.3


def sculpt(kind, recipe, picture):
    """The kind's sculpt (high detail), painted for the bake."""
    blocks = [S.block("%s block %d" % (kind, i), size, at, turn, round_share)
              for i, (size, at, turn, round_share) in enumerate(recipe["blocks"])]
    obj = S.join(blocks, kind + " sculpt")
    S.remesh(obj, recipe["voxel"] * 1.6)
    S.cut(obj, list(recipe["cuts"]) + [((0.0, 0.0, SINK), (0.0, 0.0, -1.0))])
    S.remesh(obj, recipe["voxel"])
    S.smooth(obj, 0.45, 2)
    S.displace(obj, recipe["seed"], cracks=(0.045, 0.9, 0.06), swell=(0.05, 0.8),
        grain=(0.008, 0.05), joints=recipe["joints"], joint=(0.06, 0.035))
    obj.data.materials.clear()
    obj.data.materials.append(S.paint_material(kind + " paint", picture, 1.4, cavity=0.45, edge=0.2))
    return obj
