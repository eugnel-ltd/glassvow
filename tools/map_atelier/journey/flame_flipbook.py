"""The lanterns' flame: a 4x4 flipbook of one looping flicker (R2 light).

Run from the repository root with Python 3 (numpy, Pillow):

    python3 tools/map_atelier/journey/flame_flipbook.py

Writes assets/art/map-journey/textures/flame-flipbook.png: 256x256, sixteen
64x64 frames left to right, top to bottom. Straight alpha; the flame shader
draws it additively. The flicker is value noise sampled on a circle in time,
so frame 15 runs back into frame 0 without a jump. Deterministic (seed 7411).
"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'assets/art/map-journey/textures/flame-flipbook.png'
FRAMES = 16
SIZE = 64
RNG = np.random.default_rng(7411)
LATTICE = RNG.random((32, 32, 32))


def noise(x, y, z):
    """Trilinear value noise on a periodic 32-cell lattice."""
    xi, yi, zi = np.floor(x).astype(int), np.floor(y).astype(int), np.floor(z).astype(int)
    xf, yf, zf = x - xi, y - yi, z - zi
    xf, yf, zf = [f * f * (3 - 2 * f) for f in (xf, yf, zf)]
    out = 0.0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (xf if dx else 1 - xf) * (yf if dy else 1 - yf) * (zf if dz else 1 - zf)
                out = out + w * LATTICE[(xi + dx) % 32, (yi + dy) % 32, (zi + dz) % 32]
    return out


def frame(index):
    angle = 2 * np.pi * index / FRAMES
    # Time runs round a circle in two noise dimensions, so the loop closes.
    tx, tz = 4 + 1.6 * np.cos(angle), 4 + 1.6 * np.sin(angle)
    v, u = np.mgrid[0:SIZE, 0:SIZE].astype(float)
    u = (u + .5) / SIZE * 2 - 1           # -1 left .. 1 right
    h = 1 - (v + .5) / SIZE               # 0 bottom .. 1 top
    rise = h * 3.0
    sway = (noise(tx + rise * .7, 3.1 + 0 * u, tz) - .5) * .55 * h
    lick = (noise(tx + u * 2.2 + 7, rise * 1.6 - index * .12, tz + 3) - .5) * .32 * h
    x = u - sway - lick
    # A teardrop: widest a fifth of the way up, closing to a point at the tip.
    width = .44 * np.clip(np.sin(np.clip(h * 1.05 + .18, 0, 1) * np.pi), 0, 1) * (1 - .55 * h)
    width = np.maximum(width, 1e-3)
    body = np.clip(1 - np.abs(x) / width, 0, 1)
    height = .86 + .08 * (noise(tx + 11, 5.0 + 0 * u, tz + 9) - .5)
    fade = np.clip((height - h) / .22, 0, 1) * np.clip(h / .08, 0, 1)
    shape = body ** 1.4 * fade
    core = np.clip(body * 1.6 - .55, 0, 1) * np.clip((.62 - h) / .4, 0, 1)
    red = np.clip(.95 + .05 * core, 0, 1)
    green = np.clip(.38 + .45 * shape + .4 * core, 0, 1)
    blue = np.clip(.06 + .12 * shape + .55 * core, 0, 1)
    alpha = np.clip(shape * 1.25, 0, 1)
    rgba = np.stack([red, green, blue, alpha], axis=-1)
    return (rgba * 255 + .5).astype(np.uint8)


def main():
    atlas = np.zeros((SIZE * 4, SIZE * 4, 4), np.uint8)
    for i in range(FRAMES):
        row, col = divmod(i, 4)
        atlas[row * SIZE:(row + 1) * SIZE, col * SIZE:(col + 1) * SIZE] = frame(i)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(atlas, 'RGBA').save(OUT, optimize=True)
    print('FLAME_FLIPBOOK_OK', OUT.relative_to(ROOT), OUT.stat().st_size, flush=True)


if __name__ == '__main__':
    main()
