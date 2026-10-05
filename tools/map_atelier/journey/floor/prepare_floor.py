"""Act I's floor textures (R3.2, issue #660) from the generated pictures.

The floor's bake paints with four ground covers and a scatter atlas, and the
live floor adds a tiled micro detail (`presentation/map/landscape/floor_*`).
From the pictures in `sources/` (generated with the image tool; prompts in
`sources/prompts.txt`):

- covers (moss, litter, soil, road): the slow light divided out, the edges
  blended with the picture rolled half a tile so it wraps, a light grade, 512 px;
- splats: the green key cut to alpha, its spill pulled back and the colour
  bled out under the cut, 512 px (4 x 4 cells of 128);
- detail: grain from the soil and road covers' fine structure (r), sparse
  glint speckles (g) and each one's twinkle phase (b), 512 px, wrapping.

Deterministic (numpy and Pillow; seed 717): re-running it reproduces the
shipped files.

    python3 tools/map_atelier/journey/floor/prepare_floor.py
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image


def blur_wrap(a, sigma):
    """A Gaussian blur that wraps round the picture's edges (in frequency)."""
    h, w = a.shape
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    kernel = np.exp(-2.0 * (np.pi * sigma) ** 2 * (fx * fx + fy * fy))
    return np.real(np.fft.ifft2(np.fft.fft2(a) * kernel))


def blur_clamp(a, sigma):
    pad = int(sigma * 4) + 1
    padded = np.pad(a, pad, mode="edge")
    return blur_wrap(padded, sigma)[pad:-pad, pad:-pad]


def erode3(a):
    out = a.copy()
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            out = np.minimum(out, np.roll(np.roll(a, dy, 0), dx, 1))
    return out


def bleed(rgb, solid, rounds=24):
    """Spreads the solid pixels' colour outward into the cut-away ones."""
    rgb = rgb * solid[..., None]
    weight = solid.astype(np.float64)
    for _ in range(rounds):
        acc = np.zeros_like(rgb)
        wsum = np.zeros_like(weight)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                acc += np.roll(np.roll(rgb, dy, 0), dx, 1)
                wsum += np.roll(np.roll(weight, dy, 0), dx, 1)
        grown = wsum > 0
        fill = (weight == 0) & grown
        rgb[fill] = acc[fill] / wsum[fill][:, None]
        weight[fill] = 1.0
    return rgb

HERE = Path(__file__).resolve().parent
RAW = HERE / "sources"
OUT = HERE.parents[3] / "assets" / "art" / "map-journey" / "floor"
OUT.mkdir(parents=True, exist_ok=True)
SIZE = 512


def load(name):
    path = RAW / f"{name}.jpg"
    if not path.exists():
        path = RAW / f"{name}.png"
    return np.asarray(Image.open(path).convert("RGB"), dtype=np.float64) / 255.0


def to_linear(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def to_srgb(c):
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def flatten(img, sigma):
    """Divides out the picture's slow light, keeping its mean."""
    lin = to_linear(img)
    lum = lin @ np.array([0.2126, 0.7152, 0.0722])
    slow = blur_wrap(lum, sigma)
    lin = lin * (lum.mean() / np.maximum(slow, 1e-4))[..., None]
    return to_srgb(lin)


def wrap_edges(img, frac=0.18):
    """Blends the picture with itself rolled half a tile near its borders, so it tiles."""
    h, w, _ = img.shape
    rolled = np.roll(np.roll(img, h // 2, 0), w // 2, 1)
    y = np.minimum(np.arange(h), h - 1 - np.arange(h)) / (h * frac)
    x = np.minimum(np.arange(w), w - 1 - np.arange(w)) / (w * frac)
    wy = np.clip(y, 0, 1)
    wx = np.clip(x, 0, 1)
    inner = np.minimum.outer(wy, wx)
    inner = inner * inner * (3 - 2 * inner)
    return img * inner[..., None] + rolled * (1 - inner[..., None])


def grade(img, saturation=1.0, warmth=(1.0, 1.0, 1.0), gain=1.0):
    lin = to_linear(img)
    lum = (lin @ np.array([0.2126, 0.7152, 0.0722]))[..., None]
    lin = lum + (lin - lum) * saturation
    lin = lin * np.array(warmth) * gain
    return to_srgb(lin)


def save(img, name, mode="RGB"):
    data = (np.clip(img, 0, 1) * 255.0 + 0.5).astype(np.uint8)
    Image.fromarray(data, mode).save(OUT / f"{name}.png", optimize=True)


def cover(name, **kw):
    img = load(name)
    img = flatten(img, 96)
    img = wrap_edges(img)
    img = grade(img, **kw)
    small = Image.fromarray((np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8)).resize((SIZE, SIZE), Image.LANCZOS)
    small = np.asarray(small, dtype=np.float64) / 255.0
    save(small, name)
    return small


moss = cover("floor-moss", saturation=0.62, warmth=(1.06, 0.97, 0.82), gain=0.9)
litter = cover("floor-litter", saturation=0.9, warmth=(1.0, 0.97, 0.95), gain=0.95)
soil = cover("floor-soil", saturation=0.8, warmth=(1.0, 0.98, 1.0), gain=1.0)
road = cover("floor-road", saturation=0.85, warmth=(1.0, 0.96, 0.9), gain=1.0)

# Splats: the key's distance in colour to alpha, the spill pulled back.
img = load("floor-splats")
r, g, b = img[..., 0], img[..., 1], img[..., 2]
greenness = g - np.maximum(r, b)
alpha = 1.0 - np.clip((greenness - 0.12) / 0.38, 0.0, 1.0)
alpha = erode3(alpha)
alpha = blur_clamp(alpha, 0.8)
spill = np.clip(g - np.maximum(r, b), 0, None)
rgb = img.copy()
rgb[..., 1] = g - spill * 0.9
# Bleed the colour out under the cut, so mips of the edge stay its own colour.
solid = alpha > 0.5
rgb = bleed(rgb, solid)
rgba = np.dstack([rgb, alpha])
small = Image.fromarray((np.clip(rgba, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").resize((SIZE, SIZE), Image.LANCZOS)
small.save(OUT / "floor-splats.png", optimize=True)

# Detail: grain from the covers' fine structure, glints and their phases.
rng = np.random.default_rng(717)
D = 512
fine = []
for src in (soil, road):
    lum = src @ np.array([0.3, 0.59, 0.11])
    lum = lum - blur_wrap(lum, 4.0)
    fine.append(lum / (np.percentile(np.abs(lum), 98) + 1e-6))
grain = (fine[0] * 0.6 + np.roll(fine[1], (D // 3, D // 5), (0, 1)) * 0.6)
grain = 0.5 + np.clip(grain, -1.6, 1.6) * 0.28
speck = np.zeros((D, D))
phase = np.zeros((D, D))
for _ in range(700):
    y, x = rng.integers(0, D, 2)
    s_ = rng.uniform(0.6, 1.0)
    p_ = rng.uniform(0, 1)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            fall = s_ * (1.0 if dy == 0 and dx == 0 else 0.45)
            yy, xx = (y + dy) % D, (x + dx) % D
            if fall > speck[yy, xx]:
                speck[yy, xx] = fall
                phase[yy, xx] = p_
save(np.dstack([np.clip(grain, 0, 1), speck, phase]), "floor-detail")
print("ok", {n: (OUT / f"{n}.png").stat().st_size for n in ["floor-moss", "floor-litter", "floor-soil", "floor-road", "floor-splats", "floor-detail"]})
