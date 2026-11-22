#!/usr/bin/env python3
"""Paints the textures of the memorial garden (Godot) into godot/assets/art/.

The mausoleum is modelled on the photo of XXXTentacion's real mausoleum that his family
shared; the Poison Tree stands beside it. No faces, no logos, no lyrics.

  granite.png / granite_n.png      grey granite panels with fine joints (tileable, 2 x 2 m)
  pediment.png / pediment_n.png    the tympanum, "XXXTENTACION / JAHSEH D. ONFROY" cut into it
  grille.png                       the bronze scrollwork over the door glass (alpha)
  headstone.png                    the crypt plate inside (black granite, gold letters)
  plaque.png                       the Poison Tree plaque, with the tree emblem in gold
  arch.png                         the gold lettering on the iron arch over the gate (alpha)
  ribbon.png                       the satin sash across the rose spray
  bark.png / bark_n.png / bark_glow.png   the Poison Tree's bark and its glowing veins
  palm_frond.png / palm_trunk.png  royal palm fronds (alpha) and the ringed trunk
  grass.png / grass_card.png       the lawn (tileable) and grass tufts (alpha)
  mulch.png / pavers.png / hedge.png   red mulch, travertine pavers, boxwood
  leaf.png / silver_leaf.png / petal.png   rose leaves, dusty miller, a rose petal (alpha)
  wing.png / glow.png              a feathered wing and a soft glow (alpha, for the light)

Usage: python3 tools/make-memorial.py    (needs numpy and Pillow)
"""
import os, math, random
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
ART = os.path.join(ROOT, 'godot', 'assets', 'art')
os.makedirs(ART, exist_ok=True)
SERIF = '/usr/share/fonts/truetype/liberation/LiberationSerif-Regular.ttf'
SERIF_B = '/usr/share/fonts/truetype/liberation/LiberationSerif-Bold.ttf'
if not os.path.exists(SERIF):
    SERIF = SERIF_B = '/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf'
rnd = random.Random(1998)
rng = np.random.default_rng(1998)


def save(im, name):
    im.save(os.path.join(ART, name), optimize=True)
    print('%-16s %4d KB' % (name, os.path.getsize(os.path.join(ART, name)) // 1024))


def lerp(a, b, t): return a + (b - a) * t
def mix(c1, c2, t): return tuple(int(lerp(c1[i], c2[i], t)) for i in range(len(c1)))


def value_noise(n, f):
    g = rng.random((f, f))
    x = np.arange(n) * f / n
    i = np.floor(x).astype(int); t = x - i
    t = t * t * (3 - 2 * t)
    i0, i1 = i % f, (i + 1) % f
    a, b, c, d = g[np.ix_(i0, i0)], g[np.ix_(i0, i1)], g[np.ix_(i1, i0)], g[np.ix_(i1, i1)]
    ty, tx = t[:, None], t[None, :]
    return (a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty


def fbm(n, freqs):
    out = np.zeros((n, n)); w = 1.0; tot = 0
    for f in freqs:
        out += value_noise(n, f) * w; tot += w; w *= 0.55
    out /= tot
    return (out - out.min()) / (out.max() - out.min() + 1e-9)


def normal_map(h, strength):
    """h: float array (0..1), higher = closer to the viewer. Tileable differences."""
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
    n = np.stack([-dx, dy, np.ones_like(h)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8), 'RGB')


def rgb(a):
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), 'RGB')


def rgba(a):
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), 'RGBA')


# ---------------------------------------------------------------- granite
def granite_base(n, base, spread=1.0):
    a = np.ones((n, n, 3)) * np.array(base, float)
    a += (fbm(n, [4, 8, 16]) - 0.5)[..., None] * 18 * spread
    # speckles: black mica, white quartz, grey feldspar
    for count, val, sz in [(n * n // 9, -70, 1), (n * n // 14, 45, 1), (n * n // 30, -40, 2), (n * n // 60, 60, 2)]:
        ys = rng.integers(0, n, count); xs = rng.integers(0, n, count); k = rng.uniform(0.5, 1.0, count)[:, None]
        for dy in range(sz):
            for dx in range(sz):
                a[(ys + dy) % n, (xs + dx) % n] += val * spread * k
    return a


N = 512
g = granite_base(N, (166, 166, 170))
# panel joints: the texture spans 2 x 2 m; panels 1 m wide, rows offset by half a panel
h = np.ones((N, N)) * 0.6 + fbm(N, [32, 64]) * 0.04
joint = np.zeros((N, N), bool)
for y in (0, N // 2):
    joint[max(0, y - 1):y + 2, :] = True
for (y0, y1, xs) in [(0, N // 2, (0, N // 2)), (N // 2, N, (N // 4, 3 * N // 4))]:
    for x in xs:
        joint[y0:y1, max(0, x - 1):x + 2] = True
g[joint] = g[joint] * 0.62
h[joint] = 0.2
save(rgb(g), 'granite.png')
save(normal_map(np.array(Image.fromarray((h * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2))) / 255.0, 6.0), 'granite_n.png')
gp = granite_base(256, (166, 166, 170))

# ---------------------------------------------------------------- pediment (tympanum)
PW, PH = 2048, 600
ped = Image.new('RGB', (PW, PH))
for y in range(0, PH, 256):
    for x in range(0, PW, 256):
        ped.paste(rgb(gp), (x, y))
hmap = Image.new('L', (PW, PH), 160)
pd = ImageDraw.Draw(ped); hd = ImageDraw.Draw(hmap)


def carve(text, font_path, size, cy, track=0):
    f = ImageFont.truetype(font_path, size)
    widths = [pd.textlength(ch, font=f) for ch in text]
    x = (PW - sum(widths) - track * (len(text) - 1)) / 2
    for ch, w in zip(text, widths):
        # a cut letter: light lower-right lip, shadowed upper-left wall, dark floor
        pd.text((x + 3, cy + 3), ch, font=f, fill=(214, 214, 218))
        pd.text((x - 1, cy - 1), ch, font=f, fill=(44, 44, 50))
        pd.text((x, cy), ch, font=f, fill=(62, 62, 68))
        hd.text((x, cy), ch, font=f, fill=40)
        x += w + track


inset = 40
tri = [(inset * 2.1, PH - inset * 0.9), (PW / 2, inset * 1.3), (PW - inset * 2.1, PH - inset * 0.9)]
pd.line(tri + [tri[0]], fill=(104, 104, 110), width=7)
pd.line([(p[0] + 4, p[1] + 4) for p in tri + [tri[0]]], fill=(206, 206, 210), width=3)
hd.line(tri + [tri[0]], fill=60, width=7)
carve('XXXTENTACION', SERIF, 128, 322, 6)
carve('JAHSEH D. ONFROY', SERIF, 58, 470, 4)
save(ped, 'pediment.png')
save(normal_map(np.array(hmap.filter(ImageFilter.GaussianBlur(1.5))) / 255.0, 3.0), 'pediment_n.png')

# ---------------------------------------------------------------- door grille (alpha)
GW, GH = 512, 1616
gr = Image.new('RGBA', (GW, GH), (0, 0, 0, 0))
gd = ImageDraw.Draw(gr)
BR, BR_D, BR_L = (118, 86, 50, 255), (58, 42, 24, 255), (186, 146, 88, 255)


def bar(pts, w):
    gd.line(pts, fill=BR_D, width=w + 4, joint='curve')
    gd.line(pts, fill=BR, width=w, joint='curve')
    gd.line([(p[0] - 1, p[1] - 1) for p in pts], fill=BR_L, width=max(1, w // 3), joint='curve')


def scroll(cx, cy, r, flip, turns=1.7, w=10):
    pts = []
    for k in range(80):
        a = k / 79 * turns * math.tau
        rr = r * (1 - k / 79 * 0.86)
        pts.append((cx + flip * math.cos(a) * rr, cy + math.sin(a) * rr))
    bar(pts, w)
    gd.ellipse([pts[-1][0] - w * 0.7, pts[-1][1] - w * 0.7, pts[-1][0] + w * 0.7, pts[-1][1] + w * 0.7], fill=BR_L)


cx = GW / 2
bar([(cx, 30), (cx, GH - 30)], 12)
for y in (30, GH - 30):
    bar([(20, y), (GW - 20, y)], 12)
bar([(20, 30), (20, GH - 30)], 12); bar([(GW - 20, 30), (GW - 20, GH - 30)], 12)
for i, y in enumerate(range(80, GH - 90, 150)):
    r = 66 if i % 2 == 0 else 52
    for side in (-1, 1):
        scroll(cx + side * (r + 10), y + 40, r, side)
        scroll(cx + side * (r * 0.95 + 82), y + 118, r * 0.55, -side, 1.4, 8)
        lx, ly = cx + side * (r * 2 + 40), y + 30
        gd.polygon([(lx, ly), (lx + side * 26, ly - 14), (lx + side * 8, ly + 18)], fill=BR, outline=BR_D)
    gd.ellipse([cx - 16, y + 70, cx + 16, y + 102], fill=BR_L, outline=BR_D, width=3)
for y in (GH * 0.33, GH * 0.66):
    bar([(20, y), (GW - 20, y)], 14)
save(gr, 'grille.png')


# ---------------------------------------------------------------- black granite with gold letters
def black_granite(w, h):
    a = np.ones((h, w, 3)) * 14.0
    a += (fbm(max(w, h), [6, 12, 24])[:h, :w] - 0.5)[..., None] * 10
    count = w * h // 40
    ys = rng.integers(0, h, count); xs = rng.integers(0, w, count)
    a[ys, xs] += rng.choice([10, 18, 30, 52], count)[:, None]
    im = rgb(a).filter(ImageFilter.GaussianBlur(0.5))
    sheen = Image.new('L', (w, h), 0)
    ImageDraw.Draw(sheen).polygon([(w * 0.55, 0), (w * 0.75, 0), (w * 0.35, h), (w * 0.15, h)], fill=38)
    im.paste((120, 125, 140), (0, 0), sheen.filter(ImageFilter.GaussianBlur(w / 16)))
    return im


def gold_text(im, text, font_path, size, cy, track=2, top=(255, 228, 150), bot=(190, 136, 44), x0=0, x1=None):
    x1 = im.width if x1 is None else x1
    d = ImageDraw.Draw(im)
    f = ImageFont.truetype(font_path, size)
    widths = [d.textlength(ch, font=f) for ch in text]
    x = x0 + (x1 - x0 - sum(widths) - track * (len(text) - 1)) / 2
    mask = Image.new('L', im.size, 0); md = ImageDraw.Draw(mask)
    for ch, w in zip(text, widths):
        d.text((x + 2, cy + 2), ch, font=f, fill=(0, 0, 0)); md.text((x, cy), ch, font=f, fill=255); x += w + track
    grad = Image.new('RGB', im.size)
    gp_ = ImageDraw.Draw(grad)
    for y in range(im.height):
        t = min(1, max(0, (y - cy) / (size * 1.1)))
        gp_.line([(0, y), (im.width, y)], fill=mix(top, bot, t))
    im.paste(grad, (0, 0), mask)


def wing_shape(d, cx, cy, s, side, cols):
    def feather(bx, by, ang, L, w, col, edge):
        ca, sa = math.cos(ang), math.sin(ang); nx, ny = -sa, ca
        pts = []
        for k in range(12):
            u = k / 11; half = w * math.sin(math.pi * min(1, u * 1.15)) * (1 - 0.35 * u)
            pts.append((bx + ca * L * u + nx * half, by + sa * L * u + ny * half))
        for k in range(11, -1, -1):
            u = k / 11; half = w * math.sin(math.pi * min(1, u * 1.15)) * (1 - 0.35 * u)
            pts.append((bx + ca * L * u - nx * half, by + sa * L * u - ny * half))
        d.polygon(pts, fill=col, outline=edge)
    sx = cx + side * s * 0.16
    for li, (n, Lk, wk, col) in enumerate([(13, 1.35, 0.13, cols[0]), (11, 0.95, 0.12, cols[1]), (9, 0.55, 0.11, cols[2])]):
        for i in range(n):
            t = i / (n - 1); ang = math.radians(lerp(-38, 78, t))
            L = s * Lk * (0.75 + 0.35 * math.sin(math.pi * (0.25 + 0.6 * t)))
            bx = sx + side * s * (0.05 + 0.32 * (1 - t) * (1 - li * 0.25)); by = cy - s * 0.15 + t * s * 0.25
            feather(bx, by, ang if side > 0 else math.pi - ang, L, s * wk, col, cols[3])


# crypt plate (inside the mausoleum)
SW, SH = 1024, 784
stone = black_granite(SW, SH)
sd = ImageDraw.Draw(stone)
sd.rectangle([26, 26, SW - 27, SH - 27], outline=(190, 150, 70), width=4)
sd.rectangle([38, 38, SW - 39, SH - 39], outline=(110, 86, 40), width=2)
for side in (-1, 1):
    wing_shape(sd, SW / 2, 200, 96, side, [(178, 205, 248), (214, 230, 255), (248, 251, 255), (110, 140, 200)])
sd.ellipse([SW / 2 - 52, 92, SW / 2 + 52, 116], outline=(255, 226, 140), width=5)
gold_text(stone, 'XXXTENTACION', SERIF_B, 104, 345, 4)
gold_text(stone, 'JAHSEH DWAYNE RICARDO ONFROY', SERIF, 42, 478, 3, (236, 236, 240), (170, 172, 182))
gold_text(stone, 'JANUARY 23, 1998  —  JUNE 18, 2018', SERIF, 40, 538, 2, (236, 236, 240), (170, 172, 182))
gold_text(stone, 'LONG LIVE', SERIF_B, 50, 630, 6)
save(stone, 'headstone.png')


# ---------------------------------------------------------------- the Poison Tree emblem and plaque
def tree_emblem(d, cx, base_y, s, col, w0=12):
    """A bare, twisted tree: trunk, forked branches, roots, three fruits."""
    r = random.Random(7)

    def br(x, y, ang, L, w, depth):
        if depth == 0 or w < 1:
            return
        pts = [(x, y)]; a = ang
        for k in range(5):
            a += r.uniform(-0.12, 0.12)
            # branches curl back toward the vertical a little, like a crown
            a += (-math.pi / 2 - a) * 0.06
            x += math.cos(a) * L / 5; y += math.sin(a) * L / 5
            pts.append((x, y))
        d.line(pts, fill=col, width=max(1, int(w)), joint='curve')
        n = 2 if depth > 2 else r.choice([2, 3])
        for i in range(n):
            br(x, y, a + (i - (n - 1) / 2) * r.uniform(0.5, 0.7), L * r.uniform(0.66, 0.76), w * 0.66, depth - 1)
    br(cx, base_y, -math.pi / 2, s * 0.3, w0, 6)
    for k in range(5):
        a = math.pi / 2 + (k - 2) * 0.42
        pts = [(cx, base_y)]; x, y = cx, base_y
        for j in range(4):
            a += r.uniform(-0.2, 0.2); x += math.cos(a) * s * 0.07 + (k - 2) * s * 0.03; y += abs(math.sin(a)) * s * 0.03
            pts.append((x, y))
        d.line(pts, fill=col, width=max(1, int(w0 * 0.6)), joint='curve')
    for fx, fy in [(-0.18, -0.55), (0.2, -0.62), (0.05, -0.42)]:
        px, py = cx + fx * s, base_y + fy * s
        d.ellipse([px - s * 0.025, py - s * 0.025, px + s * 0.025, py + s * 0.025], fill=col)


PLW, PLH = 1024, 512
plq = black_granite(PLW, PLH)
ImageDraw.Draw(plq).rectangle([20, 20, PLW - 21, PLH - 21], outline=(190, 150, 70), width=4)
emb = Image.new('L', (PLW, PLH), 0)
tree_emblem(ImageDraw.Draw(emb), 200, 452, 400, 255, 16)
plq.paste((0, 0, 0), (3, 3), emb)
plq.paste((222, 180, 92), (0, 0), emb)
gold_text(plq, 'POISON TREE', SERIF_B, 76, 160, 3, x0=380, x1=PLW - 40)
gold_text(plq, 'XXXTENTACION', SERIF, 44, 272, 4, (236, 236, 240), (170, 172, 182), x0=380, x1=PLW - 40)
gold_text(plq, '1998 — 2018', SERIF, 38, 330, 3, (236, 236, 240), (170, 172, 182), x0=380, x1=PLW - 40)
save(plq, 'plaque.png')

# ---------------------------------------------------------------- gate arch lettering (alpha)
AW, AH = 1024, 160
arch = Image.new('RGBA', (AW, AH), (0, 0, 0, 0))
ad = ImageDraw.Draw(arch)
f = ImageFont.truetype(SERIF_B, 92)
txt = 'XXXTENTACION'
tw = ad.textlength(txt, font=f)
ad.text(((AW - tw) / 2 + 3, 23), txt, font=f, fill=(40, 28, 10, 255))
ad.text(((AW - tw) / 2, 20), txt, font=f, fill=(232, 190, 96, 255))
save(arch, 'arch.png')

# ---------------------------------------------------------------- ribbon sash
RW, RH = 1024, 96
rib = Image.new('RGB', (RW, RH))
rd = ImageDraw.Draw(rib)
for y in range(RH):
    v = int(236 + 16 * math.sin(y / RH * math.pi))
    rd.line([(0, y), (RW, y)], fill=(v, v - 2, v - 6))
rd.rectangle([0, 6, RW, 10], fill=(210, 170, 80)); rd.rectangle([0, RH - 11, RW, RH - 7], fill=(210, 170, 80))
f = ImageFont.truetype(SERIF_B, 52)
txt = 'LONG LIVE  •  XXXTENTACION'
tw = rd.textlength(txt, font=f)
rd.text(((RW - tw) / 2, 18), txt, font=f, fill=(196, 150, 60))
save(rib, 'ribbon.png')

# ---------------------------------------------------------------- Poison Tree bark
BW, BH = 256, 512
ridges = np.zeros((BH, BW))
xs = np.arange(BW)
for k in range(14):
    off = rng.uniform(0, BW); amp = rng.uniform(4, 12); frq = rng.uniform(1, 3); wid = rng.uniform(3, 6)
    for y in range(BH):
        c = (off + amp * math.sin(y / BH * math.tau * round(frq) + k)) % BW
        dist = np.minimum(abs(xs - c), BW - abs(xs - c))
        ridges[y] += np.exp(-(dist / wid) ** 2)
ridges = (ridges - ridges.min()) / (ridges.max() - ridges.min())
big = fbm(512, [8, 16, 32])
cracks = np.vstack([big[:BH // 2, :BW], big[:BH // 2, :BW][::-1]])
hb = 0.65 * ridges + 0.35 * cracks
col = np.zeros((BH, BW, 3))
col[..., 0] = 20 + hb * 36; col[..., 1] = 13 + hb * 22; col[..., 2] = 24 + hb * 44
# veins: thin glowing lines that wander along the cracks between the ridges
vm = fbm(512, [6, 12, 24]); vm = np.vstack([vm[:BH // 2, :BW], vm[:BH // 2, :BW][::-1]])
lines = np.clip(1 - np.abs(vm - 0.5) * 28, 0, 1)
veins = lines * np.clip((0.45 - hb) * 4, 0, 1)
col += veins[..., None] * np.array([90, 20, 120])
save(rgb(col), 'bark.png')
save(normal_map(hb, 5.0), 'bark_n.png')
save(rgb(veins[..., None] * np.array([200, 60, 255])), 'bark_glow.png')

# ---------------------------------------------------------------- royal palm frond and trunk
FW, FH = 512, 160
fr = Image.new('RGBA', (FW, FH), (0, 0, 0, 0))
fd = ImageDraw.Draw(fr)
for i in range(70):
    u = i / 69
    x = 10 + u * (FW - 30)
    L = FH * 0.46 * math.sin(math.pi * min(1, 0.15 + u * 0.95)) * (1 - u * 0.25)
    for side in (-1, 1):
        tipx = x + L * 0.32 + 8
        tipy = FH / 2 + side * L * 0.94
        c = mix((44, 104, 38), (92, 150, 58), rnd.random() * 0.6)
        fd.polygon([(x - 2, FH / 2), (x + 3, FH / 2), (tipx + 2, tipy), (tipx - 1, tipy)], fill=c + (255,))
        fd.line([(x, FH / 2), (tipx, tipy)], fill=mix(c, (20, 50, 18), 0.4) + (255,), width=1)
fd.line([(0, FH / 2), (FW - 8, FH / 2)], fill=(150, 160, 90, 255), width=5)
save(fr, 'palm_frond.png')
tr = np.ones((256, 256, 3)) * np.array([150, 140, 122], float)
tr += (fbm(256, [8, 16, 32]) - 0.5)[..., None] * 40
for y in range(0, 256, 16):
    tr[y:y + 3] *= 0.68
save(rgb(tr), 'palm_trunk.png')

# ---------------------------------------------------------------- lawn, mulch, pavers, hedge
n = 256
gb = fbm(n, [8, 16, 32, 64])
gc = np.zeros((n, n, 3))
gc[..., 0] = 52 + gb * 40; gc[..., 1] = 102 + gb * 60; gc[..., 2] = 34 + gb * 22
gc[rng.random((n, n)) < 0.25] *= 1.18
save(rgb(gc), 'grass.png')
gcard = Image.new('RGBA', (256, 128), (0, 0, 0, 0))
gcd = ImageDraw.Draw(gcard)
for i in range(46):
    x = rnd.uniform(8, 248); h_ = rnd.uniform(60, 124); lean = rnd.uniform(-22, 22)
    c = mix((44, 96, 30), (110, 160, 60), rnd.random())
    gcd.polygon([(x - 3, 128), (x + 3, 128), (x + lean, 128 - h_)], fill=c + (255,))
save(gcard, 'grass_card.png')
mb = np.ones((n, n, 3)) * np.array([104, 34, 18], float)
for k in range(2600):
    x, y = rng.integers(0, n, 2); w_, h2 = rng.integers(2, 9, 2)
    mb[y:y + h2, x:x + w_] = np.array([118, 40, 20]) * rng.uniform(0.55, 1.35)
save(rgb(mb).filter(ImageFilter.GaussianBlur(0.6)), 'mulch.png')
pv = np.ones((n, n, 3)) * np.array([214, 200, 172], float)
pv += (fbm(n, [8, 16, 64]) - 0.5)[..., None] * 34
for k in range(400):
    x, y = rng.integers(0, n, 2); pv[y, x] -= 40
for a in (0, n // 2):
    pv[a:a + 3, :] = (120, 112, 98); pv[:, a:a + 3] = (120, 112, 98)
save(rgb(pv), 'pavers.png')
hd_ = np.ones((n, n, 3)) * np.array([30, 66, 30], float)
for k in range(5200):
    x, y = rng.integers(0, n, 2); s_ = rng.integers(2, 5)
    hd_[y:y + s_, x:x + s_ + 1] = np.array([42, 92, 38]) * rng.uniform(0.6, 1.6)
save(rgb(hd_).filter(ImageFilter.GaussianBlur(0.4)), 'hedge.png')

# ---------------------------------------------------------------- leaves and petals (alpha)
lf = Image.new('RGBA', (128, 256), (0, 0, 0, 0))
ld = ImageDraw.Draw(lf)
right = [(64 + 52 * math.sin(math.pi * t) * (1 - 0.3 * t), 250 - t * 244) for t in [i / 30 for i in range(31)]]
left = [(64 - (p[0] - 64), p[1]) for p in reversed(right)]
ld.polygon(right + left, fill=(48, 104, 44, 255))
ld.line([(64, 250), (64, 8)], fill=(96, 146, 70, 255), width=3)
for i in range(8):
    y = 220 - i * 26
    ld.line([(64, y), (24, y - 26)], fill=(70, 128, 58, 255), width=2); ld.line([(64, y), (104, y - 26)], fill=(70, 128, 58, 255), width=2)
save(lf, 'leaf.png')
sl = Image.new('RGBA', (128, 256), (0, 0, 0, 0))
sld = ImageDraw.Draw(sl)
for i in range(9):
    t = i / 8; y = 240 - t * 220; w_ = 52 * math.sin(math.pi * (0.15 + t * 0.85))
    for s in (1, -1):
        sld.ellipse([64 + s * w_ * 0.6 - 18, y - 16, 64 + s * w_ * 0.6 + 18, y + 16], fill=(178, 184, 188, 255))
sld.rectangle([60, 20, 68, 250], fill=(178, 184, 188, 255))
save(sl.filter(ImageFilter.GaussianBlur(0.8)), 'silver_leaf.png')
pt = Image.new('RGBA', (64, 64), (0, 0, 0, 0))
ptd = ImageDraw.Draw(pt)
ptd.ellipse([8, 4, 56, 62], fill=(255, 255, 255, 255))
save(pt.filter(ImageFilter.GaussianBlur(1.0)), 'petal.png')

# ---------------------------------------------------------------- the light: a feathered wing and a soft glow
WW, WH = 512, 512
wing = Image.new('RGBA', (WW, WH), (0, 0, 0, 0))
wd = ImageDraw.Draw(wing)


def plume(bx, by, ang, L, w, a):
    ca, sa = math.cos(ang), math.sin(ang); nx, ny = -sa, ca
    pts = []
    for k in range(14):
        u = k / 13; half = w * math.sin(math.pi * min(1, u * 1.1)) * (1 - 0.3 * u)
        pts.append((bx + ca * L * u + nx * half, by + sa * L * u + ny * half))
    for k in range(13, -1, -1):
        u = k / 13; half = w * math.sin(math.pi * min(1, u * 1.1)) * (1 - 0.3 * u)
        pts.append((bx + ca * L * u - nx * half, by + sa * L * u - ny * half))
    wd.polygon(pts, fill=(255, 255, 255, a))
    wd.line([(bx, by), (bx + ca * L * 0.95, by + sa * L * 0.95)], fill=(255, 255, 255, min(255, a + 60)), width=2)


# root at the left edge, a third of the way down; long primaries fan out right and down
for li, (cnt, Lk, wk, a) in enumerate([(14, 1.0, 0.07, 150), (12, 0.68, 0.075, 190), (10, 0.4, 0.08, 230)]):
    for i in range(cnt):
        t = i / (cnt - 1)
        L = WW * 0.92 * Lk * (0.7 + 0.3 * math.sin(math.pi * (0.2 + 0.7 * t)))
        plume(12 + li * 10, WH * 0.28 + t * WH * 0.12, math.radians(lerp(-28, 70, t)), L, WW * wk, a)
# soften: feathers fade toward their tips, and the whole wing is slightly blurred like light
wa = np.asarray(wing).astype(float)
yy, xx = np.mgrid[0:WH, 0:WW]
dist = np.hypot(xx - 12, yy - WH * 0.34) / (WW * 0.95)
wa[..., 3] *= np.clip(1.0 - dist * 0.75, 0.15, 1.0)
save(rgba(wa).filter(ImageFilter.GaussianBlur(2.2)), 'wing.png')
G_ = 128
yy, xx = np.mgrid[0:G_, 0:G_]
r = np.hypot(xx - G_ / 2 + 0.5, yy - G_ / 2 + 0.5) / (G_ / 2)
gl = np.zeros((G_, G_, 4)); gl[..., :3] = 255; gl[..., 3] = np.clip(1 - r, 0, 1) ** 2.2 * 255
save(rgba(gl), 'glow.png')
print('memorial textures done')
