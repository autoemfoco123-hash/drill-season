#!/usr/bin/env python3
"""Paints the tileable noise texture the Godot sky shader samples for clouds and aurora.

    python3 tools/make-sky-noise.py   ->  godot/assets/art/skynoise.png (256x256 RGBA)

R: fbm 4..32 (cloud body)   G: fbm 8..64 (detail)   B: inverted cellular (billows)   A: fbm 2..4 (coverage)
Every channel wraps at the edges, so the shader can scroll and repeat it without seams.
Precomputed on purpose: sin-hash noise breaks on phones whose GPUs only have mediump floats.
"""
import os
import numpy as np
from PIL import Image

N = 256
rng = np.random.default_rng(1998)


def value_noise(f):
    g = rng.random((f, f))
    x = np.arange(N) * f / N
    i = np.floor(x).astype(int)
    t = x - i
    t = t * t * t * (t * (t * 6 - 15) + 10)
    i0, i1 = i % f, (i + 1) % f
    a = g[np.ix_(i0, i0)]
    b = g[np.ix_(i0, i1)]
    c = g[np.ix_(i1, i0)]
    d = g[np.ix_(i1, i1)]
    ty, tx = t[:, None], t[None, :]
    return (a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty


def fbm(freqs):
    out = np.zeros((N, N))
    w = 1.0
    tot = 0.0
    for f in freqs:
        out += value_noise(f) * w
        tot += w
        w *= 0.5
    out /= tot
    lo, hi = np.percentile(out, 1), np.percentile(out, 99)
    return np.clip((out - lo) / (hi - lo), 0, 1)


def cellular(f):
    pts = (np.arange(f)[:, None, None] + rng.random((f, f, 2))) / f  # one point per cell
    pts = pts.reshape(-1, 2) if False else np.stack([(np.arange(f)[:, None] + rng.random((f, f))) / f,
                                                     (np.arange(f)[None, :] + rng.random((f, f))) / f], -1).reshape(-1, 2)
    y, x = np.mgrid[0:N, 0:N] / N
    best = np.full((N, N), 9.0)
    for py, px in pts:
        for oy in (-1, 0, 1):
            for ox in (-1, 0, 1):
                d = (y - py - oy) ** 2 + (x - px - ox) ** 2
                best = np.minimum(best, d)
    d = np.sqrt(best) * f
    return np.clip(1 - d, 0, 1)


r = fbm([4, 8, 16, 32])
g = fbm([8, 16, 32, 64])
b = cellular(6) * 0.65 + cellular(12) * 0.35
b = (b - b.min()) / (b.max() - b.min())
a = fbm([2, 4])
img = np.stack([r, g, b, a], -1)
out = os.path.join(os.path.dirname(__file__), "..", "godot", "assets", "art", "skynoise.png")
Image.fromarray((img * 255).round().astype(np.uint8), "RGBA").save(out, optimize=True)
print("wrote", os.path.normpath(out), os.path.getsize(out), "bytes")
