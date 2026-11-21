
/* =========================================================
   SOUNDSCAPE - the living city: wind, traffic, engines with a
   gearbox, sirens with doppler, police radio, the L, fires,
   steam, footsteps, music leaking out of buildings and cars,
   distant events, adaptive score, car radio.
   ========================================================= */
const AMB = { wind: null, city: null, evT: 6, heartT: 0, chatT: 4, heli: null, heliA: 0 };
let MUSIC_NEAR = 0;
function surfaceAt(x, z, y) {
  if (y > DECK_Y0 - 0.6) return 'metal';
  if (onIce(x, z, y)) return 'hard';
  for (const k of XL) if (Math.abs(x - k) < ROAD_HW) return 'slush';
  for (const k of ZL) if (Math.abs(z - k) < ROAD_HW) return 'slush';
  return 'snow';
}
function startAmbience() {
  const c = AU.ctx;
  const mk = (buf, rate) => { const s = c.createBufferSource(); s.buffer = buf; s.loop = true; s.playbackRate.value = rate || 1; s.start(0, Math.random() * buf.duration * 0.9); return s; };
  const filt = (type, f, q) => { const b = c.createBiquadFilter(); b.type = type; b.frequency.value = f; b.Q.value = q || 0.7; return b; };
  const pan = p => { const s = c.createStereoPanner(); s.pan.value = p; return s; };
  const chain = (src, ...nodes) => { let n = src; for (const x of nodes) { n.connect(x); n = x; } n.connect(AU.amb); return nodes; };
  const W = {};
  W.b1 = filt('bandpass', 450, 0.55); W.g1 = gainN(0.05); chain(mk(AU.pink), W.b1, W.g1, pan(-0.35));
  W.b2 = filt('bandpass', 520, 0.6); W.g2 = gainN(0.04); chain(mk(AU.pink, 0.93), W.b2, W.g2, pan(0.4));
  W.w1 = filt('bandpass', 700, 7); W.wg1 = gainN(0); chain(mk(AU.noise, 0.8), W.w1, W.wg1, pan(-0.55));
  W.w2 = filt('bandpass', 950, 9); W.wg2 = gainN(0); chain(mk(AU.noise, 0.77), W.w2, W.wg2, pan(0.55));
  W.buffG = gainN(0.05); chain(mk(AU.brown, 0.6), filt('lowpass', 110), W.buffG);
  W.hissG = gainN(0.004); chain(mk(AU.noise), filt('highpass', 6500), W.hissG);
  const C = {};
  C.r1 = gainN(0.04); chain(mk(AU.brown, 0.5), filt('lowpass', 190), C.r1, pan(-0.6));
  C.r2 = gainN(0.04); chain(mk(AU.brown, 0.47), filt('lowpass', 210), C.r2, pan(0.6));
  C.sw = gainN(0.02); chain(mk(AU.pink, 0.7), filt('bandpass', 420, 0.5), C.sw);
  C.hs = gainN(0.005); chain(mk(AU.pink), filt('bandpass', 1900, 0.4), C.hs);
  C.room = gainN(0); { const o = c.createOscillator(); o.frequency.value = 60; const o2 = c.createOscillator(); o2.frequency.value = 120; const g2 = gainN(0.4); o.connect(C.room); o2.connect(g2).connect(C.room); C.room.connect(AU.master); o.start(); o2.start(); }
  AMB.wind = W; AMB.city = C;
  // extra bank sounds that need the scene constants
  AU.bank.siren_far = DSP.mono(sirenFarRec());
  AU.bank.pop = Array.from({ length: 3 }, () => { const o = DSP.z(0.25); DSP.click(o, 0, 1800, 1); const t = DSP.tone(0.15, 120, 60, 0.05); DSP.env(t, 0.001, 0.025); DSP.add(o, t, 0, 0.9); DSP.grains(o, 0.01, 0.08, 8, 1500, 5000, 0.4); return DSP.mono(DSP.norm(o, 0.9)); });
  AU.bank.shopbell = DSP.mono((() => { const o = DSP.z(1.2); for (let k = 0; k < 6; k++) DSP.modes(o, k * 0.07 + Math.random() * 0.03, [[2650 + Math.random() * 300, 0.25, 1], [3920 + Math.random() * 300, 0.18, 0.5], [6100, 0.08, 0.2]], 1 - k * 0.13); return DSP.norm(o, 0.7); })());
  AU.bank.chirp = DSP.mono(chirpRec());
}
function sirenFarRec() {
  const n = DSP.n(8), out = new Float32Array(n); let ph = 0;
  for (let i = 0; i < n; i++) {
    const t = i / AU.sr, c = t % 4.3, k = c < 1.9 ? c / 1.9 : 1 - (c - 1.9) / 2.4;
    const f = 680 + 800 * Math.sin(k * Math.PI / 2);
    ph += f / AU.sr; ph -= Math.floor(ph);
    out[i] = (ph < 0.5 ? 1 : -1) * 0.6 + (2 * ph - 1) * 0.4;
  }
  DSP.filt(out, 'hp', 450); DSP.filt(out, 'peak', 1700, 1, 6); DSP.filt(out, 'lp', 3200); DSP.sat(out, 2);
  for (let i = 0; i < n; i++) { const t = i / AU.sr; out[i] *= Math.min(1, t / 1.5, (8 - t) / 1.5); }
  return DSP.norm(out, 0.8);
}
function chirpRec() {
  const n = DSP.n(0.75), out = new Float32Array(n); let ph = 0;
  for (let i = 0; i < n; i++) { const t = i / AU.sr, f = t < 0.3 ? 650 + 900 * (t / 0.3) : 1550 - 800 * ((t - 0.3) / 0.45); ph += f / AU.sr; ph -= Math.floor(ph); out[i] = ph < 0.5 ? 1 : -1; }
  DSP.filt(out, 'hp', 450); DSP.filt(out, 'peak', 1700, 1, 6); DSP.filt(out, 'lp', 3500); DSP.sat(out, 2); DSP.env(out, 0.01, 0.3, 0.35);
  return DSP.norm(out, 0.85);
}

/* ---------- master update (called every frame) ---------- */
function updateAmbience(dt, gust, indoorOrCar, fireNear) {
  if (!AU.ready) return;
  updateListener(dt);
  const t = AU.ctx.currentTime;
  const inBuilding = (MODE === 'menu' && MENU && MENU.indoor) || MODE === 'bench' || MODE === 'rhythm';
  const inCar = !!P.car && MODE !== 'title';
  AU.indoor = inBuilding;
  AU.occl.frequency.setTargetAtTime(inBuilding ? 420 : inCar ? 5500 : 20000, t, 0.15);
  AU.ambLP.frequency.setTargetAtTime(inBuilding ? 320 : inCar ? 1600 : 18000, t, 0.2);
  const W = AMB.wind, C = AMB.city, out = inBuilding ? 0.3 : inCar ? 0.5 : 1;
  const g = clamp(gust, 0, 1);
  W.g1.gain.setTargetAtTime((0.03 + g * 0.13) * out, t, 0.3);
  W.g2.gain.setTargetAtTime((0.025 + g * 0.1) * out, t, 0.35);
  W.b1.frequency.setTargetAtTime(360 + g * 520, t, 0.4); W.b2.frequency.setTargetAtTime(430 + g * 600, t, 0.5);
  const wob = Math.sin(REAL_T * 0.63) * 260 + Math.sin(REAL_T * 1.7) * 160;
  W.wg1.gain.setTargetAtTime(g * g * 0.06 * out, t, 0.4); W.w1.frequency.setTargetAtTime(560 + wob + g * 380, t, 0.2);
  W.wg2.gain.setTargetAtTime(g * g * 0.045 * out, t, 0.4); W.w2.frequency.setTargetAtTime(820 - wob * 0.7 + g * 300, t, 0.2);
  W.buffG.gain.setTargetAtTime((0.02 + g * 0.09 * (0.6 + Math.random() * 0.4)) * (inBuilding || inCar ? 0.1 : 1), t, 0.05);
  W.hissG.gain.setTargetAtTime((0.003 + g * 0.006) * out, t, 0.5);
  const day = 1 - DN.lamps;
  C.r1.gain.setTargetAtTime((0.025 + day * 0.035) * out, t, 1); C.r2.gain.setTargetAtTime((0.025 + day * 0.035) * out, t, 1);
  C.sw.gain.setTargetAtTime((0.012 + day * 0.016) * (0.7 + 0.3 * Math.sin(REAL_T * 0.07)) * out, t, 1);
  C.hs.gain.setTargetAtTime((0.003 + day * 0.004) * out, t, 1);
  C.room.gain.setTargetAtTime(inBuilding ? 0.004 : 0, t, 0.3);
  // health: heartbeat and a closing-in muffle
  if (MODE === 'play' || MODE === 'phone') {
    if (P.dead) AU.duck.frequency.setTargetAtTime(380, t, 0.3);
    else if (S.health < 30) {
      AMB.heartT -= dt;
      if (AMB.heartT <= 0) { AMB.heartT = lerp(0.6, 0.95, S.health / 30); play('heart', { vol: 0.5 }); }
      AU.duck.frequency.setTargetAtTime(2200 + S.health * 180, t, 0.6);
    } else if (AU.duck.frequency.value < 19000 && GAME_T - (P.lastHurt || -9) > 0.6) AU.duck.frequency.setTargetAtTime(20000, t, 0.5);
  } else if (MODE === 'title' || MODE === 'cutscene') AU.duck.frequency.setTargetAtTime(20000, t, 0.4);
  staticEmitters(dt);
  musicSources(dt);
  trafficVoices(dt);
  npcSteps(dt);
  distantEvents(dt);
  copChatter(dt);
  updateHeli(dt);
  updateScoreDirector(dt);
}

/* ---------- static loops: fire barrels, steam vents, neon ---------- */
const STATIC_EM = new Map();
function staticEmitters(dt) {
  if (!AU.bankReady) return;
  const want = [];
  for (const B of BARRELS) { const d = Math.hypot(B.x - LIS.x, B.z - LIS.z); if (d < 24) want.push({ key: 'f' + B.x + ':' + B.z, x: B.x, y: 0.9, z: B.z, d, buf: 'fire', lvl: 0.5 }); }
  for (const V of VENTS) { const d = Math.hypot(V.x - LIS.x, V.z - LIS.z); if (d < 16) want.push({ key: 'v' + V.x + ':' + V.z, x: V.x, y: 0.1, z: V.z, d, buf: 'steam', lvl: 0.16 }); }
  if (DN.lamps > 0.3) { const L = LOC.storeFront, d = Math.hypot(L.x - LIS.x, L.z - LIS.z); if (d < 12) want.push({ key: 'neon', x: L.x, y: 3, z: L.z, d, buf: 'buzz', lvl: 0.035 }); }
  want.sort((a, b) => a.d - b.d); want.length = Math.min(want.length, 4);
  const keep = new Set(want.map(w => w.key));
  for (const [k, e] of STATIC_EM) if (!keep.has(k)) { e.em.kill(); try { e.src.stop(AU.ctx.currentTime + 0.5); } catch (er) { } STATIC_EM.delete(k); }
  for (const w of want) {
    let e = STATIC_EM.get(w.key);
    if (!e) { const em = new Emitter({ ref: 1.8, wet: 0.12 }); e = { em, src: loopSrc(AU.bank[w.buf], em.in, 0.95 + Math.random() * 0.1) }; STATIC_EM.set(w.key, e); }
    e.em.set(w.x, w.y, w.z, dt, w.lvl * (AU.indoor ? 0.3 : 1));
  }
}

/* ---------- music heard in the world: the studio, a boombox, other players' cars ---------- */
const MSRC = new Map();
function musicSources(dt) {
  const cands = [];
  const S8 = LOC.studio, ds = Math.hypot(S8.x - LIS.x, S8.z - LIS.z);
  const inStudio = MODE === 'menu' && MENU && MENU.title === 'Basement 808';
  if (ds < 48 || inStudio) cands.push({ key: 'studio', st: 1, x: S8.x, y: 0.4, z: S8.z - 3, d: inStudio ? 0 : ds, lvl: MODE === 'rhythm' || MODE === 'bench' ? 0 : inStudio ? 0.22 : 0.26, lp: inStudio ? 1 : ds < 7 ? 0.05 : 0.022, ref: 3 });
  if (DN.lamps > 0.4) { const L = LOC.pavilion, d = Math.hypot(L.x - LIS.x, L.z - LIS.z); if (d < 42) cands.push({ key: 'pav', st: 3, x: L.x, y: 1, z: L.z, d, lvl: 0.2, lp: 0.3, ref: 3 }); }
  if (typeof NET !== 'undefined') for (const R of NET.remotes.values()) {
    if (!R.veh || !(R.rd > 0) || !STATIONS[R.rd] || STATIONS[R.rd].yours) continue;
    const d = Math.hypot(R.veh.pos.x - LIS.x, R.veh.pos.z - LIS.z);
    if (d < 32) cands.push({ key: 'r' + R.peer + ':' + R.rd, st: R.rd, x: R.veh.pos.x, y: 1, z: R.veh.pos.z, d, lvl: 0.3, lp: 0.07, ref: 3 });
  }
  cands.sort((a, b) => a.d - b.d); cands.length = Math.min(cands.length, 2);
  const keep = new Set(cands.map(c => c.key));
  for (const [k, m] of MSRC) if (!keep.has(k)) { m.player.stop(); m.em.kill(); MSRC.delete(k); }
  MUSIC_NEAR = 0;
  for (const c of cands) {
    let m = MSRC.get(c.key);
    if (!m) { const em = new Emitter({ ref: c.ref, wet: 0.2, lp: c.lp }); m = { em, player: new StationPlayer(c.st, em.in, 0.9) }; MSRC.set(c.key, m); }
    m.em.lpMul = c.lp;
    m.em.set(c.x, c.y, c.z, dt, c.lvl);
    MUSIC_NEAR = Math.max(MUSIC_NEAR, c.lvl * clamp(1 - c.d / 30, 0, 1));
  }
}

/* ---------- engines ---------- */
const ENGINE_SPEC = {
  hatch: { cyl: 4, idle: 850, red: 6600, pops: false }, sedan: { cyl: 6, idle: 750, red: 6200 }, suv: { cyl: 6, idle: 700, red: 5600 },
  pickup: { cyl: 8, idle: 650, red: 5400 }, coupe: { cyl: 6, idle: 900, red: 7400, pops: true }, van: { cyl: 6, idle: 700, red: 5200 },
  police: { cyl: 8, idle: 700, red: 6000, pops: true }, taxi: { cyl: 4, idle: 800, red: 6000 },
};
const GEARS = [3.3, 2.05, 1.45, 1.08, 0.85], FINAL = 3.6;
const _waves = {};
function engineWave(cyl) {
  if (_waves[cyl]) return _waves[cyl];
  const N = 120, re = new Float32Array(N + 1), im = new Float32Array(N + 1), R = rng(cyl * 977);
  for (let n = 1; n <= N; n++) {
    let a = n % cyl === 0 ? 1 / Math.pow(n / cyl, 0.8) : n % (cyl / 2) === 0 ? 0.3 / Math.pow(n / cyl, 0.9) : 0.1 * R() / (1 + n / 20);
    if (cyl === 8 && n % 2 === 1) a += 0.12 * R() / (1 + n / 30);
    a /= 1 + Math.pow(n / 70, 2);
    const ph = R() * Math.PI * 2; re[n] = a * Math.cos(ph); im[n] = a * Math.sin(ph);
  }
  return (_waves[cyl] = AU.ctx.createPeriodicWave(re, im));
}
function engineVoice(model, full) {
  const c = AU.ctx, spec = ENGINE_SPEC[model] || ENGINE_SPEC.sedan;
  const em = new Emitter({ ref: full ? 3.5 : 4, wet: 0.08 });
  const V = { spec, em, srcs: [] };
  V.osc = c.createOscillator(); V.osc.setPeriodicWave(engineWave(spec.cyl)); V.osc.frequency.value = spec.idle / 120;
  V.drive = gainN(0.5);
  const sat = c.createWaveShaper(); sat.curve = AU.curve; sat.oversample = '2x';
  V.lp = c.createBiquadFilter(); V.lp.type = 'lowpass'; V.lp.Q.value = 0.9; V.lp.frequency.value = 600;
  const muff = c.createBiquadFilter(); muff.type = 'peaking'; muff.frequency.value = spec.cyl === 8 ? 80 : 105; muff.Q.value = 1; muff.gain.value = 6;
  V.out = gainN(0);
  V.osc.connect(V.drive).connect(sat).connect(V.lp).connect(muff).connect(V.out).connect(em.in);
  V.osc.start(); V.srcs.push(V.osc);
  // combustion rasp: noise amplitude-modulated at the firing frequency
  const nz = loopSrc(AU.noise, null); nz.disconnect();
  const nbp = c.createBiquadFilter(); nbp.type = 'bandpass'; nbp.frequency.value = 1300; nbp.Q.value = 0.8;
  V.am = gainN(0.5); V.amOsc = c.createOscillator(); V.amOsc.frequency.value = spec.idle / 120 * spec.cyl; const amd = gainN(0.5);
  V.amOsc.connect(amd).connect(V.am.gain); V.amOsc.start();
  V.rasp = gainN(0); nz.connect(nbp).connect(V.am).connect(V.rasp).connect(V.lp);
  V.srcs.push(nz, V.amOsc);
  if (full) {
    const ink = loopSrc(AU.pink, null); ink.disconnect(); const ibp = c.createBiquadFilter(); ibp.type = 'bandpass'; ibp.frequency.value = 2600; ibp.Q.value = 1.5;
    V.ink = gainN(0); ink.connect(ibp).connect(V.ink).connect(em.in); V.srcs.push(ink);
    V.whine = c.createOscillator(); V.whineG = gainN(0); V.whine.connect(V.whineG).connect(em.in); V.whine.start(); V.srcs.push(V.whine);
  }
  if (AU.bank.roll) {
    V.rollG = gainN(0); V.roll = loopSrc(AU.bank.roll, V.rollG); V.rollG.connect(em.in); V.srcs.push(V.roll);
    if (full) {
      V.slushG = gainN(0); V.slush = loopSrc(AU.bank.slush, V.slushG); V.slushG.connect(em.in); V.srcs.push(V.slush);
      V.skidG = gainN(0); V.skid = loopSrc(AU.bank.skid, V.skidG); V.skidG.connect(em.in); V.srcs.push(V.skid);
      V.windG = gainN(0); const w = loopSrc(AU.pink, null); w.disconnect(); const whp = c.createBiquadFilter(); whp.type = 'highpass'; whp.frequency.value = 700; w.connect(whp).connect(V.windG).connect(AU.sfx); V.srcs.push(w);
    }
  }
  V.rpm = spec.idle; V.gear = 0; V.shiftT = 0; V.startT = 0; V.popT = 0;
  return V;
}
function killVoice(V) { if (!V) return; V.em.kill(); if (V.windG) V.windG.gain.setTargetAtTime(0, AU.ctx.currentTime, 0.05); const t = AU.ctx.currentTime + 0.6; for (const s of V.srcs) { try { s.stop(t); } catch (e) { } } }
const ENG = { V: null, car: null };
function startEngine() {
  if (!AU.ready || !P.car) return;
  if (ENG.V) killVoice(ENG.V);
  ENG.V = engineVoice(P.car.model, true); ENG.car = P.car;
  ENG.V.startT = 0.9;
  // starter motor whirr
  const c = AU.ctx, t = c.currentTime + 0.25, o = c.createOscillator(), f = c.createBiquadFilter(), g = gainN(0);
  o.type = 'sawtooth'; o.frequency.setValueAtTime(14, t); o.frequency.linearRampToValueAtTime(22, t + 0.5);
  f.type = 'bandpass'; f.frequency.value = 520; f.Q.value = 1.2;
  o.connect(f).connect(g).connect(ENG.V.em.in); g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(0.5, t + 0.05); g.gain.setValueAtTime(0.5, t + 0.45); g.gain.linearRampToValueAtTime(0, t + 0.55);
  o.start(t); o.stop(t + 0.6);
}
function stopEngine() { if (ENG.V) killVoice(ENG.V); ENG.V = null; ENG.car = null; }
function updateEngine() {
  if (!AU.ready) return;
  const dt = Math.min(0.05, AU._edt || 0.016);
  if (!P.car) { if (ENG.V) stopEngine(); return; }
  if (!ENG.V || ENG.car !== P.car) startEngine();
  const V = ENG.V, v = P.car, t = AU.ctx.currentTime, inp = playerDriveInput(), spec = V.spec;
  const sp = Math.abs(v.speed), thr = clamp(Math.abs(inp.thr || 0), 0, 1), rev = v.speed < -0.3;
  const wheelRps = sp / (2 * Math.PI * (v.sp.r || 0.33));
  const rpmFor = gi => wheelRps * 60 * GEARS[gi] * FINAL;
  if (rev) V.gear = 0;
  else if (V.shiftT <= 0) {
    if (V.gear < GEARS.length - 1 && rpmFor(V.gear) > (thr > 0.5 ? spec.red * 0.9 : 3000)) { V.gear++; V.shiftT = 0.22; }
    else if (V.gear > 0 && rpmFor(V.gear - 1) < (thr > 0.5 ? spec.red * 0.68 : 2200)) { V.gear--; V.shiftT = 0.12; }
  }
  let rpm = Math.max(spec.idle, rpmFor(V.gear));
  if (sp < 5 && thr > 0.05) rpm = Math.max(rpm, spec.idle + thr * 2300 * (1 - sp / 6));
  if (V.shiftT > 0) { V.shiftT -= dt; rpm *= 0.9; }
  if (V.startT > 0) { V.startT -= dt; rpm = V.startT > 0.6 ? 0 : spec.idle + (1 - V.startT / 0.6) * 900; }
  if (rpm > spec.red) rpm = spec.red - Math.random() * 350;
  V.rpm = lerp(V.rpm, rpm, Math.min(1, dt * 9));
  const on = V.startT <= 0.6, load = V.shiftT > 0 ? 0.15 : thr, k = V.rpm / spec.red;
  const live = MODE === 'play' || MODE === 'phone' || MODE === 'cutscene' ? 1 : 0.2;
  V.osc.frequency.setTargetAtTime(Math.max(4, V.rpm / 120), t, 0.025);
  V.amOsc.frequency.setTargetAtTime(Math.max(4, V.rpm / 120 * spec.cyl), t, 0.025);
  V.drive.gain.setTargetAtTime(0.3 + load * 1.2, t, 0.04);
  V.lp.frequency.setTargetAtTime(300 + V.rpm * 0.2 + load * 2400, t, 0.04);
  V.out.gain.setTargetAtTime(on ? 0.2 + load * 0.28 + k * 0.14 : 0, t, 0.04);
  V.rasp.gain.setTargetAtTime(on ? load * 0.22 * (0.3 + k) : 0, t, 0.04);
  V.ink.gain.setTargetAtTime(on ? load * 0.05 * k : 0, t, 0.05);
  V.whine.frequency.setTargetAtTime(30 + sp * 26 * GEARS[V.gear], t, 0.05); V.whineG.gain.setTargetAtTime(Math.min(0.012, sp * 0.0006), t, 0.1);
  if (V.rollG) {
    const l = vSide(v), lat = Math.abs(v.vel.x * l.x + v.vel.y * l.z);
    V.rollG.gain.setTargetAtTime(clamp(sp / 22, 0, 1) * 0.32, t, 0.08); V.roll.playbackRate.setTargetAtTime(0.7 + sp / 45, t, 0.1);
    V.slushG.gain.setTargetAtTime(clamp(sp / 18, 0, 1) * 0.16, t, 0.08);
    const skid = clamp((lat - 2.6) / 5, 0, 1) + (v.brake && sp > 9 ? 0.35 : 0);
    V.skidG.gain.setTargetAtTime(Math.min(1, skid) * 0.28 * live, t, 0.05); V.skid.playbackRate.setTargetAtTime(0.9 + sp / 80, t, 0.1);
    V.windG.gain.setTargetAtTime(Math.pow(sp / 35, 2) * 0.1 * live, t, 0.1);
  }
  // overrun crackle
  V.popT -= dt;
  if (spec.pops && thr < 0.05 && V.rpm > 3200 && V.popT <= 0 && Math.random() < dt * 6) { V.popT = 0.08; const b = vFwd(v); play('pop', { x: v.pos.x - b.x * v.sp.len * 0.5, y: 0.4, z: v.pos.z - b.z * v.sp.len * 0.5, vol: 0.35, ref: 2, wet: 0.15, nodelay: true }); }
  V.em.set(v.pos.x, 0.6, v.pos.z, dt, live);
}
// nearby traffic and other players' cars
const TVOICES = [];
function trafficVoices(dt) {
  if (!AU.bankReady) return;
  const cands = [];
  for (const v of VEH) {
    if (v === P.car || v.dead) continue;
    const running = v.ai || v.copAI || v.remote || (v.driver && v.driver !== 'player');
    if (!running) continue;
    const d = Math.hypot(v.pos.x - LIS.x, v.pos.z - LIS.z);
    if (d < 60) cands.push({ v, d });
  }
  cands.sort((a, b) => a.d - b.d); cands.length = Math.min(cands.length, 4);
  for (const tv of TVOICES) if (!cands.some(c => c.v === tv.v)) { killVoice(tv.V); tv.dead = true; }
  for (let i = TVOICES.length - 1; i >= 0; i--) if (TVOICES[i].dead) TVOICES.splice(i, 1);
  const t = AU.ctx.currentTime;
  for (const c of cands) {
    let tv = TVOICES.find(x => x.v === c.v);
    if (!tv) { tv = { v: c.v, V: engineVoice(c.v.model, false) }; TVOICES.push(tv); }
    const V = tv.V, v = c.v, sp = Math.abs(v.speed), spec = V.spec;
    const gear = Math.min(3, Math.floor(sp / 7)), rpm = spec.idle + ((sp - gear * 7) / 7) * 2400 * (gear < 3 ? 1 : 0.5) + gear * 250;
    const acc = clamp((sp - (tv.lastSp || sp)) / Math.max(dt, 0.001) / 3, 0, 1); tv.lastSp = sp;
    V.rpm = lerp(V.rpm, rpm, Math.min(1, dt * 5));
    const dop = V.em.doppler;
    V.osc.frequency.setTargetAtTime(V.rpm / 120 * dop, t, 0.04); V.amOsc.frequency.setTargetAtTime(V.rpm / 120 * spec.cyl * dop, t, 0.04);
    V.drive.gain.setTargetAtTime(0.35 + acc * 0.8, t, 0.08); V.lp.frequency.setTargetAtTime(300 + V.rpm * 0.18 + acc * 1500, t, 0.08);
    V.out.gain.setTargetAtTime(0.16 + acc * 0.14, t, 0.08); V.rasp.gain.setTargetAtTime(acc * 0.1, t, 0.08);
    if (V.rollG) { V.rollG.gain.setTargetAtTime(clamp(sp / 22, 0, 1) * 0.3, t, 0.1); V.roll.playbackRate.setTargetAtTime((0.7 + sp / 45) * dop, t, 0.1); }
    V.em.set(v.pos.x, 0.6, v.pos.z, dt, MODE === 'menu' || MODE === 'rhythm' ? 0.3 : 1);
  }
}

/* ---------- sirens ---------- */
const SIRENS = [];
function sirenVoice() {
  const c = AU.ctx, em = new Emitter({ ref: 7, wet: 0.35 });
  const o1 = c.createOscillator(), o2 = c.createOscillator(); o1.type = 'square'; o2.type = 'sawtooth'; o2.detune.value = 8;
  const mix = gainN(1), drive = gainN(2.2), sh = c.createWaveShaper(); sh.curve = AU.curve;
  const hp = c.createBiquadFilter(); hp.type = 'highpass'; hp.frequency.value = 450;
  const pk = c.createBiquadFilter(); pk.type = 'peaking'; pk.frequency.value = 1700; pk.Q.value = 1; pk.gain.value = 6;
  const lp = c.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = 3600;
  const g = gainN(0.32);
  o1.connect(mix); o2.connect(gainN(0.5)).connect(mix); mix.connect(drive).connect(sh).connect(hp).connect(pk).connect(lp).connect(g).connect(em.in);
  o1.start(); o2.start();
  return { em, o: [o1, o2], v: null, mode: 'wail', nextT: 0, modeT: 0 };
}
function scheduleSiren(s, t) {
  const lo = 680, hi = 1480;
  for (const o of s.o) o.frequency.cancelScheduledValues(t);
  if (s.mode === 'wail') {
    for (const o of s.o) { o.frequency.setValueAtTime(lo, t); o.frequency.linearRampToValueAtTime(hi, t + 1.9); o.frequency.linearRampToValueAtTime(lo, t + 4.3); }
    s.nextT = t + 4.3;
  } else {
    for (const o of s.o) { o.frequency.setValueAtTime(lo, t); for (let k = 0; k < 6; k++) { o.frequency.linearRampToValueAtTime(hi, t + k * 0.32 + 0.16); o.frequency.linearRampToValueAtTime(lo, t + (k + 1) * 0.32); } }
    s.nextT = t + 6 * 0.32;
  }
}
function updateSiren() {
  if (!AU.ready) return;
  const dt = Math.min(0.05, AU._edt || 0.016), t = AU.ctx.currentTime;
  const cands = [];
  for (const v of VEH) if (v.siren && !v.dead) { const d = Math.hypot(v.pos.x - LIS.x, v.pos.z - LIS.z); if (d < 280) cands.push({ v, d }); }
  cands.sort((a, b) => a.d - b.d); cands.length = Math.min(cands.length, 2);
  while (SIRENS.length < cands.length) SIRENS.push(sirenVoice());
  SIRENS.forEach((s, i) => {
    const c = cands[i];
    if (!c) { s.em.set(s.em.x, 1.5, s.em.z, dt, 0); s.v = null; return; }
    if (s.v !== c.v) { s.v = c.v; s.nextT = 0; s.em.dPrev = null; }
    s.modeT -= dt;
    if (s.modeT <= 0) { s.mode = c.d < 45 && Math.random() < 0.55 ? 'yelp' : 'wail'; s.modeT = 3 + Math.random() * 6; }
    if (t > s.nextT - 0.06) scheduleSiren(s, Math.max(t, s.nextT || t));
    const cents = 1200 * Math.log2(clamp(s.em.doppler, 0.8, 1.25));
    for (const o of s.o) o.detune.setTargetAtTime(cents + (o.type === 'sawtooth' ? 8 : 0), t, 0.05);
    const live = MODE === 'play' || MODE === 'phone' || MODE === 'cutscene' ? 1 : 0.35;
    s.em.set(c.v.pos.x, (c.v.sp.roofY || 1.4) + 0.3, c.v.pos.z, dt, live);
  });
}
function sirenBurst() { const a = Math.random() * TAU; play('chirp', { x: P.pos.x + Math.cos(a) * 8, y: 1.5, z: P.pos.z + Math.sin(a) * 8, vol: 0.9, ref: 6, wet: 0.35, slap: 0.4 }); play('chirp', { x: P.pos.x + Math.cos(a) * 8, y: 1.5, z: P.pos.z + Math.sin(a) * 8, vol: 0.9, ref: 6, wet: 0.35, at: 0.8 }); }
function copChatter(dt) {
  AMB.chatT -= dt; if (AMB.chatT > 0) return;
  AMB.chatT = 4 + Math.random() * 7;
  let best = null, bd = 26;
  for (const c of COPS) if (c.state !== 'down') { const d = Math.hypot(c.pos.x - LIS.x, c.pos.z - LIS.z); if (d < bd) { bd = d; best = { x: c.pos.x, y: c.pos.y + 1.3, z: c.pos.z }; } }
  for (const v of VEH) if (v.copAI || v.model === 'police' && v.siren) { const d = Math.hypot(v.pos.x - LIS.x, v.pos.z - LIS.z); if (d < bd) { bd = d; best = { x: v.pos.x, y: 1.1, z: v.pos.z }; } }
  const st = LOC.station; if (Math.hypot(st.x - LIS.x, st.z - LIS.z) < 30 && !best) best = { x: st.x, y: 1.5, z: st.z };
  if (best) play('chatter', { x: best.x, y: best.y, z: best.z, vol: 0.4, ref: 2, wet: 0.15 });
}
function updateHeli(dt) {
  const want = (MODE === 'play' || MODE === 'phone') && WANTED.level >= 4;
  if (want && !AMB.heli && AU.bankReady) { const em = new Emitter({ ref: 30, wet: 0.4 }); AMB.heli = { em, src: loopSrc(AU.bank.heli, em.in), lvl: 0 }; }
  if (!AMB.heli) return;
  const H = AMB.heli;
  H.lvl = clamp(H.lvl + (want ? dt * 0.15 : -dt * 0.2), 0, 1);
  AMB.heliA += dt * 0.12;
  H.em.set(P.pos.x + Math.cos(AMB.heliA) * 70, 65, P.pos.z + Math.sin(AMB.heliA) * 70, dt, H.lvl * 0.9);
  H.src.playbackRate.setTargetAtTime(H.em.doppler, AU.ctx.currentTime, 0.1);
  if (!want && H.lvl <= 0) { H.em.kill(); try { H.src.stop(AU.ctx.currentTime + 0.5); } catch (e) { } AMB.heli = null; }
}

/* ---------- the L ---------- */
const TRAIN_AU = new Map();
const AXLES = [0.9, 3.0, 11.6, 13.7];
function trainAudio(dt) {
  if (!AU.ready || !AU.bankReady) return;
  const t = AU.ctx.currentTime;
  for (const T of TRAINS) {
    let A = TRAIN_AU.get(T);
    const zc = clamp(LIS.z, T.z - TRAIN_HALF, T.z + TRAIN_HALF), y = DECK_Y + 1.2;
    const d = T.state === 'gone' ? 999 : Math.hypot(T.x - LIS.x, y - LIS.y, zc - LIS.z);
    if (d > 280) { if (A) { A.em.kill(); for (const s of A.srcs) { try { s.stop(t + 0.5); } catch (e) { } } TRAIN_AU.delete(T); } continue; }
    if (!A) {
      const c = AU.ctx, em = new Emitter({ ref: 9, wet: 0.4 }), srcs = [];
      const lp = c.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = 150; const rumbleG = gainN(0); const r = loopSrc(AU.brown, lp); lp.connect(rumbleG).connect(em.in); srcs.push(r);
      const bp = c.createBiquadFilter(); bp.type = 'bandpass'; bp.frequency.value = 900; bp.Q.value = 0.7; const roarG = gainN(0); const ro = loopSrc(AU.pink, bp); bp.connect(roarG).connect(em.in); srcs.push(ro);
      const m1 = c.createOscillator(), m2 = c.createOscillator(); m1.type = 'triangle'; const motorG = gainN(0); m1.connect(motorG); m2.connect(gainN(0.4)).connect(motorG); motorG.connect(em.in); m1.start(); m2.start(); srcs.push(m1, m2);
      const squealG = gainN(0); srcs.push(loopSrc(AU.bank.squeal, squealG)); squealG.connect(em.in);
      const slp = c.createBiquadFilter(); slp.type = 'lowpass'; slp.frequency.value = 85; slp.Q.value = 4; const structG = gainN(0); srcs.push(loopSrc(AU.brown, slp)); slp.connect(structG).connect(em.in);
      A = { em, srcs, lp, rumbleG, roarG, m1, m2, motorG, squealG, structG, dist: 0, prevV: 0 };
      TRAIN_AU.set(T, A);
    }
    const sp = Math.abs(T.v), accel = Math.abs(sp - A.prevV) / Math.max(dt, 0.001); A.prevV = sp;
    const under = underDeck(LIS.x, LIS.z, LIS.y) || Math.abs(LIS.x - T.x) < 12;
    A.rumbleG.gain.setTargetAtTime(T.state === 'gone' ? 0 : 0.85 * clamp(sp / 18, 0.12, 1), t, 0.15);
    A.lp.frequency.setTargetAtTime(110 + sp * 12, t, 0.2);
    A.roarG.gain.setTargetAtTime(0.6 * Math.pow(clamp(sp / 24, 0, 1), 1.3), t, 0.15);
    A.m1.frequency.setTargetAtTime(48 + sp * 33, t, 0.1); A.m2.frequency.setTargetAtTime((48 + sp * 33) * 1.5, t, 0.1);
    A.motorG.gain.setTargetAtTime(T.state === 'dwell' ? 0.012 : clamp(0.012 + accel * 0.02, 0, 0.07), t, 0.2);
    const squeal = T.state === 'arrive' && T.z !== 0 && sp > 0.5 && sp < 14 ? 0.3 * clamp(1 - sp / 14, 0, 1) * 2 : 0;
    A.squealG.gain.setTargetAtTime(Math.min(0.32, squeal), t, 0.12);
    A.structG.gain.setTargetAtTime((under ? 0.7 : 0.25) * clamp(sp / 14, 0, 1), t, 0.15);
    A.em.set(T.x, y, zc, dt, MODE === 'menu' && MENU && MENU.indoor ? 0.4 : 1);
    // wheels over the rail joint nearest you
    if (sp > 1 && d < 130) {
      const prev = A.dist; A.dist += sp * dt;
      for (const o of AXLES) if (Math.floor((A.dist - o) / CAR_L) > Math.floor((prev - o) / CAR_L)) play('clack', { x: T.x, y: DECK_Y + 0.3, z: zc, vol: 0.8 * clamp(sp / 16, 0.3, 1.2), ref: 6, wet: 0.3, rate: 0.92 + Math.random() * 0.16, nodelay: true });
    }
  }
}
let _paT = -99;
function trainStopFX(T, what) {
  if (!AU.ready) return;
  const near = Math.hypot(LOC.platform.x - LIS.x, LOC.platform.z - LIS.z) < 70;
  for (const dz of [-CAR_L, CAR_L]) play('door_slide', { x: T.x, y: PLAT_Y + 1.2, z: T.z + dz, vol: 0.6, ref: 4, wet: 0.3, at: Math.random() * 0.15 });
  if (what === 'open') { play('brake_hiss', { x: T.x, y: DECK_Y + 0.5, z: T.z, vol: 0.55, ref: 5, wet: 0.35 }); if (near && REAL_T - _paT > 15) { _paT = REAL_T; setTimeout(() => speak('This is Calder.', { rate: 0.95, alt: true }), 900); } }
  else if (near && REAL_T - _paT > 6) { _paT = REAL_T; speak('Doors closing.', { rate: 1, alt: true }); }
}

/* ---------- footsteps of everyone nearby ---------- */
function npcSteps(dt) {
  if (!AU.bankReady || dt <= 0) return;
  let budget = 5;
  const doList = L => {
    for (const a of L) {
      if (!a || !a.pos || a.state === 'down') continue;
      const dx = a.pos.x - LIS.x, dz = a.pos.z - LIS.z;
      if (dx * dx + dz * dz > 225 || a._sx === undefined) { a._sx = a.pos.x; a._sz = a.pos.z; a._acc = 0; continue; }
      const mv = Math.hypot(a.pos.x - a._sx, a.pos.z - a._sz); a._sx = a.pos.x; a._sz = a.pos.z;
      if (mv > 2) continue;
      const spd = mv / dt; a._acc += mv;
      const stride = spd > 3 ? 1.3 : 0.8;
      if (a._acc > stride) { a._acc = 0; if (budget-- > 0) sfxStep(a.pos.x, a.pos.y || 0, a.pos.z, surfaceAt(a.pos.x, a.pos.z, a.pos.y || 0), spd > 3 ? 0.4 : 0.24, spd > 3); }
    }
  };
  doList(PEDS); doList(COPS); doList(ENEMIES);
  if (typeof NET !== 'undefined') { const rs = []; for (const R of NET.remotes.values()) if (!R.veh) rs.push(R); doList(rs); }
}

/* ---------- distant life ---------- */
function distantEvents(dt) {
  if (!AU.bankReady) return;
  AMB.evT -= dt; if (AMB.evT > 0) return;
  const night = DN.lamps > 0.5;
  AMB.evT = night ? 8 + Math.random() * 14 : 5 + Math.random() * 9;
  const ang = Math.random() * TAU, at = r => ({ x: LIS.x + Math.cos(ang) * r, z: LIS.z + Math.sin(ang) * r });
  const W = [['car', night ? 0.25 : 0.38], ['horn', 0.14], ['siren', night ? 0.18 : 0.09], ['dog', night ? 0.12 : 0.05], ['train', 0.06], ['shots', night ? 0.07 : 0], ['plane', night ? 0.02 : 0.06], ['rattle', WIND.gust > 0.45 ? 0.12 : 0]];
  let r = Math.random() * W.reduce((a, w) => a + w[1], 0), ev = 'car';
  for (const [k, w] of W) { r -= w; if (r <= 0) { ev = k; break; } }
  let p;
  switch (ev) {
    case 'car': p = at(22 + Math.random() * 40); play('carpass', { x: p.x, y: 0.8, z: p.z, vol: 0.55, ref: 6, wet: 0.2 }); break;
    case 'horn': p = at(60 + Math.random() * 160); play(Math.random() < 0.3 ? 'horn_big' : 'horn', { x: p.x, y: 1, z: p.z, vol: 0.8, ref: 6, wet: 0.55, slap: 0.3 }); if (Math.random() < 0.4) play('horn', { x: p.x, y: 1, z: p.z, vol: 0.7, ref: 6, wet: 0.55, at: 0.5 }); break;
    case 'siren': p = at(220 + Math.random() * 350); play('siren_far', { x: p.x, y: 2, z: p.z, vol: 1.3, ref: 25, wet: 0.7 }); break;
    case 'dog': p = at(80 + Math.random() * 180); play('dog', { x: p.x, y: 0.6, z: p.z, vol: 0.7, ref: 6, wet: 0.6 }); break;
    case 'train': p = at(380); play('train_horn', { x: p.x, y: 6, z: p.z, vol: 0.9, ref: 20, wet: 0.7 }); break;
    case 'shots': { p = at(280 + Math.random() * 360); const g = Math.random() < 0.5 ? 'gun_k9' : 'gun_draft', n = 2 + Math.floor(Math.random() * 4); let tt = 0; for (let k = 0; k < n; k++) { play(g, { x: p.x, y: 1.2, z: p.z, vol: 1.9, ref: 6, wet: 0.9, at: tt }); tt += 0.12 + Math.random() * 0.4; } break; }
    case 'plane': p = at(320); play('plane', { x: p.x, y: 420, z: p.z, vol: 1.2, ref: 80, wet: 0.1, occlude: false }); break;
    case 'rattle': p = at(8 + Math.random() * 12); play('rattle', { x: p.x, y: 2, z: p.z, vol: 0.35, ref: 2, wet: 0.2 }); break;
  }
}
function onLoudNoise(x, z, d) {
  if (!AU.bankReady || DN.lamps > 0.6) return;
  if (inPark(x, z) && Math.random() < 0.5 && REAL_T - (AMB.flapT || -99) > 20) { AMB.flapT = REAL_T; play('flap', { x: x + (Math.random() - 0.5) * 20, y: 2, z: z + (Math.random() - 0.5) * 20, vol: 0.5, ref: 4, wet: 0.2, at: 0.15 }); }
  if (Math.random() < 0.12) { const a = Math.random() * TAU; play('dog', { x: x + Math.cos(a) * 90, y: 0.6, z: z + Math.sin(a) * 90, vol: 0.7, ref: 6, wet: 0.6, at: 0.8 + Math.random() }); }
}

/* ---------- adaptive score ---------- */
function updateScoreDirector(dt) {
  if (!AU.ready || !S) return;
  if (MODE === 'title') { if (SCORE.on && !SCORE.theme) stopScore(); if (!SCORE.on) startScore(true); setScore(1, 0.7, 0, dt); return; }
  if (SCORE.on && SCORE.theme) stopScore();
  if (S.settings.score === false) { if (SCORE.on) stopScore(); return; }
  if (!SCORE.on) startScore(false);
  const wl = WANTED.level, fight = P.inFight || !!activeStandoff();
  const radio = P.car && RADIO.on && S.settings.radio > 0;
  const quiet = radio || MODE === 'rhythm' || MODE === 'bench' || (PHONE && PHONE.preview) || AU.indoor;
  const near = clamp(1 - MUSIC_NEAR * 2, 0, 1);
  let amb = MODE === 'cutscene' ? 0.9 : (DN.lamps > 0.5 ? 0.7 : 0.5) * near;
  let pulse = (wl >= 1 || fight) ? 0.8 : 0, full = (wl >= 3 || fight) ? 0.9 : 0;
  if (quiet) { amb = 0; pulse = radio ? 0 : pulse * 0.3; full = radio ? 0 : full * 0.3; }
  setScore(amb, pulse, full, dt);
}

/* ---------- car radio ---------- */
const RADIO = { on: false, player: null, st: -1 };
function radioOn() { RADIO.on = true; radioRefresh(true); }
function radioOff() { RADIO.on = false; radioRefresh(false); }
function cycleRadio() { S.settings.radio = (S.settings.radio + 1) % STATIONS.length; play('static', { vol: 0.35 }); radioRefresh(true); }
function radioRefresh(announce) {
  if (!AU.ready) return;
  const st = RADIO.on && P.car ? S.settings.radio : 0;
  if (st === RADIO.st) return;
  if (RADIO.player) { RADIO.player.stop(); RADIO.player = null; }
  RADIO.st = st;
  if (st > 0 && STATIONS[st]) {
    play('static', { vol: 0.25 });
    RADIO.player = new StationPlayer(st, AU.radio, 0.55, m => { if (MODE === 'play' && P.car && RADIO.st === st) toast(null, '♪ “' + m.title + '” · ' + m.artist, '#f4c64e'); });
    if (announce) toast(null, STATIONS[st].name, '#f4c64e');
  } else if (announce && RADIO.on) toast(null, 'Radio off', '#f4c64e');
}
function radioTick() { AU._edt = Math.min(0.05, (performance.now() - (AU._lastTick || performance.now())) / 1000); AU._lastTick = performance.now(); if (AU.ready && RADIO.on && S.settings.radio !== RADIO.st) radioRefresh(false); }

/* ---------- voices ---------- */
function onSay(who, text) {
  if (who === 'POLICE') { play('chatter', { vol: 0.18 }); speak(text.replace(/!/g, '.'), { pitch: 0.78, rate: 1.08 }); }
}

/* ---------- helpers for gameplay hooks ---------- */
function hitMaterial(x, y, z) {
  if (y < 0.22) return 'snow';
  for (const v of VEH) { if (v.dead) continue; const dx = x - v.pos.x, dz = z - v.pos.z; if (dx * dx + dz * dz < Math.pow(v.sp.len * 0.55 + 0.3, 2) && y < (v.sp.roofY || 1.6) + 0.4) return 'metal'; }
  if (y > DECK_Y0 - 0.4 && y < DECK_Y + 0.6) return 'metal';
  return 'brick';
}
// closest point of a bullet's path to the listener's head, if it passes close
function nearMiss(a, b, px, py, pz) {
  const dx = b.x - a.x, dy = b.y - a.y, dz = b.z - a.z, L2 = dx * dx + dy * dy + dz * dz || 1;
  const u = clamp(((px - a.x) * dx + (py - a.y) * dy + (pz - a.z) * dz) / L2, 0, 1);
  const cx = a.x + dx * u, cy = a.y + dy * u, cz = a.z + dz * u;
  const d = Math.hypot(px - cx, py - cy, pz - cz);
  return d < 2.6 && u > 0.05 && u < 0.98 ? { x: cx, y: cy, z: cz } : null;
}
