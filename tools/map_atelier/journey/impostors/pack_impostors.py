#!/usr/bin/env python3
"""Packs the baked woodland impostors (R3.1, issue #660) into the map's atlases.

Reads a raw bake directory (`bake_impostors.gd --raw=<dir>`) and writes
assets/art/map-journey/impostors/:

- wood-albedo.png: RGBA, the albedo as rendered (sRGB), alpha = coverage.
- wood-normal.png: at half the albedo's resolution (lighting is smooth; half
  the bytes): RGB = world normal * 0.5 + 0.5 (raw, not sRGB), A = how much of
  the key light reaches the fragment through its own crown, darkened where a
  leaf is seen through a gap ("recess occlusion").
- wood-tiles.json: per tile its kind, page and rect on it, picture-plane rect
  (metres, relative to the model's base), how far it reaches toward the camera
  and how tall it stands, and its silhouette as row spans every `SPAN_M`
  metres down the picture (the planting's occlusion mask).

Each atlas is `PAGES` pages of `ATLAS_W` x `PAGE_H` stacked down the picture,
imported as a 2D texture array of one layer a page. The engine uploads an array
a layer at a time, so no upload passes 4 MiB with its mips: a RenderingDevice
transfer worker's staging buffer grows to the next power of two above its
largest upload and is never shrunk (R3.3). The importer makes a VRAM-
compressed array's layers powers of two, so the pages are.

Supersampled renders are reduced with alpha weighting, and every transparent
texel takes its nearest covered neighbour's colour so mipmaps never darken the
cut edge.

    python3 tools/map_atelier/journey/impostors/pack_impostors.py <raw dir> [<repo root>]
"""
import json
import os
import sys

import cv2
import numpy as np
from PIL import Image

ATLAS_W = 2048
PAGE_H = 1024
PAGES = 2
RECESS_PX = 9
RECESS_M = 1.4
RECESS_STRENGTH = 0.7
# Gutter between tiles, in albedo texels (even, so the half-size normal atlas
# keeps a texel of it).
PAD = 4
# The silhouette mask: one span of covered x per this many metres down the
# picture, from coverage at least `MASK_ALPHA`.
SPAN_M = 0.25
MASK_ALPHA = 0.5


def srgb_to_linear(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def linear_to_srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def load(raw, name, kind):
    path = os.path.join(raw, f"{name}-{kind}.png")
    return np.asarray(Image.open(path).convert("RGBA")).astype(np.float64) / 255.0


def reduce(values, alpha, ss):
    """Alpha-weighted box reduction by ss (values H x W x C)."""
    h, w = alpha.shape[0] // ss, alpha.shape[1] // ss
    a = alpha[: h * ss, : w * ss].reshape(h, ss, w, ss)
    v = values[: h * ss, : w * ss].reshape(h, ss, w, ss, values.shape[2])
    weight = a.sum(axis=(1, 3))
    out = (v * a[..., None]).sum(axis=(1, 3)) / np.maximum(weight, 1e-6)[..., None]
    return out, a.mean(axis=(1, 3))


def nearest(covered):
    """For every texel, the row and column of the nearest covered texel."""
    src = (~covered).astype(np.uint8)
    _, labels = cv2.distanceTransformWithLabels(src, cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL)
    ys, xs = np.nonzero(covered)
    lookup_y = np.zeros(labels.max() + 1, dtype=np.int64)
    lookup_x = np.zeros(labels.max() + 1, dtype=np.int64)
    lookup_y[labels[ys, xs]] = ys
    lookup_x[labels[ys, xs]] = xs
    return lookup_y[labels], lookup_x[labels]


def dilate(rgb, alpha):
    """Every transparent texel takes the colour of the nearest covered one."""
    covered = alpha > 0.02
    if not covered.any():
        return rgb
    iy, ix = nearest(covered)
    return rgb[iy, ix]


def spans(alpha, size_m):
    """The silhouette as [x0, x1] spans (tile units, 0..1) per `SPAN_M` rows
    down the picture; [1, 0] where the row is empty."""
    h, w = alpha.shape
    rows = max(1, int(size_m[1] / SPAN_M + 0.5))
    out = []
    for r in range(rows):
        y0 = int(r * h / rows)
        y1 = max(y0 + 1, int((r + 1) * h / rows))
        band = (alpha[y0:y1] >= MASK_ALPHA).any(axis=0)
        xs = np.nonzero(band)[0]
        if xs.size == 0:
            out.append([1.0, 0.0])
        else:
            out.append([round(float(xs[0]) / w, 4), round(float(xs[-1] + 1) / w, 4)])
    return out


def pack_tile(raw, row, ss):
    name = row["name"]
    albedo = load(raw, name, "albedo")
    normal = load(raw, name, "normal")
    shadow = load(raw, name, "shadow")
    depth = load(raw, name, "depth")
    alpha = albedo[..., 3]
    lin, a = reduce(srgb_to_linear(albedo[..., :3]), alpha, ss)
    n_lin = srgb_to_linear(normal[..., :3]) * 2.0 - 1.0
    n, _ = reduce(n_lin, alpha, ss)
    n /= np.maximum(np.linalg.norm(n, axis=2), 1e-6)[..., None]
    s, _ = reduce(srgb_to_linear(shadow[..., :1]), alpha, ss)
    # Recess occlusion: a fragment seen through a gap, deeper than the crown's
    # front surface round it, is darker. The front surface is the nearest
    # depth within a few texels (a min filter over covered texels).
    d, _ = reduce(srgb_to_linear(depth[..., :1]) * 32.0, alpha, ss)
    d = d[..., 0]
    covered = a > 0.5
    far = np.where(covered, d, 1e3).astype(np.float32)
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * RECESS_PX + 1, 2 * RECESS_PX + 1))
    front = cv2.erode(far, kernel)
    recess = np.clip((d - front) / RECESS_M, 0.0, 1.0)
    occlusion = np.where(covered, 1.0 - RECESS_STRENGTH * recess, 1.0)
    s = s * occlusion[..., None]
    return {"row": row, "albedo": dilate(linear_to_srgb(lin), a), "alpha": a,
            "normal": dilate(n * 0.5 + 0.5, a), "shadow": dilate(s, a),
            "spans": spans(a, row["size"])}


def shelf_pack(tiles):
    """Shelf packing, tallest first, a shelf that would pass a page's foot
    starting the next page; returns each tile's (page, x, y)."""
    order = sorted(range(len(tiles)), key=lambda i: -tiles[i]["alpha"].shape[0])
    page = x = y = shelf = 0
    places = {}
    for i in order:
        h, w = tiles[i]["alpha"].shape
        if x + w + PAD > ATLAS_W:
            x, y, shelf = 0, y + shelf + PAD, 0
        if y + h > PAGE_H:
            page, x, y, shelf = page + 1, 0, 0, 0
        if page >= PAGES:
            sys.exit(f"the tiles do not fit {PAGES} pages of {ATLAS_W}x{PAGE_H}")
        places[i] = (page, x, y)
        x += w + PAD
        shelf = max(shelf, h)
    return places


def repo_root():
    here = os.path.dirname(os.path.abspath(__file__))
    while not os.path.exists(os.path.join(here, "project.godot")):
        here = os.path.dirname(here)
    return here


def main():
    raw = sys.argv[1]
    root = sys.argv[2] if len(sys.argv) > 2 else repo_root()
    out_dir = os.path.join(root, "assets/art/map-journey/impostors")
    meta = json.load(open(os.path.join(raw, "tiles_raw.json")))
    ss = int(meta["ss"])
    tiles = [pack_tile(raw, row, ss) for row in meta["tiles"]]
    places = shelf_pack(tiles)
    albedo_pages = np.zeros((PAGES, PAGE_H, ATLAS_W, 4))
    normal_pages = np.zeros((PAGES, PAGE_H, ATLAS_W, 4))
    normal_pages[..., :3] = 0.5
    normal_pages[..., 1] = 1.0
    normal_pages[..., 3] = 1.0
    out_tiles = []
    for i, tile in enumerate(tiles):
        h, w = tile["alpha"].shape
        page, px, py = places[i]
        albedo_pages[page, py:py + h, px:px + w, :3] = tile["albedo"]
        albedo_pages[page, py:py + h, px:px + w, 3] = tile["alpha"]
        normal_pages[page, py:py + h, px:px + w, :3] = tile["normal"]
        normal_pages[page, py:py + h, px:px + w, 3] = tile["shadow"][..., 0]
        row = tile["row"]
        out_tiles.append({"name": row["name"], "kind": row["kind"], "yaw": round(row["yaw"], 5),
                          "layer": page, "uv": [px / ATLAS_W, py / PAGE_H, w / ATLAS_W, h / PAGE_H],
                          "low": [round(v, 5) for v in row["low"]], "size": [round(v, 5) for v in row["size"]],
                          "front": round(row["front"], 4), "top": round(row["top"], 4),
                          "spans": tile["spans"]})
    halves = []
    for page in range(PAGES):
        # Fill the gutters round each tile with its edge colours (bleed for
        # mips), within the page: a layer is filtered alone.
        covered = albedo_pages[page, ..., 3] > 0.02
        iy, ix = nearest(covered)
        albedo_pages[page, ..., :3] = albedo_pages[page][iy, ix, :3]
        normal_pages[page] = normal_pages[page][iy, ix, :]
        halves.append(cv2.resize(normal_pages[page], (ATLAS_W // 2, PAGE_H // 2), interpolation=cv2.INTER_AREA))
    os.makedirs(out_dir, exist_ok=True)
    Image.fromarray((np.clip(np.concatenate(albedo_pages), 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(
        os.path.join(out_dir, "wood-albedo.png"), optimize=True)
    Image.fromarray((np.clip(np.concatenate(halves), 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(
        os.path.join(out_dir, "wood-normal.png"), optimize=True)
    with open(os.path.join(out_dir, "wood-tiles.json"), "w") as handle:
        json.dump({"pitch": meta["pitch"], "px_per_m": meta["px_per_m"], "span_m": SPAN_M,
                   "atlas": [ATLAS_W, PAGE_H], "pages": PAGES, "tiles": out_tiles}, handle, separators=(",", ":"))
    used = [max((places[i][2] + tiles[i]["alpha"].shape[0] for i in places if places[i][0] == page), default=0)
            for page in range(PAGES)]
    print(f"packed {len(out_tiles)} tiles into {PAGES} pages of {ATLAS_W}x{PAGE_H} (rows used {used}; "
          f"normals {ATLAS_W // 2}x{PAGE_H // 2})")


if __name__ == "__main__":
    main()
