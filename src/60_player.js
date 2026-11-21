
/* =========================================================
   PLAYER - controller, camera, weapons
   ========================================================= */
const keys = {};
const mouse = { left: false, right: false };
const TOUCH = { on: false, joy: { active: false, x: 0, y: 0, id: null }, lookId: null, aim: false, fire: false, sprint: false, useHeld: false };
const P = {
  pos: new THREE.Vector3(-6, 0, -42), vel: new THREE.Vector3(), radius: 0.36, height: 1.75, onGround: true, airY: 0,
  crouch: false, aiming: false, aimT: 0, sprinting: false, stamina: 100, staminaLock: false, staDelay: 0,
  bodyYaw: Math.PI, speed: 0, fireCd: 0, reloadT: 0, reloadFor: null, switchT: 0, bloom: 0, lastShot: -99, lastHurt: -99, lastLoud: -99,
  downT: 0, healT: 0, stepAcc: 0, pivotY: 1.6, shake: 0, recoil: 0, aimHold: 0,
  human: null, gun: null, gunKey: '', stats: null, triggerLatch: false,
};
let camYaw = Math.PI, camPitch = -0.12, camDist = 3.9;
function buildPlayer() { applyPlayerSkin(); }
// (re)build the player's body from S.skin, keeping where it stands
function applyPlayerSkin() {
  const old = P.human;
  S.skin = cleanSkin(S.skin);
  P.human = buildHuman(skinHumanOpts(S.skin));
  if (old) { P.human.group.position.copy(old.group.position); P.human.group.rotation.y = old.group.rotation.y; P.human.group.visible = old.group.visible; scene.remove(old.group); }
  scene.add(P.human.group);
  P.gunKey = ''; P.gun = null; refreshPlayerGun();
  NET.skEnc = encodeSkin(S.skin);
}
function refreshPlayerGun() {
  const cfg = S.guns[S.cur].cfg;
  const key = S.cur + JSON.stringify(cfg);
  P.stats = gunStats(S.cur);
  if (key === P.gunKey && P.gun) return;
  if (P.gun && P.gun.parent) P.gun.parent.remove(P.gun);
  P.gun = buildGun(S.cur, cfg);
  P.gun.rotation.x = Math.PI / 2; P.gun.position.set(0, -0.03, 0.02); P.gun.scale.setScalar(1.35);
  P.human.AR.hand.add(P.gun);
  P.gunKey = key;
}
function playerTargets() {
  const x = P.pos.x, z = P.pos.z, y = P.pos.y;
  if (P.crouch && !P.aiming) return [[x, y + 0.98, z], [x, y + 0.62, z]];
  if (P.crouch) return [[x, y + 1.3, z], [x, y + 0.95, z]];
  return [[x, y + 1.62, z], [x, y + 1.22, z]];
}

/* ---- movement ---- */
const _fwd = new THREE.Vector3(), _tmpV = new THREE.Vector3(), _tmpV2 = new THREE.Vector3();
function updatePlayer(dt) {
  P.handsUp = Math.max(0, (P.handsUp || 0) - dt); P.pose = Math.max(0, (P.pose || 0) - dt);
  if (P.car) {
    const v = P.car;
    P.pos.set(v.pos.x, 0, v.pos.z); P.vel.set(v.vel.x, 0, v.vel.y); P.speed = Math.abs(v.speed); P.bodyYaw = v.yaw;
    P.human.group.visible = false; P.aimT = 0; P.aiming = false; P.sprinting = false;
    P.fireCd -= dt; P.switchT -= dt;
    S.stats.drive = (S.stats.drive || 0) + P.speed * dt; S.stats.dist += P.speed * dt;
    if (GAME_T - P.lastHurt > 8 && S.health < 60) S.health = Math.min(60, S.health + dt * 1.5);
    return;
  }
  let ix = 0, iz = 0;
  if (keys.KeyW || keys.ArrowUp) iz += 1; if (keys.KeyS || keys.ArrowDown) iz -= 1;
  if (keys.KeyA || keys.ArrowLeft) ix -= 1; if (keys.KeyD || keys.ArrowRight) ix += 1;
  if (TOUCH.joy.active) { ix += TOUCH.joy.x; iz += TOUCH.joy.y; }
  const il = Math.hypot(ix, iz); if (il > 1) { ix /= il; iz /= il; }
  const down = P.downT > 0;
  if (down) { ix = iz = 0; P.downT -= dt; }
  const busy = MODE !== 'play';
  if (busy) { ix = iz = 0; }
  const wantAim = !busy && !down && (mouse.right || TOUCH.aim);
  P.aiming = wantAim;
  P.aimT = clamp(P.aimT + (wantAim ? 1 : -1) * dt * 7 * (P.stats ? P.stats.aimSpeed : 1), 0, 1);
  const moving = Math.hypot(ix, iz) > 0.1;
  const wantSprint = !busy && (keys.ShiftLeft || keys.ShiftRight || TOUCH.sprint || (TOUCH.joy.active && Math.hypot(TOUCH.joy.x, TOUCH.joy.y) > 0.96)) && iz > 0.3 && !P.aiming && moving;
  if (wantSprint && P.crouch) P.crouch = false;
  // stamina (cold slows regen)
  const coldK = S.warmth < 35 ? 0.4 : 1;
  if (wantSprint && !P.staminaLock && P.stamina > 0) { P.sprinting = true; P.stamina -= dt * 17; P.staDelay = 0.8; if (P.stamina <= 0) { P.stamina = 0; P.staminaLock = true; } }
  else { P.sprinting = false; P.staDelay -= dt; if (P.staDelay <= 0) P.stamina = Math.min(100, P.stamina + dt * 15 * coldK); if (P.stamina > 25) P.staminaLock = false; }
  let speed = P.sprinting ? 7.3 : P.crouch ? 2.1 : P.aiming ? 2.7 : 4.3;
  if (S.health < 30) speed *= 0.85;
  const fx = -Math.sin(camYaw), fz = -Math.cos(camYaw), rx = Math.cos(camYaw), rz = -Math.sin(camYaw);
  let mx = fx * iz + rx * ix, mz = fz * iz + rz * ix;
  const ml = Math.hypot(mx, mz); if (ml > 1e-3) { mx /= ml; mz /= ml; }
  const mag = Math.min(1, Math.hypot(ix, iz));
  const ice = onIce(P.pos.x, P.pos.z, P.pos.y);
  const acc = P.onGround ? (ice ? 1.8 : 13) : 2.5;
  const k = 1 - Math.exp(-acc * dt);
  P.vel.x += (mx * speed * mag - P.vel.x) * k;
  P.vel.z += (mz * speed * mag - P.vel.z) * k;
  // the Hawk pushes you around outdoors
  const sh = windExposure(P.pos.x, P.pos.z, P.pos.y);
  const push = WIND.gust * 1.1 * sh;
  const { landed } = moveBody(P, (P.vel.x + WIND.dx * push) * dt, (P.vel.z + WIND.dz * push) * dt, dt);
  if ((keys.Space || TOUCH.jump) && P.onGround && !busy && !down && !P.crouch) { P.vel.y = 6.4; P.onGround = false; P.airY = P.pos.y; TOUCH.jump = false; }
  if (landed > 4.2) { const dmg = (landed - 4.2) * 8; hurtPlayer(dmg, null, true); sfx.thud(); P.shake = 0.6; }
  P.speed = Math.hypot(P.vel.x, P.vel.z);
  if (P.onGround && P.speed > 0.6) {
    P.stepAcc += P.speed * dt;
    const stride = P.sprinting ? 1.05 : 0.8;
    if (P.stepAcc > stride) { P.stepAcc = 0; sfx.step(true, P.crouch ? 0.05 : 0.11); }
    S.stats.dist += P.speed * dt;
  }
  // face direction
  const faceAim = P.aimT > 0.2 || GAME_T - P.lastShot < 0.6 || fpOn();
  let targetYaw = P.bodyYaw;
  if (faceAim) targetYaw = camYaw + Math.PI;
  else if (P.speed > 0.4) targetYaw = Math.atan2(P.vel.x, P.vel.z);
  P.bodyYaw += angDiff(P.bodyYaw, targetYaw) * (1 - Math.exp(-dt * (faceAim ? 22 : 10)));
  const H = P.human;
  H.group.position.copy(P.pos);
  H.group.rotation.y = P.bodyYaw;
  animHuman(H, dt, { speed: P.speed, crouch: P.crouch && !P.aiming ? 1 : (P.crouch ? 0.6 : 0), aim: Math.max(P.aimT, GAME_T - P.lastShot < 0.5 ? 1 : 0), pitch: camPitch, down: down ? clamp(P.downT, 0, 1) : 0, twoHand: S.cur !== 'k9', shiver: S.warmth < 30 ? 1 : 0, hands: P.handsUp > 0, pose: P.pose > 0 || (PHONE.selfie && MODE === 'phone') , wave: (P.waveT || 0) > 0 && !P.aiming, pose: (P.poseT || 0) > 0 });
  P.waveT = Math.max(0, (P.waveT || 0) - dt); P.poseT = Math.max(0, (P.poseT || 0) - dt);
  if (P.gun) P.gun.visible = !(P.handsUp > 0) && !(PHONE.selfie && MODE === 'phone');
  // timers
  P.fireCd -= dt; P.switchT -= dt; P.bloom = Math.max(0, P.bloom - dt * 2.2);
  if (P.reloadT > 0) { P.reloadT -= dt; if (P.reloadT <= 0) finishReload(); }
  if (P.healT > 0) { P.healT -= dt; S.health = Math.min(100, S.health + dt * 26); }
  // firing
  const trig = !busy && !down && (mouse.left || TOUCH.fire);
  if (trig) {
    if (P.stats.auto || !P.triggerLatch) tryFire();
    P.triggerLatch = true;
  } else P.triggerLatch = false;
  // regen when untouched and warm
  if (GAME_T - P.lastHurt > 8 && S.health < 60 && S.warmth > 20) S.health = Math.min(60, S.health + dt * 1.5);
}
function windExposure(x, z, y) {
  if (underDeck(x, z, y)) return 0.35;
  if (y > 6) return 1.35;
  return 1;
}

/* ---- camera ---- */
let FOV_T = 62;
function updateCarCamera(dt) {
  if (fpOn()) { updateCarFP(dt); return; }
  if (FP.cockpit) FP.cockpit.visible = false;
  const v = P.car, sp = Math.abs(v.speed);
  if (REAL_T - (P.lastLook || 0) > 1.4) { camYaw += angDiff(camYaw, v.yaw + Math.PI) * (1 - Math.exp(-dt * 2.6)); camPitch += (-0.16 - camPitch) * (1 - Math.exp(-dt * 2)); }
  P.shake = Math.max(0, P.shake - dt * 1.8);
  const dist = 6.4 + Math.min(sp, 30) * 0.06 + v.sp.len * 0.25, up = 1.5 + v.sp.len * 0.12;
  const cp = Math.cos(camPitch);
  _fwd.set(-Math.sin(camYaw) * cp, Math.sin(camPitch), -Math.cos(camYaw) * cp);
  const px = v.pos.x, py = 1.3 + (v.sp.roofY || 1.4) * 0.4, pz = v.pos.z;
  let d = dist;
  const tb = raycastWorld(px, py + up * 0.4, pz, -_fwd.x, -_fwd.y, -_fwd.z, dist + 0.3);
  if (tb !== Infinity) d = Math.max(1.5, tb - 0.3);
  camDist += (d - camDist) * (d < camDist ? 1 : 1 - Math.exp(-dt * 4));
  const sh = P.shake * 0.08;
  camera.position.set(px - _fwd.x * camDist + (Math.random() - 0.5) * sh, py + up * 0.4 - _fwd.y * camDist + 0.6, pz - _fwd.z * camDist + (Math.random() - 0.5) * sh);
  camera.lookAt(px, py + 0.6, pz);
  const nf = 60 + clamp(sp, 0, 34) * 0.45;
  camera.fov += (nf - camera.fov) * (1 - Math.exp(-dt * 3)); camera.updateProjectionMatrix(); setParticleScale();
  camera.updateMatrixWorld();
}
function updateSelfieCamera(dt) {
  const f = { x: Math.sin(P.bodyYaw), z: Math.cos(P.bodyYaw) }, l = { x: Math.cos(P.bodyYaw), z: -Math.sin(P.bodyYaw) };
  const tx = P.pos.x + f.x * 1.25 + l.x * 0.25, tz = P.pos.z + f.z * 1.25 + l.z * 0.25;
  camera.position.set(tx, P.pos.y + 1.72, tz);
  camera.lookAt(P.pos.x - l.x * 0.15, P.pos.y + 1.55, P.pos.z - l.z * 0.15);
  if (Math.abs(camera.fov - 58) > 0.1) { camera.fov = 58; camera.updateProjectionMatrix(); setParticleScale(); }
  P.human.group.visible = true;
  camera.updateMatrixWorld();
}
function updateCamera(dt) {
  if (P.car) { updateCarCamera(dt); return; }
  if (PHONE.selfie && MODE === 'phone') { fpHide(); updateSelfieCamera(dt); return; }
  if (fpActive()) { updateFPCamera(dt); return; }
  fpHide();
  const st = P.stats || gunStats(S.cur);
  const crouchH = P.crouch ? (P.aiming ? 1.32 : 1.05) : 1.58;
  P.pivotY += (P.pos.y + crouchH - P.pivotY) * (1 - Math.exp(-dt * 14));
  const a = P.aimT;
  const t = REAL_T;
  // cold makes your hands shake
  const coldSway = S.warmth < 35 ? (35 - S.warmth) / 35 : 0;
  const swayAmp = (0.0025 + coldSway * 0.032) * (0.35 + a * 0.65);
  const swayYaw = (Math.sin(t * 1.7) + Math.sin(t * 4.3 + 1.2) * 0.35 + (coldSway > 0.3 ? Math.sin(t * 23) * 0.15 : 0)) * swayAmp;
  const swayPitch = (Math.cos(t * 1.3) * 0.7 + Math.sin(t * 3.1) * 0.25) * swayAmp;
  P.recoil *= Math.exp(-dt * 9);
  P.shake = Math.max(0, P.shake - dt * 1.8);
  const gustShake = WIND.gust * 0.004 * windExposure(P.pos.x, P.pos.z, P.pos.y);
  const shk = P.shake * 0.03 + gustShake;
  const yaw = camYaw + swayYaw + (Math.random() - 0.5) * shk;
  const pitch = clamp(camPitch + swayPitch + P.recoil + (Math.random() - 0.5) * shk, -1.35, 1.2);
  const dist = lerp(3.9, 1.75, a);
  const shoulder = lerp(0.55, 0.72, a);
  const cp = Math.cos(pitch);
  _fwd.set(-Math.sin(yaw) * cp, Math.sin(pitch), -Math.cos(yaw) * cp);
  const rx = Math.cos(yaw), rz = -Math.sin(yaw);
  const px = P.pos.x, py = P.pivotY, pz = P.pos.z;
  // shoulder offset with collision
  let sOff = shoulder;
  const ts = raycastWorld(px, py, pz, rx, 0, rz, shoulder + 0.25);
  if (ts !== Infinity) sOff = Math.max(0, ts - 0.25);
  const sx = px + rx * sOff, sz = pz + rz * sOff, sy = py + 0.12;
  let d = dist;
  const tb = raycastWorld(sx, sy, sz, -_fwd.x, -_fwd.y, -_fwd.z, dist + 0.3);
  if (tb !== Infinity) d = Math.max(0.35, tb - 0.3);
  camDist += (d - camDist) * (d < camDist ? 1 : 1 - Math.exp(-dt * 6));
  camera.position.set(sx - _fwd.x * camDist, sy - _fwd.y * camDist, sz - _fwd.z * camDist);
  const g = groundAt(camera.position.x, camera.position.z, camera.position.y);
  if (camera.position.y < g + 0.25) camera.position.y = g + 0.25;
  camera.rotation.set(pitch, yaw, 0, 'YXZ');
  const zoom = lerp(1, st.zoom, a);
  FOV_T = (P.sprinting ? 67 : 62) / zoom;
  const nf = camera.fov + (FOV_T - camera.fov) * (1 - Math.exp(-dt * 10));
  if (Math.abs(nf - camera.fov) > 0.01) { camera.fov = nf; camera.updateProjectionMatrix(); setParticleScale(); }
  camera.updateMatrixWorld();
  // hide the player model when the camera is inside it
  P.human.group.visible = camDist > 0.9;
}

/* ---- weapons ---- */
function switchWeapon(id) {
  if (!S.guns[id] || !S.guns[id].owned || S.cur === id || P.downT > 0) return;
  S.cur = id; P.reloadT = 0; P.switchT = 0.4; refreshPlayerGun(); sfx.reload(); hudDirty = true;
}
function cycleWeapon(dir) {
  const ids = ['k9', 'draft', 'plow'].filter(i => S.guns[i].owned);
  const i = ids.indexOf(S.cur);
  switchWeapon(ids[(i + dir + ids.length) % ids.length]);
}
function startReload() {
  const g = S.guns[S.cur], st = P.stats;
  if (P.reloadT > 0 || g.mag >= st.mag || g.res <= 0) return;
  P.reloadT = st.reload; P.reloadFor = S.cur;
  if (S.cur === 'plow') sfx.pump(); else sfx.reload();
}
function finishReload() {
  if (P.reloadFor !== S.cur) return;
  const g = S.guns[S.cur], st = P.stats;
  const need = st.mag - g.mag, take = Math.min(need, g.res);
  g.mag += take; g.res -= take; hudDirty = true;
}
const _org = new THREE.Vector3(), _dir = new THREE.Vector3(), _mz = new THREE.Vector3(), _hp = new THREE.Vector3(), _up = new THREE.Vector3(0, 1, 0), _side = new THREE.Vector3();
function coneDir(base, deg, out) {
  const r = THREE.MathUtils.degToRad(deg) * Math.sqrt(Math.random()) * 0.5, a = Math.random() * TAU;
  _side.crossVectors(base, Math.abs(base.y) > 0.95 ? new THREE.Vector3(1, 0, 0) : _up).normalize();
  const up2 = new THREE.Vector3().crossVectors(_side, base).normalize();
  out.copy(base).addScaledVector(_side, Math.cos(a) * Math.tan(r)).addScaledVector(up2, Math.sin(a) * Math.tan(r)).normalize();
  return out;
}
function tryFire() {
  const g = S.guns[S.cur], st = P.stats;
  if (P.reloadT > 0 || P.switchT > 0 || P.fireCd > 0) return;
  if (g.mag <= 0) { sfx.click(); P.fireCd = 0.3; if (g.res > 0) startReload(); return; }
  P.fireCd = 60 / st.rpm; g.mag--; S.stats.shots++; hudDirty = true;
  P.lastShot = GAME_T;
  camera.updateMatrixWorld();
  _org.copy(camera.position);
  _fwd.set(0, 0, -1).applyQuaternion(camera.quaternion);
  const chestX = P.pos.x, chestY = P.pivotY - 0.15, chestZ = P.pos.z;
  const t0 = Math.max(0.3, (chestX - _org.x) * _fwd.x + (chestY - _org.y) * _fwd.y + (chestZ - _org.z) * _fwd.z);
  _org.addScaledVector(_fwd, t0);
  (fpActive() && FP.gun && FP.vm && FP.vm.visible ? FP.gun : P.gun).userData.muzzle.getWorldPosition(_mz); if (fpActive()) FP.kick = 1;
  const movingK = P.speed > 1 ? 1.35 : 1;
  const spreadDeg = lerp(st.spread, st.aimSpread, P.aimT) * movingK * (P.crouch ? 0.8 : 1) * (1 + P.bloom);
  let hitAny = false, headAny = false;
  for (let i = 0; i < st.pellets; i++) {
    coneDir(_fwd, spreadDeg, _dir);
    if (i === 0) netShot(_org, _dir, S.cur);
    const res = shootRay(_org, _dir, st.range * 2.2, null);
    _hp.copy(_org).addScaledVector(_dir, res.t === Infinity ? st.range * 2 : res.t);
    if (i < 3 || Math.random() < 0.3) addTracer(_mz, _hp, [1, 0.72, 0.4]);
    if (res.enemy || res.ped || res.cop || res.remote) {
      let dmg = st.dmg * (res.head ? 1.8 : 1) * (res.t > st.range ? 0.5 : 1);
      const dir = { x: _dir.x, z: _dir.z };
      if (i < 2) sfxImpact('flesh', _hp.x, _hp.y, _hp.z, 0.45);
      if (res.enemy) damageEnemy(res.enemy, dmg, res.head, dir);
      else if (res.ped) pedHit(res.ped, dmg, dir, true);
      else if (res.cop) copHit(res.cop, dmg, dir, true);
      else bloodBurst(_hp.x, _hp.y, _hp.z, dir.x, dir.z, 8);
      hitAny = true; headAny = headAny || res.head;
    } else if (res.t !== Infinity) {
      if (i < 2) sfxImpact(hitMaterial(_hp.x, _hp.y, _hp.z), _hp.x, _hp.y, _hp.z, 0.5);
      for (let k = 0; k < 3; k++) PFX_SMOKE.spawn(_hp.x, _hp.y, _hp.z, rand(-0.6, 0.6), rand(0.2, 1.2), rand(-0.6, 0.6), 0.7, 0.25, 0.8, 0.45, 0.85, 0.9, 0.95, 1.5, -1);
      PFX_ADD.spawn(_hp.x, _hp.y, _hp.z, 0, 0, 0, 0.08, 0.25, 0.1, 0.8, 1, 0.8, 0.5);
    }
  }
  if (hitAny) { showHitmarker(headAny); sfx.hit(headAny); }
  // muzzle flash
  const supp = S.guns[S.cur].cfg.muzzle === 'supp';
  FLASH.position.copy(_mz); FLASH.intensity = supp ? 3 : 14; FLASH.userData.t = 0.05;
  PFX_ADD.spawn(_mz.x, _mz.y, _mz.z, 0, 0, 0, 0.05, supp ? 0.15 : 0.45, 0.2, 1, 1, 0.75, 0.35);
  PFX_SMOKE.spawn(_mz.x, _mz.y, _mz.z, _fwd.x * 0.8, 0.4, _fwd.z * 0.8, 0.9, 0.15, 0.6, 0.18, 0.8, 0.85, 0.9, 1.2, 0.5);
  // recoil
  const rec = st.recoil * (P.crouch ? 0.8 : 1);
  P.recoil += rec * 0.018; camPitch = clamp(camPitch + rec * 0.0035, -1.3, 1.1); camYaw += (Math.random() - 0.5) * rec * 0.006;
  P.bloom = Math.min(1.6, P.bloom + 0.22 * st.recoil);
  sfxShot(S.cur, _mz.x, _mz.y, _mz.z, supp, 0.9);
  // noise is Heat
  addHeat(st.heatPerShot, true);
  P.lastLoud = GAME_T;
  onPlayerShot(_mz.x, _mz.z, supp);
  alertPeds(P.pos.x, P.pos.z, supp ? 12 : 48);
  if (!supp) { const copNear = COPS.some(c => c.state !== 'down' && Math.hypot(c.pos.x - P.pos.x, c.pos.z - P.pos.z) < 35) || VEH.some(v => v.copAI && Math.hypot(v.pos.x - P.pos.x, v.pos.z - P.pos.z) < 45); addWanted(copNear ? 10 : 3, P.pos, copNear); if (copNear) WANTED.hostile = true; }
  if (S.cur === 'plow') setTimeout(() => sfx.pump(), 260);
  if (g.mag === 0 && g.res > 0) setTimeout(() => { if (S.guns[S.cur] === g && g.mag === 0) startReload(); }, 300);
}
// ray vs world + enemies
function shootRay(org, dir, maxT, skipEnemy) {
  const tw = raycastWorld(org.x, org.y, org.z, dir.x, dir.y, dir.z, maxT);
  let best = tw, enemy = null, ped = null, cop = null, remote = null, head = false;
  for (const e of ENEMIES) { if (e.state === 'down' || e === skipEnemy) continue; const r = rayEnemy(org, dir, e); if (r && r.t < best) { best = r.t; enemy = e; ped = cop = remote = null; head = r.head; } }
  for (const p of PEDS) { if (p.state === 'down') continue; const r = rayEnemy(org, dir, p); if (r && r.t < best) { best = r.t; ped = p; enemy = cop = remote = null; head = r.head; } }
  for (const c of COPS) { if (c.state === 'down') continue; const r = rayEnemy(org, dir, c); if (r && r.t < best) { best = r.t; cop = c; enemy = ped = remote = null; head = r.head; } }
  for (const R of NET.remotes.values()) { if (R.veh || (R.f & 4)) continue; const r = rayEnemy(org, dir, { pos: R.pos, crouched: !!(R.f & 1) }); if (r && r.t < best) { best = r.t; remote = R; enemy = ped = cop = null; head = r.head; } }
  return { t: best, enemy, ped, cop, remote, head };
}
function rayEnemy(o, d, e) {
  const top = e.crouched ? 0.92 : 1.42, headY = e.pos.y + (e.crouched ? 1.02 : 1.6), r = 0.34;
  // head sphere
  let res = null;
  const hx = o.x - e.pos.x, hy = o.y - headY, hz = o.z - e.pos.z;
  const b = hx * d.x + hy * d.y + hz * d.z, c = hx * hx + hy * hy + hz * hz - 0.2 * 0.2, disc = b * b - c;
  if (disc > 0) { const t = -b - Math.sqrt(disc); if (t > 0) res = { t, head: true }; }
  // body cylinder
  const ox = o.x - e.pos.x, oz = o.z - e.pos.z;
  const A = d.x * d.x + d.z * d.z, B = 2 * (ox * d.x + oz * d.z), C = ox * ox + oz * oz - r * r;
  const D = B * B - 4 * A * C;
  if (D > 0 && A > 1e-6) {
    const t = (-B - Math.sqrt(D)) / (2 * A);
    if (t > 0) { const y = o.y + d.y * t; if (y > e.pos.y && y < e.pos.y + top && (!res || t < res.t)) res = { t, head: false }; }
  }
  return res;
}
function showHitmarker(head) {
  const h = $('hitmark'); h.className = head ? 'head' : ''; h.style.opacity = 1; h.style.transition = 'none';
  requestAnimationFrame(() => { h.style.transition = 'opacity .25s'; h.style.opacity = 0; });
}
function hurtPlayer(dmg, from, silent) {
  if (MODE === 'ending' || P.dead) return;
  S.health -= dmg; P.lastHurt = GAME_T; P.shake = Math.min(1, P.shake + dmg * 0.04);
  GRADE.uniforms.uHurt.value = Math.min(1, GRADE.uniforms.uHurt.value + 0.25 + dmg * 0.03);
  if (!silent && !P.car) bloodBurst(P.pos.x, P.pos.y + 1.2, P.pos.z, from ? P.pos.x - from.x : 0, from ? P.pos.z - from.z : 0, 6);
  if (!silent) sfx.hurt();
  if (S.health <= 0) { S.health = 0; playerDowned(); }
  hudDirty = true;
}
function playerDowned() {
  if (P.dead) return;
  P.dead = true;
  sfx.stinger('down');
  S.stats.timesDowned++;
  if (P.car) exitVehicle();
  P.downT = 4;
  bloodPool(P.pos.x, P.pos.y, P.pos.z, 1.8);
  playCutscene(cutDowned(), () => {
    clearCrews(); clearWanted();
    for (const c of [...COPS]) removeCop(c);
    S.health = 60; S.warmth = 75;
    const lost = Math.round(S.cash * 0.2); S.cash -= lost;
    S.heat = Math.max(0, S.heat - 25);
    placePlayer(LOC.hospital.x, 0, LOC.hospital.z, Math.PI / 2);
    P.dead = false; P.downT = 0; GRADE.uniforms.uDesat.value = 0;
    banner('Calder General', 'Hospital bill ' + fmtMoney(lost));
    sendMsg('kiara', 'mama is crying. please come home and stay home', true);
    postFeed(pick(FEED_HANDLES), `prayers up for ${n_()}. heard they ended up at Calder General`);
    saveGame();
  });
}
function placePlayer(x, y, z, yaw) {
  P.pos.set(x, y, z); P.vel.set(0, 0, 0); P.onGround = true; P.airY = y; P.pivotY = y + 1.58;
  if (yaw !== undefined) { camYaw = yaw; P.bodyYaw = yaw + Math.PI; }
}
