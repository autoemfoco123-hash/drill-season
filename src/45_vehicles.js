
/* =========================================================
   VEHICLES - low-poly extruded cars, instanced, drivable
   ========================================================= */
const CAR_SPECS = {
  hatch: { name: 'Kestrel Pip', len: 3.95, wid: 1.72, r: 0.31, wb: [0.68, 3.22], lightY: 0.74, acc: 6.2, top: 24, price: 0, buzz: 0,
    body: [[0, .32], [0, .86], [.22, .98], [2.75, .98], [3.72, .8], [3.95, .62], [3.95, .32]], cabin: [[.12, .96], [.36, 1.44], [2.05, 1.46], [2.85, .96]] },
  sedan: { name: 'Graywater Lumen', len: 4.7, wid: 1.82, r: 0.33, wb: [0.85, 3.88], lightY: 0.72, acc: 6.8, top: 28, price: 2400, buzz: 10,
    body: [[0, .32], [0, .8], [.2, .94], [1.3, .98], [3.4, .98], [4.45, .82], [4.7, .66], [4.7, .32]], cabin: [[1.1, .96], [1.85, 1.42], [3.0, 1.43], [3.6, .96]] },
  suv: { name: 'Ostrava Drift', len: 4.85, wid: 1.96, r: 0.4, wb: [0.95, 3.95], lightY: 0.92, acc: 6.4, top: 27, price: 4600, buzz: 25,
    body: [[0, .45], [0, 1.08], [.18, 1.16], [3.6, 1.16], [4.55, 1.02], [4.85, .86], [4.85, .45]], cabin: [[.16, 1.14], [.34, 1.86], [3.25, 1.88], [3.95, 1.14]] },
  pickup: { name: 'Ostrava Haul', len: 5.35, wid: 1.98, r: 0.42, wb: [1.0, 4.3], lightY: 0.86, acc: 6.0, top: 26, price: 3900, buzz: 20, bed: true,
    body: [[0, .48], [0, 1.05], [3.9, 1.08], [4.95, .98], [5.35, .84], [5.35, .48]], cabin: [[2.05, 1.06], [2.25, 1.82], [3.45, 1.84], [4.05, 1.06]] },
  coupe: { name: 'Wren GT', len: 4.5, wid: 1.86, r: 0.34, wb: [0.8, 3.7], lightY: 0.66, acc: 8.6, top: 36, price: 8200, buzz: 45, spoiler: true,
    body: [[0, .3], [0, .74], [.2, .86], [1.4, .9], [3.2, .9], [4.25, .72], [4.5, .56], [4.5, .3]], cabin: [[1.3, .88], [2.25, 1.29], [2.95, 1.3], [3.6, .88]] },
  van: { name: 'Calder Hauler', len: 5.2, wid: 2.0, r: 0.38, wb: [0.9, 4.25], lightY: 0.85, acc: 5.2, top: 23, price: 3100, buzz: 15, van: true,
    body: [[0, .42], [0, 2.05], [3.9, 2.08], [4.62, 1.22], [5.2, 1.02], [5.2, .42]], cabin: null },
  police: { name: 'Police cruiser', len: 4.9, wid: 1.86, r: 0.34, wb: [0.9, 4.0], lightY: 0.74, acc: 8.0, top: 34, police: true,
    body: [[0, .34], [0, .82], [.2, .96], [1.35, 1.0], [3.55, 1.0], [4.62, .84], [4.9, .68], [4.9, .34]], cabin: [[1.15, .98], [1.9, 1.44], [3.1, 1.45], [3.75, .98]] },
  taxi: { name: 'Calder Cab', len: 4.7, wid: 1.82, r: 0.33, wb: [0.85, 3.88], lightY: 0.72, acc: 6.6, top: 27, taxi: true,
    body: [[0, .32], [0, .8], [.2, .94], [1.3, .98], [3.4, .98], [4.45, .82], [4.7, .66], [4.7, .32]], cabin: [[1.1, .96], [1.85, 1.42], [3.0, 1.43], [3.6, .96]] },
};
const CAR_MODELS = Object.keys(CAR_SPECS);
const CIVIL_MODELS = ['hatch', 'sedan', 'sedan', 'suv', 'suv', 'pickup', 'coupe', 'van', 'taxi', 'hatch'];
const CAR_PAINTS = [0x1d1f24, 0xd8dadf, 0x8a9099, 0x5a6068, 0x6a1a1e, 0x1e2f4a, 0x34503a, 0xa8823c, 0x7a2a12, 0x2a6a8a, 0xb7b9bd, 0x2a2c30, 0x4a1f3a, 0xc9c2b0];
MAT.carPaint = new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.26, metalness: 0.55, envMapIntensity: 1.35 });
MAT.carTrim = new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.42, metalness: 0.3, envMapIntensity: 1.0 });
MAT.carEmis = new THREE.MeshBasicMaterial({ vertexColors: true });
MAT.carBar = new THREE.MeshBasicMaterial({ vertexColors: true });
function extrudeProfile(pts, width, bevel) {
  const shape = new THREE.Shape();
  shape.moveTo(pts[0][0], pts[0][1]);
  for (let i = 1; i < pts.length; i++) shape.lineTo(pts[i][0], pts[i][1]);
  shape.closePath();
  const depth = Math.max(0.01, width - bevel * 2);
  const g = new THREE.ExtrudeGeometry(shape, { depth, bevelEnabled: bevel > 0, bevelThickness: bevel, bevelSize: bevel, bevelSegments: 2, curveSegments: 1 });
  g.translate(0, 0, -depth / 2);
  g.rotateY(-Math.PI / 2);
  return g.index ? g.toNonIndexed() : g;
}
function buildCarGeo(sp) {
  const P = new Batch(), T = new Batch(), E = new Batch(), B = sp.police ? new Batch() : null;
  const L = sp.len, W = sp.wid, hl = L / 2;
  const I = new THREE.Matrix4().makeTranslation(0, 0, -hl);
  const at = (x, y, z, sx, sy, sz, rx, ry, rz) => mtx(x, y, z - hl, sx, sy, sz, rx, ry, rz);
  P.add(extrudeProfile(sp.body, W, 0.06), I, 0xffffff);
  const glass = 0x101820;
  let roofY = sp.body.reduce((m, p) => Math.max(m, p[1]), 0), roofZ0 = 0, roofZ1 = L;
  if (sp.cabin) {
    const c = sp.cabin;
    T.add(extrudeProfile(c, W - 0.16, 0.04), I, glass);
    roofY = Math.max(c[1][1], c[2][1]); roofZ0 = c[1][0]; roofZ1 = c[2][0];
    P.add(GEO.box, at(0, roofY + 0.03, (roofZ0 + roofZ1) / 2, W - 0.12, 0.07, roofZ1 - roofZ0 + 0.08), 0xffffff);
    const pillar = (a, b) => { const len = Math.hypot(b[0] - a[0], b[1] - a[1]), ang = Math.atan2(b[1] - a[1], b[0] - a[0]); for (const sx of [-1, 1]) P.add(GEO.box, at(sx * (W / 2 - 0.1), (a[1] + b[1]) / 2, (a[0] + b[0]) / 2, 0.07, 0.07, len, -ang, 0, 0), 0xffffff); };
    pillar(c[0], c[1]); pillar(c[3], c[2]);
    const mid = (c[1][0] + c[2][0]) / 2;
    for (const sx of [-1, 1]) P.add(GEO.box, at(sx * (W / 2 - 0.1), (c[0][1] + roofY) / 2, mid, 0.07, roofY - c[0][1], 0.1), 0xffffff);
    T.add(GEO.box, at(0, roofY + 0.1, (roofZ0 + roofZ1) / 2, W - 0.3, 0.06, (roofZ1 - roofZ0) * 0.8), 0xf2f6fa); // snow on the roof
    for (const sx of [-1, 1]) P.add(GEO.box, at(sx * (W / 2 + 0.06), c[3][1] + 0.08, c[3][0] - 0.15, 0.14, 0.1, 0.18), 0xffffff); // mirrors
  }
  if (sp.van) {
    const a = [3.9, 2.08], b = [4.62, 1.22], len = Math.hypot(b[0] - a[0], b[1] - a[1]), ang = Math.atan2(b[1] - a[1], b[0] - a[0]);
    T.add(GEO.box, at(0, (a[1] + b[1]) / 2 + 0.02, (a[0] + b[0]) / 2 + 0.02, W - 0.3, 0.04, len * 0.92, -ang, 0, 0), glass);
    for (const sx of [-1, 1]) T.add(GEO.box, at(sx * (W / 2 + 0.005), 1.62, 3.55, 0.02, 0.62, 0.9), glass);
    for (const sx of [-1, 1]) T.add(GEO.box, at(sx * (W / 2 + 0.006), 1.2, 1.9, 0.02, 0.05, 3.0), 0x1a2a3a);
    T.add(GEO.box, at(0, 2.13, 2.0, W - 0.3, 0.06, 3.4), 0xf2f6fa);
  }
  if (sp.bed) {
    T.add(GEO.box, at(0, 1.06, 1.0, W - 0.24, 0.02, 1.9), 0x1a1c20);
    T.add(GEO.box, at(0, 1.08, 1.0, W - 0.4, 0.04, 1.7), 0xe8eef4);
  }
  if (sp.spoiler) { P.add(GEO.box, at(0, 1.0, 0.18, W - 0.2, 0.05, 0.32), 0xffffff); for (const sx of [-0.6, 0.6]) T.add(GEO.box, at(sx, 0.94, 0.22, 0.06, 0.12, 0.1), 0x15171a); }
  // wheels: tire + rim
  for (const zw of sp.wb) for (const sx of [-1, 1]) {
    T.add(GEO.cyl, at(sx * (W / 2 - 0.1), sp.r, zw, sp.r, 0.25, sp.r, 0, 0, Math.PI / 2), 0x0d0e10);
    T.add(GEO.cyl, at(sx * (W / 2 + 0.03), sp.r, zw, sp.r * 0.58, 0.02, sp.r * 0.58, 0, 0, Math.PI / 2), 0x9aa0a8);
    T.add(GEO.box, at(sx * (W / 2 - 0.02), sp.r * 1.9, zw, 0.08, 0.1, sp.r * 2.3), 0x15171a);
  }
  // bumpers, grille, plates, lights
  const frontY = sp.body[sp.body.length - 2][1];
  T.add(GEO.box, at(0, 0.42, L + 0.04, W * 0.97, 0.18, 0.16), 0x1e2024);
  T.add(GEO.box, at(0, 0.42, -0.04, W * 0.97, 0.18, 0.16), 0x1e2024);
  T.add(GEO.box, at(0, sp.lightY - 0.04, L + 0.015, W * 0.42, 0.16, 0.04), 0x0c0d0f);
  T.add(GEO.box, at(0, 0.44, L + 0.13, 0.5, 0.12, 0.02), 0xe8ecf0);
  T.add(GEO.box, at(0, 0.58, -0.13, 0.5, 0.12, 0.02), 0xe8ecf0);
  for (const sx of [-1, 1]) {
    E.add(GEO.box, at(sx * (W / 2 - 0.3), sp.lightY, L + 0.02, 0.36, 0.13, 0.05), 0xfff2d6);
    E.add(GEO.box, at(sx * (W / 2 - 0.22), Math.min(sp.lightY + 0.08, frontY + 0.1), -0.02, 0.32, 0.12, 0.05), 0x8a0a04);
  }
  if (sp.police) {
    for (const sx of [-1, 1]) T.add(GEO.box, at(sx * (W / 2 + 0.004), 0.68, 2.45, 0.02, 0.5, 2.1), 0xeef2f6);
    T.add(GEO.box, at(0, 0.5, L + 0.2, W * 0.6, 0.36, 0.08), 0x15171a);
    T.add(GEO.box, at(0, roofY + 0.1, (roofZ0 + roofZ1) / 2, 1.1, 0.08, 0.32), 0x15171a);
    B.add(GEO.box, at(-0.3, roofY + 0.2, (roofZ0 + roofZ1) / 2, 0.5, 0.12, 0.26), new THREE.Color(3.2, 0.12, 0.08));
    B.add(GEO.box, at(0.3, roofY + 0.2, (roofZ0 + roofZ1) / 2, 0.5, 0.12, 0.26), new THREE.Color(0.1, 0.35, 3.4));
  }
  if (sp.taxi) { E.add(GEO.box, at(0, roofY + 0.22, (roofZ0 + roofZ1) / 2, 0.7, 0.2, 0.3), 0xffd24a); T.add(GEO.box, at(0, 0.7, 2.3, W + 0.01, 0.12, 2.6), 0x15171a); }
  return { paint: P.build(), trim: T.build(), emis: E.build(), bar: B ? B.build() : null, roofY };
}
const CARMESH = {};
const _zeroM = new THREE.Matrix4().makeScale(0, 0, 0);
for (const model of CAR_MODELS) {
  const sp = CAR_SPECS[model];
  const g = buildCarGeo(sp); sp.roofY = g.roofY; sp.wbLen = sp.wb[1] - sp.wb[0];
  const cap = model === 'police' ? 16 : 44;
  const mk = (geo, mat, shadow) => { const m = new THREE.InstancedMesh(geo, mat, cap); m.frustumCulled = false; m.castShadow = shadow; m.receiveShadow = shadow; for (let i = 0; i < cap; i++) m.setMatrixAt(i, _zeroM); scene.add(m); return m; };
  const M = { paint: mk(g.paint, MAT.carPaint, true), trim: mk(g.trim, MAT.carTrim, true), emis: mk(g.emis, MAT.carEmis, false), bar: g.bar ? mk(g.bar, MAT.carBar, false) : null, free: [], dirty: false };
  for (let i = 0; i < cap; i++) { M.paint.setColorAt(i, new THREE.Color(1, 1, 1)); if (M.bar) M.bar.setColorAt(i, new THREE.Color(0.1, 0.1, 0.1)); }
  for (let i = cap - 1; i >= 0; i--) M.free.push(i);
  CARMESH[model] = M;
}
const VEH = [];
let vehSeq = 0;
function spawnVehicle(model, x, z, yaw, o) {
  o = o || {};
  const M = CARMESH[model]; if (!M || !M.free.length) return null;
  const sp = CAR_SPECS[model];
  const slot = M.free.pop();
  const v = {
    id: ++vehSeq, model, sp, slot, color: o.color !== undefined ? o.color : pick(CAR_PAINTS), pos: new THREE.Vector3(x, 0, z), yaw: yaw || 0,
    vel: new THREE.Vector2(), speed: 0, steer: 0, driver: null, ai: null, parked: !!o.parked, locked: !!o.locked, owned: !!o.owned, tag: o.tag || null,
    hp: 100, awake: false, siren: false, flash: 0, remote: null, stuckT: 0, lastHonk: 0, brake: false,
  };
  v.box = { x0: 0, x1: 0, y0: 0, y1: 1.05, z0: 0, z1: 0, on: true, tag: 'car', veh: v };
  v.cab = { x0: 0, x1: 0, y0: 1.0, y1: sp.roofY || 1.4, z0: 0, z1: 0, on: !sp.van, tag: 'cabin', veh: v };
  if (sp.van) v.box.y1 = 2.05;
  M.paint.setColorAt(slot, new THREE.Color(v.color)); M.paint.instanceColor.needsUpdate = true;
  DYN_BOXES.push(v.box, v.cab);
  VEH.push(v); placeVehInstance(v);
  return v;
}
function removeVehicle(v) {
  const M = CARMESH[v.model];
  for (const k of ['paint', 'trim', 'emis', 'bar']) if (M[k]) M[k].setMatrixAt(v.slot, _zeroM);
  M.free.push(v.slot); M.dirty = true;
  for (const b of [v.box, v.cab]) { const i = DYN_BOXES.indexOf(b); if (i >= 0) DYN_BOXES.splice(i, 1); }
  const i = VEH.indexOf(v); if (i >= 0) VEH.splice(i, 1);
  v.dead = true;
}
const _vm = new THREE.Matrix4(), _vq = new THREE.Quaternion(), _vy = new THREE.Vector3(0, 1, 0), _vs = new THREE.Vector3(1, 1, 1);
function placeVehInstance(v) {
  const M = CARMESH[v.model];
  _vq.setFromAxisAngle(_vy, v.yaw);
  _vm.compose(v.pos, _vq, _vs);
  M.paint.setMatrixAt(v.slot, _vm); M.trim.setMatrixAt(v.slot, _vm); M.emis.setMatrixAt(v.slot, _vm); if (M.bar) M.bar.setMatrixAt(v.slot, _vm);
  M.dirty = true;
  const c = Math.abs(Math.cos(v.yaw)), s = Math.abs(Math.sin(v.yaw)), W = v.sp.wid / 2, L = v.sp.len / 2;
  const hx = c * W + s * L, hz = s * W + c * L;
  v.box.x0 = v.pos.x - hx; v.box.x1 = v.pos.x + hx; v.box.z0 = v.pos.z - hz; v.box.z1 = v.pos.z + hz;
  v.cab.x0 = v.pos.x - hx * 0.6; v.cab.x1 = v.pos.x + hx * 0.6; v.cab.z0 = v.pos.z - hz * 0.6; v.cab.z1 = v.pos.z + hz * 0.6;
}
const vFwd = v => ({ x: Math.sin(v.yaw), z: Math.cos(v.yaw) });
const vSide = v => ({ x: Math.cos(v.yaw), z: -Math.sin(v.yaw) }); // the car's left (driver side)
const ZERO_IN = { thr: 0, steer: 0, hand: false };
function vehPhysics(v, dt, inp) {
  const sp = v.sp;
  let f = vFwd(v), l = vSide(v);
  let vF = v.vel.x * f.x + v.vel.y * f.z, vL = v.vel.x * l.x + v.vel.y * l.z;
  const ice = onIce(v.pos.x, v.pos.z, 0);
  const dead = v.hp <= 0;
  const thr = dead ? 0 : inp.thr;
  v.brake = false;
  if (thr > 0) vF += thr * (vF < -0.5 ? 13 : sp.acc) * dt;
  else if (thr < 0) { if (vF > 0.6) { vF += thr * 14 * dt; v.brake = true; } else vF += thr * 4.5 * dt; }
  const roll = 0.35 + 0.011 * vF * vF + (thr === 0 ? 1.1 : 0);
  vF -= Math.sign(vF) * Math.min(Math.abs(vF), roll * dt);
  if (inp.hand) { vF -= Math.sign(vF) * Math.min(Math.abs(vF), 5 * dt); v.brake = true; }
  vF = clamp(vF, -8, sp.top * (dead ? 0 : 1));
  const grip = (inp.hand ? 0.9 : (v.ai ? 9 : 4.2)) * (ice ? 0.22 : 1);
  vL -= vL * Math.min(1, grip * dt);
  const maxSteer = lerp(0.6, 0.2, clamp(Math.abs(vF) / 30, 0, 1));
  v.steer += (inp.steer * maxSteer - v.steer) * Math.min(1, dt * 7);
  v.yaw += vF / sp.wbLen * Math.tan(v.steer) * (inp.hand ? 1.3 : 1) * dt;
  f = vFwd(v); l = vSide(v);
  v.vel.set(f.x * vF + l.x * vL, f.z * vF + l.z * vL);
  v.speed = vF;
  v.pos.x += v.vel.x * dt; v.pos.z += v.vel.y * dt;
  v.pos.x = clamp(v.pos.x, -BOUND, BOUND); v.pos.z = clamp(v.pos.z, -BOUND, BOUND);
}
const _vcList = [];
function vehCollide(v) {
  const f = vFwd(v), L = v.sp.len, W = v.sp.wid, r = W / 2;
  let impact = 0;
  for (const o of [-(L / 2 - r), 0, L / 2 - r]) {
    const cx = v.pos.x + f.x * o, cz = v.pos.z + f.z * o;
    const list = queryBoxes(cx - r, cz - r, cx + r, cz + r, _vcList);
    for (const b of list) {
      if (b.y1 < 0.4 || b.y0 > 1.3) continue;
      const px = clamp(cx, b.x0, b.x1), pz = clamp(cz, b.z0, b.z1);
      let dx = cx - px, dz = cz - pz; let d = Math.hypot(dx, dz);
      if (d >= r) continue;
      if (d < 1e-4) { dx = cx - (b.x0 + b.x1) / 2; dz = cz - (b.z0 + b.z1) / 2; d = Math.hypot(dx, dz) || 1; }
      const nx = dx / d, nz = dz / d, pen = r - Math.min(d, r);
      v.pos.x += nx * pen; v.pos.z += nz * pen;
      const vn = v.vel.x * nx + v.vel.y * nz;
      if (vn < 0) { v.vel.x -= 1.3 * vn * nx; v.vel.y -= 1.3 * vn * nz; impact = Math.max(impact, -vn); }
    }
  }
  for (const o of VEH) {
    if (o === v || o.dead) continue;
    const dd = Math.hypot(o.pos.x - v.pos.x, o.pos.z - v.pos.z); if (dd > (L + o.sp.len) / 2 + 0.5) continue;
    const fo = vFwd(o), ro = o.sp.wid / 2;
    for (const a of [-(L / 2 - r), 0, L / 2 - r]) for (const b of [-(o.sp.len / 2 - ro), 0, o.sp.len / 2 - ro]) {
      const ax = v.pos.x + f.x * a, az = v.pos.z + f.z * a, bx = o.pos.x + fo.x * b, bz = o.pos.z + fo.z * b;
      const dx = ax - bx, dz = az - bz, d = Math.hypot(dx, dz), min = r + ro;
      if (d >= min || d < 1e-4) continue;
      const nx = dx / d, nz = dz / d, pen = (min - d) / 2;
      v.pos.x += nx * pen; v.pos.z += nz * pen; o.pos.x -= nx * pen; o.pos.z -= nz * pen;
      const rel = (v.vel.x - o.vel.x) * nx + (v.vel.y - o.vel.y) * nz;
      if (rel < 0) { const j = -rel * 0.6; v.vel.x += nx * j; v.vel.y += nz * j; o.vel.x -= nx * j; o.vel.y -= nz * j; impact = Math.max(impact, -rel); o.awake = true; o.parked = false; if (-rel > 6) o.hp -= -rel * 1.5; }
    }
  }
  if (impact > 4) {
    v.hp -= impact * 1.6;
    if (v.driver === 'player') { P.shake = Math.min(1, impact / 18); sfx.crash(v.pos.x, v.pos.z, impact); if (impact > 12) hurtPlayer(impact * 0.6, null, true); }
    else if (Math.hypot(v.pos.x - camera.position.x, v.pos.z - camera.position.z) < 60) sfx.crash(v.pos.x, v.pos.z, impact);
    if (v.hp <= 0 && !v.smoking) { v.smoking = true; }
  }
}
// cars knock people down
function vehHitPeople(v) {
  const sp = Math.hypot(v.vel.x, v.vel.y);
  if (sp < 2.6) return;
  const f = vFwd(v), L = v.sp.len, r = v.sp.wid / 2 + 0.35;
  const hit = (pos) => { for (const o of [-(L / 2 - r / 2), 0, L / 2 - r / 2]) { if (Math.hypot(pos.x - (v.pos.x + f.x * o), pos.z - (v.pos.z + f.z * o)) < r && pos.y < 1.5) return true; } return false; };
  const push = (body) => { const n = Math.hypot(body.pos.x - v.pos.x, body.pos.z - v.pos.z) || 1; body.vel.x = v.vel.x * 0.8 + (body.pos.x - v.pos.x) / n * 3; body.vel.z = v.vel.y * 0.8 + (body.pos.z - v.pos.z) / n * 3; body.vel.y = Math.min(7, sp * 0.35); body.onGround = false; };
  if (v.driver !== 'player' && !P.car && !P.dead && hit(P.pos) && P.downT <= 0) { push(P); P.downT = 1.6; hurtPlayer(sp * 4, null, false); bloodBurst(P.pos.x, P.pos.y + 1, P.pos.z, v.vel.x, v.vel.y, 8); }
  for (const e of ENEMIES) if (e.state !== 'down' && hit(e.pos)) { push(e); e.knockT = 1.2; damageEnemy(e, sp * 7, false, { x: v.vel.x, z: v.vel.y }); if (v.driver === 'player') addWanted(8, e.pos); }
  for (const p of PEDS) if (p.state !== 'down' && hit(p.pos)) { push(p); pedHit(p, sp * 7, { x: v.vel.x, z: v.vel.y }, v.driver === 'player'); }
  for (const c of COPS) if (c.state !== 'down' && hit(c.pos)) { push(c); copHit(c, sp * 6, { x: v.vel.x, z: v.vel.y }, v.driver === 'player'); }
  if (v.driver === 'player') for (const R of NET.remotes.values()) if (!R.veh && hit(R.pos)) { bloodBurst(R.pos.x, 1, R.pos.z, v.vel.x, v.vel.y, 6); }
}

/* ---- traffic AI: right-hand lanes on the 3x3 grid, obeys the signals ---- */
const LANE = 2.1, GRID_X = XL, GRID_Z = ZL;
function laneXZ(ai, along) { return ai.axis === 'x' ? { x: along, z: ai.line + LANE * ai.dir } : { x: ai.line - LANE * ai.dir, z: along }; }
function nextCross(ai, along) {
  const cs = ai.axis === 'x' ? GRID_X : GRID_Z;
  let best = null;
  for (const c of cs) { const d = (c - along) * ai.dir; if (d > -4 && (best === null || d < (best - along) * ai.dir)) best = c; }
  return best;
}
function aiDrive(v, dt) {
  const ai = v.ai;
  const along = ai.axis === 'x' ? v.pos.x : v.pos.z;
  const ni = nextCross(ai, along);
  let target = ai.speed || 10;
  if (ni !== null) {
    const dI = (ni - along) * ai.dir;
    if (ai.turnFor !== ni && dI < 34) {
      ai.turnFor = ni;
      const opts = [];
      const cs = ai.axis === 'x' ? GRID_X : GRID_Z;
      if (cs.some(c => (c - ni) * ai.dir > 1)) opts.push('s', 's');
      const perp = ai.axis === 'x' ? GRID_Z : GRID_X;
      for (const d2 of [-1, 1]) if (perp.some(c => (c - ai.line) * d2 > 1)) opts.push(d2);
      ai.turn = opts.length ? pick(opts) : 's';
    }
    const turning = ai.turn !== 's' && ai.turnFor === ni;
    if (turning) target = Math.min(target, 5.8);
    // the light for our direction
    if (!ai.siren) {
      const ix = ai.axis === 'x' ? GRID_X.indexOf(ni) : GRID_X.indexOf(ai.line), iz = ai.axis === 'x' ? GRID_Z.indexOf(ai.line) : GRID_Z.indexOf(ni);
      if (ix >= 0 && iz >= 0) {
        const st = signalState(ix, iz, ai.axis);
        if (st !== 'g' && dI > 8.5 && dI < 22 && !(st === 'y' && dI < 12)) target = Math.min(target, Math.max(0, (dI - 10) * 0.9));
      }
    }
    if (turning) {
      // right turns cut in early, left turns cross the middle first (right-hand traffic)
      const d2 = ai.turn;
      const newAxis = ai.axis === 'x' ? 'z' : 'x';
      // which way is "right"? moving +x, right is +z; moving +z, right is -x
      const rightDir = ai.axis === 'x' ? ai.dir : -ai.dir;
      const isRight = d2 === rightDir;
      if (dI < (isRight ? LANE + 1.2 : -LANE + 1.2)) { ai.axis = newAxis; ai.line = ni; ai.dir = d2; ai.turnFor = null; ai.turn = null; }
    }
  }
  const along2 = ai.axis === 'x' ? v.pos.x : v.pos.z;
  const look = laneXZ(ai, along2 + ai.dir * (6 + Math.abs(v.speed) * 0.35));
  const desired = Math.atan2(look.x - v.pos.x, look.z - v.pos.z);
  // obstacles ahead
  const f = vFwd(v);
  let block = 99;
  const consider = (x, z, extra) => { const dx = x - v.pos.x, dz = z - v.pos.z, fd = dx * f.x + dz * f.z, ld = Math.abs(-dx * f.z + dz * f.x); if (fd > 0 && fd < 16 && ld < 1.9 + (extra || 0)) block = Math.min(block, fd); };
  for (const o of VEH) if (o !== v && !o.dead) consider(o.pos.x, o.pos.z, 0.3);
  if (!P.car) consider(P.pos.x, P.pos.z);
  for (const p of PEDS) if (p.state !== 'down') consider(p.pos.x, p.pos.z);
  if (block < 99) target = Math.min(target, Math.max(0, (block - v.sp.len / 2 - 2.4) * 1.1));
  if (block < 7 && !P.car && Math.hypot(P.pos.x - v.pos.x, P.pos.z - v.pos.z) < 8 && REAL_T - v.lastHonk > 4) { v.lastHonk = REAL_T; sfx.honk(v.pos.x, v.pos.z); }
  const sp = v.speed;
  const thr = sp < target - 0.5 ? 1 : sp > target + 0.8 ? -1 : 0;
  const steer = clamp(angDiff(v.yaw, desired) * 2.4, -1, 1);
  if (Math.abs(sp) < 0.3 && target > 2) v.stuckT += dt; else v.stuckT = 0;
  return { thr, steer, hand: false };
}
const TRAFFIC = [];
const N_TRAFFIC = IS_TOUCH ? 6 : 11;
function spawnTrafficCar(nearX, nearZ, minD, maxD) {
  for (let k = 0; k < 30; k++) {
    const axis = Math.random() < 0.5 ? 'x' : 'z';
    const line = pick(axis === 'x' ? GRID_Z : GRID_X);
    const dir = Math.random() < 0.5 ? 1 : -1;
    const cs = axis === 'x' ? GRID_X : GRID_Z, range = [cs[0] + 12, cs[cs.length - 1] - 12];
    const along = rand(range[0], range[1]);
    const p = laneXZ({ axis, line, dir }, along);
    const d = Math.hypot(p.x - nearX, p.z - nearZ);
    if (d < minD || d > maxD) continue;
    if (VEH.some(o => Math.hypot(o.pos.x - p.x, o.pos.z - p.z) < 9)) continue;
    if ((axis === 'x' ? GRID_X : GRID_Z).some(c => Math.abs(c - along) < 12)) continue;
    const yaw = axis === 'x' ? (dir > 0 ? Math.PI / 2 : -Math.PI / 2) : (dir > 0 ? 0 : Math.PI);
    const v = spawnVehicle(pick(CIVIL_MODELS), p.x, p.z, yaw, {});
    if (!v) return null;
    v.ai = { axis, line, dir, speed: rand(8.5, 11), turn: null, turnFor: null };
    v.driver = 'ai'; v.awake = true;
    TRAFFIC.push(v);
    return v;
  }
  return null;
}
let trafficT = 0;
function trafficDirector(dt) {
  trafficT -= dt; if (trafficT > 0) return; trafficT = 1.5;
  for (let i = TRAFFIC.length - 1; i >= 0; i--) {
    const v = TRAFFIC[i];
    if (v.dead || v.driver !== 'ai') { TRAFFIC.splice(i, 1); continue; }
    const d = Math.hypot(v.pos.x - P.pos.x, v.pos.z - P.pos.z);
    if (d > 175 || v.stuckT > 14 || v.hp <= 0) { if (d > 40 || v.hp <= 0) { removeVehicle(v); TRAFFIC.splice(i, 1); } }
  }
  if (TRAFFIC.length < N_TRAFFIC) spawnTrafficCar(P.pos.x, P.pos.z, TRAFFIC.length < 4 ? 30 : 60, 150);
}

/* ---- parked cars from the world's parking spots ---- */
const OWN_SPOT = { x: -4.6, z: -32, yaw: 0 };
// Parked cars stream in around you (the district has hundreds of spots); dealer, police lot and story cars always stay.
const PARKED = new Map();
function spawnAtSpot(i) {
  const s = PARK_SPOTS[i];
  if (Math.hypot(s.x - OWN_SPOT.x, s.z - OWN_SPOT.z) < 7) return null;
  if (VEH.some(o => Math.hypot(o.pos.x - s.x, o.pos.z - s.z) < 4)) return null;
  if (!s.model && s.pick === undefined) s.pick = Math.floor(Math.random() * 8);
  const model = s.model || ['hatch', 'sedan', 'sedan', 'suv', 'pickup', 'coupe', 'van', 'hatch'][s.pick];
  if (!s.model && s.color === undefined) s.paint = s.paint !== undefined ? s.paint : pick(CAR_PAINTS);
  const v = spawnVehicle(model, s.x, s.z, s.yaw !== undefined ? s.yaw : (s.alongX ? Math.PI / 2 : 0), { parked: true, color: s.color !== undefined ? s.color : s.paint, locked: s.locked, tag: s.tag });
  if (v && model === 'police') v.parkedPolice = true;
  if (v) { v.spot = i; PARKED.set(i, v); }
  return v;
}
function spawnParkedCars() {
  PARK_SPOTS.forEach((s, i) => { if (s.tag || s.model) { s.keep = true; spawnAtSpot(i); } });
  parkedDirector(true);
}
let parkedT = 0;
function parkedDirector(force) {
  parkedT -= 1 / 60; if (!force && parkedT > 0) return; parkedT = 0.8;
  const fx = MODE === 'title' ? TITLE.spot.x : P.pos.x, fz = MODE === 'title' ? TITLE.spot.z : P.pos.z;
  for (let i = 0; i < PARK_SPOTS.length; i++) {
    const s = PARK_SPOTS[i], d = Math.hypot(s.x - fx, s.z - fz), v = PARKED.get(i);
    if (v) {
      const gone = v.dead || !VEH.includes(v);
      const moved = !gone && Math.hypot(v.pos.x - s.x, v.pos.z - s.z) > 2;
      if (gone || moved || v.driver || v.owned) { PARKED.delete(i); continue; }
      if (!s.keep && d > 175 && !v.awake) { removeVehicle(v); PARKED.delete(i); }
    } else if (!s.keep && d < 130) spawnAtSpot(i);
  }
  // cars knocked off their spots and left far away get cleaned up too
  for (const v of [...VEH]) if (v.spot !== undefined && !PARKED.has(v.spot) && !v.driver && !v.owned && !v.tag && !v.ai && !v.copAI && !v.remote && v !== OWN_CAR && Math.hypot(v.pos.x - fx, v.pos.z - fz) > 220) removeVehicle(v);
}
let OWN_CAR = null;
function spawnOwnedCar(idx, near) {
  const g = S.garage[idx || 0]; if (!g) return null;
  if (OWN_CAR && !OWN_CAR.dead) { if (P.car === OWN_CAR) return OWN_CAR; removeVehicle(OWN_CAR); }
  let x = OWN_SPOT.x, z = OWN_SPOT.z, yaw = OWN_SPOT.yaw;
  if (near) {
    // nearest street lane to the player, clear of other cars
    let best = null, bd = Infinity;
    for (const xl of XL) for (const sd of [-1, 1]) { const px = xl + sd * 4.6, pz = clamp(P.pos.z, -140, 140); const d = Math.abs(px - P.pos.x); if (d < bd && !VEH.some(o => Math.hypot(o.pos.x - px, o.pos.z - pz) < 6)) { bd = d; best = { x: px, z: pz, yaw: sd > 0 ? Math.PI : 0 }; } }
    for (const zl of ZL) for (const sd of [-1, 1]) { const pz = zl + sd * 4.6, px = clamp(P.pos.x, -140, 140); const d = Math.abs(pz - P.pos.z); if (d < bd && !VEH.some(o => Math.hypot(o.pos.x - px, o.pos.z - pz) < 6)) { bd = d; best = { x: px, z: pz, yaw: sd > 0 ? Math.PI / 2 : -Math.PI / 2 }; } }
    if (best) { x = best.x; z = best.z; yaw = best.yaw; }
  }
  OWN_CAR = spawnVehicle(g.model, x, z, yaw, { parked: true, color: g.color, owned: true });
  return OWN_CAR;
}

/* ---- the player behind the wheel ---- */
function nearestCar(maxD) {
  let best = null, bd = maxD || 3.4;
  for (const v of VEH) {
    if (v.dead || v.remote || (v.driver && v.driver !== 'ai')) continue;
    const d = Math.hypot(v.pos.x - P.pos.x, v.pos.z - P.pos.z) - v.sp.len * 0.3;
    if (d < bd && Math.abs(P.pos.y - v.pos.y) < 1.5) { bd = d; best = v; }
  }
  return best;
}
function enterVehicle(v) {
  if (!v || P.car || P.downT > 0) return;
  if (v.locked && !v.owned) { banner('Locked', v.tag === 'dealer' ? 'Buy it in the Garage app' : v.sp.police ? 'Police vehicle' : ''); return; }
  if (v.hp <= 0) { banner('Wrecked', 'This one is done'); return; }
  if (v.driver === 'ai') {
    const ti = TRAFFIC.indexOf(v); if (ti >= 0) TRAFFIC.splice(ti, 1);
    v.ai = null;
    const l = vSide(v);
    spawnFleeingDriver(v.pos.x + l.x * (v.sp.wid / 2 + 0.8), v.pos.z + l.z * (v.sp.wid / 2 + 0.8));
    addWanted(10, v.pos); addHeat(3);
    S.stats.carsTaken++;
    banner('Carjacked', v.sp.name);
  } else if (!v.owned) { addWanted(4, v.pos); S.stats.carsTaken++; }
  v.driver = 'player'; v.parked = false; v.awake = true;
  P.car = v; P.crouch = false; P.aimT = 0; P.reloadT = 0;
  startEngine(); radioOn();
  sfx.door();
  hudDirty = true;
}
function exitVehicle() {
  const v = P.car; if (!v) return;
  const l = vSide(v);
  let ex = v.pos.x + l.x * (v.sp.wid / 2 + 0.7), ez = v.pos.z + l.z * (v.sp.wid / 2 + 0.7);
  if (isBlocked(ex, ez, 0.3)) { ex = v.pos.x - l.x * (v.sp.wid / 2 + 0.7); ez = v.pos.z - l.z * (v.sp.wid / 2 + 0.7); }
  v.driver = null;
  P.car = null;
  placePlayer(ex, 0, ez);
  P.bodyYaw = v.yaw;
  stopEngine(); radioOff();
  sfx.door();
  hudDirty = true;
}
function playerDriveInput() {
  let thr = 0, steer = 0;
  if (keys.KeyW || keys.ArrowUp) thr += 1;
  if (keys.KeyS || keys.ArrowDown) thr -= 1;
  if (keys.KeyA || keys.ArrowLeft) steer += 1;
  if (keys.KeyD || keys.ArrowRight) steer -= 1;
  if (TOUCH.joy.active) { thr += TOUCH.joy.y; steer -= TOUCH.joy.x; }
  if (MODE !== 'play') thr = steer = 0;
  return { thr: clamp(thr, -1, 1), steer: clamp(steer, -1, 1), hand: !!(keys.Space || TOUCH.jumpHeld) && MODE === 'play' };
}
// player car headlights at night
const HEADLIGHT = new THREE.SpotLight(0xfff2d8, 0, 60, 0.5, 0.45, 1.4);
scene.add(HEADLIGHT, HEADLIGHT.target);
function updateVehicles(dt) {
  for (let i = VEH.length - 1; i >= 0; i--) {
    const v = VEH[i];
    if (v.remote) continue;
    let inp = null;
    if (v.driver === 'player') inp = playerDriveInput();
    else if (v.ai && !v.copAI) inp = aiDrive(v, dt);
    else if (v.copAI) inp = copDrive(v, dt);
    if (v.dead) continue;
    const moving = inp || v.awake;
    if (!moving) continue;
    vehPhysics(v, dt, inp || ZERO_IN);
    vehCollide(v);
    vehHitPeople(v);
    placeVehInstance(v);
    if (!inp && Math.hypot(v.vel.x, v.vel.y) < 0.05) { v.awake = false; v.vel.set(0, 0); }
    if (v.smoking && Math.random() < 0.3) PFX_SMOKE.spawn(v.pos.x + vFwd(v).x * v.sp.len * 0.4, 1.1, v.pos.z + vFwd(v).z * v.sp.len * 0.4, rand(-.2, .2), rand(0.6, 1.2), rand(-.2, .2), 2.2, 0.5, 2.4, 0.45, 0.25, 0.25, 0.27, 0.3, 0.2);
  }
  // police light bars
  const flash = Math.floor(REAL_T * 7) % 2;
  const PM = CARMESH.police;
  for (const v of VEH) if (v.model === 'police') { PM.bar.setColorAt(v.slot, v.siren ? (flash ? new THREE.Color(1, 1, 0.08) : new THREE.Color(0.08, 1, 1)) : new THREE.Color(0.06, 0.06, 0.06)); }
  PM.bar.instanceColor.needsUpdate = true;
  for (const m of CAR_MODELS) { const M = CARMESH[m]; if (M.dirty) { M.paint.instanceMatrix.needsUpdate = M.trim.instanceMatrix.needsUpdate = M.emis.instanceMatrix.needsUpdate = true; if (M.bar) M.bar.instanceMatrix.needsUpdate = true; M.dirty = false; } }
  MAT.carEmis.color.setScalar(lerp(0.55, 1.35, DN.lamps));
  // headlights
  const pc = P.car;
  if (pc && DN.lamps > 0.2) {
    const f = vFwd(pc);
    HEADLIGHT.intensity = 260 * DN.lamps;
    HEADLIGHT.position.set(pc.pos.x + f.x * pc.sp.len * 0.5, pc.sp.lightY + 0.1, pc.pos.z + f.z * pc.sp.len * 0.5);
    HEADLIGHT.target.position.set(pc.pos.x + f.x * 22, 0, pc.pos.z + f.z * 22); HEADLIGHT.target.updateMatrixWorld();
  } else HEADLIGHT.intensity = 0;
  trafficDirector(dt);
  parkedDirector();
  updateEngine();
  radioTick();
}

/* engine, tyres and radio live in 82_soundscape.js */
