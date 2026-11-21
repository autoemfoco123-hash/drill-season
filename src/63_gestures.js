/* =========================================================
   GESTURES - T (or the middle-finger button) puts your middle
   finger up: on foot, or out of the driver's window in a car.
   Other players see it, and people nearby may answer back.
   ========================================================= */
const FLIP_LINES = ['Same to you!', 'Real mature.', 'Keep it moving!', 'Who you flipping?', 'Get outta here.', 'Wow. Okay.', 'Love you too.'];
const COP_LINES = ['Watch it.', 'Keep walking.', 'Real cute. Move along.'];
function flipping() { return (P.flipT || 0) > 0 && !P.aiming && !P.dead && !(P.handsUp > 0); }
function startFlip() {
  if (MODE !== 'play' || P.dead || P.handsUp > 0) return;
  const fresh = !((P.flipT || 0) > 0);
  P.flipT = Math.max(P.flipT || 0, 2.4); NET.presT = 0;
  if (fresh) flipReact();
}
// called every frame from updatePlayer; holding the key keeps it up
function tickFlip(dt) {
  if ((keys.KeyT || TOUCH.flip) && MODE === 'play') P.flipT = Math.max(P.flipT || 0, 0.25);
  P.flipT = Math.max(0, (P.flipT || 0) - dt);
  P.flipK = lerp(P.flipK || 0, flipping() ? 1 : 0, 1 - Math.exp(-dt * 12));
}
// the closest people on the street turn round, and one of them says something
function flipReact() {
  const px = P.pos.x, pz = P.pos.z, d = p => Math.hypot(p.pos.x - px, p.pos.z - pz);
  const near = PEDS.filter(p => p.state === 'walk' && !(p.flipBackT > 0) && d(p) < 15).sort((a, b) => d(a) - d(b)).slice(0, 2);
  near.forEach((p, i) => { p.flipDelay = 0.45 + i * 0.5 + Math.random() * 0.3; p.flipBackT = 2.4; p.flipSay = i === 0 && Math.random() < 0.75; });
  if (!near.length && COPS.some(c => c.state !== 'down' && d(c) < 14)) setTimeout(() => say('Officer', COP_LINES[Math.floor(Math.random() * COP_LINES.length)], '#8fb4ff'), 700);
}
// per pedestrian, from updatePeds; returns true while they are answering back
function pedFlipBack(p, dt) {
  if (!(p.flipBackT > 0)) return false;
  if (p.flipDelay > 0) { p.flipDelay -= dt; return false; }
  p.flipBackT -= dt;
  p.yaw += angDiff(p.yaw, Math.atan2(P.pos.x - p.pos.x, P.pos.z - p.pos.z)) * (1 - Math.exp(-dt * 8));
  if (p.flipSay) { p.flipSay = false; say('Passerby', FLIP_LINES[Math.floor(Math.random() * FLIP_LINES.length)], '#9fb0c0'); }
  return true;
}

/* ---- an arm out of the driver's window (yours, and other players') ---- */
function buildWinArm(o) {
  const g = new THREE.Group();
  const sleeve = _vmMat(o.top === 'varsity' ? o.jacket2 : o.jacket), skin = _vmMat(o.skin);
  const up = new THREE.Mesh(VM_CYL, sleeve), fore = new THREE.Mesh(VM_CYL, sleeve), hand = new THREE.Mesh(HG.hand, skin), finger = new THREE.Mesh(HG.finger, skin);
  g.add(up, fore, hand, finger);
  g.traverse(m => { if (m.isMesh) { m.frustumCulled = false; m.castShadow = true; } });
  g.visible = false; scene.add(g);
  return { g, up, fore, hand, finger };
}
function dropWinArm(A) { if (!A) return; scene.remove(A.g); A.g.traverse(m => { if (m.isMesh) m.material.dispose(); }); }
// k: 0 = hand resting on the door, 1 = arm up out of the window.
// fp: seen from the driver's seat the hand stays in the window opening; from outside it goes up past the roof line
const _fDir = new THREE.Vector3();
function poseWinArm(A, v, k, fp) {
  A.g.visible = k > 0.04 && !v.dead;
  if (!A.g.visible) return;
  if (v._cgM !== v.model) { v._cg = carGeom(v.sp); v._cgM = v.model; }
  const G = v._cg, W = v.sp.wid, xD = W * 0.21, eyeY = Math.max(G.yWB + 0.32, G.roofY - 0.26), eyeZ = G.zWB - 0.95;
  const jab = Math.sin(REAL_T * 9) * 0.02 * k;
  const SH = [xD + 0.17, eyeY - 0.22, eyeZ + 0.02];
  const E = fp ? [lerp(W / 2 - 0.06, W / 2 - 0.01, k), G.yWB + lerp(0.0, 0.1, k), eyeZ + lerp(0.25, 0.46, k)]
    : [lerp(W / 2 - 0.06, W / 2 + 0.08, k), G.yWB + lerp(0.0, 0.12, k), eyeZ + lerp(0.25, 0.4, k)];
  const upY = fp ? eyeY - 0.07 : Math.min(G.roofY + 0.14, G.yWB + 0.62);
  const H = fp ? [lerp(W / 2 - 0.08, W / 2 + 0.08, k), lerp(G.yWB + 0.05, upY, k) + jab, eyeZ + lerp(0.45, 0.56, k)]
    : [lerp(W / 2 - 0.08, W / 2 + 0.13, k), lerp(G.yWB + 0.05, upY, k) + jab, eyeZ + lerp(0.45, 0.5, k)];
  A.g.position.set(v.pos.x, 0, v.pos.z); A.g.rotation.set(0, v.yaw, 0);
  setLimb(A.up, SH, E, 0.045);
  setLimb(A.fore, E, H, 0.04);
  const hs = fp ? 0.95 : 1.15; // a touch bigger from outside so it reads at a distance
  A.hand.position.set(H[0], H[1], H[2]); A.hand.scale.set(hs, hs, hs * 0.9); A.finger.scale.setScalar(fp ? 1 : 1.15);
  _fDir.set(H[0] - E[0], H[1] - E[1], H[2] - E[2]).normalize(); _fDir.y += 1.6; _fDir.normalize(); // finger points up, not along the forearm
  A.finger.quaternion.setFromUnitVectors(_limbUp, _fDir);
  A.finger.position.set(H[0], H[1], H[2]).addScaledVector(_fDir, fp ? 0.085 : 0.098);
  A.finger.visible = k > 0.6;
}
function localWinArm() {
  const key = skinKey(cleanSkin(S.skin));
  if (!P.winArm || P.winArmKey !== key) { dropWinArm(P.winArm); P.winArm = buildWinArm(skinHumanOpts(S.skin)); P.winArmKey = key; }
  return P.winArm;
}
function remoteWinArm(R, v) {
  R.flipK = lerp(R.flipK || 0, (R.f & 64) ? 1 : 0, 0.2);
  if (R.flipK > 0.04) {
    if (!R.winArm || R.winArmKey !== R.skKey) { dropWinArm(R.winArm); R.winArm = buildWinArm(R.hOpts || skinHumanOpts(defaultSkin())); R.winArmKey = R.skKey; }
    poseWinArm(R.winArm, v, R.flipK);
  } else if (R.winArm) R.winArm.g.visible = false;
}

/* ---- first person on foot: your hand comes up into view ---- */
function buildFlipVM() {
  if (FP.flip) camera.remove(FP.flip);
  const o = skinHumanOpts(S.skin), g = new THREE.Group();
  const sleeve = _vmMat(o.top === 'varsity' ? o.jacket2 : o.jacket), cuff = _vmMat(o.jacket2), skin = _vmMat(o.skin);
  const part = (geo, m, sx, sy, sz, x, y, z) => { const me = new THREE.Mesh(geo, m); me.scale.set(sx, sy, sz); me.position.set(x, y, z); g.add(me); return me; };
  // back of a left hand facing you: fist, folded knuckles, thumb tucked in front, middle finger up
  part(HG.hand, skin, 1.0, 0.9, 0.72, 0, 0, 0);
  for (const [x, y] of [[0.027, 0.036], [-0.024, 0.036], [-0.043, 0.026]]) part(HG.hand, skin, 0.27, 0.27, 0.3, x, y, -0.006);
  part(HG.finger, skin, 0.86, 0.86, 0.86, 0, 0.085, -0.004);
  part(HG.hand, skin, 0.3, 0.42, 0.3, 0.046, 0.0, -0.022);
  limb(g, VM_CYL, cuff, [0, -0.045, 0.01], [0.004, -0.08, 0.02], 0.042);
  limb(g, VM_CYL, sleeve, [0.004, -0.075, 0.02], [0.05, -0.42, 0.16], 0.046);
  if (o.watch) { const w = new THREE.Mesh(HG.watch, _vmMat(0xd4a640)); w.scale.setScalar(0.7); w.position.set(0, -0.06, 0.012); g.add(w); }
  g.traverse(m => { if (m.isMesh) { m.castShadow = false; m.frustumCulled = false; } });
  g.visible = false; camera.add(g);
  FP.flip = g; FP.flipKey = skinKey(cleanSkin(S.skin));
}
function updateGestures() {
  const k = P.flipK || 0, live = MODE === 'play' || MODE === 'phone';
  if (P.car && live && k > 0.04) poseWinArm(localWinArm(), P.car, k, fpActive());
  else if (P.winArm) P.winArm.g.visible = false;
  const fpFoot = !P.car && live && fpActive() && k > 0.04;
  if (fpFoot && (!FP.flip || FP.flipKey !== skinKey(cleanSkin(S.skin)))) buildFlipVM();
  if (FP.flip) {
    FP.flip.visible = fpFoot;
    if (fpFoot) { FP.flip.position.set(-0.15, lerp(-0.5, -0.07, k) + Math.sin(REAL_T * 9) * 0.008, -0.4); FP.flip.rotation.set(0.12, 0.25, 0.08); }
  }
}
