"""Act I's ruins (R3.3, issue #660): four weathered gravestones, three
broken-wall pieces and three rubble clusters, one recipe per kind. Each is
drawn as an impostor (`tools/map_atelier/journey/impostors/`), so its sculpt
is kept at a few thousand triangles as the impostor bake's source, with its
colour baked onto its own UVs; neither ships.

Blender Z is up, the ground line z = 0; -y is a stone's face.
"""
import math

import sculpt as S

MOSS = (0.11, 0.13, 0.05)
RECIPES = {
    "grave-arched": {"description": "Round-headed headstone with a sunk panel, leaning, its corner chipped",
                     "seed": 8001, "budget": (2500, 3500), "texels": 256},
    "grave-cross": {"description": "Ringed cross on a stepped plinth, one arm broken short",
                    "seed": 8011, "budget": (3000, 4000), "texels": 256},
    "grave-broken": {"description": "Pointed headstone snapped across, its head fallen at its foot",
                     "seed": 8021, "budget": (2500, 3500), "texels": 256},
    "grave-tablet": {"description": "Squat tablet leaning hard over its sunken ledger slab",
                     "seed": 8031, "budget": (2500, 3500), "texels": 256},
    "wall-run": {"description": "Run of coursed ashlar falling from shoulder height to its footing",
                 "seed": 8101, "budget": (5000, 7000), "texels": 512},
    "wall-corner": {"description": "Corner of a ruined building, its two runs broken off",
                    "seed": 8111, "budget": (5000, 7000), "texels": 512},
    "wall-pier": {"description": "Wall ending in a tall pier, an arch's springer stone left on it",
                  "seed": 8121, "budget": (5000, 7000), "texels": 512},
    "rubble-blocks": {"description": "Heap of fallen ashlar blocks, half sunk",
                      "seed": 8201, "budget": (2500, 3500), "texels": 256},
    "rubble-scree": {"description": "Fan of angular granite scree",
                     "seed": 8211, "budget": (2500, 3500), "texels": 256},
    "rubble-mossy": {"description": "Low mound of stones under moss",
                     "seed": 8221, "budget": (2000, 3000), "texels": 256},
}
SINK = -0.25
COURSE = 0.28
GAP = 0.03


def _arch_outline(half, shoulder, top, steps=10):
    points = [(-half, SINK), (half, SINK), (half, shoulder)]
    for i in range(1, steps):
        a = math.pi * i / steps
        points.append((half * math.cos(a), shoulder + (top - shoulder) * math.sin(a)))
    points.append((-half, shoulder))
    return points


def _pointed_outline(half, shoulder, top, steps=6):
    points = [(-half, SINK), (half, SINK), (half, shoulder)]
    for i in range(1, steps):
        t = i / steps
        points.append((half * (1.0 - t) ** 1.3, shoulder + (top - shoulder) * math.sin(t * math.pi * 0.5)))
    points.append((0.0, top))
    for i in range(steps - 1, 0, -1):
        t = i / steps
        points.append((-half * (1.0 - t) ** 1.3, shoulder + (top - shoulder) * math.sin(t * math.pi * 0.5)))
    points.append((-half, shoulder))
    return points


def _weather(obj, seed, voxel=0.012):
    S.remesh(obj, voxel)
    S.displace(obj, seed, cracks=(0.008, 6.0, 0.05), swell=(0.006, 0.15), grain=(0.0025, 0.02))


def grave_arched(rng):
    stone = S.slab("Headstone", _arch_outline(0.28, 0.72, 1.0), 0.12)
    panel = S.block("Panel", (0.32, 0.04, 0.3), (0.0, -0.07, 0.5), round_share=0.05)
    S.boolean(stone, panel)
    S.cut(stone, [((0.24, 0.0, 0.88), (0.7, -0.2, 0.7))])
    _weather(stone, 8001)
    return S.place(stone, (0.0, 0.0, 0.0), (math.radians(-7.0), math.radians(3.0), 0.0))


def grave_cross(rng):
    parts = [S.block("Plinth", (0.5, 0.36, 0.2), (0.0, 0.0, -0.08), round_share=0.1),
             S.block("Plinth step", (0.36, 0.26, 0.14), (0.0, 0.0, 0.12), round_share=0.12),
             S.block("Shaft", (0.15, 0.12, 1.12), (0.0, 0.0, 0.7), round_share=0.12),
             S.block("Arm", (0.5, 0.12, 0.14), (-0.06, 0.0, 0.98), round_share=0.12),
             S.torus("Ring", 0.17, 0.03, (0.0, 0.0, 0.98), (math.pi * 0.5, 0.0, 0.0))]
    cross = S.join(parts, "Cross")
    S.remesh(cross, 0.012)
    S.cut(cross, [((-0.27, 0.0, 0.98), (-1.0, 0.1, 0.4))])
    _weather(cross, 8011, 0.011)
    return S.place(cross, (0.0, 0.0, 0.0), (math.radians(4.0), math.radians(-5.0), 0.0))


def grave_broken(rng):
    outline = _pointed_outline(0.27, 0.7, 1.08)
    stone = S.slab("Headstone", outline, 0.13)
    head = S.slab("Fallen head", outline, 0.13)
    S.cut(stone, [((0.0, 0.0, 0.55), (0.35, 0.0, 1.0))])
    S.cut(head, [((0.0, 0.0, 0.55), (-0.35, 0.0, -1.0))])
    # Laid on its face before the stone: its length runs toward the camera.
    S.place(head, (0.1, 0.35, 0.03), (math.radians(88.0), 0.0, math.radians(18.0)))
    _weather(stone, 8021)
    _weather(head, 8022)
    S.place(stone, (0.0, 0.0, 0.0), (math.radians(-4.0), math.radians(6.0), 0.0))
    return S.join([stone, head], "Broken headstone")


def grave_tablet(rng):
    tablet = S.block("Tablet", (0.48, 0.17, 0.86), (0.0, 0.0, 0.18), round_share=0.35, segments=4)
    S.place(tablet, (0.0, 0.0, 0.0), (math.radians(-14.0), math.radians(-4.0), 0.0))
    ledger = S.block("Ledger", (0.5, 0.95, 0.12), (0.0, -0.62, -0.02), (0.03, -0.02, 0.05), round_share=0.25)
    S.cut(ledger, [((0.22, -1.05, 0.0), (0.6, -0.8, 0.1))])
    _weather(tablet, 8031)
    _weather(ledger, 8032)
    return S.join([tablet, ledger], "Tablet and ledger")


def _wall(rng, runs, name):
    """Coursed ashlar: each run (start, end, thickness, height at start, at
    end) laid in courses of blocks, cut off above its broken top."""
    stones = []
    for start, end, thickness, rise_a, rise_b in runs:
        ax, ay = start
        bx, by = end
        length = math.hypot(bx - ax, by - ay)
        angle = math.atan2(by - ay, bx - ax)
        course = 0
        z = SINK
        while z < max(rise_a, rise_b):
            along = -rng.uniform(0.0, 0.3) if course % 2 else 0.0
            while along < length:
                size = rng.uniform(0.38, 0.72)
                centre = min(along + size * 0.5, length - 0.05)
                share = centre / length
                top = rise_a + (rise_b - rise_a) * share + 0.18 * math.sin(centre * 4.1 + course)
                if z + COURSE * 0.5 < top and (z > 0.2 or rng.random() > 0.04):
                    x = ax + math.cos(angle) * centre
                    y = ay + math.sin(angle) * centre
                    stones.append(S.block("Ashlar", (size - GAP, thickness - rng.uniform(0.0, 0.05), COURSE - GAP),
                        (x, y, z + COURSE * 0.5),
                        (rng.uniform(-0.02, 0.02), rng.uniform(-0.02, 0.02), angle + rng.uniform(-0.03, 0.03)),
                        round_share=0.14))
                along += size
            z += COURSE
            course += 1
    for i in range(rng.randint(2, 4)):
        size = rng.uniform(0.35, 0.6)
        stones.append(S.block("Fallen ashlar", (size, size * 0.6, COURSE - GAP),
            (rng.uniform(-0.6, 0.6), rng.uniform(-0.9, -0.5), 0.02),
            (rng.uniform(-0.25, 0.25), rng.uniform(-0.25, 0.25), rng.uniform(-1.0, 1.0)), round_share=0.18))
    wall = S.join(stones, name)
    S.remesh(wall, 0.016)
    S.displace(wall, rng.randint(0, 999), cracks=(0.01, 3.0, 0.05), swell=(0.008, 0.2), grain=(0.003, 0.03))
    return wall


def wall_run(rng):
    return _wall(rng, [((-1.6, 0.0), (1.6, 0.0), 0.55, 1.55, 0.35)], "Wall run")


def wall_corner(rng):
    return _wall(rng, [((0.0, 0.0), (2.2, 0.0), 0.55, 1.7, 0.45),
                       ((0.0, 0.28), (0.0, 1.8), 0.55, 1.6, 0.5)], "Wall corner")


def wall_pier(rng):
    wall = _wall(rng, [((-1.8, 0.0), (0.0, 0.0), 0.5, 0.55, 1.0)], "Wall")
    pier = S.block("Pier", (0.78, 0.78, 2.35), (0.35, 0.0, 0.9), round_share=0.05)
    cap = S.block("Pier cap", (0.9, 0.9, 0.16), (0.35, 0.0, 2.1), (0.0, 0.04, 0.05), round_share=0.2)
    springer = S.block("Springer", (0.55, 0.5, 0.32), (0.75, 0.0, 1.8), (0.0, 0.35, 0.0), round_share=0.15)
    stone = S.join([pier, cap, springer], "Pier stones")
    S.remesh(stone, 0.016)
    S.displace(stone, 8122, cracks=(0.012, 2.5, 0.05), swell=(0.008, 0.2), grain=(0.003, 0.03))
    return S.join([wall, stone], "Wall and pier")


def _scatter(rng, count, spread, sizes, name, flat=0.6, round_share=0.25):
    stones = []
    for i in range(count):
        size = rng.uniform(*sizes)
        r = spread * math.sqrt(rng.random())
        a = rng.uniform(0.0, math.tau)
        stones.append(S.block("%s %d" % (name, i), (size, size * rng.uniform(0.6, 0.9), size * flat),
            (math.cos(a) * r, math.sin(a) * r * 0.7, size * flat * 0.25),
            (rng.uniform(-0.4, 0.4), rng.uniform(-0.4, 0.4), rng.uniform(-math.pi, math.pi)), round_share=round_share))
    return stones


def rubble_blocks(rng):
    stones = _scatter(rng, 7, 0.75, (0.3, 0.55), "Fallen block", flat=0.55, round_share=0.12)
    heap = S.join(stones, "Block heap")
    S.remesh(heap, 0.016)
    S.cut(heap, [((0.0, 0.0, SINK), (0.0, 0.0, -1.0))])
    S.displace(heap, 8201, cracks=(0.01, 3.0, 0.05), swell=(0.01, 0.2), grain=(0.003, 0.03))
    return heap


def rubble_scree(rng):
    stones = _scatter(rng, 14, 0.9, (0.12, 0.42), "Scree", flat=0.7, round_share=0.08)
    scree = S.join(stones, "Scree")
    S.remesh(scree, 0.014)
    S.cut(scree, [((0.0, 0.0, SINK * 0.4), (0.0, 0.0, -1.0))])
    S.displace(scree, 8211, cracks=(0.012, 4.0, 0.06), swell=(0.008, 0.15), grain=(0.003, 0.02))
    return scree


def rubble_mossy(rng):
    mound = S.block("Mound", (1.3, 0.95, 0.42), (0.0, 0.0, -0.1), round_share=0.45, segments=4)
    # Stones enough to break the moss, so it reads as a heap and not a mat.
    stones = [mound] + _scatter(rng, 11, 0.6, (0.2, 0.38), "Mossy stone", flat=0.75, round_share=0.3)
    heap = S.join(stones, "Mossy mound")
    S.remesh(heap, 0.016)
    S.cut(heap, [((0.0, 0.0, SINK * 0.4), (0.0, 0.0, -1.0))])
    S.displace(heap, 8221, cracks=(0.006, 3.0, 0.05), swell=(0.02, 0.25), grain=(0.004, 0.03))
    return heap


BUILDERS = {"grave-arched": grave_arched, "grave-cross": grave_cross, "grave-broken": grave_broken,
            "grave-tablet": grave_tablet, "wall-run": wall_run, "wall-corner": wall_corner,
            "wall-pier": wall_pier, "rubble-blocks": rubble_blocks, "rubble-scree": rubble_scree,
            "rubble-mossy": rubble_mossy}


def sculpt(kind, recipe, picture):
    """The kind's sculpt, painted for the bake: granite, moss on what faces
    the sky (the mound's more than the rest)."""
    obj = BUILDERS[kind](S.rng(recipe["seed"]))
    rise = 0.5 if kind == "rubble-mossy" else 0.62
    obj.data.materials.clear()
    obj.data.materials.append(S.paint_material(kind + " paint", picture, 1.0, cavity=0.5, edge=0.22,
        moss=(MOSS, rise)))
    return obj
