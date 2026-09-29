#!/usr/bin/env python3
"""Greyscale legibility numbers for the #577 flame spike.

Reads the recordings `contact_sheet.py --capture` makes and prints, per pose
and look, what a colour-blind player is left with: how bright the lights are,
and how tall and how wide the lit figure stands in them; then how much each
tier moves from frame to frame. Everything is luminance only (Rec. 601),
inside the box the panes stand in. On the HUD the ember numeral is masked
out: it is the brightest thing in the lantern and says nothing about the
flame.

    python3 docs/design/2026-09-29-dusk-flame/shader-spike/measure.py \
        --recordings /tmp/flame-spike
"""
from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageStat

from contact_sheet import LOOKS, MOTION_FRAMES, MOTION_TIERS, POSES

# The panes' box in the art's UV (the shader's PANES).
PANES = (0.31, 0.43, 0.69, 0.795)
# Where the ember numeral sits over the art, in the art's UV.
NUMERAL = (0.40, 0.35, 0.60, 0.62)
# A pixel of flame rather than of lit glass. The HUD's is lower because the
# HUD dims an unlit lantern to about 0.82.
LIT = {"big": 150, "hud": 125}
# The HUD crop is the art grown by the lab's HUD_CROP, centred.
HUD_CROP = 1.2


def art_of(im: Image.Image, kind: str) -> Image.Image:
    if kind == "big":
        return im
    w, h = im.size
    inset = (1.0 - 1.0 / HUD_CROP) / 2.0
    art = im.crop((int(w * inset), int(h * inset), int(w * (1 - inset)), int(h * (1 - inset))))
    aw, ah = art.size
    ImageDraw.Draw(art).rectangle((aw * NUMERAL[0], ah * NUMERAL[1], aw * NUMERAL[2], ah * NUMERAL[3]),
                                  fill=0)
    return art


def panes(im: Image.Image) -> Image.Image:
    w, h = im.size
    return im.crop((int(w * PANES[0]), int(h * PANES[1]), int(w * PANES[2]), int(h * PANES[3])))


def figure(box: Image.Image, lit: int) -> tuple[float, float, float, float]:
    """Mean luminance; the lit figure's height from the foot of the box and its
    widest extent, both as shares of the box; and how solidly it fills the
    rectangle those two make (a dome is solid, a crown of shards is not)."""
    w, h = box.size
    px = box.load()
    top, widest, count = h, 0, 0
    for y in range(h):
        xs = [x for x in range(w) if px[x, y] >= lit]
        if xs:
            top = min(top, y)
            widest = max(widest, xs[-1] - xs[0] + 1)
            count += len(xs)
    fill = count / ((h - top) * widest) if count else 0.0
    return ImageStat.Stat(box).mean[0], (h - top) / h, widest / w, fill


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--recordings", type=Path, required=True)
    rec = ap.parse_args().recordings
    for source, kind in (("pad", "big"), ("mobile", "hud")):
        label = "large lantern" if kind == "big" else "HUD, 844×390 at 3×, numeral masked"
        print(f"\n{label}: mean L / lit height / lit width / fill")
        print(f"{'pose':24s} " + "  ".join(f"{look:>27s}" for look in LOOKS))
        for pose, _, _ in POSES:
            cells = []
            for look in LOOKS:
                im = Image.open(rec / source / f"{pose}_{look}_000_{kind}.png").convert("L")
                mean, height, width, fill = figure(panes(art_of(im, kind)), LIT[kind])
                cells.append(f"{mean:5.1f} / {height:4.2f} / {width:4.2f} / {fill:4.2f}")
            print(f"{pose:24s} " + "  ".join(f"{c:>27s}" for c in cells))
    print("\nmotion: median and p95 of the mean absolute frame-to-frame change (L)")
    for look in LOOKS:
        for pose in MOTION_TIERS:
            for kind in ("big", "hud"):
                diffs = []
                prev = None
                for k in range(MOTION_FRAMES):
                    path = rec / "mobile-motion" / f"{pose}_{look}_{k:03d}_{kind}.png"
                    box = panes(art_of(Image.open(path).convert("L"), kind))
                    if prev is not None:
                        diffs.append(ImageStat.Stat(ImageChops.difference(box, prev)).mean[0])
                    prev = box
                diffs.sort()
                print(f"{look:7s} {pose:16s} {kind:3s}  median {diffs[len(diffs) // 2]:5.2f}"
                      f"  p95 {diffs[int(len(diffs) * 0.95)]:5.2f}")


if __name__ == "__main__":
    main()
