/* =========================================================
   FISTS - 4 (or cycling past your guns) puts the gun away.
   Jab, cross, hook; hold aim to keep your guard up. Works on
   rivals, people on the street, police and other players.
   Some people on the street swing back.
   ========================================================= */
const FIST_STATS = { mag: 0, zoom: 1, aimSpeed: 1.8, auto: true, reload: 1, recoil: 0, spread: 0, aimSpread: 0, range: 1.8, pellets: 0, rpm: 0, heatPerShot: 0 };
const FIST_IDX = 9;
const PUNCHES = [
  { dmg: 9, cd: 0.3, side: -1, reach: 1.75 },
  { dmg: 12, cd: 0.36, side: 1, reach: 1.8 },
  { dmg: 19, cd: 0.62, side: -1, reach: 1.7, hook: true },
];
const BRAWL_LINES = ['Oh, you want smoke?', 'Bad idea.', 'Run it then.', "You're done.", 'Wrong one.', 'Say less.'];
const FIST_SVG = '<svg viewBox="0 0 64 32"><path d="M18 10c0-2 1.6-3.4 3.4-3.4 1 0 1.8.4 2.4 1 .6-1 1.6-1.6 2.8-1.6s2.2.6 2.8 1.6c.6-.8 1.6-1.4 2.6-1.4 1.8 0 3.2 1.4 3.2 3.2v.4c.4-.2.9-.3 1.4-.3 1.8 0 3.2 1.4 3.2 3.2V20c0 4.4-3.6 8-8 8h-6c-4.4 0-8-3.6-8-8v-3.4c-1.4-.6-2.4-2-2.4-3.6 0-1.2.6-2.3 1.4-3z" fill="currentColor"/></svg>';
function fistsOn() { return !!S.fists && !P.car; }
function setFists(on) {
  on = !!on;
  if (!!S.fists === on || P.downT > 0) return;
  S.fists = on; P.reloadT = 0; P.switchT = 0.22; P.combo = 0; P.punchT = 0;
  refreshPlayerGun(); sfx.swing(); hudDirty = true; NET.presT = 0;
}
function punch() {
  if (P.fireCd > 0 || P.switchT > 0 || P.car || P.downT > 0) return;
  if (REAL_T - (P.lastPunchReal || -9) > 0.9) P.combo = 0;
  const pu = PUNCHES[(P.combo || 0) % 3]; P.combo = ((P.combo || 0) + 1) % 3;
  P.fireCd = pu.cd; P.punchT = 0.0001; P.punchDur = Math.min(0.3, pu.cd * 0.85); P.punchSide = pu.side; P.punchHook = !!pu.hook;
  P.lastPunch = GAME_T; P.lastPunchReal = REAL_T;
  S.stats.punches = (S.stats.punches || 0) + 1;
  sfx.swing();
  if (fpActive()) FP.punch = { t: 0, side: pu.side, hook: !!pu.hook };
  const fx = -Math.sin(camYaw), fz = -Math.cos(camYaw);
  netPunch(fx, fz, pu);
  const tgt = meleeTarget(P.pos, fx, fz, pu.reach, true);
  if (tgt) P.pendingHit = { tgt, pu, t: 0.08, fx, fz };
}
// what is right in front of you, if anything
function meleeTarget(pos, fx, fz, reach, mine) {
  let best = null, bs = Infinity;
  const test = (kind, ref, p) => {
    const dx = p.x - pos.x, dz = p.z - pos.z, d = Math.hypot(dx, dz);
    if (d < 0.05 || d > reach + 0.35 || Math.abs(p.y - pos.y) > 1.3) return;
    const cos = (dx * fx + dz * fz) / d; if (cos < 0.5) return;
    const s = d - cos * 0.6; if (s < bs) { bs = s; best = { kind, ref }; }
  };
  for (const e of ENEMIES) if (e.state !== 'down') test('enemy', e, e.pos);
  for (const p of PEDS) if (p.state !== 'down') test('ped', p, p.pos);
  for (const c of COPS) if (c.state !== 'down') test('cop', c, c.pos);
  if (mine) for (const R of NET.remotes.values()) if (!R.veh && !(R.f & 4) && !(R.f & 16)) test('remote', R, R.pos);
  return best;
}
function landPunch(h) {
  const { tgt, pu, fx, fz } = h, r = tgt.ref, dir = { x: fx, z: fz };
  const p = tgt.kind === 'remote' ? r.pos : r.pos;
  if (Math.hypot(p.x - P.pos.x, p.z - P.pos.z) > pu.reach + 0.6) return; // they slipped it
  const y = p.y + 1.45;
  sfx.punch(p.x, y, p.z, pu.hook); showHitmarker(pu.hook);
  P.shake = Math.max(P.shake, pu.hook ? 0.2 : 0.1); rumble(pu.hook ? 0.6 : 0.3, 0.6, pu.hook ? 140 : 80);
  PFX_SMOKE.spawn(p.x - fx * 0.3, y, p.z - fz * 0.3, fx * 0.6, 0.3, fz * 0.6, 0.35, 0.12, 0.35, 0.25, 0.92, 0.95, 1, 0.6, 0.2);
  if (pu.hook) bloodBurst(p.x, y, p.z, fx, fz, 2);
  if (tgt.kind === 'enemy') {
    damageEnemy(r, pu.dmg, false, dir, true);
    r.vel.x += fx * (pu.hook ? 4 : 2.2); r.vel.z += fz * (pu.hook ? 4 : 2.2);
    if (pu.hook && r.state !== 'down' && Math.random() < 0.45) r.knockT = 0.9;
  } else if (tgt.kind === 'ped') pedPunched(r, pu.dmg, dir, true);
  else if (tgt.kind === 'cop') copHit(r, pu.dmg * 0.8, dir, true, true);
  // other players take the hit on their own screen
}
function pedPunched(p, dmg, dir, byPlayer) {
  if (p.state === 'down') return;
  p.hp -= dmg;
  p.vel.x += dir.x * 2.4; p.vel.z += dir.z * 2.4;
  if (p.hp <= 0) {
    p.state = 'down'; p.downT = 0; p.ko = true;
    sfx.down(p.pos.x, p.pos.z);
    if (byPlayer) { addWanted(14, p.pos); addHeat(2); S.stats.knockouts = (S.stats.knockouts || 0) + 1; if (Math.random() < 0.35) postFeed(pick(FEED_HANDLES), pick([`somebody just got knocked out on ${streetName(p.pos.x, p.pos.z)} 😭`, `fight on ${streetName(p.pos.x, p.pos.z)} rn`, 'whole block watching a fistfight in the snow'])); }
    return;
  }
  if (byPlayer) addWanted(5, p.pos);
  if (p.state !== 'brawl') {
    if (p.tough === undefined) p.tough = Math.random() < 0.4;
    if (p.tough) { p.state = 'brawl'; p.brawlT = 14; p.atkCd = 0.5; if (byPlayer) say('Passerby', pick(BRAWL_LINES), '#9fb0c0'); }
    else { p.state = 'flee'; p.fleeT = 9; p.from = { x: P.pos.x, z: P.pos.z }; }
  } else p.brawlT = Math.max(p.brawlT, 8);
  for (const o of PEDS) if (o !== p && o.state === 'walk' && Math.hypot(o.pos.x - p.pos.x, o.pos.z - p.pos.z) < 7) { o.state = 'flee'; o.fleeT = 6; o.from = { x: p.pos.x, z: p.pos.z }; }
}
// a pedestrian who swings back; returns where they want to go
function pedBrawl(p, dt, dP) {
  p.brawlT -= dt;
  if (p.brawlT <= 0 || dP > 18 || P.dead || P.car || MODE !== 'play') { p.state = 'flee'; p.fleeT = 0.01; p.from = { x: P.pos.x, z: P.pos.z }; return null; }
  p.yaw += angDiff(p.yaw, Math.atan2(P.pos.x - p.pos.x, P.pos.z - p.pos.z)) * (1 - Math.exp(-dt * 10));
  if (p.punchT > 0) { p.punchT += dt; if (p.punchT > 0.3) p.punchT = 0; }
  if (p.hitT > 0) {
    p.hitT -= dt;
    if (p.hitT <= 0 && dP < 1.45) takePunch(rand(5, 9), p.pos, null);
  }
  if (dP > 1.05) return { x: P.pos.x, z: P.pos.z, speed: 4.6 };
  p.atkCd -= dt;
  if (p.atkCd <= 0) { p.atkCd = rand(0.75, 1.2); p.punchT = 0.0001; p.punchSide = Math.random() < 0.5 ? -1 : 1; p.hitT = 0.13; sfx.swing(p.pos.x, p.pos.z); }
  return { x: p.pos.x, z: p.pos.z, speed: 0 };
}
// incoming punch on you, from anyone
function takePunch(dmg, from, R) {
  if (P.dead || P.car || MODE === 'ending') return 0;
  const guard = fistsOn() && P.aiming;
  const fx = -Math.sin(camYaw), fz = -Math.cos(camYaw), dx = from.x - P.pos.x, dz = from.z - P.pos.z, d = Math.hypot(dx, dz) || 1;
  const blocked = guard && (dx * fx + dz * fz) / d > 0.2;
  const amt = dmg * (blocked ? 0.25 : 1);
  sfx.punch(P.pos.x, P.pos.y + 1.5, P.pos.z, !blocked && dmg > 14, blocked);
  P.shake = Math.max(P.shake, blocked ? 0.08 : 0.3); rumble(blocked ? 0.2 : 0.7, 0.5, blocked ? 60 : 150);
  if (blocked) P.stamina = Math.max(0, P.stamina - 8);
  const before = S.health;
  hurtPlayer(amt, from, true);
  if (R && before > 0 && S.health <= 0) { NET.downSeq++; NET.down = { by: R.peer, i: NET.downSeq }; NET.presT = 0; setTimeout(() => toast(null, `@${R.name} knocked you out`, '#ff4b3a'), 300); }
  return amt;
}
function tickFists(dt) {
  if (P.punchT > 0) { P.punchT += dt; if (P.punchT > (P.punchDur || 0.3)) P.punchT = 0; }
  if (P.pendingHit) { P.pendingHit.t -= dt; if (P.pendingHit.t <= 0) { const h = P.pendingHit; P.pendingHit = null; landPunch(h); } }
}
/* ---- network: a punch rides along with the shots ---- */
function netPunch(fx, fz, pu) {
  if (!NET.room) return;
  NET.shotSeq++;
  NET.shots.push([NET.shotSeq, Math.round(P.pos.x * 100) / 100, Math.round((P.pos.y + 1.4) * 100) / 100, Math.round(P.pos.z * 100) / 100, Math.round(fx * 1000) / 1000, 0, Math.round(fz * 1000) / 1000, FIST_IDX, pu.dmg, pu.side, pu.hook ? 1 : 0]);
  if (NET.shots.length > 6) NET.shots.shift();
  NET.presT = 0;
}
function remotePunch(R, s) {
  R.punchT = 0.0001; R.punchSide = +s[9] < 0 ? -1 : 1; R.punchHook = !!+s[10];
  const ox = +s[1], oz = +s[3]; if (!isFinite(ox + oz)) return;
  play('swing', { x: ox, y: +s[2], z: oz, vol: 0.4, ref: 1.5 });
  if (MODE !== 'play' && MODE !== 'phone') return;
  const dx = P.pos.x - ox, dz = P.pos.z - oz, d = Math.hypot(dx, dz);
  if (d > 2.2 || d < 0.05 || Math.abs(P.pos.y + 1.4 - +s[2]) > 1.4) return;
  if (((dx * +s[4] + dz * +s[6]) / d) < 0.45) return;
  if (sameGang(R)) return; // no fighting your own
  setTimeout(() => { if (Math.hypot(P.pos.x - R.pos.x, P.pos.z - R.pos.z) < 2.4) { P.lastAttacker = R; takePunch(clamp(+s[8] || 0, 0, 20) * 0.8, R.pos, R); } }, 80);
}
/* ---- first person: both fists in view ---- */
function buildFistVM() {
  if (FP.fv) camera.remove(FP.fv);
  const o = skinHumanOpts(S.skin), g = new THREE.Group();
  const sleeve = _vmMat(o.top === 'varsity' ? o.jacket2 : o.jacket), cuff = _vmMat(o.jacket2), skin = _vmMat(o.skin);
  const mk = s => {
    const a = new THREE.Group(); g.add(a);
    const part = (geo, m, sx, sy, sz, x, y, z) => { const me = new THREE.Mesh(geo, m); me.scale.set(sx, sy, sz); me.position.set(x, y, z); a.add(me); return me; };
    part(HG.hand, skin, 0.95, 0.82, 1.05, 0, 0, 0);
    for (let k = 0; k < 4; k++) part(HG.hand, skin, 0.24, 0.24, 0.26, (k - 1.5) * 0.021 * -s, 0.022, -0.042);
    part(HG.hand, skin, 0.3, 0.26, 0.4, s * 0.042, -0.012, -0.022);
    limb(a, VM_CYL, cuff, [0, -0.012, 0.045], [0, -0.02, 0.08], 0.04);
    limb(a, VM_CYL, sleeve, [0, -0.02, 0.075], [s * 0.07, -0.2, 0.42], 0.046);
    if (o.watch && s < 0) { const w = new THREE.Mesh(HG.watch, _vmMat(0xd4a640)); w.scale.setScalar(0.7); w.position.set(0, -0.02, 0.06); a.add(w); }
    return a;
  };
  FP.fl = mk(-1); FP.fr = mk(1);
  g.traverse(m => { if (m.isMesh) { m.castShadow = false; m.frustumCulled = false; } });
  camera.add(g); FP.fv = g; FP.fvKey = skinKey(cleanSkin(S.skin));
}
function updateFistVM(dt, a) {
  if (!FP.fv || FP.fvKey !== skinKey(cleanSkin(S.skin))) buildFistVM();
  FP.fv.visible = !(P.handsUp > 0);
  const bob = Math.min(1, P.speed / 5), bx = Math.cos(FP.bob) * 0.012 * bob, by = -Math.abs(Math.sin(FP.bob)) * 0.016 * bob;
  const pu = FP.punch; if (pu) { pu.t += dt; if (pu.t > 0.3) FP.punch = null; }
  for (const [A, s] of [[FP.fl, -1], [FP.fr, 1]]) {
    let x = s * lerp(0.15, 0.095, a), y = lerp(-0.165, -0.11, a) + by, z = lerp(-0.36, -0.32, a), rz = s * lerp(-0.1, -0.35, a), rx = lerp(-0.15, 0.05, a);
    if (pu && pu.side === s) {
      const e = Math.sin(clamp(pu.t / 0.3, 0, 1) * Math.PI);
      if (pu.hook) { x = lerp(x, -s * 0.02, e); z -= 0.16 * e; y += 0.05 * e; rz += -s * 0.9 * e; }
      else { x = lerp(x, s * 0.03, e); z -= 0.26 * e; y += 0.06 * e; }
    }
    A.position.set(x + bx, y, z); A.rotation.set(rx, 0, rz);
  }
  FP.fl.visible = !((P.flipK || 0) > 0.3);
}
