#!/usr/bin/env python3
"""Paints the phone and the wardrobe art into godot/assets/ui/.

The phone is a modern flagship seen from the front (a big "Pro Max" style slab): a thin
aluminium edge with its side buttons, an even black border around the screen, the small
pill-shaped camera island, and a soft shadow under it. The edge is painted in grey so the game
can tint it to the colour picked in Settings (silver, black, burgundy, glacier).

  phone_front.png   shadow, black border and the island (drawn over the screen)
  phone_edge.png    the aluminium edge and buttons, in grey (tinted in the game)
  wallpaper.png     the home screen: glacier blue, violet and a warm street-light glow
  icon_<app>.png    the 12 app icons (rounded squares with a white glyph)
  wardrobe_bg.png   the wardrobe backdrop: a soft spotlight on dark grey
  floor_shadow.png  the soft round shadow under the character in the wardrobe

The geometry (in UI pixels) must match Phone.gd. Everything is painted at 2x.
Usage: python3 tools/make-ui.py    (needs numpy and Pillow)
"""
import os, math, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
OUT = os.path.join(ROOT, 'godot', 'assets', 'ui')
FONTS = os.path.join(ROOT, 'godot', 'fonts')
os.makedirs(OUT, exist_ok=True)

S = 2                      # texture pixels per UI pixel
W, H = 334, 696            # the phone body
R0 = 58                    # outer corner radius
RING = 4.5                 # visible aluminium edge
BEZEL = 5.5                # black border around the screen
PAD = 4                    # room for the side buttons
M = 36                     # room for the shadow
INSET = RING + BEZEL       # 10: the screen starts here
SW, SH = int(W - 2 * INSET), int(H - 2 * INSET)     # 314 x 676
ISL_W, ISL_H, ISL_Y = 72, 24, 9           # the island, from the top of the screen
CW, CH = W + 2 * PAD + 2 * M, H + 2 * M   # the canvas: 414 x 768


def save(im, name):
    p = os.path.join(OUT, name + '.png')
    im.save(p, optimize=True)
    print('%-16s %4d KB  %dx%d' % (name, os.path.getsize(p) // 1024, im.size[0], im.size[1]))


def hexc(h):
    h = h.lstrip('#')
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], float) / 255.0


def rrect_sdf(px, py, cx, cy, hw, hh, r):
    qx = np.abs(px - cx) - (hw - r)
    qy = np.abs(py - cy) - (hh - r)
    ox = np.maximum(qx, 0)
    oy = np.maximum(qy, 0)
    return np.sqrt(ox * ox + oy * oy) + np.minimum(np.maximum(qx, qy), 0) - r


def cover(d, aa):
    """0..1 coverage of the inside (d < 0) with an antialiased edge aa UI px wide"""
    return np.clip(0.5 - d / aa, 0, 1)


# ---------------------------------------------------------------- the phone
def phone():
    k = 2                                  # supersampling on top of S
    n = S * k
    ys, xs = np.mgrid[0:CH * n, 0:CW * n].astype(np.float32)
    px = (xs + 0.5) / n
    py = (ys + 0.5) / n
    cx, cy = M + PAD + W / 2, M + H / 2
    d = rrect_sdf(px, py, cx, cy, W / 2, H / 2, R0)
    aa = 1.0 / S
    # outward normal of the body outline, for the light on the edge
    gy, gx = np.gradient(d)
    gl = np.sqrt(gx * gx + gy * gy) + 1e-6
    nx, ny = gx / gl, gy / gl
    L = np.array([-0.55, -0.83])
    lam = nx * L[0] + ny * L[1]            # -1..1: facing the light (top-left) or away

    # --- edge (grey, tinted in the game)
    t = np.clip(-d / RING, 0, 1)           # 0 outer rim .. 1 where the glass starts
    prof = 0.62 + 0.30 * np.maximum(np.sin(np.clip(t, 0, 1) * math.pi), 0) ** 0.7   # rounded: bright in the middle
    prof -= 0.18 * np.exp(-((t - 0.97) / 0.06) ** 2)                # a dark step down to the glass
    shade = prof + 0.16 * lam
    spec = np.exp(-((t - 0.38) / 0.10) ** 2) * np.clip(lam, 0, 1) ** 3 * 0.35
    edge_v = np.clip(shade + spec, 0, 1)
    edge_a = cover(d, aa) * cover(-(d + RING + 0.5), aa)            # the band, overlapping the border a little

    # --- side buttons: (side, y0, y1, protrusion)
    btn_v = np.zeros_like(d)
    btn_a = np.zeros_like(d)
    for side, y0, y1, pr in [(-1, 126, 152, 2.6), (-1, 174, 222, 2.8), (-1, 236, 284, 2.8), (1, 192, 276, 2.8), (1, 398, 446, 1.8)]:
        bx = cx + side * (W / 2 + pr / 2 - 1.2)
        bd = rrect_sdf(px, py, bx, (y0 + y1) / 2 + M, pr / 2 + 1.2, (y1 - y0) / 2, 1.6)
        a = cover(bd, aa) * (d > -0.5)
        # light from the top-left: lighter on the top end, a highlight line along the length
        ty = np.clip((py - M - y0) / max(1, (y1 - y0)), 0, 1)
        v = 0.66 + 0.22 * (1 - ty) + 0.12 * (1 if side < 0 else -0.3)
        if pr < 2:
            v = v * 0.55 + 0.05                                    # the flush camera button is darker glass
        btn_v = np.where(a > btn_a, v, btn_v)
        btn_a = np.maximum(btn_a, a)
    ev = edge_v * edge_a + btn_v * btn_a * (1 - edge_a)
    ea = np.maximum(edge_a, btn_a)
    rgb = np.repeat((np.where(ea > 0, ev / np.maximum(ea, 1e-6), 0))[..., None], 3, 2)
    edge = np.dstack([rgb, ea[..., None]])

    # --- front: shadow, border, island
    body = cover(d, aa)
    sh = Image.fromarray((body * 255).astype(np.uint8))
    sh = sh.filter(ImageFilter.GaussianBlur(18 * n))
    sh = np.asarray(sh).astype(np.float32) / 255.0
    sh = np.roll(sh, int(12 * n), axis=0) * 0.62
    sh = sh * (1 - body)                                            # nothing over the body itself
    border_a = cover(d + RING - 0.6, aa) * (1 - cover(d + INSET, aa))
    border_v = np.full_like(d, 0.018)
    # a hint of glass at the outer edge of the border
    border_v += 0.07 * np.exp(-((d + RING) / 0.7) ** 2) * np.clip(0.5 + lam, 0, 1)
    sx0 = M + PAD + INSET
    sy0 = M + INSET
    icx = sx0 + SW / 2
    icy = sy0 + ISL_Y + ISL_H / 2
    idd = rrect_sdf(px, py, icx, icy, ISL_W / 2, ISL_H / 2, ISL_H / 2)
    isl_a = cover(idd, aa)
    isl_v = np.full_like(d, 0.0)
    # the front camera inside the island: a dark lens with a soft blue glint
    lx, ly = icx + ISL_W / 2 - ISL_H / 2 - 1, icy
    ld = np.sqrt((px - lx) ** 2 + (py - ly) ** 2)
    lens = cover(ld - 6.2, aa)
    glint = np.exp(-(((px - lx + 1.6) ** 2 + (py - ly + 1.8) ** 2) / 1.6))
    a = np.maximum(border_a, isl_a)
    a = np.maximum(a, sh)
    col = np.zeros(d.shape + (3,), np.float32)
    col[:] = 0.0
    bv = border_v[..., None]
    col = np.where((border_a > 0)[..., None], bv, col)
    lens_c = hexc('#0b0f1a') * 1.0
    col = np.where((isl_a > 0)[..., None], col * (1 - isl_a[..., None]), col)
    col = col + (lens * isl_a)[..., None] * lens_c[None, None, :] + (glint * lens * 0.35)[..., None] * hexc('#5a78b4')[None, None, :]
    front = np.dstack([np.clip(col, 0, 1), np.clip(a, 0, 1)[..., None]])

    def down(arr):
        im = Image.fromarray((np.clip(np.nan_to_num(arr), 0, 1) * 255).astype(np.uint8), 'RGBA')
        return im.resize((CW * S, CH * S), Image.LANCZOS)
    save(down(edge), 'phone_edge')
    save(down(front), 'phone_front')


# ---------------------------------------------------------------- the wallpaper
def wallpaper():
    w, h = SW * S, SH * S
    rng = np.random.default_rng(18)
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    u = xs / w
    v = ys / h
    top, bot = hexc('#040817'), hexc('#0b2240')
    img = top * (1 - v[..., None]) + bot * v[..., None]

    def blob(cx, cy, r, c, a):
        dd = ((u - cx) * (w / h)) ** 2 + (v - cy) ** 2
        g = np.exp(-dd / (r * r) * 2.2)[..., None]
        return g * hexc(c) * a
    img = img + blob(0.86, 0.22, 0.42, '#3aa0ff', 0.75)
    img = img + blob(0.08, 0.46, 0.36, '#6b3dff', 0.62)
    img = img + blob(0.72, 0.70, 0.30, '#22d3c5', 0.36)
    img = img + blob(0.26, 0.98, 0.40, '#ff8a3d', 0.85)
    img = img + blob(0.95, 1.02, 0.25, '#ff4f7a', 0.45)
    # two soft ribbons of light, like curved glass
    for (y0, amp, f, ph, wd, a) in [(0.56, 0.07, 5.2, 0.6, 0.018, 0.22), (0.62, 0.05, 4.1, 2.1, 0.03, 0.12)]:
        cyv = y0 + amp * np.sin(u * f + ph)
        band = np.exp(-((v - cyv) / wd) ** 2)
        img = img + band[..., None] * np.array([0.75, 0.88, 1.0]) * a
    img = 1 - np.exp(-img * 1.25)          # soft tone curve, nothing clips
    img *= (1 - 0.25 * np.clip(1 - v / 0.18, 0, 1))[..., None]      # darker under the status bar
    img += (rng.random((h, w, 1)) - 0.5) * 0.018
    im = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8), 'RGB')
    im = im.filter(ImageFilter.GaussianBlur(1.2))
    # a light dusting of snow
    dr = ImageDraw.Draw(im, 'RGBA')
    R = random.Random(5)
    for _ in range(140):
        x, y = R.random() * w, R.random() * h
        r = R.choice([1, 1, 1.5, 2, 2.5])
        dr.ellipse((x - r, y - r, x + r, y + r), fill=(255, 255, 255, R.randint(40, 120)))
    save(im, 'wallpaper')


# ---------------------------------------------------------------- the icons
N4 = 512
WHITE = (255, 255, 255, 255)


def squircle_mask(n):
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float32)
    x = (xs + 0.5) / n * 2 - 1
    y = (ys + 0.5) / n * 2 - 1
    e = 5.0
    val = np.abs(x) ** e + np.abs(y) ** e
    return np.clip((1 - val) * n / 6, 0, 1)


def icon(name, c1, c2, draw_glyph):
    ys = np.linspace(0, 1, N4)[:, None, None]
    grad = hexc(c1) * (1 - ys) + hexc(c2) * ys
    grad = np.repeat(grad, N4, 1)
    base = Image.fromarray((grad * 255).astype(np.uint8), 'RGB').convert('RGBA')
    g = Image.new('RGBA', (N4, N4), (0, 0, 0, 0))
    dr = ImageDraw.Draw(g)
    draw_glyph(dr, g)
    # a soft shadow under the glyph
    sha = g.split()[3].filter(ImageFilter.GaussianBlur(10))
    shadow = Image.new('RGBA', (N4, N4), (0, 0, 0, 0))
    shadow.putalpha(sha.point(lambda a: int(a * 0.22)))
    shadow = shadow.transform(shadow.size, Image.AFFINE, (1, 0, 0, 0, 1, -8))
    base = Image.alpha_composite(base, shadow)
    base = Image.alpha_composite(base, g)
    # a faint top sheen
    sheen = np.zeros((N4, N4, 4), np.uint8)
    sheen[..., :3] = 255
    sheen[..., 3] = (np.clip(1 - np.linspace(0, 1, N4) / 0.5, 0, 1) * 26).astype(np.uint8)[:, None]
    base = Image.alpha_composite(base, Image.fromarray(sheen, 'RGBA'))
    m = squircle_mask(N4)
    a = (np.asarray(base.split()[3]).astype(np.float32) / 255.0) * m
    base.putalpha(Image.fromarray((a * 255).astype(np.uint8)))
    save(base.resize((128, 128), Image.LANCZOS), 'icon_' + name)


def g_msgs(dr, g):
    dr.ellipse((92, 118, 420, 372), fill=WHITE)
    dr.polygon([(150, 330), (118, 410), (230, 352)], fill=WHITE)


def g_map(dr, g):
    pan = [((112, 150), (204, 118), (204, 362), (112, 394)), ((204, 118), (308, 150), (308, 394), (204, 362)), ((308, 150), (400, 118), (400, 362), (308, 394))]
    for i, p in enumerate(pan):
        dr.polygon(p, fill=(255, 255, 255, 255 if i != 1 else 225))
    dr.line([(140, 300), (200, 250), (260, 280), (372, 200)], fill=(10, 132, 255, 255), width=16, joint='curve')
    dr.ellipse((300, 150, 380, 230), fill=(255, 69, 58, 255))
    dr.polygon([(306, 205), (374, 205), (340, 262)], fill=(255, 69, 58, 255))
    dr.ellipse((325, 175, 355, 205), fill=WHITE)


def g_jobs(dr, g):
    dr.rounded_rectangle((184, 120, 328, 196), 26, outline=WHITE, width=24)
    dr.rounded_rectangle((100, 176, 412, 392), 40, fill=WHITE)
    dr.rectangle((100, 262, 412, 278), fill=(255, 140, 20, 255))
    dr.rounded_rectangle((232, 246, 280, 296), 10, fill=WHITE)


def g_blok(dr, g):
    f = ImageFont.truetype(os.path.join(FONTS, 'Inter-Bold.ttf'), 330)
    dr.text((256, 262), 'b', font=f, fill=WHITE, anchor='mm')
    dr.ellipse((356, 116, 404, 164), fill=WHITE)


def g_camera(dr, g):
    dr.rounded_rectangle((96, 168, 416, 388), 46, fill=(28, 28, 30, 255))
    dr.rounded_rectangle((196, 132, 316, 186), 18, fill=(28, 28, 30, 255))
    dr.ellipse((176, 198, 336, 358), fill=(72, 72, 76, 255))
    dr.ellipse((200, 222, 312, 334), fill=(10, 10, 14, 255))
    dr.ellipse((226, 240, 262, 276), fill=(90, 110, 150, 200))
    dr.ellipse((350, 198, 378, 226), fill=(255, 214, 10, 255))


def g_gang(dr, g):
    for (x, s, a) in [(160, 0.78, 200), (352, 0.78, 200), (256, 1.0, 255)]:
        hr = 52 * s
        hy = 200 - (1 - s) * -20
        dr.ellipse((x - hr, hy - hr, x + hr, hy + hr), fill=(255, 255, 255, a))
        bw = 96 * s
        dr.rounded_rectangle((x - bw, hy + hr + 14, x + bw, hy + hr + 14 + 150 * s), int(70 * s), fill=(255, 255, 255, a))


def g_garage(dr, g):
    dr.polygon([(150, 238), (196, 168), (316, 168), (362, 238)], fill=WHITE)
    dr.rounded_rectangle((90, 230, 422, 330), 36, fill=WHITE)
    dr.polygon([(206, 186), (250, 186), (250, 232), (176, 232)], fill=(15, 150, 140, 255))
    dr.polygon([(262, 186), (306, 186), (336, 232), (262, 232)], fill=(15, 150, 140, 255))
    for x in (168, 344):
        dr.ellipse((x - 44, 288, x + 44, 376), fill=(20, 40, 45, 255))
        dr.ellipse((x - 18, 314, x + 18, 350), fill=(200, 210, 215, 255))


def g_wardrobe(dr, g):
    dr.arc((222, 96, 290, 164), 200, 90, fill=WHITE, width=20)
    dr.line([(256, 162), (256, 196)], fill=WHITE, width=20)
    dr.line([(256, 196), (96, 330), (416, 330), (256, 196)], fill=WHITE, width=24, joint='curve')
    dr.rounded_rectangle((88, 318, 424, 346), 14, fill=WHITE)


def g_online(dr, g):
    dr.ellipse((106, 106, 406, 406), outline=WHITE, width=24)
    dr.ellipse((196, 106, 316, 406), outline=WHITE, width=20)
    dr.line([(256, 110), (256, 402)], fill=WHITE, width=20)
    dr.line([(112, 256), (400, 256)], fill=WHITE, width=20)
    dr.arc((126, 90, 386, 230), 20, 160, fill=WHITE, width=18)
    dr.arc((126, 282, 386, 422), 200, 340, fill=WHITE, width=18)


def g_settings(dr, g):
    c = 256
    for i in range(10):
        a = i * math.pi * 2 / 10
        pts = []
        for (r, da) in [(118, -0.17), (158, -0.11), (158, 0.11), (118, 0.17)]:
            pts.append((c + math.cos(a + da) * r, c + math.sin(a + da) * r))
        dr.polygon(pts, fill=WHITE)
    dr.ellipse((c - 126, c - 126, c + 126, c + 126), fill=WHITE)
    dr.ellipse((c - 58, c - 58, c + 58, c + 58), fill=(120, 120, 126, 255))
    dr.ellipse((c - 92, c - 92, c + 92, c + 92), outline=(120, 120, 126, 255), width=10)


def g_pad(dr, g):
    dk = (40, 30, 0, 255)
    dr.rounded_rectangle((92, 176, 420, 340), 82, fill=dk)
    dr.ellipse((92, 236, 210, 384), fill=dk)
    dr.ellipse((302, 236, 420, 384), fill=dk)
    y = (255, 214, 10, 255)
    dr.rectangle((150, 236, 172, 304), fill=y)
    dr.rectangle((127, 259, 195, 281), fill=y)
    for (x, yy) in [(334, 238), (370, 270), (334, 302), (298, 270)]:
        dr.ellipse((x - 14, yy - 14, x + 14, yy + 14), fill=y)


def g_stats(dr, g):
    for i, hgt in enumerate([110, 170, 140, 240]):
        x = 116 + i * 76
        dr.rounded_rectangle((x, 392 - hgt, x + 52, 392), 18, fill=WHITE)
    dr.line([(110, 398), (404, 398)], fill=(255, 255, 255, 140), width=10)


ICONS = [
    ('map', '#5ac8fa', '#0a6cff', g_map), ('msgs', '#6fe27a', '#22b04a', g_msgs), ('jobs', '#ffbb3c', '#ff7a00', g_jobs),
    ('blok', '#ff5e9c', '#8f3cff', g_blok), ('camera', '#e5e5ea', '#8e8e93', g_camera), ('gang', '#ff6e5e', '#c81e1e', g_gang),
    ('garage', '#3ad8c8', '#0a8f86', g_garage), ('style', '#d6aaff', '#7c43f2', g_wardrobe), ('online', '#7f7cff', '#3330a8', g_online),
    ('settings', '#b0b0b6', '#5c5c62', g_settings), ('pad', '#ffe45c', '#ffb300', g_pad), ('stats', '#5fd4ff', '#0a7aff', g_stats),
]


# ---------------------------------------------------------------- the wardrobe
def wardrobe():
    w, h = 1280, 720
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    u, v = xs / w, ys / h
    dd = ((u - 0.6) * 1.6) ** 2 + ((v - 0.42) * 1.0) ** 2
    spot = np.exp(-dd * 2.4)
    img = hexc('#0b0c0f') * (1 - spot[..., None]) + hexc('#2a2a2e') * spot[..., None]
    floor = np.clip((v - 0.62) / 0.38, 0, 1)
    img = img * (1 - floor[..., None] * 0.35)
    img += (np.random.default_rng(3).random((h, w, 1)) - 0.5) * 0.012
    save(Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8), 'RGB'), 'wardrobe_bg')
    n = 256
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float32)
    r = np.sqrt(((xs + 0.5) / n * 2 - 1) ** 2 + ((ys + 0.5) / n * 2 - 1) ** 2)
    a = np.clip(1 - r, 0, 1) ** 1.6 * 0.75
    im = np.zeros((n, n, 4), np.uint8)
    im[..., 3] = (a * 255).astype(np.uint8)
    save(Image.fromarray(im, 'RGBA'), 'floor_shadow')


# ---------------------------------------------------------------- the gun shop's sign
def sign_gunshop():
    w, h = 1024, 181
    im = Image.new('RGBA', (w, h), (22, 22, 26, 255))
    glow = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    dr = ImageDraw.Draw(glow)
    f = ImageFont.truetype(os.path.join(FONTS, 'Inter-Bold.ttf'), 92)
    fs = ImageFont.truetype(os.path.join(FONTS, 'Inter-SemiBold.ttf'), 26)
    dr.text((w // 2, 72), 'IRONSIDE ARMS', font=f, fill=(255, 70, 60, 255), anchor='mm')
    blur = glow.filter(ImageFilter.GaussianBlur(10))
    im = Image.alpha_composite(im, blur)
    im = Image.alpha_composite(im, blur)
    d2 = ImageDraw.Draw(im)
    d2.text((w // 2, 72), 'IRONSIDE ARMS', font=f, fill=(255, 214, 205, 255), anchor='mm')
    d2.text((w // 2, 146), 'GUNS  ·  AMMO  ·  REPAIRS  ·  CALDER AVE', font=fs, fill=(220, 220, 225, 255), anchor='mm')
    d2.rectangle((6, 6, w - 7, h - 7), outline=(90, 90, 96, 255), width=3)
    save(im, 'sign_gunshop')


phone()
sign_gunshop()
wallpaper()
for (nm, c1, c2, fn) in ICONS:
    icon(nm, c1, c2, fn)
wardrobe()
print('ui art done')
