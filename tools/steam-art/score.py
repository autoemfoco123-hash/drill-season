#!/usr/bin/env python3
"""The epic trailer's score: an original drill / cinematic hybrid, synthesized from scratch.
140 BPM in F minor, 45 bars plus a tail, laid out on the trailer's cuts:
  bars  0- 8  intro: drone, heartbeat, a lone piano motif, the choir coming in, a riser
  bar   8     DROP 1 (the logo slam): braam, impact, the beat comes in
  bars  9-25  the beat: 808 slides, kick, clap, hats with rolls, bells, choir pads
              bar 16 beat 2: stop-down for the slow-motion explosion, back in on bar 18
  bars 25-31  break: piano and choir, filtered, then a build (snare roll, riser)
  bars 31-39  DROP 2: everything, plus strings, brass stabs and taikos
  bars 39-41  build to the logo
  bar  41     LOGO HIT: impact, braam, the choir holds the chord; bar 43 the end card
Writes score.wav (48 kHz, 32-bit float, stereo) and score_stems/*.wav.
Usage: score.py [out_dir]"""
import os, sys, math
import numpy as np
from scipy import signal

SR = 48000
BPM = 140.0
BEAT = 60.0 / BPM
BAR = 4 * BEAT
STEP = BEAT / 4
BARS = 45
TAIL = 4.0
N = int((BARS * BAR + TAIL) * SR)
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.abspath(__file__)) + '/work/epic'
os.makedirs(OUT + '/score_stems', exist_ok=True)
rng = np.random.default_rng(140)

def t_of(bar, step=0.0): return bar * BAR + step * STEP
def midi_hz(m): return 440.0 * 2 ** ((m - 69) / 12.0)

stems = {}
def stem(name):
    if name not in stems: stems[name] = np.zeros((N, 2), np.float32)
    return stems[name]

def add(name, t, x, gain=1.0, pan=0.0):
    """x mono or (n,2); placed at time t (s)."""
    s = int(round(t * SR))
    if s >= N: return
    if x.ndim == 1:
        l = math.cos((pan + 1) * math.pi / 4); r = math.sin((pan + 1) * math.pi / 4)
        x = np.stack([x * l, x * r], 1) * math.sqrt(2)
    e = min(N, s + len(x))
    if s < 0:
        x = x[-s:]; s = 0
    stem(name)[s:e] += (x[:e - s] * gain).astype(np.float32)

def env_adsr(n, a, d, s, r, sus_len=None):
    a = int(a * SR); d = int(d * SR); r = int(r * SR)
    sl = (n - a - d - r) if sus_len is None else int(sus_len * SR)
    sl = max(0, sl)
    e = np.concatenate([np.linspace(0, 1, max(a, 1), endpoint=False), np.linspace(1, s, max(d, 1), endpoint=False),
                        np.full(sl, s), np.linspace(s, 0, max(r, 1))])
    if len(e) < n: e = np.concatenate([e, np.zeros(n - len(e))])
    return e[:n]

def saw(freq, n, phase=0.0):
    # freq: scalar or array; a naive saw, filtered afterwards
    f = np.full(n, freq) if np.isscalar(freq) else freq
    ph = (np.cumsum(f) / SR + phase) % 1.0
    return 2 * ph - 1

def sine(freq, n, phase=0.0):
    f = np.full(n, freq) if np.isscalar(freq) else freq
    return np.sin(2 * np.pi * (np.cumsum(f) / SR + phase))

def lp(x, fc, order=2):
    sos = signal.butter(order, min(fc, SR * 0.45), 'low', fs=SR, output='sos'); return signal.sosfilt(sos, x, axis=0)
def hp(x, fc, order=2):
    sos = signal.butter(order, fc, 'high', fs=SR, output='sos'); return signal.sosfilt(sos, x, axis=0)
def bp(x, lo, hi, order=2):
    sos = signal.butter(order, [lo, min(hi, SR * 0.45)], 'band', fs=SR, output='sos'); return signal.sosfilt(sos, x, axis=0)

def sweep_lp(x, f0, f1, blocks=64, curve=1.0):
    """low-pass whose cutoff glides from f0 to f1 (log), in blocks, keeping the filter state"""
    out = np.zeros_like(x); n = len(x); bl = max(256, n // blocks)
    zi = None
    for i in range(0, n, bl):
        k = (i / max(1, n - 1)) ** curve
        fc = math.exp(math.log(f0) + (math.log(f1) - math.log(f0)) * k)
        sos = signal.butter(2, min(fc, SR * 0.45), 'low', fs=SR, output='sos')
        if zi is None: zi = np.zeros((sos.shape[0], 2) + x.shape[1:])
        out[i:i + bl], zi = signal.sosfilt(sos, x[i:i + bl], axis=0, zi=zi)
    return out

def noise(n): return rng.standard_normal(n)

# ---------------------------------------------------------------- reverb (convolution)
def make_ir(sec, bright=0.6, pre=0.012):
    n = int(sec * SR)
    t = np.arange(n) / SR
    irs = []
    for ch in range(2):
        x = rng.standard_normal(n) * np.exp(-t * 6.9 / sec)
        x = lp(x, 2500 + 6000 * bright)
        # a few early reflections
        for k in range(8):
            d = int((pre + rng.uniform(0.005, 0.06)) * SR)
            if d < n: x[d] += rng.uniform(0.3, 0.7) * (1 if rng.random() < 0.5 else -1)
        x[:int(pre * SR)] = 0
        irs.append(x / np.sqrt(np.sum(x ** 2)))
    return np.stack(irs, 1)

IR_HALL = make_ir(3.2, 0.5)
IR_ROOM = make_ir(1.1, 0.8, 0.006)
IR_HUGE = make_ir(5.5, 0.35, 0.02)

def reverb(x, ir, wet):
    if x.ndim == 1: x = np.stack([x, x], 1)
    y = np.stack([signal.fftconvolve(x[:, c], ir[:, c])[:len(x)] for c in range(2)], 1)
    return x * (1 - wet * 0.35) + y * wet

# ---------------------------------------------------------------- the song's harmony
CH = { 'Fm': [53, 56, 60], 'Db': [49, 53, 56], 'Bbm': [46, 49, 53], 'C': [48, 52, 55] }
ROOT = { 'Fm': 29, 'Db': 25, 'Bbm': 34, 'C': 24 }        # 808 roots (F1, Db1, Bb1, C1)
PROG = ['Fm', 'Db', 'Bbm', 'C']
def chord_at(bar, per=1): return PROG[(bar // per) % 4]
MOTIF = { 'Fm': [(0, 84, 3), (3, 80, 3), (6, 77, 2), (8, 80, 2), (10, 84, 2), (12, 85, 4)],
          'Db': [(0, 85, 3), (3, 80, 3), (6, 77, 2), (8, 80, 2), (10, 85, 2), (12, 84, 4)],
          'Bbm': [(0, 82, 3), (3, 77, 3), (6, 73, 2), (8, 77, 2), (10, 82, 2), (12, 80, 4)],
          'C': [(0, 79, 3), (3, 76, 3), (6, 72, 2), (8, 76, 2), (10, 79, 2), (12, 80, 2), (14, 79, 2)] }
CHOIR = { 'Fm': [53, 60, 65, 68, 72], 'Db': [49, 56, 61, 65, 68], 'Bbm': [46, 53, 58, 61, 65], 'C': [48, 55, 60, 64, 67] }

# ---------------------------------------------------------------- instruments
def kick(gain=1.0):
    n = int(0.5 * SR); t = np.arange(n) / SR
    f = 48 + 120 * np.exp(-t / 0.035)
    x = sine(f, n) * np.exp(-t / 0.22)
    x += hp(noise(n), 3000) * np.exp(-t / 0.004) * 0.35
    return np.tanh(x * 1.6) * 0.9 * gain

def snare():
    n = int(0.45 * SR); t = np.arange(n) / SR
    body = sine(185 + 40 * np.exp(-t / 0.02), n) * np.exp(-t / 0.06) * 0.6
    nz = bp(noise(n), 1600, 9000) * np.exp(-t / 0.14) * 0.8
    clap = np.zeros(n)
    for k, d in enumerate([0.0, 0.011, 0.022]):
        s = int(d * SR); m = int(0.012 * SR)
        clap[s:s + m] += bp(noise(m), 900, 5000) * np.linspace(1, 0.2, m)
    clap += bp(noise(n), 900, 5000) * np.exp(-t / 0.09) * 0.5
    return np.tanh((body + nz + clap * 0.7) * 1.3) * 0.7

def hat(open_=False, vel=1.0):
    n = int((0.32 if open_ else 0.06) * SR); t = np.arange(n) / SR
    x = hp(noise(n), 7500, 4) * np.exp(-t / (0.11 if open_ else 0.014))
    return x * 0.45 * vel

def perc():
    n = int(0.18 * SR); t = np.arange(n) / SR
    x = sine(820 * (1 + 0.4 * np.exp(-t / 0.01)), n) * np.exp(-t / 0.05) * 0.5 + hp(noise(n), 2000) * np.exp(-t / 0.006) * 0.3
    return x * 0.6

def b808(notes, length):
    """notes: [(t_rel, midi)], a sliding 808 line of the given total length (s)"""
    n = int(length * SR); t = np.arange(n) / SR
    f = np.zeros(n); amp = np.zeros(n)
    for i, (tr, m) in enumerate(notes):
        s = int(tr * SR)
        e = int(notes[i + 1][0] * SR) if i + 1 < len(notes) else n
        hz = midi_hz(m)
        prev = midi_hz(notes[i - 1][1]) if i > 0 else hz
        g = int(0.07 * SR)
        seg = np.full(e - s, hz)
        if i > 0 and prev != hz:
            k = min(g, e - s); seg[:k] = prev * (hz / prev) ** (np.arange(k) / k)
        f[s:e] = seg
        tt = np.arange(e - s) / SR
        a = np.exp(-tt / 1.6) * (1 - np.exp(-tt / 0.004))
        if i > 0 and prev != hz: a = np.maximum(a, 0.85 * np.exp(-tt / 1.6))
        amp[s:e] = a
    x = sine(f, n) * amp
    x = np.tanh(x * 2.2) * 0.75 + sine(f * 2, n) * amp * 0.06
    rel = int(0.03 * SR); x[-rel:] *= np.linspace(1, 0, rel)
    return lp(x, 1800)

def bellpiano(m, dur, vel=1.0):
    f = midi_hz(m); n = int((dur + 2.2) * SR); t = np.arange(n) / SR
    x = np.zeros(n)
    for k, (r, a, d) in enumerate([(1, 1.0, 1.6), (2, 0.45, 0.9), (3, 0.22, 0.6), (4, 0.18, 0.4), (5.4, 0.12, 0.35), (8.93, 0.05, 0.18)]):
        x += a * np.sin(2 * np.pi * f * r * t * (1 + 0.0003 * k * k)) * np.exp(-t / d)
    x += hp(noise(n), 3000) * np.exp(-t / 0.004) * 0.15
    off = int(dur * SR)
    x[off:] *= np.exp(-np.arange(n - off) / SR / 0.35)
    return x * 0.22 * vel

def piano(m, dur, vel=1.0):
    f = midi_hz(m); n = int((dur + 1.8) * SR); t = np.arange(n) / SR
    B = 0.00035; x = np.zeros(n)
    for k in range(1, 11):
        fk = f * k * math.sqrt(1 + B * k * k)
        if fk > 12000: break
        x += (1.0 / k ** 1.25) * np.sin(2 * np.pi * fk * t + rng.uniform(0, 6.28)) * np.exp(-t * (0.9 + 0.55 * k))
    x += lp(noise(n), 2500) * np.exp(-t / 0.006) * 0.08
    off = int(dur * SR)
    x[off:] *= np.exp(-np.arange(n - off) / SR / 0.25)
    return x * 0.3 * vel

FORMANTS = [(730, 90, 1.0), (1090, 110, 0.5), (2440, 160, 0.16), (3400, 200, 0.06)]   # "ah"
def choir(notes, dur, att=0.6, rel=1.2):
    n = int((dur + rel) * SR); t = np.arange(n) / SR
    src = np.zeros(n)
    for m in notes:
        f0 = midi_hz(m)
        for v in range(4):
            det = 2 ** (rng.uniform(-9, 9) / 1200)
            vib = 1 + 0.006 * np.sin(2 * np.pi * (4.6 + rng.uniform(-0.6, 0.6)) * t + rng.uniform(0, 6))
            src += saw(f0 * det * vib, n, rng.random())
    src += lp(noise(n), 6000) * 0.25
    x = np.zeros(n)
    for fc, bw, g in FORMANTS:
        x += bp(src, fc - bw, fc + bw) * g
    e = env_adsr(n, att, 0.3, 0.85, rel, dur - att - 0.3)
    return x * e * 0.09

def strings(m, dur):
    n = int((dur + 0.12) * SR); t = np.arange(n) / SR
    x = sum(saw(midi_hz(m) * 2 ** (d / 1200), n, rng.random()) for d in (-7, 0, 6))
    x = lp(x, 3200) * env_adsr(n, 0.008, 0.06, 0.6, 0.1)
    return x * 0.06

def braam(root=29, length=3.6):
    n = int(length * SR); t = np.arange(n) / SR
    x = np.zeros(n)
    for m, g in [(root, 1.0), (root + 12, 0.9), (root + 19, 0.6), (root + 24, 0.5), (root + 27, 0.35)]:
        for d in (-8, 0, 7):
            x += saw(midi_hz(m) * 2 ** (d / 1200), n, rng.random()) * g
    # the filter opens fast, then closes slowly
    a = sweep_lp(x[:int(0.35 * SR)], 180, 2600, 24)
    b = sweep_lp(x[int(0.35 * SR):], 2600, 380, 48, 0.6)
    x = np.concatenate([a, b])
    x = np.tanh(x * 0.35) * env_adsr(n, 0.02, 0.4, 0.55, 2.2)
    return x * 0.5

def impact(length=4.0):
    n = int(length * SR); t = np.arange(n) / SR
    sub = sine(55 * np.exp(-t / 1.2) + 24, n) * np.exp(-t / 1.1)
    thump = lp(noise(n), 400) * np.exp(-t / 0.08) * 1.6
    crack = bp(noise(n), 1500, 9000) * np.exp(-t / 0.05) * 0.6
    return np.tanh((sub * 1.4 + thump + crack) * 1.3) * 0.8

def taiko():
    n = int(1.2 * SR); t = np.arange(n) / SR
    x = sine(72 * (1 + 0.5 * np.exp(-t / 0.03)), n) * np.exp(-t / 0.35) + lp(noise(n), 700) * np.exp(-t / 0.05) * 0.8
    return np.tanh(x * 1.5) * 0.55

def riser(length):
    n = int(length * SR); k = np.linspace(0, 1, n)
    nz = noise(n)
    out = np.zeros(n); bl = n // 64
    zi = None
    for i in range(0, n, bl):
        c = 300 * (30 ** k[i])
        sos = signal.butter(2, [c * 0.7, min(c * 1.4, SR * 0.45)], 'band', fs=SR, output='sos')
        if zi is None: zi = np.zeros((sos.shape[0], 2))
        out[i:i + bl], zi = signal.sosfilt(sos, nz[i:i + bl], zi=zi)
    tone = saw(110 * 2 ** (k * 2.5), n) * 0.15
    return (out * 1.2 + lp(tone, 4000)) * (k ** 2.2) * 0.5

def rev_cymbal(length):
    n = int(length * SR); t = np.arange(n) / SR
    x = hp(noise(n), 4000) * np.exp(-t / 0.9)
    return x[::-1] * 0.35

def heartbeat():
    n = int(0.7 * SR); t = np.arange(n) / SR
    def thump(d, g):
        s = int(d * SR); m = n - s; tt = np.arange(m) / SR
        y = np.zeros(n); y[s:] = sine(52 + 20 * np.exp(-tt / 0.02), m) * np.exp(-tt / 0.09) * g; return y
    return np.tanh((thump(0, 1.0) + thump(0.22, 0.7)) * 1.5) * 0.7

def drone(length, root=29):
    n = int(length * SR); t = np.arange(n) / SR
    x = sum(saw(midi_hz(m) * 2 ** (d / 1200), n, rng.random()) for m in (root, root + 12, root + 19) for d in (-6, 6))
    x = lp(x, 260) * (0.75 + 0.25 * np.sin(2 * np.pi * 0.12 * t))
    return x * env_adsr(n, 2.5, 0.1, 1.0, 2.0) * 0.18

def whoosh(length=0.8):
    n = int(length * SR); k = np.linspace(0, 1, n)
    x = bp(noise(n), 400, 6000) * np.sin(np.pi * k) ** 2
    return x * 0.4

# ---------------------------------------------------------------- the arrangement
def beat_bar(bar, intensity=1.0, rolls=True, taikos=False):
    t0 = t_of(bar)
    # kick: drill syncopation, varied every other bar
    kp = [0, 7, 10] if bar % 2 == 0 else [0, 3, 10, 13]
    for s in kp: add('drums', t0 + s * STEP, kick(), 0.95)
    # clap on beat 3, a ghost before the next bar sometimes
    add('drums', t0 + 8 * STEP, snare(), 0.8 * intensity)
    if bar % 4 == 3: add('drums', t0 + 15 * STEP, snare(), 0.35)
    # hats: 8ths with 16th pushes, a triplet roll every second bar
    for s in range(0, 16, 2): add('hats', t0 + s * STEP, hat(vel=1.0 if s % 4 == 0 else 0.7), 0.9, 0.15)
    for s in (3, 7, 11): add('hats', t0 + s * STEP, hat(vel=0.5), 0.8, 0.15)
    if rolls and bar % 2 == 1:
        for k in range(6): add('hats', t0 + 12 * STEP + k * (4 * STEP / 6), hat(vel=0.55 + 0.08 * k), 0.85, 0.15)
    add('perc', t0 + 6 * STEP, perc(), 0.5, -0.4); add('perc', t0 + 14 * STEP, perc(), 0.35, 0.4)
    if taikos:
        for s in (0, 8): add('epic', t0 + s * STEP, taiko(), 0.8)

def b808_bar(bar, chord):
    r = ROOT[chord] + 12
    notes = [(0, r), (7 * STEP, r), (10 * STEP, r + 12), (12 * STEP, r + 10 if chord in ('Fm', 'Bbm') else r + 7)]
    add('808', t_of(bar), b808(notes, BAR), 0.85)

def motif_bar(bar, chord, inst='bell', vel=1.0, oct=0):
    for s, m, l in MOTIF[chord]:
        x = bellpiano(m + oct, l * STEP, vel) if inst == 'bell' else piano(m + oct, l * STEP, vel)
        add(inst, t_of(bar) + s * STEP, x, 1.0, 0.25 if inst == 'bell' else -0.15)

def choir_bars(bar, nbars, chord, gain=1.0, att=0.5):
    add('choir', t_of(bar), choir(CHOIR[chord], nbars * BAR, att=att), gain)

def strings_bar(bar, chord):
    r = CH[chord][0] + 12
    pat = [r, r + 7, r + 12, r + 7]
    for s in range(16):
        add('strings', t_of(bar) + s * STEP, strings(pat[s % 4], STEP * 0.85), 1.0, -0.3 if s % 2 else 0.3)

# intro, bars 0-8
add('drone', 0.0, drone(8 * BAR + 1.0), 0.55)
for b in range(0, 8):
    add('heart', t_of(b), heartbeat(), 0.55 if b >= 2 else 0.35)
for b in range(2, 8):
    ch = chord_at(b - 2, 2)
    motif_bar(b, ch, 'piano', 0.42 + 0.05 * (b - 2))
for b in (4, 6):
    choir_bars(b, 2, chord_at(b - 2, 2), 0.45, att=1.6)
add('fx', t_of(6), riser(2 * BAR), 0.9)
add('fx', t_of(7), rev_cymbal(BAR), 0.8)

# DROP 1 on bar 8
def big_hit(bar, root=29, size=1.0):
    add('epic', t_of(bar), impact(), 1.0 * size)
    add('epic', t_of(bar), braam(root), 0.85 * size)
add('fx', t_of(8) - 0.04, whoosh(0.5)[::-1], 0.6)
big_hit(8)

# the beat, bars 9-25 (stop-down at bar 16 beat 2 for the explosion; back on bar 18)
for b in range(9, 25):
    ch = chord_at(b)
    if b in (16, 17):
        continue
    beat_bar(b, 1.0)
    b808_bar(b, ch)
    motif_bar(b, ch, 'bell', 0.9)
    if b % 2 == 1: choir_bars(b, 2, ch, 0.55)
# bar 16: one beat of the groove, then the floor drops out
add('drums', t_of(16), kick(), 0.95); add('808', t_of(16), b808([(0, ROOT['Fm'] + 12)], BEAT * 1.0), 0.85)
add('epic', t_of(16, 4), impact(5.0), 0.9)
add('choir', t_of(16, 4), choir(CHOIR['Fm'], 2 * BAR - BEAT, att=0.15, rel=0.4), 0.55)
add('drone', t_of(16, 4), drone(2 * BAR - BEAT), 1.2)
add('fx', t_of(17), rev_cymbal(BAR), 0.9)
for k in range(8): add('drums', t_of(17, 8) + k * (8 * STEP / 8), snare(), 0.18 + 0.06 * k)
add('epic', t_of(18), impact(2.5), 0.6)

# break, bars 25-31
for b in range(25, 29):
    ch = chord_at(b)
    motif_bar(b, ch, 'piano', 0.9)
    add('808', t_of(b), b808([(0, ROOT[ch] + 12)], BAR), 0.5)
    for s in range(0, 16, 4): add('hats', t_of(b) + s * STEP, hat(vel=0.5), 0.7, 0.2)
choir_bars(25, 2, 'Fm', 0.8, 0.8); choir_bars(27, 2, 'Bbm', 0.8, 0.8)
for b in (29, 30):
    ch = chord_at(b)
    motif_bar(b, ch, 'piano', 1.0)
    choir_bars(b, 1, ch, 0.9, 0.3)
    add('808', t_of(b), b808([(0, ROOT[ch] + 12)], BAR), 0.6)
# the build: a snare roll speeding up, a riser, a breath of silence before the drop
for k in range(32):
    tk = t_of(29) + (2 * BAR - BEAT) * (1 - (1 - k / 32) ** 1.6)
    add('drums', tk, snare(), 0.15 + 0.5 * (k / 32))
add('fx', t_of(29), riser(2 * BAR - BEAT), 1.0)
add('fx', t_of(30), rev_cymbal(BAR - BEAT * 0.5), 0.8)

# DROP 2, bars 31-39
big_hit(31, size=1.1)
for b in range(31, 39):
    ch = chord_at(b)
    beat_bar(b, 1.1, taikos=True)
    b808_bar(b, ch)
    motif_bar(b, ch, 'bell', 1.0)
    strings_bar(b, ch)
    if b % 2 == 1: choir_bars(b, 2, ch, 0.8)
    if b % 2 == 1: add('epic', t_of(b), braam(ROOT[ch] + (0 if ROOT[ch] > 27 else 12), 1.6), 0.4)

# build to the logo, bars 39-41
for b in (39, 40):
    ch = chord_at(b)
    beat_bar(b, 1.1, taikos=True)
    b808_bar(b, ch)
    strings_bar(b, ch)
    choir_bars(b, 1, ch, 0.9, 0.2)
for k in range(24):
    add('drums', t_of(40) + k * (BAR / 24), snare(), 0.2 + 0.03 * k)
add('fx', t_of(39), riser(2 * BAR), 1.1)

# LOGO HIT on bar 41: the choir holds the chord, the bells play the motif slowly
big_hit(41, size=1.25)
add('epic', t_of(41), impact(6.0), 0.5)
add('choir', t_of(41), choir(CHOIR['Fm'], 4 * BAR, att=0.08, rel=3.5), 1.1)
add('drone', t_of(41), drone(4 * BAR + 3), 1.2)
for b, ch in ((41, 'Fm'), (42, 'Db')):
    motif_bar(b, ch, 'bell', 0.8)
# the end card, bar 43
add('epic', t_of(43), taiko(), 0.9)
add('piano', t_of(43), piano(53, 3.0, 1.0) + piano(60, 3.0, 0.8) + piano(65, 3.0, 0.7), 1.0)
add('bell', t_of(43, 4), bellpiano(84, 2.0, 0.7), 1.0, 0.2)

# ---------------------------------------------------------------- mix
GAINS = { 'drums': 0.82, 'hats': 1.7, 'perc': 3.0, '808': 0.62, 'bell': 1.0, 'piano': 0.9, 'choir': 3.4, 'strings': 3.4,
          'epic': 0.9, 'fx': 1.4, 'drone': 1.2, 'heart': 1.4 }
VERB = { 'drums': (IR_ROOM, 0.18), 'hats': (IR_ROOM, 0.12), 'perc': (IR_HALL, 0.25), 'bell': (IR_HALL, 0.45), 'piano': (IR_HALL, 0.5),
         'choir': (IR_HUGE, 0.6), 'strings': (IR_HALL, 0.35), 'epic': (IR_HUGE, 0.35), 'fx': (IR_HALL, 0.2), 'drone': (IR_HALL, 0.3), 'heart': (IR_HALL, 0.15) }
# the kick ducks the pads (sidechain)
kick_env = np.abs(stems['drums'][:, 0])
kick_env = signal.sosfilt(signal.butter(1, 8, 'low', fs=SR, output='sos'), kick_env)
duck = 1 - np.clip(kick_env * 1.4, 0, 0.45)
mix = np.zeros((N, 2), np.float32)
for name, x in stems.items():
    if name in VERB: x = reverb(x, *VERB[name])
    if name in ('choir', 'strings', 'drone', 'bell'): x = x * duck[:, None]
    x = x * GAINS.get(name, 1.0)
    stems[name] = x.astype(np.float32)
    mix += stems[name]
# glue: gentle saturation, then peak-normalize to -1 dBFS (loudness is set in the edit)
mix = np.tanh(mix * 0.9) / 0.9
scale = 10 ** (-1 / 20) / max(1e-9, np.max(np.abs(mix)))
mix *= scale
fade = int(1.5 * SR); mix[-fade:] *= np.linspace(1, 0, fade)[:, None]

import wave
def write(path, x):
    with wave.open(path, 'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype('<i2').tobytes())
write(OUT + '/score.wav', mix)
for name, x in stems.items():
    write(OUT + '/score_stems/' + name + '.wav', x * scale)
# the balance in the second drop (bars 31-39), dB RMS per stem as it sits in the mix
for nm, b0, b1 in (('intro', 2, 8), ('drop 1', 9, 16), ('break', 25, 29), ('drop 2', 31, 39), ('logo', 41, 43)):
    s0, s1 = int(t_of(b0) * SR), int(t_of(b1) * SR)
    print(f'{nm:7s}', ', '.join(f'{k} {20 * math.log10(np.sqrt(np.mean((v[s0:s1] * scale) ** 2)) + 1e-9):.0f}' for k, v in sorted(stems.items()) if np.any(v[s0:s1])))
print('score', OUT + '/score.wav', round(N / SR, 2), 's;', 'bars', BARS, 'bar', round(BAR, 4), 's')
