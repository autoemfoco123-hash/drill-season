#!/usr/bin/env python3
"""The epic trailer (turf update): renders the e_* scenes (and a few from the first trailer) in
the game frame by frame, grades them like a film, cuts them on the bars of score.py, adds the
turf map graphics, captions, the logo slam, the end card, the music and the sound effects.

  python3 trailer_epic.py render [scene ...]   render scenes (3 at a time), 1920x1080
  python3 trailer_epic.py edit                 grade, cut, titles, mix -> the trailer
Everything lands in $DS_WORK/epic (default ./work/epic)."""
import os, sys, glob, json, shutil, subprocess, random, math, wave
import numpy as np
from PIL import Image, ImageFilter, ImageDraw, ImageFont, ImageEnhance
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.environ.get('DS_WORK', HERE + '/work') + '/epic'
GODOT = os.path.normpath(HERE + '/../../godot')
FR, SEG, CAP, STILLS = WORK + '/frames', WORK + '/seg', WORK + '/cap', WORK + '/stills'
for d in (FR, SEG, CAP, STILLS): os.makedirs(d, exist_ok=True)
FPS, W, H = 30, 1920, 1080
BPM = 140.0
BAR = 4 * 60.0 / BPM

def fb(bar): return int(round(bar * BAR * FPS))        # frame of a bar line

# ---------------------------------------------------------------- the timeline, in bars
# (segment, scene, first bar, bars, frame offset into the scene in bars)
TL = [
    ('open', 'e_open', 0, 2, 0), ('halo', 'e_halo', 2, 1, 0), ('low', 'e_low', 3, 1, 0), ('sable', 'e_sable', 4, 1, 0),
    ('map', 'e_map', 5, 3, 0),
    ('logo', None, 8, 1, 0),
    ('take', 'e_takeover', 9, 2, 0), ('fp', 'e_fp', 11, 1, 0), ('cars', 'e_cars', 12, 2, 0), ('ride', 'e_ride', 14, 1, 0),
    ('chase', 'chase', 15, 1, 0), ('boom', 'e_boom', 16, 2, 0), ('punch', 'punch', 18, 1, 0), ('raid', 'e_raid', 19, 2, 0),
    ('gun', 'gunfight', 21, 1, 0), ('rag', 'ragdoll', 22, 1, 0), ('win', 'e_win', 23, 2, 0),
    ('studio', 'studio', 25, 2, 0), ('storm', 'storm', 27, 2, 0), ('map2', 'e_map2', 29, 2, 0),
    ('drift', 'e_drift', 31, 1, 0), ('dances', 'dances', 32, 1, 0), ('train', 'train', 33, 1, 0), ('cars2', 'e_cars', 34, 1, 2),
    ('walk', 'e_walk', 35, 2, 0), ('take2', 'e_takeover', 37, 1, 2), ('raid2', 'e_raid', 38, 1, 2),
    ('finale', 'e_finale', 39, 6, 0),
]
END_BAR = 45
TAIL = 2.0                                   # black at the end while the music rings out
TOD = { 'punch': '20.2', 'gunfight': '20.4', 'ragdoll': '20.4' }

def scene_frames():
    need = {}
    for seg, sc, b0, nb, off in TL:
        if sc is None: continue
        n = fb(off) + (fb(b0 + nb) - fb(b0)) + 2
        need[sc] = max(need.get(sc, 0), n)
    return need

def log(*a): print(*a, flush=True)

# ---------------------------------------------------------------- rendering in the game
def render(scene, n):
    d = f'{FR}/{scene}'
    if os.path.exists(d + '/done') and len(glob.glob(d + '/*.png')) >= n: return
    shutil.rmtree(d, ignore_errors=True)
    env = dict(os.environ, DS_TRAILER=scene, DS_FRAMES=str(n), DS_SHOTS=FR, HOME=f'{WORK}/gdhome_{scene}')
    if scene in TOD: env['DS_TOD'] = TOD[scene]
    cmd = ['timeout', '5400', 'xvfb-run', '-a', '-s', '-screen 0 1920x1080x24', 'godot3', '--path', '.', '--audio-driver', 'Dummy',
           '--resolution', '1920x1080', '--fixed-fps', '30', '--autotest']
    r = subprocess.run(cmd, cwd=GODOT, env=env, capture_output=True, text=True)
    errs = [l for l in (r.stdout + r.stderr).split('\n') if 'SCRIPT ERROR' in l]
    got = len(glob.glob(d + '/*.png'))
    log(f'{scene}: {got}/{n} frames, exit {r.returncode}', errs[:3])
    if got >= n: open(d + '/done', 'w').write('ok')

def render_all(only):
    need = scene_frames()
    jobs = [(s, n) for s, n in need.items() if not only or s in only]
    # longest first
    jobs.sort(key=lambda j: -j[1])
    with ThreadPoolExecutor(int(os.environ.get('DS_JOBS', '3'))) as ex:
        list(ex.map(lambda j: render(*j), jobs))

if __name__ == '__main__' and len(sys.argv) > 1 and sys.argv[1] == 'render':
    log('scenes:', scene_frames())
    render_all(sys.argv[2:])
    sys.exit(0)


# ================================================================ the edit
GODOT_SFX = (GODOT + '/assets/sfx/', GODOT + '/assets/sfx2/')
LB = 138                                         # letterbox bar height for 2.39:1
CAPTIONS = {   # segment: (kind, text, sub, from frame)
    'open': ('lower', 'CALDER PARK', 'CHICAGO · WINTER', 10), 'halo': ('title', 'EVERY BLOCK', '', 3), 'low': ('title', 'BELONGS', '', 3),
    'sable': ('title', 'TO SOMEBODY', '', 3), 'take': ('title', 'HOLD THE CORNER', '', 6), 'ride': ('title', 'ROLL DEEP', '', 4),
    'raid': ('title', 'DEFEND IT', '', 8), 'studio': ('title', 'MAKE YOUR NAME', '', 8),
}
GRADE = {   # segment: exposure
    'open': 1.25, 'halo': 1.15, 'low': 1.1, 'sable': 1.05, 'map': 1.35, 'map2': 1.35, 'ride': 1.45, 'raid': 1.2, 'fp': 1.15, 'cars': 1.15,
    'cars2': 1.15, 'walk': 1.1, 'finale': 1.0, 'boom': 1.0, 'drift': 1.2,
}
MINE = (80, 232, 255)       # your gang on the map: cyan, apart from Sable Row's blue
CREW_COL = { 'halo': (230, 66, 61), 'lowend': (242, 168, 61), 'sable': (86, 110, 245), 'cops': (110, 150, 230), '': (220, 225, 235) }
OWN = ['lowend', 'lowend', 'lowend', 'lowend', 'lowend', '', 'halo', 'halo', 'halo', '', 'halo', 'cops', 'sable', 'sable', 'sable', 'sable']
CREW_NAME = { 'halo': 'HALO', 'lowend': 'LOW END', 'sable': 'SABLE ROW', 'cops': 'AREA 7' }

def caption(kind, t, sub=''):
    import urllib.parse
    key = f'{kind}_{t}_{sub}'.replace(' ', '_').replace('&', 'and').replace('·', '-').replace('/', '_')
    out = f'{CAP}/{key}.png'
    if not os.path.exists(out):
        q = urllib.parse.urlencode({ 'k': kind, 't': t, 's': sub })
        subprocess.run(['node', HERE + '/shot.js', HERE + '/epic_caption.html', out, str(W), str(H), '#c', q], check=True, cwd=HERE)
    return Image.open(out).convert('RGBA')

def ease(x): return 1 - (1 - x) ** 3

# a fixed vignette and some film grain
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
_r = np.sqrt(((xx - W / 2) / (W / 2)) ** 2 + ((yy - H / 2) / (H / 2)) ** 2)
VIG = (1.0 - 0.32 * np.clip(_r - 0.25, 0, None) ** 1.6)[..., None].astype(np.float32)
_gr = np.random.default_rng(7)
GRAIN = [(_gr.standard_normal((H // 2, W // 2)).astype(np.float32) * 0.018) for _ in range(6)]
SH = np.array([-0.05, 0.0, 0.06], np.float32)
HI = np.array([0.05, 0.012, -0.05], np.float32)

def grade(img, i, exp=1.1):
    x = np.asarray(img, np.float32) * (exp / 255.0)
    lum = (x[..., 0] * 0.2126 + x[..., 1] * 0.7152 + x[..., 2] * 0.0722)[..., None]
    x = x * (1 + (1 - np.clip(lum, 0, 1)) * SH + np.clip(lum, 0, 1) * HI)
    x = np.clip(x, 0, 1)
    x = x * x * (3 - 2 * x) * 0.35 + x * 0.65                     # a soft S-curve
    l2 = (x[..., 0] * 0.2126 + x[..., 1] * 0.7152 + x[..., 2] * 0.0722)[..., None]
    x = l2 + (x - l2) * 1.12
    # bloom from the bright parts
    small = Image.fromarray((np.clip(x, 0, 1) * 255).astype(np.uint8)).resize((W // 4, H // 4), Image.BILINEAR)
    sm = np.asarray(small, np.float32) / 255.0
    sm = np.clip(sm - 0.62, 0, None) * 2.2
    bl = Image.fromarray((np.clip(sm, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(9)).resize((W, H), Image.BILINEAR)
    x = x + np.asarray(bl, np.float32) / 255.0 * 0.32
    x = x * VIG
    g = GRAIN[i % len(GRAIN)]
    g = np.repeat(np.repeat(g, 2, 0), 2, 1)[..., None]
    x = x + g
    return Image.fromarray((np.clip(x, 0, 1) * 255).astype(np.uint8))

def letterbox(img, h):
    if h <= 0: return img
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, W, int(h)), fill=(0, 0, 0)); d.rectangle((0, H - int(h), W, H), fill=(0, 0, 0))
    return img

def flash(img, a, col=(255, 255, 255)):
    if a <= 0: return img
    return Image.blend(img, Image.new('RGB', (W, H), col), min(1.0, a))

def shake(img, amt, i):
    if amt <= 0.5: return img
    r = random.Random(i * 7919)
    dx, dy = int((r.random() - 0.5) * amt * 2), int((r.random() - 0.5) * amt * 2)
    return img.transform((W, H), Image.AFFINE, (1, 0, -dx, 0, 1, -dy), resample=Image.BILINEAR)

def put_caption(img, cap, i, n, start=3):
    j = i - start
    if j < 0: return img
    a = min(1.0, j / 7.0) * min(1.0, (n - 1 - i) / 6.0)
    if a <= 0: return img
    s = 1.0 + 0.06 * (1 - ease(min(1.0, j / 10.0)))
    c = cap
    if abs(s - 1) > 1e-3:
        cw, ch = int(W * s), int(H * s)
        c = cap.resize((cw, ch), Image.BILINEAR).crop(((cw - W) // 2, (ch - H) // 2, (cw - W) // 2 + W, (ch - H) // 2 + H))
    if a < 1:
        c = c.copy(); c.putalpha(c.getchannel('A').point(lambda v: int(v * a)))
    base = img.convert('RGBA'); base.alpha_composite(c)
    return base.convert('RGB')

LOGO = Image.open(HERE + '/../../marketing/steam/logo_2194x1265.png').convert('RGBA')
def logo_at(width):
    h = int(LOGO.height * width / LOGO.width)
    return LOGO.resize((int(width), h), Image.LANCZOS)

def glow_logo(width):
    lg = logo_at(width)
    a = lg.getchannel('A').filter(ImageFilter.GaussianBlur(28))
    gl = Image.new('RGBA', lg.size, (255, 110, 50, 0)); gl.putalpha(a.point(lambda v: int(v * 0.55)))
    out = Image.new('RGBA', lg.size); out.alpha_composite(gl); out.alpha_composite(lg)
    return out

class Particles:
    def __init__(self, n, seed, ember=False):
        r = random.Random(seed); self.ember = ember
        self.p = [[r.random() * W, r.random() * H, 1 + r.random() * (2.5 if ember else 3.5), 40 + r.random() * 140, r.random() * 6.28] for _ in range(n)]
    def draw(self, img, i):
        d = ImageDraw.Draw(img, 'RGBA')
        for x, y, s, v, ph in self.p:
            if self.ember:
                yy = (y - v * i / FPS) % H; xx = (x + 26 * math.sin(ph + i / 14)) % W; col = (255, 150 + int(60 * math.sin(ph)), 60, 200)
            else:
                yy = (y + v * i / FPS) % H; xx = (x + 18 * math.sin(ph + i / 20)) % W; col = (255, 255, 255, 150)
            d.ellipse((xx - s, yy - s, xx + s, yy + s), fill=col)

# ---------------------------------------------------------------- the turf map overlay
def load_grid(scene):
    p = f'{FR}/{scene}/grid.json'
    if not os.path.exists(p): return None
    k = W / 1280.0           # the game reports screen points in its 1280x720 base size (stretch mode 2d)
    return [[([q[0] * k, q[1] * k] if q else None) for q in fr] for fr in json.load(open(p))]

def quad(g, b):
    i, j = b % 4, b // 4
    pts = [g[j * 5 + i], g[j * 5 + i + 1], g[(j + 1) * 5 + i + 1], g[(j + 1) * 5 + i]]
    if any(p is None for p in pts): return None
    cx = sum(p[0] for p in pts) / 4; cy = sum(p[1] for p in pts) / 4
    k = 0.86
    return [(cx + (p[0] - cx) * k, cy + (p[1] - cy) * k) for p in pts], (cx, cy)

FONT_TAG = None
def tag_font(size):
    return ImageFont.truetype(GODOT + '/fonts/Inter-Bold.ttf', size)

def map_overlay(img, g, owners, shown, pulse, labels=True, flip_at=None):
    """owners: block -> owner key; shown: block -> 0..1 how far it has faded in; pulse: block -> 0..1 flash"""
    ov = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    # darken everything outside the city
    ring = [g[0 * 5 + i] for i in range(5)] + [g[j * 5 + 4] for j in range(1, 5)] + [g[4 * 5 + i] for i in range(3, -1, -1)] + [g[j * 5] for j in range(3, 0, -1)]
    if all(p is not None for p in ring):
        mask = Image.new('L', (W, H), 255); ImageDraw.Draw(mask).polygon([tuple(p) for p in ring], fill=0)
        mask = mask.filter(ImageFilter.GaussianBlur(30))
        dark = Image.new('RGBA', (W, H), (3, 4, 10, 255)); dark.putalpha(mask.point(lambda v: int(v * 0.72)))
        ov.alpha_composite(dark)
    # the streets, faintly
    for j in range(5):
        row = [g[j * 5 + i] for i in range(5)]
        if all(p is not None for p in row): d.line([tuple(p) for p in row], fill=(255, 255, 255, 40), width=2)
    for i in range(5):
        col = [g[j * 5 + i] for j in range(5)]
        if all(p is not None for p in col): d.line([tuple(p) for p in col], fill=(255, 255, 255, 40), width=2)
    groups = {}
    for b in range(16):
        q = quad(g, b)
        if q is None: continue
        poly, c = q
        o = owners[b]
        a = shown.get(b, 0.0)
        if a <= 0: continue
        col = MINE if o == 'mine' else CREW_COL[o]
        fa = int((125 if o == 'mine' else (95 if o not in ('', 'cops') else 40)) * a + 120 * pulse.get(b, 0.0))
        d.polygon(poly, fill=col + (min(255, fa),), outline=col + (int(230 * a),))
        d.line(poly + [poly[0]], fill=col + (int(230 * a),), width=3)
        groups.setdefault(o, []).append(c)
    if labels:
        for b in range(16):
            q = quad(g, b)
            o = owners[b]
            if q is None or o == '' or shown.get(b, 0.0) < 0.5: continue
            poly, (cx, cy) = q
            name = 'FRL' if o == 'mine' else { 'halo': 'HALO', 'lowend': 'LOW END', 'sable': 'SABLE ROW', 'cops': 'AREA 7' }[o]
            wq = min(abs(poly[1][0] - poly[0][0]), abs(poly[2][0] - poly[3][0]))
            f = tag_font(int(max(14, min(30, wq / 7.5))))
            tw = d.textlength(name, font=f)
            col = MINE if o == 'mine' else CREW_COL[o]
            d.text((cx - tw / 2 + 2, cy - f.size / 2 + 2), name, font=f, fill=(0, 0, 0, 170))
            d.text((cx - tw / 2, cy - f.size / 2), name, font=f, fill=(255, 255, 255, 235))
            d.rectangle((cx - tw / 2, cy + f.size * 0.75, cx + tw / 2, cy + f.size * 0.75 + 3), fill=col + (230,))
    base = img.convert('RGBA'); base.alpha_composite(ov)
    return base.convert('RGB')

BEATF = 60.0 / BPM * FPS        # frames per beat
def map_state(seg, i):
    owners = { b: OWN[b] for b in range(16) }
    shown, pulse = {}, {}
    if seg == 'map':
        order = [('halo', 1), ('lowend', 3), ('sable', 5), ('cops', 7)]
        for o, beat in order:
            t = (i - beat * BEATF) / 6.0
            for b in range(16):
                if OWN[b] == o:
                    shown[b] = max(0.0, min(1.0, t))
                    if 0 <= t < 2: pulse[b] = max(0.0, 1 - t / 2)
        t2 = (i - 8 * BEATF) / 4.0
        for b in range(16):
            if OWN[b] == '':
                shown[b] = max(0.0, min(1.0, t2)) * (0.6 + 0.4 * abs(math.sin(i * 0.25)))
    else:   # map2: your colour spreading, a block a beat
        for b in range(16): shown[b] = 1.0
        order = [5, 9, 6, 10, 1, 2, 13, 14]
        for k, b in enumerate(order):
            t = (i - k * BEATF) / 3.0
            if t >= 0:
                owners[b] = 'mine'
                if t < 3: pulse[b] = max(0.0, 1 - t / 3)
    return owners, shown, pulse

# ---------------------------------------------------------------- assembling
CTAS = { 'wishlist': ('WISHLIST NOW', 'ON STEAM'), 'outnow': ('AVAILABLE NOW', 'ON STEAM') }
STILL_AT = { 'halo': 30, 'low': 30, 'sable': 30, 'take': 60, 'fp': 30, 'cars': 50, 'ride': 30, 'boom': 20, 'raid': 60, 'win': 50,
             'drift': 30, 'walk': 60, 'finale': 60, 'cars2': 25, 'take2': 30, 'raid2': 25 }

def encoder(out):
    return subprocess.Popen(['ffmpeg', '-y', '-v', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{W}x{H}', '-r', str(FPS), '-i', '-',
                             '-vf', 'format=yuv420p', '-c:v', 'libx264', '-preset', 'slow', '-crf', '17', '-profile:v', 'high',
                             '-x264-params', 'keyint=60', '-r', str(FPS), out], stdin=subprocess.PIPE)

def seg_list():
    out = []
    for seg, sc, b0, nb, off in TL:
        n = fb(b0 + nb) - fb(b0)
        files, s0 = [], 0
        if sc:
            s0 = fb(off) if off else 0
            files = sorted(glob.glob(f'{FR}/{sc}/*.png'))[s0:s0 + n]
            if len(files) < n: raise SystemExit(f'{seg}: {sc} has {len(files)} of {n} frames')
        out.append((seg, sc, b0, nb, n, files, s0))
    return out

def edit():
    segs = seg_list()
    total = fb(END_BAR) + int(TAIL * FPS)
    encs = { k: encoder(f'{WORK}/video_{k}.mp4') for k in CTAS }
    caps = { k: caption(*v[:3]) for k, v in CAPTIONS.items() }
    cap_take = caption('title', 'TAKE YOURS'); cap_run = caption('title', 'RUN THE CITY')
    cap_win = caption('banner', 'TOOK BISHOP & CALDER', '[FRL]  ·  $168 OFF THE CORNER  ·  $280 A DAY')
    cap_tag = caption('tag', 'MAKE YOUR NAME IN THE SNOW')
    cap_end = { k: caption('end', *v) for k, v in CTAS.items() }
    snow = Particles(220, 3); embers = Particles(90, 11, True)
    last_map = None
    frame_no = 0
    def emit(img, variants=None):
        nonlocal frame_no
        b = img.tobytes()
        for k, p in encs.items():
            p.stdin.write(variants[k].tobytes() if variants else b)
        frame_no += 1
    for seg, sc, b0, nb, n, files, s0 in segs:
        log(f'{seg}: {n} frames from bar {b0}')
        grid = load_grid(sc) if seg in ('map', 'map2') else None
        for i in range(n):
            if seg == 'logo':
                bg = last_map if last_map is not None else Image.new('RGB', (W, H))
                img = ImageEnhance.Brightness(bg.filter(ImageFilter.GaussianBlur(10))).enhance(0.32).convert('RGBA')
                glow = Image.new('RGBA', (W, H), (0, 0, 0, 0)); gd = ImageDraw.Draw(glow)
                for r, a in ((620, 26), (420, 40), (250, 60)):
                    gd.ellipse((W / 2 - r * 1.6, H / 2 - r, W / 2 + r * 1.6, H / 2 + r), fill=(255, 90, 40, a))
                img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(60)))
                sc_ = 1.0 + 0.38 * math.exp(-i / 3.0)
                lg = glow_logo(1180 * sc_)
                r = random.Random(i)
                sh = 26 * math.exp(-i / 4.0)
                x = int(W / 2 - lg.width / 2 + (r.random() - 0.5) * sh); y = int(H / 2 - lg.height / 2 - 10 + (r.random() - 0.5) * sh)
                img.alpha_composite(lg, (max(0, x), max(0, y)), (max(0, -x), max(0, -y)))
                embers.draw(img, i); snow.draw(img, i)
                img = img.convert('RGB')
                img = flash(img, 0.9 - i * 0.22)
                lb = LB * (1 - ease(max(0.0, min(1.0, (i - 30) / 18.0))))
                emit(letterbox(img, lb))
                continue
            k = int(os.path.basename(files[i])[:5])
            img = grade(Image.open(files[i]).convert('RGB'), i + b0 * 100, GRADE.get(seg, 1.1))
            if seg in STILL_AT and i == STILL_AT[seg]: img.save(f'{STILLS}/{seg}.png')
            if seg == 'finale' and i in (40, 90, 150): img.save(f'{STILLS}/finale_{i}.png')
            if grid is not None and k < len(grid):
                owners, shown, pulse = map_state(seg, i)
                img = map_overlay(img, grid[k], owners, shown, pulse)
                if seg == 'map':
                    last_map = img.copy()
                    if i >= int(8 * BEATF): img = put_caption(img, cap_take, i, n, int(8 * BEATF))
                else:
                    if i >= int(4 * BEATF): img = put_caption(img, cap_run, i, n, int(4 * BEATF))
            if seg in caps: img = put_caption(img, caps[seg], i, n, CAPTIONS[seg][3])
            if seg == 'win': img = put_caption(img, cap_win, i, n, 4)
            # hits
            if seg == 'take' and i < 4: img = flash(img, 0.45 - i * 0.12)
            if seg == 'boom':
                if 13 <= i < 18: img = flash(img, (18 - i) * 0.12, (255, 200, 140))
                if i >= 13: img = shake(img, 22 * math.exp(-(i - 13) / 9.0), i)
            if seg == 'punch' and i < 3: img = flash(img, 0.25 - i * 0.08)
            if seg == 'drift' and i < 5:
                img = flash(img, 0.7 - i * 0.15); img = shake(img, 14 - i * 3, i)
            lb = 0
            if b0 < 8: lb = LB
            if seg == 'finale':
                lb = LB * ease(min(1.0, i / 14.0))
                L0, E0 = fb(41) - fb(39), fb(43) - fb(39)
                if i >= L0:
                    j = i - L0
                    img = ImageEnhance.Brightness(img).enhance(1 - 0.42 * min(1.0, j / 6.0)).convert('RGBA')
                    sc_ = 1.0 + 0.3 * math.exp(-j / 3.0)
                    lg = glow_logo(880 * sc_)
                    x = int(W / 2 - lg.width / 2); y = int(330 - lg.height / 2)
                    img.alpha_composite(lg, (max(0, x), max(0, y)), (max(0, -x), max(0, -y)))
                    img = img.convert('RGB')
                    img = shake(img, 18 * math.exp(-j / 4.0), i)
                    img = flash(img, 0.85 - j * 0.2)
                    if j >= 22: img = put_caption(img, cap_tag, i, n + 999, L0 + 22)
                fo = (i - (n - 22)) / 22.0
                img = letterbox(img, lb)
                if i >= E0:
                    vs = {}
                    for kk, ce in cap_end.items():
                        v = put_caption(img, ce, i, n + 999, E0)
                        if fo > 0: v = flash(v, min(1.0, fo), (0, 0, 0))
                        vs[kk] = v
                    emit(img, vs)
                    continue
                if fo > 0: img = flash(img, min(1.0, fo), (0, 0, 0))
                emit(img)
                continue
            emit(letterbox(img, lb))
    black = Image.new('RGB', (W, H))
    while frame_no < total: emit(black)
    for p in encs.values():
        p.stdin.close(); p.wait()
    log('video frames', frame_no)
    return total

# ---------------------------------------------------------------- sound
def load_wav(path, sr=48000):
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', path, '-ac', '2', '-ar', str(sr), '-f', 'f32le', '-'], capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, 2).copy()

def sfx_file(name):
    for base in GODOT_SFX:
        if os.path.exists(base + name + '.ogg'): return base + name + '.ogg'
        alts = sorted(glob.glob(base + name + '_[0-9].ogg'))
        if alts: return random.choice(alts)
    return None

def build_audio(total):
    sr = 48000
    n = int(total / FPS * sr) + sr
    mix = np.zeros((n, 2), np.float32)
    random.seed(9)
    cache = {}
    def put(name, t, vol=1.0, pitch=1.0):
        f = sfx_file(name)
        if f is None or t < 0: return
        if f not in cache: cache[f] = load_wav(f, sr)
        a = cache[f]
        if pitch != 1.0:
            idx = np.arange(0, len(a) - 1, pitch)
            a = np.stack([np.interp(idx, np.arange(len(a)), a[:, c]) for c in (0, 1)], 1).astype(np.float32)
        s = int(t * sr); e = min(n, s + len(a))
        if e > s: mix[s:e] += a[:e - s] * vol
    for seg, sc, b0, nb, n_, files, s0 in seg_list():
        t0 = fb(b0) / FPS
        evf = f'{FR}/{sc}/events.txt' if sc else None
        if evf and os.path.exists(evf):
            for line in open(evf):
                k, nm, vol, pitch = line.split()
                k = int(k)
                if not (s0 <= k < s0 + n_): continue
                vol, pitch = float(vol), float(pitch)
                if nm == 'train_pass': nm = 'train_horn'
                if seg == 'boom' and nm == 'car_explode':
                    put('car_explode', t0 + (k - s0) / FPS, 1.0, 0.72); put('boom', t0 + (k - s0) / FPS, 0.8, 0.6)
                    continue
                put(nm, t0 + (k - s0) / FPS, vol * 0.5, pitch)
        tb = lambda beats: t0 + beats * 60.0 / BPM
        if seg == 'map':
            for bt in (1, 3, 5, 7): put('pop', tb(bt), 0.35, 0.8)
        if seg == 'map2':
            for bt in range(8): put('chime', tb(bt), 0.22, 1.0 + bt * 0.04)
        if seg == 'win': put('cash', t0 + 0.25, 0.55)
        if seg == 'chase': put('siren_far', t0, 0.45)
        if seg == 'drift': put('skid', t0, 0.5); put('skid', t0 + 0.9, 0.4)
        if seg in ('cars', 'cars2', 'ride'): put('car_pass', t0 + 0.4, 0.45)
        if seg == 'train': put('train_horn', t0 + 0.2, 0.35)
        if seg in ('walk', 'finale'): put('crackle', t0, 0.35)
        if seg == 'open': put('wind', t0, 0.35)
    wav = WORK + '/sfx.wav'
    with wave.open(wav, 'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(sr)
        w.writeframes((np.clip(mix, -1, 1) * 32767).astype('<i2').tobytes())
    dur = total / FPS
    raw = WORK + '/audio_raw.wav'
    subprocess.run(['ffmpeg', '-y', '-v', 'error', '-i', WORK + '/score.wav', '-i', wav, '-filter_complex',
                    f'[0:a]atrim=0:{dur},afade=t=out:st={dur - 1.8}:d=1.8[m];[1:a]volume=0.8[s];[m][s]amix=inputs=2:normalize=0',
                    '-ar', '48000', '-ac', '2', '-c:a', 'pcm_f32le', raw], check=True)
    r = subprocess.run(['ffmpeg', '-v', 'info', '-i', raw, '-af', 'ebur128=framelog=quiet', '-f', 'null', '-'], capture_output=True, text=True)
    I = [l for l in r.stderr.split('\n') if l.strip().startswith('I:')][-1].split()[1]
    gain = -14.0 - float(I)
    out = WORK + '/audio.wav'
    subprocess.run(['ffmpeg', '-y', '-v', 'error', '-i', raw, '-af', f'volume={gain:.2f}dB,alimiter=limit=0.89:attack=2:release=80:level=false', '-ar', '48000', out], check=True)
    log('audio: measured', I, 'LUFS, gain', round(gain, 2), 'dB')
    return out

if __name__ == '__main__' and len(sys.argv) > 1 and sys.argv[1] in ('edit', 'audio'):
    total = fb(END_BAR) + int(TAIL * FPS)
    if sys.argv[1] == 'edit': edit()
    audio = build_audio(total)
    for k in CTAS:
        v = f'{WORK}/video_{k}.mp4'
        if not os.path.exists(v): continue
        out = f'{WORK}/DrillSeason-Trailer-TurfWars-1080p-{k}.mp4'
        subprocess.run(['ffmpeg', '-y', '-v', 'error', '-i', v, '-i', audio, '-c:v', 'copy', '-c:a', 'aac', '-b:a', '320k', '-shortest',
                        '-movflags', '+faststart', out], check=True)
        subprocess.run(['ffmpeg', '-y', '-v', 'error', '-i', out, '-vf', 'scale=1280:720:flags=lanczos', '-c:v', 'libx264', '-preset', 'slow', '-crf', '24',
                        '-maxrate', '3500k', '-bufsize', '7000k', '-c:a', 'aac', '-b:a', '160k', '-movflags', '+faststart', out.replace('1080p', '720p')], check=True)
        log('wrote', out)
