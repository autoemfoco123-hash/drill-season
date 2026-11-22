#!/usr/bin/env python3
"""Paints the Godot memorial garden textures into godot/assets/art/:
headstone.png the crypt plate inside the mausoleum (black granite, gold letters)
granite.png   speckled grey granite (tileable) for the mausoleum
pediment.png  the pediment with its engraved inscription
door_l.png, door_r.png  the bronze double doors with scrollwork over dark glass
The mausoleum is modelled on the photo of the real one that the family shared.
No faces, no logos, no lyrics: names, dates, angel wings and a halo, roses.
Usage: python3 tools/make-memorial.py"""
import os, math, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
W, H = 2048, 1424
FB = os.path.join(ROOT, 'godot', 'fonts', 'DejaVuSans-Bold.ttf')
FR = os.path.join(ROOT, 'godot', 'fonts', 'DejaVuSans.ttf')
rnd = random.Random(1998)

def font(size, bold=True):
    return ImageFont.truetype(FB if bold else FR, size)

def lerp(a, b, t): return a + (b - a) * t
def mix(c1, c2, t): return tuple(int(lerp(c1[i], c2[i], t)) for i in range(len(c1)))

# wings() and rose() paint on whichever image `img` is set to
img = None

def wings(cx, cy, s):
    d = ImageDraw.Draw(img)
    def feather(bx, by, ang, L, w, col, edge):
        ca, sa = math.cos(ang), math.sin(ang)
        nx, ny = -sa, ca
        pts = []
        for k in range(12):
            u = k / 11
            half = w * math.sin(math.pi * min(1, u * 1.15)) * (1 - 0.35 * u)
            pts.append((bx + ca * L * u + nx * half, by + sa * L * u + ny * half))
        for k in range(11, -1, -1):
            u = k / 11
            half = w * math.sin(math.pi * min(1, u * 1.15)) * (1 - 0.35 * u)
            pts.append((bx + ca * L * u - nx * half, by + sa * L * u - ny * half))
        d.polygon(pts, fill=col, outline=edge)
        d.line([(bx, by), (bx + ca * L * 0.92, by + sa * L * 0.92)], fill=edge, width=2)
    for side in (-1, 1):
        sx = cx + side * s * 0.16
        # three layers: long primaries hanging out and down, then secondaries, then small coverts
        layers = [(13, 1.35, 0.13, (178, 205, 248)), (11, 0.95, 0.12, (214, 230, 255)), (9, 0.55, 0.11, (248, 251, 255))]
        for li, (n, Lk, wk, col) in enumerate(layers):
            for i in range(n):
                t = i / (n - 1)
                # fan from up-and-out down to pointing down
                deg = lerp(-38, 78, t)
                ang = math.radians(deg)
                L = s * Lk * (0.75 + 0.35 * math.sin(math.pi * (0.25 + 0.6 * t)))
                bx = sx + side * s * (0.05 + 0.32 * (1 - t) * (1 - li * 0.25))
                by = cy - s * 0.15 + t * s * 0.25
                a2 = ang if side > 0 else math.pi - ang
                feather(bx, by, a2, L, s * wk, col, (110, 140, 200))
    # halo
    halo = Image.new('L', (W, H), 0)
    ImageDraw.Draw(halo).ellipse([cx - s * 0.62, cy - s * 1.02, cx + s * 0.62, cy - s * 0.72], outline=255, width=26)
    img.paste((255, 236, 160), (0, 0), halo.filter(ImageFilter.GaussianBlur(16)).point(lambda v: v * 0.75))
    d.ellipse([cx - s * 0.55, cy - s * 0.99, cx + s * 0.55, cy - s * 0.75], outline=(255, 236, 150), width=9)
    d.ellipse([cx - s * 0.55, cy - s * 0.99, cx + s * 0.55, cy - s * 0.75], outline=(255, 252, 225), width=3)

def rose(cx, cy, s, col=(200, 20, 45)):
    d = ImageDraw.Draw(img)
    d.line([(cx, cy), (cx + rnd.uniform(-s, s) * 0.3, cy + s * 2.6)], fill=(40, 110, 50), width=max(3, int(s * 0.15)))
    d.ellipse([cx + s * 0.1, cy + s * 1.2, cx + s * 0.95, cy + s * 1.65], fill=(50, 130, 60), outline=(20, 60, 25))
    dark = mix(col, (60, 0, 15), 0.55)
    # outer petals, then a tighter cup, then the spiral heart
    for k in range(5):
        a = k / 5 * math.tau + 0.3
        px2, py2 = cx + math.cos(a) * s * 0.45, cy + math.sin(a) * s * 0.35
        d.ellipse([px2 - s * 0.55, py2 - s * 0.45, px2 + s * 0.55, py2 + s * 0.45], fill=col, outline=dark)
    d.ellipse([cx - s * 0.55, cy - s * 0.5, cx + s * 0.55, cy + s * 0.45], fill=mix(col, (255, 255, 255), 0.12), outline=dark)
    for k in range(3):
        r = s * (0.38 - k * 0.11)
        d.arc([cx - r, cy - r * 0.8 - k * 2, cx + r, cy + r * 0.8], start=200 + k * 40, end=520 + k * 40, fill=dark, width=3)


# ---------- the headstone in the memorial garden: black granite, gold letters ----------
SW, SH = 1024, 784
stone = Image.new('RGB', (SW, SH), (13, 13, 15))
sp = stone.load()
for _ in range(26000):
    x, y = rnd.randrange(SW), rnd.randrange(SH)
    v = rnd.choice([22, 28, 34, 48, 70])
    sp[x, y] = (v, v, v + 3)
stone = stone.filter(ImageFilter.GaussianBlur(0.6))
# polished sheen
sheen = Image.new('L', (SW, SH), 0)
ImageDraw.Draw(sheen).polygon([(SW * 0.55, 0), (SW * 0.75, 0), (SW * 0.35, SH), (SW * 0.15, SH)], fill=40)
stone.paste((120, 125, 140), (0, 0), sheen.filter(ImageFilter.GaussianBlur(60)))
sd = ImageDraw.Draw(stone)
GOLD_T, GOLD_B = (255, 226, 140), (196, 140, 46)
sd.rectangle([26, 26, SW - 27, SH - 27], outline=(190, 150, 70), width=4)
sd.rectangle([38, 38, SW - 39, SH - 39], outline=(110, 86, 40), width=2)

def engraved(text, size, cy, top=GOLD_T, bot=GOLD_B, bold=True):
    f = font(size, bold)
    w = sd.textlength(text, font=f)
    x = (SW - w) / 2
    sd.text((x + 3, cy + 3), text, font=f, fill=(0, 0, 0))
    mask = Image.new('L', (SW, SH), 0)
    ImageDraw.Draw(mask).text((x, cy), text, font=f, fill=255)
    grad = Image.new('RGB', (SW, SH))
    gp = ImageDraw.Draw(grad)
    for y in range(SH):
        t = min(1, max(0, (y - cy) / (size * 1.1)))
        gp.line([(0, y), (SW, y)], fill=mix(top, bot, t))
    stone.paste(grad, (0, 0), mask)

# the wing emblem with its halo, inlaid in white stone
img = stone
wings(SW / 2, 196, 98)
sd = ImageDraw.Draw(stone)
engraved('XXXTENTACION', 104, 345)
engraved('JAHSEH DWAYNE RICARDO ONFROY', 40, 470, (236, 236, 240), (170, 172, 182), False)
engraved('JANUARY 23, 1998  —  JUNE 18, 2018', 38, 530, (236, 236, 240), (170, 172, 182), False)
engraved('LONG LIVE', 46, 625)
# two small roses at the foot
for sx in (SW * 0.24, SW * 0.76):
    img = stone
    rose(sx, 660, 34)
    rose(sx + (40 if sx < SW / 2 else -40), 670, 28, (235, 235, 240))
stone.save(os.path.join(ROOT, 'godot', 'assets', 'art', 'headstone.png'), optimize=True)
print('headstone.png', os.path.getsize(os.path.join(ROOT, 'godot', 'assets', 'art', 'headstone.png')) // 1024, 'KB')

# ---------- the mausoleum ----------
ART = os.path.join(ROOT, 'godot', 'assets', 'art')
SERIF = '/usr/share/fonts/truetype/liberation/LiberationSerif-Regular.ttf'
if not os.path.exists(SERIF):
    SERIF = '/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf'

def granite_tile(n=256, base=(168, 168, 170)):
    im = Image.new('RGB', (n, n), base)
    p = im.load()
    for _ in range(n * n // 3):
        x, y = rnd.randrange(n), rnd.randrange(n)
        v = rnd.choice([-46, -30, -18, 14, 26, 40])
        c = tuple(max(0, min(255, base[i] + v + rnd.randint(-4, 4))) for i in range(3))
        for dx, dy in [(0, 0), (1, 0), (0, 1)] if rnd.random() < 0.35 else [(0, 0)]:
            p[(x + dx) % n, (y + dy) % n] = c
    return im.filter(ImageFilter.GaussianBlur(0.5))

g = granite_tile()
g.save(os.path.join(ART, 'granite.png'), optimize=True)

# pediment: the triangle maps (0,1) (1,1) (0.5,0); the inscription sits low in it
PW, PH = 1024, 300
ped = Image.new('RGB', (PW, PH))
for y in range(0, PH, 256):
    for x in range(0, PW, 256):
        ped.paste(g, (x, y))
pd = ImageDraw.Draw(ped)
# engraved border groove, inset from the triangle's edges
inset = 26
pd.line([(inset * 1.9, PH - inset * 0.8), (PW / 2, inset * 1.1), (PW - inset * 1.9, PH - inset * 0.8), (inset * 1.9, PH - inset * 0.8)], fill=(110, 110, 114), width=5)
pd.line([(inset * 1.9 + 3, PH - inset * 0.8 + 3), (PW / 2, inset * 1.1 + 3), (PW - inset * 1.9 + 3, PH - inset * 0.8 + 3)], fill=(205, 205, 208), width=2)

def carve(draw, text, size, cy, width):
    f = ImageFont.truetype(SERIF, size)
    w = draw.textlength(text, font=f)
    x = (width - w) / 2
    draw.text((x + 2, cy + 2), text, font=f, fill=(206, 206, 210))
    draw.text((x, cy), text, font=f, fill=(52, 52, 58))

def spaced(text, n=1):
    return (' ' * n).join(text)

carve(pd, 'XXXTENTACION', 60, 168, PW)
carve(pd, 'JAHSEH D. ONFROY', 30, 238, PW)
ped.save(os.path.join(ART, 'pediment.png'), optimize=True)

# a door leaf: black bronze frame, dark glass, mirrored scrollwork, gold handle at the inner edge
DW, DH = 256, 808
door = Image.new('RGB', (DW, DH), (16, 13, 12))
dd = ImageDraw.Draw(door)
for y in range(DH):
    t = y / DH
    dd.line([(18, y), (DW - 18, y)], fill=mix((40, 42, 48), (14, 15, 18), abs(t - 0.35) * 1.4))
dd.rectangle([0, 0, DW - 1, DH - 1], outline=(28, 22, 18), width=18)
dd.rectangle([16, 16, DW - 17, DH - 17], outline=(92, 70, 44), width=4)
dd.rectangle([30, 30, DW - 31, DH - 31], outline=(60, 46, 30), width=3)
BR = (118, 88, 52)
BR2 = (64, 48, 30)

def scroll(cx, cy, r, flip, turns=1.6):
    pts = []
    for k in range(60):
        a = k / 59 * turns * math.tau
        rr = r * (1 - k / 59 * 0.82)
        pts.append((cx + flip * math.cos(a) * rr, cy + math.sin(a) * rr))
    dd.line(pts, fill=BR2, width=7)
    dd.line(pts, fill=BR, width=4)

cx = DW / 2
# a central stem with paired C- and S-scrolls climbing it
dd.line([(cx, 40), (cx, DH - 40)], fill=BR2, width=7)
dd.line([(cx, 40), (cx, DH - 40)], fill=BR, width=4)
for i, y in enumerate(range(70, DH - 60, 92)):
    r = 34 if i % 2 == 0 else 26
    for side in (-1, 1):
        scroll(cx + side * (r + 6), y + 20, r, side)
        scroll(cx + side * (r * 0.9 + 40), y + 64, r * 0.6, -side, 1.3)
    dd.ellipse([cx - 9, y + 36, cx + 9, y + 54], fill=BR, outline=BR2)
# rails
for y in (DH * 0.33, DH * 0.67):
    dd.rectangle([30, y - 5, DW - 31, y + 5], fill=(70, 54, 34))
# gold handle near the inner edge (right side of the left leaf)
hx = DW - 36
dd.rounded_rectangle([hx - 9, DH * 0.44, hx + 9, DH * 0.56], radius=8, fill=(212, 170, 72), outline=(120, 90, 30), width=2)
dd.ellipse([hx - 14, DH * 0.5 - 14, hx + 14, DH * 0.5 + 14], fill=(226, 186, 90), outline=(120, 90, 30), width=2)
door.save(os.path.join(ART, 'door_l.png'), optimize=True)
door.transpose(Image.FLIP_LEFT_RIGHT).save(os.path.join(ART, 'door_r.png'), optimize=True)
print('mausoleum textures done')
