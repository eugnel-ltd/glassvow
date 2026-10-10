"""Shared helpers for the journey's tiled ground and stone pictures (numpy).

Used by `floor/prepare_floor.py` (R3.2) and `stone/prepare_stone.py` (R3.3):
a wrapping blur, sRGB and linear light, the slow light divided out, the edges
blended so a picture tiles, and a light grade.
"""
import numpy as np


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
