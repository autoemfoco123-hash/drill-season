#!/usr/bin/env python3
"""The Steam store and library art for the turf update, from four key art frames rendered in the
game (Trailer.gd e_finale with DS_KEYCAM / DS_FACEOFF / DS_NOMUG, see README.md):
  key_right.png   3840x2160  the crew right of centre under the L, a wreck burning, room for the logo
  key_center.png  3840x2160  the crew in the middle
  key_faceoff.png 3840x2160  your crew and Halo facing off across Calder Ave
Each is graded like the trailer (split tone, bloom, vignette), with embers and snow, then cut
to every size Steam asks for. Usage: compose_epic.py <keyart dir> <out dir> [trailer stills dir]"""
import os, sys, math, random, subprocess, urllib.parse, shutil
import numpy as np
from PIL import Image, ImageFilter, ImageDraw, ImageEnhance

HERE = os.path.dirname(os.path.abspath(__file__))
KEY, OUT = sys.argv[1], sys.argv[2]
STILLS = sys.argv[3] if len(sys.argv) > 3 else None
os.makedirs(OUT, exist_ok=True)
TMP = OUT + '/.tmp'; os.makedirs(TMP, exist_ok=True)
LOGO = Image.open(HERE + '/../../marketing/steam/logo_2194x1265.png').convert('RGBA')

def grade(img, exp=1.08, bottom=0.45):
    W, H = img.size
    x = np.asarray(img.convert('RGB'), np.float32) * (exp / 255.0)
    lum = (x[..., 0] * 0.2126 + x[..., 1] * 0.7152 + x[..., 2] * 0.0722)[..., None]
    x = x * (1 + (1 - np.clip(lum, 0, 1)) * np.array([-0.06, 0.0, 0.07], np.float32) + np.clip(lum, 0, 1) * np.array([0.06, 0.012, -0.05], np.float32))
    x = np.clip(x, 0, 1)
    x = x * x * (3 - 2 * x) * 0.4 + x * 0.6
    l2 = (x[..., 0] * 0.2126 + x[..., 1] * 0.7152 + x[..., 2] * 0.0722)[..., None]
    x = l2 + (x - l2) * 1.15
    # the bright snow in the foreground: pull the bottom of the frame down
    yy = np.linspace(0, 1, H, dtype=np.float32)[:, None, None]
    x = x * (1 - bottom * np.clip((yy - 0.72) / 0.28, 0, 1) ** 1.4)
    small = Image.fromarray((np.clip(x, 0, 1) * 255).astype(np.uint8)).resize((W // 6, H // 6), Image.BILINEAR)
    sm = np.clip(np.asarray(small, np.float32) / 255.0 - 0.6, 0, None) * 2.4
    bl = Image.fromarray((np.clip(sm, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(max(4, W // 400))).resize((W, H), Image.BILINEAR)
    x = x + np.asarray(bl, np.float32) / 255.0 * 0.38
    yy2, xx2 = np.mgrid[0:H, 0:W].astype(np.float32)
    r = np.sqrt(((xx2 - W / 2) / (W / 2)) ** 2 + ((yy2 - H / 2) / (H / 2)) ** 2)
    x = x * (1.0 - 0.34 * np.clip(r - 0.3, 0, None) ** 1.5)[..., None]
    x = x + np.random.default_rng(3).standard_normal((H, W, 1)).astype(np.float32) * 0.012
    return Image.fromarray((np.clip(x, 0, 1) * 255).astype(np.uint8))

def particles(img, seed, fire_xy=None, n_snow=260, n_ember=120):
    """snow in front (some of it soft and big, out of focus) and embers rising from the fire"""
    W, H = img.size
    k = W / 1920.0
    rng = random.Random(seed)
    base = img.convert('RGBA')
    far = Image.new('RGBA', (W, H)); d = ImageDraw.Draw(far)
    for _ in range(n_snow):
        x, y, s = rng.random() * W, rng.random() * H, (1 + rng.random() * 2.6) * k
        d.ellipse((x - s, y - s, x + s, y + s), fill=(255, 255, 255, int(110 + rng.random() * 110)))
    near = Image.new('RGBA', (W, H)); d2 = ImageDraw.Draw(near)
    for _ in range(14):
        x, y, s = rng.random() * W, rng.random() * H, (8 + rng.random() * 16) * k
        d2.ellipse((x - s, y - s, x + s, y + s), fill=(255, 255, 255, 70))
    near = near.filter(ImageFilter.GaussianBlur(6 * k))
    if fire_xy:
        em = Image.new('RGBA', (W, H)); d3 = ImageDraw.Draw(em)
        fx, fy = fire_xy[0] * W, fire_xy[1] * H
        for _ in range(n_ember):
            x = fx + rng.gauss(0, 0.07 * W); y = fy - abs(rng.gauss(0, 0.28 * H))
            s = (1 + rng.random() * 2.2) * k
            d3.ellipse((x - s, y - s, x + s, y + s), fill=(255, 140 + int(rng.random() * 90), 50, int(150 + rng.random() * 100)))
        glow = em.filter(ImageFilter.GaussianBlur(3 * k))
        base.alpha_composite(glow); base.alpha_composite(em)
    base.alpha_composite(far); base.alpha_composite(near)
    return base.convert('RGB')

def cover(img, w, h, fx=0.5, fy=0.5):
    """scale to cover w x h, then crop around (fx, fy) of the source"""
    sw, sh = img.size
    s = max(w / sw, h / sh)
    im = img.resize((int(math.ceil(sw * s)), int(math.ceil(sh * s))), Image.LANCZOS)
    x = int(max(0, min(im.width - w, fx * im.width - w / 2))); y = int(max(0, min(im.height - h, fy * im.height - h / 2)))
    return im.crop((x, y, x + w, y + h))

def logo(width, glow=True):
    h = int(LOGO.height * width / LOGO.width)
    lg = LOGO.resize((int(width), h), Image.LANCZOS)
    out = Image.new('RGBA', (lg.width + 80, lg.height + 80))
    a = lg.getchannel('A')
    sh = Image.new('RGBA', lg.size, (0, 0, 0, 0)); sh.putalpha(a.filter(ImageFilter.GaussianBlur(max(3, width // 60))).point(lambda v: int(v * 0.75)))
    out.alpha_composite(sh, (40, 46))
    if glow:
        g = Image.new('RGBA', lg.size, (255, 110, 50, 0)); g.putalpha(a.filter(ImageFilter.GaussianBlur(max(4, width // 30))).point(lambda v: int(v * 0.5)))
        out.alpha_composite(g, (40, 40))
    out.alpha_composite(lg, (40, 40))
    return out

def put(base, layer, cx, cy):
    b = base.convert('RGBA')
    b.alpha_composite(layer, (int(cx - layer.width / 2), int(cy - layer.height / 2)))
    return b.convert('RGB')

def shade(img, side='left', amt=0.6, reach=0.55):
    W, H = img.size
    g = np.linspace(1, 0, int(W * reach)) ** 1.3 * amt if side in ('left', 'right') else None
    m = np.zeros((H, W), np.float32)
    if side == 'left': m[:, :len(g)] = g
    elif side == 'right': m[:, W - len(g):] = g[::-1]
    elif side == 'top':
        gg = np.linspace(1, 0, int(H * reach)) ** 1.3 * amt; m[:len(gg), :] = gg[:, None]
    elif side == 'bottom':
        gg = np.linspace(1, 0, int(H * reach)) ** 1.3 * amt; m[H - len(gg):, :] = gg[::-1][:, None]
    x = np.asarray(img, np.float32) * (1 - m[..., None])
    return Image.fromarray(x.clip(0, 255).astype(np.uint8))

def text(w, h, **kw):
    q = urllib.parse.urlencode(dict(w=w, h=h, **kw))
    out = f'{TMP}/text_{abs(hash(q))}.png'
    subprocess.run(['node', HERE + '/shot.js', HERE + '/art_text.html', out, str(w), str(h), '#c', q], check=True, cwd=HERE)
    return Image.open(out).convert('RGBA')

def save(img, name):
    img.convert('RGB').save(f'{OUT}/{name}', optimize=True)
    print('wrote', name, img.size)

# ---------------------------------------------------------------- the four key art frames, graded
def key(name, fire, exp=1.08, bottom=0.45, seed=1):
    p = f'{TMP}/{name}_graded.png'
    if os.path.exists(p): return Image.open(p).convert('RGB')
    im = grade(Image.open(f'{KEY}/{name}.png'), exp, bottom)
    im = particles(im, seed, fire)
    im.save(p)
    return im

R = key('key_right', (0.38, 0.62), 1.1, 0.5, 1)
C = key('key_center', (0.3, 0.62), 1.1, 0.5, 2)

# ---------------------------------------------------------------- store capsules
m = cover(R, 1232, 706, 0.5, 0.52); m = shade(m, 'left', 0.55, 0.6)
save(put(m, logo(560), 330, 230), 'main_capsule_1232x706.png')

hd = cover(R, 920, 430, 0.33, 0.56); hd = shade(hd, 'left', 0.62, 0.62)
save(put(hd, logo(370), 215, 200), 'header_capsule_920x430.png')
save(put(hd, logo(370), 215, 200), 'library_header_920x430.png')

sm = cover(R, 462, 174, 0.5, 0.56); sm = shade(sm, 'left', 0.75, 0.75)
save(put(sm, logo(250, glow=False), 140, 88), 'small_capsule_462x174.png')

vc = cover(C, 748, 896, 0.51, 0.5); vc = shade(vc, 'top', 0.5, 0.42)
save(put(vc, logo(620), 374, 200), 'vertical_capsule_748x896.png')

lc = cover(C, 600, 900, 0.51, 0.5); lc = shade(lc, 'top', 0.5, 0.42)
save(put(lc, logo(520), 300, 190), 'library_capsule_600x900.png')

# library hero: no logo, no text (Steam puts the library logo over it, bottom left)
save(cover(R, 3840, 1240, 0.5, 0.6), 'library_hero_3840x1240.png')
shutil.copy(HERE + '/../../marketing/steam/library_logo_1249x720.png', f'{OUT}/library_logo_1249x720.png')

# page background: the art, dark and quiet, so the store page reads over it
pb = cover(C, 1438, 810, 0.5, 0.5)
pb = ImageEnhance.Color(ImageEnhance.Brightness(pb.filter(ImageFilter.GaussianBlur(2))).enhance(0.55)).enhance(0.8)
save(shade(pb, 'bottom', 0.75, 0.5), 'page_background_1438x810.png')

# ---------------------------------------------------------------- the update post (events) and the trailer thumbnail
eh = cover(R, 1920, 622, 0.3, 0.6); eh = shade(eh, 'left', 0.7, 0.62)
eh = put(eh, logo(420), 330, 215)
eh = eh.convert('RGBA'); eh.alpha_composite(text(1920, 622, t='THE TURF WARS UPDATE', f='anton', size=62, sp=6, x='left', y=0.78, pad=110, rule=360, s='TAKE CORNERS · HOLD THEM · RUN THE CITY', ssize=24, ssp=7))
save(eh, 'event_header_1920x622.png')

ec = cover(R, 800, 450, 0.42, 0.55); ec = shade(ec, 'left', 0.7, 0.65)
ec = put(ec, logo(290), 190, 120)
ec = ec.convert('RGBA'); ec.alpha_composite(text(800, 450, t='THE TURF WARS UPDATE', f='anton', size=40, sp=4, x='left', y=0.76, pad=36, rule=200))
save(ec, 'event_cover_800x450.png')

th = cover(R, 1920, 1080, 0.5, 0.52); th = shade(th, 'left', 0.55, 0.6)
th = put(th, logo(860), 520, 360)
th = th.convert('RGBA'); th.alpha_composite(text(1920, 1080, t='TURF WARS', f='anton', size=120, sp=14, x='left', y=0.74, pad=150, rule=300, s='OFFICIAL TRAILER', ssize=40, ssp=14))
save(th, 'trailer_thumbnail_1920x1080.png')

# the key art on its own, for social posts and the store's "about" section
save(cover(R, 1920, 1080), 'keyart_crew_1920x1080.png')
save(put(cover(C, 3840, 2160).convert('RGB'), logo(1500), 1920, 520), 'keyart_logo_3840x2160.png')

# ---------------------------------------------------------------- screenshots, from the trailer's graded frames (no titles)
if STILLS:
    os.makedirs(OUT + '/screenshots', exist_ok=True)
    pick = ['take', 'cars', 'boom', 'raid', 'halo', 'win', 'drift', 'walk', 'finale_40', 'fp', 'low', 'ride', 'sable', 'cars2']
    k = 1
    for s in pick:
        p = f'{STILLS}/{s}.png'
        if os.path.exists(p):
            Image.open(p).convert('RGB').save(f'{OUT}/screenshots/turf_{k:02d}_{s}.png', optimize=True); k += 1
    print('screenshots', k - 1)
shutil.rmtree(TMP, ignore_errors=True)
