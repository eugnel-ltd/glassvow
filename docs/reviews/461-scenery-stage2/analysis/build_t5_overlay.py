#!/usr/bin/env python3
"""Overlay compiled origin centres and contact support on the locked T5 frame."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


HERE = Path(__file__).resolve().parent
PACKET = HERE.parent
PROJECTIONS = HERE / "t5-projections.json"
OUTPUT = HERE / "t5-act1-seed717-opening-overlay.png"
RESULT = HERE / "t5-overlay.json"

IN_GRADE = (86, 255, 145, 235)
OUT_OF_GRADE = (255, 180, 54, 235)
PANEL = (12, 14, 20, 215)
WHITE = (242, 244, 248, 255)


def font(size: int) -> ImageFont.ImageFont:
    candidates = (
        Path("/System/Library/Fonts/Supplemental/Arial.ttf"),
        Path("/Library/Fonts/Arial.ttf"),
        Path("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"),
    )
    for candidate in candidates:
        if candidate.is_file():
            return ImageFont.truetype(str(candidate), size=size)
    return ImageFont.load_default()


LABEL = font(15)
LEGEND = font(17)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def point(raw: list[float]) -> tuple[float, float]:
    return float(raw[0]), float(raw[1])


def main() -> None:
    evidence = json.loads(PROJECTIONS.read_text(encoding="utf-8"))
    frame = PACKET / str(evidence["frame"])
    with Image.open(frame) as source:
        image = source.convert("RGBA")
    overlay = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    in_grade = 0
    out_of_grade = 0
    for index, row in enumerate(evidence["placements"], start=1):
        centre = point(row["screen_centre"])
        if bool(row["in_grade_rect"]):
            in_grade += 1
            support = row["support_screen"]
            x0 = point(support["x_min"])[0]
            x1 = point(support["x_max"])[0]
            y0 = point(support["z_max"])[1]
            y1 = point(support["z_min"])[1]
            draw.ellipse((min(x0, x1), min(y0, y1), max(x0, x1), max(y0, y1)), outline=IN_GRADE, width=3)
            colour = IN_GRADE
        else:
            out_of_grade += 1
            colour = OUT_OF_GRADE
            radius = 9
            draw.line((centre[0] - radius, centre[1] - radius, centre[0] + radius, centre[1] + radius), fill=colour, width=3)
            draw.line((centre[0] - radius, centre[1] + radius, centre[0] + radius, centre[1] - radius), fill=colour, width=3)
        radius = 5
        draw.ellipse((centre[0] - radius, centre[1] - radius, centre[0] + radius, centre[1] + radius), fill=colour, outline=(0, 0, 0, 255), width=1)
        draw.text((centre[0] + 7, centre[1] - 9), str(index), font=LABEL, fill=colour, stroke_width=2, stroke_fill=(0, 0, 0, 230))

    draw.rounded_rectangle((18, 18, 566, 105), radius=8, fill=PANEL, outline=(90, 96, 110, 240), width=1)
    draw.text((32, 29), "T5 · Act I seed 717 · opening · Forward Mobile", font=LEGEND, fill=WHITE)
    draw.text((32, 55), f"Green: {in_grade} origins with grade-domain contact support", font=LABEL, fill=IN_GRADE)
    draw.text((32, 78), f"Amber: {out_of_grade} compiled origins outside the locked grade rect", font=LABEL, fill=OUT_OF_GRADE)

    composed = Image.alpha_composite(image, overlay).convert("RGB")
    composed.save(OUTPUT, format="PNG", optimize=True)
    result = {
        "schema": 1,
        "test": "T5",
        "frame": str(frame.relative_to(PACKET)),
        "frame_sha256": sha256(frame),
        "overlay": str(OUTPUT.relative_to(PACKET)),
        "overlay_sha256": sha256(OUTPUT),
        "compiled_origins": len(evidence["placements"]),
        "in_grade_rect_origins": in_grade,
        "out_of_grade_rect_origins": out_of_grade,
        "inspection_status": "overlay_generated",
        "method": "MapScene.project_anchors overlay; green outlines are the projected 1.75 m contact support",
        "coverage_note": "Out-of-rect origins have no containing grade texel and therefore no grade-domain contact ellipse.",
    }
    RESULT.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
