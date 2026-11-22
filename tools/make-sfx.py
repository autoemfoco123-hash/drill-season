#!/usr/bin/env python3
"""Synthesizes the Godot version's extra ambience and car sounds into godot/assets/sfx2/*.ogg:
wind (seamless loop), city (distant city bed, seamless loop), starter (engine start),
creak_0..2 (lake ice), shift (gear change clunk), whoosh_car (a car passing close),
crackle (fire barrel loop). Needs numpy and ffmpeg. Usage: python3 tools/make-sfx.py"""
import numpy as np, subprocess, os, wave, sys

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'godot', 'assets', 'sfx2')
rng = np.random.default_rng(7)

def lp(x, fc):
    a = np.exp(-2 * np.pi * fc / SR)
    y = np.empty_like(x); s = 0.0
    for i in range(len(x)):
        s = (1 - a) * x[i] + a * s; y[i] = s
    return y

def lp_fast(x, fc):
    # one-pole low-pass via FFT-free recursion in chunks (vectorised with scipy-free trick)
    from numpy.fft import rfft, irfft, rfftfreq
    X = rfft(x); f = rfftfreq(len(x), 1 / SR)
    H = 1 / np.sqrt(1 + (f / fc) ** 2)
    return irfft(X * H, len(x))

def band(x, f0, q):
    from numpy.fft import rfft, irfft, rfftfreq
    X = rfft(x); f = rfftfreq(len(x), 1 / SR) + 1e-6
    H = 1 / (1 + 1j * q * (f / f0 - f0 / f))
    return irfft(X * H, len(x))

def pink(n):
    from numpy.fft import rfft, irfft, rfftfreq
    w = rng.standard_normal(n)
    X = rfft(w); f = rfftfreq(n, 1 / SR); f[0] = 1
    return irfft(X / np.sqrt(f), n)

def brown(n):
    from numpy.fft import rfft, irfft, rfftfreq
    w = rng.standard_normal(n)
    X = rfft(w); f = rfftfreq(n, 1 / SR); f[0] = 1
    return irfft(X / f, n)

def smooth_noise(n, rate):
    # a slow random curve between 0 and 1
    k = max(2, int(n / SR * rate) + 2)
    pts = rng.random(k)
    xs = np.linspace(0, k - 1, n)
    i = np.floor(xs).astype(int); t = xs - i
    t = t * t * (3 - 2 * t)
    i2 = np.minimum(i + 1, k - 1)
    return pts[i] * (1 - t) + pts[i2] * t

def norm(x, peak=0.9):
    m = np.max(np.abs(x)) or 1
    return x / m * peak

def seamless(x, fade_s=1.5):
    n = int(fade_s * SR)
    head = x[:n].copy(); body = x[n:].copy()
    t = np.linspace(0, 1, n)
    body[-n:] = body[-n:] * np.cos(t * np.pi / 2) + head * np.sin(t * np.pi / 2)
    return body

def write(name, x, stereo=None, q=5):
    os.makedirs(OUT, exist_ok=True)
    wav = os.path.join(OUT, name + '.wav')
    data = np.stack([x, stereo], 1) if stereo is not None else x[:, None]
    data = np.clip(data, -1, 1)
    with wave.open(wav, 'wb') as w:
        w.setnchannels(data.shape[1]); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((data * 32767).astype('<i2').tobytes())
    ogg = os.path.join(OUT, name + '.ogg')
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-c:a', 'libvorbis', '-q:a', str(q), ogg], check=True)
    os.remove(wav)
    print(name, '%.1fs' % (len(x) / SR), '%d KB' % (os.path.getsize(ogg) // 1024))

def env(n, a, d):
    t = np.arange(n) / SR
    return np.minimum(1, t / max(a, 1e-4)) * np.exp(-t / d)

def reverb(x, secs=1.8, wet=0.3):
    n = int(secs * SR)
    ir = rng.standard_normal(n) * np.exp(-np.arange(n) / SR * 6.9 / secs)
    ir = lp_fast(ir, 3500)
    from numpy.fft import rfft, irfft
    L = len(x) + n
    y = irfft(rfft(x, L) * rfft(ir, L), L)[:len(x)]
    return x * (1 - wet) + norm(y, np.max(np.abs(x))) * wet

# ---- wind: gusting band-passed noise with a faint whistle, 24 s loop, stereo ----
def wind():
    n = SR * 26
    chans = []
    for c in range(2):
        p = pink(n)
        g = 0.25 + 0.75 * smooth_noise(n, 0.35) ** 1.6
        lo = band(p, 380, 0.7) * g
        hi = band(p, 1200, 2.0) * g ** 2 * 0.5
        wh = band(rng.standard_normal(n), 1650 + 300 * c, 18) * (g ** 3) * 0.35
        chans.append(seamless(lo + hi + wh))
    m = max(np.max(np.abs(chans[0])), np.max(np.abs(chans[1])))
    write('wind', chans[0] / m * 0.8, chans[1] / m * 0.8)

# ---- city: distant rumble, traffic swells, far horns and a far siren, 30 s loop ----
def city():
    n = SR * 32
    base = lp_fast(brown(n), 160)
    base = norm(base, 0.5)
    swells = np.zeros(n)
    t = np.arange(n) / SR
    for _ in range(14):
        c = rng.uniform(1, 30); w = rng.uniform(1.5, 4)
        g = np.exp(-((t - c) / w) ** 2)
        nz = band(rng.standard_normal(n), rng.uniform(180, 420), 1.2)
        swells += nz * g * rng.uniform(0.15, 0.35)
    horns = np.zeros(n)
    for _ in range(3):
        c = rng.uniform(2, 28); f = rng.uniform(330, 420); d = rng.uniform(0.2, 0.6)
        m = (t > c) & (t < c + d)
        horns[m] += (np.sign(np.sin(2 * np.pi * f * t[m])) + 0.6 * np.sign(np.sin(2 * np.pi * f * 1.26 * t[m]))) * 0.04
    siren_c = rng.uniform(8, 20)
    sm = (t > siren_c) & (t < siren_c + 6)
    sf = 700 + 250 * np.sin(2 * np.pi * 0.35 * (t[sm] - siren_c))
    siren = np.zeros(n); siren[sm] = np.sin(2 * np.pi * np.cumsum(sf) / SR) * 0.03 * np.sin(np.pi * (t[sm] - siren_c) / 6)
    x = base + lp_fast(swells, 1400) + lp_fast(horns + siren, 1800)
    x = reverb(x, 2.5, 0.45)
    x = seamless(norm(x, 0.8))
    write('city', x)

# ---- starter: the starter motor cranking, then the engine catching ----
def starter():
    n = int(SR * 1.1)
    t = np.arange(n) / SR
    f = 13 + 9 * np.minimum(1, t / 0.7)
    ph = 2 * np.pi * np.cumsum(f) / SR
    crank = (np.mod(ph, 2 * np.pi) < 1.2).astype(float)
    crank = band(crank * (0.6 + 0.4 * rng.random(n)), 520, 1.3)
    whine = np.sin(2 * np.pi * np.cumsum(900 + 600 * np.minimum(1, t / 0.7)) / SR) * 0.08
    body = (crank + whine) * np.where(t < 0.78, 1, np.exp(-(t - 0.78) * 20))
    catch = np.zeros(n); k = int(0.72 * SR)
    burst = band(rng.standard_normal(n - k), 140, 0.8) * env(n - k, 0.005, 0.18)
    catch[k:] = burst * 2.2
    x = norm(lp_fast(body + catch, 4500), 0.85)
    write('starter', x)

# ---- ice creaks: resonant groans with fast pitch glides and crackle ----
def creaks():
    for i in range(3):
        n = int(SR * rng.uniform(1.2, 2.2))
        t = np.arange(n) / SR
        f0 = rng.uniform(70, 160)
        f = f0 * (1 + 2.5 * smooth_noise(n, 6) ** 2)
        tone = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.5 * np.sin(4 * np.pi * np.cumsum(f) / SR + 1)
        am = smooth_noise(n, 12) ** 3 * env(n, 0.05, 0.7)
        crack = (rng.random(n) < 0.002).astype(float) * rng.standard_normal(n)
        crack = band(crack, 2500, 2) * 3
        x = (tone * am + crack * env(n, 0.01, 0.5)) * np.sin(np.pi * t / t[-1]) ** 0.3
        x = reverb(x, 2.0, 0.4)
        write('creak_%d' % i, norm(x, 0.8))

# ---- gear shift: a dull mechanical clunk ----
def shift():
    n = int(SR * 0.3)
    x = band(rng.standard_normal(n), 220, 1.5) * env(n, 0.002, 0.05) + band(rng.standard_normal(n), 1400, 3) * env(n, 0.001, 0.02) * 0.4
    write('shift', norm(x, 0.7))

# ---- a car passing close (whoosh with doppler) ----
def pass_by():
    n = int(SR * 2.4)
    t = np.arange(n) / SR - 1.2
    d = np.sqrt(t ** 2 * 15 ** 2 + 3 ** 2)
    g = 1 / d ** 1.2
    p = pink(n)
    w = band(p, 600, 0.6) * g
    eng = np.sin(2 * np.pi * np.cumsum(55 * (1 - 0.12 * np.tanh(t * 3))) / SR) * g * 0.6
    x = lp_fast(w + eng, 5000)
    write('car_pass', norm(x, 0.85))

# ---- fire crackle loop ----
def crackle():
    n = SR * 12
    roar = lp_fast(brown(n), 400) * 0.6
    pops = (rng.random(n) < 0.0009).astype(float) * rng.random(n)
    pops = band(pops, 3000, 1.2) * 6 + band((rng.random(n) < 0.004).astype(float), 1800, 3) * 1.5
    x = seamless(norm(roar, 0.4) + pops, 1.0)
    write('crackle', norm(x, 0.8))

if __name__ == '__main__':
    for f in [wind, city, starter, creaks, shift, pass_by, crackle]:
        f()
