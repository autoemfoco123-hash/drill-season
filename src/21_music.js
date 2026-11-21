
/* =========================================================
   MUSIC - drill production: rendered drum kit, distorted
   sliding 808s, FM bells, piano, choir, strings, flute, vocal
   chops; song arranger; world-synced radio; adaptive score.
   ========================================================= */
function radioBus() {
  // car speakers: warm low end, softened top, a touch of compression
  const c = AU.ctx, inG = gainN(1);
  const ls = c.createBiquadFilter(); ls.type = 'lowshelf'; ls.frequency.value = 110; ls.gain.value = 4;
  const pk = c.createBiquadFilter(); pk.type = 'peaking'; pk.frequency.value = 420; pk.Q.value = 0.9; pk.gain.value = -2;
  const hs = c.createBiquadFilter(); hs.type = 'highshelf'; hs.frequency.value = 7500; hs.gain.value = -4;
  const cmp = c.createDynamicsCompressor(); cmp.threshold.value = -20; cmp.ratio.value = 3; cmp.attack.value = 0.01; cmp.release.value = 0.2;
  const trim = gainN(0.42);
  inG.connect(ls).connect(pk).connect(hs).connect(cmp).connect(trim).connect(AU.music);
  return inG;
}
function satCurve(k) { const n = 2048, c = new Float32Array(n); for (let i = 0; i < n; i++) { const x = i / (n - 1) * 2 - 1; c[i] = Math.tanh(x * k) / Math.tanh(k); } return c; }
function makeBus(out, o) {
  o = o || {};
  const ctx = AU.ctx;
  const B = { alive: true, seq: null };
  B.bus = gainN(o.gain === undefined ? 0.72 : o.gain); B.bus.connect(out || AU.music);
  B.dry = gainN(0.95); B.dry.connect(B.bus);
  // 808 chain: drive -> saturation -> lowpass (harmonics so it reads on small speakers)
  const shaper = ctx.createWaveShaper(); shaper.curve = AU.curve808 || (AU.curve808 = satCurve(2.6)); shaper.oversample = '2x';
  const subLP = ctx.createBiquadFilter(); subLP.type = 'lowpass'; subLP.frequency.value = 1500; subLP.Q.value = 0.6;
  B.sub = gainN(0.62); B.sub.connect(shaper).connect(subLP).connect(B.bus);
  B.mel = gainN(0.8); B.mel.connect(B.bus);
  B.send = gainN(o.verb === undefined ? 0.3 : o.verb);
  if (!out || out === AU.music || out === AU.radio) B.send.connect(AU.plateSend);
  const delay = ctx.createDelay(1.5); delay.delayTime.value = 60 / 140 * 0.75;
  const fb = gainN(0.3), dlp = ctx.createBiquadFilter(); dlp.type = 'lowpass'; dlp.frequency.value = 2600;
  B.dsend = gainN(0.32); B.dsend.connect(delay); delay.connect(dlp).connect(fb).connect(delay); const dg = gainN(0.55); dlp.connect(dg).connect(B.bus);
  B.delay = delay;
  B.setTempo = bpm => { delay.delayTime.value = 60 / bpm * 0.75; };
  return B;
}
function killBus(B) {
  if (!B || !AU.ready) return;
  B.alive = false;
  if (B.seq) { B.seq.dead = true; SEQS.delete(B.seq); }
  if (B.extra) for (const s of B.extra) { try { s.stop(); } catch (e) { } }
  const t = AU.ctx.currentTime;
  B.bus.gain.cancelScheduledValues(t); B.bus.gain.setTargetAtTime(0, t, 0.06);
  setTimeout(() => { try { B.bus.disconnect(); } catch (e) { } }, 900);
}
/* ---------- instruments ---------- */
function iDrum(B, name, t, v, rate, send) {
  const buf = bankPick(name); if (!buf) return;
  const s = AU.ctx.createBufferSource(); s.buffer = buf; s.playbackRate.value = rate || 1;
  const g = gainN(v); s.connect(g).connect(B.dry);
  if (send) { const sg = gainN(send); g.connect(sg).connect(B.send); }
  s.start(Math.max(t, AU.ctx.currentTime));
}
function i808(B, t, dur, f, fromF, glide, v) {
  const c = AU.ctx, o = c.createOscillator(), g = c.createGain(), vv = v || 1;
  o.type = 'sine';
  if (fromF) { o.frequency.setValueAtTime(fromF, t); o.frequency.exponentialRampToValueAtTime(f, t + glide); } else o.frequency.setValueAtTime(f, t);
  g.gain.setValueAtTime(0.0001, t); g.gain.linearRampToValueAtTime(0.95 * vv, t + 0.005);
  g.gain.setTargetAtTime(0.6 * vv, t + 0.04, 0.3);
  g.gain.setTargetAtTime(0.0001, t + Math.max(0.04, dur - 0.035), 0.03);
  o.connect(g).connect(B.sub); o.start(t); o.stop(t + dur + 0.25);
  const o2 = c.createOscillator(), g2 = c.createGain(); o2.type = 'triangle';
  o2.frequency.setValueAtTime((fromF || f) * 2, t); if (fromF) o2.frequency.exponentialRampToValueAtTime(f * 2, t + glide);
  o2.connect(g2).connect(B.sub); envG(g2, t, 0.003, 0.22 * vv, Math.min(0.3, dur)); o2.start(t); o2.stop(t + dur + 0.1);
}
function noteOut(B, g, send, dly) { g.connect(B.mel); if (send) { const s = gainN(send); g.connect(s).connect(B.send); } if (dly) { const d = gainN(dly); g.connect(d).connect(B.dsend); } }
function iBell(B, t, f, dur, v) {
  const c = AU.ctx, car = c.createOscillator(), mod = c.createOscillator(), mg = c.createGain(), car2 = c.createOscillator(), g2 = gainN(0.22), g = c.createGain();
  car.frequency.value = f; mod.frequency.value = f * 3.5; car2.frequency.value = f * 2.002;
  mg.gain.setValueAtTime(f * 2.4, t); mg.gain.exponentialRampToValueAtTime(f * 0.12, t + 0.9);
  mod.connect(mg).connect(car.frequency); car.connect(g); car2.connect(g2).connect(g);
  g.gain.setValueAtTime(0.0001, t); g.gain.linearRampToValueAtTime(0.2 * (v || 1), t + 0.002); g.gain.setTargetAtTime(0.0001, t + 0.002, 0.32 + dur * 0.7);
  noteOut(B, g, 0.55, 0.35);
  const end = t + 2.6 + dur; car.start(t); mod.start(t); car2.start(t); car.stop(end); mod.stop(end); car2.stop(end);
}
function iPiano(B, t, f, dur, v) {
  const c = AU.ctx, g = gainN(0.0001), vel = v || 0.85, Bh = 0.00032;
  const reg = f < 180 ? 1.7 : f < 420 ? 1.15 : 0.7;
  const end = t + dur + 0.6;
  for (let n = 1; n <= 9; n++) {
    const fn = f * n * Math.sqrt(1 + Bh * n * n); if (fn > 9500) break;
    const amp = Math.pow(n, -1.15) * (n === 1 ? 1 : 0.55 + 0.45 * vel) * (n > 5 ? 0.6 : 1);
    const tau = 2.4 * reg / (1 + 0.42 * n);
    for (const det of n <= 2 ? [0, 1.6] : [0]) {
      const o = c.createOscillator(), og = c.createGain(); o.frequency.value = fn; o.detune.value = det;
      og.gain.setValueAtTime(0.0001, t); og.gain.linearRampToValueAtTime(amp * (det ? 0.5 : 1), t + 0.003);
      og.gain.setTargetAtTime(0.0001, t + 0.003, tau); og.gain.setTargetAtTime(0.0001, t + dur, 0.09);
      o.connect(og).connect(g); o.start(t); o.stop(end);
    }
  }
  const hn = noiseSrc(), hf = c.createBiquadFilter(), hg = c.createGain(); hf.type = 'lowpass'; hf.frequency.value = 2400;
  hn.connect(hf).connect(hg).connect(g); envG(hg, t, 0.001, 0.05 * vel, 0.01); hn.start(t, Math.random(), 0.05);
  g.gain.setValueAtTime(0.11 * vel, t);
  noteOut(B, g, 0.35, 0.12);
}
function iEP(B, t, f, dur, v) {
  const c = AU.ctx, car = c.createOscillator(), mod = c.createOscillator(), mg = c.createGain(), g = c.createGain(), trem = c.createOscillator(), tg = gainN(0.18), tw = gainN(1);
  car.frequency.value = f; mod.frequency.value = f;
  mg.gain.setValueAtTime(f * 1.6 * (v || 1), t); mg.gain.exponentialRampToValueAtTime(f * 0.08, t + 0.6);
  mod.connect(mg).connect(car.frequency);
  trem.frequency.value = 4.6; trem.connect(tg).connect(tw.gain);
  car.connect(tw).connect(g);
  g.gain.setValueAtTime(0.0001, t); g.gain.linearRampToValueAtTime(0.14 * (v || 1), t + 0.004); g.gain.setTargetAtTime(0.0001, t + 0.004, 1.1); g.gain.setTargetAtTime(0.0001, t + dur, 0.15);
  noteOut(B, g, 0.25, 0);
  const end = t + dur + 0.9; car.start(t); mod.start(t); trem.start(t); car.stop(end); mod.stop(end); trem.stop(end);
}
const VOWELS = { ah: [[730, 8, 1], [1090, 9, 0.5], [2440, 10, 0.22]], oo: [[300, 7, 1], [870, 8, 0.35], [2240, 10, 0.12]], ay: [[660, 7, 1], [1720, 9, 0.55], [2410, 10, 0.25]], oh: [[570, 7, 1], [840, 8, 0.45], [2410, 10, 0.18]] };
function vibrato(o, t, rate, cents, delay) { const c = AU.ctx, l = c.createOscillator(), lg = gainN(0); l.frequency.value = rate; l.connect(lg).connect(o.detune); lg.gain.setValueAtTime(0, t); lg.gain.linearRampToValueAtTime(cents, t + (delay || 0.3)); l.start(t); return l; }
function iChoir(B, t, f, dur, v, vowel) {
  const c = AU.ctx, sum = gainN(1), g = gainN(0.0001), end = t + dur + 0.8;
  const forms = VOWELS[vowel || (f < 220 ? 'oo' : 'ah')];
  for (const [ff, q, a] of forms) { const bp = c.createBiquadFilter(); bp.type = 'bandpass'; bp.frequency.value = ff; bp.Q.value = q; const ga = gainN(a * 3); sum.connect(bp).connect(ga).connect(g); }
  for (const det of [-9, 0, 8]) { const o = c.createOscillator(); o.type = 'sawtooth'; o.frequency.value = f; o.detune.value = det; const l = vibrato(o, t, 4.8 + Math.random(), 7, 0.4); o.connect(sum); o.start(t); o.stop(end); l.stop(end); }
  g.gain.setValueAtTime(0.0001, t); g.gain.linearRampToValueAtTime(0.05 * (v || 1), t + 0.35); g.gain.setValueAtTime(0.05 * (v || 1), t + Math.max(0.36, dur - 0.05)); g.gain.setTargetAtTime(0.0001, t + Math.max(0.36, dur - 0.05), 0.25);
  noteOut(B, g, 0.7, 0);
}
function iStrings(B, t, f, dur, v) {
  const c = AU.ctx, lp = c.createBiquadFilter(), g = gainN(0.0001), end = t + dur + 0.9;
  lp.type = 'lowpass'; lp.Q.value = 0.6; lp.frequency.setValueAtTime(700, t); lp.frequency.linearRampToValueAtTime(2300, t + 0.3);
  lp.connect(g);
  for (const det of [-11, -3, 6, 12]) { const o = c.createOscillator(); o.type = 'sawtooth'; o.frequency.value = f; o.detune.value = det; const l = vibrato(o, t, 5.4, 9, 0.35); o.connect(lp); o.start(t); o.stop(end); l.stop(end); }
  g.gain.setValueAtTime(0.0001, t); g.gain.linearRampToValueAtTime(0.035 * (v || 1), t + 0.2); g.gain.setValueAtTime(0.035 * (v || 1), t + Math.max(0.21, dur - 0.05)); g.gain.setTargetAtTime(0.0001, t + Math.max(0.21, dur - 0.05), 0.3);
  noteOut(B, g, 0.6, 0);
}
function iFlute(B, t, f, dur, v) {
  const c = AU.ctx, g = gainN(0.0001), end = t + dur + 0.4;
  for (const [m, a] of [[1, 1], [2, 0.14], [3, 0.05]]) { const o = c.createOscillator(); o.frequency.value = f * m; const og = gainN(a); const l = vibrato(o, t, 5.1, 14, 0.25); o.connect(og).connect(g); o.start(t); o.stop(end); l.stop(end); }
  const n = noiseSrc(), bp = c.createBiquadFilter(), ng = gainN(0.0001); bp.type = 'bandpass'; bp.frequency.value = f * 2; bp.Q.value = 2;
  n.connect(bp).connect(ng).connect(g); ng.gain.setValueAtTime(0.0001, t); ng.gain.linearRampToValueAtTime(0.35, t + 0.04); ng.gain.setTargetAtTime(0.08, t + 0.05, 0.08); ng.gain.setTargetAtTime(0.0001, t + dur, 0.06); n.start(t, Math.random(), dur + 0.4);
  g.gain.setValueAtTime(0.0001, t); g.gain.linearRampToValueAtTime(0.09 * (v || 1), t + 0.06); g.gain.setTargetAtTime(0.0001, t + dur, 0.1);
  noteOut(B, g, 0.5, 0.3);
}
function iChop(B, t, f, dur, v) {
  const c = AU.ctx, sum = gainN(1), g = gainN(0.0001), d = Math.min(dur, 0.24), end = t + d + 0.2;
  const forms = VOWELS[Math.random() < 0.5 ? 'ay' : 'oh'];
  for (const [ff, q, a] of forms) { const bp = c.createBiquadFilter(); bp.type = 'bandpass'; bp.frequency.value = ff; bp.Q.value = q; const ga = gainN(a * 3); sum.connect(bp).connect(ga).connect(g); }
  for (const det of [-6, 6]) { const o = c.createOscillator(); o.type = 'sawtooth'; o.frequency.setValueAtTime(f * 1.02, t); o.frequency.exponentialRampToValueAtTime(f, t + 0.03); o.detune.value = det; o.connect(sum); o.start(t); o.stop(end); }
  g.gain.setValueAtTime(0.0001, t); g.gain.linearRampToValueAtTime(0.09 * (v || 1), t + 0.006); g.gain.setValueAtTime(0.09 * (v || 1), t + d - 0.02); g.gain.linearRampToValueAtTime(0.0001, t + d);
  noteOut(B, g, 0.4, 0.25);
}
function iPad(B, t, freqs, dur, v) {
  const c = AU.ctx, lp = c.createBiquadFilter(), g = gainN(0.0001);
  lp.type = 'lowpass'; lp.frequency.value = 900; lp.Q.value = 0.5; lp.connect(g);
  for (const f of freqs) for (const det of [-7, 7]) { const o = c.createOscillator(); o.type = 'sawtooth'; o.frequency.value = f; o.detune.value = det; o.connect(lp); o.start(t); o.stop(t + dur + 0.4); }
  g.gain.setValueAtTime(0.0001, t); g.gain.linearRampToValueAtTime(0.026 * (v || 1), t + 0.35); g.gain.setValueAtTime(0.026 * (v || 1), t + dur - 0.2); g.gain.linearRampToValueAtTime(0.0001, t + dur + 0.3);
  noteOut(B, g, 0.6, 0);
}
function leadNote(B, inst, t, f, d, v) {
  switch (inst) {
    case 'piano': iPiano(B, t, f, Math.max(d, 0.25), v); break;
    case 'flute': iFlute(B, t, f * 2, d, v); break;
    case 'strings': iStrings(B, t, f, Math.max(d, 0.2), v * 1.1); break;
    case 'chop': iChop(B, t, f, d, v); break;
    case 'ep': iEP(B, t, f, d, v); break;
    default: iBell(B, t, f, d, v);
  }
}
function padChord(B, inst, t, fs, d, v) {
  if (inst === 'choir') for (const f of fs) iChoir(B, t, f, d, (v || 1) * 0.8);
  else if (inst === 'strings') for (const f of fs) iStrings(B, t, f / 2, d, (v || 1) * 0.6);
  else if (inst === 'ep') for (const f of fs) iEP(B, t, f, d, (v || 1) * 0.55);
  else if (inst !== 'none') iPad(B, t, fs, d, v);
}
function playEv(B, e, t, beat) {
  const st = beat.style, v = e.v === undefined ? 1 : e.v;
  switch (e.k) {
    case 'kick': iDrum(B, 'kick', t, 0.95 * v); break;
    case 'clap':
      if (st === 'lofi') iDrum(B, 'snare', t, 0.55 * v, 0.88, 0.15);
      else { iDrum(B, 'clap', t, 0.55 * v, 1, 0.32); iDrum(B, 'snare', t, 0.5 * v, st === 'uk' ? 1.07 : st === 'ny' ? 0.95 : 1, 0.28); }
      break;
    case 'hat': iDrum(B, 'hat', t, 0.3 * v, (e.tone || 7600) / 7600 * (st === 'lofi' ? 0.8 : 1)); break;
    case 'ohat': iDrum(B, 'ohat', t, 0.26 * v, 1, 0.08); break;
    case 'rim': iDrum(B, 'rim', t, 0.3 * v, 1, 0.25); break;
    case 'perc': iDrum(B, 'perc', t, 0.25 * v, e.r || 1, 0.3); break;
    case 'crash': iDrum(B, 'crash', t, 0.26 * v, 1, 0.2); break;
    case 'rev': iDrum(B, 'revcrash', t, 0.24 * v, 1, 0.1); break;
    case 'riser': iDrum(B, 'riser', t, 0.18 * v, 1, 0.3); break;
    case 'vinyl': iDrum(B, 'vinyl', t, 0.35, 1); break;
    case '808': i808(B, t, e.d, e.f, e.from, e.gl, v); break;
    case 'bell': leadNote(B, e.inst || beat.lead, t, e.f, e.d, (e.acc ? 1.1 : 0.85) * v); break;
    case 'pad': padChord(B, beat.pad, t, e.fs, e.d, v); break;
  }
}
/* ---------- sequencer (lookahead scheduler) ---------- */
const SEQS = new Set();
class Seq {
  constructor(ev, t0, B, beat) { this.ev = ev; this.t0 = t0; this.B = B; this.beat = beat; this.i = 0; this.loop = 0; this.dead = false; this.onDone = null; this.onLoop = null; B.seq = this; if (B.setTempo && beat.bpm) B.setTempo(beat.bpm); SEQS.add(this); this.pump(AU.ctx.currentTime); }
  pump(now) {
    const horizon = now + 1.4;
    while (!this.dead) {
      if (this.i >= this.ev.length) {
        if (this.loop) { this.t0 += this.loop; this.i = 0; if (this.onLoop) this.onLoop(this); continue; }
        SEQS.delete(this); this.dead = true; if (this.onDone) this.onDone(this); return;
      }
      const e = this.ev[this.i], t = this.t0 + e.t;
      if (t > horizon) return;
      this.i++;
      if (t < now - 0.03) continue;
      try { playEv(this.B, e, t, this.beat); } catch (err) { }
    }
  }
}
function pumpSeqs() { if (!AU.ready) return; const now = AU.ctx.currentTime; for (const s of SEQS) s.pump(now); }
function startSequencerClock() { setInterval(pumpSeqs, 50); }
function scheduleBeat(B, beat, t0) { return new Seq(beat.ev, t0, B, beat); }

/* ---------- composition ---------- */
const SCALE_MIN = [0, 2, 3, 5, 7, 8, 11];
function degSemi(d) { return SCALE_MIN[((d % 7) + 7) % 7] + 12 * Math.floor(d / 7); }
function makeMotif(R, density) {
  const motif = []; let deg = 2 + Math.floor(R() * 3);
  for (let s = 0; s < 32; s += 2) {
    if (R() < (s % 8 === 0 ? 0.92 : 0.5) * (density || 1)) {
      deg = clamp(deg + Math.floor(R() * 5) - 2, 0, 9);
      motif.push({ s, deg, dur: R() < 0.3 ? 4 : 2, acc: s % 8 === 0 });
      if (R() < 0.22) motif.push({ s: s + 1, deg: clamp(deg + 1, 0, 9), dur: 1, acc: false });
    }
  }
  return motif;
}
function drillPattern(seed, style) {
  style = style || 'chi';
  const R = rng(seed), IR = rng((seed ^ 0x5bd1e995) >>> 0);
  const bpm = style === 'ny' ? 144 : style === 'uk' ? 142 : 140, step = 60 / bpm / 4, bar = step * 16;
  const root = 25 + Math.floor(R() * 6);
  const progs = [[0, 8, 5, 7], [0, 8, 3, 7], [0, 5, 8, 7], [0, 3, 8, 10]];
  const prog = progs[Math.floor(R() * progs.length)];
  const motifA = makeMotif(R, 1);
  const kickPats = style === 'ny' ? [[0, 3, 7, 10, 13], [0, 6, 10, 14], [0, 3, 10, 12]] : style === 'uk' ? [[0, 7, 10], [0, 3, 6, 10], [0, 10, 13]] : [[0, 10], [0, 7, 10], [0, 3, 10, 13], [0, 6, 11], [0, 10, 14]];
  const kpA = kickPats[Math.floor(R() * kickPats.length)], kpB = kickPats[Math.floor(R() * kickPats.length)];
  const hatPats = style === 'uk' || style === 'ny' ? [[0, 4 / 3, 8 / 3, 4, 6, 22 / 3, 26 / 3, 10, 12, 40 / 3, 44 / 3], [0, 2, 3, 6, 8, 10, 11, 14]] : [[0, 2, 4, 6, 8, 10, 12, 14], [0, 3, 6, 8, 11, 14], [0, 4 / 3, 8 / 3, 4, 6, 8, 28 / 3, 32 / 3, 12, 14]];
  const hp = hatPats[Math.floor(R() * hatPats.length)];
  const leads = style === 'uk' ? ['piano', 'flute', 'bell', 'strings'] : style === 'ny' ? ['chop', 'piano', 'bell', 'chop'] : ['bell', 'bell', 'piano', 'piano', 'flute'];
  const pads = style === 'uk' ? ['strings', 'choir'] : style === 'ny' ? ['choir', 'choir', 'pad'] : ['pad', 'choir', 'strings'];
  const lead = leads[Math.floor(IR() * leads.length)], pad = pads[Math.floor(IR() * pads.length)];
  const motifB = makeMotif(IR, 0.55);
  return { R, IR, style, bpm, step, bar, root, prog, motifA, motifB, kpA, kpB, hp, lead, pad, prev808: null };
}
// one bar of drill. sec: intro | hook | verse | bridge | outro ; i = bar index within section, n = section length
function emitDrillBar(ev, P, b, sec, i, n, o) {
  o = o || {};
  const R = P.R, step = P.step, t0 = b * P.bar, ch = P.prog[b % 4], style = P.style;
  const drums = sec === 'hook' || sec === 'verse' || (sec === 'outro' && i < 2);
  const fade = sec === 'outro' ? 1 - i / n * 0.7 : 1;
  const motif = sec === 'verse' ? P.motifB : P.motifA;
  if (sec !== 'verse' || i % 4 < 2 || o.forceMel) for (const m of motif) {
    if ((m.s >> 4) !== (b % 2)) continue;
    ev.push({ t: t0 + (m.s % 16) * step, k: 'bell', f: NOTE(P.root + 36 + degSemi(m.deg)), d: m.dur * step, acc: m.acc, intro: !drums, v: fade });
  }
  const major = (ch === 8 || ch === 3 || ch === 10 || ch === 7);
  const pr = P.root + 36 + ch - (ch > 6 ? 12 : 0);
  ev.push({ t: t0, k: 'pad', fs: [NOTE(pr), NOTE(pr + (major ? 4 : 3)), NOTE(pr + 7)], d: P.bar, v: fade });
  const hatsOn = drums || sec === 'bridge' || (sec === 'intro' && i === n - 1);
  if (hatsOn) {
    const hv = drums ? 1 : 0.55;
    const roll = !drums ? null : (b % 4 === 3) ? (R() < 0.5 ? 'trip' : '32') : (b % 4 === 1 && R() < 0.6 ? 'short' : null);
    for (const h of P.hp) {
      if ((roll === 'trip' || roll === '32') && h >= 12) continue;
      if (roll === 'short' && h >= 6 && h < 8) continue;
      ev.push({ t: t0 + h * step, k: 'hat', v: hv * (h % 4 === 0 ? 1 : 0.7), roll: false, off: (h % 4) !== 0 });
    }
    if (roll === 'trip') for (let k = 0; k < 6; k++) ev.push({ t: t0 + (12 + k * 2 / 3) * step, k: 'hat', v: hv * (0.45 + k * 0.1), roll: k === 0 ? 'start' : 'mid', tone: 6500 + k * 450 });
    if (roll === '32') for (let k = 0; k < 8; k++) ev.push({ t: t0 + (12 + k * 0.5) * step, k: 'hat', v: hv * (0.4 + k * 0.08), roll: k === 0 ? 'start' : 'mid', tone: 7000 + (k % 2) * 900 });
    if (roll === 'short') for (let k = 0; k < 4; k++) ev.push({ t: t0 + (6 + k * 0.5) * step, k: 'hat', v: hv * 0.6, roll: k === 0 ? 'start' : 'mid' });
    if (b % 2 === 1 && drums) ev.push({ t: t0 + 14 * step, k: 'ohat', v: 0.7 });
  }
  // build into the drop
  if (i === n - 1 && (sec === 'intro' || sec === 'bridge')) {
    for (let k = 0; k < 4; k++) ev.push({ t: t0 + (12 + k) * step, k: 'clap', v: 0.3 + k * 0.15, main: false, build: true });
    ev.push({ t: t0 + P.bar - 2.15, k: 'riser', v: 1 });
    ev.push({ t: t0 + P.bar - 1.55, k: 'rev', v: 1 });
  }
  if (!drums) { P.prev808 = null; return; }
  if (i === 0 && sec === 'hook') ev.push({ t: t0, k: 'crash', v: 1 });
  ev.push({ t: t0 + 8 * step, k: 'clap', v: 1 * fade, main: true });
  if (b % 2 === 1 && R() < 0.6) ev.push({ t: t0 + 15 * step, k: 'clap', v: 0.5, main: false });
  if (style !== 'chi' && b % 2 === 0) ev.push({ t: t0 + (style === 'uk' ? 13 : 6) * step, k: 'clap', v: 0.45, main: false });
  if (style === 'uk') { ev.push({ t: t0 + 3 * step, k: 'rim', v: 0.35 }); if (b % 2) ev.push({ t: t0 + 11 * step, k: 'rim', v: 0.3 }); }
  if (style === 'ny') { ev.push({ t: t0 + 6 * step, k: 'perc', v: 0.4, r: 1 }); ev.push({ t: t0 + 13 * step, k: 'perc', v: 0.32, r: 1.33 }); }
  if (o.endHit) { ev.push({ t: t0, k: 'kick', v: 1, s: 0 }); ev.push({ t: t0, k: '808', f: NOTE(P.root + 12), d: P.bar * 0.9, from: P.prev808 ? NOTE(P.prev808) : null, gl: 0.08, withKick: true }); return; }
  const kp = (b % 4 < 2) ? P.kpA : P.kpB;
  for (let k = 0; k < kp.length; k++) {
    const s = kp[k];
    ev.push({ t: t0 + s * step, k: 'kick', v: s === 0 ? 1 : 0.85, s });
    const next = k + 1 < kp.length ? kp[k + 1] : 16;
    let note = P.root + 12 + ch - (ch > 6 ? 12 : 0);
    if (k > 0 && R() < 0.3) note += (R() < 0.5 ? 7 : -5);
    const glide = P.prev808 !== null && P.prev808 !== note && R() < (style === 'chi' ? 0.45 : 0.8);
    ev.push({ t: t0 + s * step, k: '808', f: NOTE(note), d: (next - s) * step * 0.96, from: glide ? NOTE(P.prev808) : null, gl: 0.07, withKick: true });
    P.prev808 = note;
  }
  if (R() < 0.45) {
    const note = P.root + 24 + ch - (ch > 6 ? 12 : 0);
    ev.push({ t: t0 + 14.5 * step, k: '808', f: NOTE(note - 12), d: 1.4 * step, from: NOTE(note), gl: 0.12, withKick: false, slide: true });
  }
}
// Studio beat + note chart. type: tribute | wayout | diss ; style: chi | uk | ny
function buildBeat(seed, type, style) {
  const P = drillPattern(seed, style);
  const R = P.R, bars = 16, ev = [];
  for (let b = 0; b < bars; b++) {
    if (b < 2) emitDrillBar(ev, P, b, 'intro', b, 2);
    else emitDrillBar(ev, P, b, 'hook', b - 2, bars - 2, { endHit: b === bars - 1 });
  }
  ev.sort((a, b) => a.t - b.t);
  const bar = P.bar;
  const lvl = type === 'diss' ? 3 : type === 'wayout' ? 2 : 1;
  const cand = [];
  for (const e of ev) {
    if (e.t < bar * 0.98) continue;
    if (e.k === 'kick') cand.push({ t: e.t, lane: 0, need: e.s === 0 ? 1 : 2 });
    else if (e.k === 'clap') cand.push({ t: e.t, lane: 1, need: e.main ? 1 : (e.build ? 1 : 3) });
    else if (e.k === '808' && (!e.withKick || e.slide)) cand.push({ t: e.t, lane: 2, need: 2 });
    else if (e.k === 'bell') cand.push({ t: e.t, lane: e.intro ? (e.acc ? 2 : 3) : 3, need: e.intro || e.acc ? 1 : 3 });
    else if (e.k === 'hat' && e.roll === 'start') cand.push({ t: e.t, lane: 3, need: 2 });
    else if (e.k === 'hat' && e.roll === 'mid') cand.push({ t: e.t, lane: 3, need: 4 });
    else if (e.k === 'hat' && e.off) cand.push({ t: e.t, lane: 2, need: 3, p: 0.4 });
    else if (e.k === 'ohat') cand.push({ t: e.t, lane: 3, need: 2 });
  }
  const notes = [], lastLane = [-9, -9, -9, -9];
  for (const c of cand) {
    if (c.need > lvl) continue;
    if (c.p && R() > c.p) continue;
    if (c.t - lastLane[c.lane] < 0.2) continue;
    if (notes.filter(n => Math.abs(n.t - c.t) < 0.02).length >= 2) continue;
    const near = notes.length && (c.t - notes[notes.length - 1].t) < 0.1 && Math.abs(c.t - notes[notes.length - 1].t) > 0.02;
    if (near) continue;
    notes.push({ t: c.t, lane: c.lane, hit: null });
    lastLane[c.lane] = c.t;
  }
  return { ev, notes, dur: bars * bar, bar, step: P.step, root: P.root, style: P.style, bpm: P.bpm, lead: P.lead, pad: P.pad };
}
const SONG_FORM = [['intro', 4], ['hook', 8], ['verse', 8], ['hook', 8], ['bridge', 4], ['verse', 8], ['hook', 8], ['outro', 4]];
const SONG_BARS = SONG_FORM.reduce((a, s) => a + s[1], 0);
function composeSong(seed, style) {
  if (style === 'lofi') return composeLofi(seed);
  const P = drillPattern(seed, style), ev = [];
  let b = 0;
  for (const [sec, n] of SONG_FORM) for (let i = 0; i < n; i++, b++) emitDrillBar(ev, P, b, sec, i, n);
  ev.sort((a, c) => a.t - c.t);
  return { ev, dur: b * P.bar, bpm: P.bpm, style: P.style, lead: P.lead, pad: P.pad, bar: P.bar };
}
const LOFI_BARS = 32;
function composeLofi(seed) {
  const R = rng(seed), bpm = 82, step = 60 / bpm / 4, bar = step * 16, ev = [];
  const root = 45 + Math.floor(R() * 7);
  const progs = [[[0, 3, 7, 10, 14], [5, 8, 12, 15, 19], [-4, 0, 3, 7, 10], [-5, -1, 2, 5, 9]], [[0, 3, 7, 10, 14], [-2, 2, 5, 9, 12], [-4, 0, 3, 7, 11], [-5, -1, 2, 5, 8]]];
  const prog = progs[Math.floor(R() * progs.length)];
  const sw = s => s + (s % 2 ? 0.28 : 0);
  for (let b = 0; b < LOFI_BARS; b++) {
    const t0 = b * bar, ch = prog[b % 4], drums = b >= 2 && b < LOFI_BARS - 1;
    ev.push({ t: t0, k: 'pad', fs: ch.slice(1).map(m => NOTE(root + 12 + m)), d: bar * 0.95, v: 1 });
    if (b % 2 === 0) ev.push({ t: t0, k: 'vinyl' });
    if (R() < 0.7) for (let k = 0; k < 3; k++) { const s = 4 + Math.floor(R() * 10); ev.push({ t: t0 + sw(s) * step, k: 'bell', f: NOTE(root + 24 + ch[1 + Math.floor(R() * 4)]), d: step * (2 + Math.floor(R() * 3)), acc: false, v: 0.7 }); }
    if (!drums) continue;
    for (const s of [0, 7, 10]) if (s === 0 || R() < 0.75) ev.push({ t: t0 + sw(s) * step, k: 'kick', v: s === 0 ? 0.85 : 0.6 });
    for (const s of [4, 12]) ev.push({ t: t0 + s * step, k: 'clap', v: 0.8 });
    for (let s = 0; s < 16; s += 2) ev.push({ t: t0 + sw(s) * step, k: 'hat', v: 0.45 + R() * 0.3, tone: 6600 });
    ev.push({ t: t0, k: '808', f: NOTE(root - 12 + ch[0]), d: step * 6, v: 0.55 });
    ev.push({ t: t0 + sw(10) * step, k: '808', f: NOTE(root - 12 + ch[0] + (R() < 0.5 ? 7 : 12)), d: step * 4, v: 0.45 });
  }
  ev.sort((a, c) => a.t - c.t);
  return { ev, dur: LOFI_BARS * bar, bpm, style: 'lofi', lead: 'ep', pad: 'ep', bar };
}

/* ---------- radio ---------- */
const STATIONS = [
  { name: 'Radio off', short: 'Off' },
  { name: 'WCLD 91.1 · Calder Drill', short: 'WCLD', style: 'chi', key: 11 },
  { name: 'Hawk 98.4 · UK Drill', short: 'Hawk', style: 'uk', key: 23 },
  { name: 'Northline 103.9 · NY Drill', short: 'North', style: 'ny', key: 37 },
  { name: 'Low End FM · After Hours', short: 'Low End', style: 'lofi', key: 53 },
  { name: 'Your tracks', short: 'Yours', yours: true },
];
const SONG_WORDS = ['Black Ice', 'Windchill', 'Low End', 'Thin Ice', 'Lake Effect', 'No Heat', 'Frostbite', 'Third Rail', 'Night Shift', 'Overcast', 'Whiteout', 'Sleet', 'Last Train', 'Platform 2', 'Snowplow', 'Zero Degrees', 'Static', 'Ghost Line', 'Steam', 'Calder Nights', 'Brick & Snow', 'Hawk Season', 'Garnet St', 'Harlan Ave', 'Cold Front', 'Slush Fund', 'Northbound', 'Under the L', 'Salt Truck', 'Space Heater'];
const SONG_ARTISTS = ['@frostline.808', '@sleetgang', '@harlan.hooks', '@lowend.lou', '@garnet.gz', '@coldfront.kay', '@thinice.tv', '@platform2', '@wren.wav', '@snowdrift.sav', '@windchill.dee', '@calder.kid', '@bishop.bandz', '@overcast.ollie', '@saltline', '@zero.f'];
function stationSongDur(st) { const s = STATIONS[st]; if (!s || !s.style) return 90; if (s.style === 'lofi') return LOFI_BARS * 240 / 82; const bpm = s.style === 'ny' ? 144 : s.style === 'uk' ? 142 : 140; return SONG_BARS * 240 / bpm; }
function stationSeed(st, k) { return (Math.imul(STATIONS[st].key * 2654435761 + k * 40503, 1) ^ (k * 2246822519)) >>> 0; }
function songMeta(st, k) { const R = rng(stationSeed(st, k) ^ 0x9e3779b9); return { title: SONG_WORDS[Math.floor(R() * SONG_WORDS.length)], artist: SONG_ARTISTS[Math.floor(R() * SONG_ARTISTS.length)] }; }
// Plays a station in sync with the shared world clock: everyone in the room hears the same song at the same moment.
class StationPlayer {
  constructor(st, out, gain, onSong) { this.st = st; this.out = out; this.gain = gain; this.onSong = onSong; this.B = null; this.stopped = false; this.yIdx = 0; this.start(); }
  start() {
    const now = AU.ctx.currentTime, s = STATIONS[this.st];
    if (s.yours) { this.playYours(now + 0.15); return; }
    const D = stationSongDur(this.st), T = worldSeconds(), k = Math.floor(T / D);
    this.play(k, now - (T - k * D));
  }
  play(k, t0) {
    if (this.stopped) return;
    const st = this.st, song = composeSong(stationSeed(st, k), STATIONS[st].style), D = stationSongDur(st);
    const B = makeBus(this.out, { gain: this.gain, verb: this.out === AU.radio || this.out === AU.music ? 0.3 : 0 });
    const old = this.B; this.B = B;
    const sq = new Seq(song.ev, t0, B, song);
    sq.onDone = () => this.play(k + 1, t0 + D);
    const now = AU.ctx.currentTime;
    if (old) setTimeout(() => killBus(old), Math.max(0, (t0 - now) * 1000 + 1500));
    if (this.onSong) { const m = songMeta(st, k); setTimeout(() => { if (!this.stopped && this.B === B) this.onSong(m); }, Math.max(0, (t0 - now) * 1000)); }
  }
  playYours(t0) {
    if (this.stopped) return;
    if (!S.tracks.length) { this.st = 1; this.start(); return; }
    const tr = S.tracks[this.yIdx++ % S.tracks.length];
    const beat = buildBeat(tr.seed || (tr.title.length * 7919), 'wayout', tr.style || 'chi');
    const B = makeBus(this.out, { gain: this.gain }); const old = this.B; this.B = B;
    const sq = new Seq(beat.ev, t0, B, beat); sq.onDone = () => this.playYours(t0 + beat.dur);
    if (old) setTimeout(() => killBus(old), Math.max(0, (t0 - AU.ctx.currentTime) * 1000 + 1500));
    if (this.onSong) setTimeout(() => { if (!this.stopped && this.B === B) this.onSong({ title: tr.title, artist: '@' + S.name }); }, Math.max(0, (t0 - AU.ctx.currentTime) * 1000));
  }
  stop() { this.stopped = true; killBus(this.B); this.B = null; }
}

/* ---------- adaptive score: ambient -> pulse -> full chase ---------- */
const SCORE = { on: false, seed: 0, buses: null, seqs: null, lvl: [0, 0, 0], target: [0, 0, 0], loops: 0, theme: false };
function scoreEvents(seed, theme) {
  const P = drillPattern(seed, 'chi');
  P.lead = theme ? 'piano' : (DN.lamps > 0.5 ? 'piano' : 'bell'); P.pad = theme || DN.lamps > 0.5 ? 'choir' : 'strings';
  const full = [], amb = [], pulse = [];
  for (let b = 0; b < 8; b++) {
    const ev = [];
    emitDrillBar(ev, P, b, 'hook', b, 8, { forceMel: true });
    for (const e of ev) {
      if (e.k === 'bell') { if (b % 2 === 0 || theme) amb.push(Object.assign({}, e, { v: 0.75 })); }
      else if (e.k === 'pad') amb.push(e);
      else full.push(e);
    }
    const t0 = b * P.bar, ch = P.prog[b % 4], n = P.root + 12 + ch - (ch > 6 ? 12 : 0);
    pulse.push({ t: t0, k: '808', f: NOTE(n), d: P.bar * 0.48, v: 0.7 });
    pulse.push({ t: t0 + P.bar * 0.625, k: '808', f: NOTE(n), d: P.bar * 0.3, v: 0.5 });
    for (let s = 0; s < 16; s += 2) pulse.push({ t: t0 + s * P.step, k: 'hat', v: s % 4 ? 0.25 : 0.4 });
    pulse.push({ t: t0 + 8 * P.step, k: 'rim', v: 0.45 });
  }
  const srt = a => a.sort((x, y) => x.t - y.t);
  return { amb: srt(amb), pulse: srt(pulse), full: srt(full), dur: 8 * P.bar, beat: { style: 'chi', lead: P.lead, pad: P.pad, bpm: P.bpm } };
}
function startScore(theme) {
  if (!AU.ready || SCORE.on) return;
  SCORE.on = true; SCORE.theme = !!theme; SCORE.seed = theme ? 808 : (Math.random() * 1e9) >>> 0; SCORE.loops = 0;
  const E = scoreEvents(SCORE.seed, theme), t0 = AU.ctx.currentTime + 0.2;
  SCORE.buses = [makeBus(AU.music, { gain: 0 }), makeBus(AU.music, { gain: 0 }), makeBus(AU.music, { gain: 0 })];
  const lists = [E.amb, E.pulse, E.full];
  SCORE.seqs = lists.map((ev, i) => { const s = new Seq(ev, t0, SCORE.buses[i], E.beat); s.loop = E.dur; return s; });
  SCORE.seqs[0].onLoop = () => {
    SCORE.loops++;
    if (SCORE.theme || SCORE.loops % 4) return;
    const N = scoreEvents((Math.random() * 1e9) >>> 0, false);
    SCORE.seqs.forEach((s, i) => { s.ev = [N.amb, N.pulse, N.full][i]; s.beat = N.beat; if (i) { s.i = 0; s.t0 = SCORE.seqs[0].t0; } });
  };
  SCORE.lvl = [0, 0, 0];
}
function stopScore() {
  if (!SCORE.on) return;
  SCORE.on = false;
  for (const B of SCORE.buses) killBus(B);
  SCORE.buses = null; SCORE.seqs = null;
}
function setScore(amb, pulse, full, dt) {
  if (!SCORE.on) return;
  const t = AU.ctx.currentTime, tg = [amb, pulse, full];
  for (let i = 0; i < 3; i++) {
    const rate = tg[i] > SCORE.lvl[i] ? 0.6 : 0.25;
    SCORE.lvl[i] += clamp(tg[i] - SCORE.lvl[i], -rate * dt, rate * dt);
    SCORE.buses[i].bus.gain.setTargetAtTime(SCORE.lvl[i] * (i === 2 ? 0.55 : 0.48), t, 0.1);
  }
}
