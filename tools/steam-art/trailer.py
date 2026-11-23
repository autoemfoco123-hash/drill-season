#!/usr/bin/env python3
"""Builds the Drill Season trailer: renders each shot in the game (Trailer.gd), cuts them on the
beat of WCLD 91.1's track, adds captions, the logo slam, the end card, the music and the sound
effects, and writes a 1080p master for Steam and a light 720p copy for the web.
Usage: trailer.py [shot ...]   (no args: everything; shots already encoded are kept)"""
import os, sys, glob, json, shutil, subprocess, random, math
import numpy as np
from PIL import Image, ImageFilter, ImageEnhance

HERE = os.path.dirname(os.path.abspath(__file__))
SP = os.environ.get('DS_WORK', HERE + '/work')            # renders, segments and the output land here
TR = SP + '/trailer'
GODOT = os.path.normpath(HERE + '/../../godot')
FR, SEG, STILLS, CAP = TR + '/frames', TR + '/seg', TR + '/stills', TR + '/cap'   # cap: caption PNGs from caption.html
for d in (FR, SEG, STILLS): os.makedirs(d, exist_ok=True)
FPS = 30
W, H = 1920, 1080
BEAT = 60 / 139.5
T0, DROP1, QUIET2, DROP2, END = 37.40, 44.02, 75.22, 85.16, 90.80
MUSIC = GODOT + '/assets/music/wcld.ogg'

# ---------- the timeline, in music time ----------
cuts = [('open', T0), ('crew', T0 + 3.30), ('logo', DROP1)]
t = DROP1 + 4 * BEAT
for name, beats in [('walk', 6), ('drive', 8), ('chase', 6), ('shoot_fp', 8), ('gunfight', 6), ('punch', 4), ('ragdoll', 5),
                    ('studio', 6), ('phone', 4), ('wardrobe', 4), ('interior', 4), ('console', 7.5)]:
    cuts.append((name, t)); t += beats * BEAT
cuts += [('train', QUIET2), ('storm', QUIET2 + 3.30), ('dances', QUIET2 + 6.55), ('hero', DROP2)]
bounds = [c[1] for c in cuts] + [END]
fr = [round((b - T0) * FPS) for b in bounds]
SHOTS = [(cuts[i][0], fr[i], fr[i + 1] - fr[i]) for i in range(len(cuts))]   # name, first frame, frames
CAPTIONS = { 'open': 'calder', 'walk': 'name', 'drive': 'block', 'studio': 'studio', 'console': 'tv', 'dances': 'dances' }
GRADE = 'eq=contrast=1.05:saturation=1.14:gamma=0.98'

def log(*a): print(*a, flush=True)

def encoder(out, grade=True):
    vf = (GRADE + ',' if grade else '') + 'format=yuv420p'
    return subprocess.Popen(['ffmpeg', '-y', '-v', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{W}x{H}', '-r', str(FPS), '-i', '-',
                             '-vf', vf, '-c:v', 'libx264', '-preset', 'medium', '-crf', '15', '-profile:v', 'high', '-r', str(FPS), out], stdin=subprocess.PIPE)

def ease(x): return 1 - (1 - x) ** 3

def caption_frame(img, cap, i, n):
    # slides in from the left over 8 frames, fades out over the last 6
    a = min(1.0, i / 8.0) * min(1.0, (n - 1 - i) / 6.0)
    if a <= 0: return img
    c = cap.copy()
    if a < 1: c.putalpha(c.getchannel('A').point(lambda v: int(v * a)))
    dx = int(-50 * (1 - ease(min(1.0, i / 8.0))))
    base = img.convert('RGBA')
    base.alpha_composite(c, (dx, 0) if dx >= 0 else (0, 0), (max(0, -dx), 0))
    return base.convert('RGB')

def render(name, n):
    out = f'{SEG}/{name}.mp4'
    if os.path.exists(out): return
    d = f'{FR}/{name}'
    shutil.rmtree(d, ignore_errors=True)
    env = dict(os.environ, DS_TRAILER=name, DS_FRAMES=str(n), DS_SHOTS=FR, HOME=SP + '/gdhome')
    if name == 'console': env.update(DS_CONSOLE='1', DS_FAKEPAD='xbox')
    cmd = ['timeout', '1500', 'xvfb-run', '-a', '-s', '-screen 0 1920x1080x24', 'godot3', '--path', '.', '--audio-driver', 'Dummy',
           '--resolution', '1920x1080', '--fixed-fps', '30', '--autotest']
    r = subprocess.run(cmd, cwd=GODOT, env=env, capture_output=True, text=True)
    errs = [l for l in (r.stdout + r.stderr).split('\n') if 'SCRIPT ERROR' in l]
    frames = sorted(glob.glob(d + '/*.png'))
    log(f'{name}: {len(frames)}/{n} frames, exit {r.returncode}', errs[:3])
    if len(frames) < n: raise SystemExit(f'{name} came out short')
    cap = Image.open(f'{CAP}/{CAPTIONS[name]}.png') if name in CAPTIONS else None
    p = encoder(out)
    for i, f in enumerate(frames[:n]):
        img = Image.open(f).convert('RGB')
        if cap is not None and i >= 6: img = caption_frame(img, cap, i - 6, n - 6)
        p.stdin.write(img.tobytes())
    p.stdin.close(); p.wait()
    for k, q in enumerate((0.25, 0.55, 0.85)):
        shutil.copy(frames[int(q * (n - 1))], f'{STILLS}/{name}_{k}.png')
    shutil.copy(frames[-1], f'{STILLS}/{name}_last.png')
    shutil.copy(frames[0], f'{STILLS}/{name}_first.png')
    if os.path.exists(d + '/events.txt'): shutil.copy(d + '/events.txt', f'{SEG}/{name}.events')
    shutil.rmtree(d)

LOGO = Image.open(os.environ.get('DS_LOGO', HERE + '/../../marketing/steam/logo_2194x1265.png')).convert('RGBA')

def logo_at(width):
    h = int(LOGO.height * width / LOGO.width)
    return LOGO.resize((int(width), h), Image.LANCZOS)

class Snow:
    def __init__(self, n, seed):
        r = random.Random(seed)
        self.p = [[r.random() * W, r.random() * H, 1 + r.random() * 4, 60 + r.random() * 160, r.random() * 6.28] for _ in range(n)]
    def draw(self, img, i):
        from PIL import ImageDraw
        d = ImageDraw.Draw(img, 'RGBA')
        for x, y, s, v, ph in self.p:
            yy = (y + v * i / FPS) % H
            xx = (x + 18 * math.sin(ph + i / 20)) % W
            d.ellipse((xx - s, yy - s, xx + s, yy + s), fill=(255, 255, 255, 170))

def logo_slam(n):
    out = f'{SEG}/logo.mp4'
    if os.path.exists(out): return
    bg = Image.open(f'{STILLS}/crew_last.png').convert('RGB').filter(ImageFilter.GaussianBlur(8))
    bg = ImageEnhance.Brightness(bg).enhance(0.38)
    snow = Snow(260, 3)
    r = random.Random(5)
    p = encoder(out)
    for i in range(n):
        img = bg.copy().convert('RGBA')
        s = 1.0 + 0.42 * math.exp(-i / 3.2)
        lg = logo_at(1240 * s)
        sh = 22 * math.exp(-i / 4.0)
        x = int(W / 2 - lg.width / 2 + (r.random() - 0.5) * sh)
        y = int(H / 2 - lg.height / 2 - 20 + (r.random() - 0.5) * sh)
        img.alpha_composite(lg, (max(0, x), max(0, y)), (max(0, -x), max(0, -y)))
        snow.draw(img, i)
        fl = max(0.0, 0.85 - i * 0.2)
        if fl > 0: img = Image.blend(img, Image.new('RGBA', (W, H), (255, 255, 255, 255)), fl)
        p.stdin.write(img.convert('RGB').tobytes())
    p.stdin.close(); p.wait()

def hero_card(n):
    # the hero shot with the logo landing on the drop, the platforms, then a fade to black
    out = f'{SEG}/hero_card.mp4'
    if os.path.exists(out): return
    raw = f'{SEG}/hero.mp4'
    dec = subprocess.Popen(['ffmpeg', '-v', 'error', '-i', raw, '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'], stdout=subprocess.PIPE)
    end = Image.open(f'{CAP}/end.png')
    p = encoder(out, grade=False)
    for i in range(n):
        buf = dec.stdout.read(W * H * 3)
        if len(buf) < W * H * 3: break
        img = Image.frombytes('RGB', (W, H), buf).convert('RGBA')
        dark = Image.new('RGBA', (W, H), (4, 5, 14, int(110 * min(1, i / 6))))
        img.alpha_composite(dark)
        s = 1.0 + 0.32 * math.exp(-i / 3.2)
        lg = logo_at(1000 * s)
        x = int(W / 2 - lg.width / 2); y = int(400 - lg.height / 2)
        img.alpha_composite(lg, (max(0, x), max(0, y)), (max(0, -x), max(0, -y)))
        if i >= 40:
            e = end.copy(); a = min(1.0, (i - 40) / 12.0)
            e.putalpha(e.getchannel('A').point(lambda v: int(v * a)))
            img.alpha_composite(e)
        fl = max(0.0, 0.8 - i * 0.2)
        if fl > 0: img = Image.blend(img, Image.new('RGBA', (W, H), (255, 255, 255, 255)), fl)
        fo = (i - (n - 16)) / 16.0
        if fo > 0: img = Image.blend(img, Image.new('RGBA', (W, H), (0, 0, 0, 255)), min(1.0, fo))
        p.stdin.write(img.convert('RGB').tobytes())
    dec.stdout.close(); dec.wait()
    p.stdin.close(); p.wait()

def load_wav(path, sr=48000):
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', path, '-ac', '2', '-ar', str(sr), '-f', 'f32le', '-'], capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, 2).copy()

def sfx_file(name):
    for base in (GODOT + '/assets/sfx/', GODOT + '/assets/sfx2/'):
        for cand in (name + '.ogg', name + '_0.ogg'):
            if os.path.exists(base + cand):
                if cand.endswith('_0.ogg'):
                    alts = sorted(glob.glob(base + name + '_[0-9].ogg'))
                    return random.choice(alts)
                return base + cand
    return None

def build_audio(total_frames):
    sr = 48000
    n = int(total_frames / FPS * sr) + sr
    mix = np.zeros((n, 2), np.float32)
    random.seed(9)
    def put(name, t, vol=1.0, pitch=1.0):
        f = sfx_file(name)
        if f is None or t < 0: return
        a = load_wav(f, sr)
        if pitch != 1.0:
            idx = np.arange(0, len(a) - 1, pitch)
            a = np.stack([np.interp(idx, np.arange(len(a)), a[:, c]) for c in (0, 1)], 1).astype(np.float32)
        s = int(t * sr); e = min(n, s + len(a))
        mix[s:e] += a[:e - s] * vol
    start = { name: f0 for name, f0, _ in SHOTS }
    for name, f0, cnt in SHOTS:
        evf = f'{SEG}/{name}.events'
        if not os.path.exists(evf): continue
        for line in open(evf):
            k, nm, vol, pitch = line.split()
            fname = { 'train_pass': 'train_horn' }.get(nm, nm)
            put(fname, (f0 + int(k)) / FPS, float(vol) * 0.55, float(pitch))
    put('riser', (DROP1 - T0) - 2.1, 0.45)
    put('boom', DROP1 - T0, 0.9)
    put('stab', DROP1 - T0, 0.5)
    put('siren_far', start['chase'] / FPS, 0.5)
    put('vinyl', (QUIET2 - T0) - 0.25, 0.55)
    put('whoosh', start['train'] / FPS + 0.3, 0.5)
    put('riser', (DROP2 - T0) - 2.1, 0.45)
    put('boom', DROP2 - T0, 0.95)
    wav = TR + '/sfx.wav'
    import wave
    with wave.open(wav, 'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(sr)
        w.writeframes((np.clip(mix, -1, 1) * 32767).astype('<i2').tobytes())
    dur = total_frames / FPS
    raw = TR + '/audio_raw.wav'
    subprocess.run(['ffmpeg', '-y', '-v', 'error', '-ss', str(T0), '-t', str(dur), '-i', MUSIC, '-i', wav, '-filter_complex',
                    f'[0:a]aresample=48000,volume=0.9,afade=t=out:st={dur - 1.4}:d=1.4[m];[1:a]volume=1.0[s];[m][s]amix=inputs=2:normalize=0',
                    '-ar', '48000', '-ac', '2', '-c:a', 'pcm_f32le', raw], check=True)
    # one fixed gain to about -14 LUFS and a limiter on the peaks: the quiet intro stays quiet, the drop hits
    r = subprocess.run(['ffmpeg', '-v', 'info', '-i', raw, '-af', 'ebur128=framelog=quiet', '-f', 'null', '-'], capture_output=True, text=True)
    I = [l for l in r.stderr.split('\n') if l.strip().startswith('I:')][-1].split()[1]
    gain = -14.0 - float(I)
    out = TR + '/audio.wav'
    subprocess.run(['ffmpeg', '-y', '-v', 'error', '-i', raw, '-af', f'volume={gain:.2f}dB,alimiter=limit=0.84:attack=1:release=60:level=false', '-ar', '48000', out], check=True)
    log('audio: measured', I, 'LUFS, gain', round(gain, 2), 'dB')
    return out

def main():
    only = sys.argv[1:]
    for name, f0, n in SHOTS:
        if only and name not in only: continue
        if name == 'logo': continue
        render(name, n)
    if not only or 'logo' in only:
        logo_slam(dict((s[0], s[2]) for s in SHOTS)['logo'])
    if os.path.exists(f'{SEG}/hero.mp4'):
        hero_card(dict((s[0], s[2]) for s in SHOTS)['hero'])
    if only: return
    lst = TR + '/concat.txt'
    with open(lst, 'w') as fl:
        for name, _, _ in SHOTS:
            fl.write(f"file '{SEG}/{'hero_card' if name == 'hero' else name}.mp4'\n")
    total = fr[-1]
    subprocess.run(['ffmpeg', '-y', '-v', 'error', '-f', 'concat', '-safe', '0', '-i', lst, '-c', 'copy', TR + '/video.mp4'], check=True)
    audio = build_audio(total)
    subprocess.run(['ffmpeg', '-y', '-v', 'error', '-i', TR + '/video.mp4', '-i', audio, '-c:v', 'copy', '-c:a', 'aac', '-b:a', '320k',
                    '-shortest', '-movflags', '+faststart', TR + '/DrillSeason-trailer-1080p.mp4'], check=True)
    subprocess.run(['ffmpeg', '-y', '-v', 'error', '-i', TR + '/DrillSeason-trailer-1080p.mp4', '-vf', 'scale=1280:720:flags=lanczos',
                    '-c:v', 'libx264', '-preset', 'slow', '-crf', '27', '-maxrate', '2200k', '-bufsize', '4400k', '-c:a', 'aac', '-b:a', '128k',
                    '-movflags', '+faststart', TR + '/DrillSeason-trailer-720p.mp4'], check=True)
    log('done', total, 'frames')

if __name__ == '__main__':
    log('shots:', [(s[0], s[2]) for s in SHOTS], 'total', fr[-1])
    main()
