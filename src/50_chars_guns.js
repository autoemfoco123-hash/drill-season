
/* =========================================================
   CHARACTERS (primitive humanoids)
   ========================================================= */
const HG = {
  torso: new THREE.CapsuleGeometry(0.25, 0.36, 4, 10),
  puff: new THREE.TorusGeometry(0.255, 0.045, 6, 16),
  head: new THREE.SphereGeometry(0.13, 14, 10),
  beanie: new THREE.SphereGeometry(0.142, 14, 8, 0, TAU, 0, Math.PI * 0.55),
  pom: new THREE.SphereGeometry(0.045, 8, 6),
  hood: new THREE.TorusGeometry(0.12, 0.05, 6, 12),
  thigh: new THREE.CapsuleGeometry(0.088, 0.3, 3, 8),
  shin: new THREE.CapsuleGeometry(0.078, 0.3, 3, 8),
  upper: new THREE.CapsuleGeometry(0.078, 0.22, 3, 8),
  fore: new THREE.CapsuleGeometry(0.066, 0.2, 3, 8),
  hand: new THREE.SphereGeometry(0.055, 8, 6),
  finger: new THREE.CapsuleGeometry(0.015, 0.072, 3, 8),
  shoe: new THREE.BoxGeometry(0.13, 0.09, 0.27),
  pack: new THREE.BoxGeometry(0.3, 0.36, 0.14),
  chain: new THREE.TorusGeometry(0.13, 0.014, 5, 16),
  coat: new THREE.CylinderGeometry(0.27, 0.34, 0.6, 10, 1, true),
  mug: new THREE.CylinderGeometry(0.045, 0.04, 0.11, 10),
  shadow: new THREE.CircleGeometry(0.42, 16),
  capTop: new THREE.CylinderGeometry(0.15, 0.145, 0.09, 12),
  brim: new THREE.BoxGeometry(0.22, 0.02, 0.12),
  badge: new THREE.BoxGeometry(0.06, 0.07, 0.02),
  mask: new THREE.SphereGeometry(0.138, 14, 10, 0, TAU, Math.PI * 0.42, Math.PI * 0.4),
  eye: new THREE.SphereGeometry(0.019, 6, 4),
  brow: new THREE.BoxGeometry(0.052, 0.013, 0.014),
  hairCap: new THREE.SphereGeometry(0.137, 14, 8, 0, TAU, 0, Math.PI * 0.5),
  afro: new THREE.SphereGeometry(0.19, 12, 10),
  loc: new THREE.CylinderGeometry(0.019, 0.014, 0.27, 5),
  braid: new THREE.CylinderGeometry(0.024, 0.015, 0.32, 5),
  ball: new THREE.SphereGeometry(0.05, 7, 5),
  durag: new THREE.SphereGeometry(0.142, 14, 8, 0, TAU, 0, Math.PI * 0.56),
  tail: new THREE.BoxGeometry(0.06, 0.24, 0.012),
  bucketTop: new THREE.CylinderGeometry(0.125, 0.148, 0.11, 12),
  bucketBrim: new THREE.CylinderGeometry(0.225, 0.225, 0.016, 16),
  band: new THREE.TorusGeometry(0.152, 0.014, 5, 16, Math.PI),
  cup: new THREE.CylinderGeometry(0.058, 0.058, 0.045, 10),
  shades: new THREE.BoxGeometry(0.21, 0.048, 0.02),
  beard: new THREE.BoxGeometry(0.17, 0.075, 0.07),
  hoodUp: new THREE.SphereGeometry(0.172, 12, 10, 0, TAU, 0, Math.PI * 0.64),
  hoodDown: new THREE.TorusGeometry(0.13, 0.055, 6, 12),
  pocket: new THREE.BoxGeometry(0.075, 0.1, 0.03),
  stripe: new THREE.BoxGeometry(0.022, 0.24, 0.022),
  collar: new THREE.TorusGeometry(0.145, 0.032, 5, 12),
  boot: new THREE.BoxGeometry(0.145, 0.19, 0.29),
  ankle: new THREE.CylinderGeometry(0.078, 0.084, 0.13, 8),
  sole: new THREE.BoxGeometry(0.138, 0.03, 0.28),
  bag: new THREE.BoxGeometry(0.21, 0.15, 0.075),
  strap: new THREE.BoxGeometry(0.03, 0.66, 0.012),
  watch: new THREE.BoxGeometry(0.065, 0.032, 0.065),
  zip: new THREE.BoxGeometry(0.012, 0.42, 0.012),
};
const SHADOW_MAT = new THREE.MeshBasicMaterial({ color: 0x000000, transparent: true, opacity: 0.32, depthWrite: false });
// Options (all optional): skin, hair/hairCol, beard, head (none|beanie|cap|capback|durag|bucket|hood|skimask|headphones),
// hat (headwear colour), pom, top (puffer|hoodie|parka|track|varsity|leather), jacket/jacket2, pantsStyle (jeans|cargo|joggers|ski),
// pants/pants2, shoe (sneaker|high|boot), shoes, chain, watch, glasses, bag (back|cross), pack/bagCol, build (0 slim|1|2 heavy),
// plus the older flags: cap, hood, coat, mask, badge, scale.
function buildHuman(o) {
  const g = new THREE.Group();
  const mats = [];
  const M = (c, emi) => { const m = new THREE.MeshLambertMaterial({ color: c }); if (emi) m.emissive = new THREE.Color(emi); mats.push(m); return m; };
  const add = (parent, geo, mat, x, y, z, rx, ry, rz, sx, sy, sz) => { const m = new THREE.Mesh(geo, mat); m.position.set(x || 0, y || 0, z || 0); if (rx || ry || rz) m.rotation.set(rx || 0, ry || 0, rz || 0); if (sx) m.scale.set(sx, sy === undefined ? sx : sy, sz === undefined ? sx : sz); parent.add(m); return m; };
  const top = o.top || (o.coat ? 'parka' : 'puffer');
  const head = o.head || (o.cap ? 'cap' : o.hat === null || o.hat === undefined ? 'none' : 'beanie');
  const bw = o.build === 0 ? 0.92 : o.build === 2 ? 1.15 : 1;
  const mJ = M(o.jacket), mJ2 = M(o.jacket2 || o.jacket), mP = M(o.pants), mS = M(o.skin), mH = M(o.hat !== undefined && o.hat !== null ? o.hat : 0x15171a), mShoe = M(o.shoes || 0x15171a);
  const mHair = M(o.hairCol !== undefined ? o.hairCol : 0x0f0d0c), mDark = M(0x0b0b0d), mGold = M(0xd4a640, 0x3a2a08);
  const mSleeve = top === 'varsity' ? mJ2 : mJ, mHand = o.gloves !== undefined ? M(o.gloves) : mS;
  const root = new THREE.Group(); g.add(root);
  const hips = new THREE.Group(); hips.position.y = 0.92; root.add(hips);
  const spine = new THREE.Group(); hips.add(spine);
  add(spine, HG.torso, mJ, 0, 0.36, 0, 0, 0, 0, 1.12 * bw, 1, 0.8 * bw);
  if (top === 'puffer') for (const y of [0.2, 0.42]) add(spine, HG.puff, mJ2, 0, y, 0, Math.PI / 2, 0, 0, 1.13 * bw, 0.82, 1);
  if (top === 'parka') { add(spine, HG.coat, mJ, 0, 0.05, 0, 0, 0, 0, bw, 1, 0.82 * bw); add(spine, HG.puff, mJ2, 0, 0.42, 0, Math.PI / 2, 0, 0, 1.13 * bw, 0.82, 1); }
  if (top === 'hoodie') add(spine, HG.pocket, mJ2, 0, 0.2, 0.2 * bw, 0, 0, 0, 2.2, 1, 1);
  if (top === 'track' || top === 'leather' || top === 'varsity') add(spine, HG.zip, top === 'track' ? mJ2 : mDark, 0, 0.36, 0.205 * bw);
  if (top === 'leather' || top === 'varsity') add(spine, HG.collar, mJ2, 0, 0.6, 0, Math.PI / 2, 0, 0, 1, 1, 0.7);
  if (o.chain) add(spine, HG.chain, mGold, 0, 0.5, 0.12, 1.25);
  if (o.pack || o.bag === 'back') add(spine, HG.pack, M(o.pack || o.bagCol || 0x15171a), 0, 0.36, -0.24 * bw);
  if (o.bag === 'cross') { const mb = M(o.bagCol || 0x15171a); add(spine, HG.strap, mb, 0, 0.36, 0.205 * bw, 0, 0, 0.75); add(spine, HG.bag, mb, -0.17, 0.12, 0.17 * bw); }
  if (o.badge) add(spine, HG.badge, mGold, 0.12, 0.52, 0.2);
  const headG = new THREE.Group(); headG.position.y = 0.78; spine.add(headG);
  add(headG, HG.head, mS, 0, 0.06, 0, 0, 0, 0, 0.95, 1.05, 1);
  // face
  const skimask = head === 'skimask';
  if (skimask) add(headG, HG.head, mH, 0, 0.062, 0, 0, 0, 0, 1.0, 1.1, 1.05);
  for (const s of [-1, 1]) { add(headG, HG.eye, mDark, s * 0.045, 0.085, skimask ? 0.128 : 0.118); if (!skimask) add(headG, HG.brow, mHair, s * 0.047, 0.118, 0.115, 0, 0, s * 0.08); }
  if (o.beard && !skimask && !o.mask) add(headG, HG.beard, mHair, 0, -0.005, 0.07);
  if (o.mask) add(headG, HG.mask, M(o.mask), 0, 0.06, 0, 0, 0, 0, 0.97, 1.06, 1.03);
  if (o.glasses) add(headG, HG.shades, mDark, 0, 0.087, skimask ? 0.135 : 0.124);
  // hair (what shows depends on the headwear)
  const hair = o.hair || 'none', coversTop = head === 'beanie' || head === 'durag' || head === 'skimask' || head === 'hood' || head === 'bucket';
  if (hair !== 'none' && !skimask) {
    if (hair === 'afro') { if (coversTop || head === 'cap' || head === 'capback') add(headG, HG.afro, mHair, 0, 0.06, -0.02, 0, 0, 0, 0.9, 0.62, 0.9); else add(headG, HG.afro, mHair, 0, 0.13, -0.01); }
    else if (!coversTop) add(headG, HG.hairCap, mHair, 0, 0.07, -0.003, 0, 0, 0, hair === 'buzz' ? 0.99 : 1.04, hair === 'buzz' ? 0.96 : 1.08, hair === 'buzz' ? 0.99 : 1.06);
    if (hair === 'twists' && !coversTop) for (let k = 0; k < 9; k++) { const a = k / 9 * TAU; add(headG, HG.ball, mHair, Math.cos(a) * 0.08, 0.17 + (k % 2) * 0.02, Math.sin(a) * 0.08 - 0.01); }
    if (hair === 'locs') for (let k = 0; k < 11; k++) { const a = Math.PI * 0.15 + k / 10 * Math.PI * 1.7; const x = Math.sin(a) * 0.12, z = -Math.cos(a) * 0.12; if (z > 0.06) continue; add(headG, HG.loc, mHair, x, -0.02, z, -z * 1.2, 0, x * 1.4); }
    if (hair === 'braids') for (const s of [-1, 1]) add(headG, HG.braid, mHair, s * 0.06, -0.06, -0.11, 0.35, 0, s * 0.1);
  }
  // headwear
  if (head === 'beanie') { add(headG, HG.beanie, mH, 0, 0.085, 0); if (o.pom) add(headG, HG.pom, M(typeof o.pom === 'number' && o.pom > 1 ? o.pom : (o.hat || 0xffffff)), 0, 0.23, 0); }
  else if (head === 'cap' || head === 'capback') { add(headG, HG.capTop, mH, 0, 0.15, 0); add(headG, HG.brim, mH, 0, 0.11, head === 'cap' ? 0.12 : -0.12); }
  else if (head === 'durag') { add(headG, HG.durag, mH, 0, 0.075, 0); add(headG, HG.tail, mH, 0, -0.06, -0.135, 0.15); }
  else if (head === 'bucket') { add(headG, HG.bucketTop, mH, 0, 0.165, 0); add(headG, HG.bucketBrim, mH, 0, 0.115, 0, -0.05); }
  else if (head === 'hood') add(headG, HG.hoodUp, mJ2, 0, 0.06, -0.035, -0.5, 0, 0, 1, 1.05, 1.05);
  else if (head === 'headphones') { add(headG, HG.band, mH, 0, 0.07, 0, 0, Math.PI / 2, 0); for (const s of [-1, 1]) add(headG, HG.cup, mH, s * 0.14, 0.06, 0, 0, 0, Math.PI / 2); }
  if (o.hood || ((top === 'hoodie' || top === 'parka') && head !== 'hood')) add(headG, HG.hoodDown, mJ2, 0, -0.03, -0.04, Math.PI / 2 - 0.3);
  const legScale = o.pantsStyle === 'ski' ? 1.16 : 1;
  const mkLeg = side => {
    const thigh = new THREE.Group(); thigh.position.set(0.115 * side * bw, 0.02, 0); hips.add(thigh);
    add(thigh, HG.thigh, mP, 0, -0.22, 0, 0, 0, 0, legScale * bw, 1, legScale * bw);
    if (o.pantsStyle === 'cargo') add(thigh, HG.pocket, mP, side * 0.09 * bw, -0.26, 0, 0, side * 0.2, 0, 1.2, 1.1, 1.4);
    if (o.pantsStyle === 'joggers' || o.pantsStyle === 'track') add(thigh, HG.stripe, M(o.pants2 || 0xe8e8ea), side * 0.088 * bw, -0.22, 0, 0, 0, 0, 1, 1.5, 1);
    const knee = new THREE.Group(); knee.position.y = -0.45; thigh.add(knee);
    add(knee, HG.shin, mP, 0, -0.2, 0, 0, 0, 0, legScale, 1, legScale);
    if (o.pantsStyle === 'joggers' || o.pantsStyle === 'track') add(knee, HG.stripe, M(o.pants2 || 0xe8e8ea), side * 0.078, -0.18, 0, 0, 0, 0, 1, 1.3, 1);
    const shoe = o.shoe || 'sneaker';
    if (shoe === 'boot') add(knee, HG.boot, mShoe, 0, -0.39, 0.04);
    else { add(knee, HG.shoe, mShoe, 0, -0.42, 0.045); add(knee, HG.sole, M(shoe === 'high' ? 0xe8e8ea : 0xf2f2f2), 0, -0.468, 0.045); if (shoe === 'high') add(knee, HG.ankle, mShoe, 0, -0.33, 0.01); }
    return { thigh, knee };
  };
  const mkArm = side => {
    const sh = new THREE.Group(); sh.position.set(0.31 * side * bw, 0.6, 0); spine.add(sh);
    add(sh, HG.upper, mSleeve, 0, -0.15, 0, 0, 0, 0, bw, 1, bw);
    if (top === 'track') add(sh, HG.stripe, mJ2, side * 0.07, -0.15, 0);
    const elbow = new THREE.Group(); elbow.position.y = -0.3; sh.add(elbow);
    add(elbow, HG.fore, mSleeve, 0, -0.13, 0, 0, 0, 0, bw, 1, bw);
    if (top === 'track') add(elbow, HG.stripe, mJ2, side * 0.06, -0.12, 0, 0, 0, 0, 1, 0.9, 1);
    if (o.watch && side < 0) add(elbow, HG.watch, mGold, 0, -0.24, 0);
    const hand = new THREE.Group(); hand.position.y = -0.29; elbow.add(hand);
    add(hand, HG.hand, mHand);
    const finger = add(hand, HG.finger, mHand, 0, -0.09, 0.006); finger.visible = false; // only for the middle-finger gesture
    return { sh, elbow, hand, finger };
  };
  const L = mkLeg(-1), R = mkLeg(1), AL = mkArm(-1), AR = mkArm(1);
  const shadow = new THREE.Mesh(HG.shadow, SHADOW_MAT); shadow.rotation.x = -Math.PI / 2; shadow.position.y = 0.03; g.add(shadow);
  if (o.scale) root.scale.setScalar(o.scale);
  g.traverse(m => { if (m.isMesh) m.frustumCulled = true; });
  return { group: g, root, hips, spine, headG, L, R, AL, AR, mats, phase: Math.random() * 10, scale: o.scale || 1, shadow };
}
// pose: {speed, crouch, aim(0..1), pitch, down(0..1), wave, carry}
function animHuman(h, dt, pose) {
  const sp = pose.speed || 0;
  h.phase += dt * (sp > 0.2 ? (3.2 + sp * 1.25) : 0);
  const ph = h.phase;
  const amp = clamp(sp / 5, 0, 1.15);
  const cr = pose.crouch ? 1 : 0;
  h.cr = lerp(h.cr || 0, cr, 1 - Math.exp(-dt * 12));
  const c = h.cr;
  const hipY = lerp(0.92, 0.56, c) - Math.abs(Math.sin(ph)) * 0.04 * amp;
  h.hips.position.y = hipY;
  const swing = Math.sin(ph) * 0.75 * amp;
  h.L.thigh.rotation.x = lerp(swing, -1.25 + swing * 0.3, c);
  h.R.thigh.rotation.x = lerp(-swing, -1.25 - swing * 0.3, c);
  h.L.knee.rotation.x = lerp(Math.max(0, -Math.sin(ph + 0.6)) * 1.1 * amp + 0.05, 2.0, c);
  h.R.knee.rotation.x = lerp(Math.max(0, Math.sin(ph + 0.6)) * 1.1 * amp + 0.05, 2.0, c);
  h.spine.rotation.x = lerp(0.06 * amp, 0.35, c);
  const aim = pose.aim || 0;
  const pitch = pose.pitch || 0;
  // right arm: aim forward or swing
  const armSwing = Math.sin(ph) * 0.55 * amp;
  const relaxR = pose.carry ? -0.45 : armSwing * -1;
  h.AR.sh.rotation.x = lerp(relaxR, -Math.PI / 2 - pitch - h.spine.rotation.x, aim);
  h.AR.sh.rotation.z = lerp(0.08, 0.0, aim);
  h.AR.elbow.rotation.x = lerp(pose.carry ? -0.5 : -0.25, -0.05, aim);
  h.AL.sh.rotation.x = lerp(armSwing, -Math.PI / 2 - pitch - h.spine.rotation.x + 0.15, aim * (pose.twoHand ? 1 : 0.85));
  h.AL.sh.rotation.z = lerp(-0.08, -0.55, aim);
  h.AL.elbow.rotation.x = lerp(-0.25, -0.35, aim);
  if (pose.wave) { h.AL.sh.rotation.x = -2.6; h.AL.sh.rotation.z = -0.3 + Math.sin(REAL_T * 8) * 0.25; h.AL.elbow.rotation.x = -0.4; }
  if (pose.flip) { const j = Math.sin(REAL_T * 9) * 0.06; h.AL.sh.rotation.x = -1.5 + j; h.AL.sh.rotation.z = -0.22; h.AL.elbow.rotation.x = -1.3; }
  if (h.AL.finger) h.AL.finger.visible = !!pose.flip;
  if (pose.mug) { h.AL.sh.rotation.x = -0.9; h.AL.elbow.rotation.x = -1.4; h.AL.sh.rotation.z = -0.1; }
  if (pose.hands) { for (const A of [h.AL, h.AR]) { A.sh.rotation.x = -2.9; A.elbow.rotation.x = -0.35; } h.AL.sh.rotation.z = -0.25; h.AR.sh.rotation.z = 0.25; }
  if (pose.pose) { h.AR.sh.rotation.x = -1.9; h.AR.elbow.rotation.x = -1.2; h.AR.sh.rotation.z = 0.3; h.AL.sh.rotation.x = -0.4; h.spine.rotation.x = -0.08; }
  h.headG.rotation.x = lerp(0, -pitch * 0.6, aim);
  // downed: fall backwards
  const dn = pose.down || 0;
  h.root.rotation.x = -dn * Math.PI / 2 * 0.96;
  h.root.position.y = dn * 0.18;
  h.root.position.z = -dn * 0.5;
  if (pose.shiver) h.spine.rotation.z = Math.sin(REAL_T * 40) * 0.015 * pose.shiver;
  else h.spine.rotation.z = 0;
}

/* =========================================================
   WEAPONS - fictional brands, game-style parts
   ========================================================= */
const WEAPONS = {
  k9: { name: 'Kestrel "Wren" K9', short: 'K9', cls: 'Compact pistol · Kestrel Arms', dmg: 24, rpm: 330, auto: false, spread: 2.4, aimSpread: 0.75, range: 46, mag: 12, reload: 1.35, recoil: 1.0, noise: 2.0, pellets: 1, zoom: 1.3, aimSpeed: 1, price: 0, buzz: 0, ammo: { n: 24, price: 30 } },
  draft: { name: 'Graywater "Draft"', short: 'Draft', cls: 'Submachine gun · Graywater Works', dmg: 15, rpm: 780, auto: true, spread: 3.6, aimSpread: 1.5, range: 40, mag: 30, reload: 2.1, recoil: 0.55, noise: 1.4, pellets: 1, zoom: 1.35, aimSpeed: 0.95, price: 1800, buzz: 30, ammo: { n: 60, price: 45 } },
  plow: { name: 'Ostrava "Snowplow" 12', short: 'Snowplow', cls: 'Pump shotgun · Ostrava Ironworks', dmg: 11, rpm: 70, auto: false, spread: 6.5, aimSpread: 4.4, range: 24, mag: 6, reload: 2.8, recoil: 3.2, noise: 3.6, pellets: 9, zoom: 1.2, aimSpeed: 0.85, price: 3000, buzz: 50, ammo: { n: 12, price: 45 } },
};
const PARTS = {
  optic: [
    { id: 'iron', name: 'Iron sights', price: 0, note: '1.3x' },
    { id: 'reflex', name: 'Reflex', price: 250, mods: { aimSpread: 0.8, zoom: 0.25 }, note: 'Tighter aim' },
    { id: 'holo', name: 'Holo', price: 450, mods: { aimSpread: 0.62, zoom: 0.6, spread: 1.1 }, note: 'Zoom, wider hip' },
  ],
  barrel: [
    { id: 'short', name: 'Short', price: 150, mods: { spread: 1.15, aimSpread: 1.12, range: 0.8, aimSpeed: 1.3 }, note: 'Fast handling' },
    { id: 'standard', name: 'Standard', price: 0, note: 'Balanced' },
    { id: 'long', name: 'Long', price: 300, mods: { spread: 0.85, aimSpread: 0.8, range: 1.3, aimSpeed: 0.78 }, note: 'Range, slower aim' },
  ],
  mag: [
    { id: 'std', name: 'Standard', price: 0, note: 'Quick reload' },
    { id: 'ext', name: 'Extended', price: 300, mods: { mag: 1.5, reload: 1.3 }, note: '+50% rounds' },
  ],
  muzzle: [
    { id: 'none', name: 'None', price: 0, note: 'Loud' },
    { id: 'comp', name: 'Compensator', price: 250, mods: { recoil: 0.55, noise: 1.15 }, note: 'Less kick, louder' },
    { id: 'supp', name: 'Suppressor', price: 650, buzz: 40, mods: { noise: 0.3, recoil: 0.9, range: 0.9, dmg: 0.92 }, note: 'Quiet, less Heat' },
  ],
  finish: [
    { id: 'gunmetal', name: 'Gunmetal', price: 0, c: 0x41474e, m: 0.85, r: 0.38 },
    { id: 'frost', name: 'Frost', price: 120, c: 0xdbe7ef, m: 0.35, r: 0.5 },
    { id: 'bronze', name: 'Bronze', price: 200, c: 0x8c5b2e, m: 0.9, r: 0.33 },
    { id: 'ice', name: 'Ice', price: 300, c: 0x9fd8ff, m: 0.15, r: 0.06, e: 0x0c2a40 },
    { id: 'crimson', name: 'Crimson', price: 250, c: 0x7c1220, m: 0.6, r: 0.32 },
    { id: 'gold', name: 'Gold', price: 800, buzz: 70, c: 0xd9a93a, m: 1.0, r: 0.22 },
  ],
  charm: [
    { id: 'none', name: 'None', price: 0 },
    { id: 'dice', name: 'Dice', price: 60 },
    { id: 'flake', name: 'Snowflake', price: 60 },
    { id: 'mic', name: 'Mic', price: 90 },
    { id: 'feather', name: 'Hawk feather', price: 120 },
    { id: 'crown', name: 'Crown', price: 150 },
  ],
};
const partOf = (cat, id) => PARTS[cat].find(p => p.id === id) || PARTS[cat][0];
function gunStats(id, cfgOverride) {
  const W = WEAPONS[id], cfg = cfgOverride || S.guns[id].cfg;
  const s = Object.assign({}, W);
  for (const cat of ['optic', 'barrel', 'mag', 'muzzle']) {
    const p = partOf(cat, cfg[cat]);
    if (p.mods) for (const k in p.mods) { if (k === 'zoom') s.zoom += p.mods[k]; else s[k] *= p.mods[k]; }
  }
  s.mag = Math.round(s.mag);
  s.heatPerShot = s.noise * 0.45;
  return s;
}
const GUNMATS = {};
function finishMat(id) {
  if (GUNMATS[id]) return GUNMATS[id];
  const F = partOf('finish', id);
  const m = new THREE.MeshStandardMaterial({ color: F.c, metalness: F.m, roughness: F.r, envMap: ENV, envMapIntensity: 1.25 });
  if (F.e) m.emissive = new THREE.Color(F.e);
  return GUNMATS[id] = m;
}
const GMAT = {
  poly: new THREE.MeshStandardMaterial({ color: 0x1b1e23, metalness: 0.15, roughness: 0.72, envMap: ENV, envMapIntensity: 0.6 }),
  dark: new THREE.MeshStandardMaterial({ color: 0x0d0e10, metalness: 0.7, roughness: 0.45, envMap: ENV }),
  glass: new THREE.MeshStandardMaterial({ color: 0x66c8ff, transparent: true, opacity: 0.35, metalness: 0, roughness: 0.05, envMap: ENV }),
  dot: new THREE.MeshBasicMaterial({ color: 0xff3020 }),
  white: new THREE.MeshStandardMaterial({ color: 0xf2f2ee, roughness: 0.4, envMap: ENV }),
  silver: new THREE.MeshStandardMaterial({ color: 0xc8ccd2, metalness: 1, roughness: 0.25, envMap: ENV }),
  gold: new THREE.MeshStandardMaterial({ color: 0xd9a93a, metalness: 1, roughness: 0.2, envMap: ENV }),
  ice: new THREE.MeshStandardMaterial({ color: 0xbfe6ff, metalness: 0.1, roughness: 0.05, envMap: ENV, emissive: 0x10283a }),
  brown: new THREE.MeshStandardMaterial({ color: 0x6a4424, roughness: 0.7 }),
};
const GBOX = new THREE.BoxGeometry(1, 1, 1), GCYL = new THREE.CylinderGeometry(1, 1, 1, 14), GTOR = new THREE.TorusGeometry(1, 0.28, 5, 10), GCONE = new THREE.ConeGeometry(1, 1, 8);
// builds a gun in local space: origin at the grip, barrel toward +z, up +y
function buildGun(id, cfg) {
  const g = new THREE.Group();
  const fin = finishMat(cfg.finish);
  const box = (w, h, d, x, y, z, m, rx) => { const me = new THREE.Mesh(GBOX, m); me.scale.set(w, h, d); me.position.set(x, y, z); if (rx) me.rotation.x = rx; g.add(me); return me; };
  const cyl = (r, len, x, y, z, m) => { const me = new THREE.Mesh(GCYL, m); me.scale.set(r, len, r); me.rotation.x = Math.PI / 2; me.position.set(x, y, z + len / 2); g.add(me); return me; };
  let tipZ, boreY, railY, railZ, charmAt;
  const bl = cfg.barrel;
  if (id === 'k9') {
    box(0.032, 0.11, 0.048, 0, -0.012, -0.018, GMAT.poly, 0.22);
    box(0.03, 0.03, 0.17, 0, 0.05, 0.04, GMAT.poly);
    box(0.035, 0.032, 0.19, 0, 0.079, 0.04, fin);
    for (let i = 0; i < 4; i++) box(0.036, 0.022, 0.004, 0, 0.08, -0.035 + i * 0.008, GMAT.dark);
    box(0.006, 0.006, 0.05, 0, 0.022, 0.055, GMAT.poly); box(0.006, 0.03, 0.006, 0, 0.034, 0.078, GMAT.poly);
    const ext = bl === 'short' ? 0.0 : bl === 'long' ? 0.055 : 0.016;
    tipZ = 0.135 + ext; boreY = 0.075; railY = 0.096; railZ = 0.0;
    if (ext > 0) cyl(0.008, ext, 0, boreY, 0.135, GMAT.dark);
    if (cfg.mag === 'ext') box(0.03, 0.04, 0.042, 0, -0.085, -0.032, GMAT.poly, 0.22);
    charmAt = [0, -0.07, -0.05];
  } else if (id === 'draft') {
    box(0.046, 0.065, 0.3, 0, 0.06, 0.05, fin);
    box(0.02, 0.008, 0.22, 0, 0.096, 0.05, GMAT.dark);
    box(0.032, 0.1, 0.045, 0, -0.01, -0.01, GMAT.poly, 0.25);
    box(0.03, cfg.mag === 'ext' ? 0.22 : 0.15, 0.044, 0, cfg.mag === 'ext' ? -0.07 : -0.035, 0.11, GMAT.poly, 0.12);
    const len = bl === 'short' ? 0.03 : bl === 'long' ? 0.13 : 0.07;
    cyl(0.019, 0.08, 0, 0.06, 0.2, GMAT.dark);
    cyl(0.009, len, 0, 0.06, 0.28, GMAT.dark);
    tipZ = 0.28 + len; boreY = 0.06; railY = 0.104; railZ = 0.03;
    box(0.024, 0.07, 0.026, 0, 0.0, 0.23, GMAT.poly);
    box(0.008, 0.01, 0.22, 0.014, 0.065, -0.2, GMAT.dark); box(0.008, 0.01, 0.22, -0.014, 0.065, -0.2, GMAT.dark);
    box(0.034, 0.095, 0.016, 0, 0.045, -0.31, GMAT.poly);
    charmAt = [0, 0.03, -0.12];
  } else {
    box(0.05, 0.072, 0.24, 0, 0.05, 0.07, fin);
    box(0.032, 0.1, 0.045, 0, -0.01, -0.01, GMAT.poly, 0.32);
    box(0.044, 0.095, 0.3, 0, 0.03, -0.19, GMAT.poly, -0.06);
    const len = bl === 'short' ? 0.36 : bl === 'long' ? 0.66 : 0.5;
    cyl(0.012, len, 0, 0.07, 0.19, fin);
    const tl = Math.min(len - 0.04, cfg.mag === 'ext' ? 0.5 : 0.36);
    cyl(0.012, tl, 0, 0.038, 0.19, GMAT.dark);
    cyl(0.022, 0.15, 0, 0.038, 0.24, GMAT.poly);
    box(0.006, 0.01, 0.006, 0, 0.087, 0.18 + len, GMAT.white);
    tipZ = 0.19 + len; boreY = 0.07; railY = 0.09; railZ = 0.06;
    charmAt = [0, -0.01, -0.07];
  }
  // optics
  if (cfg.optic === 'iron') {
    box(0.014, 0.012, 0.006, 0, railY + 0.004, railZ - 0.05, GMAT.dark);
    box(0.004, 0.012, 0.004, 0, railY + 0.004, tipZ - 0.02, GMAT.dark);
  } else if (cfg.optic === 'reflex') {
    box(0.022, 0.01, 0.034, 0, railY + 0.005, railZ, GMAT.dark);
    box(0.03, 0.004, 0.004, 0, railY + 0.036, railZ + 0.012, GMAT.dark);
    box(0.004, 0.03, 0.004, 0.014, railY + 0.022, railZ + 0.012, GMAT.dark); box(0.004, 0.03, 0.004, -0.014, railY + 0.022, railZ + 0.012, GMAT.dark);
    box(0.026, 0.026, 0.002, 0, railY + 0.022, railZ + 0.012, GMAT.glass);
    box(0.003, 0.003, 0.003, 0, railY + 0.022, railZ + 0.014, GMAT.dot);
  } else {
    box(0.04, 0.008, 0.06, 0, railY + 0.004, railZ, GMAT.dark);
    box(0.004, 0.034, 0.06, 0.018, railY + 0.025, railZ, GMAT.dark); box(0.004, 0.034, 0.06, -0.018, railY + 0.025, railZ, GMAT.dark);
    box(0.04, 0.005, 0.06, 0, railY + 0.044, railZ, GMAT.dark);
    box(0.032, 0.03, 0.002, 0, railY + 0.025, railZ + 0.03, GMAT.glass);
    box(0.004, 0.004, 0.003, 0, railY + 0.025, railZ + 0.031, GMAT.dot);
  }
  // muzzle devices
  if (cfg.muzzle === 'comp') { cyl(id === 'plow' ? 0.017 : 0.012, 0.03, 0, boreY, tipZ, GMAT.dark); box(0.03, 0.004, 0.012, 0, boreY + 0.012, tipZ + 0.015, GMAT.poly); tipZ += 0.03; }
  else if (cfg.muzzle === 'supp') { const L = id === 'plow' ? 0.2 : 0.14; cyl(id === 'plow' ? 0.022 : 0.017, L, 0, boreY, tipZ, GMAT.dark); tipZ += L; }
  // charm
  if (cfg.charm !== 'none') {
    const [cx, cy, cz] = charmAt;
    const ring = new THREE.Mesh(GTOR, GMAT.silver); ring.scale.setScalar(0.006); ring.position.set(cx + 0.02, cy, cz); ring.rotation.y = Math.PI / 2; g.add(ring);
    const ring2 = ring.clone(); ring2.position.y -= 0.011; ring2.rotation.y = 0; g.add(ring2);
    const cg = new THREE.Group(); cg.position.set(cx + 0.02, cy - 0.03, cz); g.add(cg);
    const add = (geo, m, sx, sy, sz, x, y, z, rz) => { const me = new THREE.Mesh(geo, m); me.scale.set(sx, sy, sz); me.position.set(x || 0, y || 0, z || 0); if (rz) me.rotation.z = rz; cg.add(me); };
    if (cfg.charm === 'dice') add(GBOX, GMAT.white, 0.016, 0.016, 0.016);
    if (cfg.charm === 'flake') for (let i = 0; i < 3; i++) add(GBOX, GMAT.ice, 0.032, 0.004, 0.004, 0, 0, 0, i * Math.PI / 3);
    if (cfg.charm === 'mic') { add(GCYL, GMAT.dark, 0.005, 0.03, 0.005, 0, -0.005); const s = new THREE.Mesh(new THREE.SphereGeometry(0.009, 10, 8), GMAT.silver); s.position.y = 0.014; cg.add(s); }
    if (cfg.charm === 'feather') add(GCONE, GMAT.brown, 0.007, 0.045, 0.002, 0, -0.01, 0, Math.PI);
    if (cfg.charm === 'crown') { add(GCYL, GMAT.gold, 0.012, 0.01, 0.012); for (let i = 0; i < 5; i++) { const a = i / 5 * TAU; const c = new THREE.Mesh(GCONE, GMAT.gold); c.scale.set(0.003, 0.01, 0.003); c.position.set(Math.cos(a) * 0.011, 0.009, Math.sin(a) * 0.011); cg.add(c); } }
    g.userData.charm = cg;
  }
  const muzzle = new THREE.Object3D(); muzzle.position.set(0, boreY, tipZ); g.add(muzzle);
  g.userData.muzzle = muzzle;
  return g;
}

/* ---- username nameplates (everyone in Calder is a handle) ---- */
function makeNameplate(text, color, sub) {
  const c = document.createElement('canvas'); c.width = 512; c.height = 128;
  const g = c.getContext('2d');
  g.font = '700 44px "Barlow Semi Condensed", "Segoe UI", Roboto, sans-serif';
  const tw = Math.min(470, g.measureText(text).width);
  const w = tw + 56, x0 = (512 - w) / 2;
  g.fillStyle = 'rgba(5,11,19,.74)';
  g.beginPath(); g.roundRect ? g.roundRect(x0, 18, w, 62, 14) : g.rect(x0, 18, w, 62); g.fill();
  g.fillStyle = color || '#ff9a3c'; g.beginPath(); g.arc(x0 + 22, 49, 7, 0, TAU); g.fill();
  g.fillStyle = '#eef6ff'; g.textAlign = 'left'; g.textBaseline = 'middle'; g.fillText(text, x0 + 38, 50, 470);
  if (sub) { g.font = '600 26px "IBM Plex Mono", monospace'; g.fillStyle = color || '#ff9a3c'; g.textAlign = 'center'; g.fillText(sub, 256, 104); }
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace;
  const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: t, transparent: true, depthWrite: false }));
  s.scale.set(1.9, 0.475, 1); s.renderOrder = 12; s.position.y = 2.15;
  return s;
}
