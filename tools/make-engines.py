#!/usr/bin/env python3
"""Renders the engine sounds into godot/assets/engine/ (scripts/EngineAudio.gd plays them).

The way racing sims do it: for each engine, short seamless loops recorded at a ladder of RPMs,
on throttle and off throttle, which the game crossfades and pitches between. Here the
"recordings" come from a physically informed model instead of a microphone:

  * every cylinder fires at its real crank angle in its real firing order, each one a little
    different from the others (volumetric efficiency, spark), with cycle-to-cycle variation
    and crank-speed jitter; a lumpy cam makes the idle lope
  * the pulses go down each bank's exhaust: pulse shape, header and full-length pipe
    resonances (waveguide combs, damped toward the top), the muffler, radiation from the
    tailpipe, then the pipe's own saturation. A crossplane V8's two banks fire unevenly, and
    that, through two slightly different pipes, is where its burble comes from
  * turbulence: rasp in the high mids, riding on the pulses, more under load
  * the intake stem: the induction roar through the airbox (a Helmholtz resonance), valve
    train ticks, the structure-borne rumble you feel in the cabin, a supercharger's whine
  * off throttle: weak, soft combustion, a hiss past the closed throttle plate

Two stems per loop, exhaust and intake/mechanics: the game mixes them differently outside the
car and in the driver's seat. Everything is built periodic (filters applied in the frequency
domain on a whole number of engine cycles), so the loops have no seam at all.

Also: turbo whistle loop, blow-off valve, afterfire pops and crackles, gear whine.

  godot/assets/engine/<profile>_<rpm>_<on|off>_<ex|in>.wav   16-bit mono, 32 kHz
  godot/assets/engine/engines.json                         the ladder and the specs

Usage: python3 tools/make-engines.py   (needs numpy)
"""
import os, json, wave
import numpy as np

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
OUT = os.path.join(ROOT, 'godot', 'assets', 'engine')
os.makedirs(OUT, exist_ok=True)
SR = 32000
C_EX = 520.0          # speed of sound in hot exhaust gas, m/s

# crossplane V8 (firing order 1-8-7-2-6-5-4-3, odd cylinders on bank 0): each bank fires
# 180-270-180-90 degrees apart
V8_ORDER = [1, 8, 7, 2, 6, 5, 4, 3]
V8_ANG = [i * 90.0 for i in range(8)]
V8_BANK = [0 if c % 2 == 1 else 1 for c in V8_ORDER]

PROFILES = {
    # an econobox four: buzzy, thin, a tight muffler, busy valve train
    'i4': dict(cyl=4, ang=[0, 180, 360, 540], bank=[0, 0, 0, 0], idle=850, red=6800,
               pipes=[[0.7, 2.4]], refl=[-0.6, -0.4], muf=1250, mufq=0.9, tau=0.00085, rasp=0.22,
               drive=1.4, vary=0.04, cylvar=0.06, lope=0.0, jit=0.010, intake=1.0, mech=1.2, rumble=0.8,
               sc=0.0, gain=1.0),
    # a family V6: smooth, a bit of growl at the top
    'v6': dict(cyl=6, ang=[0, 120, 240, 360, 480, 600], bank=[0, 1, 0, 1, 0, 1], idle=750, red=6400,
               pipes=[[0.85, 2.9], [0.92, 2.9]], refl=[-0.55, -0.4], muf=1000, mufq=0.8, tau=0.0010, rasp=0.28,
               drive=1.6, vary=0.05, cylvar=0.07, lope=0.0, jit=0.012, intake=0.9, mech=0.9, rumble=1.0,
               sc=0.0, gain=1.0),
    # a turbo straight six: silky, hollow under boost, a raspy top end
    'i6t': dict(cyl=6, ang=[0, 120, 240, 360, 480, 600], bank=[0, 0, 0, 0, 0, 0], idle=900, red=7400,
                pipes=[[0.55, 3.3]], refl=[-0.6, -0.45], muf=1550, mufq=1.0, tau=0.0008, rasp=0.5,
                drive=2.0, vary=0.04, cylvar=0.05, lope=0.0, jit=0.008, intake=0.6, mech=0.8, rumble=0.8,
                sc=0.0, gain=1.0),
    # a crossplane V8 (trucks, the police cars): the burble, a deep exhaust
    'v8': dict(cyl=8, ang=V8_ANG, bank=V8_BANK, idle=650, red=5900,
               pipes=[[0.95, 3.4], [1.12, 3.0]], refl=[-0.6, -0.45], muf=850, mufq=0.9, tau=0.0013, rasp=0.32,
               drive=2.2, vary=0.06, cylvar=0.09, lope=0.08, jit=0.014, intake=0.8, mech=0.7, rumble=1.3,
               sc=0.0, gain=1.0),
    # a muscle V8 with a big cam and a blower: loping idle, loud, the supercharger's whine
    'v8s': dict(cyl=8, ang=V8_ANG, bank=V8_BANK, idle=750, red=6600,
                pipes=[[0.9, 2.6], [1.1, 2.3]], refl=[-0.65, -0.5], muf=1600, mufq=1.1, tau=0.0011, rasp=0.55,
                drive=2.8, vary=0.1, cylvar=0.1, lope=0.32, jit=0.02, intake=1.0, mech=0.8, rumble=1.5,
                sc=1.0, gain=1.0),
}
NPTS = 9


def ladder(idle, red):
    lo = idle * 0.95
    hi = red * 1.06
    return [lo * (hi / lo) ** (i / (NPTS - 1)) for i in range(NPTS)]


def freqs(N):
    return np.fft.rfftfreq(N, 1.0 / SR)


def lowpass2(f, fc, q):
    s = 1j * f / fc
    return 1.0 / (s * s + s / q + 1.0)


def bandpass2(f, fc, q):
    s = 1j * f / fc
    return (s / q) / (s * s + s / q + 1.0)


def highpass1(f, fc):
    s = 1j * f / fc
    return s / (s + 1.0)


def pipe(f, L, r0, damp=2600.0):
    # a waveguide: the pulse runs down the pipe and back, the open end reflects it inverted;
    # losses grow with frequency
    T = 2.0 * L / C_EX
    r = r0 * np.exp(-f / damp)
    return (1.0 + r) / (1.0 - r * np.exp(-2j * np.pi * f * T))


def train(N, times, amps):
    """impulses at fractional sample times (wrapping round the loop), split between the two
    nearest samples so the timing stays exact"""
    x = np.zeros(N)
    for t, a in zip(times, amps):
        p = (t * SR) % N
        i = int(np.floor(p))
        fr = p - i
        x[i % N] += a * (1.0 - fr)
        x[(i + 1) % N] += a * fr
    return x


def shaped_noise(N, rng, H):
    spec = (rng.standard_normal(len(H)) + 1j * rng.standard_normal(len(H))) * H
    spec[0] = 0
    y = np.fft.irfft(spec, N)
    return y / (np.std(y) + 1e-12)


def env_train(N, times, amps, width_s):
    # raised-cosine bursts of the given width at each event (wrapping)
    x = np.zeros(N)
    w = max(2, int(width_s * SR))
    win = 0.5 - 0.5 * np.cos(np.linspace(0, 2 * np.pi, w))
    for t, a in zip(times, amps):
        i0 = int(round((t * SR) % N))
        idx = (i0 + np.arange(w)) % N
        x[idx] += a * win
    return x


def render(name, P, rpm_want, load, rng):
    cyc_hz = rpm_want / 120.0
    dur = float(np.clip(1.7 - rpm_want / 6500.0, 0.85, 1.6))
    ncyc = max(3, int(round(dur * cyc_hz)))
    N = int(round(ncyc / cyc_hz * SR))
    rpm = ncyc * 120.0 * SR / N            # the exact rpm of the loop
    cyc_t = 120.0 / rpm
    f = freqs(N)
    cyl = P['cyl']
    k_rpm = rpm / P['red']
    idle_k = float(np.clip(1.0 - (rpm - P['idle']) / 1500.0, 0.0, 1.0))
    # --- combustion events
    cylgain = 1.0 + P['cylvar'] * rng.standard_normal(cyl)
    banks = sorted(set(P['bank']))
    ev = {b: ([], []) for b in banks}
    allev = ([], [])
    ina = ([], [])
    lope = P['lope'] * idle_k
    for c in range(ncyc):
        drift = rng.standard_normal() * P['jit'] * (0.4 + idle_k) * cyc_t / cyl
        for j in range(cyl):
            t = (c + P['ang'][j] / 720.0) * cyc_t + drift + rng.standard_normal() * P['jit'] * 0.4 * cyc_t / cyl
            a = cylgain[j] * (1.0 + P['vary'] * (1.0 + idle_k) * rng.standard_normal())
            if lope > 0 and rng.random() < lope:
                a *= rng.uniform(0.25, 0.7)          # the big cam: a weak, late burn now and then
                t += rng.uniform(0.0, 0.05) * cyc_t / cyl
            if load > 0.5:
                a *= 0.55 + 0.45 * min(1.0, 0.35 + k_rpm)
            else:
                a *= 0.16 + 0.05 * rng.standard_normal()
            a = max(0.02, a)
            ev[P['bank'][j]][0].append(t); ev[P['bank'][j]][1].append(a)
            allev[0].append(t); allev[1].append(a)
            ina[0].append(t + cyc_t * (380.0 / 720.0)); ina[1].append(a)
    # --- the exhaust stem
    tau = P['tau'] * (1.0 - 0.25 * k_rpm) * (1.0 if load > 0.5 else 1.6)
    s = 2j * np.pi * f * tau
    pulse = 1.0 / (1.0 + s) ** 2 - 0.32 / (1.0 + s * 2.6) ** 2       # blowdown, then the dip behind it
    ex = np.zeros(N)
    for bi, b in enumerate(banks):
        x = train(N, *ev[b])
        L1, L2 = P['pipes'][bi % len(P['pipes'])]
        H = pulse * pipe(f, L1, P['refl'][0]) * pipe(f, L2, P['refl'][1], 1500.0)
        muf = P['muf'] * (1.0 + 0.35 * load * k_rpm)
        H *= lowpass2(f, muf, P['mufq']) * highpass1(f, 55.0)
        H *= 1.0 + 0.6 * bandpass2(f, muf * 1.9, 2.5)                  # the muffler's chamber
        H *= 2j * np.pi * f / (2j * np.pi * f + 2 * np.pi * 900.0) + 0.35   # tailpipe radiation
        y = np.fft.irfft(np.fft.rfft(x) * H, N)
        y /= (np.max(np.abs(y)) + 1e-9)
        drive = P['drive'] * (0.5 + 0.5 * load) * (0.75 + 0.35 * k_rpm)
        y = np.tanh(y * drive) / np.tanh(drive)
        # turbulence riding on the pulses
        envb = np.abs(np.fft.irfft(np.fft.rfft(x) * lowpass2(f, 60.0 + rpm / 20.0, 0.7), N))
        envb /= (np.max(envb) + 1e-9)
        nz = shaped_noise(N, rng, bandpass2(f, 1400.0 + 900.0 * k_rpm, 0.9) + 0.25 * bandpass2(f, 3200.0, 1.2))
        y += nz * envb * P['rasp'] * 0.6 * (0.25 + 0.75 * load) * (0.3 + 0.7 * k_rpm)
        # the muffler's shell and the tailpipe take the fizz off what the saturation added
        y = np.fft.irfft(np.fft.rfft(y) * lowpass2(f, muf * 2.3, 0.7) * lowpass2(f, 7000.0, 0.6), N)
        ex += y * (1.0 if bi == 0 else 0.92)
    ex *= (0.35 + 0.65 * k_rpm ** 0.6) * (1.0 if load > 0.5 else 0.42)
    # --- the intake and mechanical stem
    ins = np.zeros(N)
    # induction roar: bursts of airflow through the airbox, a resonance, more under load
    burst = env_train(N, ina[0], ina[1], cyc_t * 160.0 / 720.0)
    air = shaped_noise(N, rng, bandpass2(f, 230.0, 3.0) * 2.0 + bandpass2(f, 1100.0, 1.2) + 0.35 * bandpass2(f, 2600.0, 1.0))
    roar = air * burst * (load * (0.25 + 0.75 * k_rpm ** 0.8) + (1 - load) * 0.04)
    tone = np.fft.irfft(np.fft.rfft(train(N, *ina)) * bandpass2(f, 230.0, 2.5) * (1.0 + bandpass2(f, 140.0 + rpm / 60.0, 1.5)), N)
    tone /= (np.max(np.abs(tone)) + 1e-9)
    ins += P['intake'] * (roar * 0.6 + tone * 0.5 * (0.3 + 0.7 * load) * k_rpm ** 0.5)
    if load < 0.5:
        hiss = shaped_noise(N, rng, bandpass2(f, 1900.0 + 600 * k_rpm, 4.0))
        ins += hiss * 0.08 * k_rpm
    # the rumble through the floor: the firing pulses, low passed
    rum = np.fft.irfft(np.fft.rfft(train(N, *allev)) * lowpass2(f, 140.0 + rpm / 40.0, 0.9) * highpass1(f, 25.0), N)
    rum /= (np.max(np.abs(rum)) + 1e-9)
    ins += rum * P['rumble'] * 0.55 * (0.5 + 0.5 * load)
    # valve train: tiny ticks, two per cylinder per cycle
    ticks = []
    for c in range(ncyc):
        for j in range(cyl):
            for o in (130.0, 480.0):
                ticks.append((c + (P['ang'][j] + o) / 720.0) * cyc_t + rng.standard_normal() * 0.00004)
    tk = train(N, ticks, list(0.6 + 0.4 * rng.random(len(ticks))))
    tk = np.fft.irfft(np.fft.rfft(tk) * highpass1(f, 3500.0) * lowpass2(f, 9000.0, 0.7) / (1.0 + 2j * np.pi * f * 0.00025), N)
    tk /= (np.max(np.abs(tk)) + 1e-9)
    ins += tk * P['mech'] * 0.12 * (0.6 + 0.4 * k_rpm)
    # a supercharger: the rotors' whine, pitched with the crank
    if P['sc'] > 0:
        fsc = rpm / 60.0 * 2.4 * 6.0
        t = np.arange(N) / SR
        # whole cycles in the loop, so the tone loops too
        k = np.round(fsc * N / SR) / (N / SR)
        w = np.sin(2 * np.pi * k * t) + 0.35 * np.sin(4 * np.pi * k * t + 0.6) + 0.12 * np.sin(6 * np.pi * k * t + 1.3)
        ins += w * P['sc'] * 0.16 * k_rpm ** 1.3 * (0.35 + 0.65 * load)
    return rpm, ex.astype(np.float64), ins.astype(np.float64)


def write(path, x):
    y = np.clip(x, -1.0, 1.0)
    d = (y * 32767).astype('<i2').tobytes()
    with wave.open(path, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(d)


def main():
    manifest = {'rate': SR, 'profiles': {}}
    for name, P in PROFILES.items():
        rng = np.random.default_rng(sum(map(ord, name)) * 101)
        pts = []
        clips = []
        for rpm_w in ladder(P['idle'], P['red']):
            row = {}
            for load in (1.0, 0.0):
                rpm, ex, ins = render(name, P, rpm_w, load, rng)
                lt = 'on' if load > 0.5 else 'off'
                row['rpm_' + lt] = rpm
                clips.append((rpm_w, lt, ex, ins))
            pts.append(row)
        # one level for the whole engine, so louder stays louder
        pk_ex = max(np.max(np.abs(c[2])) for c in clips)
        pk_in = max(np.max(np.abs(c[3])) for c in clips)
        files = []
        for i, (rpm_w, lt, ex, ins) in enumerate(clips):
            base = '%s_%04d_%s' % (name, int(round(rpm_w)), lt)
            write(os.path.join(OUT, base + '_ex.wav'), ex / pk_ex * 0.9)
            write(os.path.join(OUT, base + '_in.wav'), ins / pk_in * 0.9)
            files.append(base)
        ladder_out = []
        for i, row in enumerate(pts):
            ladder_out.append({'on': files[i * 2], 'off': files[i * 2 + 1], 'rpm_on': round(row['rpm_on'], 2), 'rpm_off': round(row['rpm_off'], 2)})
        manifest['profiles'][name] = {'cyl': P['cyl'], 'idle': P['idle'], 'red': P['red'], 'ladder': ladder_out,
                                      'turbo': name == 'i6t', 'blower': P['sc'] > 0}
        print('%-4s %d loops' % (name, len(clips) * 2))
    extras(manifest)
    with open(os.path.join(OUT, 'engines.json'), 'w') as fh:
        json.dump(manifest, fh, indent=1)


def extras(manifest):
    rng = np.random.default_rng(99)
    # turbo whistle: a narrow band of air round a tone, 1 s loop
    N = SR
    f = freqs(N)
    t = np.arange(N) / SR
    wh = shaped_noise(N, rng, bandpass2(f, 4200.0, 14.0)) * 0.5 + np.sin(2 * np.pi * 4200 * t) * 0.6 + np.sin(2 * np.pi * 8400 * t) * 0.12
    write(os.path.join(OUT, 'turbo.wav'), wh / np.max(np.abs(wh)) * 0.7)
    # gear whine: the gearbox and diff, a tone with a sideband
    gw = np.sin(2 * np.pi * 600 * t) + 0.4 * np.sin(2 * np.pi * 1200 * t + 0.3) + 0.25 * np.sin(2 * np.pi * 560 * t)
    gw += shaped_noise(N, rng, bandpass2(f, 600.0, 20.0)) * 0.3
    write(os.path.join(OUT, 'whine.wav'), gw / np.max(np.abs(gw)) * 0.7)
    # blow-off valve: a sharp hiss falling away
    n = int(0.55 * SR)
    tt = np.arange(n) / SR
    fb = freqs(n)
    hs = shaped_noise(n, rng, bandpass2(fb, 3200.0, 0.7) + 0.6 * bandpass2(fb, 6500.0, 1.0))
    env = (1 - np.exp(-tt / 0.004)) * np.exp(-tt / 0.13)
    write(os.path.join(OUT, 'bov.wav'), hs * env / np.max(np.abs(hs * env)) * 0.8)
    # afterfire: a pop out of the tailpipe, with a crackle or two behind it (four takes)
    for k in range(4):
        n = int(0.45 * SR)
        x = np.zeros(n)
        fb = freqs(n)
        times = [0.0] + sorted(rng.uniform(0.03, 0.3, rng.integers(1, 4)))
        for j, tm in enumerate(times):
            i = int(tm * SR)
            a = 1.0 if j == 0 else rng.uniform(0.25, 0.6)
            x[i] += a
            # the crack: a short noisy burst
            m = int(0.012 * SR)
            x[i:i + m] += rng.standard_normal(min(m, n - i)) * a * 0.5 * np.exp(-np.arange(min(m, n - i)) / (0.002 * SR))
        H = pipe(fb, 0.9, -0.6) * lowpass2(fb, 2400.0, 0.8) * highpass1(fb, 50.0)
        y = np.fft.irfft(np.fft.rfft(x) * H, n)
        y = np.tanh(y / np.max(np.abs(y)) * 2.5)
        y *= np.exp(-np.arange(n) / (0.2 * SR))
        write(os.path.join(OUT, 'pop%d.wav' % k), y / np.max(np.abs(y)) * 0.9)
    manifest['extras'] = ['turbo', 'whine', 'bov', 'pop0', 'pop1', 'pop2', 'pop3']


if __name__ == '__main__':
    main()
