#!/usr/bin/env python3
"""Build compact review sheets and raw-frame integrity indexes for Stage 1."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps


HERE = Path(__file__).resolve().parent
PACKET = HERE.parent
MANIFEST = json.loads((PACKET / "manifest.json").read_text(encoding="utf-8"))
FRAMES = {row["frame_id"]: row for row in MANIFEST["frames"]}

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


def title_for(frame: dict[str, object]) -> str:
    pose = str(frame["pose"]).replace("-", " ")
    return f"Act {int(frame['act'])} · seed {int(frame['seed'])} · {pose}"


def paste_cell(
    canvas: Image.Image,
    frame_id: str,
    origin: tuple[int, int],
    size: tuple[int, int],
    image_box: tuple[int, int],
) -> None:
    frame = FRAMES[frame_id]
    x, y = origin
    width, height = size
    draw = ImageDraw.Draw(canvas)
    draw.rectangle((x, y, x + width - 1, y + height - 1), outline=BORDER, width=1)
    draw.text((x + 11, y + 7), title_for(frame), font=TITLE, fill=PRIMARY)
    draw.text(
        (x + 11, y + 34),
        f"{frame_id} | {frame['shape']} | {frame['pose']} | scenery {frame['scenery_count']}",
        font=META,
        fill=SECONDARY,
    )

    source_path = PACKET / str(frame["file"])
    with Image.open(source_path) as source:
        image = ImageOps.contain(source.convert("RGB"), image_box, Image.Resampling.LANCZOS)
    image_area_top = y + 61
    image_area_height = height - 66
    paste_x = x + (width - image.width) // 2
    paste_y = image_area_top + (image_area_height - image.height) // 2
    canvas.paste(image, (paste_x, paste_y))
    draw.rectangle(
        (paste_x - 1, paste_y - 1, paste_x + image.width, paste_y + image.height),
        outline=BORDER,
        width=1,
    )


def two_column_sheet(path: Path, rows: list[tuple[str, str | None]]) -> None:
    width, row_height = 1228, 459
    canvas = Image.new("RGB", (width, row_height * len(rows)), BACKGROUND)
    for row, (left, right) in enumerate(rows):
        y = row * row_height
        if right is None:
            paste_cell(canvas, left, (0, y), (width, row_height), (590, 392))
        else:
            paste_cell(canvas, left, (0, y), (614, row_height), (566, 392))
            paste_cell(canvas, right, (614, y), (614, row_height), (596, 392))
    canvas.save(path, format="JPEG", quality=92, subsampling=0, optimize=True)


def three_column_sheet(path: Path, frames: tuple[str, str, str]) -> None:
    canvas = Image.new("RGB", (1572, 397), BACKGROUND)
    for column, frame_id in enumerate(frames):
        paste_cell(canvas, frame_id, (column * 524, 0), (524, 397), (500, 330))
    canvas.save(path, format="JPEG", quality=92, subsampling=0, optimize=True)


def write_indexes() -> None:
    dimensions = []
    hashes = []
    for frame in MANIFEST["frames"]:
        path = PACKET / str(frame["file"])
        with Image.open(path) as image:
            width, height = image.size
        dimensions.append(
            {
                "frame_id": frame["frame_id"],
                "file": frame["file"],
                "width": width,
                "height": height,
            }
        )
        hashes.append(
            {
                "frame_id": frame["frame_id"],
                "file": frame["file"],
                "png_sha256": sha256(path),
            }
        )
    common = {
        "schema": 1,
        "issue": 461,
        "capture_head": MANIFEST["capture_head"],
        "frame_count": len(MANIFEST["frames"]),
    }
    (PACKET / "dimensions.json").write_text(
        json.dumps({**common, "frames": dimensions}, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    (PACKET / "pixel-hashes.json").write_text(
        json.dumps({**common, "diagnostic_only": True, "frames": hashes}, indent=2, sort_keys=True)
        + "\n",
        encoding="utf-8",
    )


def main() -> None:
    two_column_sheet(
        PACKET / "act-01-seed-17634-after.jpg",
        [("F001", "F002"), ("F003", "F004")],
    )
    two_column_sheet(
        PACKET / "act-01-seed-717-after.jpg",
        [("F005", "F006"), ("F007", "F008"), ("F009", None)],
    )
    three_column_sheet(
        PACKET / "acts-02-04-seed-717-after.jpg",
        ("F010", "F011", "F012"),
    )
    write_indexes()
    for path in sorted(PACKET.glob("*.jpg")):
        print(f"{path.name} {sha256(path)}")


if __name__ == "__main__":
    main()
