#!/usr/bin/env python3
"""Seat a full-bleed 1024 icon candidate on the macOS icon grid.

Apple's masters keep an 824px rounded-square live area centred in a 1024
canvas, transparent outside it (measured from Preview.app's own icns, DL
review of PR #53). A full-bleed square reads as a black tile in the Dock —
24% wider than every neighbour, with corners nothing else has.

    tools/make_icon_master.py <candidate.png> <out.png>

The candidate fills the live area at its own scale, uncropped, so the
composition is the one that was picked. Corners follow Apple's ~22.37% radius,
drawn at 4x and box-reduced so the edge is anti-aliased. Run
tools/make_icon.sh afterwards to rebuild the icns ladder.
"""
import sys

from PIL import Image, ImageDraw

NIGHT = (4, 5, 11, 255)
CANVAS = 1024
LIVE = 824
RADIUS = round(LIVE * 0.2237)
SUPERSAMPLE = 4


def main() -> int:
    src_path, out_path = sys.argv[1], sys.argv[2]
    art = Image.open(src_path).convert("RGBA")
    if art.size != (CANVAS, CANVAS):
        art = art.resize((CANVAS, CANVAS), Image.LANCZOS)

    plate = Image.new("RGBA", (CANVAS, CANVAS), NIGHT)
    inset = (CANVAS - LIVE) // 2
    plate.paste(art.resize((LIVE, LIVE), Image.LANCZOS), (inset, inset))

    ss = SUPERSAMPLE
    mask = Image.new("L", (CANVAS * ss,) * 2, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (inset * ss, inset * ss, (inset + LIVE) * ss - 1, (inset + LIVE) * ss - 1),
        radius=RADIUS * ss, fill=255)
    plate.putalpha(mask.reduce(ss))
    plate.save(out_path)
    print(f"wrote {out_path} (live {LIVE}px, radius {RADIUS}px)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
