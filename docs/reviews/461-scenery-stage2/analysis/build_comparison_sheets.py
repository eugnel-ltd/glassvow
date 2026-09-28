#!/usr/bin/env python3
"""Build matched Stage 1/Stage 2 Forward Mobile comparison sheets."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps


HERE = Path(__file__).resolve().parent
PACKET = HERE.parent
ROOT = PACKET.parents[2]
BASELINE = ROOT / "docs/reviews/461-scenery-mobile"

BACKGROUND = (15, 17, 24)
PRIMARY = (238, 239, 243)
SECONDARY = (166, 173, 187)
BORDER = (73, 78, 91)


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


TITLE = font(21)
META = font(16)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def paste_frame(
    canvas: Image.Image,
    frame: dict[str, object],
    packet: Path,
    label: str,
    x: int,
    y: int,
    width: int,
    row_height: int,
) -> None:
    draw = ImageDraw.Draw(canvas)
    draw.rectangle((x, y, x + width - 1, y + row_height - 1), outline=BORDER, width=1)
    draw.text((x + 11, y + 7), label, font=TITLE, fill=PRIMARY)
    draw.text(
        (x + 11, y + 34),
        f"{frame['frame_id']} | Act {frame['act']} | seed {frame['seed']} | "
        f"{frame['shape']} | {frame['pose']}",
        font=META,
        fill=SECONDARY,
    )
    with Image.open(packet / str(frame["file"])) as source:
        image = ImageOps.contain(source.convert("RGB"), (566, 392), Image.Resampling.LANCZOS)
    area_top = y + 61
    area_height = row_height - 66
    paste_x = x + (width - image.width) // 2
    paste_y = area_top + (area_height - image.height) // 2
    canvas.paste(image, (paste_x, paste_y))
    draw.rectangle(
        (paste_x - 1, paste_y - 1, paste_x + image.width, paste_y + image.height),
        outline=BORDER,
        width=1,
    )


def build(path: Path, frame_ids: list[str]) -> None:
    current_manifest = json.loads((PACKET / "manifest.json").read_text(encoding="utf-8"))
    baseline_manifest = json.loads((BASELINE / "manifest.json").read_text(encoding="utf-8"))
    current = {str(row["frame_id"]): row for row in current_manifest["frames"]}
    baseline = {str(row["frame_id"]): row for row in baseline_manifest["frames"]}
    width, row_height = 1228, 459
    canvas = Image.new("RGB", (width, row_height * len(frame_ids)), BACKGROUND)
    for row, frame_id in enumerate(frame_ids):
        y = row * row_height
        paste_frame(canvas, baseline[frame_id], BASELINE, "Stage 1 Forward Mobile", 0, y, 614, row_height)
        paste_frame(canvas, current[frame_id], PACKET, "Stage 2 contact bind", 614, y, 614, row_height)
    canvas.save(path, format="JPEG", quality=92, subsampling=0, optimize=True)


def main() -> None:
    outputs = {
        "act-01-seed-17634-stage1-vs-stage2.jpg": ["F001", "F002", "F003", "F004"],
        "act-01-seed-717-stage1-vs-stage2.jpg": ["F005", "F006", "F007", "F008", "F009"],
        "acts-02-04-seed-717-stage1-vs-stage2.jpg": ["F010", "F011", "F012"],
    }
    for filename, frame_ids in outputs.items():
        path = PACKET / filename
        build(path, frame_ids)
        print(f"{filename} {sha256(path)}")


if __name__ == "__main__":
    main()
