
/* =========================================================
   FIRST-PERSON CAMERA - V toggles. On foot you see your own
   sleeves, hands and gun; in a car you sit in the driver's seat.
   ========================================================= */
const FP = { vm: null, gun: null, key: '', bob: 0, lastYaw: 0, lastPitch: 0, lagX: 0, lagY: 0, kick: 0, cockpit: null, wheel: null, spd: null, spdCtx: null, spdVal: -1 };
function fpOn() { return !!S.settings.fp; }
function fpActive() { return fpOn() && !P.dead && (MODE === 'play' || MODE === 'phone') && !(PHONE.selfie && MODE === 'phone'); }
function toggleFP() {
  S.settings.fp = !S.settings.fp;
  banner(S.settings.fp ? 'First person' : 'Third person', 'V to switch');
  if (!S.settings.fp) { if (FP.vm) FP.vm.visible = false; if (FP.cockpit) FP.cockpit.visible = false; }
  sfx.ui();
}
const _vmMat = c => new THREE.MeshLambertMaterial({ color: c, emissive: new THREE.Color(c).multiplyScalar(0.06) });
const _limbUp = new THREE.Vector3(0, 1, 0), _limbD = new THREE.Vector3();
function limb(parent, geo, mat, a, b, r) { // a cylinder from point a to point b
  const m = new THREE.Mesh(geo, mat);
  _limbD.set(b[0] - a[0], b[1] - a[1], b[2] - a[2]);
  const L = _limbD.length(); _limbD.normalize();
  m.quaternion.setFromUnitVectors(_limbUp, _limbD);
  m.position.set((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2);
  m.scale.set(r, L, r); parent.add(m); return m;
}
const VM_CYL = new THREE.CylinderGeometry(1, 0.85, 1, 10);
function buildViewmodel() {
  if (FP.vm) camera.remove(FP.vm);
  const o = skinHumanOpts(S.skin);
  const g = new THREE.Group();
  const sleeve = _vmMat(o.top === 'varsity' ? o.jacket2 : o.jacket), cuff = _vmMat(o.jacket2), skin = _vmMat(o.skin);
  const gun = buildGun(S.cur, S.guns[S.cur].cfg);
  gun.rotation.y = Math.PI; gun.scale.setScalar(1.0);
  g.add(gun);
  const two = S.cur !== 'k9';
  // right hand on the grip, forearm running back and down out of frame
  const rh = new THREE.Mesh(HG.hand, skin); rh.scale.set(0.72, 0.85, 0.9); rh.position.set(0.004, -0.032, 0.035); g.add(rh);
  limb(g, VM_CYL, cuff, [0.01, -0.05, 0.07], [0.02, -0.055, 0.095], 0.034);
  limb(g, VM_CYL, sleeve, [0.02, -0.055, 0.09], [0.1, -0.2, 0.36], 0.036);
  if (o.watch) { const w = new THREE.Mesh(HG.watch, _vmMat(0xd4a640)); w.scale.setScalar(0.7); w.position.set(-0.02, -0.04, 0.06); g.add(w); }
  // support hand under the front of the gun
  const left = new THREE.Group(); g.add(left);
  const lz = two ? -0.14 : 0.0, lx = two ? -0.005 : -0.03;
  const lh = new THREE.Mesh(HG.hand, skin); lh.scale.set(0.75, 0.75, 0.95); lh.position.set(lx, -0.045, lz + 0.01); left.add(lh);
  limb(left, VM_CYL, cuff, [lx - 0.01, -0.06, lz + 0.05], [lx - 0.025, -0.07, lz + 0.075], 0.034);
  limb(left, VM_CYL, sleeve, [lx - 0.025, -0.07, lz + 0.07], [-0.2, -0.24, 0.3], 0.036);
  g.traverse(m => { if (m.isMesh) { m.castShadow = false; m.frustumCulled = false; } });
  camera.add(g);
  FP.vm = g; FP.gun = gun; FP.left = left;
  FP.key = S.cur + JSON.stringify(S.guns[S.cur].cfg) + skinKey(cleanSkin(S.skin));
}
function updateViewmodel(dt, a) {
  const key = S.cur + JSON.stringify(S.guns[S.cur].cfg) + skinKey(cleanSkin(S.skin));
  if (!FP.vm || key !== FP.key) buildViewmodel();
  const vm = FP.vm; vm.visible = !(P.handsUp > 0);
  // weapon lags behind fast mouse moves
  const dy = angDiff(FP.lastYaw, camYaw), dp = camPitch - FP.lastPitch; FP.lastYaw = camYaw; FP.lastPitch = camPitch;
  FP.lagX = lerp(FP.lagX, clamp(-dy * 1.6, -0.06, 0.06), 1 - Math.exp(-dt * 10));
  FP.lagY = lerp(FP.lagY, clamp(dp * 1.6, -0.05, 0.05), 1 - Math.exp(-dt * 10));
  FP.kick = Math.max(0, FP.kick - dt * 9);
  const mv = Math.min(1, P.speed / 5) * (1 - a * 0.8);
  const bx = Math.cos(FP.bob) * 0.012 * mv, by = -Math.abs(Math.sin(FP.bob)) * 0.016 * mv;
  const reload = P.reloadT > 0 ? Math.sin(clamp(P.reloadT / Math.max(0.2, (P.stats || gunStats(S.cur)).reload), 0, 1) * Math.PI) : 0;
  const sw = P.switchT > 0 ? P.switchT / 0.4 : 0;
  const sprint = P.sprinting && a < 0.1 ? 1 : 0;
  FP.sprintK = lerp(FP.sprintK || 0, sprint, 1 - Math.exp(-dt * 8));
  const hipX = 0.13, hipY = -0.15, hipZ = -0.42, adsX = 0, adsY = -0.092, adsZ = -0.36;
  vm.position.set(lerp(hipX, adsX, a) + bx + FP.lagX - FP.sprintK * 0.04, lerp(hipY, adsY, a) + by + FP.lagY - reload * 0.12 - sw * 0.2 - FP.sprintK * 0.05, lerp(hipZ, adsZ, a) + FP.kick * 0.05);
  vm.rotation.set(FP.kick * 0.22 + reload * 0.6 - FP.sprintK * 0.35, lerp(0.04, 0, a) + FP.sprintK * 0.5, -reload * 0.35 + FP.sprintK * 0.2);
  FP.left.visible = P.reloadT <= 0;
}
function updateFPCamera(dt) {
  const st = P.stats || gunStats(S.cur);
  const eyeH = P.crouch ? 1.06 : 1.62;
  P.pivotY += (P.pos.y + eyeH - P.pivotY) * (1 - Math.exp(-dt * 14));
  const a = P.aimT, t = REAL_T;
  const coldSway = S.warmth < 35 ? (35 - S.warmth) / 35 : 0;
  const swayAmp = (0.0018 + coldSway * 0.028) * (0.4 + a * 0.6);
  const swayYaw = (Math.sin(t * 1.7) + Math.sin(t * 4.3 + 1.2) * 0.35 + (coldSway > 0.3 ? Math.sin(t * 23) * 0.15 : 0)) * swayAmp;
  const swayPitch = (Math.cos(t * 1.3) * 0.7 + Math.sin(t * 3.1) * 0.25) * swayAmp;
  P.recoil *= Math.exp(-dt * 9);
  P.shake = Math.max(0, P.shake - dt * 1.8);
  const shk = P.shake * 0.03 + WIND.gust * 0.003 * windExposure(P.pos.x, P.pos.z, P.pos.y);
  FP.bob += dt * (P.speed > 0.3 && P.onGround ? 3.4 + P.speed * 1.25 : 0);
  const bobAmp = Math.min(1, P.speed / 5) * (1 - a * 0.75) * 0.03;
  const yaw = camYaw + swayYaw + (Math.random() - 0.5) * shk;
  const pitch = clamp(camPitch + swayPitch + P.recoil + (Math.random() - 0.5) * shk, -1.45, 1.45);
  const fx = -Math.sin(yaw), fz = -Math.cos(yaw);
  // keep the eye out of walls
  let push = 0.14;
  const tw = raycastWorld(P.pos.x, P.pivotY, P.pos.z, fx, 0, fz, 0.5);
  if (tw !== Infinity) push = Math.max(-0.12, Math.min(push, tw - 0.3));
  camera.position.set(P.pos.x + fx * push, P.pivotY + Math.abs(Math.sin(FP.bob)) * bobAmp, P.pos.z + fz * push);
  camera.rotation.set(pitch, yaw, Math.sin(FP.bob * 0.5) * bobAmp * 0.35, 'YXZ');
  const zoom = lerp(1, st.zoom * 1.1, a);
  FOV_T = ((S.settings.fov || 70) + (P.sprinting ? 6 : 0)) / zoom;
  const nf = camera.fov + (FOV_T - camera.fov) * (1 - Math.exp(-dt * 12));
  if (Math.abs(nf - camera.fov) > 0.01) { camera.fov = nf; camera.updateProjectionMatrix(); setParticleScale(); }
  camera.updateMatrixWorld();
  P.human.group.visible = false;
  if (FP.cockpit) FP.cockpit.visible = false;
  updateViewmodel(dt, a);
}
/* ---- driver's seat ---- */
function buildCockpit() {
  const g = new THREE.Group();
  const dark = new THREE.MeshLambertMaterial({ color: 0x141619 }), trim = new THREE.MeshLambertMaterial({ color: 0x2a2e34 }), skin = _vmMat(SKIN_TONES[cleanSkin(S.skin).tone]);
  const box = (w, h, d, x, y, z, m, rx) => { const me = new THREE.Mesh(GEO.box, m); me.scale.set(w, h, d); me.position.set(x, y, z); me.rotation.x = rx || 0; g.add(me); return me; };
  box(2.0, 0.22, 0.6, 0.35, -0.47, -0.78, dark, -0.1);     // dashboard
  box(2.0, 0.03, 0.35, 0.35, -0.355, -0.98, trim, -0.2);   // defroster strip
  box(0.2, 0.06, 0.02, 0.36, 0.3, -0.7, trim);             // rear-view mirror
  box(0.02, 0.1, 0.02, 0.36, 0.36, -0.7, trim);
  const wheel = new THREE.Group(); wheel.position.set(0, -0.31, -0.5); wheel.rotation.x = -0.45; g.add(wheel);
  wheel.add(new THREE.Mesh(new THREE.TorusGeometry(0.17, 0.02, 6, 28), dark));
  const hub = new THREE.Mesh(GEO.box, trim); hub.scale.set(0.1, 0.075, 0.05); wheel.add(hub);
  for (const s of [-1, 1]) { const sp = new THREE.Mesh(GEO.box, trim); sp.scale.set(0.16, 0.028, 0.025); sp.position.x = s * 0.085; wheel.add(sp); const h = new THREE.Mesh(HG.hand, skin); h.scale.setScalar(0.85); h.position.set(s * 0.168, 0.0, 0.03); wheel.add(h); }
  const c = document.createElement('canvas'); c.width = 128; c.height = 64;
  const tex = new THREE.CanvasTexture(c); tex.colorSpace = THREE.SRGBColorSpace;
  const sp = new THREE.Mesh(new THREE.PlaneGeometry(0.16, 0.08), new THREE.MeshBasicMaterial({ map: tex, toneMapped: false }));
  sp.position.set(0, -0.345, -0.64); sp.rotation.x = -0.45; g.add(sp);
  g.traverse(m => { if (m.isMesh) { m.castShadow = false; m.frustumCulled = false; } });
  camera.add(g);
  FP.cockpit = g; FP.wheel = wheel; FP.spd = tex; FP.spdCtx = c.getContext('2d');
}
function updateCarFP(dt) {
  const v = P.car, sp = Math.abs(v.speed);
  if (REAL_T - (P.lastLook || 0) > 1.4) { camYaw += angDiff(camYaw, v.yaw + Math.PI) * (1 - Math.exp(-dt * 2.6)); camPitch += (-0.16 - camPitch) * (1 - Math.exp(-dt * 2)); }
  P.shake = Math.max(0, P.shake - dt * 1.8);
  const fx = Math.sin(v.yaw), fz = Math.cos(v.yaw), lx = Math.cos(v.yaw), lz = -Math.sin(v.yaw);
  const side = v.sp.wid * 0.2, fwd = -v.sp.len * 0.04, eye = (v.sp.roofY || 1.4) - 0.32;
  const sh = P.shake * 0.04;
  camera.position.set(v.pos.x + fx * fwd + lx * side + (Math.random() - 0.5) * sh, eye + Math.sin(REAL_T * 13) * Math.min(sp, 25) * 0.0006, v.pos.z + fz * fwd + lz * side + (Math.random() - 0.5) * sh);
  const look = clamp(angDiff(v.yaw + Math.PI, camYaw), -1.9, 1.9);
  camera.rotation.set(clamp(camPitch + 0.16, -0.7, 0.6), v.yaw + Math.PI + look, 0, 'YXZ');
  const nf = (S.settings.fov || 70) + clamp(sp, 0, 34) * 0.3;
  camera.fov += (nf - camera.fov) * (1 - Math.exp(-dt * 3)); camera.updateProjectionMatrix(); setParticleScale();
  camera.updateMatrixWorld();
  if (!FP.cockpit) buildCockpit();
  FP.cockpit.visible = true; if (FP.vm) FP.vm.visible = false;
  // undo the head-look so the dash stays put while you look around
  FP.cockpit.position.set(0, 0, 0); FP.cockpit.rotation.set(-clamp(camPitch + 0.16, -0.7, 0.6), -look, 0, 'XYZ');
  FP.wheel.rotation.z = -(v.steer || 0) * 1.6;
  const mph = Math.round(sp * 2.237);
  if (mph !== FP.spdVal) {
    FP.spdVal = mph; const g = FP.spdCtx;
    g.fillStyle = '#05070a'; g.fillRect(0, 0, 128, 64);
    g.fillStyle = '#ffb347'; g.font = '700 34px Inter, sans-serif'; g.textAlign = 'center'; g.fillText(String(mph), 64, 40);
    g.fillStyle = '#8a96a6'; g.font = '600 12px Inter, sans-serif'; g.fillText('MPH', 64, 57);
    FP.spd.needsUpdate = true;
  }
}
function fpHide() { if (FP.vm) FP.vm.visible = false; if (FP.cockpit) FP.cockpit.visible = false; }
