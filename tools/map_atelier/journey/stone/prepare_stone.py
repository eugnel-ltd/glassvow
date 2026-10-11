"""Act I's stone pictures (R3.3, issue #660) from the generated sources.

From the pictures in `sources/` (generated with the image tool; prompts in
`sources/prompts.txt`), each with its slow light divided out, its edges
blended with the picture rolled half a tile so it wraps, and a light grade:

- `build/stone/granite-tile.png` and `build/stone/strata-tile.png` (1024 px):
  what the Blender kit paints its stone with before it bakes each kind's
  colour (`build_stone.py`); never shipped;
- `assets/art/map-journey/stone/strata.png` (512 px): the strata the floor's
  bake lays on the ravine's steep banks (`floor_paint.gdshader`).

Deterministic (numpy and Pillow): re-running it reproduces every file.

    python3 tools/map_atelier/journey/stone/prepare_stone.py
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from cover_tools import flatten, grade, wrap_edges  # noqa: E402

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
RAW = HERE / "sources"
BUILD = ROOT / "build" / "stone"
OUT = ROOT / "assets" / "art" / "map-journey" / "stone"
# How the strata picture spans the floor's banks: 1.6 m a tile (`floor_paint`).
SHIPPED = 512


def load(name):
    return np.asarray(Image.open(RAW / f"{name}.jpg").convert("RGB"), dtype=np.float64) / 255.0


def to_image(img):
    return Image.fromarray((np.clip(img, 0, 1) * 255.0 + 0.5).astype(np.uint8), "RGB")


def tile(name, **kw):
    img = load(name)
    img = flatten(img, 96)
    img = wrap_edges(img)
    return grade(img, **kw)


def main():
    BUILD.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    # Granite: a cool mid grey under the warm key, its lichen kept but muted.
    granite = tile("granite", saturation=0.7, warmth=(1.0, 0.99, 0.97), gain=0.92)
    to_image(granite).save(BUILD / "granite-tile.png", optimize=True)
    # Strata: the warm grey-browns kept, a little darker than the ground.
    strata = tile("strata", saturation=0.82, warmth=(1.02, 0.98, 0.94), gain=0.88)
    to_image(strata).save(BUILD / "strata-tile.png", optimize=True)
    to_image(strata).resize((SHIPPED, SHIPPED), Image.LANCZOS).save(OUT / "strata.png", optimize=True)
    print("ok", {p.name: p.stat().st_size for p in [BUILD / "granite-tile.png", BUILD / "strata-tile.png",
                                                    OUT / "strata.png"]})


if __name__ == "__main__":
    main()
