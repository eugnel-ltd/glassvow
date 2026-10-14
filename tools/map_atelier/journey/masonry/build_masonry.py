"""Act II's masonry atlas (#660 II.3): the Sunken City's slate-lavender stone.

Run from the repository root with Python 3 (numpy, Pillow):

    python3 tools/map_atelier/journey/masonry/build_masonry.py

Writes two tileable layers, each 2 m wide and 1 m high in the world, into one
atlas, as R3.3's stone atlas carries its colour and, at half size, its
tangent-space normals:

- assets/art/map-journey/masonry/masonry-albedo.png (1024 x 1024): the top half
  is ashlar (the causeways' walls, piers and parapets: courses of cut blocks,
  their arrises worn pale, in dark mortar), the bottom half paving (the decks:
  small setts, worn smooth and lighter along the middle of the road);
- assets/art/map-journey/masonry/masonry-normal.png (512 x 512): their normals,
  from the same height field (OpenGL convention, +Y up, as the stone's).

The occlusion is carried in the colour. Deterministic (seed 6602). The art is a
lane pick (`docs/art-ledger.md`); the owner may re-pick, and a re-pick is a
change of the recipe's numbers below.
"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[4]
OUT = ROOT / 'assets/art/map-journey/masonry'
WIDTH = 1024
LAYER = 512
RNG = np.random.default_rng(6602)
# Metres a layer spans across and up: 512 texels a metre.
SPAN = (2.0, 1.0)

# The palette (sRGB): slate-lavender stone, a cooler and a warmer block, the
# dark mortar between, and the pale worn arrises.
STONE = np.array([0.36, 0.37, 0.45])
STONE_COOL = np.array([0.27, 0.31, 0.40])
STONE_WARM = np.array([0.43, 0.40, 0.46])
MORTAR = np.array([0.10, 0.11, 0.14])
WORN = np.array([0.55, 0.56, 0.62])


def value_noise(width, height, cells, seed):
    """Tileable value noise: a periodic lattice of `cells` across, smoothly
    interpolated."""
    rng = np.random.default_rng(seed)
    lattice = rng.random((cells[1], cells[0]))
    ys = np.arange(height) * cells[1] / height
    xs = np.arange(width) * cells[0] / width
    y0 = np.floor(ys).astype(int)
    x0 = np.floor(xs).astype(int)
    fy = ys - y0
    fx = xs - x0
    fy = fy * fy * (3 - 2 * fy)
    fx = fx * fx * (3 - 2 * fx)
    y1 = (y0 + 1) % cells[1]
    x1 = (x0 + 1) % cells[0]
    a = lattice[np.ix_(y0, x0)]
    b = lattice[np.ix_(y0, x1)]
    c = lattice[np.ix_(y1, x0)]
    d = lattice[np.ix_(y1, x1)]
    top = a + (b - a) * fx[None, :]
    bottom = c + (d - c) * fx[None, :]
    return top + (bottom - top) * fy[:, None]


def fractal(width, height, base, octaves, seed):
    total = np.zeros((height, width))
    weight = 0.0
    for octave in range(octaves):
        scale = 2 ** octave
        amplitude = 0.5 ** octave
        total += amplitude * value_noise(width, height, (base[0] * scale, base[1] * scale), seed + octave)
        weight += amplitude
    return total / weight


def blocks(width, height, rows, lengths, gap, bevel, seed, round_corners=0.0):
    """A tileable bond of rectangular blocks: `rows` courses, each block
    `lengths` (min, max) texels long, `gap` texels of mortar, its arrises
    bevelled over `bevel` texels. Returns the height field (1 on a block's
    face, 0 in the mortar), each texel's block tint (-1 to 1) and its
    distance in from the nearest arris (texels)."""
    rng = np.random.default_rng(seed)
    face = np.zeros((height, width))
    tint = np.zeros((height, width))
    inset = np.zeros((height, width))
    course = height / rows
    for row in range(rows):
        top = int(round(row * course))
        bottom = int(round((row + 1) * course))
        offset = int(rng.integers(0, width))
        x = 0
        cuts = []
        while x < width:
            length = int(rng.integers(lengths[0], lengths[1]))
            if width - (x + length) < lengths[0]:
                length = width - x
            cuts.append((x, x + length))
            x += length
        for start, end in cuts:
            shade = rng.uniform(-1, 1)
            ys = np.arange(top, bottom)
            xs = (np.arange(start, end) + offset) % width
            yy, xx = np.meshgrid(ys - top, np.arange(end - start), indexing='ij')
            h = bottom - top
            w = end - start
            # Distance in from the block's edge, less the mortar's half.
            dist = np.minimum(np.minimum(yy, h - 1 - yy), np.minimum(xx, w - 1 - xx)).astype(float) - gap * 0.5
            if round_corners > 0:
                cx = np.minimum(xx, w - 1 - xx)
                cy = np.minimum(yy, h - 1 - yy)
                corner = np.hypot(np.maximum(0, round_corners - cx), np.maximum(0, round_corners - cy))
                dist = np.minimum(dist, round_corners - corner - gap * 0.5)
            profile = np.clip(dist / bevel, 0, 1)
            profile = profile * profile * (3 - 2 * profile)
            face[np.ix_(ys, xs)] = profile
            tint[np.ix_(ys, xs)] = shade
            inset[np.ix_(ys, xs)] = dist
    return face, tint, inset


def warp(fields, amount, seed):
    """Displaces every field in `fields` by the same tileable noise, `amount`
    texels at most, so the joints wander as laid stone's do."""
    h, w = fields[0].shape
    dx = (fractal(w, h, (12, 6), 3, seed) - 0.5) * 2 * amount
    dy = (fractal(w, h, (12, 6), 3, seed + 100) - 0.5) * 2 * amount
    ys, xs = np.mgrid[0:h, 0:w]
    sy = (ys + dy).round().astype(int) % h
    sx = (xs + dx).round().astype(int) % w
    return [field[sy, sx] for field in fields]


def chips(face, inset, seed, depth):
    """Knocks chips out of the arrises: noise eats into a block's edge."""
    h, w = face.shape
    bite = fractal(w, h, (64, 32), 2, seed)
    eaten = np.clip((depth - inset) / depth, 0, 1) * np.clip((bite - 0.55) * 4, 0, 1)
    return face * (1 - eaten)


def ashlar():
    """The walls: four courses a metre (0.25 m stones; smaller would read as
    rubble at the map's distance), blocks 0.3 to 0.75 m long."""
    w, h = WIDTH, LAYER
    face, tint, inset = blocks(w, h, 4, (150, 380), 6, 12, 11)
    face, tint, inset = warp([face, tint, inset], 5, 13)
    face = chips(face, inset, 17, 10.0)
    rough = fractal(w, h, (16, 8), 5, 21)
    grain = fractal(w, h, (96, 48), 3, 31)
    stain = fractal(w, h, (4, 2), 3, 41)
    height = face * (0.82 + 0.18 * rough) - 0.04 * grain * face
    base = np.where(tint[..., None] < 0, STONE + (STONE_COOL - STONE) * -tint[..., None],
                    STONE + (STONE_WARM - STONE) * tint[..., None])
    colour = base * (0.86 + 0.24 * rough[..., None]) * (0.92 + 0.12 * grain[..., None])
    # The arrises worn pale, the faces darker toward their middles' pits.
    arris = np.clip(1 - np.abs(inset - 3.0) / 5.0, 0, 1) * (face > 0.05)
    colour = colour + (WORN - colour) * (0.35 * arris)[..., None]
    colour = colour * (0.85 + 0.15 * stain[..., None])
    mortar = np.clip(1 - face * 1.6, 0, 1)
    colour = colour + (MORTAR - colour) * mortar[..., None]
    return colour, height


def paving():
    """The decks: setts about 0.18 x 0.14 m in staggered rows, rounded and worn
    smooth, lighter where feet pass (the layer's middle, its V running along
    the road)."""
    w, h = WIDTH, LAYER
    face, tint, inset = blocks(w, h, 7, (64, 110), 6, 14, 51, round_corners=14.0)
    face, tint, inset = warp([face, tint, inset], 4, 53)
    face = chips(face, inset, 57, 8.0)
    rough = fractal(w, h, (24, 12), 4, 61)
    grain = fractal(w, h, (128, 64), 3, 71)
    height = face * (0.75 + 0.25 * rough)
    base = np.where(tint[..., None] < 0, STONE + (STONE_COOL - STONE) * -tint[..., None],
                    STONE + (STONE_WARM - STONE) * tint[..., None])
    colour = base * 0.95 * (0.85 + 0.25 * rough[..., None]) * (0.92 + 0.1 * grain[..., None])
    # Polish: the crown of each sett catches a little more.
    crown = np.clip(inset / 18.0, 0, 1) * (face > 0.05)
    colour = colour + (WORN - colour) * (0.22 * crown)[..., None]
    mortar = np.clip(1 - face * 1.5, 0, 1)
    colour = colour + (MORTAR - colour) * mortar[..., None]
    return colour, height


def normals(height, strength):
    """Tangent-space normals from a tileable height field (OpenGL: green up,
    the layer's V running down the image)."""
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 0.5
    n = np.stack([-dx * strength, dy * strength, np.ones_like(height)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n * 0.5 + 0.5


def half(image):
    """Box-filters an image to half its size (it tiles, so its edges wrap)."""
    return (image[0::2, 0::2] + image[1::2, 0::2] + image[0::2, 1::2] + image[1::2, 1::2]) * 0.25


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    wall_colour, wall_height = ashlar()
    deck_colour, deck_height = paving()
    colour = np.concatenate([wall_colour, deck_colour], axis=0)
    height = np.concatenate([wall_height, deck_height], axis=0)
    # Each layer's normals from its own field, so neither bleeds into the other.
    normal = np.concatenate([normals(wall_height, 6.0), normals(deck_height, 5.0)], axis=0)
    Image.fromarray(np.clip(colour * 255 + 0.5, 0, 255).astype(np.uint8), 'RGB').save(OUT / 'masonry-albedo.png', optimize=True)
    Image.fromarray(np.clip(half(normal) * 255 + 0.5, 0, 255).astype(np.uint8), 'RGB').save(OUT / 'masonry-normal.png', optimize=True)
    print('wrote', OUT / 'masonry-albedo.png', OUT / 'masonry-normal.png', 'height range', float(height.min()), float(height.max()))


if __name__ == '__main__':
    main()
