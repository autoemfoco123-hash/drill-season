
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
  if (!S.settings.fp) fpHide();
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
  FP.left.visible = P.reloadT <= 0 && !((P.flipK || 0) > 0.3);
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
  fpReleaseCar();
  if (S.fists) { if (FP.vm) FP.vm.visible = false; updateFistVM(dt, a); }
  else { if (FP.fv) FP.fv.visible = false; updateViewmodel(dt, a); }
}
/* ---- driver's seat: a real interior built to each car's dimensions ---- */
const _ck = new THREE.Vector3(), _ck2 = new THREE.Vector3();
function carGeom(sp) {
  // windshield base/top, roof back and hood nose, in car-local z (forward from the centre) and height
  const L2 = sp.len / 2, body = sp.body, cab = sp.cabin;
  let wb, wt, rb;
  if (cab) { wb = cab[3]; wt = cab[2]; rb = cab[1]; }
  else { wt = body[2]; wb = body[3]; rb = body[1]; }
  const front = body.filter(p => p[0] > wb[0] + 0.05 && p[1] > 0.5);
  const nose = front.length ? front[front.length - 1] : [sp.len, wb[1] - 0.2];
  const mid = front.length ? front[0] : nose;
  return { zWB: wb[0] - L2, yWB: wb[1], zWT: wt[0] - L2, yWT: wt[1], zRB: rb[0] - L2, roofY: Math.max(wt[1], rb[1]), zMid: mid[0] - L2, yMid: mid[1], zNose: nose[0] - L2, yNose: nose[1] };
}
function setLimb(m, a, b, r) {
  _ck.set(b[0] - a[0], b[1] - a[1], b[2] - a[2]);
  const L = _ck.length(); _ck.normalize();
  m.quaternion.setFromUnitVectors(_limbUp, _ck);
  m.position.set((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2);
  m.scale.set(r, L, r);
}
function buildCockpit(v) {
  if (FP.cockpit) { scene.remove(FP.cockpit); FP.cockpit.traverse(m => { if (m.geometry && m.geometry !== GEO.box && m.geometry !== VM_CYL && m.geometry !== HG.hand) m.geometry.dispose(); }); }
  const sp = v.sp, G = carGeom(sp), W = sp.wid, g = new THREE.Group();
  const o = skinHumanOpts(S.skin);
  const M = (c, r, m) => new THREE.MeshStandardMaterial({ color: c, roughness: r === undefined ? 0.8 : r, metalness: m || 0 });
  const dash = M(0x17181b, 0.75), trim = M(0x2a2c31, 0.6), soft = M(0x3a3a3c, 0.95), liner = M(0x8c8982, 1), chrome = M(0xb8bcc2, 0.25, 0.9);
  const paint = new THREE.MeshPhysicalMaterial({ color: v.color, roughness: 0.32, metalness: 0.4, clearcoat: 1, clearcoatRoughness: 0.06 });
  const glass = new THREE.MeshStandardMaterial({ color: 0x9fb4c8, transparent: true, opacity: 0.06, roughness: 0.04, metalness: 0.2, depthWrite: false });
  const box = (w, h, d, x, y, z, m, rx, ry, rz) => { const me = new THREE.Mesh(GEO.box, m); me.scale.set(w, h, d); me.position.set(x, y, z); me.rotation.set(rx || 0, ry || 0, rz || 0); g.add(me); return me; };
  const bar = (a, b2, r, m) => { const me = new THREE.Mesh(VM_CYL, m); setLimb(me, a, b2, r); g.add(me); return me; };
  const xD = W * 0.21, eyeY = Math.max(G.yWB + 0.32, G.roofY - 0.26), eyeZ = G.zWB - 0.95;
  FP.eye = [xD, eyeY, eyeZ]; FP.geomKey = v.model + ':' + v.color + ':' + skinKey(cleanSkin(S.skin));
  // the hood you look out over, in the car's own paint
  const hz0 = G.zWB + 0.02, hz1 = Math.max(G.zMid, G.zWB + 0.6), hood = box(W - 0.1, 0.05, hz1 - hz0, 0, (G.yWB + G.yMid) / 2 - 0.02, (hz0 + hz1) / 2, paint, Math.atan2(G.yWB - G.yMid, hz1 - hz0));
  const nz1 = Math.max(G.zNose - 0.05, hz1 + 0.1); box(W - 0.14, 0.05, nz1 - hz1, 0, (G.yMid + G.yNose) / 2 - 0.02, (hz1 + nz1) / 2, paint, Math.atan2(G.yMid - G.yNose, nz1 - hz1));
  for (const s of [-1, 1]) box(0.06, 0.07, hz1 - hz0, s * (W / 2 - 0.05), (G.yWB + G.yMid) / 2 + 0.02, (hz0 + hz1) / 2, paint, Math.atan2(G.yWB - G.yMid, hz1 - hz0));
  // dashboard, gauge hood, centre stack
  const dT = G.yWB - 0.06;
  box(W - 0.12, 0.3, 0.62, 0, dT - 0.15, G.zWB - 0.3, dash);
  box(W - 0.12, 0.04, 0.3, 0, dT + 0.01, G.zWB - 0.14, dash, -0.18);
  // instrument pod: you read the gauges over the top of the wheel
  const gY = eyeY - 0.215, gZ = eyeZ + 0.5, podTop = gY + 0.072, podH = Math.max(0.06, podTop - (dT - 0.05));
  box(0.39, podH, 0.18, xD, podTop - podH / 2, gZ + 0.095, dash);
  box(0.41, 0.02, 0.09, xD, podTop + 0.008, gZ - 0.01, dash, 0.18);
  box(0.36, 0.42, 0.2, 0, dT - 0.36, G.zWB - 0.66, trim);
  box(0.24, 0.5, 0.55, 0, 0.62, eyeZ + 0.05, trim);
  for (const s of [-1, 1]) box(0.14, 0.04, 0.02, s * 0.62, dT - 0.05, G.zWB - 0.615, chrome);
  // gauges (canvas) and the radio screen
  const gc = document.createElement('canvas'); gc.width = 512; gc.height = 192;
  const gt = new THREE.CanvasTexture(gc); gt.colorSpace = THREE.SRGBColorSpace; gt.anisotropy = 4;
  const gp = new THREE.Mesh(new THREE.PlaneGeometry(0.36, 0.135), new THREE.MeshBasicMaterial({ map: gt, toneMapped: false }));
  gp.position.set(xD, gY, gZ); gp.rotation.set(0.25, Math.PI, 0); g.add(gp);
  const rc = document.createElement('canvas'); rc.width = 256; rc.height = 128;
  const rt = new THREE.CanvasTexture(rc); rt.colorSpace = THREE.SRGBColorSpace;
  const rp = new THREE.Mesh(new THREE.PlaneGeometry(0.2, 0.1), new THREE.MeshBasicMaterial({ map: rt, toneMapped: false }));
  rp.position.set(0, dT - 0.1, G.zWB - 0.62); rp.rotation.set(0.15, Math.PI, 0); g.add(rp);
  // steering wheel (spins with the steering) and your hands on it
  const wheel = new THREE.Group(); wheel.position.set(xD, eyeY - 0.42, eyeZ + 0.43); wheel.rotation.set(0.45, Math.PI, 0); g.add(wheel);
  const spin = new THREE.Group(); wheel.add(spin);
  spin.add(new THREE.Mesh(new THREE.TorusGeometry(0.185, 0.022, 8, 32), M(0x141416, 0.55)));
  const hub = new THREE.Mesh(GEO.box, trim); hub.scale.set(0.12, 0.09, 0.05); spin.add(hub);
  for (const [x, y, w, h] of [[-0.1, 0, 0.17, 0.03], [0.1, 0, 0.17, 0.03], [0, -0.1, 0.03, 0.16]]) { const sp2 = new THREE.Mesh(GEO.box, trim); sp2.scale.set(w, h, 0.025); sp2.position.set(x, y, 0); spin.add(sp2); }
  const column = bar([xD, eyeY - 0.42 - 0.06, eyeZ + 0.5], [xD, dT - 0.2, G.zWB - 0.55], 0.04, trim);
  const skin = _vmMat(o.skin), sleeve = _vmMat(o.top === 'varsity' ? o.jacket2 : o.jacket);
  const hands = [-1, 1].map(s => { const h = new THREE.Mesh(HG.hand, skin); h.scale.set(0.85, 0.85, 1.0); h.position.set(s * 0.185, 0.0, -0.025); spin.add(h); return h; });
  const arms = [-1, 1].map(() => { const m = new THREE.Mesh(VM_CYL, sleeve); g.add(m); return m; });
  // pillars, roof, doors, mirrors, seats
  const ax = W / 2 - 0.09, axT = W / 2 - 0.17;
  for (const s of [-1, 1]) {
    bar([s * ax, G.yWB - 0.02, G.zWB + 0.02], [s * axT, G.yWT - 0.03, G.zWT], 0.036, trim);
    box(0.08, (G.yWB + 0.06) - 0.4, Math.max(0.6, G.zWB - G.zRB + 0.4), s * (W / 2 - 0.05), (0.4 + G.yWB + 0.06) / 2, (G.zWB + G.zRB) / 2 - 0.2, dash);
    box(0.12, 0.05, Math.max(0.6, G.zWB - G.zRB + 0.4), s * (W / 2 - 0.08), G.yWB + 0.07, (G.zWB + G.zRB) / 2 - 0.2, trim);
    bar([s * (W / 2 - 0.08), G.yWB + 0.08, eyeZ - 0.42], [s * (W / 2 - 0.15), G.roofY - 0.05, eyeZ - 0.5], 0.06, trim);
    box(0.09, 0.08, 0.16, s * (W / 2 + 0.07), G.yWB + 0.14, G.zWB - 0.08, paint);
    box(0.012, 0.07, 0.13, s * (W / 2 + 0.115), G.yWB + 0.14, G.zWB - 0.1, chrome);
  }
  box(W - 0.24, 0.07, 0.14, 0, G.yWT - 0.035, G.zWT - 0.06, trim);
  box(W - 0.18, 0.04, Math.max(0.5, G.zWT - G.zRB), 0, G.roofY - 0.04, (G.zWT + G.zRB) / 2, liner);
  box(0.25, 0.075, 0.03, 0, G.yWT - 0.15, G.zWT - 0.14, trim); box(0.23, 0.06, 0.005, 0, G.yWT - 0.15, G.zWT - 0.157, chrome);
  bar([0, G.yWT - 0.11, G.zWT - 0.14], [0, G.yWT - 0.03, G.zWT - 0.07], 0.012, trim);
  box(0.5, 0.12, 0.55, -xD, 0.62, eyeZ, soft); box(0.5, 0.65, 0.12, -xD, 0.95, eyeZ - 0.3, soft, -0.15);
  // windshield glass and wipers
  const wsh = new THREE.Mesh(new THREE.PlaneGeometry(W - 0.2, Math.hypot(G.zWT - G.zWB, G.yWT - G.yWB)), glass);
  wsh.position.set(0, (G.yWB + G.yWT) / 2, (G.zWB + G.zWT) / 2); wsh.rotation.set(Math.atan2(G.zWT - G.zWB, G.yWT - G.yWB), 0, 0); g.add(wsh);
  for (const x of [xD - 0.05, -0.15]) box(0.55, 0.015, 0.02, x + 0.1, G.yWB + 0.03, G.zWB + 0.05, dash, 0, 0, 0.12);
  g.traverse(m => { if (m.isMesh) { m.castShadow = false; m.receiveShadow = false; m.frustumCulled = false; } });
  scene.add(g);
  FP.cockpit = g; FP.spinG = spin; FP.hands = hands; FP.arms = arms; FP.gaugeTex = gt; FP.gaugeCtx = gc.getContext('2d'); FP.radioTex = rt; FP.radioCtx = rc.getContext('2d'); FP.gaugeKey = ''; FP.radioKey = '';
}
function drawGauges(v) {
  const sp = Math.abs(v.speed), mph = Math.round(sp * 2.237), rpm = ENG.V ? ENG.V.rpm : 800, red = ENG.V ? ENG.V.spec.red : 6500;
  const gear = v.speed < -0.3 ? 'R' : ENG.V ? String(ENG.V.gear + 1) : 'D';
  const key = mph + '|' + Math.round(rpm / 50) + '|' + gear;
  if (key === FP.gaugeKey) return; FP.gaugeKey = key;
  const g = FP.gaugeCtx, W = 512, H = 192;
  g.fillStyle = '#050608'; g.fillRect(0, 0, W, H);
  const dial = (cx, val, max, label, redFrom) => {
    const r = 78, a0 = Math.PI * 0.75, a1 = Math.PI * 2.25;
    g.lineWidth = 3; g.strokeStyle = '#2a3036'; g.beginPath(); g.arc(cx, 100, r, a0, a1); g.stroke();
    for (let i = 0; i <= 10; i++) { const a = a0 + (a1 - a0) * i / 10, hot = redFrom !== undefined && i / 10 >= redFrom; g.strokeStyle = hot ? '#ff4a3a' : '#c8d0d8'; g.lineWidth = i % 2 ? 2 : 3; g.beginPath(); g.moveTo(cx + Math.cos(a) * (r - 4), 100 + Math.sin(a) * (r - 4)); g.lineTo(cx + Math.cos(a) * (r - (i % 2 ? 11 : 16)), 100 + Math.sin(a) * (r - (i % 2 ? 11 : 16))); g.stroke(); }
    const a = a0 + (a1 - a0) * clamp(val / max, 0, 1);
    g.strokeStyle = '#ff7a2a'; g.lineWidth = 4; g.beginPath(); g.moveTo(cx, 100); g.lineTo(cx + Math.cos(a) * (r - 12), 100 + Math.sin(a) * (r - 12)); g.stroke();
    g.fillStyle = '#1a1e22'; g.beginPath(); g.arc(cx, 100, 9, 0, TAU); g.fill();
    g.fillStyle = '#8a96a2'; g.font = '600 15px Inter, sans-serif'; g.textAlign = 'center'; g.fillText(label, cx, 152);
  };
  dial(110, rpm, 8000, 'RPM ×1000', red / 8000);
  dial(402, mph, 140, 'MPH');
  g.fillStyle = '#ffb347'; g.font = '700 46px Inter, sans-serif'; g.textAlign = 'center'; g.fillText(String(mph), 256, 92);
  g.fillStyle = '#c8d0d8'; g.font = '700 30px Inter, sans-serif'; g.fillText(gear, 256, 140);
  g.fillStyle = '#7be0a6'; g.font = '600 13px Inter, sans-serif'; g.fillText(clockStr ? clockStr() : '', 256, 176);
  FP.gaugeTex.needsUpdate = true;
}
function drawRadio() {
  const st = RADIO.on && S.settings.radio ? STATIONS[S.settings.radio] : null, key = (st ? st.name : 'off');
  if (key === FP.radioKey) return; FP.radioKey = key;
  const g = FP.radioCtx; g.fillStyle = '#04070a'; g.fillRect(0, 0, 256, 128);
  g.fillStyle = st ? '#ffb347' : '#56606a'; g.font = '700 26px Inter, sans-serif'; g.textAlign = 'center';
  g.fillText(st ? st.short : 'RADIO OFF', 128, 58);
  g.fillStyle = '#8a96a2'; g.font = '500 14px Inter, sans-serif'; g.fillText(st ? st.name.split('·')[1] ? st.name.split('·')[1].trim() : '' : 'R to tune', 128, 90);
  FP.radioTex.needsUpdate = true;
}
function fpReleaseCar() { if (FP.hidCar) { FP.hidCar.hideBody = false; placeVehInstance(FP.hidCar); FP.hidCar = null; } if (FP.cockpit) FP.cockpit.visible = false; }
function updateCarFP(dt) {
  const v = P.car, sp = Math.abs(v.speed);
  if (REAL_T - (P.lastLook || 0) > 1.4) { camYaw += angDiff(camYaw, v.yaw + Math.PI) * (1 - Math.exp(-dt * 2.6)); camPitch += (-0.1 - camPitch) * (1 - Math.exp(-dt * 2)); }
  P.shake = Math.max(0, P.shake - dt * 1.8);
  const key = v.model + ':' + v.color + ':' + skinKey(cleanSkin(S.skin));
  if (!FP.cockpit || FP.geomKey !== key) buildCockpit(v);
  if (FP.hidCar !== v) { fpReleaseCar(); v.hideBody = true; FP.hidCar = v; }
  const ck = FP.cockpit; ck.visible = true;
  ck.position.set(v.pos.x, 0, v.pos.z); ck.rotation.set(0, v.yaw, 0); ck.updateMatrixWorld(true);
  // eye: seat position plus road buzz and a little body roll in corners
  const lat = (v.steer || 0) * sp;
  _ck2.set(FP.eye[0] + clamp(lat * 0.002, -0.05, 0.05), FP.eye[1] + Math.sin(REAL_T * 17) * Math.min(sp, 25) * 0.0004 + (Math.random() - 0.5) * P.shake * 0.03, FP.eye[2]);
  ck.localToWorld(_ck2);
  camera.position.copy(_ck2);
  const look = clamp(angDiff(v.yaw + Math.PI, camYaw), -2.0, 2.0) + 0.42 * (P.flipK || 0); // glance at the window when the finger goes up
  camera.rotation.set(clamp(camPitch + 0.06, -0.6, 0.5), v.yaw + Math.PI + look, -clamp(lat * 0.0015, -0.03, 0.03), 'YXZ');
  const nf = (S.settings.fov || 70) + clamp(sp, 0, 34) * 0.25;
  if (Math.abs(nf - camera.fov) > 0.05) { camera.fov += (nf - camera.fov) * (1 - Math.exp(-dt * 3)); camera.updateProjectionMatrix(); setParticleScale(); }
  camera.updateMatrixWorld();
  if (FP.vm) FP.vm.visible = false; if (FP.fv) FP.fv.visible = false;
  // wheel turns with the steering; forearms follow the hands
  FP.spinG.rotation.z = -(v.steer || 0) * 2.4;
  FP.spinG.updateMatrixWorld(true);
  const sx = [FP.eye[0] + 0.2, FP.eye[0] - 0.2];
  FP.hands[0].visible = FP.arms[0].visible = !((P.flipK || 0) > 0.04); // that hand is out of the window
  FP.hands.forEach((h, i) => {
    h.getWorldPosition(_ck); ck.worldToLocal(_ck);
    setLimb(FP.arms[i], [_ck.x, _ck.y - 0.02, _ck.z - 0.04], [sx[i], FP.eye[1] - 0.3, FP.eye[2] - 0.02], 0.04);
  });
  drawGauges(v); drawRadio();
}
function fpHide() { if (FP.vm) FP.vm.visible = false; if (FP.fv) FP.fv.visible = false; if (FP.flip) FP.flip.visible = false; fpReleaseCar(); }
