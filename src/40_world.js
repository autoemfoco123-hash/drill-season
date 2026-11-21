
/* =========================================================
   COLLISION WORLD (axis-aligned boxes + uniform grid)
   ========================================================= */
const BOXES = [], GRID = new Map(), CELL = 12;
const COVER = [];
let QSTAMP = 0;
const gkey = (cx, cz) => (cx + 200) * 1000 + (cz + 200);
function addCol(x0, y0, z0, x1, y1, z1, tag) {
  const b = { x0: Math.min(x0, x1), y0: Math.min(y0, y1), z0: Math.min(z0, z1), x1: Math.max(x0, x1), y1: Math.max(y0, y1), z1: Math.max(z0, z1), tag: tag || 'solid', _q: 0 };
  BOXES.push(b);
  for (let cx = Math.floor(b.x0 / CELL); cx <= Math.floor(b.x1 / CELL); cx++)
    for (let cz = Math.floor(b.z0 / CELL); cz <= Math.floor(b.z1 / CELL); cz++) {
      const k = gkey(cx, cz); let c = GRID.get(k); if (!c) { c = []; GRID.set(k, c); } c.push(b);
    }
  if (tag === 'cover' || tag === 'column') COVER.push(b);
  return b;
}
const _qOut = [];
function queryBoxes(x0, z0, x1, z1, out) {
  out = out || _qOut; out.length = 0; QSTAMP++;
  for (let cx = Math.floor(x0 / CELL); cx <= Math.floor(x1 / CELL); cx++)
    for (let cz = Math.floor(z0 / CELL); cz <= Math.floor(z1 / CELL); cz++) {
      const c = GRID.get(gkey(cx, cz)); if (!c) continue;
      for (const b of c) if (b._q !== QSTAMP) { b._q = QSTAMP; out.push(b); }
    }
  return out;
}
const DYN_BOXES = []; // trains
function rayBox(ox, oy, oz, ix, iy, iz, b) {
  let t1 = (b.x0 - ox) * ix, t2 = (b.x1 - ox) * ix;
  let tmin = Math.min(t1, t2), tmax = Math.max(t1, t2);
  t1 = (b.y0 - oy) * iy; t2 = (b.y1 - oy) * iy;
  tmin = Math.max(tmin, Math.min(t1, t2)); tmax = Math.min(tmax, Math.max(t1, t2));
  t1 = (b.z0 - oz) * iz; t2 = (b.z1 - oz) * iz;
  tmin = Math.max(tmin, Math.min(t1, t2)); tmax = Math.min(tmax, Math.max(t1, t2));
  if (tmax >= Math.max(tmin, 0)) return tmin > 0 ? tmin : 0;
  return Infinity;
}
const _rayOut = [];
// returns distance to the first solid hit (Infinity if none within maxT)
function raycastWorld(ox, oy, oz, dx, dy, dz, maxT, ignoreLow) {
  const ix = 1 / (dx || 1e-9), iy = 1 / (dy || 1e-9), iz = 1 / (dz || 1e-9);
  const ex = ox + dx * maxT, ez = oz + dz * maxT;
  const list = queryBoxes(Math.min(ox, ex), Math.min(oz, ez), Math.max(ox, ex), Math.max(oz, ez), _rayOut);
  let best = maxT;
  for (const b of list) { if (ignoreLow && b.y1 < ignoreLow) continue; const t = rayBox(ox, oy, oz, ix, iy, iz, b); if (t < best) best = t; }
  for (const b of DYN_BOXES) { if (!b.on) continue; const t = rayBox(ox, oy, oz, ix, iy, iz, b); if (t < best) best = t; }
  if (dy < 0) { const tg = -oy / dy; if (tg >= 0 && tg < best) best = tg; }
  return best < maxT ? best : Infinity;
}
function segClear(ax, ay, az, bx, by, bz) {
  const dx = bx - ax, dy = by - ay, dz = bz - az, L = Math.hypot(dx, dy, dz);
  if (L < 0.01) return true;
  return raycastWorld(ax, ay, az, dx / L, dy / L, dz / L, L - 0.05) === Infinity;
}
function groundAt(x, z, y) {
  let g = 0;
  const list = queryBoxes(x - 0.05, z - 0.05, x + 0.05, z + 0.05);
  for (const b of list) if (x >= b.x0 && x <= b.x1 && z >= b.z0 && z <= b.z1 && b.y1 <= y + STEP_UP && b.y1 > g) g = b.y1;
  for (const b of DYN_BOXES) if (b.on && x >= b.x0 && x <= b.x1 && z >= b.z0 && z <= b.z1 && b.y1 <= y + STEP_UP && b.y1 > g) g = b.y1;
  return g;
}
const _mvList = [];
function pushOut(body, b) {
  const r = body.radius;
  const px = body.pos.x, pz = body.pos.z;
  const cx = clamp(px, b.x0, b.x1), cz = clamp(pz, b.z0, b.z1);
  const ddx = px - cx, ddz = pz - cz, d2 = ddx * ddx + ddz * ddz;
  if (d2 >= r * r) return false;
  if (d2 > 1e-8) { const d = Math.sqrt(d2), k = (r - d) / d; body.pos.x += ddx * k; body.pos.z += ddz * k; }
  else {
    const l = px - b.x0, rr = b.x1 - px, t = pz - b.z0, bb = b.z1 - pz, m = Math.min(l, rr, t, bb);
    if (m === l) body.pos.x = b.x0 - r; else if (m === rr) body.pos.x = b.x1 + r; else if (m === t) body.pos.z = b.z0 - r; else body.pos.z = b.z1 + r;
  }
  return true;
}
// body: {pos, vel, radius, height, onGround, airY}
function moveBody(body, dx, dz, dt) {
  const steps = Math.max(1, Math.ceil(Math.hypot(dx, dz) / 0.3));
  let hitWall = false;
  for (let s = 0; s < steps; s++) {
    body.pos.x += dx / steps; body.pos.z += dz / steps;
    const r = body.radius + 0.05;
    const list = queryBoxes(body.pos.x - r, body.pos.z - r, body.pos.x + r, body.pos.z + r, _mvList);
    for (const b of list) {
      if (b.y1 <= body.pos.y + STEP_UP || b.y0 >= body.pos.y + body.height) continue;
      if (pushOut(body, b)) hitWall = true;
    }
    for (const b of DYN_BOXES) {
      if (!b.on || b.y1 <= body.pos.y + STEP_UP || b.y0 >= body.pos.y + body.height) continue;
      if (pushOut(body, b)) hitWall = true;
    }
  }
  body.pos.x = clamp(body.pos.x, -BOUND, BOUND); body.pos.z = clamp(body.pos.z, -BOUND, BOUND);
  // vertical
  const wasGround = body.onGround;
  body.vel.y -= GRAV * dt;
  body.pos.y += body.vel.y * dt;
  const g = groundAt(body.pos.x, body.pos.z, body.pos.y - body.vel.y * dt);
  let landed = 0;
  if (body.pos.y <= g || (wasGround && body.vel.y <= 0 && body.pos.y - g < 0.75)) {
    if (!wasGround) landed = (body.airY || body.pos.y) - g;
    body.pos.y = g; body.vel.y = 0; body.onGround = true; body.airY = g;
  } else {
    if (wasGround) body.airY = body.pos.y;
    body.airY = Math.max(body.airY || body.pos.y, body.pos.y);
    body.onGround = false;
  }
  return { hitWall, landed };
}

/* =========================================================
   WORLD CONSTRUCTION
   ========================================================= */
const B_PROPS = new Batch(), B_EMIS = new Batch(), B_SNOW = new Batch(), B_DECAL = new Batch(), B_GLASS = new Batch(), B_SHOP = new Batch(), B_GYM = new Batch();
const FACADES = ['brick', 'brown', 'grey', 'siding', 'cream', 'ware'].map((s, i) => {
  const a = facadeTex(s, 100 + i * 7), b = facadeTex(s, 300 + i * 13);
  const mk = t => { const m = new THREE.MeshStandardMaterial({ map: t.map, emissiveMap: t.emis, emissive: 0xffffff, emissiveIntensity: 1.15, roughness: 0.9, metalness: 0, envMapIntensity: 0.45 }); m.userData.mask = t.mask; return m; };
  return { style: s, mats: [mk(a), mk(b)], batches: [new Batch(), new Batch()] };
});
const B_ROOF = new Batch();
// simple shapes that real scanned models replace once they load
const B_BARREL = new Batch(), B_BARREL_FIRE = new Batch(), B_BARRIER = new Batch(), B_VENT = new Batch();
const FALLBACK = {}, BARRIERS = [], DUMPSTERS = [];
const LAMPS = [], BARRELS = [], VENTS = [], HEATERS = [], SIGNS = [], PARK_SPOTS = [], SIGNAL_HEADS = [];
let SIGNAL_MESH = null;
const RESERVED = [];
const reserve = (x0, z0, x1, z1) => RESERVED.push({ x0, z0, x1, z1 });
const overlapsReserved = (x0, z0, x1, z1, m) => RESERVED.some(r => x0 < r.x1 + m && x1 > r.x0 - m && z0 < r.z1 + m && z1 > r.z0 - m);
function vbox(batch, x, y, z, w, h, d, color, ry) { batch.add(GEO.box, mtx(x, y + h / 2, z, w, h, d, 0, ry || 0, 0), color); }
function solid(x, y, z, w, h, d, color, tag, batch) {
  vbox(batch || B_PROPS, x, y, z, w, h, d, color);
  return addCol(x - w / 2, y, z - d / 2, x + w / 2, y + h, z + d / 2, tag);
}
function vcyl(batch, x, y, z, r, h, color, seg6) { batch.add(seg6 ? GEO.cyl6 : GEO.cyl, mtx(x, y + h / 2, z, r, h, r), color); }

function facadeBox(F, bt, cx, cy, cz, w, h, d, faces, uo) {
  const geo = new THREE.BoxGeometry(w, h, d).toNonIndexed();
  const uv = geo.attributes.uv;
  const dims = [[d, h], [d, h], [w, d], [w, d], [w, h], [w, h]];
  for (let f = 0; f < 6; f++) for (let i = 0; i < 6; i++) { const k = f * 6 + i; uv.setXY(k, uv.getX(k) * dims[f][0] / 12 + (uo || 0), uv.getY(k) * dims[f][1] / 12); }
  const m = mtx(cx, cy, cz, 1, 1, 1);
  for (const f of faces) bt.add(geo, m, 0xffffff, f * 6, 6);
}
// face: which side meets the street ('n' = -z, 's' = +z, 'w' = -x, 'e' = +x)
function building(x0, z0, x1, z1, h, styleIdx, variant, face) {
  const w = x1 - x0, d = z1 - z0, cx = (x0 + x1) / 2, cz = (z0 + z1) / 2;
  const F = FACADES[styleIdx];
  const uo = Math.floor(Math.random() * 4) * 0.25;
  const bt = F.batches[variant === undefined ? (Math.random() < 0.5 ? 0 : 1) : variant];
  facadeBox(F, bt, cx, h / 2, cz, w, h, d, [0, 1, 4, 5], uo);
  const stone = styleIdx === 2 ? 0x8f887a : styleIdx === 5 ? 0x55585c : 0x7a6e60;
  // roof cap, cornice and a string course at the first floor
  vbox(B_ROOF, cx, h, cz, w + 0.3, 0.28, d + 0.3, 0xffffff);
  vbox(B_PROPS, cx, h - 0.55, cz, w + 0.55, 0.55, d + 0.55, stone);
  vbox(B_PROPS, cx, h - 0.85, cz, w + 0.3, 0.3, d + 0.3, 0x2a2622);
  if (styleIdx !== 5) vbox(B_PROPS, cx, 2.95, cz, w + 0.14, 0.2, d + 0.14, stone);
  // street-face details
  if (face) {
    const along = face === 'n' || face === 's' ? 'x' : 'z';
    const len = along === 'x' ? w : d;
    const sgn = face === 'n' || face === 'w' ? -1 : 1;
    const fx = along === 'x' ? cx : (face === 'w' ? x0 : x1), fz = along === 'z' ? cz : (face === 'n' ? z0 : z1);
    // greystone and cream two-flats get bay windows
    if ((styleIdx === 2 || styleIdx === 4) && len >= 8 && h >= 6) {
      const bw = 2.7, bd = 0.9, bh = h - 1.6, off = len / 2 - 2.6;
      for (const o of len > 12 ? [-off, off] : [-off]) {
        const bx = along === 'x' ? cx + o : fx + sgn * bd / 2, bz = along === 'x' ? fz + sgn * bd / 2 : cz + o;
        facadeBox(F, bt, bx, 0.9 + bh / 2, bz, along === 'x' ? bw : bd, bh, along === 'x' ? bd : bw, along === 'x' ? [0, 1, face === 's' ? 4 : 5] : [face === 'e' ? 0 : 1, 4, 5], uo);
        vbox(B_PROPS, bx, 0.9 + bh, bz, (along === 'x' ? bw : bd) + 0.2, 0.22, (along === 'x' ? bd : bw) + 0.2, stone);
        vbox(B_ROOF, bx, 1.12 + bh, bz, (along === 'x' ? bw : bd) + 0.2, 0.12, (along === 'x' ? bd : bw) + 0.2, 0xffffff);
      }
    }
    // brick walk-ups get a black fire escape
    if ((styleIdx === 0 || styleIdx === 1) && h >= 9 && len >= 9 && Math.random() < 0.7) {
      const o = (Math.random() < 0.5 ? -1 : 1) * (len / 2 - 3);
      const ex = along === 'x' ? cx + o : fx + sgn * 0.55, ez = along === 'x' ? fz + sgn * 0.55 : cz + o;
      const pw = along === 'x' ? 2.8 : 1.0, pd = along === 'x' ? 1.0 : 2.8;
      for (let y = 3.2; y < h - 1; y += 3) {
        vbox(B_PROPS, ex, y, ez, pw, 0.07, pd, 0x15171a);
        vbox(B_SNOW, ex, y + 0.07, ez, pw * 0.94, 0.05, pd * 0.94, 0xffffff);
        vbox(B_PROPS, ex + (along === 'x' ? 0 : sgn * 0.45), y + 0.5, ez + (along === 'x' ? sgn * 0.45 : 0), along === 'x' ? pw : 0.05, 0.05, along === 'x' ? 0.05 : pd, 0x15171a);
        B_PROPS.add(GEO.box, mtx(ex, y - 1.4, ez, along === 'x' ? 0.06 : 0.5, 3.1, along === 'x' ? 0.5 : 0.06, along === 'x' ? 0 : 0.5, 0, along === 'x' ? 0.5 : 0), 0x15171a);
      }
    }
  }
  // rooftop clutter: AC units, chimneys, and the odd water tower on warehouses
  if (w > 6 && d > 6) {
    const R = Math.random;
    if (R() < 0.7) vbox(B_PROPS, cx + (R() - 0.5) * (w - 4), h, cz + (R() - 0.5) * (d - 4), 1.3, 0.8, 1.7, 0x8a9096);
    if (styleIdx !== 5 && R() < 0.6) vbox(B_PROPS, cx + (R() - 0.5) * (w - 3), h, cz + (R() - 0.5) * (d - 3), 0.7, 1.5, 0.7, 0x5d3328);
    if (styleIdx === 5 && h > 7 && R() < 0.45) {
      const tx = cx + (R() - 0.5) * (w - 6), tz = cz + (R() - 0.5) * (d - 6);
      for (const [a, b] of [[-1, -1], [1, -1], [-1, 1], [1, 1]]) vbox(B_PROPS, tx + a * 1.1, h, tz + b * 1.1, 0.16, 2.6, 0.16, 0x2a2420);
      vcyl(B_PROPS, tx, h + 2.6, tz, 1.75, 2.6, 0x5a4030);
      B_PROPS.add(GEO.cone, mtx(tx, h + 5.75, tz, 1.95, 1.1, 1.95), 0x3a2c24);
      B_SNOW.add(GEO.cone, mtx(tx, h + 5.85, tz, 1.75, 0.95, 1.75), 0xffffff);
    }
  }
  addCol(x0, 0, z0, x1, h, z1, 'building');
}

/* ---- districts ---- */
const NBX = XB.length - 1, NBZ = ZB.length - 1;
function districtOf(i, j) {
  if (i === 2 && j === 3) return 'park';
  if (i === NBX - 1) return 'lake';        // Shore Dr lakefront
  if (i === 0) return 'yard';              // Kessler rail yard
  if (j === 0) return 'industry';          // Ironside industrial strip
  if (i === NBX - 2) return 'ware';        // warehouses east of the L
  if (j === NBZ - 2 && i >= 1 && i <= 3) return 'courts';  // Garnet Courts towers
  if (j === NBZ - 1) return 'rows';        // two-flats south of Sable St
  return 'res';
}
const ALLEYS = [];
for (let i = 0; i < NBX; i++) for (let j = 0; j < NBZ; j++) {
  const d = districtOf(i, j); if (d === 'park' || d === 'lake' || d === 'yard' || d === 'courts') continue;
  const b = blockRect(i, j); if (b.z1 - b.z0 < 50) continue;
  ALLEYS.push([b.x0 + (i === 0 ? 8 : 0), b.x1, (b.z0 + b.z1) / 2]);
}

/* ---- ground, roads, sidewalks ---- */
(function ground() {
  const g = new THREE.PlaneGeometry(3000, 3000); g.rotateX(-Math.PI / 2);
  const uv = g.attributes.uv; for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i) * 3000 / 14, uv.getY(i) * 3000 / 14);
  const m = new THREE.Mesh(g, MAT.ground); m.receiveShadow = true; scene.add(m);
  const roadB = new Batch(), walkB = new Batch();
  const quad = (batch, x0, z0, x1, z1, y, alongX, tile, vTile) => {
    const geo = new THREE.PlaneGeometry(1, 1).toNonIndexed(); geo.rotateX(-Math.PI / 2);
    const uvA = geo.attributes.uv; const L = alongX ? x1 - x0 : z1 - z0, W = alongX ? z1 - z0 : x1 - x0;
    for (let i = 0; i < uvA.count; i++) { const u = uvA.getX(i), v = uvA.getY(i); if (alongX) uvA.setXY(i, u * L / tile, v * (vTile ? W / vTile : 1)); else uvA.setXY(i, v * L / tile, u * (vTile ? W / vTile : 1)); }
    batch.add(geo, mtx((x0 + x1) / 2, y, (z0 + z1) / 2, x1 - x0, 1, z1 - z0), 0xffffff);
  };
  const E = MAP_HALF + 10;
  for (const z of ZL) { quad(roadB, -E, z - ROAD_HW, ROAD_X_END, z + ROAD_HW, 0.012, true, 12); quad(walkB, -E, z - WALK_EDGE, ROAD_X_END, z - ROAD_HW, 0.006, true, 4, 4); quad(walkB, -E, z + ROAD_HW, ROAD_X_END, z + WALK_EDGE, 0.006, true, 4, 4); }
  for (const x of XL) { quad(roadB, x - ROAD_HW, -E, x + ROAD_HW, E, 0.016, false, 12); quad(walkB, x - WALK_EDGE, -E, x - ROAD_HW, E, 0.008, false, 4, 4); quad(walkB, x + ROAD_HW, -E, x + WALK_EDGE, E, 0.008, false, 4, 4); }
  // lakefront promenade
  quad(walkB, ROAD_X_END, -E, LAKE_X - 6, E, 0.007, false, 4, 4);
  const rm = new THREE.Mesh(roadB.build(), MAT.road); rm.receiveShadow = true; scene.add(rm);
  const wm = new THREE.Mesh(walkB.build(), MAT.walk); wm.receiveShadow = true; scene.add(wm);
  // alleys (slushy)
  const alleyB = new Batch();
  for (const [x0, x1, z] of ALLEYS) quad(alleyB, x0, z - 3, x1, z + 3, 0.01, true, 12);
  const am = new THREE.Mesh(alleyB.build(), MAT.road); am.receiveShadow = true; scene.add(am);
  // world bounds
  for (const [x0, z0, x1, z1] of [[-E, -E, E, -BOUND - 0.5], [-E, BOUND + 0.5, E, E], [-E, -E, -BOUND - 0.5, E], [BOUND + 0.5, -E, E, E]]) addCol(x0, 0, z0, x1, 40, z1, 'bound');
})();

/* ---- the L: deck, columns, tracks, station ---- */
const BED_X0 = 64.4, BED_X1 = 75.6;
(function theL() {
  const steel = 0x2b3440, steelD = 0x1b222b, conc = 0x8d939a;
  for (let z = -320; z < 320; z += 40) {
    vbox(B_PROPS, LX, DECK_Y0, z + 20, BED_X1 - BED_X0, DECK_Y - DECK_Y0, 40, steelD);
    vbox(B_PROPS, BED_X0 + 0.2, DECK_Y0 - 0.9, z + 20, 0.4, 0.9, 40, steel);
    vbox(B_PROPS, BED_X1 - 0.2, DECK_Y0 - 0.9, z + 20, 0.4, 0.9, 40, steel);
    vbox(B_PROPS, LX, DECK_Y0 - 0.6, z + 20, 0.5, 0.6, 40, steel);
  }
  addCol(BED_X0, DECK_Y0, -BOUND, BED_X1, DECK_Y, BOUND, 'deck');
  for (const tx of TRACKS) {
    for (const off of [-0.72, 0.72]) vbox(B_PROPS, tx + off, DECK_Y, 0, 0.12, 0.16, 640, 0x6f7780);
    vbox(B_PROPS, tx + (tx < LX ? -1.35 : 1.35), DECK_Y, 0, 0.2, 0.2, 640, 0x8a7a3a);
    for (let z = -300; z < 300; z += 1.2) vbox(B_PROPS, tx, DECK_Y - 0.02, z, 2.2, 0.06, 0.25, 0x2a221c);
  }
  for (let z = -(MAP_HALF - 6); z <= MAP_HALF - 6; z += 16) {
    if (ZL.some(l => Math.abs(z - l) < 11)) continue;
    for (const cx of [BED_X0 + 0.6, BED_X1 - 0.6]) {
      solid(cx, 0, z, 0.7, DECK_Y0 - 0.9, 0.7, steel, 'column');
      vbox(B_PROPS, cx, 0, z, 1.0, 0.5, 1.0, conc);
    }
    vbox(B_PROPS, LX, DECK_Y0 - 1.1, z, BED_X1 - BED_X0, 0.5, 0.5, steel);
  }
  for (const side of [-1, 1]) {
    const px0 = side < 0 ? DECK_X0 : 74.8, px1 = side < 0 ? 65.2 : DECK_X1;
    const pcx = (px0 + px1) / 2, pw = px1 - px0;
    solid(pcx, DECK_Y0, 0, pw, PLAT_Y - DECK_Y0, 44, conc, 'platform');
    const edgeX = side < 0 ? px1 - 0.25 : px0 + 0.25;
    vbox(B_PROPS, edgeX, PLAT_Y, 0, 0.5, 0.02, 44, 0xd8b23a);
    const outX = side < 0 ? px0 + 0.12 : px1 - 0.12;
    for (let z = -16; z <= 16; z += 8) vbox(B_PROPS, outX - side * 0.5, PLAT_Y, z, 0.18, 3.0, 0.18, steel);
    vbox(B_PROPS, pcx, PLAT_Y + 3.0, 0, pw + 0.4, 0.25, 36, steelD);
    vbox(B_SNOW, pcx, PLAT_Y + 3.25, 0, pw + 0.5, 0.2, 36.2, 0xffffff);
    for (let z = -14; z <= 14; z += 7) vbox(B_EMIS, pcx, PLAT_Y + 2.9, z, 1.2, 0.06, 0.3, 0xfff1d8);
    vbox(B_PROPS, outX, PLAT_Y, 0, 0.08, 1.1, 44, steel);
    addCol(outX - 0.1, PLAT_Y, -22, outX + 0.1, PLAT_Y + 1.1, 22, 'rail');
    // warming shelter: back wall on the outside, open toward the tracks, heat lamp inside
    const shz = side < 0 ? 8 : -8;
    const backX = side < 0 ? px0 + 0.35 : px1 - 0.35, tipX = backX - side * 1.7;
    solid(backX, PLAT_Y, shz, 0.12, 2.6, 5.2, 0xffffff, 'glass', B_GLASS);
    for (const e of [-2.6, 2.6]) solid((backX + tipX) / 2, PLAT_Y, shz + e, 1.7, 2.6, 0.12, 0xffffff, 'glass', B_GLASS);
    for (const e of [-2.6, 2.6]) vbox(B_PROPS, tipX, PLAT_Y, shz + e, 0.1, 2.6, 0.14, steelD);
    vbox(B_PROPS, (backX + tipX) / 2, PLAT_Y + 2.6, shz, 1.9, 0.16, 5.4, steelD);
    vbox(B_EMIS, (backX + tipX) / 2, PLAT_Y + 2.45, shz, 0.5, 0.12, 2.4, 0xff5a1a);
    HEATERS.push({ x: (backX + tipX) / 2, y: PLAT_Y, z: shz, r: 2.6 });
    vbox(B_PROPS, backX - side * 0.45, PLAT_Y + 0.45, shz, 0.5, 0.08, 3, 0x5a4a3a);
    LAMPS.push({ x: (backX + tipX) / 2, y: PLAT_Y + 2.2, z: shz, heater: true });
    const smat = new THREE.MeshBasicMaterial({ map: signTex('CALDER', { bg: '#0d1c2e', fg: '#f4f8ff', glow: '#9fd0ff', size: 84, blur: 6, border: '#9fd0ff' }) });
    for (const f of [1, -1]) { const sm = new THREE.Mesh(new THREE.PlaneGeometry(4.2, 0.9), smat); sm.position.set(pcx + f * 0.02, PLAT_Y + 2.35, side < 0 ? -12 : 12); sm.rotation.y = f * Math.PI / 2; scene.add(sm); vbox(B_PROPS, pcx, PLAT_Y + 1.85, side < 0 ? -12 : 12, 0.03, 1.0, 4.3, 0x1b222b); }
    // stairs down to the sidewalk, south of the platform, outside the track bed
    const sx = side < 0 ? 62 : 78;
    const N = 12, top = PLAT_Y, len = 22;
    for (let i = 0; i < N; i++) {
      const h = top * (N - i) / (N + 1);
      solid(sx, 0, 22 + (i + 0.5) * len / N, 3, h, len / N, i % 2 ? 0x7b8189 : 0x858b93, 'stairs');
    }
    for (const off of [-1.55, 1.55]) {
      for (let i = 0; i < N; i += 3) { const z = 22 + (i + 0.5) * len / N; const h = top * (N - i) / (N + 1); vbox(B_PROPS, sx + off, 0, z, 0.08, h + 1.0, 0.08, steel); }
      const ang = Math.atan2(top, len);
      B_PROPS.add(GEO.box, mtx(sx + off, top / 2 + 1.0, 22 + len / 2, 0.08, 0.08, Math.hypot(top, len), ang, 0, 0), steel);
      addCol(sx + off - 0.05, 0, 22, sx + off + 0.05, PLAT_Y + 1, 44, 'rail');
    }
    signPlane('L', sx, 2.6, 44.3, 0.8, 0.8, 0, { bg: '#0d1c2e', fg: '#ffffff', glow: '#9fd0ff', size: 96, w: 128, h: 128, blur: 4 });
  }
  for (let z = -136; z <= 136; z += 32) LAMPS.push({ x: LX, y: DECK_Y0 - 1.4, z, under: true });
  for (let z = -12; z <= 12; z += 12) { LAMPS.push({ x: 63, y: PLAT_Y + 2.7, z, plat: true }); LAMPS.push({ x: 77, y: PLAT_Y + 2.7, z, plat: true }); }
})();

/* ---- street furniture helpers ---- */
function snowbank(x, z, alongX, len) {
  const w = alongX ? len : 1.1, d = alongX ? 1.1 : len;
  for (let i = 0; i < 3; i++) B_SNOW.add(GEO.sph, mtx(x + (alongX ? (i - 1) * len / 3 : rand(-.1, .1)), 0.35, z + (alongX ? rand(-.1, .1) : (i - 1) * len / 3), (alongX ? len / 2.6 : 0.65), rand(0.62, 0.78), (alongX ? 0.65 : len / 2.6)), 0xffffff);
  addCol(x - w / 2, 0, z - d / 2, x + w / 2, 1.08, z + d / 2, 'cover');
}
function dumpster(x, z, alongX, col) {
  DUMPSTERS.push({ x, z, alongX });
  const w = alongX ? 2.0 : 1.3, d = alongX ? 1.3 : 2.0;
  vbox(B_PROPS, x, 0.12, z, w, 1.1, d, col || pick([0x234a35, 0x1f3550, 0x4a3a22]));
  vbox(B_PROPS, x, 1.22, z, w + 0.06, 0.08, d + 0.06, 0x111111);
  vbox(B_SNOW, x, 1.3, z, w * 0.9, 0.1, d * 0.9, 0xffffff);
  addCol(x - w / 2, 0, z - d / 2, x + w / 2, 1.3, z + d / 2, 'cover');
}
function barrier(x, z, alongX, len) {
  len = len || 3; const w = alongX ? len : 0.6, d = alongX ? 0.6 : len;
  BARRIERS.push({ x, z, alongX, len });
  vbox(B_BARRIER, x, 0, z, w, 1.08, d, 0x9a9890);
  vbox(B_BARRIER, x, 0.5, z, alongX ? len : 0.62, 0.16, alongX ? 0.62 : len, 0xc9a43a);
  vbox(B_BARRIER, x, 1.08, z, w * 0.95, 0.06, d * 0.95, 0xeef3f9);
  addCol(x - w / 2, 0, z - d / 2, x + w / 2, 1.08, z + d / 2, 'cover');
}
function lamp(x, z, armDX, armDZ) {
  vcyl(B_PROPS, x, 0, z, 0.11, 7.6, 0x3a3f46);
  B_PROPS.add(GEO.box, mtx(x + armDX * 0.8, 7.5, z + armDZ * 0.8, Math.abs(armDX) * 1.6 + 0.1, 0.1, Math.abs(armDZ) * 1.6 + 0.1), 0x3a3f46);
  vbox(B_PROPS, x + armDX * 1.6, 7.32, z + armDZ * 1.6, 0.6, 0.22, 0.6, 0x2a2e33);
  vbox(B_EMIS, x + armDX * 1.6, 7.24, z + armDZ * 1.6, 0.44, 0.08, 0.44, 0xffb46a);
  addCol(x - 0.12, 0, z - 0.12, x + 0.12, 7.6, z + 0.12, 'pole');
  LAMPS.push({ x: x + armDX * 1.6, y: 7.1, z: z + armDZ * 1.6 });
}
function barrel(x, z) {
  vcyl(B_BARREL, x, 0, z, 0.42, 0.95, 0x5a2e1a);
  vcyl(B_BARREL, x, 0.3, z, 0.43, 0.06, 0x3a1e10); vcyl(B_BARREL, x, 0.65, z, 0.43, 0.06, 0x3a1e10);
  vcyl(B_BARREL_FIRE, x, 0.9, z, 0.36, 0.04, 0xff7a2a);
  addCol(x - 0.42, 0, z - 0.42, x + 0.42, 0.95, z + 0.42, 'barrel');
  BARRELS.push({ x, y: 1.0, z, r: 4.6, t: Math.random() * 10 });
  LAMPS.push({ x, y: 1.7, z, fire: true });
}
function vent(x, z) {
  vcyl(B_VENT, x, 0.02, z, 0.6, 0.03, 0x2a2a2a);
  VENTS.push({ x, z, r: 2.6, t: Math.random() * 5 });
}
function tree(x, z, s) {
  s = s || rand(0.85, 1.3);
  const h = 5.5 * s;
  B_PROPS.add(GEO.cyl6, mtx(x, h / 2, z, 0.2 * s, h, 0.2 * s), 0x2a211c);
  for (let i = 0; i < 6; i++) {
    const a = i / 6 * TAU + rand(-.3, .3), y = h * rand(0.45, 0.85), L = rand(1.6, 2.8) * s;
    const m = mtx(x + Math.cos(a) * L * 0.45, y + L * 0.3, z + Math.sin(a) * L * 0.45, 0.06 * s, L, 0.06 * s, Math.sin(a) * 0.9, 0, -Math.cos(a) * 0.9);
    B_PROPS.add(GEO.cyl6, m, 0x2a211c);
    B_SNOW.add(GEO.box, mtx(x + Math.cos(a) * L * 0.5, y + L * 0.36, z + Math.sin(a) * L * 0.5, 0.1 * s, 0.05, 0.1 * s), 0xffffff);
  }
  addCol(x - 0.22 * s, 0, z - 0.22 * s, x + 0.22 * s, h, z + 0.22 * s, 'tree');
}
function fence(x0, z0, x1, z1, h) {
  const alongX = Math.abs(x1 - x0) > Math.abs(z1 - z0);
  const len = alongX ? Math.abs(x1 - x0) : Math.abs(z1 - z0);
  vbox(B_PROPS, (x0 + x1) / 2, 0, (z0 + z1) / 2, alongX ? len : 0.08, h || 1.6, alongX ? 0.08 : len, 0x3b3f44);
  for (let s = 0; s <= len; s += 2.5) vbox(B_PROPS, alongX ? Math.min(x0, x1) + s : x0, 0, alongX ? z0 : Math.min(z0, z1) + s, 0.12, (h || 1.6) + 0.1, 0.12, 0x24272b);
  addCol(Math.min(x0, x1) - 0.06, 0, Math.min(z0, z1) - 0.06, Math.max(x0, x1) + 0.06, h || 1.6, Math.max(z0, z1) + 0.06, 'fence');
}
function shopPane(x, y, z, w, h, ry, dim) {
  const geo = new THREE.PlaneGeometry(1, 1).toNonIndexed();
  const uv = geo.attributes.uv; const off = Math.random(); for (let i = 0; i < uv.count; i++) uv.setX(i, uv.getX(i) * w / 8 + off);
  B_SHOP.add(geo, mtx(x, y, z, w, h, 1, 0, ry, 0), dim ? 0x9a8a78 : 0xffffff);
}
function signPlane(text, x, y, z, w, h, ry, opts) {
  const m = new THREE.Mesh(new THREE.PlaneGeometry(w, h), new THREE.MeshBasicMaterial({ map: signTex(text, opts), transparent: !!opts.transparent }));
  m.position.set(x, y, z); m.rotation.y = ry; scene.add(m); SIGNS.push(m); return m;
}

/* ---- special buildings ---- */
(function special() {
  // HOME: greystone two-flat on Bishop St, door faces east
  reserve(-28, -52, -10, -32);
  building(-26, -50, -10.5, -34, 9.5, 2, 0, null);
  vbox(B_PROPS, -9.6, 0, -42, 1.8, 0.5, 3.4, 0x8a8478); vbox(B_PROPS, -9.2, 0.5, -42, 1.0, 0.4, 3.0, 0x8a8478);
  addCol(-10.5, 0, -43.7, -8.7, 0.5, -40.3, 'stoop');
  vbox(B_EMIS, -10.45, 1.0, -42, 0.04, 2.1, 1.1, 0x40301c);
  vbox(B_EMIS, -10.4, 3.4, -42, 0.1, 0.18, 0.3, 0xffd8a0);
  LAMPS.push({ x: -9.6, y: 3.2, z: -42, porch: true });
  // CORNER STORE: NE corner of Calder & Bishop
  reserve(10, -28, 28, -10);
  building(10.5, -26, 26, -10.5, 7, 1, 1);
  shopPane(18, 1.7, -10.47, 13, 2.6, 0); shopPane(10.47, 1.7, -18, 12, 2.6, -Math.PI / 2);
  vbox(B_PROPS, 18, 3.1, -10.0, 15.5, 0.25, 1.2, 0x2a1810);
  signPlane('CALDER MINI MART', 18, 3.85, -10.3, 10, 1.2, 0, { bg: '#1a0705', fg: '#ff5a3a', glow: '#ff3a1a', size: 78, w: 1024, h: 128 });
  signPlane('COFFEE · HAND WARMERS · ATM', 18, 2.75, -10.2, 6, 0.45, 0, { bg: '#0a0a0a', fg: '#ffd27a', glow: '#ffb040', size: 54, w: 1024, h: 80, blur: 8 });
  signPlane('ICE', 12.2, 1.3, -9.4, 1.2, 0.6, 0, { bg: '#e8f4ff', fg: '#1f6fd0', glow: '#1f6fd0', size: 90, w: 256, h: 128, blur: 0 });
  solid(12.2, 0, -9.6, 1.4, 1.7, 0.9, 0xc8d6e4, 'cover');
  LAMPS.push({ x: 18, y: 2.6, z: -8.6, shop: true });
  // STUDIO: Benny's two-flat with basement stairwell on Calder Ave
  reserve(30, -30, 50, -10);
  building(30.5, -28, 48, -10.5, 8.5, 0, 0, null);
  vbox(B_PROPS, 41, -0.02, -9.8, 2.2, 0.04, 1.4, 0x121418);
  vbox(B_EMIS, 41, 0.0, -10.46, 1.0, 1.0, 0.05, 0x7a1a14);
  fence(39.8, -10.3, 39.8, -8.9, 0.9); fence(42.2, -10.3, 42.2, -8.9, 0.9);
  signPlane('BASEMENT 808', 41, 2.4, -10.4, 2.6, 0.62, 0, { bg: '#0a0404', fg: '#ff4a3a', glow: '#ff2a1a', size: 80, w: 512, h: 140 });
  signPlane('ON AIR', 38.6, 1.2, -10.4, 0.9, 0.3, 0, { bg: '#220404', fg: '#ff2a2a', glow: '#ff0000', size: 70, w: 256, h: 90 });
  LAMPS.push({ x: 41, y: 2.2, z: -8.8, porch: true });
  // REC CENTER in the park
  reserve(-40, 48, -10, 80);
  building(-38, 50, -12.5, 78, 8, 4, 1);
  { const geo = GEO.plane; B_GYM.add(geo, mtx(-12.47, 4.3, 64, 18, 3.4, 1, 0, Math.PI / 2, 0), 0xffffff); }
  vbox(B_EMIS, -12.42, 0.0, 63, 0.06, 2.3, 2.2, 0xe8d2a0);
  vbox(B_PROPS, -11.8, 2.6, 63, 1.4, 0.18, 3.2, 0x1d3b2a);
  signPlane('CALDER PARK REC CENTER', -12.3, 6.6, 64, 13, 1.1, Math.PI / 2, { bg: '#08140e', fg: '#9ff0c0', glow: '#5fd090', size: 64, w: 1024, h: 96 });
  signPlane('OPEN TILL 10 · ALL AGES', -12.3, 5.6, 64, 6, 0.5, Math.PI / 2, { bg: '#08140e', fg: '#f0f8f4', glow: '#5fd090', size: 54, w: 1024, h: 96, blur: 4 });
  LAMPS.push({ x: -10.5, y: 2.8, z: 63, porch: true });
  barrel(COACH_POS.x - 1.0, COACH_POS.z + 1.7);
  // vacant lot (south of Calder, east of Bishop) with barrel + fence
  reserve(22, 10, 50, 40);
  fence(22, 40, 50, 40, 1.8); fence(50, 10.5, 50, 40, 1.8);
  barrel(36, 26);
  dumpster(26, 34, true); snowbank(42, 20, true, 4); barrier(30, 16, true, 3);
  B_SNOW.add(GEO.sph, mtx(44, 0.4, 33, 2.4, 0.8, 1.6), 0xffffff);
  // AREA 7 POLICE station on Garnet St, with cruisers out front
  reserve(92, 50, 128, 80);
  building(95, 56, 125, 79, 9, 5, 0, null);
  vbox(B_EMIS, 110, 0.3, 79.06, 3.2, 2.4, 0.05, 0xcfe2ff);
  vbox(B_PROPS, 110, 2.9, 79.6, 6, 0.25, 1.4, 0x1a2438);
  signPlane('AREA 7 · POLICE', 110, 5.4, 79.08, 9, 1.1, 0, { bg: '#0a1426', fg: '#e8f0ff', glow: '#5a8aff', size: 78, w: 1024, h: 128 });
  for (const x of [99, 121]) { vcyl(B_PROPS, x, 0, 80.6, 0.1, 6, 0x3a3f46); vbox(B_EMIS, x, 5.6, 80.6, 0.5, 0.35, 0.35, 0x2a5aff); }
  PARK_SPOTS.push({ x: 101, z: 85.4, alongX: true, yaw: Math.PI / 2, model: 'police', color: 0x101216, locked: true, tag: 'station' }, { x: 118, z: 85.4, alongX: true, yaw: Math.PI / 2, model: 'police', color: 0x101216, locked: true, tag: 'station' });
  // CALDER GENERAL hospital facing Harlan Ave
  reserve(-146, -66, -104, -24);
  building(-140, -62, -106, -28, 16, 4, 1, null);
  vbox(B_EMIS, -105.94, 0.3, -45, 0.05, 2.5, 4, 0xe8f4ff);
  vbox(B_PROPS, -105.2, 2.8, -45, 1.8, 0.25, 6, 0xd8dde2);
  signPlane('CALDER GENERAL', -105.9, 13.5, -45, 14, 1.4, Math.PI / 2, { bg: '#f2f6fa', fg: '#1a3a6a', glow: '#1a3a6a', size: 80, w: 1024, h: 110, blur: 0 });
  signPlane('EMERGENCY', -105.9, 3.6, -45, 4.6, 0.7, Math.PI / 2, { bg: '#b0121a', fg: '#ffffff', glow: '#ffffff', size: 70, w: 512, h: 90, blur: 4 });
  // MARROW MOTORS lot on Calder Ave
  reserve(82, 12, 142, 46);
  building(124, 26, 140, 44, 5, 5, 1, null);
  signPlane('MARROW MOTORS', 132, 4.2, 25.94, 12, 1.2, Math.PI, { bg: '#0a0a0a', fg: '#ffd24a', glow: '#ffb000', size: 84, w: 1024, h: 110 });
  fence(84, 46, 124, 46, 1.5); fence(84, 12.5, 84, 46, 1.5);
  for (let i = 0; i < 6; i++) PARK_SPOTS.push({ x: 90 + i * 5.6, z: 22, alongX: false, yaw: Math.PI, model: ['coupe', 'suv', 'pickup', 'sedan', 'van', 'coupe'][i], color: [0xb01822, 0xe8e8ea, 0x1e2f4a, 0x2a2c30, 0xd8dade, 0xd9a93a][i], locked: true, tag: 'dealer' });
  for (let x = 86; x < 122; x += 6) LAMPS.push({ x, y: 4.4, z: 16, park: true });
  for (let x = 86; x < 122; x += 6) { vcyl(B_PROPS, x, 0, 15.2, 0.07, 4.4, 0x3a3f46); vbox(B_EMIS, x, 4.3, 15.2, 0.6, 0.12, 0.3, 0xfff2d8); }
  // REYES meeting spot: unmarked car under the L at Low End Rd
  PARK_SPOTS.push({ x: 67.1, z: -104, alongX: false, model: 'sedan', color: 0x16181c, locked: true, tag: 'reyes' });
  vbox(B_EMIS, 67.1, 1.2, -102.6, 0.6, 0.08, 0.12, 0x2050ff);
})();

/* ---- new districts: Kessler rail yard, Shore Dr lakefront, Garnet Courts hoops, Ironside Fuel ---- */
const roadGapZ = (z, m) => ZL.some(l => Math.abs(z - l) < (m || WALK_EDGE + 1));
function zSegments(z0, z1, m) { // stretches of a N-S line that don't cross an E-W street
  const segs = []; let a = z0;
  for (const l of ZL) { if (l - m > a && l - m < z1) { segs.push([a, l - m]); a = l + m; } else if (l + m > a && l - m <= a) a = l + m; }
  if (a < z1) segs.push([a, z1]);
  return segs;
}
(function railYard() {
  const R = rng(4242);
  const tracks = [-238, -229.5, -221, -212.5];
  const segs = zSegments(-MAP_HALF + 2, MAP_HALF - 2, WALK_EDGE + 0.5);
  for (const tx of tracks) {
    for (const [a, b] of segs) {
      vbox(B_PROPS, tx, 0, (a + b) / 2, 3.4, 0.06, b - a, 0x34302c);
      for (let z = a + 0.6; z < b - 0.4; z += 1.4) vbox(B_PROPS, tx, 0.05, z, 2.5, 0.07, 0.26, 0x2b231c);
    }
    for (const off of [-0.72, 0.72]) vbox(B_PROPS, tx + off, 0.06, 0, 0.1, 0.13, 2 * MAP_HALF - 4, 0x75706a);
  }
  // freight cars parked on the sidings (cover)
  const cols = [0x6a3a2a, 0x46566a, 0x7a6a3a, 0x3a4a3a, 0x8a4a2a, 0x2a3a5a, 0x5a5a5e];
  for (const tx of tracks) {
    let z = -MAP_HALF + 8 + R() * 20;
    while (z < MAP_HALF - 22) {
      const L = 13 + R() * 4;
      if (R() < 0.6 && !ZL.some(l => z + L > l - WALK_EDGE - 1.5 && z < l + WALK_EDGE + 1.5)) {
        const c = pick(cols), tank = R() < 0.25;
        if (tank) { B_PROPS.add(GEO.cyl, mtx(tx, 2.4, z + L / 2, 1.45, L - 1, 1.45, Math.PI / 2, 0, 0), 0x2c2f33); addCol(tx - 1.45, 0.9, z + 0.5, tx + 1.45, 3.9, z + L - 0.5, 'cover'); }
        else { solid(tx, 0.95, z + L / 2, 3.0, 3.5, L, c, 'cover'); vbox(B_PROPS, tx + 1.52, 1.6, z + L / 2, 0.04, 2.2, 3.2, 0x1e1e20); vbox(B_PROPS, tx - 1.52, 1.6, z + L / 2, 0.04, 2.2, 3.2, 0x1e1e20); }
        vbox(B_SNOW, tx, tank ? 3.85 : 4.45, z + L / 2, tank ? 1.6 : 3.1, 0.12, L - 0.6, 0xffffff);
        for (const dz of [2.4, L - 2.4]) vbox(B_PROPS, tx, 0.12, z + dz, 2.2, 0.8, 2.6, 0x1b1d20);
        z += L + 1.0;
      } else z += 7 + R() * 16;
    }
  }
  // floodlight masts and the yard fence along Kessler Ave
  for (const z of [-215, -130, -45, 45, 135, 215]) { vcyl(B_PROPS, -204.5, 0, z, 0.16, 12, 0x3a3f46); vbox(B_EMIS, -205.3, 11.7, z, 0.35, 0.7, 2.6, 0xfff2d8); addCol(-204.7, 0, z - 0.2, -204.3, 12, z + 0.2, 'pole'); LAMPS.push({ x: -207, y: 11.5, z, park: true }); }
  for (const [a, b] of zSegments(-MAP_HALF + 2, MAP_HALF - 2, WALK_EDGE + 1)) fence(-202, a, -202, b, 2.4);
  solid(-245, 0, -100, 4, 3.2, 5, 0x5a4a3a, 'building'); vbox(B_SNOW, -245, 3.2, -100, 4.2, 0.2, 5.2, 0xffffff); vbox(B_EMIS, -242.98, 1.6, -100, 0.04, 0.8, 1.2, 0xffd8a0);
  signPlane('KESSLER YARD · NO TRESPASSING', -201.9, 2.0, -9, 6, 0.6, Math.PI / 2, { bg: '#1a1d22', fg: '#e8d8a0', glow: '#000', size: 56, w: 768, h: 80, blur: 0 });
})();
(function lakefront() {
  const R = rng(777), E = MAP_HALF + 10;
  // frozen lake out to the horizon
  const ice = new THREE.Mesh(new THREE.PlaneGeometry(2400, 5000), MAT.ice); ice.rotation.x = -Math.PI / 2; ice.position.set(LAKE_X + 1200, 0.016, 0); ice.receiveShadow = true; scene.add(ice);
  for (let k = 0; k < 140; k++) { const x = LAKE_X + 4 + Math.pow(R(), 1.6) * 600, z = (R() - 0.5) * 1400, w = 3 + R() * 18; B_SNOW.add(GEO.box, mtx(x, 0.02, z, w, 0.04, w * (0.3 + R() * 0.7), 0, R() * 3, 0), 0xffffff); }
  for (let k = 0; k < 40; k++) { const x = LAKE_X + 8 + R() * 220, z = (R() - 0.5) * 600; for (let q = 0; q < 6; q++) vbox(B_SNOW, x + q * 1.1, 0, z + (R() - 0.5) * 1.2, 1.2, 0.2 + R() * 0.5, 0.8, 0xdfefff, R()); }
  // rock revetment and the promenade rail
  for (let z = -E + 6; z < E - 6; z += 2.4) {
    const c = [0x62666c, 0x55595f, 0x707479][Math.floor(R() * 3)], h = 0.45 + R() * 0.7;
    vbox(B_PROPS, LAKE_X - 3.2 + R() * 1.4, -0.1, z, 2.0 + R(), h, 2.3, c, R() * 0.6);
    B_SNOW.add(GEO.box, mtx(LAKE_X - 3 + R(), h - 0.08, z, 1.6, 0.14, 1.8, 0, R(), 0), 0xffffff);
  }
  const RX = LAKE_X - 6.5;
  for (const [a, b] of zSegments(-E + 4, E - 4, WALK_EDGE)) {
    vbox(B_PROPS, RX, 1.0, (a + b) / 2, 0.08, 0.08, b - a, 0x2b3036);
    for (let z = a; z <= b; z += 2.4) vcyl(B_PROPS, RX, 0, z, 0.05, 1.08, 0x2b3036);
    addCol(RX - 0.1, 0, a, RX + 0.1, 1.1, b, 'fence');
  }
  for (let z = -E + 18; z < E - 12; z += 26) { if (roadGapZ(z, 12)) continue; lamp(RX - 2.2, z, -1, 0); }
  for (let z = -E + 30; z < E - 20; z += 34) { if (roadGapZ(z, 14)) continue; vbox(B_PROPS, RX - 1.2, 0.42, z, 0.5, 0.08, 1.8, 0x5a3e26); vbox(B_PROPS, RX - 1.0, 0.5, z, 0.08, 0.5, 1.8, 0x5a3e26); vbox(B_SNOW, RX - 1.2, 0.5, z, 0.46, 0.05, 1.7, 0xffffff); }
  // a fishing pier out onto the ice
  const pz = -38, px0 = RX - 0.5, px1 = LAKE_X + 22;
  vbox(B_PROPS, (px0 + px1) / 2, 0, pz, px1 - px0, 0.42, 3.6, 0x4a3a2c); vbox(B_SNOW, (px0 + px1) / 2, 0.42, pz, px1 - px0, 0.04, 3.2, 0xffffff);
  addCol(px0, 0, pz - 1.8, px1, 0.42, pz + 1.8, 'stoop');
  for (const s of [-1, 1]) { vbox(B_PROPS, (px0 + 2 + px1) / 2, 1.3, pz + s * 1.75, px1 - px0 - 2, 0.07, 0.07, 0x2b3036); addCol(px0 + 2, 0.42, pz + s * 1.75 - 0.08, px1, 1.4, pz + s * 1.75 + 0.08, 'fence'); for (let x = px0 + 2; x <= px1; x += 3) vcyl(B_PROPS, x, 0.42, pz + s * 1.75, 0.05, 0.92, 0x2b3036); }
  LAMPS.push({ x: px1 - 1, y: 3.2, z: pz, park: true }); vcyl(B_PROPS, px1 - 0.6, 0.42, pz + 1.4, 0.07, 2.8, 0x3a3f46); vbox(B_EMIS, px1 - 0.6, 3.2, pz + 1.1, 0.3, 0.16, 0.5, 0xffd8a0);
  signPlane('SHORE DR LAKEFRONT · ICE AT OWN RISK', RX - 0.2, 1.7, 9, 5.4, 0.55, -Math.PI / 2, { bg: '#0e2238', fg: '#d8ecff', glow: '#000', size: 52, w: 768, h: 80, blur: 0 });
})();
(function hoops() {
  const c = LOC.court, x0 = c.x - 14, x1 = c.x + 14, z0 = c.z - 8.5, z1 = c.z + 8.5;
  reserve(x0 - 3, z0 - 3, x1 + 3, z1 + 3);
  const slab = new THREE.Mesh(new THREE.PlaneGeometry(x1 - x0 + 3, z1 - z0 + 3).rotateX(-Math.PI / 2), MAT.road); slab.position.set(c.x, 0.02, c.z); slab.receiveShadow = true; scene.add(slab);
  const line = (x, z, w, d) => vbox(B_PROPS, x, 0.022, z, w, 0.012, d, 0xe8e4d8);
  line(c.x, z0, x1 - x0, 0.1); line(c.x, z1, x1 - x0, 0.1); line(x0, c.z, 0.1, z1 - z0); line(x1, c.z, 0.1, z1 - z0); line(c.x, c.z, 0.1, z1 - z0);
  for (let k = 0; k < 20; k++) { const a = k / 20 * TAU; line(c.x + Math.cos(a) * 1.8, c.z + Math.sin(a) * 1.8, 0.1, 0.6); }
  for (const s of [-1, 1]) {
    const bx = s < 0 ? x0 : x1;
    line(bx - s * 2.9, c.z - 2.4, 5.8, 0.1); line(bx - s * 2.9, c.z + 2.4, 5.8, 0.1); line(bx - s * 5.8, c.z, 0.1, 4.8);
    for (let k = 0; k <= 12; k++) { const a = -Math.PI / 2 + k / 12 * Math.PI; line(bx - s * Math.cos(a) * 6.7, c.z + Math.sin(a) * 6.7, 0.1, 0.5); }
    const hx = bx - s * 1.2;
    vcyl(B_PROPS, bx + s * 0.4, 0, c.z, 0.1, 3.4, 0x2b3036); addCol(bx + s * 0.4 - 0.12, 0, c.z - 0.12, bx + s * 0.4 + 0.12, 3.4, c.z + 0.12, 'pole');
    vbox(B_PROPS, bx - s * 0.2, 3.15, c.z, 1.2, 0.08, 0.08, 0x2b3036);
    vbox(B_PROPS, hx + s * 0.5, 2.75, c.z, 0.05, 1.05, 1.8, 0xeeeeee); vbox(B_PROPS, hx + s * 0.47, 2.75, c.z, 0.02, 0.45, 0.6, 0xc0322a);
    for (const [dx, dz, w, d] of [[0, -0.23, 0.46, 0.03], [0, 0.23, 0.46, 0.03], [-0.23, 0, 0.03, 0.46], [0.23, 0, 0.03, 0.46]]) vbox(B_PROPS, hx + dx, 2.6, c.z + dz, w, 0.03, d, 0xe0621a);
    vbox(B_SNOW, hx + s * 0.5, 3.28, c.z, 0.07, 0.04, 1.8, 0xffffff);
  }
  const F0 = x0 - 2, F1 = x1 + 2, G0 = z0 - 2, G1 = z1 + 2;
  fence(F0, G0, c.x - 2, G0, 3); fence(c.x + 2, G0, F1, G0, 3); fence(F0, G1, F1, G1, 3); fence(F0, G0, F0, G1, 3); fence(F1, G0, F1, G1, 3);
  for (const s of [-1, 1]) { vcyl(B_PROPS, c.x + s * 9, 0, G1 - 0.3, 0.09, 6.5, 0x3a3f46); vbox(B_EMIS, c.x + s * 9, 6.4, G1 - 0.8, 0.5, 0.14, 0.9, 0xfff2d8); LAMPS.push({ x: c.x + s * 9, y: 6.2, z: G1 - 1.5, park: true }); }
  vbox(B_PROPS, c.x, 0.42, G1 + 1.2, 4, 0.08, 0.5, 0x5a3e26); vbox(B_SNOW, c.x, 0.5, G1 + 1.2, 3.8, 0.05, 0.45, 0xffffff);
  signPlane('GARNET COURTS', c.x, 2.4, G0 - 0.08, 5, 0.6, Math.PI, { bg: '#2a1a12', fg: '#ffb347', glow: '#ff7a2a', size: 64, w: 768, h: 90 });
})();
(function gasStation() {
  const cx = -42, cz = -201;
  reserve(-66, -228, -14, -191);
  const slab = new THREE.Mesh(new THREE.PlaneGeometry(52, 36).rotateX(-Math.PI / 2), MAT.walk); slab.position.set(-40, 0.014, -209); slab.receiveShadow = true; scene.add(slab);
  building(-32, -228, -15, -211, 4.6, 3, 1, null);
  shopPane(-23.5, 1.5, -210.94, 7, 2.2, 0, false);
  signPlane('IRONSIDE FUEL · MINI MART', -23.5, 3.7, -210.92, 9, 0.8, 0, { bg: '#0a0d12', fg: '#ffd24a', glow: '#ff9a2a', size: 64, w: 1024, h: 92 });
  LAMPS.push({ x: -23.5, y: 2.6, z: -209.5, shop: true });
  vbox(B_PROPS, cx, 4.6, cz, 24, 0.55, 13, 0xd8dde2); vbox(B_SNOW, cx, 5.15, cz, 24.2, 0.14, 13.2, 0xffffff);
  for (const s of [-1, 1]) vbox(B_EMIS, cx, 4.68, cz + s * 6.52, 24, 0.32, 0.04, 0xd0202a);
  for (let dx = -10; dx <= 10; dx += 4) for (const dz of [-3.5, 0, 3.5]) vbox(B_EMIS, cx + dx, 4.57, cz + dz, 1.8, 0.03, 0.5, 0xffffff);
  for (const dx of [-9, 9]) for (const dz of [-4, 4]) solid(cx + dx, 0, cz + dz, 0.5, 4.6, 0.5, 0xc8ccd2, 'pole');
  for (const dx of [-7, 0, 7]) { vbox(B_PROPS, cx + dx, 0, cz, 1.6, 0.2, 6.5, 0x9aa0a8); for (const dz of [-1.6, 1.6]) { solid(cx + dx, 0.2, cz + dz, 0.75, 1.65, 0.5, 0x22303e, 'cover'); vbox(B_EMIS, cx + dx, 1.35, cz + dz + (dz < 0 ? -0.26 : 0.26), 0.4, 0.3, 0.02, 0x7ad0ff); } }
  for (const dx of [-8, 8]) LAMPS.push({ x: cx + dx, y: 4.3, z: cz, park: true });
  vcyl(B_PROPS, -15.5, 0, -192.5, 0.16, 6.5, 0x2b3036); addCol(-15.7, 0, -192.7, -15.3, 6.5, -192.3, 'pole');
  signPlane('FUEL  3.89', -15.5, 6.6, -192.2, 3.2, 1.4, 0, { bg: '#0a0d12', fg: '#ffd24a', glow: '#ff9a2a', size: 110, w: 512, h: 220 });
  PARK_SPOTS.push({ x: cx - 3.5, z: cz - 1.9, alongX: true, yaw: Math.PI / 2 }, { x: cx + 7 + 3.5, z: cz + 1.9, alongX: true, yaw: -Math.PI / 2 });
})();

/* ---- park ---- */
const POND = { x: -50, z: 32, r: 15 };
(function park() {
  const pm = new THREE.Mesh(new THREE.CircleGeometry(POND.r, 48), MAT.ice); pm.rotation.x = -Math.PI / 2; pm.position.set(POND.x, 0.025, POND.z); scene.add(pm);
  const rim = new THREE.Mesh(new THREE.RingGeometry(POND.r, POND.r + 0.9, 48), new THREE.MeshLambertMaterial({ color: 0xf0f6fc })); rim.rotation.x = -Math.PI / 2; rim.position.set(POND.x, 0.03, POND.z); scene.add(rim);
  // low stone walls around part of the pond (cover)
  for (let i = 0; i < 10; i++) {
    const a = i / 10 * TAU + 0.3; if (i % 3 === 2) continue;
    const x = POND.x + Math.cos(a) * (POND.r + 3), z = POND.z + Math.sin(a) * (POND.r + 3);
    const alongX = Math.abs(Math.sin(a)) > 0.7;
    const w = alongX ? 4 : 0.7, d = alongX ? 0.7 : 4;
    vbox(B_PROPS, x, 0, z, w, 1.1, d, 0x6d6a64); vbox(B_SNOW, x, 1.1, z, w + 0.1, 0.1, d + 0.1, 0xffffff);
    addCol(x - w / 2, 0, z - d / 2, x + w / 2, 1.1, z + d / 2, 'cover');
  }
  // trees
  const R = rng(77);
  for (let i = 0; i < 46; i++) {
    const x = -84 + R() * 72, z = 12 + R() * 66;
    if (Math.hypot(x - POND.x, z - POND.z) < POND.r + 5) continue;
    if (x > -42 && z > 46) continue;
    if (Math.hypot(x - LOC.pavilion.x, z - LOC.pavilion.z) < 8) continue;
    if (x > -82 && x < -62 && z > 64 && z < 79) continue;
    if (x > -18) continue;
    tree(x, z);
  }
  // pavilion
  for (const [dx, dz] of [[-4, -3], [4, -3], [-4, 3], [4, 3]]) solid(LOC.pavilion.x + dx, 0, LOC.pavilion.z + dz, 0.35, 3.2, 0.35, 0x4a3a2c, 'column');
  vbox(B_PROPS, LOC.pavilion.x, 3.2, LOC.pavilion.z, 9.6, 0.35, 7.6, 0x3a2a20);
  vbox(B_SNOW, LOC.pavilion.x, 3.55, LOC.pavilion.z, 9.8, 0.3, 7.8, 0xffffff);
  for (const dz of [-1.2, 1.2]) { vbox(B_PROPS, LOC.pavilion.x, 0.42, LOC.pavilion.z + dz, 6, 0.08, 0.6, 0x5a4636); vbox(B_PROPS, LOC.pavilion.x, 0, LOC.pavilion.z + dz, 0.12, 0.42, 0.5, 0x2a2a2a); }
  // basketball court with hoops (snowed in)
  const court = new THREE.Mesh(new THREE.PlaneGeometry(18, 13), new THREE.MeshLambertMaterial({ color: 0x9fb0c2 })); court.rotation.x = -Math.PI / 2; court.position.set(-72, 0.02, 71.5); scene.add(court);
  for (const s of [-1, 1]) { vcyl(B_PROPS, -72 + s * 8.4, 0, 71.5, 0.08, 3.1, 0x3a3f46); vbox(B_PROPS, -72 + s * 8.0, 2.9, 71.5, 0.06, 1.0, 1.6, 0xd8dde2); B_PROPS.add(GEO.cyl, mtx(-72 + s * 7.6, 3.0, 71.5, 0.25, 0.03, 0.25), 0xd0502a); addCol(-72 + s * 8.4 - 0.1, 0, 71.4, -72 + s * 8.4 + 0.1, 3.1, 71.6, 'pole'); }
  fence(-82, 64.5, -62, 64.5, 2.4); fence(-82, 78.5, -62, 78.5, 2.4); fence(-82, 64.5, -82, 78.5, 2.4);
  // benches along paths
  for (const [x, z, ax] of [[-30, 20, true], [-70, 30, false], [-50, 52, true], [-24, 40, false]]) { vbox(B_PROPS, x, 0.42, z, ax ? 2.2 : 0.6, 0.08, ax ? 0.6 : 2.2, 0x5a4636); vbox(B_SNOW, x, 0.5, z, ax ? 2.2 : 0.6, 0.06, ax ? 0.6 : 2.2, 0xffffff); addCol(x - (ax ? 1.1 : .3), 0, z - (ax ? .3 : 1.1), x + (ax ? 1.1 : .3), 0.5, z + (ax ? .3 : 1.1), 'bench'); }
  barrel(-38, 22);
  // snowman (kids from the rec)
  B_SNOW.add(GEO.sph, mtx(-30, 0.45, 44, 0.55, 0.55, 0.55), 0xffffff); B_SNOW.add(GEO.sph, mtx(-30, 1.18, 44, 0.4, 0.4, 0.4), 0xffffff); B_SNOW.add(GEO.sph, mtx(-30, 1.72, 44, 0.27, 0.27, 0.27), 0xffffff);
  B_PROPS.add(GEO.cone, mtx(-30, 1.72, 44.32, 0.05, 0.25, 0.05, Math.PI / 2, 0, 0), 0xe06a20);
  B_PROPS.add(GEO.cyl, mtx(-30, 1.5, 44, 0.34, 0.08, 0.34), 0xc0303a);
  addCol(-30.5, 0, 43.5, -29.5, 2, 44.5, 'snowman');
  // park lamps
  for (const [x, z] of [[-30, 28], [-70, 20], [-60, 50], [-34, 72], [-80, 40]]) { vcyl(B_PROPS, x, 0, z, 0.09, 4.2, 0x2f343a); vbox(B_EMIS, x, 4.1, z, 0.35, 0.35, 0.35, 0xffc27a); addCol(x - 0.1, 0, z - 0.1, x + 0.1, 4.2, z + 0.1, 'pole'); LAMPS.push({ x, y: 4.0, z, park: true }); }
  // low hedge walls along Calder and Bishop sides of the park
  for (let x = -82; x < -16; x += 9) { vbox(B_SNOW, x + 3, 0, 11.2, 6, 0.9, 1.0, 0xe8f0f8); addCol(x, 0, 10.7, x + 6, 0.95, 11.7, 'cover'); }
})();

/* ---- procedural blocks ---- */
function blockRect(i, j) { return { x0: i === 0 ? -MAP_HALF : XB[i] + WALK_EDGE, x1: i === NBX - 1 ? MAP_HALF : XB[i + 1] - WALK_EDGE, z0: j === 0 ? -MAP_HALF : ZB[j] + WALK_EDGE, z1: j === NBZ - 1 ? MAP_HALF : ZB[j + 1] - WALK_EDGE }; }
(function blocks() {
  const R = rng(9137);
  const styleFor = d => (d === 'ware' || d === 'industry') ? (R() < 0.6 ? 5 : 3) : d === 'rows' ? (R() < 0.45 ? 1 : R() < 0.5 ? 2 : 0) : (R() < 0.3 ? 0 : R() < 0.5 ? 1 : R() < 0.6 ? 2 : R() < 0.5 ? 3 : 4);
  const tryBuild = (x0, z0, x1, z1, h, st, face) => {
    if (overlapsReserved(x0, z0, x1, z1, 0.5)) return false;
    building(x0, z0, x1, z1, h, st, undefined, face);
    return true;
  };
  for (let i = 0; i < NBX; i++) for (let j = 0; j < NBZ; j++) {
    const dist = districtOf(i, j);
    if (dist === 'park' || dist === 'lake' || dist === 'yard') continue;
    const b = blockRect(i, j);
    const ware = dist === 'ware' || dist === 'industry', rows = dist === 'rows', courts = dist === 'courts';
    const outerW = i === 0, outerE = i === NBX - 1, outerN = j === 0, outerS = j === NBZ - 1;
    const hasAlley = !courts && (b.z1 - b.z0) >= 50;
    const zc = (b.z0 + b.z1) / 2;
    const depth = () => ware ? 14 + R() * 8 : rows ? 10 + R() * 3 : 11 + R() * 5;
    const height = () => ware ? 6 + R() * 5 : rows ? 6 + R() * 2.6 : 6.5 + R() * 6.5;
    // Garnet Courts: brick towers rising behind the street wall
    if (courts) {
      const ix0 = b.x0 + 18, ix1 = b.x1 - 18, iz0 = b.z0 + 18, iz1 = b.z1 - 18;
      const rowsZ = [[iz0, iz0 + 14], [iz1 - 13, iz1]];
      rowsZ.forEach(([z0, z1], k) => {
        if (i === 2 && k === 0) return; // the hoops court
        const w = Math.min(34, ix1 - ix0), x0 = (ix0 + ix1) / 2 - w / 2;
        reserve(x0, z0, x0 + w, z1);
        building(x0, z0, x0 + w, z1, 30 + R() * 14, R() < 0.6 ? 0 : 4, 1, null);
      });
    }
    for (const edge of ['n', 's']) {
      if (edge === 'n' && outerN) continue; if (edge === 's' && outerS) continue;
      let x = b.x0 + (outerW ? 8 : 0);
      const xEnd = b.x1 - (outerE ? 4 : 0);
      while (x < xEnd - 5) {
        let w = ware ? 14 + R() * 16 : rows ? 7 + R() * 2.5 : 8 + R() * 7; if (x + w > xEnd) w = xEnd - x; if (w < 5) break;
        const d = depth(), h = height();
        if (edge === 'n') tryBuild(x, b.z0, x + w, b.z0 + d, h, styleFor(dist), 'n'); else tryBuild(x, b.z1 - d, x + w, b.z1, h, styleFor(dist), 's');
        x += w + (R() < (rows ? 0.6 : 0.45) ? 1.2 + R() * 2.2 : 0);
      }
    }
    for (const edge of ['w', 'e']) {
      if (edge === 'w' && outerW) continue; if (edge === 'e' && outerE) continue;
      let z = b.z0 + (outerN ? 0 : 17);
      const zEnd = b.z1 - (outerS ? 0 : 17);
      while (z < zEnd - 5) {
        let w = 8 + R() * 7; if (z + w > zEnd) w = zEnd - z; if (w < 5) break;
        if (hasAlley && z < zc + 4 && z + w > zc - 4) { z = zc + 4; continue; }
        const d = depth(), h = height();
        if (edge === 'w') tryBuild(b.x0, z, b.x0 + d, z + w, h, styleFor(dist), 'w'); else tryBuild(b.x1 - d, z, b.x1, z + w, h, styleFor(dist), 'e');
        z += w + (R() < 0.4 ? 1.5 + R() * 2 : 0);
      }
    }
    if (hasAlley) {
      let x = b.x0 + 18;
      while (x < b.x1 - 20) {
        const w = 6 + R() * 2;
        if (!overlapsReserved(x, zc - 10, x + w, zc - 3.2, 0)) { if (R() < 0.65) { building(x, zc - 9.6, x + w, zc - 3.4, 3.2, ware ? 5 : 3); } }
        if (!overlapsReserved(x, zc + 3.2, x + w, zc + 10, 0)) { if (R() < 0.65) { building(x, zc + 3.4, x + w, zc + 9.6, 3.2, ware ? 5 : 1); } }
        if (R() < 0.35) dumpster(x + w / 2, zc + (R() < 0.5 ? -2.2 : 2.2), true);
        x += w + 0.5 + R() * 4;
      }
      for (let k = 0; k < 2; k++) { const lx = b.x0 + 20 + k * (b.x1 - b.x0 - 40); LAMPS.push({ x: lx, y: 3.6, z: zc, alley: true }); vcyl(B_PROPS, lx, 0, zc - 2.9, 0.08, 3.8, 0x2f343a); vbox(B_EMIS, lx, 3.6, zc - 2.6, 0.3, 0.2, 0.5, 0xffb46a); }
    }
  }
})();

/* ---- streets: lamps, cars, snowbanks, vents, barricades ---- */
(function streets() {
  const R = rng(555);
  const nearCross = (v, lines, m) => lines.some(l => Math.abs(v - l) < m);
  const blockedZone = (x, z) => (x > 56 && x < 84 && z > 14 && z < 50) || (x > 60 && x < 80 && z > -110 && z < -96) || (Math.abs(x - 41) < 3 && Math.abs(z + 8) < 2.5) || (Math.abs(x - LOC.home.x) < 2.5 && Math.abs(z - LOC.home.z) < 3) || (Math.abs(x - 16) < 9 && Math.abs(z + 8) < 2) || (Math.abs(x - LOC.rec.x) < 2 && Math.abs(z - LOC.rec.z) < 4);
  // E-W streets
  for (const zc of ZL) {
    for (let x = -(MAP_HALF - 10); x <= ROAD_X_END - 14; x += 32) {
      if (nearCross(x, XL, 12)) continue;
      const side = ((x + MAP_HALF - 10) / 32) % 2 ? 1 : -1;
      if (x > 56 && x < 84) continue;
      lamp(x, zc + side * 8.6, 0, -side);
    }
    for (const side of [-1, 1]) {
      let x = -(MAP_HALF - 6);
      while (x < SHORE_X - 12) {
        const gap = 5.5 + R() * 9;
        if (!nearCross(x, XL, 14) && !blockedZone(x, zc + side * 4.6) && R() < 0.42) PARK_SPOTS.push({ x, z: zc + side * 4.6, alongX: true, yaw: side > 0 ? Math.PI / 2 : -Math.PI / 2 });
        else if (!nearCross(x, XL, 14) && R() < 0.35 && !blockedZone(x, zc + side * 6.6)) snowbank(x, zc + side * 6.6, true, 3 + R() * 2.5);
        x += gap;
      }
    }
  }
  // N-S streets
  for (const xc of XL) {
    for (let z = -(MAP_HALF - 10); z <= MAP_HALF - 10; z += 32) {
      if (nearCross(z, ZL, 12)) continue;
      if (xc === LX) continue;
      const side = ((z + MAP_HALF - 10) / 32) % 2 ? 1 : -1;
      lamp(xc + side * 8.6, z, -side, 0);
    }
    for (const side of [-1, 1]) {
      let z = -(MAP_HALF - 6);
      while (z < MAP_HALF - 6) {
        const gap = 5.5 + R() * 9;
        const px = xc + side * (xc === LX ? 4.7 : 4.6);
        if (!nearCross(z, ZL, 14) && !blockedZone(px, z) && R() < (xc === LX ? 0.3 : 0.42) && !(xc === LX && (((z + MAP_HALF - 6) % 16 + 16) % 16 < 3.5 || ((z + MAP_HALF - 6) % 16 + 16) % 16 > 12.5))) PARK_SPOTS.push({ x: px, z, alongX: false, yaw: side > 0 ? Math.PI : 0 });
        else if (!nearCross(z, ZL, 14) && R() < 0.3 && !blockedZone(xc + side * 6.6, z) && !(xc === LX)) snowbank(xc + side * 6.6, z, false, 3 + R() * 2.5);
        z += gap;
      }
    }
  }
  // jersey barriers + barrel under the L
  barrier(LX, -40, false, 3); barrier(LX, 56, false, 3); barrier(LX - 2.5, -64, true, 2.4); barrier(LX + 2.5, 70, true, 2.4);
  barrel(DECK_X0 - 1.0, -36);
  // alley barrel behind the studio
  barrel(28, -44); dumpster(33, -42.6, true);
  barrel(-6.5, -57);
  // steam vents
  for (const [x, z] of [[-40, 0.5], [28, -1.5], [104, 1], [1.5, -62], [-1.2, 38], [24, -90], [-95, 30], [70, -20]]) vent(x, z);
  // barricades at the edges of the map
  for (const zc of ZL) snowbank(-(MAP_HALF - 4), zc, false, 10);
  for (const xc of XL) for (const ze of [-(MAP_HALF - 4), MAP_HALF - 4]) { if (xc === LX) { barrier(xc, ze, true, 10); continue; } snowbank(xc, ze, true, 10); }
  // more fire barrels and steam in the new districts
  for (const [x, z] of [[-36, 108], [-62, 133], [-28, -186.5], [-205, -95], [-205, 92], [175, -60], [176, 70], [116, 186], [-130, 186], [30, -186]]) barrel(x, z);
  for (const [x, z] of [[-140, -180.5], [120, 179], [-60, 180.8], [160.6, 120], [-190.5, -60]]) vent(x, z);
  // newspaper boxes / bus shelter on Calder
  for (const [x, z] of [[-60, -7.4], [8, 7.4], [95, -7.4]]) { solid(x, 0, z, 0.5, 1.1, 0.5, pick([0x1f4a8a, 0x8a1f1f, 0x2a6a3a]), 'cover'); }
  // storefront signs along Calder Ave (fictional shops)
  const shops = [['WINGS & FISH', '#ffcf5a'], ['CURRENCY EXCHANGE', '#7ad0ff'], ['BEAUTY SUPPLY', '#ff8ad0'], ['LAUNDROMAT 24H', '#9fffd0'], ['TAX PREP', '#ffe08a'], ['CELL REPAIR', '#8ab0ff'], ['BARBER', '#ff6a6a'], ['FURNITURE', '#ffb47a']];
  let si = 0;
  for (const [x, z, ry] of [[-70, -10.3, 0], [-40, -10.3, 0], [100, -10.3, 0], [125, -10.3, 0], [20, 10.3, Math.PI], [-125, -10.3, 0], [110, 10.3, Math.PI], [-120, 10.3, Math.PI]]) {
    const [txt, col] = shops[si++ % shops.length];
    const list = queryBoxes(x - 1, z - 2, x + 1, z + 2);
    const ok = list.some(b => b.tag === 'building' && x >= b.x0 && x <= b.x1 && Math.abs((ry === 0 ? b.z1 : b.z0) - z) < 1.4);
    if (!ok) continue;
    const bz = list.find(b => b.tag === 'building' && x >= b.x0 && x <= b.x1 && Math.abs((ry === 0 ? b.z1 : b.z0) - z) < 1.4);
    const fz = ry === 0 ? bz.z1 + 0.06 : bz.z0 - 0.06;
    signPlane(txt, x, 3.2, fz, 5, 0.7, ry, { bg: '#0a0806', fg: col, glow: col, size: 62, w: 768, h: 110 });
    shopPane(x, 1.5, fz + (ry === 0 ? 0.01 : -0.01), 4.2, 2.0, ry, true);
  }
})();

/* ---- finalize static batches ---- */
const DECALS = [];
(function finalize() {
  for (const L of LAMPS) {
    if (L.fire || L.shop || L.porch) continue;
    const r = L.under ? 7 : L.plat ? 5 : L.park ? 6 : L.alley ? 5 : 9.5;
    const y = L.plat ? PLAT_Y + 0.03 : 0.04;
    const geo = GEO.plane;
    B_DECAL.add(geo, mtx(L.x, y, L.z, r * 2, r * 2, 1, -Math.PI / 2, 0, 0), 0xffffff);
  }
  for (const B of BARRELS) B_DECAL.add(GEO.plane, mtx(B.x, 0.05, B.z, 9, 9, 1, -Math.PI / 2, 0, 0), 0xffffff);
  const dm = new THREE.Mesh(B_DECAL.build(), MAT.glowDecal); dm.renderOrder = 2; scene.add(dm);
  buildSignals();
  B_PROPS.mesh(MAT.props); B_EMIS.mesh(MAT.emis, false, false);
  FALLBACK.barrel = B_BARREL.mesh(MAT.props); FALLBACK.barrelFire = B_BARREL_FIRE.mesh(MAT.emis, false, false); FALLBACK.barrier = B_BARRIER.mesh(MAT.props); FALLBACK.vent = B_VENT.mesh(MAT.props, false); B_SNOW.mesh(MAT.snow); B_ROOF.mesh(MAT.snow, false, true);
  MAT.shop.vertexColors = true; B_SHOP.mesh(MAT.shop, false, false); B_GYM.mesh(MAT.gym, false, false);
  const gm = B_GLASS.mesh(MAT.glass, false, false); gm.renderOrder = 3;
  for (const F of FACADES) F.batches.forEach((b, i) => { if (b.p.length) b.mesh(F.mats[i]); });
  // lamp halos
  const hp = [];
  for (const L of LAMPS) if (!L.fire) hp.push(L.x, L.y + 0.05, L.z);
  const hg = new THREE.BufferGeometry(); hg.setAttribute('position', new THREE.Float32BufferAttribute(hp, 3));
  const halo = new THREE.Points(hg, new THREE.PointsMaterial({ color: 0xff9a45, size: 2.6, map: TEX.glow, transparent: true, opacity: 0.55, depthWrite: false, blending: THREE.AdditiveBlending }));
  scene.add(halo); MAT.halo = halo.material;
})();

/* ---- traffic signals (shared timing, so every player sees the same lights) ---- */
const SIG_CYCLE = 27;
function signalState(ix, iz, axis) {
  const t = (((worldSeconds() + ix * 7 + iz * 11) % SIG_CYCLE) + SIG_CYCLE) % SIG_CYCLE;
  if (axis === 'x') return t < 10 ? 'g' : t < 13 ? 'y' : 'r';
  return t >= 14 && t < 24 ? 'g' : t >= 24 && t < 26.5 ? 'y' : 'r';
}
function buildSignals() {
  const heads = [];
  XL.forEach((x, ix) => ZL.forEach((z, iz) => {
    // [pole x, pole z, facing yaw, axis it controls]
    for (const [px, pz, ry, axis] of [[x + 7.4, z + 7.4, -Math.PI / 2, 'x'], [x - 7.4, z - 7.4, Math.PI / 2, 'x'], [x - 7.4, z + 7.4, Math.PI, 'z'], [x + 7.4, z - 7.4, 0, 'z']]) {
      vcyl(B_PROPS, px, 0, pz, 0.09, 4.6, 0x2b3036);
      addCol(px - 0.1, 0, pz - 0.1, px + 0.1, 4.6, pz + 0.1, 'pole');
      const fx = Math.sin(ry), fz = Math.cos(ry);
      vbox(B_PROPS, px + fx * 0.05, 3.4, pz + fz * 0.05, 0.36, 1.1, 0.3, 0x15171a);
      vbox(B_SNOW, px + fx * 0.05, 4.5, pz + fz * 0.05, 0.38, 0.06, 0.32, 0xffffff);
      for (let k = 0; k < 3; k++) heads.push({ x: px + fx * 0.21, y: 4.25 - k * 0.32, z: pz + fz * 0.21, ix, iz, axis, k });
    }
  }));
  const geo = new THREE.SphereGeometry(0.11, 8, 6);
  SIGNAL_MESH = new THREE.InstancedMesh(geo, new THREE.MeshBasicMaterial({ color: 0xffffff }), heads.length);
  heads.forEach((h, i) => { SIGNAL_MESH.setMatrixAt(i, mtx(h.x, h.y, h.z, 1, 1, 1)); SIGNAL_MESH.setColorAt(i, new THREE.Color(0x111111)); });
  SIGNAL_MESH.instanceMatrix.needsUpdate = true; scene.add(SIGNAL_MESH);
  SIGNAL_HEADS.push(...heads);
}
const _sigCols = { r: new THREE.Color(3.2, 0.15, 0.08), y: new THREE.Color(3.0, 1.6, 0.1), g: new THREE.Color(0.2, 2.6, 0.9), off: new THREE.Color(0.06, 0.06, 0.06) };
let sigT = 0;
function updateSignals(dt) {
  sigT -= dt; if (sigT > 0 || !SIGNAL_MESH) return; sigT = 0.25;
  SIGNAL_HEADS.forEach((h, i) => { const st = signalState(h.ix, h.iz, h.axis); const lit = (h.k === 0 && st === 'r') || (h.k === 1 && st === 'y') || (h.k === 2 && st === 'g'); SIGNAL_MESH.setColorAt(i, lit ? _sigCols[st] : _sigCols.off); });
  SIGNAL_MESH.instanceColor.needsUpdate = true;
}

/* ---- street-graph navigation ---- */
const NAV = [];
(function nav() {
  const xs = [-(MAP_HALF - 5), ...XL, SHORE_X + 26], zs = [-(MAP_HALF - 5), ...ZL, MAP_HALF - 5];
  const idx = {};
  const add = (x, z) => { const k = x + ',' + z; if (idx[k] !== undefined) return idx[k]; idx[k] = NAV.length; NAV.push({ x, z, n: [] }); return idx[k]; };
  const link = (a, b) => { if (!NAV[a].n.includes(b)) NAV[a].n.push(b); if (!NAV[b].n.includes(a)) NAV[b].n.push(a); };
  for (const x of XL) for (let k = 0; k < zs.length - 1; k++) link(add(x, zs[k]), add(x, zs[k + 1]));
  for (const z of ZL) for (let k = 0; k < xs.length - 1; k++) link(add(xs[k], z), add(xs[k + 1], z));
  // park interior + alleys
  const pk = add(-50, 50), pk2 = add(-60, 12), pk3 = add(-30, 30);
  link(pk, add(-95, 90)); link(pk2, add(-95, 0)); link(pk3, add(0, 0)); link(pk, pk3); link(pk2, pk3); link(pk, add(0, 90));
  // lakefront promenade runs the length of Shore Dr
  for (let k = 0; k < zs.length - 1; k++) link(add(SHORE_X + 26, zs[k]), add(SHORE_X + 26, zs[k + 1]));
  // the hoops court off Garnet St
  link(add(LOC.court.x, LOC.court.z - 14), add(LOC.court.x, 90)); link(add(LOC.court.x, LOC.court.z - 14), add(LOC.court.x, LOC.court.z)); link(add(LOC.court.x, 90), add(-95, 90)); link(add(LOC.court.x, 90), add(0, 90));
})();
function nearestNav(x, z, needClear) {
  let best = -1, bd = Infinity;
  for (let i = 0; i < NAV.length; i++) {
    const d = Math.hypot(NAV[i].x - x, NAV[i].z - z);
    if (d < bd && (!needClear || segClear(x, 0.6, z, NAV[i].x, 0.6, NAV[i].z))) { bd = d; best = i; }
  }
  if (best < 0 && needClear) return nearestNav(x, z, false);
  return best;
}
function navPath(sx, sz, tx, tz) {
  const a = nearestNav(sx, sz, true), b = nearestNav(tx, tz, true);
  const dist = new Array(NAV.length).fill(Infinity), prev = new Array(NAV.length).fill(-1), done = new Array(NAV.length).fill(false);
  dist[a] = 0;
  for (let it = 0; it < NAV.length; it++) {
    let u = -1, ud = Infinity; for (let i = 0; i < NAV.length; i++) if (!done[i] && dist[i] < ud) { ud = dist[i]; u = i; }
    if (u < 0 || u === b) break; done[u] = true;
    for (const v of NAV[u].n) { const nd = dist[u] + Math.hypot(NAV[u].x - NAV[v].x, NAV[u].z - NAV[v].z); if (nd < dist[v]) { dist[v] = nd; prev[v] = u; } }
  }
  const path = []; let c = b; while (c >= 0) { path.unshift({ x: NAV[c].x, z: NAV[c].z }); if (c === a) break; c = prev[c]; }
  path.push({ x: tx, z: tz });
  return path;
}
function inPark(x, z) { return x > -85 && x < -10 && z > 10 && z < 80; }
function onIce(x, z, y) { return y < 0.3 && (Math.hypot(x - POND.x, z - POND.z) < POND.r || x > LAKE_X); }
function underDeck(x, z, y) { return x > DECK_X0 && x < DECK_X1 && y < DECK_Y0; }
function streetName(x, z) {
  for (let k = 0; k < XL.length; k++) if (Math.abs(x - XL[k]) < WALK_EDGE + 1) { for (let j = 0; j < ZL.length; j++) if (Math.abs(z - ZL[j]) < WALK_EDGE + 1) return XN[k] + ' & ' + ZN[j]; return XN[k]; }
  for (let j = 0; j < ZL.length; j++) if (Math.abs(z - ZL[j]) < WALK_EDGE + 1) return ZN[j];
  if (inPark(x, z)) return 'Calder Park';
  if (x > LAKE_X) return 'Frozen lake';
  if (x > SHORE_X + WALK_EDGE) return 'Lakefront';
  if (x < XL[0] - WALK_EDGE) return 'Kessler rail yard';
  if (Math.hypot(x - LOC.court.x, z - LOC.court.z) < 16) return 'Garnet Courts';
  return 'Alley';
}
