
/* =========================================================
   AUDIO CORE - procedural, physically motivated sound.
   3D listener + HRTF panning, air absorption, speed-of-sound
   delay, occlusion, facade slapback, convolution reverb, and a
   bank of one-shots rendered sample-by-sample at startup.
   ========================================================= */
const AU = { ctx: null, ready: false, bank: {}, voices: 0, sr: 48000, hrtf: true, indoor: false };
const SOUND_SPEED = 343;
const NOTE = m => 440 * Math.pow(2, (m - 69) / 12);
// Real recordings can replace any bank sound later: list names here and
// ship audio/<name>.mp3 next to the page (e.g. ['gun_k9', 'step_snow']).
const AUDIO_PACK = [];

function initAudio() {
  if (AU.ctx) { if (AU.ctx.state !== 'running') { try { AU.ctx.resume().then(soundBadge, soundBadge); } catch (e) { } } return; }
  const AC = window.AudioContext || window.webkitAudioContext;
  if (!AC) { AU.err = 'This browser has no Web Audio'; soundBadge(); return; }
  let ctx;
  try { ctx = new AC({ latencyHint: 'interactive' }); } catch (e) { try { ctx = new AC(); } catch (e2) { AU.err = e2.message; soundBadge(); return; } }
  AU.ctx = ctx; AU.sr = ctx.sampleRate;
  ctx.onstatechange = soundBadge;
  try { buildAudioGraph(ctx); } catch (e) { AU.err = 'Audio setup failed: ' + e.message; console.error('audio', e); }
  soundBadge();
}
function buildAudioGraph(ctx) {
  AU.hrtf = S.settings.quality !== 'low';
  const glue = ctx.createDynamicsCompressor();
  glue.threshold.value = -15; glue.knee.value = 8; glue.ratio.value = 3; glue.attack.value = 0.004; glue.release.value = 0.2;
  const lim = ctx.createDynamicsCompressor();
  lim.threshold.value = -2.5; lim.knee.value = 0; lim.ratio.value = 20; lim.attack.value = 0.001; lim.release.value = 0.07;
  glue.connect(lim).connect(ctx.destination);
  AU.limiter = lim;
  AU.master = gainN(S.settings.vol); AU.master.connect(glue);
  // the world bus can be muffled (hurt, downed, indoors)
  AU.duck = ctx.createBiquadFilter(); AU.duck.type = 'lowpass'; AU.duck.frequency.value = 20000; AU.duck.Q.value = 0.4;
  AU.worldOut = gainN(1); AU.duck.connect(AU.worldOut).connect(AU.master);
  AU.occl = ctx.createBiquadFilter(); AU.occl.type = 'lowpass'; AU.occl.frequency.value = 20000; AU.occl.Q.value = 0.4;
  AU.sfx = gainN(1); AU.sfx.connect(AU.occl).connect(AU.duck);
  AU.ui = gainN(0.85); AU.ui.connect(AU.master);
  AU.music = gainN(S.settings.music); AU.music.connect(AU.master);
  AU.ambLP = ctx.createBiquadFilter(); AU.ambLP.type = 'lowpass'; AU.ambLP.frequency.value = 18000;
  AU.amb = gainN(1); AU.amb.connect(AU.ambLP).connect(AU.duck);
  // reverbs: street (outdoor brick canyon), room (indoors), plate (music)
  const lite = LOW_POWER || S.settings.quality === 'low';
  AU.street = ctx.createConvolver(); AU.street.buffer = lite ? makeIR(1.5, 1.4, 'street') : makeIR(2.6, 2.1, 'street');
  AU.room = ctx.createConvolver(); AU.room.buffer = makeIR(lite ? 0.5 : 0.8, 0.45, 'room');
  AU.plate = ctx.createConvolver(); AU.plate.buffer = lite ? makeIR(1.8, 1.6, 'plate') : makeIR(3.2, 2.6, 'plate');
  AU.streetSend = gainN(1); AU.streetRet = gainN(0.62); AU.streetSend.connect(AU.street).connect(AU.streetRet).connect(AU.sfx);
  AU.roomSend = gainN(1); AU.roomRet = gainN(0.5); AU.roomSend.connect(AU.room).connect(AU.roomRet).connect(AU.sfx);
  AU.plateSend = gainN(1); AU.plateRet = gainN(0.55); AU.plateSend.connect(AU.plate).connect(AU.plateRet).connect(AU.music);
  // facade slapback: one echo per side, delay set from how far the walls are
  AU.slapSend = gainN(1);
  AU.slap = [-1, 1].map(side => {
    const d = ctx.createDelay(1); d.delayTime.value = 0.08;
    const f = ctx.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = 4200;
    const g = gainN(0); const p = ctx.createStereoPanner(); p.pan.value = side * 0.75;
    AU.slapSend.connect(d).connect(f).connect(g).connect(p).connect(AU.sfx);
    g.connect(AU.streetSend);
    return { d, g, side };
  });
  // noise sources for live synthesis
  AU.noise = noiseBuffer(2, 'white'); AU.pink = noiseBuffer(4, 'pink'); AU.brown = noiseBuffer(4, 'brown');
  const curve = new Float32Array(1024);
  for (let i = 0; i < 1024; i++) { const x = i / 511.5 - 1; curve[i] = Math.tanh(x * 3.4); }
  AU.curve = curve;
  AU.radio = radioBus();
  AU.ready = true;
  try { buildBank(); } catch (e) { console.error('audio bank', e); }
  try { startAmbience(); } catch (e) { console.error('ambience', e); }
  startSequencerClock();
  loadAudioPack();
}
// Browsers only let a page make sound after a tap/click/key press, and iOS mutes
// Web Audio when the silent switch is on unless a media element is playing.
function silentWavURL() {
  const n = 4000, b = new Uint8Array(44 + n), v = new DataView(b.buffer);
  const w = (o, s) => { for (let i = 0; i < s.length; i++) b[o + i] = s.charCodeAt(i); };
  w(0, 'RIFF'); v.setUint32(4, 36 + n, true); w(8, 'WAVE'); w(12, 'fmt '); v.setUint32(16, 16, true); v.setUint16(20, 1, true); v.setUint16(22, 1, true);
  v.setUint32(24, 8000, true); v.setUint32(28, 8000, true); v.setUint16(32, 1, true); v.setUint16(34, 8, true); w(36, 'data'); v.setUint32(40, n, true);
  b.fill(128, 44);
  let s = ''; for (let i = 0; i < b.length; i++) s += String.fromCharCode(b[i]);
  return 'data:audio/wav;base64,' + btoa(s);
}
function unlockAudio() {
  try { if (navigator.audioSession && navigator.audioSession.type !== 'playback') navigator.audioSession.type = 'playback'; } catch (e) { }
  initAudio();
  const c = AU.ctx; if (!c) return;
  if (c.state !== 'running' || AU.stalled) { try { c.resume().then(soundBadge, soundBadge); } catch (e) { } }
  try { const b = c.createBuffer(1, 1, c.sampleRate), s = c.createBufferSource(); s.buffer = b; s.connect(c.destination); s.start(0); } catch (e) { }
  const ios = /iPhone|iPad|iPod/.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  if (ios) {
    try {
      if (!AU.unmuteEl) { const el = document.createElement('audio'); el.setAttribute('x-webkit-airplay', 'deny'); el.setAttribute('playsinline', ''); el.preload = 'auto'; el.loop = true; el.src = silentWavURL(); AU.unmuteEl = el; }
      if (AU.unmuteEl.paused) { const p = AU.unmuteEl.play(); if (p && p.catch) p.catch(() => { }); }
    } catch (e) { }
  }
  soundBadge();
}
function soundState() {
  if (AU.err) return 'err';
  if (!AU.ctx) return 'off';
  if (AU.ctx.state !== 'running' || !AU.ready) return 'off';
  if (AU.stalled) return 'stuck';
  return 'on';
}
function soundBadge() {
  const el = document.getElementById('snd'); if (!el) return;
  const st = soundState();
  el.hidden = st === 'on' && MODE !== 'title';
  el.className = st;
  const t = el.querySelector('span');
  if (t) t.textContent = st === 'err' ? 'Sound unavailable · ' + AU.err : st === 'stuck' ? 'Sound stuck · tap to restart' : st === 'on' ? 'Sound on · tap to test' : 'Tap for sound';
}
// the audio clock must move while the context says it is running; webviews sometimes freeze it
let _wdT = -1, _wdN = 0;
setInterval(() => {
  if (!AU.ctx) return;
  const t = AU.ctx.currentTime;
  if (AU.ctx.state === 'running' && t === _wdT) { if (++_wdN >= 2 && !AU.stalled) { AU.stalled = true; soundBadge(); } }
  else { _wdN = 0; if (AU.stalled) { AU.stalled = false; soundBadge(); } }
  _wdT = t;
  soundBadge();
}, 600);
function soundTest() {
  unlockAudio();
  if (soundState() === 'on') { play('notif', { vol: 0.8 }); play('kick', { vol: 0.7, at: 0.25 }); }
}
function audioInfo() {
  const c = AU.ctx;
  if (!c) return 'not started (tap the screen)';
  return `${c.state}${AU.stalled ? ' · clock frozen' : ''} · ${Math.round(c.sampleRate / 100) / 10} kHz · clock ${c.currentTime.toFixed(1)} s · ${AU.bankReady ? 'sounds ready' : 'building sounds'}${AU.unmuteEl ? ' · iOS media mode ' + (AU.unmuteEl.paused ? 'off' : 'on') : ''}${navigator.audioSession ? ' · session ' + navigator.audioSession.type : ''}${AU.err ? ' · ' + AU.err : ''}`;
}
function gainN(v) { const g = AU.ctx.createGain(); g.gain.value = v; return g; }
function applyVolumes() {
  if (!AU.ready) return;
  AU.master.gain.setTargetAtTime(S.settings.vol, AU.ctx.currentTime, 0.05);
  AU.music.gain.setTargetAtTime(S.settings.music, AU.ctx.currentTime, 0.05);
}
function noiseBuffer(sec, color) {
  const n = Math.floor(AU.sr * sec), buf = AU.ctx.createBuffer(1, n, AU.sr), d = buf.getChannelData(0);
  let b0 = 0, b1 = 0, b2 = 0, b3 = 0, b4 = 0, b5 = 0, b6 = 0, br = 0;
  for (let i = 0; i < n; i++) {
    const w = Math.random() * 2 - 1;
    if (color === 'pink') {
      b0 = 0.99886 * b0 + w * 0.0555179; b1 = 0.99332 * b1 + w * 0.0750759; b2 = 0.969 * b2 + w * 0.153852;
      b3 = 0.8665 * b3 + w * 0.3104856; b4 = 0.55 * b4 + w * 0.5329522; b5 = -0.7616 * b5 - w * 0.016898;
      d[i] = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + w * 0.5362) * 0.11; b6 = w * 0.115926;
    } else if (color === 'brown') { br = (br + 0.02 * w) / 1.02; d[i] = br * 3.5; }
    else d[i] = w;
  }
  loopSeam(d, Math.floor(AU.sr * 0.05));
  return buf;
}
// crossfade the tail into the head so a buffer loops without a click
function loopSeam(d, x) {
  const n = d.length;
  for (let i = 0; i < x; i++) { const k = i / x; d[i] = d[i] * k + d[n - x + i] * (1 - k); }
  return d;
}
function makeIR(len, rt, kind) {
  const sr = AU.sr, n = Math.floor(len * sr), buf = AU.ctx.createBuffer(2, n, sr);
  const pre = kind === 'plate' ? 0.014 : kind === 'street' ? 0.006 : 0.002;
  for (let ch = 0; ch < 2; ch++) {
    const d = buf.getChannelData(ch);
    let lp = 0;
    for (let i = 0; i < n; i++) {
      const t = i / sr; if (t < pre) continue;
      const env = Math.exp(-6.91 * (t - pre) / rt);
      // highs die faster than lows: the smoothing gets heavier over time
      const a = kind === 'plate' ? 0.8 * Math.exp(-t * 1.1) + 0.1 : kind === 'room' ? 0.6 * Math.exp(-t * 4) + 0.08 : 0.55 * Math.exp(-t * 2.4) + 0.035;
      lp += a * ((Math.random() * 2 - 1) - lp);
      d[i] = lp * env * (kind === 'street' ? 0.55 : 1);
    }
    if (kind === 'street' || kind === 'room') {
      const N = kind === 'street' ? 16 : 22, span = kind === 'street' ? 0.19 : 0.03;
      for (let k = 0; k < N; k++) {
        const t = pre + 0.004 + Math.pow(Math.random(), 0.8) * span, i0 = Math.floor(t * sr);
        const amp = (1 - k / N) * (Math.random() < 0.5 ? 1 : -1) * (kind === 'street' ? 0.9 : 0.5);
        for (let j = 0; j < 60 && i0 + j < n; j++) d[i0 + j] += amp * Math.exp(-j / 7) * (j & 1 ? -0.35 : 1);
      }
    }
  }
  return buf;
}

/* ---------- listener ---------- */
const LIS = { x: 0, y: 0, z: 0, slapT: 0 };
const _lisV = new THREE.Vector3();
function updateListener(dt) {
  if (!AU.ready) return;
  const cp = camera.position, m = camera.matrixWorld.elements;
  _lisV.copy(cp);
  // third person: hear from between the camera and the player
  if ((MODE === 'play' || MODE === 'phone') && !P.dead) _lisV.lerp(P.car ? P.car.pos : P.pos, P.car ? 0.35 : 0.55).setY(lerp(cp.y, (P.car ? 1.2 : P.pos.y + 1.6), 0.5));
  LIS.x = _lisV.x; LIS.y = _lisV.y; LIS.z = _lisV.z;
  const L = AU.ctx.listener;
  const fx = -m[8], fy = -m[9], fz = -m[10], ux = m[4], uy = m[5], uz = m[6];
  if (L.positionX) {
    L.positionX.value = LIS.x; L.positionY.value = LIS.y; L.positionZ.value = LIS.z;
    L.forwardX.value = fx; L.forwardY.value = fy; L.forwardZ.value = fz; L.upX.value = ux; L.upY.value = uy; L.upZ.value = uz;
  } else { L.setPosition(LIS.x, LIS.y, LIS.z); L.setOrientation(fx, fy, fz, ux, uy, uz); }
  // slapback: how far are the facades to the left and right?
  LIS.slapT -= dt;
  if (LIS.slapT <= 0) {
    LIS.slapT = 0.35;
    const rx = m[0], rz = m[2], t = AU.ctx.currentTime;
    for (const s of AU.slap) {
      const d = raycastWorld(LIS.x, LIS.y, LIS.z, rx * s.side, 0, rz * s.side, 70);
      const ok = d !== Infinity && d > 1.5 && !AU.indoor;
      s.d.delayTime.setTargetAtTime(ok ? Math.min(0.42, 2 * d / SOUND_SPEED) : 0.3, t, 0.1);
      s.g.gain.setTargetAtTime(ok ? 0.42 / (1 + d / 18) : 0, t, 0.1);
    }
  }
}
function distToListener(x, y, z) { return Math.hypot(x - LIS.x, (y === undefined ? LIS.y : y) - LIS.y, z - LIS.z); }
// legacy helper: rough pan/gain for code that does its own mixing
const _camRight = new THREE.Vector3();
function spatial(x, z, y) {
  const d = distToListener(x, y, z);
  const m = camera.matrixWorld.elements; _camRight.set(m[0], m[1], m[2]);
  const pan = clamp(((x - LIS.x) * _camRight.x + (z - LIS.z) * _camRight.z) / (d + 2), -1, 1) * 0.85;
  return { d, gain: 1 / (1 + d * 0.055), pan, lp: 18000 / (1 + d * 0.045) };
}
function occluded(x, y, z, d) {
  if (d < 4 || d > 260) return false;
  const dx = (x - LIS.x) / d, dy = (y - LIS.y) / d, dz = (z - LIS.z) / d;
  const hit = raycastWorld(LIS.x, LIS.y, LIS.z, dx, dy, dz, d - 1);
  return hit < d - 1.5;
}
function makePanner(ref, roll, d) {
  const p = AU.ctx.createPanner();
  p.panningModel = AU.hrtf && !(d > 30) ? 'HRTF' : 'equalpower'; p.distanceModel = 'inverse';
  p.refDistance = ref || 2.5; p.rolloffFactor = roll || 1; p.maxDistance = 10000;
  p.coneInnerAngle = 360; p.coneOuterAngle = 360;
  return p;
}
function setPannerPos(p, x, y, z) { if (p.positionX) { p.positionX.value = x; p.positionY.value = y; p.positionZ.value = z; } else p.setPosition(x, y, z); }

/* ---------- one-shot voices ---------- */
// o: { x, y, z, vol, rate, wet, slap, at, lp, ref, roll, bus, ui, nodelay, occlude, detune }
function voice(buf, o) {
  if (!AU.ready || !buf) return null;
  o = o || {};
  if (AU.voices > 64 && !o.force) return null;
  const ctx = AU.ctx, src = ctx.createBufferSource();
  src.buffer = buf; src.playbackRate.value = o.rate || 1; if (o.detune) src.detune.value = o.detune;
  const g = ctx.createGain(); g.gain.value = o.vol === undefined ? 1 : o.vol;
  src.connect(g);
  let t = ctx.currentTime + (o.at || 0);
  const nodes = [src, g];
  if (o.x === undefined || o.ui) g.connect(o.bus || AU.ui);
  else {
    const y = o.y === undefined ? LIS.y - 0.4 : o.y;
    const d = distToListener(o.x, y, o.z);
    if (!o.nodelay) t += Math.min(1.4, d / SOUND_SPEED);
    let cut = 20000 / (1 + d / 75), occ = 1;
    if (o.occlude !== false && occluded(o.x, y, o.z, d)) { cut = Math.min(cut, 700 + 6000 / (1 + d / 12)); occ = 0.5; }
    const air = ctx.createBiquadFilter(); air.type = 'lowpass'; air.frequency.value = Math.max(320, cut * (o.lp || 1)); air.Q.value = 0.5;
    const pan = makePanner(o.ref, o.roll, d); setPannerPos(pan, o.x, y, o.z);
    g.gain.value *= occ;
    g.connect(air).connect(pan).connect(o.bus || AU.sfx);
    nodes.push(air, pan);
    const wet = (o.wet === undefined ? 0.22 : o.wet) * (0.35 + Math.min(1.7, d / 45)) / (1 + d / 28) * (o.vol === undefined ? 1 : o.vol) * (occ < 1 ? 1.4 : 1);
    if (wet > 0.004) { const ws = gainN(wet); air.connect(ws).connect(AU.indoor ? AU.roomSend : AU.streetSend); nodes.push(ws); }
    if (o.slap) { const ss = gainN(o.slap / (1 + d / 25) * (o.vol === undefined ? 1 : o.vol)); air.connect(ss).connect(AU.slapSend); nodes.push(ss); }
  }
  AU.voices++;
  src.onended = () => { AU.voices--; for (const n of nodes) { try { n.disconnect(); } catch (e) { } } };
  src.start(t);
  return { src, g, t };
}
function bankPick(name) { const v = AU.bank[name]; if (!v) return null; return Array.isArray(v) ? v[Math.floor(Math.random() * v.length)] : v; }
function play(name, o) { return voice(bankPick(name), o); }

/* ---------- persistent emitters (engines, sirens, fires, music leaks) ---------- */
class Emitter {
  constructor(o) {
    o = o || {};
    const ctx = AU.ctx;
    this.in = gainN(1); this.out = gainN(0);
    this.air = ctx.createBiquadFilter(); this.air.type = 'lowpass'; this.air.frequency.value = 18000; this.air.Q.value = 0.5;
    this.pan = makePanner(o.ref || 3, o.roll || 1);
    this.wetG = gainN(0);
    this.in.connect(this.air).connect(this.out).connect(this.pan).connect(o.bus || AU.sfx);
    this.air.connect(this.wetG).connect(AU.streetSend);
    this.wet = o.wet === undefined ? 0.18 : o.wet; this.lpMul = o.lp || 1;
    this.d = 999; this.dPrev = null; this.doppler = 1; this.occ = 1; this.occT = 0; this.level = 1;
    this.x = 0; this.y = 0; this.z = 0;
  }
  set(x, y, z, dt, level) {
    this.x = x; this.y = y; this.z = z; if (level !== undefined) this.level = level;
    const t = AU.ctx.currentTime, d = distToListener(x, y, z);
    setPannerPos(this.pan, x, y, z);
    if (this.dPrev !== null && dt > 0) {
      const vr = clamp((d - this.dPrev) / dt, -60, 60);
      this.doppler = lerp(this.doppler, SOUND_SPEED / (SOUND_SPEED + vr), Math.min(1, dt * 6));
    }
    this.dPrev = d; this.d = d;
    this.occT -= dt;
    if (this.occT <= 0) { this.occT = 0.25; this.occ = occluded(x, y, z, d) ? 0.45 : 1; }
    const cut = Math.max(300, 20000 / (1 + d / 75) * (this.occ < 1 ? 0.12 : 1) * this.lpMul);
    this.air.frequency.setTargetAtTime(cut, t, 0.08);
    this.out.gain.setTargetAtTime(this.level * (this.occ < 1 ? 0.6 : 1), t, 0.08);
    this.wetG.gain.setTargetAtTime(this.level * this.wet * (0.35 + Math.min(1.7, d / 45)) / (1 + d / 28), t, 0.1);
  }
  kill() { const t = AU.ctx.currentTime; this.out.gain.setTargetAtTime(0, t, 0.08); this.wetG.gain.setTargetAtTime(0, t, 0.08); const s = this; setTimeout(() => { try { s.pan.disconnect(); s.wetG.disconnect(); s.in.disconnect(); } catch (e) { } }, 700); }
}
function loopSrc(buf, dest, rate) {
  const s = AU.ctx.createBufferSource(); s.buffer = buf; s.loop = true; s.playbackRate.value = rate || 1;
  if (dest) s.connect(dest); s.start(AU.ctx.currentTime, Math.random() * buf.duration * 0.9);
  return s;
}

/* ---------- legacy primitives still used by a few systems ---------- */
function noiseSrc(loop) { const s = AU.ctx.createBufferSource(); s.buffer = AU.noise; s.loop = !!loop; return s; }
function envG(g, t, a, peak, d) {
  g.gain.setValueAtTime(0.0001, t);
  g.gain.linearRampToValueAtTime(peak, t + a);
  g.gain.exponentialRampToValueAtTime(0.0001, t + a + d);
}
function sfxTone(f, dur, type, vol, when, dest) {
  if (!AU.ready) return;
  const ctx = AU.ctx, t = ctx.currentTime + (when || 0);
  const o = ctx.createOscillator(), g = ctx.createGain();
  o.type = type || 'sine'; o.frequency.value = f;
  o.connect(g).connect(dest || AU.ui); envG(g, t, 0.005, vol || 0.2, dur); o.start(t); o.stop(t + dur + 0.05);
}
function sfxOut(x, z, vol) {
  const e = { out: AU.ctx.createGain() };
  const pan = makePanner(3, 1); setPannerPos(pan, x, LIS.y - 0.3, z);
  e.out.gain.value = vol; e.out.connect(pan).connect(AU.sfx);
  setTimeout(() => { try { pan.disconnect(); } catch (err) { } }, 3000);
  return e.out;
}

/* =========================================================
   DSP KIT - sample-level synthesis for the sound bank
   ========================================================= */
const DSP = {
  n(sec) { return Math.max(1, Math.floor(sec * AU.sr)); },
  z(sec) { return new Float32Array(DSP.n(sec)); },
  noise(sec) { const a = DSP.z(sec); for (let i = 0; i < a.length; i++) a[i] = Math.random() * 2 - 1; return a; },
  coef(type, f, q, db) {
    const w = 2 * Math.PI * clamp(f, 10, AU.sr * 0.49) / AU.sr, cs = Math.cos(w), sn = Math.sin(w), al = sn / (2 * (q || 0.707)), A = Math.pow(10, (db || 0) / 40);
    let b0, b1, b2, a0, a1, a2;
    switch (type) {
      case 'lp': b0 = (1 - cs) / 2; b1 = 1 - cs; b2 = b0; a0 = 1 + al; a1 = -2 * cs; a2 = 1 - al; break;
      case 'hp': b0 = (1 + cs) / 2; b1 = -(1 + cs); b2 = b0; a0 = 1 + al; a1 = -2 * cs; a2 = 1 - al; break;
      case 'bp': b0 = al; b1 = 0; b2 = -al; a0 = 1 + al; a1 = -2 * cs; a2 = 1 - al; break;
      case 'peak': b0 = 1 + al * A; b1 = -2 * cs; b2 = 1 - al * A; a0 = 1 + al / A; a1 = -2 * cs; a2 = 1 - al / A; break;
      default: b0 = 1; b1 = 0; b2 = 0; a0 = 1; a1 = 0; a2 = 0;
    }
    return [b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0];
  },
  filt(x, type, f, q, db) {
    const [b0, b1, b2, a1, a2] = DSP.coef(type, f, q, db);
    let x1 = 0, x2 = 0, y1 = 0, y2 = 0;
    for (let i = 0; i < x.length; i++) { const x0 = x[i], y0 = b0 * x0 + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2; x2 = x1; x1 = x0; y2 = y1; y1 = y0; x[i] = y0; }
    return x;
  },
  // exponential cutoff sweep f0 -> f1 over T seconds
  sweep(x, type, f0, f1, q, T) {
    let x1 = 0, x2 = 0, y1 = 0, y2 = 0, c = null;
    const n = x.length, TN = Math.max(1, T * AU.sr);
    for (let i = 0; i < n; i++) {
      if ((i & 31) === 0) { const k = Math.min(1, i / TN); c = DSP.coef(type, f0 * Math.pow(f1 / f0, k), q); }
      const x0 = x[i], y0 = c[0] * x0 + c[1] * x1 + c[2] * x2 - c[3] * y1 - c[4] * y2; x2 = x1; x1 = x0; y2 = y1; y1 = y0; x[i] = y0;
    }
    return x;
  },
  // attack (linear) then exponential decay with time-constant tau
  env(x, a, tau, hold) {
    const A = Math.max(1, a * AU.sr), H = (hold || 0) * AU.sr, T = tau * AU.sr;
    for (let i = 0; i < x.length; i++) x[i] *= i < A ? i / A : i < A + H ? 1 : Math.exp(-(i - A - H) / T);
    return x;
  },
  // sine (or other) with exponential pitch glide
  tone(sec, f0, f1, T, shape) {
    const a = DSP.z(sec), TN = Math.max(1, (T || sec) * AU.sr); let ph = 0;
    for (let i = 0; i < a.length; i++) {
      const f = f1 ? f0 * Math.pow(f1 / f0, Math.min(1, i / TN)) : f0;
      ph += f / AU.sr; ph -= Math.floor(ph);
      a[i] = shape === 'saw' ? 2 * ph - 1 : shape === 'tri' ? 1 - 4 * Math.abs(ph - 0.5) : shape === 'sq' ? (ph < 0.5 ? 1 : -1) : Math.sin(ph * 2 * Math.PI);
    }
    return a;
  },
  add(dst, src, at, g) { const o = Math.floor((at || 0) * AU.sr); const gg = g === undefined ? 1 : g; for (let i = 0; i < src.length && o + i < dst.length; i++) if (o + i >= 0) dst[o + i] += src[i] * gg; return dst; },
  sat(x, drive) { const k = Math.tanh(drive); for (let i = 0; i < x.length; i++) x[i] = Math.tanh(x[i] * drive) / k; return x; },
  norm(x, peak) { let px = 0, py = 0; for (let i = 0; i < x.length; i++) { const y = x[i] - px + 0.998 * py; px = x[i]; py = y; x[i] = y; } let m = 0; for (let i = 0; i < x.length; i++) m = Math.max(m, Math.abs(x[i])); if (m > 0) { const k = (peak || 0.95) / m; for (let i = 0; i < x.length; i++) x[i] *= k; } return x; },
  fadeOut(x, sec) { const n = Math.min(x.length, Math.floor(sec * AU.sr)); for (let i = 0; i < n; i++) x[x.length - 1 - i] *= i / n; return x; },
  // a short metallic/mechanical click
  click(dst, at, f, amp) { const c = DSP.noise(0.02); DSP.filt(c, 'bp', f, 3.5); DSP.env(c, 0.0002, 0.0032); DSP.add(dst, c, at, amp * 2.2); const r = DSP.tone(0.04, f * 1.63); DSP.env(r, 0.0004, 0.008); DSP.add(dst, r, at, amp * 0.25); },
  // modal ring: partials [f, tau, amp]
  modes(dst, at, parts, amp) { for (const [f, tau, a] of parts) { const r = DSP.tone(Math.min(2.5, tau * 7), f * (0.97 + Math.random() * 0.06)); DSP.env(r, 0.0003, tau); DSP.add(dst, r, at, a * amp); } },
  // sparse granular crunch (snow, gravel, debris)
  grains(dst, at, span, count, f0, f1, amp, shape) {
    for (let k = 0; k < count; k++) {
      const u = Math.pow(Math.random(), shape || 0.8), t = at + u * span;
      const g = DSP.noise(0.0006 + Math.random() * 0.0028);
      DSP.filt(g, 'bp', f0 + Math.random() * (f1 - f0), 1.2 + Math.random() * 3);
      DSP.env(g, 0.0001, 0.0009 + Math.random() * 0.0015);
      DSP.add(dst, g, t, amp * (0.25 + Math.random()) * (1 - u * 0.7));
    }
  },
  mono(x) { const b = AU.ctx.createBuffer(1, x.length, AU.sr); b.getChannelData(0).set(x); return b; },
  stereo(l, r) { const n = Math.max(l.length, r.length), b = AU.ctx.createBuffer(2, n, AU.sr); b.getChannelData(0).set(l); b.getChannelData(1).set(r); return b; },
  loop(x, xf) { return loopSeam(x, Math.floor((xf || 0.15) * AU.sr)); },
};

/* ---------- recipes ---------- */
const REC = {
  gun(kind, supp) {
    const R = () => 0.92 + Math.random() * 0.16;
    const big = kind === 'plow', smg = kind === 'draft';
    const out = DSP.z(big ? 1.4 : smg ? 0.7 : 0.95);
    if (!supp) {
      // supersonic crack / muzzle blast front
      const a = DSP.noise(0.03); DSP.filt(a, 'hp', big ? 650 : 1100, 0.7); DSP.env(a, 0.0003, (big ? 0.0085 : smg ? 0.0045 : 0.0055) * R()); DSP.add(out, a, 0, 2.6);
      // expanding gas: broadband, darkening quickly
      const b = DSP.noise(0.6); DSP.sweep(b, 'lp', (big ? 5200 : 8200) * R(), (big ? 240 : 420) * R(), 0.8, big ? 0.22 : 0.11); DSP.env(b, 0.0008, (big ? 0.075 : smg ? 0.032 : 0.045) * R()); DSP.add(out, b, 0, big ? 1.7 : 1.35);
      // chest thump
      const c = DSP.tone(0.5, (big ? 96 : 122) * R(), big ? 33 : 47, big ? 0.17 : 0.09); DSP.env(c, 0.0015, (big ? 0.12 : smg ? 0.05 : 0.065) * R()); DSP.add(out, c, 0, big ? 1.8 : 1.15);
      // bite
      const d = DSP.noise(0.1); DSP.filt(d, 'bp', (big ? 1300 : 1900) * R(), 1.3); DSP.env(d, 0.0006, big ? 0.03 : 0.02); DSP.add(out, d, 0, 0.9);
      // low gas rumble
      const e = DSP.noise(big ? 1.2 : 0.8); DSP.filt(e, 'lp', big ? 300 : 380, 0.7); DSP.filt(e, 'lp', big ? 300 : 380, 0.7); DSP.env(e, 0.012, big ? 0.26 : 0.12); DSP.add(out, e, 0.003, big ? 1.1 : 0.6);
    } else {
      const a = DSP.noise(0.2); DSP.filt(a, 'lp', 1500 * R(), 0.8); DSP.env(a, 0.0008, 0.02); DSP.add(out, a, 0, 1.2);
      const c = DSP.tone(0.25, 175 * R(), 68, 0.05); DSP.env(c, 0.001, 0.03); DSP.add(out, c, 0, 0.9);
      const h = DSP.noise(0.05); DSP.filt(h, 'bp', 5200, 1.5); DSP.env(h, 0.0004, 0.006); DSP.add(out, h, 0, 0.45);
    }
    // the action cycling
    if (!big) { DSP.click(out, smg ? 0.016 : 0.03, 4200 * R(), supp ? 0.45 : 0.2); DSP.click(out, smg ? 0.042 : 0.074, 2900 * R(), supp ? 0.5 : 0.26); }
    DSP.sat(out, 1.7); return DSP.norm(out, 0.95);
  },
  casing(shell) {
    const out = DSP.z(0.5);
    const bounces = [[0, 1], [0.085 + Math.random() * 0.04, 0.45], [0.16 + Math.random() * 0.05, 0.2], [0.21 + Math.random() * 0.04, 0.08]];
    for (const [t, a] of bounces) {
      if (shell) { DSP.modes(out, t, [[720, 0.012, 1], [1530, 0.008, 0.6], [2650, 0.005, 0.4]], a); const n = DSP.noise(0.02); DSP.filt(n, 'lp', 900); DSP.env(n, 0.0005, 0.006); DSP.add(out, n, t, a * 0.6); }
      else DSP.modes(out, t, [[3150, 0.03, 1], [5820, 0.02, 0.7], [8970, 0.012, 0.5], [11900, 0.008, 0.3]], a);
    }
    return DSP.norm(out, 0.8);
  },
  reload() {
    const out = DSP.z(1.0);
    DSP.click(out, 0, 3600, 0.5);
    const s = DSP.noise(0.14); DSP.filt(s, 'bp', 1800, 1); DSP.env(s, 0.03, 0.04); DSP.add(out, s, 0.04, 0.35);
    DSP.click(out, 0.42, 2500, 0.7); const th = DSP.tone(0.1, 320, 200, 0.05); DSP.env(th, 0.001, 0.02); DSP.add(out, th, 0.42, 0.5); DSP.click(out, 0.45, 3300, 0.4);
    const p = DSP.noise(0.1); DSP.filt(p, 'bp', 2400, 1.2); DSP.env(p, 0.04, 0.03); DSP.add(out, p, 0.66, 0.4);
    DSP.click(out, 0.79, 3100, 1); DSP.modes(out, 0.79, [[2100, 0.05, 0.25], [3400, 0.04, 0.2], [5200, 0.03, 0.12]], 1); const t2 = DSP.tone(0.08, 230); DSP.env(t2, 0.001, 0.015); DSP.add(out, t2, 0.79, 0.4);
    return DSP.norm(out, 0.9);
  },
  pump() {
    const out = DSP.z(0.5);
    const a = DSP.noise(0.1); DSP.filt(a, 'bp', 1500, 1); DSP.env(a, 0.025, 0.035); DSP.add(out, a, 0, 0.5); DSP.click(out, 0.07, 2300, 0.7);
    const b = DSP.noise(0.1); DSP.filt(b, 'bp', 1700, 1); DSP.env(b, 0.02, 0.03); DSP.add(out, b, 0.14, 0.45);
    DSP.click(out, 0.19, 2000, 1.1); DSP.modes(out, 0.19, [[1300, 0.06, 0.3], [2600, 0.04, 0.2]], 1); const t = DSP.tone(0.1, 160); DSP.env(t, 0.001, 0.02); DSP.add(out, t, 0.19, 0.5);
    return DSP.norm(out, 0.9);
  },
  dry() { const out = DSP.z(0.15); DSP.click(out, 0, 3000, 1); DSP.modes(out, 0, [[4200, 0.01, 0.3]], 1); return DSP.norm(out, 0.8); },
  impact(mat) {
    const out = DSP.z(mat === 'metal' ? 0.6 : 0.35);
    if (mat === 'brick') {
      const a = DSP.noise(0.04); DSP.filt(a, 'bp', 2500, 1); DSP.env(a, 0.0004, 0.006); DSP.add(out, a, 0, 1);
      const b = DSP.tone(0.1, 190, 85, 0.04); DSP.env(b, 0.001, 0.018); DSP.add(out, b, 0, 0.6);
      DSP.grains(out, 0.02, 0.22, 16, 2000, 6500, 0.18, 1.4);
    } else if (mat === 'metal') {
      DSP.click(out, 0, 3500, 0.8);
      DSP.modes(out, 0, [[1180, 0.22, 0.4], [2470, 0.16, 0.3], [3960, 0.1, 0.25], [5600, 0.07, 0.18], [7900, 0.05, 0.1]], 1);
    } else if (mat === 'snow') {
      const a = DSP.noise(0.1); DSP.filt(a, 'lp', 700); DSP.env(a, 0.002, 0.025); DSP.add(out, a, 0, 1);
      DSP.grains(out, 0.004, 0.05, 10, 1500, 5000, 0.25);
    } else {
      const a = DSP.tone(0.15, 140, 55, 0.06); DSP.env(a, 0.001, 0.035); DSP.add(out, a, 0, 1);
      const b = DSP.noise(0.1); DSP.filt(b, 'lp', 500); DSP.env(b, 0.002, 0.03); DSP.add(out, b, 0, 0.8);
      const c = DSP.noise(0.08); DSP.filt(c, 'bp', 1200, 3); for (let i = 0; i < c.length; i++) c[i] *= 0.5 + 0.5 * Math.sin(i / AU.sr * 2 * Math.PI * 70); DSP.env(c, 0.004, 0.05); DSP.add(out, c, 0, 0.3);
    }
    return DSP.norm(out, 0.9);
  },
  ricochet() {
    const n = DSP.n(0.55), out = new Float32Array(n); let ph = 0;
    const f0 = 3400 + Math.random() * 800, f1 = 1200 + Math.random() * 400;
    for (let i = 0; i < n; i++) { const t = i / AU.sr, f = f0 * Math.pow(f1 / f0, t / 0.55) * (1 + 0.02 * Math.sin(t * 2 * Math.PI * 28)); ph += f / AU.sr; out[i] = Math.sin(ph * 2 * Math.PI); }
    DSP.env(out, 0.004, 0.15); const nz = DSP.noise(0.3); DSP.filt(nz, 'bp', 3000, 4); DSP.env(nz, 0.002, 0.05); DSP.add(out, nz, 0, 0.3);
    return DSP.norm(out, 0.7);
  },
  whiz() {
    const out = DSP.z(0.3);
    const w = Math.floor(0.0007 * AU.sr); for (let i = 0; i < w * 2; i++) out[i] = i < w ? 1 - i / w * 2 : -1 + (i - w) / w;
    const h = DSP.noise(0.01); DSP.filt(h, 'hp', 3000); DSP.env(h, 0.0001, 0.002); DSP.add(out, h, 0, 0.8);
    const s = DSP.noise(0.25); DSP.sweep(s, 'bp', 5200, 2400, 6, 0.12); DSP.env(s, 0.008, 0.045); DSP.add(out, s, 0.002, 1.6);
    return DSP.norm(out, 0.9);
  },
  stepSnow() {
    const out = DSP.z(0.24);
    for (const [ct, cg] of [[0, 1], [0.035 + Math.random() * 0.025, 0.7]]) {
      const th = DSP.noise(0.08); DSP.filt(th, 'lp', 280, 0.7); DSP.env(th, 0.004, 0.025); DSP.add(out, th, ct, 0.9 * cg);
      DSP.grains(out, ct, 0.075, Math.floor(28 + Math.random() * 26), 1300, 7000, 0.55 * cg, 0.9);
      if (Math.random() < 0.55) { const sq = DSP.noise(0.06); DSP.filt(sq, 'bp', 1050 + Math.random() * 600, 14); DSP.env(sq, 0.01, 0.018); DSP.add(out, sq, ct + 0.01, 0.9 * cg); }
    }
    DSP.filt(out, 'hp', 70); return DSP.norm(out, 0.9);
  },
  stepSlush() {
    const out = DSP.z(0.25);
    const a = DSP.noise(0.18); DSP.filt(a, 'lp', 1000); for (let i = 0; i < a.length; i++) a[i] *= 0.4 + Math.random() * 0.6 * (Math.random() < 0.08 ? 2 : 1); DSP.env(a, 0.006, 0.045); DSP.add(out, a, 0, 1);
    const b = DSP.noise(0.06); DSP.filt(b, 'bp', 650, 2); DSP.env(b, 0.002, 0.02); DSP.add(out, b, 0.01, 0.6);
    DSP.grains(out, 0.03, 0.12, 9, 2200, 4800, 0.25, 1.2);
    return DSP.norm(out, 0.85);
  },
  stepHard(metal) {
    const out = DSP.z(metal ? 0.4 : 0.22);
    for (const [ct, cg] of [[0, 1], [0.045 + Math.random() * 0.02, 0.55]]) {
      const a = DSP.noise(0.03); DSP.filt(a, 'bp', 2700, 1.2); DSP.env(a, 0.0005, 0.006); DSP.add(out, a, ct, 0.7 * cg);
      const b = DSP.tone(0.08, metal ? 210 : 145, null); DSP.env(b, 0.001, 0.02); DSP.add(out, b, ct, 0.55 * cg);
      const c = DSP.noise(0.05); DSP.filt(c, 'lp', 500); DSP.env(c, 0.001, 0.014); DSP.add(out, c, ct, 0.5 * cg);
      if (metal) DSP.modes(out, ct, [[182, 0.12, 0.18], [415, 0.09, 0.14], [870, 0.06, 0.08], [1630, 0.04, 0.05]], cg);
    }
    const sc = DSP.noise(0.06); DSP.filt(sc, 'bp', 4000, 1); DSP.env(sc, 0.01, 0.02); DSP.add(out, sc, 0.05, 0.1);
    return DSP.norm(out, 0.85);
  },
  rustle() { const out = DSP.noise(0.3); DSP.filt(out, 'bp', 3300 + Math.random() * 900, 0.8); DSP.env(out, 0.05 + Math.random() * 0.03, 0.07); return DSP.norm(out, 0.6); },
  bodyfall() {
    const out = DSP.z(0.9);
    const a = DSP.tone(0.3, 92, 46, 0.08); DSP.env(a, 0.002, 0.06); DSP.add(out, a, 0, 0.7);
    const b = DSP.noise(0.2); DSP.filt(b, 'lp', 420); DSP.env(b, 0.002, 0.05); DSP.add(out, b, 0, 0.6);
    const c = DSP.tone(0.4, 74, 36, 0.1); DSP.env(c, 0.002, 0.09); DSP.add(out, c, 0.17, 1);
    const d = DSP.noise(0.3); DSP.filt(d, 'lp', 380); DSP.env(d, 0.003, 0.08); DSP.add(out, d, 0.17, 0.9);
    DSP.grains(out, 0.17, 0.1, 40, 1300, 6000, 0.35);
    const r = DSP.noise(0.4); DSP.filt(r, 'bp', 3000, 0.8); DSP.env(r, 0.05, 0.1); DSP.add(out, r, 0.02, 0.15);
    return DSP.norm(out, 0.95);
  },
  hurt() {
    const out = DSP.z(0.35);
    const a = DSP.tone(0.25, 115, 48, 0.07); DSP.env(a, 0.001, 0.05); DSP.add(out, a, 0, 1);
    const b = DSP.noise(0.15); DSP.filt(b, 'lp', 600); DSP.env(b, 0.001, 0.035); DSP.add(out, b, 0, 0.8);
    return DSP.norm(out, 0.9);
  },
  heart() {
    const out = DSP.z(0.7);
    for (const [t, a] of [[0, 1], [0.27, 0.7]]) { const s = DSP.tone(0.25, 58, 40, 0.08); DSP.env(s, 0.006, 0.05); DSP.add(out, s, t, a); const n = DSP.noise(0.1); DSP.filt(n, 'lp', 120); DSP.env(n, 0.004, 0.03); DSP.add(out, n, t, a * 0.6); }
    return DSP.norm(out, 0.9);
  },
  crash(big) {
    const len = big ? 1.8 : 0.8, out = DSP.z(len);
    const a = DSP.tone(0.6, big ? 72 : 95, big ? 31 : 45, 0.15); DSP.env(a, 0.002, big ? 0.13 : 0.07); DSP.add(out, a, 0, big ? 1.5 : 1);
    const b = DSP.noise(0.5); DSP.filt(b, 'lp', 260); DSP.env(b, 0.002, big ? 0.12 : 0.06); DSP.add(out, b, 0, 1.1);
    // crumpling sheet metal: resonant bands driven by a spiky envelope
    const m = DSP.noise(big ? 0.8 : 0.35), mm = new Float32Array(m.length);
    for (let k = 0; k < (big ? 8 : 5); k++) { const c = m.slice(); DSP.filt(c, 'bp', 300 + Math.random() * 3600, 8 + Math.random() * 18); for (let i = 0; i < c.length; i++) mm[i] += c[i]; }
    const spikes = new Float32Array(m.length);
    for (let k = 0; k < (big ? 26 : 10); k++) { const t0 = Math.floor(Math.pow(Math.random(), 1.6) * m.length * 0.7), A = 0.3 + Math.random(); for (let i = t0; i < m.length; i++) { const v = A * Math.exp(-(i - t0) / (0.025 * AU.sr)); if (v < 0.001) break; spikes[i] += v; } }
    for (let i = 0; i < mm.length; i++) mm[i] *= spikes[i];
    DSP.add(out, mm, 0.004, big ? 0.6 : 0.45);
    if (big) {
      const g = DSP.noise(0.2); DSP.filt(g, 'hp', 5000); DSP.env(g, 0.001, 0.05); DSP.add(out, g, 0.012, 0.6);
      for (let k = 0; k < 60; k++) { const t = 0.015 + Math.pow(Math.random(), 1.8) * 0.9, f = 3000 + Math.random() * 9000; const p = DSP.tone(0.06, f); DSP.env(p, 0.0002, 0.008 + Math.random() * 0.03); DSP.add(out, p, t, 0.05 + Math.random() * 0.12); }
      DSP.grains(out, 0.3, 1.2, 30, 600, 3000, 0.12, 1.5);
    } else { const c = DSP.noise(0.05); DSP.filt(c, 'bp', 1500, 2); DSP.env(c, 0.0005, 0.01); DSP.add(out, c, 0, 0.7); }
    DSP.sat(out, 1.3); return DSP.norm(out, 0.95);
  },
  door(close) {
    const out = DSP.z(0.5);
    if (close) {
      const a = DSP.tone(0.3, 98, 68, 0.06); DSP.env(a, 0.001, 0.045); DSP.add(out, a, 0, 1);
      const b = DSP.noise(0.2); DSP.filt(b, 'lp', 360); DSP.env(b, 0.001, 0.055); DSP.add(out, b, 0, 0.9);
      DSP.click(out, 0.004, 2200, 0.5); DSP.grains(out, 0.02, 0.1, 10, 2000, 5000, 0.1);
      DSP.modes(out, 0, [[520, 0.03, 0.12], [1350, 0.02, 0.06]], 1);
    } else {
      DSP.click(out, 0, 2400, 0.6); DSP.click(out, 0.03, 1700, 0.5);
      const c = DSP.noise(0.2); DSP.filt(c, 'bp', 850, 9); DSP.env(c, 0.04, 0.06); DSP.add(out, c, 0.05, 0.25);
      const d = DSP.tone(0.15, 140, 100, 0.05); DSP.env(d, 0.002, 0.02); DSP.add(out, d, 0.03, 0.3);
    }
    return DSP.norm(out, 0.9);
  },
  horn(f1, f2, len) {
    const out = DSP.z(len + 0.06), n = out.length, A = Math.floor(0.012 * AU.sr), Rl = Math.floor(0.04 * AU.sr);
    let p1 = 0, p2 = 0;
    for (let i = 0; i < n; i++) {
      const t = i / AU.sr, wob = 1 + 0.004 * Math.sin(t * 2 * Math.PI * 7);
      p1 += f1 * wob / AU.sr; p2 += f2 * wob / AU.sr; p1 -= Math.floor(p1); p2 -= Math.floor(p2);
      const e = i < A ? i / A : i > n - Rl ? (n - i) / Rl : 1;
      out[i] = ((2 * p1 - 1) + 0.85 * (2 * p2 - 1)) * e;
    }
    DSP.filt(out, 'lp', 3200, 0.7); DSP.filt(out, 'peak', 2300, 2, 7); DSP.filt(out, 'peak', 900, 1.5, 4); DSP.sat(out, 2.4);
    return DSP.norm(out, 0.9);
  },
  clack() {
    const out = DSP.z(0.25);
    const a = DSP.tone(0.15, 165, 90, 0.04); DSP.env(a, 0.001, 0.03); DSP.add(out, a, 0, 1);
    const b = DSP.noise(0.08); DSP.filt(b, 'lp', 700); DSP.env(b, 0.001, 0.02); DSP.add(out, b, 0, 0.8);
    DSP.modes(out, 0, [[780, 0.04, 0.16], [1350, 0.03, 0.12], [2240, 0.02, 0.08]], 1);
    return DSP.norm(out, 0.9);
  },
  hiss(len) { const out = DSP.noise(len); DSP.filt(out, 'hp', 1800); DSP.filt(out, 'peak', 5000, 1, 5); DSP.env(out, 0.02, len * 0.35, len * 0.25); DSP.fadeOut(out, 0.1); return DSP.norm(out, 0.7); },
  doorSlide() {
    const out = DSP.z(1.4);
    const h = DSP.noise(0.5); DSP.filt(h, 'bp', 3200, 1); DSP.env(h, 0.02, 0.15); DSP.add(out, h, 0, 0.4);
    const r = DSP.noise(1.0); DSP.filt(r, 'lp', 220); DSP.env(r, 0.25, 0.2, 0.4); DSP.add(out, r, 0.05, 0.6);
    const t = DSP.tone(0.2, 115, 80, 0.06); DSP.env(t, 0.001, 0.04); DSP.add(out, t, 0.95, 0.9); DSP.click(out, 0.95, 1500, 0.4);
    return DSP.norm(out, 0.9);
  },
  chime() { const out = DSP.z(1.8); for (const [t, f] of [[0, 659.3], [0.45, 523.3]]) DSP.modes(out, t, [[f, 0.55, 1], [f * 2, 0.3, 0.35], [f * 3.01, 0.15, 0.15], [f * 4.2, 0.08, 0.08]], 1); return DSP.norm(out, 0.8); },
  trainHorn() { return REC.horn(311, 370, 1.1); },
  squealLoop() {
    const out = DSP.z(2.2);
    for (const f of [2900, 3420, 4710]) { const c = DSP.noise(2.2); DSP.filt(c, 'bp', f, 45); DSP.filt(c, 'bp', f, 45); let am = 0.5; for (let i = 0; i < c.length; i++) { if ((i & 255) === 0) am = clamp(am + (Math.random() - 0.5) * 0.25, 0.1, 1); c[i] *= am; } DSP.add(out, c, 0, 1); }
    return DSP.norm(DSP.loop(out, 0.2), 0.8);
  },
  fireLoop() {
    const out = DSP.z(4.2);
    const roar = DSP.noise(4.2); DSP.filt(roar, 'lp', 320); let am = 0.6; for (let i = 0; i < roar.length; i++) { if ((i & 511) === 0) am = clamp(am + (Math.random() - 0.5) * 0.2, 0.3, 1); roar[i] *= am; } DSP.add(out, roar, 0, 1.2);
    DSP.grains(out, 0, 4.1, 260, 1800, 7000, 0.6, 1);
    for (let k = 0; k < 14; k++) { const t = Math.random() * 4, p = DSP.noise(0.04); DSP.filt(p, 'bp', 900 + Math.random() * 1500, 2); DSP.env(p, 0.0005, 0.006); DSP.add(out, p, t, 1.5); }
    return DSP.norm(DSP.loop(out, 0.2), 0.8);
  },
  steamLoop() { const out = DSP.noise(3); DSP.filt(out, 'hp', 1400); DSP.filt(out, 'peak', 4200, 0.8, 6); let am = 0.7; for (let i = 0; i < out.length; i++) { if ((i & 511) === 0) am = clamp(am + (Math.random() - 0.5) * 0.12, 0.5, 1); out[i] *= am; } return DSP.norm(DSP.loop(out, 0.2), 0.7); },
  buzzLoop() { const n = AU.sr, out = new Float32Array(n); for (let i = 0; i < n; i++) { const t = i / AU.sr; out[i] = Math.sin(t * 2 * Math.PI * 120) + 0.6 * Math.sin(t * 2 * Math.PI * 240 + 0.4) + 0.35 * Math.sin(t * 2 * Math.PI * 360 + 1) + 0.25 * Math.sign(Math.sin(t * 2 * Math.PI * 120)) * 0.3 + (Math.random() - 0.5) * 0.08; } return DSP.norm(out, 0.6); },
  rollLoop() { const out = DSP.noise(2.2); DSP.filt(out, 'lp', 420, 0.7); DSP.filt(out, 'peak', 900, 1, 3); return DSP.norm(DSP.loop(out, 0.2), 0.8); },
  slushLoop() { const out = DSP.noise(2.2); DSP.filt(out, 'hp', 1800); DSP.filt(out, 'lp', 7000); for (let i = 0; i < out.length; i++) out[i] *= 0.55 + Math.random() * 0.45 * (Math.random() < 0.02 ? 3 : 1); return DSP.norm(DSP.loop(out, 0.2), 0.7); },
  skidLoop() {
    const out = DSP.z(2.2);
    const a = DSP.noise(2.2); DSP.filt(a, 'bp', 1150, 7); DSP.filt(a, 'bp', 1150, 7); DSP.add(out, a, 0, 1);
    const b = DSP.noise(2.2); DSP.filt(b, 'bp', 2350, 9); DSP.add(out, b, 0, 0.5);
    const c = DSP.noise(2.2); DSP.filt(c, 'hp', 2500); DSP.add(out, c, 0, 0.25);
    let am = 0.7; for (let i = 0; i < out.length; i++) { if ((i & 255) === 0) am = clamp(am + (Math.random() - 0.5) * 0.2, 0.4, 1); out[i] *= am; }
    return DSP.norm(DSP.loop(out, 0.2), 0.8);
  },
  // police radio: squelch, garbled formant speech, roger beep
  chatter() {
    const len = 1.3 + Math.random() * 1.4, out = DSP.z(len + 0.35);
    const sq = DSP.noise(0.06); DSP.filt(sq, 'hp', 900); DSP.env(sq, 0.001, 0.02); DSP.add(out, sq, 0, 0.6);
    const vow = [[730, 1090, 2440], [530, 1840, 2480], [300, 870, 2240], [570, 840, 2410], [270, 2290, 3010], [660, 1720, 2410]];
    let t = 0.05, f0 = 115 + Math.random() * 40;
    while (t < len) {
      const sl = 0.07 + Math.random() * 0.12, v = vow[Math.floor(Math.random() * vow.length)], n = DSP.n(sl);
      const ex = new Float32Array(n); let ph = 0; const ff = f0 * (0.9 + Math.random() * 0.25);
      for (let i = 0; i < n; i++) { ph += ff / AU.sr; if (ph >= 1) { ph -= 1; ex[i] = 1; } ex[i] += (Math.random() - 0.5) * 0.25; }
      const syl = new Float32Array(n);
      for (let k = 0; k < 3; k++) { const c = ex.slice(); DSP.filt(c, 'bp', v[k] * (0.95 + Math.random() * 0.1), 6); DSP.add(syl, c, 0, [1, 0.6, 0.3][k]); }
      for (let i = 0; i < n; i++) syl[i] *= Math.sin(Math.PI * i / n);
      if (Math.random() > 0.12) DSP.add(out, syl, t, 1);
      t += sl + (Math.random() < 0.18 ? 0.08 + Math.random() * 0.12 : 0.005);
    }
    const hiss = DSP.noise(len); DSP.filt(hiss, 'bp', 2000, 0.5); DSP.add(out, hiss, 0.05, 0.05);
    DSP.filt(out, 'hp', 320); DSP.filt(out, 'lp', 3000); DSP.sat(DSP.norm(out, 1), 2.2);
    const tail = DSP.noise(0.09); DSP.filt(tail, 'hp', 1200); DSP.env(tail, 0.001, 0.03); DSP.add(out, tail, len + 0.05, 0.4);
    const beep = DSP.tone(0.07, 1250); DSP.env(beep, 0.002, 0.03, 0.03); DSP.add(out, beep, len + 0.1, 0.25);
    return DSP.norm(out, 0.85);
  },
  dog() {
    const out = DSP.z(0.75);
    for (const t of [0, 0.28 + Math.random() * 0.08]) {
      const n = DSP.n(0.16), ex = new Float32Array(n); let ph = 0;
      for (let i = 0; i < n; i++) { const k = i / n, f = 430 - 190 * k; ph += f / AU.sr; if (ph >= 1) { ph -= 1; ex[i] = 1; } ex[i] += (Math.random() - 0.5) * 0.5; }
      const b = new Float32Array(n);
      for (const [f, q, a] of [[600, 4, 1], [1400, 5, 0.6], [2600, 6, 0.3]]) { const c = ex.slice(); DSP.filt(c, 'bp', f, q); DSP.add(b, c, 0, a); }
      DSP.env(b, 0.008, 0.05); DSP.add(out, b, t, 1);
    }
    return DSP.norm(out, 0.9);
  },
  flap() {
    const out = DSP.z(2.0);
    for (let b = 0; b < 9; b++) {
      const t0 = Math.random() * 0.5, rate = 9 + Math.random() * 5, dur = 0.8 + Math.random() * 0.9, n = DSP.n(dur), w = DSP.noise(dur);
      DSP.filt(w, 'bp', 1100 + Math.random() * 900, 1.2);
      for (let i = 0; i < n; i++) { const t = i / AU.sr, ph = (t * rate) % 1; w[i] *= Math.pow(Math.max(0, Math.sin(ph * Math.PI)), 6) * (1 - t / dur); }
      DSP.add(out, w, t0, 0.6);
    }
    return DSP.norm(out, 0.8);
  },
  carPass() {
    const len = 4.5, out = DSP.noise(len), n = out.length, mid = 0.4 + Math.random() * 0.2;
    DSP.filt(out, 'lp', 900);
    for (let i = 0; i < n; i++) { const k = i / n, d = Math.abs(k - mid) * 6; out[i] *= 1 / (1 + d * d); }
    const eng = DSP.z(len); let ph = 0;
    for (let i = 0; i < n; i++) { const k = i / n, f = (k < mid ? 74 : 58) + Math.random() * 2; ph += f / AU.sr; const d = Math.abs(k - mid) * 6; eng[i] = (Math.abs(((ph % 1) * 2) - 1) - 0.5) / (1 + d * d); }
    DSP.filt(eng, 'lp', 400); DSP.add(out, eng, 0, 0.6);
    return DSP.norm(out, 0.8);
  },
  heliLoop() {
    const n = DSP.n(2), out = new Float32Array(n), w = DSP.noise(2); DSP.filt(w, 'lp', 900);
    for (let i = 0; i < n; i++) { const t = i / AU.sr, ph = (t * 19) % 1; out[i] = w[i] * (0.15 + Math.pow(1 - ph, 8) * 1.4) + 0.06 * Math.sin(t * 2 * Math.PI * 1650) + 0.03 * Math.sin(t * 2 * Math.PI * 3300); }
    return DSP.norm(out, 0.8);
  },
  rattle() { const out = DSP.z(0.7); for (let k = 0; k < 7; k++) DSP.modes(out, Math.random() * 0.5, [[900 + Math.random() * 1400, 0.03, 0.5], [2600 + Math.random() * 1800, 0.02, 0.3]], 0.4 + Math.random() * 0.6); return DSP.norm(out, 0.7); },
  plane() { const out = DSP.noise(14); DSP.filt(out, 'lp', 260); DSP.filt(out, 'peak', 520, 1, 5); const n = out.length; for (let i = 0; i < n; i++) { const k = i / n; out[i] *= Math.sin(Math.PI * k) ** 2; } return DSP.norm(out, 0.8); },
  // UI
  notif() { const out = DSP.z(0.75); for (const [t, f] of [[0, 1318.5], [0.11, 1975.5]]) DSP.modes(out, t, [[f, 0.18, 1], [f * 3.9, 0.025, 0.25], [f * 9.2, 0.008, 0.1]], 1); return DSP.norm(out, 0.7); },
  msgIn() { const out = DSP.z(0.2); const a = DSP.tone(0.15, 880, 1320, 0.03); DSP.env(a, 0.002, 0.04); DSP.add(out, a, 0, 1); DSP.click(out, 0, 2500, 0.2); return DSP.norm(out, 0.6); },
  msgOut() { const out = DSP.z(0.35); const a = DSP.noise(0.3); DSP.sweep(a, 'bp', 700, 3800, 2, 0.18); DSP.env(a, 0.06, 0.05); DSP.add(out, a, 0, 0.8); const b = DSP.tone(0.2, 520, 980, 0.12); DSP.env(b, 0.02, 0.05); DSP.add(out, b, 0, 0.3); return DSP.norm(out, 0.6); },
  haptic() { const out = DSP.z(0.32); for (const t of [0, 0.12]) { const b = DSP.tone(0.09, 172, null, 0, 'sq'); DSP.filt(b, 'lp', 400); DSP.env(b, 0.005, 0.05, 0.03); DSP.add(out, b, t, 1); } return DSP.norm(out, 0.6); },
  shutter() { const out = DSP.z(0.2); const a = DSP.noise(0.02); DSP.filt(a, 'bp', 3600, 2); DSP.env(a, 0.0002, 0.004); DSP.add(out, a, 0, 1); const w = DSP.noise(0.05); DSP.filt(w, 'bp', 1200, 2); DSP.env(w, 0.01, 0.015); DSP.add(out, w, 0.01, 0.2); const b = DSP.noise(0.02); DSP.filt(b, 'bp', 2500, 2); DSP.env(b, 0.0002, 0.005); DSP.add(out, b, 0.065, 0.8); const t = DSP.tone(0.04, 180); DSP.env(t, 0.001, 0.01); DSP.add(out, t, 0, 0.3); return DSP.norm(out, 0.7); },
  tap() { const out = DSP.z(0.06); DSP.click(out, 0, 2400, 0.6); const t = DSP.tone(0.03, 1150); DSP.env(t, 0.0005, 0.006); DSP.add(out, t, 0, 0.15); return DSP.norm(out, 0.45); },
  lock() { const out = DSP.z(0.12); DSP.click(out, 0, 1800, 0.8); DSP.click(out, 0.018, 3100, 0.4); const t = DSP.tone(0.05, 240); DSP.env(t, 0.001, 0.01); DSP.add(out, t, 0, 0.3); return DSP.norm(out, 0.55); },
  cash() {
    const out = DSP.z(1.0);
    DSP.modes(out, 0.0, [[2093, 0.35, 1], [2093 * 2.76, 0.12, 0.3], [2093 * 5.4, 0.05, 0.15]], 0.7);
    const dr = DSP.noise(0.3); DSP.filt(dr, 'bp', 600, 1.2); DSP.env(dr, 0.05, 0.08); DSP.add(out, dr, 0.08, 0.35); DSP.click(out, 0.35, 1400, 0.6);
    for (let k = 0; k < 14; k++) DSP.modes(out, 0.2 + Math.random() * 0.45, [[3000 + Math.random() * 5000, 0.04, 0.25]], 1);
    return DSP.norm(out, 0.7);
  },
  punch() { const out = DSP.z(0.28); const a = DSP.tone(0.2, 120 + Math.random() * 35, 48, 0.05); DSP.env(a, 0.0008, 0.045); DSP.add(out, a, 0, 1); const b = DSP.noise(0.05); DSP.filt(b, 'bp', 1700 + Math.random() * 700, 1.1); DSP.env(b, 0.0004, 0.007); DSP.add(out, b, 0, 0.9); const c = DSP.noise(0.14); DSP.filt(c, 'lp', 850); DSP.env(c, 0.001, 0.03); DSP.add(out, c, 0.002, 0.7); return DSP.norm(out, 0.9); },
  swing() { const out = DSP.noise(0.24); DSP.sweep(out, 'bp', 500, 2300, 1.5, 0.12); DSP.env(out, 0.05, 0.05); return DSP.norm(out, 0.5); },
  whoosh() { const out = DSP.noise(0.7); DSP.sweep(out, 'bp', 380, 2600, 1.3, 0.3); DSP.env(out, 0.22, 0.12); return DSP.norm(out, 0.6); },
  boom() {
    const out = DSP.z(2.5);
    const a = DSP.tone(2, 58, 30, 0.8); DSP.env(a, 0.004, 0.55); DSP.add(out, a, 0, 1);
    const b = DSP.noise(1.5); DSP.filt(b, 'lp', 160); DSP.env(b, 0.004, 0.4); DSP.add(out, b, 0, 0.8);
    const c = DSP.noise(0.1); DSP.filt(c, 'bp', 1800, 1); DSP.env(c, 0.001, 0.015); DSP.add(out, c, 0, 0.3);
    DSP.sat(out, 1.4); return DSP.norm(out, 0.95);
  },
  stab() {
    const out = DSP.z(1.6);
    for (const m of [45, 46, 52, 57]) { const s = DSP.tone(1.5, NOTE(m), null, 0, 'saw'); DSP.add(out, s, 0, 0.25); }
    DSP.sweep(out, 'lp', 2400, 500, 0.8, 0.6); DSP.env(out, 0.004, 0.4);
    const a = DSP.tone(1.2, 62, 38, 0.3); DSP.env(a, 0.003, 0.3); DSP.add(out, a, 0, 0.9);
    DSP.sat(out, 1.3); return DSP.norm(out, 0.9);
  },
  static() { const out = DSP.noise(0.3); DSP.filt(out, 'bp', 1600, 0.6); for (let i = 0; i < out.length; i++) out[i] *= 0.5 + (Math.random() < 0.03 ? 1.5 : 0.5); DSP.env(out, 0.01, 0.1, 0.1); return DSP.norm(out, 0.5); },
  // drums (music)
  kick() { const out = DSP.z(0.7); const a = DSP.tone(0.7, 172, 47, 0.065); DSP.env(a, 0.0015, 0.32); DSP.add(out, a, 0, 1); const c = DSP.noise(0.01); DSP.filt(c, 'hp', 3000); DSP.env(c, 0.0002, 0.0018); DSP.add(out, c, 0, 0.5); DSP.sat(out, 1.4); return DSP.norm(out, 0.95); },
  snare() {
    const out = DSP.z(0.45);
    const a = DSP.tone(0.2, 205, 182, 0.05, 'tri'); DSP.env(a, 0.0008, 0.05); DSP.add(out, a, 0, 0.7);
    const b = DSP.tone(0.15, 335); DSP.env(b, 0.0008, 0.03); DSP.add(out, b, 0, 0.3);
    const n = DSP.noise(0.45); DSP.filt(n, 'hp', 1400); DSP.filt(n, 'peak', 4600, 0.7, 5); DSP.env(n, 0.0008, 0.085 + Math.random() * 0.03); DSP.add(out, n, 0, 0.95);
    DSP.sat(out, 1.3); return DSP.norm(out, 0.95);
  },
  clap() {
    const out = DSP.z(0.5);
    for (const t of [0, 0.0095, 0.019, 0.0285]) { const b = DSP.noise(0.02); DSP.filt(b, 'bp', 1150, 1.1); DSP.env(b, 0.0002, 0.0038); DSP.add(out, b, t, 1); }
    const tl = DSP.noise(0.45); DSP.filt(tl, 'bp', 1200, 0.9); DSP.env(tl, 0.001, 0.11 + Math.random() * 0.03); DSP.add(out, tl, 0.029, 0.8);
    return DSP.norm(out, 0.95);
  },
  rim() { const out = DSP.z(0.12); const a = DSP.noise(0.03); DSP.filt(a, 'bp', 1750, 3); DSP.env(a, 0.0002, 0.005); DSP.add(out, a, 0, 1); const b = DSP.tone(0.05, 520); DSP.env(b, 0.0003, 0.009); DSP.add(out, b, 0, 0.5); const c = DSP.tone(0.04, 1630); DSP.env(c, 0.0003, 0.005); DSP.add(out, c, 0, 0.3); return DSP.norm(out, 0.9); },
  metal(len, tau) {
    const n = DSP.n(len), out = new Float32Array(n), fs = [205.3, 304.4, 369.6, 522.7, 540, 800].map(f => f * 2.03); const ph = fs.map(() => Math.random());
    for (let i = 0; i < n; i++) { let s = 0; for (let k = 0; k < 6; k++) { ph[k] += fs[k] / AU.sr; ph[k] -= Math.floor(ph[k]); s += ph[k] < 0.5 ? 1 : -1; } out[i] = s / 6; }
    DSP.filt(out, 'hp', 7000, 0.7); DSP.filt(out, 'peak', 10000, 0.9, 5);
    const nz = DSP.noise(len); DSP.filt(nz, 'hp', 8500); DSP.add(out, nz, 0, 0.3);
    DSP.env(out, 0.0004, tau); return DSP.norm(out, 0.9);
  },
  perc() { const out = DSP.z(0.2); const a = DSP.tone(0.15, 860, 800, 0.03); DSP.env(a, 0.0005, 0.03); DSP.add(out, a, 0, 1); const b = DSP.tone(0.08, 2400); DSP.env(b, 0.0003, 0.01); DSP.add(out, b, 0, 0.35); return DSP.norm(out, 0.85); },
  crashCym() { const out = REC.metal(2.4, 0.85); const n = DSP.noise(2.4); DSP.filt(n, 'hp', 3200); DSP.env(n, 0.001, 0.7); DSP.add(out, n, 0, 0.5); return DSP.norm(out, 0.85); },
  riser() { const out = DSP.noise(2.2); DSP.sweep(out, 'bp', 300, 7000, 2.2, 2.1); const n = out.length; for (let i = 0; i < n; i++) out[i] *= Math.pow(i / n, 1.6); DSP.fadeOut(out, 0.03); return DSP.norm(out, 0.7); },
  vinyl() { const out = DSP.z(3); const h = DSP.noise(3); DSP.filt(h, 'bp', 3000, 0.4); DSP.add(out, h, 0, 0.05); for (let k = 0; k < 70; k++) { const t = Math.random() * 2.95, p = DSP.noise(0.003); DSP.filt(p, 'hp', 1500); DSP.add(out, p, t, Math.random() * 0.9); } return DSP.norm(DSP.loop(out, 0.1), 0.6); },
};
function reversed(buf) { const b = AU.ctx.createBuffer(buf.numberOfChannels, buf.length, buf.sampleRate); for (let c = 0; c < buf.numberOfChannels; c++) { const s = buf.getChannelData(c), d = b.getChannelData(c); for (let i = 0; i < s.length; i++) d[i] = s[s.length - 1 - i]; } return b; }
function buildBank() {
  const B = AU.bank, M = DSP.mono, many = (k, f) => Array.from({ length: k }, () => M(f()));
  const t0 = performance.now();
  const jobs = [];
  const J = f => jobs.push(f);
  J(() => { B.notif = M(REC.notif()); B.msg_in = M(REC.msgIn()); B.msg_out = M(REC.msgOut()); B.haptic = M(REC.haptic()); B.shutter = M(REC.shutter()); B.tap = M(REC.tap()); B.lock = M(REC.lock()); B.cash = M(REC.cash()); });
  J(() => { B.kick = M(REC.kick()); B.snare = many(2, REC.snare); B.clap = many(2, REC.clap); B.rim = M(REC.rim()); B.perc = M(REC.perc()); });
  J(() => { B.hat = [M(REC.metal(0.12, 0.018)), M(REC.metal(0.12, 0.026)), M(REC.metal(0.15, 0.036))]; B.ohat = M(REC.metal(0.6, 0.17)); });
  J(() => { B.crash = M(REC.crashCym()); B.revcrash = reversed(M(REC.crashCym())); B.riser = M(REC.riser()); B.vinyl = M(REC.vinyl()); });
  J(() => { B.step_snow = many(7, REC.stepSnow); B.step_slush = many(4, REC.stepSlush); B.step_hard = many(4, () => REC.stepHard(false)); B.step_metal = many(4, () => REC.stepHard(true)); B.rustle = many(3, REC.rustle); });
  J(() => { for (const g of ['k9', 'draft', 'plow']) { B['gun_' + g] = many(3, () => REC.gun(g, false)); B['gun_' + g + '_s'] = many(2, () => REC.gun(g, true)); } });
  J(() => { B.casing = many(3, () => REC.casing(false)); B.shell = many(2, () => REC.casing(true)); });
  J(() => { B.reload = M(REC.reload()); B.pump = M(REC.pump()); B.dry = M(REC.dry()); });
  J(() => { B.imp_brick = many(3, () => REC.impact('brick')); B.imp_metal = many(3, () => REC.impact('metal')); B.imp_snow = many(2, () => REC.impact('snow')); B.imp_flesh = many(3, () => REC.impact('flesh')); });
  J(() => { B.ricochet = many(3, REC.ricochet); B.whiz = many(2, REC.whiz); });
  J(() => { B.bodyfall = many(2, REC.bodyfall); B.hurt = many(2, REC.hurt); B.heart = M(REC.heart()); });
  J(() => { B.crash_big = many(2, () => REC.crash(true)); B.crash_small = many(2, () => REC.crash(false)); });
  J(() => { B.door_open = M(REC.door(false)); B.door_close = many(2, () => REC.door(true)); });
  J(() => { B.horn = M(REC.horn(415, 518, 0.42)); B.horn_big = M(REC.horn(298, 372, 0.55)); B.horn_long = M(REC.horn(415, 518, 1.1)); });
  J(() => { B.clack = many(3, REC.clack); B.brake_hiss = M(REC.hiss(1.4)); B.door_slide = M(REC.doorSlide()); B.chime = M(REC.chime()); B.train_horn = M(REC.trainHorn()); });
  J(() => { B.squeal = M(REC.squealLoop()); B.fire = M(REC.fireLoop()); B.steam = M(REC.steamLoop()); B.buzz = M(REC.buzzLoop()); });
  J(() => { B.roll = M(REC.rollLoop()); B.slush = M(REC.slushLoop()); B.skid = M(REC.skidLoop()); });
  J(() => { B.chatter = many(4, REC.chatter); B.dog = many(2, REC.dog); B.flap = M(REC.flap()); B.carpass = many(2, REC.carPass); B.heli = M(REC.heliLoop()); B.rattle = many(2, REC.rattle); B.plane = M(REC.plane()); });
  J(() => { B.punch = many(3, REC.punch); B.swing = many(2, REC.swing); });
  J(() => { B.whoosh = M(REC.whoosh()); B.boom = M(REC.boom()); B.stab = M(REC.stab()); B.static = M(REC.static()); });
  // UI, steps and guns first; the rest is rendered in small slices so startup never hitches
  let i = 0;
  const run = () => {
    const ts = performance.now();
    while (i < jobs.length && performance.now() - ts < 10) { try { jobs[i](); } catch (e) { console.warn('bank', i, e); } i++; }
    if (i < jobs.length) setTimeout(run, 0); else { AU.bankMs = Math.round(performance.now() - t0); AU.bankReady = true; }
  };
  run();
}
async function loadAudioPack() {
  for (const name of AUDIO_PACK) {
    try {
      const r = await fetch('audio/' + name + '.mp3'); if (!r.ok) continue;
      const buf = await AU.ctx.decodeAudioData(await r.arrayBuffer());
      AU.bank[name] = [buf];
    } catch (e) { }
  }
}

/* ---------- speech (train PA, police megaphone) ---------- */
let _voices = null;
function speak(text, o) {
  o = o || {};
  if (!S.settings.voices || !window.speechSynthesis || !window.SpeechSynthesisUtterance) return;
  try {
    if (!_voices) { _voices = speechSynthesis.getVoices() || []; }
    const u = new SpeechSynthesisUtterance(text);
    const en = _voices.filter(v => /^en(-|_)US/i.test(v.lang));
    const pool = en.length ? en : _voices.filter(v => /^en/i.test(v.lang));
    if (pool.length) u.voice = o.alt && pool.length > 1 ? pool[1] : pool[0];
    u.rate = o.rate || 1; u.pitch = o.pitch || 1; u.volume = clamp((o.vol || 1) * S.settings.vol, 0, 1);
    if (o.cancel) speechSynthesis.cancel();
    speechSynthesis.speak(u);
  } catch (e) { }
}

/* =========================================================
   SFX API (called from gameplay)
   ========================================================= */
function gunKind(k) { return k === 'plow' || k === 'draft' ? k : 'k9'; }
function sfxShot(kind, x, y, z, supp, vol) {
  if (!AU.ready) return;
  const k = gunKind(kind);
  const d = distToListener(x, y, z);
  play('gun_' + k + (supp ? '_s' : ''), { x, y, z, vol: (vol || 1) * (k === 'plow' ? 1.25 : k === 'draft' ? 0.85 : 1) * (supp ? 0.5 : 1.6), wet: supp ? 0.12 : 0.55, slap: supp ? 0 : 0.9, ref: 4, rate: 0.97 + Math.random() * 0.06, force: true });
  if (d < 6 && k !== 'plow') play('casing', { x, y: Math.max(0.05, y - 1.3), z, at: 0.32 + Math.random() * 0.1, vol: 0.18, wet: 0.05, ref: 1.5, rate: 0.95 + Math.random() * 0.1 });
  if (d < 6 && k === 'plow') play('shell', { x, y: Math.max(0.05, y - 1.3), z, at: 0.75, vol: 0.2, wet: 0.05, ref: 1.5 });
  if (!supp && d < 220) onLoudNoise(x, z, d);
}
function sfxImpact(mat, x, y, z, vol) {
  if (!AU.ready) return;
  play('imp_' + mat, { x, y, z, vol: vol || 0.55, ref: 2, wet: 0.2, rate: 0.9 + Math.random() * 0.2 });
  if (mat === 'brick' && Math.random() < 0.22) play('ricochet', { x, y, z, vol: 0.18, ref: 3, wet: 0.3, at: 0.01 });
}
function sfxStep(x, y, z, surf, vol, run) {
  if (!AU.ready) return;
  play('step_' + surf, { x, y: y + 0.05, z, vol: vol || 0.3, ref: 1.6, roll: 1.3, wet: AU.indoor ? 0.1 : 0.06, rate: 0.9 + Math.random() * 0.2, nodelay: true, occlude: false });
  if (run && Math.random() < 0.6) play('rustle', { x, y: y + 1.1, z, vol: (vol || 0.3) * 0.25, ref: 1.6, roll: 1.4, wet: 0, rate: 0.9 + Math.random() * 0.2, nodelay: true, occlude: false });
}
const sfx = {
  click() { play('dry', { vol: 0.5 }); },
  ui() { play('tap', { vol: 0.6, rate: 0.95 + Math.random() * 0.1 }); },
  tap() { play('tap', { vol: 0.5, rate: 0.95 + Math.random() * 0.1 }); },
  reload() { play('reload', { x: P.pos.x, y: P.pos.y + 1.2, z: P.pos.z, vol: 0.45, ref: 1.5, wet: 0.04, nodelay: true, occlude: false }); },
  pump() { play('pump', { x: P.pos.x, y: P.pos.y + 1.2, z: P.pos.z, vol: 0.55, ref: 1.5, wet: 0.05, nodelay: true, occlude: false }); },
  hit(head) { play('imp_flesh', { vol: head ? 0.32 : 0.22, rate: head ? 1.25 : 1 }); sfxTone(head ? 2300 : 1700, 0.035, 'sine', 0.04); },
  hurt() {
    play('hurt', { vol: 0.7 });
    if (!AU.ready) return;
    const t = AU.ctx.currentTime, f = AU.duck.frequency;
    f.cancelScheduledValues(t); f.setValueAtTime(f.value, t); f.linearRampToValueAtTime(650, t + 0.03); f.setTargetAtTime(20000, t + 0.25, 0.35);
    if (S.health < 45) sfxTone(4100 + Math.random() * 300, 1.6, 'sine', 0.018);
  },
  step(snow, vol) { sfxStep(P.pos.x, P.pos.y, P.pos.z, surfaceAt(P.pos.x, P.pos.z, P.pos.y), (vol || 0.12) * 2.6, P.sprinting); },
  ping() { play('notif', { vol: 0.55 }); if (MODE !== 'phone') play('haptic', { vol: 0.45, at: 0.02 }); },
  msgIn() { play('msg_in', { vol: 0.5 }); },
  msgOut() { play('msg_out', { vol: 0.5 }); },
  lock() { play('lock', { vol: 0.5 }); },
  cash() { play('cash', { vol: 0.5 }); },
  down(x, z) { play('bodyfall', { x, y: 0.3, z, vol: 0.8, ref: 2.5, wet: 0.15 }); },
  whoosh() { play('whoosh', { vol: 0.35 }); },
  swing(x, z) { play('swing', x === undefined ? { vol: 0.32, rate: 0.9 + Math.random() * 0.2 } : { x, y: 1.4, z, vol: 0.4, ref: 1.5, rate: 0.9 + Math.random() * 0.2 }); },
  punch(x, y, z, big, blocked) { play('punch', { x, y, z, vol: blocked ? 0.4 : big ? 1 : 0.75, ref: 2, wet: 0.12, rate: blocked ? 1.4 : big ? 0.82 : 0.95 + Math.random() * 0.15 }); },
  chime(x, z) { play('chime', { x, y: PLAT_Y + 3, z, vol: 0.5, ref: 8, wet: 0.35 }); },
  horn(x, z) { play('train_horn', { x, y: DECK_Y + 2, z, vol: 1.1, ref: 10, wet: 0.5, slap: 0.6 }); },
  screech(x, z) { /* the continuous squeal is handled by the train voice */ },
  clack(x, z, vol) { play('clack', { x, y: DECK_Y + 0.3, z, vol: 0.6 * (vol || 1), ref: 5, wet: 0.25, rate: 0.9 + Math.random() * 0.2 }); },
  cheer() { if (!AU.ready) return; for (let i = 0; i < 18; i++) play('clap', { vol: 0.14 + Math.random() * 0.1, at: Math.random() * 1.6, rate: 0.85 + Math.random() * 0.3, bus: AU.ui }); play('whoosh', { vol: 0.2, rate: 0.7 }); },
  thud() { play('hurt', { vol: 0.9, rate: 0.7 }); play('bodyfall', { vol: 0.5 }); },
  crash(x, z, imp) { play(imp > 10 ? 'crash_big' : 'crash_small', { x, y: 0.7, z, vol: clamp(imp / 12, 0.35, 1.5), ref: 4, wet: 0.35, slap: 0.6, rate: 0.92 + Math.random() * 0.16 }); },
  honk(x, z, big) { play(big ? 'horn_big' : 'horn', { x: x === undefined ? P.pos.x : x, y: 1, z: z === undefined ? P.pos.z : z, vol: 0.75, ref: 4, wet: 0.3, slap: 0.5 }); },
  door(x, z) { const px = x === undefined ? P.pos.x : x, pz = z === undefined ? P.pos.z : z; play('door_open', { x: px, y: 1, z: pz, vol: 0.5, ref: 2, wet: 0.08, nodelay: true }); play('door_close', { x: px, y: 1, z: pz, vol: 0.75, ref: 2, wet: 0.12, at: 0.55, nodelay: true }); },
  shutter() { play('shutter', { vol: 0.6 }); },
  siren() { if (!AU.ready) return; sirenBurst(); },
  whiz(x, y, z) { play('whiz', { x, y, z, vol: 0.7, ref: 1.5, wet: 0.05, nodelay: true, occlude: false }); },
  stinger(kind) {
    if (!AU.ready) return;
    if (kind === 'cut' && REAL_T - (AU._stingT || -9) < 1.2) return;
    AU._stingT = REAL_T;
    if (kind === 'cut') { play('revcrash', { vol: 0.16, bus: AU.music }); play('boom', { vol: 0.35, at: 0.05, bus: AU.music }); }
    else if (kind === 'wanted') { play('stab', { vol: 0.32, bus: AU.music }); }
    else if (kind === 'busted') { play('boom', { vol: 0.6, bus: AU.music }); play('stab', { vol: 0.35, bus: AU.music, rate: 0.85 }); }
    else if (kind === 'down') { play('boom', { vol: 0.7, bus: AU.music, rate: 0.8 }); }
    else if (kind === 'banner') play('whoosh', { vol: 0.22, rate: 1.2 });
  },
};
