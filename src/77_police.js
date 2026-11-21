
/* =========================================================
   POLICE - Wanted level, cruisers, officers, arrests
   ========================================================= */
const WANTED = { level: 0, pts: 0, last: new THREE.Vector3(), seenT: 99, hostile: false, bustT: 0, decayT: 0, spawnT: 0, seeT: 0 };
const WANT_STEPS = [8, 25, 45, 70, 90];
const COPS = [];
function wantedLevelFor(pts) { let l = 0; for (const s of WANT_STEPS) if (pts >= s) l++; return l; }
function addWanted(pts, where, force) {
  if (MODE === 'title' || MODE === 'ending' || P.busting) return;
  const w = where || P.pos;
  if (!force && witnesses(w.x, w.z, 48) === 0 && pts < 20) return;
  const before = WANTED.level;
  WANTED.pts = Math.min(100, WANTED.pts + pts);
  WANTED.level = wantedLevelFor(WANTED.pts);
  WANTED.last.copy(P.pos); WANTED.seenT = 0;
  if (WANTED.level > before) { hudDirty = true; sfx.stinger('wanted'); if (before === 0) toast(null, 'Police are on the way', '#71c6ff'); }
}
function clearWanted() {
  WANTED.pts = 0; WANTED.level = 0; WANTED.hostile = false; WANTED.bustT = 0;
  for (const v of VEH) if (v.copAI) { v.siren = false; v.copAI.mode = 'leave'; }
  hudDirty = true;
}
function spawnCruiser() {
  for (let k = 0; k < 30; k++) {
    const axis = Math.random() < 0.5 ? 'x' : 'z';
    const line = pick(axis === 'x' ? GRID_Z : GRID_X);
    const dir = Math.random() < 0.5 ? 1 : -1;
    const along = rand(axis === 'x' ? -92 : -88, axis === 'x' ? 68 : 88);
    const p = laneXZ({ axis, line, dir }, along);
    const d = Math.hypot(p.x - P.pos.x, p.z - P.pos.z);
    if (d < 60 || d > 130) continue;
    if (VEH.some(o => Math.hypot(o.pos.x - p.x, o.pos.z - p.z) < 9)) continue;
    if (segClear(P.pos.x, P.pos.y + 1.5, P.pos.z, p.x, 1.4, p.z) && k < 22) continue;
    const yaw = axis === 'x' ? (dir > 0 ? Math.PI / 2 : -Math.PI / 2) : (dir > 0 ? 0 : Math.PI);
    const v = spawnVehicle('police', p.x, p.z, yaw, { color: 0x101216 });
    if (!v) return null;
    v.driver = 'police'; v.awake = true; v.siren = true;
    v.ai = { axis, line, dir, speed: 17, siren: true, turn: null, turnFor: null };
    v.copAI = { mode: 'respond', crew: 2, deployed: false, t: 0 };
    return v;
  }
  return null;
}
function greedyTurn(v, target) {
  const ai = v.ai;
  const along = ai.axis === 'x' ? v.pos.x : v.pos.z;
  const ni = nextCross(ai, along);
  if (ni === null) return;
  const dI = (ni - along) * ai.dir;
  if (ai.turnFor !== ni && dI < 30) {
    ai.turnFor = ni;
    const here = ai.axis === 'x' ? { x: ni, z: ai.line } : { x: ai.line, z: ni };
    const opts = [];
    const cs = ai.axis === 'x' ? GRID_X : GRID_Z;
    if (cs.some(c => (c - ni) * ai.dir > 1)) opts.push({ t: 's', d: ai.axis === 'x' ? Math.hypot(here.x + ai.dir * 40 - target.x, here.z - target.z) : Math.hypot(here.x - target.x, here.z + ai.dir * 40 - target.z) });
    const perp = ai.axis === 'x' ? GRID_Z : GRID_X;
    for (const d2 of [-1, 1]) if (perp.some(c => (c - ai.line) * d2 > 1)) opts.push({ t: d2, d: ai.axis === 'x' ? Math.hypot(here.x - target.x, here.z + d2 * 40 - target.z) : Math.hypot(here.x + d2 * 40 - target.x, here.z - target.z) });
    opts.sort((a, b) => a.d - b.d);
    ai.turn = opts.length ? opts[0].t : 's';
  }
}
// cruiser driving brain (called from the vehicle loop)
function copDrive(v, dt) {
  const C = v.copAI; C.t += dt;
  const tgt = P.car ? P.car.pos : (WANTED.seenT < 6 ? P.pos : WANTED.last);
  const d = Math.hypot(tgt.x - v.pos.x, tgt.z - v.pos.z);
  if (C.mode === 'leave' || WANTED.level === 0) {
    v.siren = false; v.ai.siren = false; v.ai.speed = 10;
    if (Math.hypot(v.pos.x - P.pos.x, v.pos.z - P.pos.z) > 110) { removeVehicle(v); return ZERO_IN; }
    return aiDrive(v, dt);
  }
  v.siren = true;
  if (C.deployed) {
    if (P.car && d > 25) {
      // call the officers back
      const mine = COPS.filter(c => c.car === v && c.state !== 'down');
      if (mine.every(c => Math.hypot(c.pos.x - v.pos.x, c.pos.z - v.pos.z) < 4) || C.t > 14) { for (const c of mine) removeCop(c); C.deployed = false; C.t = 0; }
    }
    return { thr: v.speed > 0.3 ? -1 : 0, steer: 0, hand: true };
  }
  if (P.car && d < 60) {
    // chase: aim a little ahead of the car and push hard
    const lead = P.car.vel;
    const px = tgt.x + lead.x * 0.6, pz = tgt.z + lead.y * 0.6;
    const desired = Math.atan2(px - v.pos.x, pz - v.pos.z);
    const steer = clamp(angDiff(v.yaw, desired) * 2.8, -1, 1);
    const ahead = Math.abs(angDiff(v.yaw, desired)) < 1.4;
    return { thr: ahead ? 1 : (v.speed > 4 ? -1 : 0.6), steer, hand: Math.abs(angDiff(v.yaw, desired)) > 1.0 && v.speed > 12 };
  }
  if (d < 40) {
    const desired = Math.atan2(tgt.x - v.pos.x, tgt.z - v.pos.z);
    const steer = clamp(angDiff(v.yaw, desired) * 2.4, -1, 1);
    if (d < 15 && !P.car) {
      if (Math.abs(v.speed) < 1.5 && !C.deployed && WANTED.level > 0) deployOfficers(v);
      return { thr: v.speed > 0.4 ? -1 : 0, steer, hand: v.speed > 6 };
    }
    return { thr: v.speed < 11 ? 1 : 0, steer, hand: false };
  }
  greedyTurn(v, tgt);
  v.ai.speed = 18;
  return aiDrive(v, dt);
}
function deployOfficers(v) {
  v.copAI.deployed = true; v.copAI.t = 0;
  const l = vSide(v);
  for (const s of [1, -1]) {
    const x = v.pos.x + l.x * s * (v.sp.wid / 2 + 0.7), z = v.pos.z + l.z * s * (v.sp.wid / 2 + 0.7);
    if (!isBlocked(x, z, 0.3)) spawnCop(x, z, v);
  }
  if (WANTED.level >= 3 || WANTED.hostile) say('POLICE', pick(['Drop it! Now!', 'Shots fired, engaging!', 'Get on the ground!']), '#71c6ff');
  else say('POLICE', pick(['Hands where I can see them!', "Stop right there!", 'Get on the ground!']), '#71c6ff');
}
function spawnCop(x, z, car) {
  const h = buildHuman({ jacket: 0x1b2436, jacket2: 0x232e44, pants: 0x161b26, skin: pick(PED_SKIN), hat: 0x10141e, cap: true, badge: true, shoes: 0x0c0c0c });
  scene.add(h.group);
  const gun = buildGun('k9', DEF_CFG()); gun.rotation.x = Math.PI / 2; gun.scale.setScalar(1.35); gun.position.set(0, -0.03, 0.02); h.AR.hand.add(gun);
  const plate = makeNameplate('POLICE', '#71c6ff'); plate.scale.multiplyScalar(0.8); h.group.add(plate);
  const c = { h, gun, plate, car, pos: new THREE.Vector3(x, 0, z), vel: new THREE.Vector3(), radius: 0.34, height: 1.75, onGround: true, airY: 0, yaw: car ? car.yaw : 0, state: 'chase', hp: 70, fireCd: rand(0.8, 1.4), canSee: null, losT: 0, path: null, pathT: 0, pathAge: 99, crouched: false, downT: 0, strafe: 1, strafeT: 1, knockT: 0, seeT: 0 };
  h.group.position.copy(c.pos);
  COPS.push(c);
  return c;
}
function removeCop(c) { scene.remove(c.h.group); const i = COPS.indexOf(c); if (i >= 0) COPS.splice(i, 1); }
function copHit(c, dmg, dir, byPlayer, melee) {
  if (c.state === 'down') return;
  c.hp -= dmg;
  if (!melee) bloodBurst(c.pos.x, c.pos.y + 1.2, c.pos.z, dir ? dir.x : 0, dir ? dir.z : 0, 10);
  if (byPlayer) { WANTED.hostile = true; addWanted(c.hp <= 0 ? 35 : 16, c.pos, true); addHeat(c.hp <= 0 ? 8 : 3); }
  if (c.hp <= 0) {
    c.state = 'down'; c.downT = 0; c.gun.visible = false;
    sfx.down(c.pos.x, c.pos.z);
    setTimeout(() => bloodPool(c.pos.x, c.pos.y, c.pos.z, rand(1.4, 2.1)), 700);
  }
}
function copSees(c) {
  const eye = c.pos.y + 1.55;
  if (Math.hypot(P.pos.x - c.pos.x, P.pos.z - c.pos.z) > 70 || P.dead) return null;
  if (P.car) { const v = P.car; return segClear(c.pos.x, eye, c.pos.z, v.pos.x, 1.0, v.pos.z) ? [v.pos.x, 1.0, v.pos.z] : null; }
  for (const t of playerTargets()) if (segClear(c.pos.x, eye, c.pos.z, t[0], t[1], t[2])) return t;
  return null;
}
const _cmz = new THREE.Vector3(), _chp = new THREE.Vector3();
function copShoot(c) {
  const tp = c.canSee; if (!tp) return;
  c.gun.userData.muzzle.getWorldPosition(_cmz);
  const d = Math.hypot(P.pos.x - c.pos.x, P.pos.z - c.pos.z);
  let p = 0.34 * clamp(1.3 - d / 35, 0.25, 1);
  if (P.crouch && !P.aiming) p *= 0.6; if (P.speed > 3.5) p *= 0.65; if (P.car) p *= 0.7;
  const hit = Math.random() < p;
  let tx = tp[0], ty = tp[1], tz = tp[2];
  if (!hit) { tx += rand(-1.2, 1.2); ty += rand(-0.5, 0.8); tz += rand(-1.2, 1.2); }
  const dx = tx - _cmz.x, dy = ty - _cmz.y, dz = tz - _cmz.z, L = Math.hypot(dx, dy, dz) || 1;
  _chp.set(_cmz.x + dx, _cmz.y + dy, _cmz.z + dz);
  addTracer(_cmz, _chp, [0.75, 0.85, 1]);
  PFX_ADD.spawn(_cmz.x, _cmz.y, _cmz.z, 0, 0, 0, 0.05, 0.4, 0.2, 1, 1, 0.75, 0.35);
  sfxShot('k9', _cmz.x, _cmz.y, _cmz.z, false, 0.8);
  alertPeds(c.pos.x, c.pos.z, 35);
  if (hit) { if (P.car) { P.car.hp -= 4; if (Math.random() < 0.35) hurtPlayer(5, c.pos); } else { hurtPlayer(8, c.pos); bloodBurst(P.pos.x, P.pos.y + 1.2, P.pos.z, dx, dz, 6); } }
}
function updatePolice(dt) {
  const W = WANTED;
  // seen?
  W.seeT -= dt;
  if (W.seeT <= 0) {
    W.seeT = 0.3;
    let seen = false;
    for (const c of COPS) if (c.state !== 'down') { c.canSee = copSees(c); if (c.canSee) seen = true; }
    for (const v of VEH) if (v.copAI && v.copAI.mode !== 'leave' && !v.copAI.deployed) { const d = Math.hypot(v.pos.x - P.pos.x, v.pos.z - P.pos.z); if (d < 55 && segClear(v.pos.x, 1.5, v.pos.z, P.pos.x, P.pos.y + 1.2, P.pos.z)) seen = true; }
    if (seen && W.level > 0) { W.last.copy(P.pos); W.seenT = 0; }
  }
  W.seenT += dt;
  // lose them: after 12s unseen the level steps down every 8s
  if (W.level > 0 && W.seenT > 12) {
    W.decayT += dt * gangLookoutBoost();
    if (W.decayT > 8) { W.decayT = 0; W.level--; W.pts = W.level ? WANT_STEPS[W.level - 1] : 0; hudDirty = true; if (W.level === 0) { clearWanted(); toast(null, 'You lost the police', '#86e3b0'); } }
  } else W.decayT = 0;
  // cruiser director
  W.spawnT -= dt;
  const want = [0, 1, 2, 2, 3, 4][W.level];
  const active = VEH.filter(v => v.copAI && v.copAI.mode !== 'leave').length;
  if (active < want && W.spawnT <= 0) { W.spawnT = 6; spawnCruiser(); }
  // officers on foot
  const hostile = W.hostile || W.level >= 3;
  let near = false;
  for (let i = COPS.length - 1; i >= 0; i--) {
    const c = COPS[i], H = c.h;
    if (c.state === 'down') {
      c.downT += dt; animHuman(H, dt, { down: Math.min(1, c.downT / 0.5) });
      if (c.downT > 35) removeCop(c);
      continue;
    }
    if (W.level === 0) { c.state = 'return'; }
    const dx = P.pos.x - c.pos.x, dz = P.pos.z - c.pos.z, d = Math.hypot(dx, dz);
    let goal = null, speed = 0, aim = 0;
    if (c.knockT > 0) { c.knockT -= dt; }
    else if (c.state === 'return') {
      if (c.car && !c.car.dead) { goal = { x: c.car.pos.x, z: c.car.pos.z }; speed = 3.5; if (Math.hypot(c.car.pos.x - c.pos.x, c.car.pos.z - c.pos.z) < 2.5) { removeCop(c); if (c.car.copAI) { c.car.copAI.deployed = false; c.car.copAI.mode = 'leave'; } continue; } }
      else { removeCop(c); continue; }
    } else if (P.car) {
      goal = navTarget(c, P.car.pos.x, P.car.pos.z, 0, dt); speed = 5; aim = hostile ? 1 : 0;
    } else if (hostile) {
      aim = c.canSee ? 1 : 0.5;
      if (!c.canSee || d > 14) { goal = navTarget(c, P.pos.x, P.pos.z, P.pos.y, dt); speed = 4.8; }
      else { c.strafeT -= dt; if (c.strafeT <= 0) { c.strafeT = rand(1, 2.2); c.strafe *= -1; } goal = { x: c.pos.x - dz / d * c.strafe * 3, z: c.pos.z + dx / d * c.strafe * 3 }; speed = 2.4; if (d < 7) goal = { x: c.pos.x - dx, z: c.pos.z - dz }; }
      c.fireCd -= dt;
      if (c.canSee && c.fireCd <= 0) { copShoot(c); c.fireCd = rand(0.55, 1.1); }
    } else {
      aim = 0.5;
      goal = d > 1.4 ? navTarget(c, P.pos.x, P.pos.z, P.pos.y, dt) : null; speed = d > 6 ? 5.4 : 3;
      if (d < 1.9 && !P.car && P.downT <= 0) near = true;
    }
    let vx = 0, vz = 0;
    if (goal) { const gx = goal.x - c.pos.x, gz = goal.z - c.pos.z, gl = Math.hypot(gx, gz); if (gl > 0.3) { vx = gx / gl * speed; vz = gz / gl * speed; } }
    const k = c.knockT > 0 ? 0 : 1 - Math.exp(-dt * 8);
    c.vel.x += (vx - c.vel.x) * k; c.vel.z += (vz - c.vel.z) * k;
    moveBody(c, c.vel.x * dt, c.vel.z * dt, dt);
    const sp = Math.hypot(c.vel.x, c.vel.z);
    const face = aim > 0.5 ? Math.atan2(dx, dz) : sp > 0.4 ? Math.atan2(c.vel.x, c.vel.z) : c.yaw;
    c.yaw += angDiff(c.yaw, face) * (1 - Math.exp(-dt * 9));
    H.group.position.copy(c.pos); H.group.rotation.y = c.yaw;
    animHuman(H, dt, { speed: sp, aim, pitch: 0, down: c.knockT > 0 ? Math.min(1, c.knockT) : 0 });
  }
  // the arrest
  if (near && !hostile && WANTED.level > 0) {
    W.bustT += dt * (P.speed > 4 ? 0.2 : 1);
    if (W.bustT > 1.6) busted();
  } else W.bustT = Math.max(0, W.bustT - dt * 1.5);
  updateSiren();
}
function busted() {
  if (P.busting) return;
  P.busting = true;
  WANTED.bustT = 0;
  sfx.stinger('busted');
  const heavy = S.heat >= 90;
  playCutscene(cutBusted(), () => {
    P.busting = false;
    clearWanted();
    for (const c of [...COPS]) removeCop(c);
    for (const v of [...VEH]) if (v.copAI) removeVehicle(v);
    if (heavy) { triggerEnding('locked'); return; }
    S.stats.busted++;
    const fine = Math.round(S.cash * 0.2); S.cash -= fine;
    for (const id in S.guns) S.guns[id].res = Math.floor(S.guns[id].res / 2);
    addHeat(-10);
    if (P.car) exitVehicle();
    placePlayer(LOC.station.x, 0, LOC.station.z + 1.5, 0);
    clearCrews();
    banner('Released', `Area 7 · fine ${fmtMoney(fine)}`);
    postFeed(pick(FEED_HANDLES), `${n_()} got picked up by Area 7 tonight 👀`);
    sendMsg('kiara', 'mama had to come get u from the station?? 😭');
    saveGame();
  });
}
