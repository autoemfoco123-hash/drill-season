
/* =========================================================
   THE HAWK (wind), warmth, light pool, FX
   ========================================================= */
const WIND = { gust: 0.1, target: 0.1, t: 6, phase: 'calm', dx: -0.96, dz: 0.28, base: Math.atan2(-0.96, 0.28) };
let hudDirty = true;
function updateWind(dt) {
  WIND.t -= dt;
  if (WIND.t <= 0) {
    if (WIND.phase === 'calm') { WIND.phase = 'gust'; WIND.target = rand(0.6, 1); WIND.t = rand(2.5, 5); }
    else { WIND.phase = 'calm'; WIND.target = rand(0.04, 0.18); WIND.t = rand(9, 20); }
  }
  WIND.gust += (WIND.target - WIND.gust) * (1 - Math.exp(-dt * (WIND.phase === 'gust' ? 1.3 : 0.5)));
  const a = WIND.base + Math.sin(REAL_T * 0.07) * 0.25;
  WIND.dx = Math.sin(a); WIND.dz = Math.cos(a);
}
function warmSources() {
  let warm = 0, fire = 0, label = null;
  const px = P.pos.x, pz = P.pos.z, py = P.pos.y;
  for (const B of BARRELS) { const d = Math.hypot(B.x - px, B.z - pz); if (d < B.r && py < 2) { const k = 1 - d / B.r; warm += 4 + 11 * k; fire = Math.max(fire, k); label = 'Fire barrel'; } }
  for (const V of VENTS) { const d = Math.hypot(V.x - px, V.z - pz); if (d < V.r && py < 1) { warm += 6; label = label || 'Steam vent'; } }
  for (const H of HEATERS) { const d = Math.hypot(H.x - px, H.z - pz); if (d < H.r && Math.abs(py - H.y) < 1.5) { warm += 10; label = 'Heat lamp'; } }
  return { warm, fire, label };
}
let frostWarnT = 0;
function updateVitals(dt, indoor) {
  const src = indoor ? { warm: 24, fire: 0, label: 'Inside' } : P.car ? { warm: 9, fire: 0, label: 'Car heater' } : warmSources();
  const exposure = indoor || P.car ? 0 : windExposure(P.pos.x, P.pos.z, P.pos.y);
  let drain = indoor || P.car ? 0 : (0.36 * (DN.night > 0.5 ? 1.15 : 0.8) + WIND.gust * 0.85 * exposure) * (P.speed > 3 ? 0.85 : 1);
  if (S.buffs.warmers > 0) { drain *= 0.5; S.buffs.warmers -= dt; }
  if (S.buffs.coffee > 0) { drain *= 0.6; S.buffs.coffee -= dt; }
  S.warmth = clamp(S.warmth - drain * dt + src.warm * dt, 0, 100);
  P.warmLabel = src.warm > 0 ? src.label : null;
  if (S.warmth <= 0 && !indoor) {
    S.health -= dt * 1.3; P.lastHurt = GAME_T - 3;
    frostWarnT -= dt; if (frostWarnT <= 0) { frostWarnT = 12; banner('Frostbite', 'Get to a fire barrel or inside'); }
    if (S.health <= 0) { S.health = 0; playerDowned(); }
  }
  if (S.warmth < 30) S.stats.coldTime += dt;
  GRADE.uniforms.uFrost.value = S.warmth < 40 ? (40 - S.warmth) / 40 : 0;
  return src.fire;
}
const LIGHT_INT = { street: 55, under: 34, plat: 30, fire: 30, porch: 16, shop: 26, heater: 7, alley: 24, park: 30 };
let lightT = 0;
function updateLightPool(dt) {
  lightT -= dt;
  if (lightT <= 0) {
    lightT = 0.25;
    const cx = camera.position.x, cz = camera.position.z;
    const fx = -Math.sin(camYaw), fz = -Math.cos(camYaw);
    const arr = [];
    for (const v of VEH) if (v.siren) { const d = Math.hypot(v.pos.x - cx, v.pos.z - cz); if (d < 70) arr.push({ L: { x: v.pos.x, y: (v.sp.roofY || 1.4) + 0.7, z: v.pos.z, police: v }, s: d - 40 }); }
    const lampsOn = DN.lamps > 0.05;
    for (const L of LAMPS) {
      if (!lampsOn && !L.fire && !L.heater) continue;
      const dx = L.x - cx, dz = L.z - cz, d = Math.hypot(dx, dz);
      if (d > 70) continue;
      const ahead = (dx * fx + dz * fz) / (d + 0.01);
      arr.push({ L, s: d - ahead * 10 });
    }
    arr.sort((a, b) => a.s - b.s);
    LIGHT_POOL.forEach((pl, i) => {
      const it = arr[i]; pl.userData.L = it ? it.L : null;
      if (!it) { pl.intensity = 0; return; }
      const L = it.L; pl.position.set(L.x, L.y - 0.3, L.z);
      const kind = L.police ? 'police' : L.fire ? 'fire' : L.under ? 'under' : L.plat ? 'plat' : L.porch ? 'porch' : L.shop ? 'shop' : L.heater ? 'heater' : L.alley ? 'alley' : L.park ? 'park' : 'street';
      pl.userData.kind = kind;
      pl.userData.base = kind === 'police' ? 60 : LIGHT_INT[kind];
      pl.color.set(kind === 'fire' || kind === 'heater' ? 0xff7a2a : kind === 'plat' ? 0xffe8c8 : kind === 'shop' ? 0xfff0d0 : 0xff9a3c);
      pl.distance = kind === 'fire' ? 12 : kind === 'police' ? 30 : 26;
    });
  }
  const flash = Math.floor(REAL_T * 7) % 2;
  for (const pl of LIGHT_POOL) {
    const L = pl.userData.L; if (!L) continue;
    const k = pl.userData.kind;
    if (k === 'police') { pl.color.setRGB(flash ? 1 : 0.1, 0.1, flash ? 0.1 : 1); pl.position.set(L.police.pos.x, (L.police.sp.roofY || 1.4) + 0.5, L.police.pos.z); pl.intensity = pl.userData.base * (0.4 + DN.night * 0.6); }
    else pl.intensity = pl.userData.base * (L.fire ? 0.8 + Math.random() * 0.35 : 1) * (k === 'fire' || k === 'heater' ? 1 : DN.lamps);
  }
  if (FLASH.userData.t > 0) { FLASH.userData.t -= dt; if (FLASH.userData.t <= 0) FLASH.intensity = 0; }
}
let breathT = 0;
function updateAmbientFX(dt) {
  const cx = camera.position.x, cz = camera.position.z;
  for (const B of BARRELS) {
    if (Math.hypot(B.x - cx, B.z - cz) > 70) continue;
    for (let k = 0; k < 2; k++) PFX_ADD.spawn(B.x + rand(-.25, .25), 0.95, B.z + rand(-.25, .25), rand(-.15, .15) + WIND.dx * 0.3, rand(0.8, 1.8), rand(-.15, .15) + WIND.dz * 0.3, rand(0.35, 0.6), 0.55, 0.12, 0.85, 1, rand(0.45, 0.6), 0.18, 0, 0.5);
    if (Math.random() < 0.25) PFX_ADD.spawn(B.x, 1.2, B.z, rand(-.5, .5) + WIND.dx, rand(1.5, 3), rand(-.5, .5) + WIND.dz, 1.6, 0.05, 0.02, 1, 1, 0.6, 0.2, 0.3, 0);
  }
  for (const V of VENTS) {
    if (Math.hypot(V.x - cx, V.z - cz) > 60) continue;
    if (Math.random() < 0.45) PFX_SMOKE.spawn(V.x + rand(-.3, .3), 0.1, V.z + rand(-.3, .3), WIND.dx * 0.6, rand(0.8, 1.4), WIND.dz * 0.6, rand(2, 3.2), 0.6, 2.6, 0.32, 0.9, 0.92, 0.96, 0.25, 0.15);
  }
  breathT -= dt;
  if (breathT <= 0) {
    breathT = 2.4;
    const puff = (h, yaw, y) => { const fx = Math.sin(yaw), fz = Math.cos(yaw); for (let k = 0; k < 3; k++) PFX_SMOKE.spawn(h.x + fx * 0.25, y, h.z + fz * 0.25, fx * 0.5 + rand(-.1, .1), rand(0.05, 0.2), fz * 0.5 + rand(-.1, .1), 1.2, 0.08, 0.45, 0.35, 0.95, 0.97, 1, 1.2, 0.05); };
    if (P.human.group.visible && !P.car && MODE === 'play') puff(P.pos, P.bodyYaw, P.pos.y + (P.crouch ? 1.0 : 1.62));
    for (const k in NPCS) { const n = NPCS[k]; if (n.h.group.visible && Math.hypot(n.h.group.position.x - cx, n.h.group.position.z - cz) < 30) puff(n.h.group.position, n.h.group.rotation.y, n.h.group.position.y + 1.6 * (n.scale || 1)); }
  }
}

/* =========================================================
   METERS
   ========================================================= */
function heatTier(h) { return h >= 90 ? 'Max' : h >= 75 ? 'Blazing' : h >= 50 ? 'Hot' : h >= 25 ? 'Warm' : 'Cool'; }
function buzzTier(b) { return b >= 80 ? 'Star' : b >= 60 ? 'Viral' : b >= 35 ? 'Buzzing' : b >= 15 ? 'Local' : 'Underground'; }
function addHeat(v) {
  if (!v) return;
  S.heat = clamp(S.heat + v, 0, 100);
  S.stats.heatPeak = Math.max(S.stats.heatPeak, S.heat);
  hudDirty = true;
  if (S.heat >= 100 && !P.lockSeq && MODE !== 'title') startLockup();
}
function addBuzz(v) { S.buzz = clamp(S.buzz + v, 0, 100); S.stats.buzzPeak = Math.max(S.stats.buzzPeak, S.buzz); hudDirty = true; }
function addCash(v) { S.cash += v; if (v > 0) S.stats.cashEarned += v; hudDirty = true; if (v > 0) sfx.cash(); }
let streamT = 30, clockAcc = 0;
let lastMin = -1;
function updateEconomy(dt) {
  streamT -= dt;
  if (streamT <= 0) {
    streamT = 30;
    const pay = Math.floor(S.buzz * 0.55);
    if (pay > 0) { S.cash += pay; S.stats.cashEarned += pay; P.streamFlash = { v: pay, t: REAL_T }; hudDirty = true; }
    if (S.buzz > 25 && S.playTime - (S.flags.lastTrackAt || 0) > 300) addBuzz(-1);
  }
  const m = worldMinutes();
  if (lastMin >= 0 && lastMin < 360 && m >= 360) { S.day++; banner('Day ' + S.day, 'Sun is coming up over the lake'); }
  if (lastMin >= 0 && lastMin < 990 && m >= 990) banner('Sundown', 'The Hawk gets colder at night');
  lastMin = m;
}
function clockStr() {
  const m = Math.floor(worldMinutes()); let h = Math.floor(m / 60) % 24; const mm = m % 60;
  const ap = h >= 12 ? 'PM' : 'AM'; h = h % 12 || 12;
  return `${h}:${String(mm).padStart(2, '0')} ${ap}`;
}
function tempF() { const m = worldMinutes(); return Math.round(10 + Math.sin((m / 1440 - 0.3) * TAU) * 6); }

/* =========================================================
   NPCs WITH HANDLES
   ========================================================= */
const NPCS = {};
function mkNpc(key, look, x, z, yaw) {
  const h = buildHuman(look);
  h.group.position.set(x, 0, z); h.group.rotation.y = yaw; scene.add(h.group);
  h.group.add(makeNameplate(CAST[key].name, CAST[key].color));
  const n = { key, h, home: { x, z, yaw }, scale: look.scale || 1, pos: new THREE.Vector3(x, 0, z), vel: new THREE.Vector3(), radius: 0.3, height: 1.4, onGround: true, airY: 0, lineT: 0 };
  NPCS[key] = n; return n;
}
function buildNPCs() {
  mkNpc('benny', { jacket: 0x3a2a1e, jacket2: 0x4a3626, pants: 0x2a2a2a, skin: 0x8a5a3a, hat: 0x222222, scale: 1.05 }, BENNY_POS.x, BENNY_POS.z, 0.3);
  mkNpc('coach', { jacket: 0x1d4a32, jacket2: 0x255c3e, pants: 0x1d2a22, skin: 0x5a3a26, hat: 0x1d4a32 }, COACH_POS.x, COACH_POS.z, 2.4);
  mkNpc('kiara', { jacket: 0x6a3a9a, jacket2: 0x7d4ab0, pants: 0x22243a, skin: 0x6b4630, hat: 0xf0e6ff, pom: 0xc79bff, pack: 0x2a6a8a, scale: 0.8 }, LOC.rec.x + 0.2, LOC.rec.z - 1.8, Math.PI / 2);
  mkNpc('reyes', { jacket: 0x2a2e36, jacket2: 0x30353e, pants: 0x1a1c22, skin: 0x9a6a48, hat: null, coat: true }, LOC.reyes.x, LOC.reyes.z, Math.PI);
  NPCS.kiara.h.group.visible = false; NPCS.reyes.h.group.visible = false;
  NPCS.kiara.trail = [];
}
const NPC_LINES = {
  benny: () => S.heat >= 60 ? ['Cars been parked outside all night. Chill.', "I can't have detectives on my steps, man."] : S.heat >= 30 ? ['People asking about you. Keep it in the music.', "Don't bring that energy downstairs."] : S.buzz >= 50 ? ["Numbers looking crazy. Don't fumble it.", 'Everybody wants a feature now.'] : ['Booth is warm. Come lay something.', 'I cooked a new 808. It slides crazy.', 'Shovel the steps on your way in.'],
  coach: () => S.heat >= 40 ? ['I hear your name in places I don\'t like.', "Walk away more. It's not weakness."] : (S.buzz >= 60 && S.heat <= 25) ? ['The showcase slot is yours if you want it.'] : (S.buzz >= 60) ? ['Get your Heat down and the showcase is yours.'] : ['Fire is going. Warm your hands.', 'Rec closes at ten. Your sister is still inside.', 'Kids been asking when you coming back to the court.'],
  kiara: () => P.inFight ? ['What is happening?!', 'Get down!'] : S.heat >= 50 ? ['Why are those guys staring?', 'Can we just go home?'] : ["It's brick out here.", 'Did you really make that song?', 'Walk faster, my toes are numb.', 'Mama made greens tonight.', 'Everybody at the rec knows your songs.'],
};
let subtitleTimer = null;
function say(who, text, color) {
  const el = $('subtitle');
  el.innerHTML = '';
  const w = document.createElement('span'); w.className = 'who'; w.style.color = color || '#ff9a3c'; w.textContent = who;
  const t = document.createElement('span'); t.textContent = text;
  el.append(w, t); el.classList.add('on');
  onSay(who, text);
  clearTimeout(subtitleTimer); subtitleTimer = setTimeout(() => el.classList.remove('on'), 3800);
}
function sayCast(key, text) { say(CAST[key].name, text, CAST[key].color); }
function updateNPCs(dt) {
  const B = NPCS.benny, C = NPCS.coach, K = NPCS.kiara, R = NPCS.reyes;
  for (const n of [B, C]) {
    const d = Math.hypot(n.h.group.position.x - P.pos.x, n.h.group.position.z - P.pos.z);
    n.lineT -= dt;
    if (d < 7 && n.lineT <= 0 && MODE === 'play') { n.lineT = 45; sayCast(n.key, pick(NPC_LINES[n.key]())); }
    if (d < 9) n.h.group.rotation.y += angDiff(n.h.group.rotation.y, Math.atan2(P.pos.x - n.h.group.position.x, P.pos.z - n.h.group.position.z)) * (1 - Math.exp(-dt * 3));
    n.waveT = Math.max(0, (n.waveT || 0) - dt);
    animHuman(n.h, dt, { speed: 0, mug: n.key === 'benny' && !n.waveT, wave: n.waveT > 0 });
  }
  // Reyes only appears for the meeting
  R.h.group.visible = jobAvailable('reyes');
  if (R.h.group.visible) { R.h.group.rotation.y += angDiff(R.h.group.rotation.y, Math.atan2(P.pos.x - R.h.group.position.x, P.pos.z - R.h.group.position.z)) * (1 - Math.exp(-dt * 2)); animHuman(R.h, dt, { speed: 0 }); }
  // sister: waits at the rec when she asked for a ride, follows you during the walk
  const escort = S.job && S.job.id === 'kiara';
  K.h.group.visible = escort || (S.flags.kiaraAsk && !escort);
  if (!escort) {
    if (K.h.group.visible) { K.pos.set(LOC.rec.x + 0.2, 0, LOC.rec.z - 1.8); K.h.group.position.copy(K.pos); animHuman(K.h, dt, { speed: 0, wave: Math.hypot(P.pos.x - K.pos.x, P.pos.z - K.pos.z) < 18 }); }
    return;
  }
  const tr = K.trail;
  const last = tr[tr.length - 1];
  if (!last || Math.hypot(last.x - P.pos.x, last.z - P.pos.z) > 0.6) tr.push({ x: P.pos.x, z: P.pos.z, y: P.pos.y });
  const dP = Math.hypot(P.pos.x - K.pos.x, P.pos.z - K.pos.z);
  while (tr.length > 1 && Math.hypot(tr[0].x - K.pos.x, tr[0].z - K.pos.z) < 0.8) tr.shift();
  if (dP > 45) { const t0 = tr[Math.max(0, tr.length - 6)]; K.pos.set(t0.x, t0.y, t0.z); tr.length = 0; }
  let vx = 0, vz = 0;
  if (dP > 2.4 && tr.length) {
    const t = tr[0]; const dx = t.x - K.pos.x, dz = t.z - K.pos.z, l = Math.hypot(dx, dz) || 1;
    const sp = dP > 9 ? 6.8 : 4.4;
    vx = dx / l * sp; vz = dz / l * sp;
  }
  const k = 1 - Math.exp(-dt * 8);
  K.vel.x += (vx - K.vel.x) * k; K.vel.z += (vz - K.vel.z) * k;
  moveBody(K, K.vel.x * dt, K.vel.z * dt, dt);
  const sp = Math.hypot(K.vel.x, K.vel.z);
  K.h.group.position.copy(K.pos);
  if (sp > 0.3) K.h.group.rotation.y += angDiff(K.h.group.rotation.y, Math.atan2(K.vel.x, K.vel.z)) * (1 - Math.exp(-dt * 10));
  animHuman(K.h, dt, { speed: sp, crouch: P.inFight && sp < 0.5 });
  K.lineT -= dt;
  if (K.lineT <= 0) { K.lineT = rand(16, 26); sayCast('kiara', pick(NPC_LINES.kiara())); }
}

/* =========================================================
   JOBS
   ========================================================= */
const vancePay = () => 1200 + (S.stats.disses || 0) * 300;
const JOBS = [
  { id: 'studio', title: 'Studio session', giver: 'benny', where: () => LOC.studio, desc: () => 'Booth is open at Basement 808. Pick a verse and lay it down.', chips: () => [['b', 'Buzz +'], ['c', 'Streams $']], avail: () => true, cd: 'studio' },
  { id: 'diss', title: 'Diss deal', giver: 'vance', where: () => LOC.studio, desc: () => `${CAST.vance.name} pays ${fmtMoney(vancePay())} for a diss aimed at ${CAST.saint.name}. Record it at Basement 808.`, chips: () => [['b', 'Buzz ++'], ['h', 'Heat ++'], ['c', fmtMoney(vancePay())]], avail: () => !!S.flags.vanceOffer, cd: 'studio' },
  { id: 'video', title: 'Video shoot', giver: 'benny', where: () => (S.job && S.job.id === 'video' && S.job.marks) ? S.job.marks[S.job.stage] : LOC.platform, desc: () => 'Shoot on the Calder L platform. Hit 3 marks. A train in the shot is a bonus. Costs $150.', chips: () => [['b', 'Buzz +'], ['w', 'Cold up there']], avail: () => S.stats.tracks >= 1, cd: 'video' },
  { id: 'kiara', title: 'Walk sis home', giver: 'kiara', where: () => (S.job && S.job.id === 'kiara') ? LOC.home : LOC.rec, desc: () => `${CAST.kiara.name} is at the rec center. Walk her home to Bishop St.`, chips: () => [['h', 'Heat −12']], avail: () => !!S.flags.kiaraAsk || (S.job && S.job.id === 'kiara') },
  { id: 'merch', title: 'Merch drop', giver: 'benny', where: () => (S.job && S.job.id === 'merch') ? MERCH_DROPS.find(d => !S.job.done.includes(d.id)) : LOC.studio, desc: () => 'Pick up hoodies at Basement 808. Drop them at 3 spots before the timer runs out.', chips: () => [['b', 'Buzz +'], ['c', '$360+']], avail: () => S.stats.tracks >= 1, cd: 'merch' },
  { id: 'laylow', title: 'Lay low', giver: 'reyes', where: () => LOC.home, desc: () => 'Go home and stay in for a while. Heat drops.', chips: () => [['h', 'Heat −20']], avail: () => true, cd: 'laylow' },
  { id: 'showcase', title: 'Rec showcase', giver: 'coach', where: () => LOC.rec, desc: () => `${CAST.coach.name} saved you a slot. Perform clean.`, chips: () => [['b', 'Ending: Way Out']], avail: () => S.buzz >= 60 && S.heat <= 25 && !S.flags.showcaseDone, lock: () => S.flags.showcaseDone ? 'You already did the showcase' : `Needs Buzz 60+ and Heat 25 or less (now ${Math.round(S.buzz)} / ${Math.round(S.heat)})` },
  { id: 'reyes', title: 'Meet the detective', giver: 'reyes', where: () => LOC.reyes, desc: () => `${CAST.reyes.name} wants to talk under the L at Low End Rd. Come alone.`, chips: () => [['h', 'Ending: Witness']], avail: () => S.heat >= 80 && !!S.flags.reyesOffer, lock: () => 'Shows up at Heat 80+' },
  { id: 'saint', title: 'The pond', giver: 'saint', where: () => LOC.park, desc: () => `${CAST.saint.name} is waiting at the Calder Park pond.`, chips: () => [['h', 'Ending: Crown']], avail: () => !!S.flags.saintChallenge && !S.flags.saintDown && !S.flags.saintChallengeLive, lock: () => 'Unlocks after two diss tracks' },
];
const MERCH_DROPS = [{ id: 'store', x: LOC.storeFront.x, z: LOC.storeFront.z, name: 'Mini Mart window' }, { id: 'pav', x: LOC.pavilion.x, z: LOC.pavilion.z, name: 'Park pavilion' }, { id: 'stairs', x: LOC.stairs.x, z: LOC.stairs.z, name: 'L stairs' }];
const jobById = id => JOBS.find(j => j.id === id);
function cdLeft(key) { return Math.max(0, (S.cd[key] || 0) - S.playTime); }
function jobAvailable(id) { const j = jobById(id); if (!j) return false; if (S.job && S.job.id === id) return true; return j.avail() && !(j.cd && cdLeft(j.cd) > 0); }
const BEACONS = {};
function buildBeacons() {
  const geo = new THREE.CylinderGeometry(0.7, 0.7, 70, 16, 1, true);
  const ringGeo = new THREE.PlaneGeometry(3.2, 3.2);
  for (const j of JOBS) {
    const col = new THREE.Color(CAST[j.giver].color);
    const pillar = new THREE.Mesh(geo, new THREE.MeshBasicMaterial({ map: TEX.beam, color: col, transparent: true, opacity: 0.5, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide, fog: false }));
    pillar.position.y = 35; pillar.renderOrder = 6;
    const ring = new THREE.Mesh(ringGeo, new THREE.MeshBasicMaterial({ map: TEX.ring, color: col, transparent: true, opacity: 0.85, blending: THREE.AdditiveBlending, depthWrite: false }));
    ring.rotation.x = -Math.PI / 2; ring.position.y = 0.06; ring.renderOrder = 6;
    const g = new THREE.Group(); g.add(pillar, ring); g.visible = false; scene.add(g);
    BEACONS[j.id] = { g, pillar, ring };
  }
}
function updateBeacons(dt) {
  for (const j of JOBS) {
    const b = BEACONS[j.id]; const on = jobAvailable(j.id) && MODE !== 'title';
    const w = on ? j.where() : null;
    if (!w) { b.g.visible = false; continue; }
    const tracked = S.tracked === j.id;
    const d = Math.hypot(w.x - P.pos.x, w.z - P.pos.z);
    b.g.visible = tracked || d < 45;
    b.g.position.set(w.x, w.y || 0, w.z);
    b.pillar.material.opacity = (tracked ? 0.55 : 0.2) * clamp(d / 12, 0.15, 1);
    b.ring.rotation.z += dt * 0.8; b.ring.scale.setScalar(1 + Math.sin(REAL_T * 3) * 0.06);
  }
}
function trackJob(id) { S.tracked = S.tracked === id ? null : id; hudDirty = true; }
function setCd(key, s) { S.cd[key] = S.playTime + s; }
function startJob(id, data) {
  S.job = Object.assign({ id, stage: 0, t: 0 }, data || {}); S.tracked = id; hudDirty = true;
}
function endJob() { S.job = null; hudDirty = true; }
function updateJobs(dt) {
  const J = S.job;
  if (!J) return;
  J.t += dt;
  if (J.id === 'kiara') {
    if (Math.hypot(P.pos.x - LOC.home.x, P.pos.z - LOC.home.z) < 6 && Math.hypot(NPCS.kiara.pos.x - LOC.home.x, NPCS.kiara.pos.z - LOC.home.z) < 7) {
      const dh = J.fight ? -5 : -12;
      addHeat(dh); S.stats.rides++; setCd('kiara', 240); S.flags.kiaraAsk = false;
      sayCast('kiara', J.fight ? 'You said no drama. I mean it.' : 'Thanks. Don\'t stay out late.');
      setTimeout(() => sendMsg('kiara', J.fight ? 'u said no drama. mama saw the news' : pick(['thanks for walking me 💜', 'mama says thank u', 'next time bring hot chocolate'])), 6000);
      banner('Home safe', `Heat ${dh}`);
      postFeed(pick(FEED_HANDLES), `${'@' + S.name} walking little sis home in this cold. respect`);
      NPCS.kiara.trail.length = 0;
      endJob();
    }
  } else if (J.id === 'merch') {
    const left = 200 - J.t;
    for (const d of MERCH_DROPS) {
      if (J.done.includes(d.id)) continue;
      if (Math.hypot(P.pos.x - d.x, P.pos.z - d.z) < 3.2 && Math.abs(P.pos.y - (d.y || 0)) < 2.5) {
        J.done.push(d.id); addCash(120); addBuzz(2); banner('Hoodies dropped', d.name + ' · +$120'); S.stats.merch++;
      }
    }
    if (J.done.length === 3) { addBuzz(4); banner('Merch sold out', 'Buzz +4'); postFeed(pick(FEED_HANDLES), `copped the ${'@' + S.name} hoodie 🔥 warmest thing I own`); netPost({ k: 'merch' }); setCd('merch', 200); endJob(); }
    else if (left <= 0) { banner('Merch drop over', `${J.done.length}/3 spots`); setCd('merch', 200); endJob(); }
  } else if (J.id === 'video') {
    const m = J.marks[J.stage];
    const d = Math.hypot(P.pos.x - m.x, P.pos.z - m.z);
    J.markT += dt;
    if (d < 1.3 && Math.abs(P.pos.y - PLAT_Y) < 0.5) {
      J.hold += dt;
      if (TRAINS.some(T => T.state !== 'gone' && Math.abs(T.z) < 70)) J.train = true;
      if (J.hold >= 2.5) { J.stage++; J.hold = 0; J.markT = 0; sfx.ui(); if (J.stage >= J.marks.length) finishVideo(true); }
    } else J.hold = Math.max(0, J.hold - dt);
    if (S.job && J.markT > 12) finishVideo(false);
  }
}
function finishVideo(ok) {
  const J = S.job;
  if (ok) {
    const b = 6 + (J.train ? 5 : 0);
    addBuzz(b); addHeat(2); S.stats.videos++;
    banner(J.train ? 'Train in the shot' : 'Video wrapped', `Buzz +${b}`);
    postFeed('@L_platform_lurker', J.train ? `${'@' + S.name} shot a video on the Calder platform and the train came through mid-verse 🚆` : `${'@' + S.name} filming on the Calder platform in -10 wind chill. dedication`);
    netPost({ k: 'video', train: !!J.train });
  } else { addBuzz(2); banner('Shoot wrapped', 'You missed a mark'); }
  setCd('video', 180); endJob();
  for (const r of VIDEO_RINGS) r.visible = false;
}
const VIDEO_RINGS = [];
function startVideo() {
  if (S.cash < 150) { toast('benny', 'Camera guy needs $150 up front.'); return; }
  addCash(-150);
  const zs = [-17, -12, 12, 17, -4, 3].sort(() => Math.random() - 0.5).slice(0, 3);
  const marks = zs.map(z => ({ x: 63.7, y: PLAT_Y, z }));
  startJob('video', { marks, hold: 0, markT: 0, train: false });
  if (!VIDEO_RINGS.length) for (let i = 0; i < 3; i++) { const r = new THREE.Mesh(new THREE.PlaneGeometry(2.4, 2.4), new THREE.MeshBasicMaterial({ map: TEX.ring, color: 0xff9a3c, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false })); r.rotation.x = -Math.PI / 2; scene.add(r); VIDEO_RINGS.push(r); }
  banner('Rolling', 'Hit your marks');
}
function updateVideoRings() {
  const J = S.job;
  VIDEO_RINGS.forEach((r, i) => {
    if (!J || J.id !== 'video') { r.visible = false; return; }
    const m = J.marks[i]; r.visible = i >= J.stage; r.position.set(m.x, m.y + 0.03, m.z);
    r.material.opacity = i === J.stage ? 0.9 : 0.25; r.rotation.z += 0.02;
  });
}
function layLow() {
  if (WANTED.level > 0) { $('mn-sub').textContent = 'Police are watching the block. Lose them first.'; return; }
  const fade = $('fade'); fade.style.opacity = 1;
  closeMenu(true);
  MODE = 'cut';
  setTimeout(() => {
    addHeat(-20); S.health = Math.min(100, S.health + 40); S.warmth = 100;
    if (S.buzz > 10) addBuzz(-2);
    S.stats.layLows++;
    clearCrews(); setCd('laylow', 150);
    if (S.job && S.job.id !== 'kiara') endJob();
    placePlayer(LOC.home.x + 1.6, 0, LOC.home.z, Math.PI * 0.5);
    fade.style.opacity = 0; MODE = 'play';
    banner('Stayed in', 'Heat −20 · ' + clockStr());
    if (S.heat >= 40) sendMsg('reyes', 'Good. Stay in more often.');
    saveGame(); lockPointer();
  }, 1600);
}
function startLockup() {
  if (P.lockSeq) return;
  P.lockSeq = true;
  triggerEnding('locked');
}

/* =========================================================
   MESSAGES + FEED (cast handles, block chatter)
   ========================================================= */
const FEED_HANDLES = ['@calderkid', '@lowendlo', '@bishopst.blog', '@frostedtips', '@southside_slush', '@ice.cold.ivy', '@rec_hoops23', '@L_platform_lurker', '@grandma.g', '@nocap.nadia', '@808.dre', '@sodiumglow', '@greystone.gabe', '@windchill.will', '@hawkwatcher', '@marrow.st.mike'];
function sendMsg(who, text, quiet) {
  S.threads[who].push({ t: S.playTime, text });
  if (S.threads[who].length > 40) S.threads[who].shift();
  if (!(MODE === 'phone' && PHONE.tab === 'msgs' && PHONE.thread === who)) S.unread[who] = (S.unread[who] || 0) + 1;
  if (!quiet || MODE === 'play') toast(who, text);
  hudDirty = true;
}
function postFeed(handle, text) {
  S.feed.unshift({ h: handle, text, at: Date.now(), likes: Math.floor(rand(3, 40) * (1 + S.buzz / 12)) });
  if (S.feed.length > 50) S.feed.pop();
}
const n_ = () => '@' + S.name;
function feedForTrack(tr) {
  const t = tr.title, g = tr.grade;
  const good = g === 'S' || g === 'A' || g === 'B';
  const pool = [];
  if (good) pool.push(`${t} by ${n_()} is hard 🥶`, `${n_()} snapped on ${t}`, `who is ${n_()}?? ${t} on repeat`, `${t} sounds like 4am on the Calder platform`);
  else pool.push(`${t} kinda mid ngl`, `${n_()} rushed ${t}. flow was off`, `${t} got potential tho`);
  if (tr.type === 'tribute') pool.push(`${n_()} made ${t} for the rec kids 🥹`, `${t} got me calling my sister`);
  if (tr.type === 'wayout') pool.push(`${n_()} going places. ${t} is a ticket out`, `${t} sounds like the Loop at night`);
  if (tr.type === 'diss') pool.push(`${n_()} really went at @saint.halo on ${t} 😳`, `${t} is crazy but Calder bout to be hot`, `@saint.halo not letting ${t} slide`);
  postFeed(pick(FEED_HANDLES), pick(pool));
  setTimeout(() => postFeed(pick(FEED_HANDLES), pick(pool)), 5000);
}
let ambientFeedT = 50;
function castTick() {
  const F = S.flags;
  if (!F.intro) {
    F.intro = true;
    sendMsg('benny', `yo ${n_()}. booth is warm. basement on Calder by the Mini Mart`);
    setTimeout(() => { F.kiaraAsk = true; sendMsg('kiara', 'can u get me from the rec later? its brick out 🥶'); }, 14000);
    postFeed('@hawkwatcher', 'wind chill -17 tonight. the Hawk is OUT');
  }
  if (!F.vanceOffer && S.buzz >= 15) { F.vanceOffer = true; sendMsg('vance', `Northline Records. Your numbers are moving. Put ${CAST.saint.name} in a track and I pay ${fmtMoney(vancePay())}.`); }
  if (!F.vance50 && S.buzz >= 50) { F.vance50 = true; sendMsg('vance', 'Northline wants a meeting. Keep the heat on.'); }
  if (!F.coach30 && S.buzz >= 30) { F.coach30 = true; sendMsg('coach', 'Kids at the rec been playing your songs on the speaker. Keep it clean and I can find you a stage.'); }
  if (S.buzz >= 60 && S.heat <= 25 && !F.showcaseOffer && !F.showcaseDone) { F.showcaseOffer = true; sendMsg('coach', 'Buzz is up, Heat is down. Showcase at the rec. That slot is yours, come see me.'); S.tracked = 'showcase'; }
  if (F.showcaseOffer && !F.showcaseDone && S.heat > 25 && !F.showcaseHold) { F.showcaseHold = true; sendMsg('coach', 'Showcase is on hold. Cool down first.'); }
  if (S.heat <= 25) F.showcaseHold = false;
  if (S.heat >= 50 && !F.coach50) { F.coach50 = true; sendMsg('coach', "I hear things. Don't make me hear your name the wrong way."); }
  if (S.heat >= 40 && !F.reyes40) { F.reyes40 = true; sendMsg('reyes', 'This is the detective for this area. Your name came across my desk. Keep it on the record, not the street.'); }
  if (S.heat >= 60 && !F.reyes60) { F.reyes60 = true; sendMsg('reyes', "Shots on Calder. Diss tracks. I'm not stupid. Go home and lay low."); S.tracked = S.tracked || 'laylow'; }
  if (S.heat >= 80 && !F.reyesOffer) { F.reyesOffer = true; sendMsg('reyes', 'I can help you or I can arrest you. Under the L at Low End Rd. Come alone.'); S.tracked = 'reyes'; }
  if (S.heat >= 95 && !F.reyes95) { F.reyes95 = true; sendMsg('reyes', 'Last chance. After this I come to you.'); }
  if (S.heat < 30) { F.reyes95 = false; }
  if (S.heat >= 60 && !F.benny60) { F.benny60 = true; sendMsg('benny', 'cars been parked outside the studio all night. u good?'); }
  if (S.heat >= 60 && !F.kiara60) { F.kiara60 = true; sendMsg('kiara', 'mama keeps asking where u at. she heard stuff'); }
  if (!F.kiaraAsk && F.intro && !(S.job && S.job.id === 'kiara') && cdLeft('kiara') <= 0 && S.stats.rides > 0) { F.kiaraAsk = true; sendMsg('kiara', pick(['come get me pls its brick', 'im at the rec. dont be late again', 'u picking me up or nah', 'coach closing up. come get me 🥶'])); }
  if (!F.draftHint && S.cash >= 1500 && S.buzz >= 30 && !S.guns.draft.owned) { F.draftHint = true; sendMsg('benny', 'a Graywater Draft showed up on the bench. its yours if u got the bread'); }
  if (!F.plowHint && S.cash >= 2500 && S.buzz >= 50 && !S.guns.plow.owned) { F.plowHint = true; sendMsg('benny', 'Ostrava Snowplow on the bench now. loud tho. real loud'); }
  if (S.stats.disses >= 2 && !F.saintChallenge && !F.saintDown) { F.saintChallenge = true; sendMsg('saint', 'You keep saying my name. Calder Park pond. Come say it to my face.'); }
  // saint challenge trigger
  if (jobAvailable('saint') && Math.hypot(P.pos.x - LOC.park.x, P.pos.z - LOC.park.z) < 26 && !F.saintChallengeLive && MODE === 'play') {
    F.saintChallengeLive = true;
    const c = spawnCrew({ x: LOC.park.x + 8, z: LOC.park.z - 6, n: 4, shooters: 2, saint: true, challenge: true });
    c.t = 0;
    setTimeout(() => { F.saintChallengeLive = false; }, 120000);
  }
  ambientFeedT -= 1;
  if (ambientFeedT <= 0) {
    ambientFeedT = rand(60, 100);
    const h = S.heat;
    const pool = h >= 80 ? [`detectives knocking on Bishop St asking about ${n_()}`, `${n_()} name all over the block rn`] : h >= 60 ? [`@saint.halo people asking about ${n_()} 👀`, `${n_()} better stay in`] : h >= 40 ? ['lotta noise on Calder tonight', 'cops posted by the L again'] : ['rec center got hot cocoa tonight', 'the Hawk is disrespectful tonight fr', 'L was 20 min late again', 'Mini Mart coffee hits different at -10', 'who left the snowman by the pond 😂'];
    postFeed(pick(FEED_HANDLES), pick(pool));
  }
}
function onWalkAway(c) {
  postFeed(pick(FEED_HANDLES), pick([`seen ${n_()} walk away from @halo crew. grown man move`, `${n_()} walked off. some calling it soft, I call it smart`]));
  if (!S.flags.walkMsg) { S.flags.walkMsg = true; setTimeout(() => sendMsg('coach', 'Heard you walked away tonight. That is the hardest thing to do.'), 7000); setTimeout(() => sendMsg('kiara', 'saw that post. proud of u for walking away'), 15000); }
  if (c.saint) setTimeout(() => sendMsg('saint', 'Keep walking. That is what you do.'), 9000);
  netPost({ k: 'walk' });
}
function onTrackReleased(tr) {
  S.flags.lastTrackAt = S.playTime;
  feedForTrack(tr);
  if (tr.type === 'diss') {
    setTimeout(() => sendMsg('saint', pick(['Heard the track. Cute.', 'You rap about me more than you rap about yourself.', 'Stay inside. The Hawk is not the only thing out here.', 'Keep my name out your mouth.'])), 8000);
    if (S.heat > 40) setTimeout(() => sendMsg('coach', "Heard that track. That's not you."), 16000);
  } else if (S.flags.vanceOffer && Math.random() < 0.5) setTimeout(() => sendMsg('vance', 'Nice song. Nice does not pay. You know what does.'), 9000);
  if (S.stats.tracks === 1) setTimeout(() => sendMsg('benny', "that one's crazy. also there's a workbench downstairs now, for your gear. Kestrel parts, all legal, all loud"), 5000);
}

/* =========================================================
   INTERACTIONS (E)
   ========================================================= */
function shootAround() {
  if (cdLeft('hoops') > 0) return;
  setCd('hoops', 45);
  const made = Math.round(clamp(2 + Math.random() * 7 + (S.buzz > 60 ? 1 : 0), 1, 10));
  P.poseT = 1.4; S.warmth = Math.min(100, S.warmth + 18);
  S.stats.hoops = (S.stats.hoops || 0) + 1;
  addBuzz(made >= 7 ? 3 : 1);
  banner(`${made}/10 at Garnet Courts`, made >= 7 ? 'Buzz +3 · warmed up' : 'Buzz +1 · warmed up');
  if (made >= 8) postFeed('@garnet.courts', `@${S.name} hit ${made}/10 at Garnet Courts in this cold 🥶🏀`);
  hudDirty = true;
}
function lakeView() {
  if (cdLeft('lake') > 0) return;
  setCd('lake', 120); addHeat(-4); P.poseT = 1.2;
  banner('Lake effect', 'Heat −4 · the city goes quiet out here');
}
const INTERACT = [
  { id: 'studio', x: LOC.studio.x, z: LOC.studio.z, r: 2.4, label: () => 'Enter Basement 808', act: () => openStudioMenu() },
  { id: 'store', x: LOC.store.x, z: LOC.store.z, r: 3.2, label: () => 'Enter Calder Mini Mart', act: () => openStoreMenu() },
  { id: 'gas', x: -23.5, z: -208.6, r: 3.0, label: () => 'Enter Ironside Fuel', act: () => openStoreMenu('gas') },
  { id: 'court', x: LOC.court.x, z: LOC.court.z, r: 8.5, label: () => cdLeft('hoops') > 0 ? `Catch your breath · ${Math.ceil(cdLeft('hoops'))}s` : 'Shoot around · warms you up', act: () => shootAround() },
  { id: 'lake', x: LAKE_X + 19, z: -38, r: 3.2, label: () => cdLeft('lake') > 0 ? 'The lake is quiet' : 'Look out over the lake · Heat −4', act: () => lakeView() },
  { id: 'rec', x: LOC.rec.x, z: LOC.rec.z, r: 2.6, label: () => 'Enter the rec center', act: () => openRecMenu() },
  { id: 'home', x: LOC.home.x, z: LOC.home.z, r: 2.4, label: () => 'Go inside (home)', act: () => openHomeMenu() },
  { id: 'video', x: LOC.platform.x, y: PLAT_Y, z: LOC.platform.z, r: 2.6, label: () => jobAvailable('video') && !S.job ? 'Start the video shoot · $150' : null, act: () => startVideo() },
  { id: 'reyes', x: LOC.reyes.x, z: LOC.reyes.z, r: 3, label: () => jobAvailable('reyes') ? `Talk to ${CAST.reyes.name}` : null, act: () => openReyesMenu() },
  { id: 'coach', x: COACH_POS.x, z: COACH_POS.z, r: 2.2, label: () => `Talk to ${CAST.coach.name}`, act: () => sayCast('coach', pick(NPC_LINES.coach())) },
  { id: 'benny', x: BENNY_POS.x, z: BENNY_POS.z, r: 2.2, label: () => `Talk to ${CAST.benny.name}`, act: () => sayCast('benny', pick(NPC_LINES.benny())) },
];
function nearestInteract() {
  let best = null, bd = Infinity;
  for (const it of INTERACT) {
    if (Math.abs((it.y || 0) - P.pos.y) > 1.6) continue;
    const d = Math.hypot(it.x - P.pos.x, it.z - P.pos.z);
    if (d < it.r && d < bd) { const l = it.label(); if (l) { bd = d; best = { it, l }; } }
  }
  return best;
}
function canGoInside() {
  return !CREWS.some(c => c.state === 'combat' && c.members.some(e => e.state !== 'down' && Math.hypot(e.pos.x - P.pos.x, e.pos.z - P.pos.z) < 35));
}
