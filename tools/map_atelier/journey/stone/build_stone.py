"""Builds Act I's stone (R3.3, issue #660) in Blender: the five granite
outcrops and the six cliff pieces (`outcrops.py`, `cliffs.py`), drawn as
meshes, and the ten ruins (`ruins.py`), drawn as impostors.

Hero kinds (outcrops, cliffs): each sculpted, retopologised to its budget,
unwrapped into its own cell of one atlas and baked into it (`sculpt.py`):

- `assets/art/map-journey/stone/stone-albedo.png` (2048 x 1536, 4 x 3 cells
  of 512): the colour, carrying its occlusion;
- `assets/art/map-journey/stone/stone-normal.png` (1024 x 768): the
  tangent-space normals at half size;
- `tools/map_atelier/journey/stone/glb/<kind>.glb`: the reduced meshes, which
  `pack_stone.gd` packs for the game (`stone-pieces.res`);
- `tools/map_atelier/journey/sources/<kind>.blend`: the masters.

Ruins: each sculpted at a few thousand triangles with its colour baked onto
its own UVs, into `tools/map_atelier/journey/impostors/stone/` (`<kind>.glb`,
`<kind>-albedo.png`), the impostor bake's sources.

`manifest.json` beside the atlas lists every kind: its triangles, footprint
circle, top and lowest point (Godot metres, Y up), atlas cell and description.

Run `prepare_stone.py` first, then Blender in the background at 4 threads:

    blender -b -t 4 --factory-startup --python tools/map_atelier/journey/stone/build_stone.py [-- --only=kind,kind]
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import cliffs  # noqa: E402
import outcrops  # noqa: E402
import ruins  # noqa: E402
import sculpt as S  # noqa: E402

HERO = list(outcrops.RECIPES) + list(cliffs.RECIPES)
ATLAS = (2048, 1536)
COLUMNS = 4
ROWS = 3
# Each cell keeps this many texels clear at its edges (the mips' bleed).
MARGIN = 8
# How far the bake's rays reach either side of a reduced surface (metres).
REACH = {"outcrop": 0.09, "cliff": 0.14, "ruin": 0.05}


def cell(index):
    column = index % COLUMNS
    row = index // COLUMNS
    mu = MARGIN / ATLAS[0]
    mv = MARGIN / ATLAS[1]
    return (column / COLUMNS + mu, 1.0 - (row + 1) / ROWS + mv, 1.0 / COLUMNS - 2 * mu, 1.0 / ROWS - 2 * mv)


def _row(kind, low, recipe, family, extra):
    radius, top, bottom = S.footprint(low)
    row = {"id": kind, "family": family, "triangles": S.triangles(low), "radius": radius, "top": top,
           "bottom": bottom, "description": recipe["description"]}
    row.update(extra)
    return row


def heroes():
    images = S.atlas("stone", ATLAS)
    rows = []
    for index, kind in enumerate(HERO):
        granite = kind in outcrops.RECIPES
        module = outcrops if granite else cliffs
        recipe = module.RECIPES[kind]
        S.reset()
        picture = S.BUILD / ("granite-tile.png" if granite else "strata-tile.png")
        high = module.sculpt(kind, recipe, picture)
        low = S.retopologise(high, recipe["budget"], kind)
        S.unwrap(low, cell(index))
        S.bake_into(images, high, low, REACH["outcrop" if granite else "cliff"], index == 0)
        S.plain(low, ("Granite / " if granite else "Strata / ") + kind)
        S.export_glb(low, S.GLB / (kind + ".glb"))
        rows.append(_row(kind, low, recipe, "outcrop" if granite else "cliff",
            {"cell": [round(v, 6) for v in cell(index)]}))
        S.save_master(low, kind, recipe)
        print("STONE_KIND", kind, rows[-1]["triangles"], flush=True)
    S.finish_atlas(images, S.OUT / "stone-albedo.png", S.OUT / "stone-normal.png")
    return rows


def ruin_kinds(only):
    rows = []
    for kind, recipe in ruins.RECIPES.items():
        if only and kind not in only:
            continue
        S.reset()
        high = ruins.sculpt(kind, recipe, S.BUILD / "granite-tile.png")
        low = S.retopologise(high, recipe["budget"], kind)
        S.unwrap(low)
        S.bake_single(high, low, kind, recipe["texels"], REACH["ruin"],
            S.IMPOSTOR_SOURCES / (kind + "-albedo.png"))
        S.plain(low, "Stone ruin / " + kind)
        S.export_glb(low, S.IMPOSTOR_SOURCES / (kind + ".glb"))
        rows.append(_row(kind, low, recipe, "ruin", {}))
        S.save_master(low, kind, recipe)
        print("STONE_KIND", kind, rows[-1]["triangles"], flush=True)
    return rows


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = set()
    for arg in args:
        if arg.startswith("--only="):
            only = set(arg[len("--only="):].split(","))
    S.setup()
    rows = []
    # The hero kinds share one atlas, so they are always built together.
    if not only or only & set(HERO):
        rows += heroes()
    rows += ruin_kinds(only)
    manifest = S.OUT / "manifest.json"
    known = {}
    if manifest.exists() and only:
        known = {row["id"]: row for row in json.loads(manifest.read_text())["kinds"]}
    for row in rows:
        known[row["id"]] = row
    # Blender Z up to Godot Y up: the heights carry over, the circle too.
    manifest.write_text(json.dumps({"generator": "tools/map_atelier/journey/stone/build_stone.py",
        "atlas": list(ATLAS), "kinds": [known[k] for k in sorted(known)]}, indent=2) + "\n")
    print("STONE_KIT_OK", len(rows), flush=True)


main()
