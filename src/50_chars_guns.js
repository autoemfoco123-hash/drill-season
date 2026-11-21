
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
};
const SHADOW_MAT = new THREE.MeshBasicMaterial({ color: 0x000000, transparent: true, opacity: 0.32, depthWrite: false });
function buildHuman(o) {
  const g = new THREE.Group();
  const mats = [];
  const M = (c, emi) => { const m = new THREE.MeshLambertMaterial({ color: c }); if (emi) m.emissive = new THREE.Color(emi); mats.push(m); return m; };
  const mJ = M(o.jacket), mJ2 = M(o.jacket2 || o.jacket), mP = M(o.pants), mS = M(o.skin), mH = M(o.hat), mShoe = M(o.shoes || 0x15171a);
  const root = new THREE.Group(); g.add(root);
  const hips = new THREE.Group(); hips.position.y = 0.92; root.add(hips);
  const spine = new THREE.Group(); hips.add(spine);
  const torso = new THREE.Mesh(HG.torso, mJ); torso.position.y = 0.36; torso.scale.set(1.12, 1, 0.8); spine.add(torso);
  for (const y of [0.2, 0.42]) { const r = new THREE.Mesh(HG.puff, mJ2); r.rotation.x = Math.PI / 2; r.position.y = y; r.scale.set(1.13, 0.82, 1); spine.add(r); }
  if (o.coat) { const c = new THREE.Mesh(HG.coat, mJ); c.position.y = 0.05; c.scale.set(1, 1, 0.82); spine.add(c); }
  if (o.chain) { const ch = new THREE.Mesh(HG.chain, M(0xd4a640, 0x3a2a08)); ch.rotation.x = 1.25; ch.position.set(0, 0.5, 0.12); spine.add(ch); }
  if (o.pack) { const p = new THREE.Mesh(HG.pack, M(o.pack)); p.position.set(0, 0.36, -0.24); spine.add(p); }
  if (o.badge) { const b = new THREE.Mesh(HG.badge, M(0xd4a640, 0x2a1a04)); b.position.set(0.12, 0.52, 0.2); spine.add(b); }
  const headG = new THREE.Group(); headG.position.y = 0.78; spine.add(headG);
  const head = new THREE.Mesh(HG.head, mS); head.position.y = 0.06; head.scale.set(0.95, 1.05, 1); headG.add(head);
  if (o.mask) { const mk = new THREE.Mesh(HG.mask, M(o.mask)); mk.position.y = 0.06; mk.scale.set(0.97, 1.06, 1.03); headG.add(mk); }
  if (o.hood) { const hd = new THREE.Mesh(HG.hood, mJ2); hd.position.set(0, -0.02, -0.02); hd.rotation.x = Math.PI / 2; headG.add(hd); }
  if (o.cap) { const cp = new THREE.Mesh(HG.capTop, mH); cp.position.y = 0.15; headG.add(cp); const br = new THREE.Mesh(HG.brim, mH); br.position.set(0, 0.11, 0.12); headG.add(br); }
  else if (o.hat !== null) {
    const hat = new THREE.Mesh(HG.beanie, mH); hat.position.y = 0.085; headG.add(hat);
    if (o.pom) { const pm = new THREE.Mesh(HG.pom, M(o.pom)); pm.position.y = 0.23; headG.add(pm); }
  }
  const mkLeg = side => {
    const thigh = new THREE.Group(); thigh.position.set(0.115 * side, 0.02, 0); hips.add(thigh);
    const tm = new THREE.Mesh(HG.thigh, mP); tm.position.y = -0.22; thigh.add(tm);
    const knee = new THREE.Group(); knee.position.y = -0.45; thigh.add(knee);
    const sm = new THREE.Mesh(HG.shin, mP); sm.position.y = -0.2; knee.add(sm);
    const shoe = new THREE.Mesh(HG.shoe, mShoe); shoe.position.set(0, -0.42, 0.045); knee.add(shoe);
    return { thigh, knee };
  };
  const mkArm = side => {
    const sh = new THREE.Group(); sh.position.set(0.31 * side, 0.6, 0); spine.add(sh);
    const um = new THREE.Mesh(HG.upper, mJ); um.position.y = -0.15; sh.add(um);
    const elbow = new THREE.Group(); elbow.position.y = -0.3; sh.add(elbow);
    const fm = new THREE.Mesh(HG.fore, mJ); fm.position.y = -0.13; elbow.add(fm);
    const hand = new THREE.Group(); hand.position.y = -0.29; elbow.add(hand);
    const hm = new THREE.Mesh(HG.hand, mS); hand.add(hm);
    return { sh, elbow, hand };
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
