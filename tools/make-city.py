#!/usr/bin/env python3
"""Paints the city's textures for the cel-shaded look into godot/assets/tex/.

Semi-realistic, not photographic: clean shapes, a limited palette per material, crisp dark
lines where things meet (mortar, plank shadows, window frames), soft ambient shading around
openings. The facades keep the exact window layout of the originals (4 floors x 4 bays in
256 px = 12 x 12 m; the warehouse has wide windows on every other bay and floor), so the
night-time window maps baked into city.glb still line up.

  wall_<style>.png           brick, brown, grey (stone), siding, cream, ware (warehouse): plain
                             wall, 6 x 6 m per tile; the windows, cornices and storefronts are
                             real geometry (scripts/CityBuild.gd)
  signs.png                  the shop signs (made-up generic names) and street signs, one atlas
  road.png                   asphalt with slush tracks and the centre dashes, snow at the kerbs
  walk.png                   sidewalk slabs with a dusting of snow and salt

Usage: python3 tools/make-city.py    (needs numpy and Pillow)
"""
import os, math, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
OUT = os.path.join(ROOT, 'godot', 'assets', 'tex')
os.makedirs(OUT, exist_ok=True)
N = 256


def save(im, name):
    im.save(os.path.join(OUT, name + '.png'), optimize=True)
    print('%-18s %4d KB' % (name, os.path.getsize(os.path.join(OUT, name + '.png')) // 1024))


def hexc(h):
    h = h.lstrip('#')
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], float)


def noise(rng, n, f):
    g = rng.random((f, f))
    x = np.arange(n) * f / n
    i = np.floor(x).astype(int); t = x - i; t = t * t * (3 - 2 * t)
    i0, i1 = i % f, (i + 1) % f
    a, b, c, d = g[np.ix_(i0, i0)], g[np.ix_(i0, i1)], g[np.ix_(i1, i0)], g[np.ix_(i1, i1)]
    ty, tx = t[:, None], t[None, :]
    return (a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty


def windows(style):
    ware = style == 'ware'
    out = []
    for f in range(4):
        for c in range(4):
            if ware and (f % 2 == 1 or c % 2 == 1):
                continue
            x = c * 64 + (8 if ware else 18)
            y = f * 64 + (10 if ware else 12)
            out.append((x, y, 48 if ware else 28, 14 if ware else 38))
    return out


# per style: wall colours, mortar/line colour, trim (frames, sills), lintel
STYLE = {
    'brick':  dict(wall=['#8a3b2c', '#7a3326', '#9a4433', '#6e2d22'], line='#4a2a24', trim='#e8e1d4', lintel='#5b2a21', kind='brick'),
    'brown':  dict(wall=['#5a3a2c', '#4e3226', '#664233', '#452b21'], line='#2c1d17', trim='#d9cfc0', lintel='#3a2419', kind='brick'),
    'cream':  dict(wall=['#b59a72', '#a88d66', '#c2a77e', '#9c825d'], line='#7a6448', trim='#f0ebe0', lintel='#8a7152', kind='brick'),
    'grey':   dict(wall=['#9a958a', '#8f8a7f', '#a7a296', '#858075'], line='#5e5a52', trim='#ece7dc', lintel='#7c776c', kind='stone'),
    'siding': dict(wall=['#5b6b7b', '#56667a', '#607080', '#52626f'], line='#2f3a45', trim='#eef1f4', lintel='#47535f', kind='siding'),
    'ware':   dict(wall=['#5f6266', '#585b5f', '#666a6e', '#525559'], line='#33363a', trim='#2c3034', lintel='#45484c', kind='panel'),
}


def facade(style, seed, wins=True):
    S = STYLE[style]
    rng = np.random.default_rng(seed)
    R = random.Random(seed)
    img = np.zeros((N, N, 3))
    walls = [hexc(c) for c in S['wall']]
    line = hexc(S['line'])
    kind = S['kind']
    if kind == 'brick':
        bh, bw = 4, 9
        for row in range(N // bh):
            off = (row % 2) * (bw // 2)
            for x0 in range(-bw, N, bw):
                c = walls[R.randrange(len(walls))] * (0.94 + R.random() * 0.12)
                xa = x0 + off
                img[row * bh:row * bh + bh - 1, max(0, xa):max(0, min(N, xa + bw - 1))] = c
                if xa + bw - 1 < N and xa + bw - 1 >= 0:
                    img[row * bh:row * bh + bh, xa + bw - 1] = line
            img[row * bh + bh - 1, :] = line
    elif kind == 'stone':
        bh, bw = 12, 22
        for row in range(N // bh + 1):
            off = (row % 2) * 11
            for x0 in range(-bw, N, bw):
                c = walls[R.randrange(len(walls))] * (0.95 + R.random() * 0.1)
                xa = x0 + off
                y0 = row * bh
                img[y0:min(N, y0 + bh - 1), max(0, xa):max(0, min(N, xa + bw - 1))] = c
                if 0 <= xa + bw - 1 < N:
                    img[y0:min(N, y0 + bh), xa + bw - 1] = line
            if row * bh + bh - 1 < N:
                img[row * bh + bh - 1, :] = line
    elif kind == 'siding':
        for y0 in range(0, N, 5):
            img[y0:y0 + 5, :] = walls[(y0 // 5) % 2] * (0.97 + R.random() * 0.05)
            if y0 + 4 < N:
                img[y0 + 4, :] = line                          # the shadow under each plank
            img[y0, :] = img[y0, :] * 1.08                     # light catching the plank's lip
        for x in range(0, N, 128):
            img[:, x:x + 2] = hexc(S['trim']) * 0.9            # corner boards
    else:
        for x0 in range(0, N, 32):
            c = walls[(x0 // 32) % len(walls)]
            img[:, x0:x0 + 32] = c
            img[:, x0] = line
        img[N // 2, :] = line
    # soft, large-scale variation and grime toward the street
    v = noise(rng, N, 6) - 0.5
    img *= (1.0 + v[..., None] * 0.1)
    if not wins:
        # a plain tile: grime comes from the mesh (darker toward the ground), so none baked in
        return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), 'RGB')
    grime = np.linspace(0, 1, N)[:, None] ** 2
    img *= (1.0 - grime[..., None] * 0.22)
    trim = hexc(S['trim'])
    lintel = hexc(S['lintel'])
    for (x, y, ww, hh) in windows(style):
        # ambient shadow around the opening
        for k in range(1, 5):
            a = 0.12 * (5 - k) / 4
            img[max(0, y - k - 4):y + hh + 3 + k, max(0, x - 3 - k):x + ww + 3 + k] *= (1 - a * 0.35)
        # lintel / header
        if kind in ('brick',):
            # a soldier course of upright bricks
            for bx in range(x - 4, x + ww + 4, 4):
                c = lintel * (0.92 + R.random() * 0.16)
                img[y - 8:y - 2, bx:bx + 3] = c
                img[y - 8:y - 2, bx + 3] = line
            img[y - 9, x - 4:x + ww + 4] = line
            img[y - 2, x - 4:x + ww + 4] = line
        else:
            img[y - 6:y - 2, x - 4:x + ww + 4] = lintel
            img[y - 7, x - 4:x + ww + 4] = line
        # frame
        img[y - 2:y + hh + 1, x - 2:x + ww + 2] = trim if style != 'ware' else trim
        # glass: sky reflection at the top fading to a dark interior, a diagonal glint
        gy = np.linspace(0, 1, hh)[:, None]
        sky = hexc('#9fb9d6') * (1 - gy) + hexc('#1a2533') * gy
        sky = sky * 0.55 + hexc('#0e1621') * 0.45
        img[y:y + hh, x:x + ww] = sky[:, None, :] * np.ones((1, ww, 1))
        for k in range(ww):
            yy = int(hh * 0.15 + k * 0.6)
            if 0 <= yy < hh - 2:
                img[y + yy:y + yy + 2, x + k] = img[y + yy:y + yy + 2, x + k] * 0.5 + 255 * 0.5 * 0.55
        # what's inside: curtains or blinds in some
        pick = R.random()
        if pick < 0.25 and style != 'ware':
            side = R.choice([0, 1])
            cw = ww // 2 - 2
            cc = hexc(R.choice(['#7a3b2f', '#3f5a73', '#7a6a4a', '#4a5a3a', '#6a4a6a']))
            xs = x + (1 if side == 0 else ww - cw - 1)
            img[y + 2:y + hh - 2, xs:xs + cw] = img[y + 2:y + hh - 2, xs:xs + cw] * 0.35 + cc * 0.65
        elif pick < 0.45:
            for yy in range(y + 2, y + hh - 1, 3):
                img[yy, x:x + ww] = img[yy, x:x + ww] * 0.5 + hexc('#c9c4b8') * 0.5
        # mullions
        if style == 'ware':
            for k in range(1, 4):
                img[y:y + hh, x + k * ww // 4] = line
            img[y + hh // 2, x:x + ww] = line
        else:
            img[y:y + hh, x + ww // 2 - 1:x + ww // 2 + 1] = trim * 0.85
            img[y + hh // 2, x:x + ww] = trim * 0.85
        # frame outline (the ink line)
        img[y - 2, x - 2:x + ww + 2] = line
        img[y + hh, x - 2:x + ww + 2] = line
        img[y - 2:y + hh + 1, x - 2] = line
        img[y - 2:y + hh + 1, x + ww + 1] = line
        # sill with snow on it, and its shadow
        img[y + hh + 1:y + hh + 3, x - 4:x + ww + 4] = hexc('#f2f6fb')
        img[y + hh + 3, x - 4:x + ww + 4] = hexc('#c9d3de')
        img[y + hh + 4:y + hh + 6, x - 4:x + ww + 4] *= 0.6
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), 'RGB')


for style in STYLE:
    save(facade(style, 1000 + sum(map(ord, style)), wins=False), 'wall_%s' % style)


# ---------- signs: 1024 x 1024. Left half: 16 shop signs, 512 x 64 each (made-up, generic
# names of the kinds of shops on a South Side commercial strip, no real businesses). Right
# half: street signs in 128 px cells ----------
from PIL import ImageFont
FONT = os.path.join(ROOT, 'godot', 'fonts')
SHOPS = [('FOOD & LIQUOR', '#b3121a', '#ffffff'), ('CURRENCY EXCHANGE', '#0f2f6e', '#ffd84a'), ('BEAUTY SUPPLY', '#e0218a', '#ffffff'),
         ('FISH & CHICKEN', '#f2c11a', '#b3121a'), ('TAQUERIA', '#1f7a3a', '#ffffff'), ('LAUNDROMAT', '#2a8fd6', '#ffffff'),
         ('CELL PHONES', '#111111', '#3af06a'), ('TAX SERVICE', '#ffffff', '#1a3a8a'), ('BARBER SHOP', '#1c1c1c', '#ff4040'),
         ('DOLLAR PLUS', '#2b9a3a', '#ffe94a'), ('PAWN & GOLD', '#1a1208', '#f2c14a'), ('WINGS & FRIES', '#d8461a', '#fff4d0'),
         ('GOOD NEWS CHURCH', '#f2efe6', '#3a2a6a'), ('AUTO PARTS', '#123a7a', '#ffffff'), ('NAILS & SPA', '#7a2a6a', '#ffd6f0'),
         ('GROCERY · DELI', '#0e5a52', '#ffffff')]


def shop_sign(name, bg, fg):
    im = Image.new('RGB', (512, 64), bg)
    d = ImageDraw.Draw(im)
    f = ImageFont.truetype(os.path.join(FONT, 'Inter-Bold.ttf'), 40)
    while d.textlength(name, font=f) > 470:
        f = ImageFont.truetype(os.path.join(FONT, 'Inter-Bold.ttf'), f.size - 2)
    tw = d.textlength(name, font=f)
    d.rectangle([3, 3, 508, 60], outline=fg, width=2)
    d.text(((512 - tw) / 2, 32), name, font=f, fill=fg, anchor='lm')
    return im


def street_signs():
    im = Image.new('RGBA', (512, 1024), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    fb = os.path.join(FONT, 'Inter-Bold.ttf')
    # stop: a red octagon, white border, STOP
    c = 64
    pts = [(c + 60 * math.cos(math.radians(22.5 + 45 * k)), c + 60 * math.sin(math.radians(22.5 + 45 * k))) for k in range(8)]
    d.polygon(pts, fill='#ffffff')
    pts2 = [(c + 54 * math.cos(math.radians(22.5 + 45 * k)), c + 54 * math.sin(math.radians(22.5 + 45 * k))) for k in range(8)]
    d.polygon(pts2, fill='#c4161c')
    d.text((c, c + 2), 'STOP', font=ImageFont.truetype(fb, 34), fill='#ffffff', anchor='mm')
    # bus stop (made-up transit): blue square, white bus pictogram-ish and BUS
    d.rounded_rectangle([132, 4, 252, 124], 10, fill='#1d4fa8')
    d.rounded_rectangle([156, 26, 228, 76], 8, fill='#ffffff')
    d.rectangle([162, 34, 222, 52], fill='#1d4fa8')
    d.ellipse([164, 70, 178, 84], fill='#ffffff'); d.ellipse([206, 70, 220, 84], fill='#ffffff')
    d.text((192, 104), 'BUS', font=ImageFont.truetype(fb, 22), fill='#ffffff', anchor='mm')
    # no parking: white, red ring and slash over a P
    d.rectangle([260, 4, 380, 124], fill='#f4f4f0')
    d.ellipse([272, 16, 368, 112], outline='#c4161c', width=9)
    d.text((320, 66), 'P', font=ImageFont.truetype(fb, 54), fill='#111111', anchor='mm')
    d.line([(290, 34), (350, 94)], fill='#c4161c', width=9)
    # one way: black with a white arrow (2:1 in a 128 x 64 cell)
    d.rectangle([388, 32, 508, 92], fill='#111111')
    d.polygon([(398, 56), (478, 56), (478, 46), (500, 62), (478, 78), (478, 68), (398, 68)], fill='#ffffff')
    d.text((438, 62), 'ONE WAY', font=ImageFont.truetype(fb, 11), fill='#111111', anchor='mm')
    # a street-name blade: green, white letters left blank (the names are in the HUD)
    d.rounded_rectangle([4, 136, 252, 176], 6, fill='#1f6b3a', outline='#ffffff', width=3)
    return im


atlas = Image.new('RGBA', (1024, 1024), (0, 0, 0, 255))
for i, (n, bg, fg) in enumerate(SHOPS):
    atlas.paste(shop_sign(n, bg, fg), (0, i * 64))
atlas.paste(street_signs(), (512, 0))
atlas.save(os.path.join(OUT, 'signs.png'), optimize=True)
print('signs.png')

# ---------- road: u along the road, v across ----------
rng = np.random.default_rng(7)
R = random.Random(7)
road = np.ones((N, N, 3)) * hexc('#3b4048')
road *= (1.0 + (noise(rng, N, 16) - 0.5)[..., None] * 0.08)
agg = rng.random((N, N)) < 0.06
road[agg] *= 1.18
# slush tracks: two per lane, lighter dirty grey-blue, soft edges
v = np.arange(N)
for c in (52, 88, 168, 204):
    band = np.exp(-((v - c) / 9.0) ** 2)[:, None]
    road = road * (1 - band[..., None] * 0.45) + hexc('#8e9aa8')[None, None, :] * band[..., None] * 0.45
# centre: double yellow dashes
for x0 in range(0, N, 32):
    road[124:127, x0:x0 + 18] = hexc('#e2b23a')
    road[130:133, x0:x0 + 18] = hexc('#e2b23a')
# snow banks at the kerbs, with a crisp edge
for y in range(0, 14):
    k = 1.0 - y / 14.0
    road[y] = road[y] * (1 - k) + hexc('#eef3f9') * k
    road[N - 1 - y] = road[N - 1 - y] * (1 - k) + hexc('#eef3f9') * k
road[14] *= 0.8
road[N - 15] *= 0.8
save(Image.fromarray(np.clip(road, 0, 255).astype(np.uint8), 'RGB'), 'road')

# ---------- sidewalk: 128 px, slabs with joints, snow dust and salt ----------
M = 128
rng = np.random.default_rng(11)
walk = np.ones((M, M, 3)) * hexc('#a9b2bc')
walk *= (1.0 + (noise(rng, M, 8) - 0.5)[..., None] * 0.08)
for a in (0, 64):
    walk[a:a + 2, :] = hexc('#6d7680')
    walk[:, a:a + 2] = hexc('#6d7680')
snow = noise(rng, M, 6)
mask = np.clip((snow - 0.55) * 4, 0, 1)
walk = walk * (1 - mask[..., None]) + hexc('#eef3f9') * mask[..., None]
salt = rng.random((M, M)) < 0.03
walk[salt] = hexc('#dfe4ea')
save(Image.fromarray(np.clip(walk, 0, 255).astype(np.uint8), 'RGB'), 'walk')
print('city textures done')
