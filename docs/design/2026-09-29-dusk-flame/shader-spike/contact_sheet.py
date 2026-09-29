#!/usr/bin/env python3
"""Contact sheets, strips and the stability loop for the #577 flame spike.

The flame lab records its own crops (``--record``), so nothing here guesses
where the lantern is. Record into a scratch folder outside the repository, then
build the sheets next to this file:

    python3 docs/design/2026-09-29-dusk-flame/shader-spike/contact_sheet.py \
        --capture --recordings /tmp/flame-spike

``--capture`` runs ``tools/shot.sh --flame --record=...`` once per recording
(each is one boot; the clock is pinned, so a rerun is the same picture on the
same GPU). Without it, the sheets are rebuilt from recordings already on disk.
"""
from __future__ import annotations

import argparse
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
FONT_TC = ROOT / "assets/fonts/NotoSerifTC-Regular.woff2"
FONT_TITLE = ROOT / "assets/fonts/Cinzel-700.woff2"

# id, tier label, way label: the lab's POSES, in its order.
POSES = [
    ("kindling", "Kindling 燃", "the starter deck"),
    ("steady-shatter", "Steady 定", "Shatter 霜焰"),
    ("steady-lantern", "Steady 定", "Lantern 熾焰"),
    ("steady-edge", "Steady 定", "Edge 蝕焰"),
    ("true-shatter", "True 真", "Shatter 霜焰"),
    ("true-lantern", "True 真", "Lantern 熾焰"),
    ("true-edge", "True 真", "Edge 蝕焰"),
    ("shatter-edge-fringe", "Steady 定", "Shatter + Edge fringe"),
    ("lantern-shatter-fringe", "Steady 定", "Lantern + Shatter fringe"),
    ("soot", "Soot 塵", "scattered"),
]
LOOKS = ["leaded", "vector"]

# name, --shape, --vp (the stage at its device density), density note.
SHAPES = [
    ("pad", "pad-landscape", "2360x1640", "1180×820 stage at 2× (iPad)"),
    ("desktop", "desktop-landscape", "2916x1640", "1458×820 stage at 2× (Retina Mac)"),
    ("mobile", "phone-landscape", "2532x1170", "844×390 stage at 3× (iPhone)"),
]
STILL_AT = "1.2"
MOTION_TIERS = ["soot", "kindling", "steady-lantern", "true-lantern"]
MOTION_FRAMES, MOTION_STEP = 60, 1.0 / 30.0
TWEEN_FROM, TWEEN_TO, TWEEN_FRAMES, TWEEN_STEP = "kindling", "steady-shatter", 11, 0.1

CELL, LABEL_H, TITLE_H, PAD = 190, 34, 44, 12
BG, FG, DIM = (10, 12, 22), (226, 222, 210), (150, 158, 184)


def font(path: Path, size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    try:
        return ImageFont.truetype(str(path), size)
    except OSError:
        return ImageFont.load_default()


def record(out: Path, *args: str) -> None:
    out.mkdir(parents=True, exist_ok=True)
    cmd = [str(ROOT / "tools/shot.sh"), "--flame", f"--record={out}", *args]
    print("+", " ".join(cmd))
    subprocess.run(cmd, check=True, cwd=ROOT, stdout=subprocess.DEVNULL)


def capture(rec: Path) -> None:
    for name, shape, vp, _ in SHAPES:
        base = [f"--shape={shape}", f"--vp={vp}"]
        record(rec / name, *base, "--poses=all", "--look=all", f"--time={STILL_AT}")
        if name == "mobile":
            record(rec / "mobile-today", *base, "--poses=kindling", f"--time={STILL_AT}",
                   "--flame=off")
            record(rec / "mobile-nonum", *base, "--poses=all", "--look=all",
                   f"--time={STILL_AT}", "--numeral=off")
            record(rec / "mobile-motion", *base, f"--poses={','.join(MOTION_TIERS)}",
                   "--look=all", "--time=0", f"--frames={MOTION_FRAMES}",
                   f"--step={MOTION_STEP:.4f}")
            record(rec / "mobile-tween", *base, f"--from={TWEEN_FROM}",
                   f"--poses={TWEEN_TO}", "--look=all", "--time=0",
                   f"--frames={TWEEN_FRAMES}", f"--step={TWEEN_STEP}")


def glass(im: Image.Image) -> Image.Image:
    """The large lantern's lights, with a little hood and foot."""
    w, h = im.size
    return im.crop((int(w * 0.27), int(h * 0.37), int(w * 0.73), int(h * 0.86)))


def tile(path: Path, kind: str, side: int) -> Image.Image:
    im = Image.open(path).convert("RGB")
    if kind == "big":
        im = glass(im)
    im.thumbnail((side, side), Image.LANCZOS)
    cell = Image.new("RGB", (side, side), BG)
    cell.paste(im, ((side - im.width) // 2, (side - im.height) // 2))
    return cell


def sheet(rec: Path, kind: str, title: str, note: str) -> Image.Image:
    """Ten poses by two looks: five across, two rows per look."""
    cols = 5
    width = PAD * 2 + cols * CELL
    rows_h = len(LOOKS) * (TITLE_H - 14 + 2 * (CELL + LABEL_H))
    out = Image.new("RGB", (width, TITLE_H + rows_h + PAD), BG)
    draw = ImageDraw.Draw(out)
    draw.text((PAD, 10), title, font=font(FONT_TITLE, 20), fill=FG)
    draw.text((width - PAD, 16), note, font=font(FONT_TC, 14), fill=DIM, anchor="ra")
    small = font(FONT_TC, 13)
    y = TITLE_H
    for look in LOOKS:
        draw.text((PAD, y), look.upper(), font=font(FONT_TITLE, 14), fill=DIM)
        y += TITLE_H - 14
        for i, (pose, tier, way) in enumerate(POSES):
            x = PAD + (i % cols) * CELL
            yy = y + (i // cols) * (CELL + LABEL_H)
            out.paste(tile(rec / f"{pose}_{look}_000_{kind}.png", kind, CELL), (x, yy))
            draw.text((x + 4, yy + CELL + 2), tier, font=small, fill=FG)
            draw.text((x + 4, yy + CELL + 17), way, font=small, fill=DIM)
        y += 2 * (CELL + LABEL_H)
    return out


def strip(rows: list[tuple[str, Path, str]], picks: list[int], title: str,
          side: int = 140) -> Image.Image:
    """One row per (label, folder, stem), one column per picked frame. A label
    ending in HUD takes the HUD crop, any other the large lantern."""
    label_w = 150
    out = Image.new("RGB", (PAD + label_w + side * len(picks) + PAD,
                            TITLE_H + len(rows) * side + PAD), BG)
    draw = ImageDraw.Draw(out)
    draw.text((PAD, 10), title, font=font(FONT_TITLE, 18), fill=FG)
    small = font(FONT_TC, 13)
    for r, (label, folder, stem) in enumerate(rows):
        y = TITLE_H + r * side
        draw.text((PAD, y + side // 2 - 8), label, font=small, fill=DIM)
        for c, k in enumerate(picks):
            kind = "hud" if label.endswith("HUD") else "big"
            out.paste(tile(folder / f"{stem}_{k:03d}_{kind}.png", kind, side),
                      (PAD + label_w + c * side, y))
    return out


def today(rec: Path) -> Image.Image:
    """Today's lantern beside Kindling in both looks: the flame's resting state
    should still be the lantern the game has."""
    cols = [("today (--flame=off)", rec / "mobile-today", "kindling_leaded"),
            ("Kindling, leaded", rec / "mobile", "kindling_leaded"),
            ("Kindling, vector", rec / "mobile", "kindling_vector")]
    side = 300
    out = Image.new("RGB", (PAD * 2 + side * len(cols), TITLE_H + 2 * side + LABEL_H + PAD), BG)
    draw = ImageDraw.Draw(out)
    draw.text((PAD, 10), "Today's lantern and Kindling · mobile, 844×390 at 3×",
              font=font(FONT_TITLE, 18), fill=FG)
    for c, (label, folder, stem) in enumerate(cols):
        x = PAD + c * side
        out.paste(tile(folder / f"{stem}_000_hud.png", "hud", side), (x, TITLE_H))
        out.paste(tile(folder / f"{stem}_000_big.png", "big", side), (x, TITLE_H + side))
        draw.text((x + 4, TITLE_H + 2 * side + 6), label, font=font(FONT_TC, 14), fill=DIM)
    return out


def stability_loop(rec: Path, dest: Path) -> None:
    """Four tiers side by side for two seconds: the large lights over the HUD."""
    side = 240
    frames: list[Image.Image] = []
    palette: Image.Image | None = None
    for k in range(MOTION_FRAMES):
        frame = Image.new("RGB", (side * len(MOTION_TIERS), side * 2), BG)
        for c, pose in enumerate(MOTION_TIERS):
            frame.paste(tile(rec / f"{pose}_leaded_{k:03d}_big.png", "big", side), (c * side, 0))
            frame.paste(tile(rec / f"{pose}_leaded_{k:03d}_hud.png", "hud", side), (c * side, side))
        # One palette for every frame, or the loop shimmers where nothing moved.
        palette = palette or frame.quantize(colors=192, method=Image.Quantize.MEDIANCUT)
        frames.append(frame.quantize(palette=palette, dither=Image.Dither.NONE))
    frames[0].save(dest, save_all=True, append_images=frames[1:], loop=0,
                   duration=int(MOTION_STEP * 1000), optimize=True)


def build(rec: Path) -> None:
    for name, _, _, note in SHAPES:
        s = sheet(rec / name, "hud", f"The lantern flame · HUD · {name}", note)
        s.save(HERE / f"sheet-{name}.png", optimize=True)
        if name == "mobile":
            ImageOps.grayscale(s).save(HERE / "grey-mobile.png", optimize=True)
    design = sheet(rec / "pad", "big", "The lantern flame · the figure, large",
                   "the lab's inspection lantern, same material")
    design.save(HERE / "sheet-design.png", optimize=True)
    ImageOps.grayscale(design).save(HERE / "grey-design.png", optimize=True)
    sheet(rec / "mobile-nonum", "hud", "The lantern flame · HUD · mobile · numeral hidden",
          "844×390 at 3×, --numeral=off").save(HERE / "numeral-off-mobile.png", optimize=True)
    today(rec).save(HERE / "today-kindling.png", optimize=True)
    motion, tween = rec / "mobile-motion", rec / "mobile-tween"
    strip([("Soot, leaded", motion, "soot_leaded"), ("Soot, leaded HUD", motion, "soot_leaded"),
           ("Soot, vector", motion, "soot_vector"), ("Soot, vector HUD", motion, "soot_vector")],
          [0, 10, 20, 30, 40, 50], "Soot gutters · every 1/3 s").save(
        HERE / "strip-soot.png", optimize=True)
    strip([("leaded", tween, "steady-shatter_leaded"), ("leaded HUD", tween, "steady-shatter_leaded"),
           ("vector", tween, "steady-shatter_vector"), ("vector HUD", tween, "steady-shatter_vector")],
          [0, 2, 4, 6, 8, 10], "Kindling to Steady Shatter · every 0.2 s").save(
        HERE / "strip-tween.png", optimize=True)
    stability_loop(motion, HERE / "stability.gif")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--recordings", type=Path, required=True)
    ap.add_argument("--capture", action="store_true")
    args = ap.parse_args()
    if args.capture:
        capture(args.recordings)
    build(args.recordings)


if __name__ == "__main__":
    main()
