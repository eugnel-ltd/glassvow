#!/usr/bin/env python3
"""Key a magenta-field portrait to alpha and grade it against the portrait gate.

Stagecraft portraits are generated on a flat #FF00FF field because a black field
cannot be separated from a black hood void (docs/art-ledger.md, the
`unwalkedSelf` lesson). This keys the field out with a soft edge, writes RGBA,
normalises with `sips -Z 1024`, and grades the written file against the
ledger's portrait gate:

    leftover field-magenta           < 32 px
    opaque near-black in the frame   < 400 px   (the 8 px canvas frame)
    corners                          alpha 0
    solid share                      >= 90% of non-transparent px at alpha >= 240

The frame reading always carries the bottom edge's share. With --cut-bottom (a
brief that cuts the figures at the canvas foot, as the Queue's does) that share
is reported but not graded.

Keying. A pixel's magenta strength is min(R, B) - G: 255 for #FF00FF, at most
about 120 on the violet glass of `enemies/eternalKeeper.png`, and about 20 on
the Lamplighter's glass. The field colour is the median of the canvas border. A pixel is field when its strength is within
FIELD_TOLERANCE of the field's own AND it is connected to the canvas border or
lies in an enclosed pocket of at least POCKET_MIN px (the gap between an arm
and the body). Every other pixel within EDGE_PX of the keyed field is an edge
pixel, matted against the field: its alpha is how far it lies along the line
from the field colour to the mean of the solid figure pixels within
FORE_RADIUS (never less than the least alpha that could reproduce it over the
field), and its colour is that local mean. A lead edge stays dark, an amber rim
stays amber and teal glass stays teal, with no pink or green fringe. Black
always keys to alpha 1, and the hood void never meets the field anyway: the
figure's lead outline walls it off.

Haze (--haze, opt-in). Grok Build fills the border-connected field to pure
#FF00FF itself, but a background area the figure encloses (between a lantern
pole and the robe, inside the lantern's hanging ring) keeps the render's own
pink haze, about (233, 61, 186), strength 60 to 160. With --haze, an enclosed
area of at least HAZE_MIN px grown through strength >= HAZE_FLOOR whose median
strength is >= HAZE_MEDIAN is cleared too, its edge band matted against the
pocket's own median colour; then every visible pixel still at strength >=
SPILL_FLOOR has that magenta excess taken out of R and B (a pink sliver
becomes lead-brown), and the count is reported so a large one stands out. Use
it only for a palette with no magenta-leaning glass (the Lamplighter's
grey-green and teal stay below strength 20; the Queue is gold, slate and
teal), never for the Keeper: the violet glass of `enemies/eternalKeeper.png`
reaches 120. Without it a pocket stays visible and fails the leftover gate.

No key (--no-key). A render that carries its own alpha (Codex draws on a
transparent background) is not keyed: it is written as RGBA, normalised with
`sips -Z 1024` and graded on the frame, the corners and the solid share, with
one more row that fails a render without an alpha channel. With no field
keyed there is no leftover to grade, so the field-magenta count is reported
as information only: on such a render it counts the figure's own colours.

    python3 tools/key_magenta.py RAW.png OUT.png [--expect 682x1024] [--haze] [--cut-bottom]
    python3 tools/key_magenta.py --no-key RAW.png OUT.png [--expect 682x1024] [--cut-bottom]
    python3 tools/key_magenta.py --plate RAW.png
    python3 tools/key_magenta.py --contact-sheet OUT.png --row TITLE IMG [IMG ...]
        [--row ...] [--tag STEM=TEXT ...] [--tile-height PX] [--guides] [--palette]

Exit status is 0 only when every graded metric passes.
"""
from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from collections import deque
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

FIELD_TOLERANCE = 48
POCKET_MIN = 48
HAZE_MIN = 4
HAZE_FLOOR = 40
HAZE_MEDIAN = 60
SPILL_FLOOR = 40
EDGE_PX = 2
FORE_RADIUS = 3
FRAME_PX = 8
NEAR_BLACK = 24
SOLID_ALPHA = 240
MAX_LEFTOVER = 32
MAX_FRAME_DARK = 400
MIN_SOLID_SHARE = 0.90
PLATE_SIZE = (1536, 1024)
GREY = (128, 128, 128)


def strength(rgb: Image.Image) -> bytes:
    """Magenta strength min(R, B) - G per pixel, clamped to 0..255."""
    r, g, b = rgb.split()
    return ImageChops.subtract(ImageChops.darker(r, b), g).tobytes()


def field_colour(rgb: Image.Image) -> tuple[int, int, int]:
    """Median colour of the one-pixel canvas border."""
    w, h = rgb.size
    px = rgb.load()
    ring = [px[x, y] for x in range(w) for y in (0, h - 1)]
    ring += [px[x, y] for y in range(1, h - 1) for x in (0, w - 1)]
    mid = len(ring) // 2
    return tuple(sorted(c[i] for c in ring)[mid] for i in range(3))


def _component(mask: bytearray, seen: bytearray, start: int, w: int, h: int
               ) -> tuple[list[int], bool]:
    """4-connected component of `mask` from `start`, and whether it meets the border."""
    seen[start] = 1
    queue = deque([start])
    cells: list[int] = []
    border = False
    while queue:
        i = queue.popleft()
        cells.append(i)
        x, y = i % w, i // w
        border = border or x in (0, w - 1) or y in (0, h - 1)
        for j, inside in ((i - 1, x > 0), (i + 1, x < w - 1), (i - w, y > 0), (i + w, y < h - 1)):
            if inside and mask[j] and not seen[j]:
                seen[j] = 1
                queue.append(j)
    return cells, border


def components(mask: bytearray, w: int, h: int):
    """Yield (cells, meets_border) for every 4-connected component of `mask`."""
    seen = bytearray(w * h)
    for start, flagged in enumerate(mask):
        if flagged and not seen[start]:
            yield _component(mask, seen, start, w, h)


def _fill(cells: list[int], size: int) -> bytearray:
    region = bytearray(size)
    for i in cells:
        region[i] = 255
    return region


def field_mask(power: bytes, w: int, h: int, floor: int) -> bytearray:
    """255 where the pixel is keyed field: border-connected, or an enclosed pocket."""
    field = bytearray(w * h)
    for cells, border in components(bytearray(v >= floor for v in power), w, h):
        if border or len(cells) >= POCKET_MIN:
            for i in cells:
                field[i] = 255
    return field


def haze_pockets(rgb: Image.Image, power: bytes) -> list[tuple[bytearray, tuple[int, ...]]]:
    """Enclosed magenta-haze pockets, each with its own median colour."""
    w, h = rgb.size
    data = rgb.tobytes()
    found = []
    for cells, border in components(bytearray(v >= HAZE_FLOOR for v in power), w, h):
        if border or len(cells) < HAZE_MIN:
            continue
        mid = len(cells) // 2
        if sorted(power[i] for i in cells)[mid] < HAZE_MEDIAN:
            continue
        colour = tuple(sorted(data[3 * i + c] for i in cells)[mid] for c in range(3))
        found.append((_fill(cells, w * h), colour))
    return found


def _foreground(px, band: bytes, x: int, y: int, w: int, h: int) -> tuple[float, ...]:
    """Mean colour of the solid figure pixels within FORE_RADIUS; black if there are none."""
    total, n = [0, 0, 0], 0
    for ny in range(max(0, y - FORE_RADIUS), min(h, y + FORE_RADIUS + 1)):
        for nx in range(max(0, x - FORE_RADIUS), min(w, x + FORE_RADIUS + 1)):
            r, g, b, a = px[nx, ny]
            if a == 255 and not band[ny * w + nx]:
                total[0] += r
                total[1] += g
                total[2] += b
                n += 1
    return tuple(v / n for v in total) if n else (0.0, 0.0, 0.0)


def _matte(pixel: tuple[int, ...], fore: tuple[float, ...], back: tuple[int, ...]
           ) -> tuple[int, int, int, int]:
    """An edge pixel as the local figure colour laid over `back`.

    Alpha is how far the pixel lies along the line from `back` to `fore`, never
    less than the least alpha that could reproduce it over `back` (so black stays
    solid). A partial pixel takes `fore` as its colour rather than being unmixed:
    Grok Build anti-aliases against its render's own background before it fills
    the field flat, so unmixing against the flat field would tint the edge.
    """
    d = [f - b for f, b in zip(fore, back)]
    along = sum((p - b) * v for p, b, v in zip(pixel[:3], back, d)) / (sum(v * v for v in d) or 1.0)
    floor = max((f - c) / f if c < f else (c - f) / (255 - f) if c > f else 0.0
                for c, f in zip(pixel[:3], back))
    alpha = max(along, floor)
    if alpha >= 0.97:
        return (*pixel[:3], 255)
    if alpha <= 0.03:
        return (0, 0, 0, 0)
    return (*(round(v) for v in fore), round(alpha * 255))


def _cut(out: Image.Image, region: bytearray, back: tuple[int, ...]) -> None:
    """Clear `region` and matte the EDGE_PX band around it against `back`."""
    w, h = out.size
    mask = Image.frombytes("L", (w, h), bytes(region))
    out.paste((0, 0, 0, 0), (0, 0, w, h), mask)
    band = ImageChops.subtract(mask.filter(ImageFilter.MaxFilter(2 * EDGE_PX + 1)), mask).tobytes()
    px = out.load()
    for i, inside in enumerate(band):
        if inside:
            x, y = i % w, i // w
            if px[x, y][3] == 255:
                px[x, y] = _matte(px[x, y], _foreground(px, band, x, y, w, h), back)


def despill(out: Image.Image) -> tuple[Image.Image, int]:
    """Take the magenta excess out of every visible pixel still at strength >= SPILL_FLOOR."""
    r, g, b, a = out.split()
    excess = ImageChops.subtract(ImageChops.darker(r, b), g).point(
        lambda v: v if v >= SPILL_FLOOR else 0)
    excess = ImageChops.multiply(excess, a.point(lambda v: 255 if v else 0))
    count = sum(excess.histogram()[1:])
    return Image.merge("RGBA", (ImageChops.subtract(r, excess), g,
                                ImageChops.subtract(b, excess), a)), count


def key(raw: Image.Image, haze: bool = False) -> tuple[Image.Image, int]:
    """The raw magenta-field render as an RGBA cutout, and the count of despilled pixels."""
    rgb = raw.convert("RGB")
    w, h = rgb.size
    field = field_colour(rgb)
    field_power = min(field[0], field[2]) - field[1]
    if field_power < 128:
        raise SystemExit(f"no magenta field: the canvas border reads {field}")
    power = strength(rgb)
    regions = [(field_mask(power, w, h, field_power - FIELD_TOLERANCE), field)]
    if haze:
        regions += haze_pockets(rgb, power)
    out = rgb.convert("RGBA")
    for region, back in regions:
        _cut(out, region, back)
    return despill(out) if haze else (out, 0)


def is_field_magenta(r: int, g: int, b: int) -> bool:
    """The ledger's field-magenta test (the Act IV `unwalkedSelf` gate)."""
    return min(r, b) >= 180 and g <= 60 and abs(r - b) <= 50


def field_magenta_px(im: Image.Image) -> int:
    """Visible pixels that pass the field-magenta test."""
    return sum(1 for r, g, b, a in im.convert("RGBA").getdata() if a and is_field_magenta(r, g, b))


def gate(im: Image.Image, cut_bottom: bool = False, keyed: bool = True
         ) -> list[tuple[str, str, bool]]:
    """The portrait alpha gate: (metric, reading, passed) per ledger rule.

    `cut_bottom` is for a brief that cuts the figures at the canvas foot (the
    Queue): the bottom edge's near-black is still reported but no longer graded.
    `keyed` False drops the leftover-magenta row: nothing was keyed, so nothing
    can be left over.
    """
    rgba = im.convert("RGBA")
    w, h = rgba.size
    px = rgba.load()
    frame = [(x, y) for y in range(h) for x in range(w)
             if min(x, y, w - 1 - x, h - 1 - y) < FRAME_PX]
    dark = [y for x, y in frame if px[x, y][3] and max(px[x, y][:3]) <= NEAR_BLACK]
    bottom = sum(1 for y in dark if y >= h - FRAME_PX)
    corners = [px[x, y][3] for x, y in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1))]
    hist = rgba.getchannel("A").histogram()
    visible = sum(hist[1:])
    share = sum(hist[SOLID_ALPHA:]) / visible if visible else 0.0
    # The bottom-edge share is always reported: a figure cut at the canvas foot puts
    # lead there by design, and a reader needs the split to see it.
    if cut_bottom:
        graded = len(dark) - bottom
        frame = f"{len(dark)} px ({graded} graded, < {MAX_FRAME_DARK}; bottom edge {bottom}, not graded)"
    else:
        graded = len(dark)
        frame = f"{len(dark)} px (< {MAX_FRAME_DARK}; bottom edge {bottom})"
    rows = [
        ("near-black in 8 px frame", frame, graded < MAX_FRAME_DARK),
        ("corners alpha", str(corners), all(c == 0 for c in corners)),
        ("alpha >= 240 share", f"{share:.1%} (>= 90%)", share >= MIN_SOLID_SHARE),
    ]
    if not keyed:
        return rows
    leftover = field_magenta_px(rgba)
    return [("leftover field-magenta", f"{leftover} px (< {MAX_LEFTOVER})", leftover < MAX_LEFTOVER),
            *rows]


def report(name: str, rows: list[tuple[str, str, bool]], info: str = "") -> bool:
    print(name)
    for metric, reading, ok in rows:
        print(f"  {'PASS' if ok else 'FAIL'}  {metric:26} {reading}")
    if info:
        print(f"  info  {info}")
    passed = all(ok for _, _, ok in rows)
    print(f"  GATE {'PASS' if passed else 'FAIL'}")
    return passed


def canvas_row(size: tuple[int, int], expect: tuple[int, int]) -> tuple[str, str, bool]:
    got, want = f"{size[0]}x{size[1]}", f"{expect[0]}x{expect[1]}"
    return ("canvas", f"{got} (expect {want})", size == expect)


def parse_size(text: str) -> tuple[int, int]:
    w, h = text.lower().split("x")
    return int(w), int(h)


def has_alpha(im: Image.Image) -> bool:
    return im.mode in ("RGBA", "LA", "PA") or "transparency" in im.info


def key_file(raw: Path, out: Path, expect: tuple[int, int] | None, haze: bool,
             cut_bottom: bool, no_key: bool = False) -> bool:
    if shutil.which("sips") is None:
        raise SystemExit("sips not found: the ledger normalises portraits with macOS `sips -Z 1024`")
    src = Image.open(raw)
    if no_key:
        alpha = [("alpha channel", f"{src.mode} (the render's own, not keyed)", has_alpha(src))]
        src.convert("RGBA").save(out)
        spilled = 0
    else:
        alpha = []
        cutout, spilled = key(src, haze)
        cutout.save(out)
    subprocess.run(["sips", "-Z", "1024", str(out)], check=True, capture_output=True)
    im = Image.open(out)
    rows = ([canvas_row(im.size, expect)] if expect else []) + alpha + gate(im, cut_bottom, not no_key)
    info = f"figure bbox {im.getchannel('A').getbbox()}"
    if no_key:
        info += f"; field-magenta {field_magenta_px(im)} px (not graded: nothing was keyed)"
    return report(f"{out.name}  {im.size[0]}x{im.size[1]} {im.mode}", rows,
                  info + (f"; despilled {spilled} px" if haze else ""))


def check_plate(path: Path) -> bool:
    im = Image.open(path)
    return report(f"{path.name}  {im.mode}", [canvas_row(im.size, PLATE_SIZE)])


def two_shot_guides(im: Image.Image) -> None:
    """Draw the plate two-shot bands: the bust columns (outer 28%) and the pane (bottom 30%)."""
    draw = ImageDraw.Draw(im)
    w, h = im.size
    for x in (round(w * 0.28), round(w * 0.72)):
        draw.line([(x, 0), (x, h)], fill=(0, 230, 255, 255), width=2)
    draw.line([(0, round(h * 0.70)), (w, round(h * 0.70))], fill=(0, 230, 255, 255), width=2)


def contact_sheet(out: Path, rows: list[list[str]], tags: dict[str, str], tile_h: int,
                  guides: bool = False, palette: bool = False) -> None:
    """Every image of a family, labelled with its stem and tag, over mid-grey.

    `palette` saves a dithered 256-colour sheet, about a third of the RGB file.
    """
    font = ImageFont.load_default(size=20)
    gutter, title_h, label_h = 16, 34, 56
    layout = []
    for title, *paths in rows:
        tiles = []
        for p in paths:
            im = Image.open(p).convert("RGBA")
            im = im.resize((round(tile_h * im.width / im.height), tile_h), Image.LANCZOS)
            if guides:
                two_shot_guides(im)
            tiles.append((Path(p).stem, im))
        layout.append((title, tiles))
    width = gutter + max(sum(im.width + gutter for _, im in tiles) for _, tiles in layout)
    height = gutter + sum(title_h + tile_h + label_h + gutter for _ in layout)
    sheet = Image.new("RGB", (width, height), GREY)
    draw = ImageDraw.Draw(sheet)
    y = gutter
    for title, tiles in layout:
        draw.text((gutter, y + 6), title, fill=(0, 0, 0), font=font)
        y += title_h
        x = gutter
        for stem, im in tiles:
            sheet.paste(im, (x, y), im)
            draw.text((x, y + tile_h + 4), stem, fill=(0, 0, 0), font=font)
            tag = tags.get(stem)
            if tag:
                box = draw.textbbox((x, y + tile_h + 28), tag, font=font)
                fill = (140, 20, 20) if tag.upper().startswith("REJECT") else (24, 24, 24)
                draw.rectangle((box[0] - 3, box[1] - 2, box[2] + 3, box[3] + 2), fill=fill)
                draw.text((x, y + tile_h + 28), tag, fill=(255, 255, 255), font=font)
            x += im.width + gutter
        y += tile_h + label_h + gutter
    if palette:
        sheet = sheet.quantize(colors=256, dither=Image.Dither.FLOYDSTEINBERG)
    sheet.save(out, optimize=True)
    print(f"{out}  {sheet.width}x{sheet.height}")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("paths", nargs="*", type=Path, help="RAW.png OUT.png, or the plate")
    ap.add_argument("--expect", type=parse_size, help="expected canvas, e.g. 682x1024")
    ap.add_argument("--haze", action="store_true",
                    help="no magenta-leaning glass in this palette: clear enclosed haze "
                         "pockets and despill (never for the Keeper)")
    ap.add_argument("--cut-bottom", action="store_true",
                    help="the brief cuts the figures at the canvas foot: report the bottom "
                         "edge's near-black but do not grade it (the Queue)")
    ap.add_argument("--no-key", action="store_true",
                    help="the render carries its own alpha (a transparent background): "
                         "grade it without keying")
    ap.add_argument("--plate", action="store_true", help="check a 1536x1024 plate; no keying")
    ap.add_argument("--contact-sheet", type=Path, metavar="OUT.png")
    ap.add_argument("--row", action="append", nargs="+", default=[], metavar="TITLE IMG")
    ap.add_argument("--tag", action="append", default=[], metavar="STEM=TEXT")
    ap.add_argument("--tile-height", type=int, default=400)
    ap.add_argument("--guides", action="store_true",
                    help="contact sheet: draw the plate two-shot bands on every tile")
    ap.add_argument("--palette", action="store_true",
                    help="contact sheet: save as a dithered 256-colour PNG (about a third of the size)")
    args = ap.parse_args()
    if args.contact_sheet:
        tags = dict(t.split("=", 1) for t in args.tag)
        contact_sheet(args.contact_sheet, args.row, tags, args.tile_height, args.guides,
                      args.palette)
        return 0
    if args.plate and len(args.paths) == 1:
        return 0 if check_plate(args.paths[0]) else 1
    if args.no_key and args.haze:
        ap.error("--haze clears keyed field; a --no-key render has none")
    if len(args.paths) == 2:
        return 0 if key_file(args.paths[0], args.paths[1], args.expect, args.haze,
                             args.cut_bottom, args.no_key) else 1
    ap.error("give RAW.png OUT.png, --plate RAW.png, or --contact-sheet")
    return 2


if __name__ == "__main__":
    sys.exit(main())
