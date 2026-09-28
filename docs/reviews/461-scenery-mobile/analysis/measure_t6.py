#!/usr/bin/env python3
"""Measure the Stage 1 T6 prop-to-ground luminance ratio.

The two equal-sized rectangles are wholly inside the Act I seed 717 opening
frame's upper-left compiled monolith and adjacent unobstructed ground.  They
share the same vertical span so the comparison does not mix the map's broad
top-to-bottom grade into the object/ground ratio.
"""

from __future__ import annotations

import hashlib
import json
import statistics
from pathlib import Path

from PIL import Image


HERE = Path(__file__).resolve().parent
PACKET = HERE.parent
FRAME = PACKET / "raw" / (
    "act-01_seed-00000717_shape-pad-landscape_zoom-02-20_"
    "pose-opening_locale-en.png"
)
OUTPUT = HERE / "t6-luminance.json"

# Pillow crop boxes are [left, top, right, bottom), in source-frame pixels.
PROP_BOX = (365, 235, 415, 315)
GROUND_BOX = (285, 235, 335, 315)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def luminances(image: Image.Image, box: tuple[int, int, int, int]) -> list[float]:
    crop = image.crop(box).convert("RGB")
    pixels = crop.load()
    return [
        0.2126 * pixels[x, y][0]
        + 0.7152 * pixels[x, y][1]
        + 0.0722 * pixels[x, y][2]
        for y in range(crop.height)
        for x in range(crop.width)
    ]


def main() -> None:
    with Image.open(FRAME) as image:
        prop = statistics.median(luminances(image, PROP_BOX))
        ground = statistics.median(luminances(image, GROUND_BOX))

    result = {
        "schema": 1,
        "test": "T6",
        "frame": str(FRAME.relative_to(PACKET)),
        "frame_sha256": sha256(FRAME),
        "backend": "mobile",
        "metric": "prop median luminance / ground median luminance",
        "luminance": "display-referred 8-bit RGB; Rec. 709 coefficients 0.2126, 0.7152, 0.0722",
        "crop_coordinates": "[left, top, right, bottom), source-frame pixels",
        "prop_roi": list(PROP_BOX),
        "ground_roi": list(GROUND_BOX),
        "pixels_per_roi": (PROP_BOX[2] - PROP_BOX[0]) * (PROP_BOX[3] - PROP_BOX[1]),
        "prop_median": round(prop, 6),
        "ground_median": round(ground, 6),
        "ratio": round(prop / ground, 6),
        "graded": False,
    }
    OUTPUT.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
