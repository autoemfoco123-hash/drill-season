/* =========================================================
   LITE RENDERER - for browsers with no WebGL, such as the
   PS4 web browser. The same world, drawn in plain JavaScript:
   a small depth-buffered software rasterizer whose picture is
   scaled up to fill the screen. Buildings are captured as they
   are built; people, cars and trains are drawn from their live
   (animated) parts each frame.
   ========================================================= */
let LITE_PICKED = false; try { LITE_PICKED = localStorage.getItem('ds.lite') === '1'; } catch (e) { }
let LITE_MODE = PLAT.webgl === false || /[?&]lite\b/.test(location.search) || LITE_PICKED;
// consoles keep a copy of the city in software form, so a lost graphics context never means a black screen
const liteCapturing = () => LITE_MODE || IS_CONSOLE;
const LITE = {
  canvas: null, ctx: null, over: null, octx: null, W: 0, H: 0, img: null, buf: null, depth: null,
  statics: [], grid: new Map(), cell: 16, frame: 0, scale: 1, ms: 12, adaptT: 0, tag: -1, mute: false,
  ground: null, gN: 1024, gHalf: 270, snow: [], vis: [], lastSize: '',
};
const LITE_NEAR = 0.05, LITE_FAR = 170;
const LITE_FACADE_COLS = { brick: 0x8a4a38, brown: 0x6a4836, grey: 0x9a9488, siding: 0x7a8890, cream: 0xcbbf9a, ware: 0x5d6064 };
const LITE_STYLES = ['brick', 'brown', 'grey', 'siding', 'cream', 'ware'];
function makeLiteRenderer() {
  const c = document.createElement('canvas'); c.className = 'gl lite';
  const o = document.createElement('canvas'); o.className = 'lite-over';
  LITE.canvas = c; LITE.ctx = c.getContext('2d'); LITE.over = o; LITE.octx = o.getContext('2d');
  const size = new THREE.Vector2(innerWidth, innerHeight);
  const noop = () => { };
  liteResize();
  return {
    domElement: c, isLite: true, autoClear: true, toneMapping: 0, toneMappingExposure: 1, outputColorSpace: 'srgb',
    shadowMap: { enabled: false, type: 0, autoUpdate: true }, capabilities: { isWebGL2: false, getMaxAnisotropy: () => 1, maxTextureSize: 4096 },
    info: { render: {}, memory: {} }, extensions: { get: () => null, has: () => false }, xr: { enabled: false }, properties: { get: () => ({}) },
    setPixelRatio: noop, getPixelRatio: () => 1, setSize(w, h) { size.set(w, h); liteResize(); }, getSize: v => v.copy(size), getDrawingBufferSize: v => v.copy(size),
    render: noop, compile: noop, dispose: noop, setRenderTarget: noop, getRenderTarget: () => null, clear: noop, setClearColor: noop, getClearColor: c2 => c2, getClearAlpha: () => 1,
    setAnimationLoop: noop, getContext: () => null, resetState: noop, getActiveCubeFace: () => 0, getActiveMipmapLevel: () => 0, initTexture: noop,
  };
}
// WebGL gave up (context lost and not back, or the renderer keeps failing): carry on in software
function liteTakeOver(why) {
  if (LITE_MODE || !LITE.statics.length) return false;
  const gl = renderer.domElement;
  makeLiteRenderer();
  gl.style.display = 'none'; gl.after(LITE.canvas); LITE.canvas.after(LITE.over);
  LITE.canvas.addEventListener('mousedown', e => { if (MODE === 'cutscene') skipCutscene(); });
  LITE_MODE = true;
  console.warn('switched to the software renderer:', why);
  if (typeof toast === 'function') toast(null, 'Graphics switched to the simple renderer to keep the game running', '#ffb347');
  return true;
}
// internal resolution: small, scaled up by the browser; adjusts to hold the frame rate
function liteResize() {
  const aspect = innerWidth / Math.max(1, innerHeight);
  const base = PLAT.console ? 360 : 440;
  const W = Math.round(clamp(base * LITE.scale, 200, 720)), H = Math.max(90, Math.round(W / aspect));
  if (W === LITE.W && H === LITE.H) return;
  LITE.W = W; LITE.H = H; LITE.canvas.width = W; LITE.canvas.height = H;
  LITE.img = LITE.ctx.createImageData(W, H); LITE.buf = new Uint32Array(LITE.img.data.buffer); LITE.depth = new Float32Array(W * H);
  LITE.over.width = innerWidth; LITE.over.height = innerHeight;
}

/* ---- capturing the world as it is built (see Batch in 30_scene.js) ---- */
const _lbbCache = new WeakMap();
function liteGeoBox(geo) {
  let b = _lbbCache.get(geo);
  if (!b) { if (!geo.boundingBox) geo.computeBoundingBox(); b = geo.boundingBox; _lbbCache.set(geo, b); }
  return b;
}
function liteCorners(bb, me, out) {
  for (let i = 0; i < 8; i++) {
    const x = i & 1 ? bb.max.x : bb.min.x, y = i & 2 ? bb.max.y : bb.min.y, z = i & 4 ? bb.max.z : bb.min.z;
    out[i * 3] = me[0] * x + me[4] * y + me[8] * z + me[12];
    out[i * 3 + 1] = me[1] * x + me[5] * y + me[9] * z + me[13];
    out[i * 3 + 2] = me[2] * x + me[6] * y + me[10] * z + me[14];
  }
  return out;
}
function liteRecord(batch, geo, m, col) {
  if (LITE.mute) return;
  const bb = liteGeoBox(geo), c = liteCorners(bb, m.elements, new Float32Array(24));
  // skip flat things (road paint, decals); the ground is drawn separately
  let mn = Infinity; for (const [a, b] of [[0, 1], [0, 2], [0, 4]]) mn = Math.min(mn, Math.hypot(c[b * 3] - c[a * 3], c[b * 3 + 1] - c[a * 3 + 1], c[b * 3 + 2] - c[a * 3 + 2]));
  if (mn < 0.015) return;
  (batch.lite || (batch.lite = [])).push({ c, r: col.r, g: col.g, b: col.b, fac: LITE.tag });
}
function liteFacade(style, cx, cy, cz, w, h, d) {
  const bb = new THREE.Box3(new THREE.Vector3(-w / 2, -h / 2, -d / 2), new THREE.Vector3(w / 2, h / 2, d / 2));
  const c = liteCorners(bb, new THREE.Matrix4().makeTranslation(cx, cy, cz).elements, new Float32Array(24));
  const col = new THREE.Color(LITE_FACADE_COLS[style] || 0x777777);
  liteAddStatic({ c, r: col.r, g: col.g, b: col.b, fac: LITE_STYLES.indexOf(style), em: false });
}
function liteCommit(batch, mat) {
  if (!batch.lite) return;
  const list = batch.lite; batch.lite = null;
  if (!mat || (mat.transparent && mat.opacity < 0.5)) return;
  const em = !!(mat.isMeshBasicMaterial || (mat.emissive && !mat.emissiveMap && mat.emissive.r + mat.emissive.g + mat.emissive.b > 0.3 && (mat.emissiveIntensity || 0) > 0.2));
  const mc = mat.color || { r: 1, g: 1, b: 1 };
  for (const e of list) { e.r *= mc.r; e.g *= mc.g; e.b *= mc.b; e.em = em; liteAddStatic(e); }
}
function liteAddStatic(e) {
  const c = e.c; let x0 = Infinity, x1 = -Infinity, z0 = Infinity, z1 = -Infinity, cx = 0, cy = 0, cz = 0;
  for (let i = 0; i < 8; i++) { const x = c[i * 3], z = c[i * 3 + 2]; x0 = Math.min(x0, x); x1 = Math.max(x1, x); z0 = Math.min(z0, z); z1 = Math.max(z1, z); cx += x; cy += c[i * 3 + 1]; cz += z; }
  e.cx = cx / 8; e.cy = cy / 8; e.cz = cz / 8; e.rad = 0; for (let i = 0; i < 8; i++) e.rad = Math.max(e.rad, Math.hypot(c[i * 3] - e.cx, c[i * 3 + 1] - e.cy, c[i * 3 + 2] - e.cz));
  e.seed = (Math.imul(Math.round(e.cx * 7), 73856093) ^ Math.imul(Math.round(e.cz * 7), 19349663)) >>> 0; e.f = -1;
  const S2 = LITE.cell;
  for (let ix = Math.floor(x0 / S2); ix <= Math.floor(x1 / S2); ix++) for (let iz = Math.floor(z0 / S2); iz <= Math.floor(z1 / S2); iz++) {
    const k = ix * 4096 + iz; let a = LITE.grid.get(k); if (!a) LITE.grid.set(k, a = []); a.push(e);
  }
  LITE.statics.push(e);
}

/* ---- the ground: one map of roads, sidewalks, snow and ice, looked up per pixel ---- */
function liteGroundMap() {
  const N = LITE.gN, Hh = LITE.gHalf, k = N / (2 * Hh);
  const cv = document.createElement('canvas'); cv.width = cv.height = N; const g = cv.getContext('2d');
  const X = x => (x + Hh) * k, L = v => v * k;
  g.fillStyle = '#d9e1ea'; g.fillRect(0, 0, N, N);
  for (let i = 0; i < 9000; i++) { g.fillStyle = Math.random() < 0.5 ? 'rgba(170,185,200,.35)' : 'rgba(255,255,255,.5)'; g.fillRect(Math.random() * N, Math.random() * N, 1 + Math.random() * 2, 1 + Math.random() * 2); }
  g.fillStyle = '#b9ccd8'; g.fillRect(X(LAKE_X), 0, N, N);
  g.strokeStyle = 'rgba(255,255,255,.5)'; g.lineWidth = 1; for (let i = 0; i < 60; i++) { const x = X(LAKE_X) + Math.random() * (N - X(LAKE_X)), y = Math.random() * N; g.beginPath(); g.moveTo(x, y); g.lineTo(x + (Math.random() - 0.5) * 30, y + (Math.random() - 0.5) * 30); g.stroke(); }
  const E = MAP_HALF + 10;
  const walk = (x0, z0, x1, z1) => { g.fillStyle = '#9b9c99'; g.fillRect(X(x0), X(z0), L(x1 - x0), L(z1 - z0)); };
  for (const z of ZL) { walk(-E, z - WALK_EDGE, ROAD_X_END, z + WALK_EDGE); }
  for (const x of XL) { walk(x - WALK_EDGE, -E, x + WALK_EDGE, E); }
  walk(ROAD_X_END, -E, LAKE_X - 6, E);
  const road = (x0, z0, x1, z1, alongX) => {
    g.fillStyle = '#3b3e43'; g.fillRect(X(x0), X(z0), L(x1 - x0), L(z1 - z0));
    // slushy tyre tracks and the double yellow
    g.fillStyle = 'rgba(120,126,134,.55)';
    for (const o of [-4.6, -2.4, 2.4, 4.6]) alongX ? g.fillRect(X(x0), X((z0 + z1) / 2 + o) - 0.5, L(x1 - x0), 1) : g.fillRect(X((x0 + x1) / 2 + o) - 0.5, X(z0), 1, L(z1 - z0));
    g.fillStyle = '#d8b23a'; alongX ? g.fillRect(X(x0), X((z0 + z1) / 2) - 0.5, L(x1 - x0), 1) : g.fillRect(X((x0 + x1) / 2) - 0.5, X(z0), 1, L(z1 - z0));
  };
  for (const z of ZL) road(-E, z - ROAD_HW, ROAD_X_END, z + ROAD_HW, true);
  for (const x of XL) road(x - ROAD_HW, -E, x + ROAD_HW, E, false);
  // crosswalks
  g.fillStyle = 'rgba(235,238,240,.85)';
  for (const x of XL) for (const z of ZL) for (const s of [-1, 1]) {
    for (let i = -ROAD_HW + 0.6; i < ROAD_HW; i += 1.2) { g.fillRect(X(x + i), X(z + s * (ROAD_HW + 1)), L(0.6), L(2.2)); g.fillRect(X(x + s * (ROAD_HW + 1)), X(z + i), L(2.2), L(0.6)); }
  }
  LITE.ground = new Uint32Array(g.getImageData(0, 0, N, N).data.buffer);
  LITE.groundOut = LITE.ground[0];
}

/* ---- per-frame state ---- */
const LT = { e: null, cx: 0, cy: 0, f: 1, tanX: 1, tanY: 1, px: 0, py: 0, pz: 0, fogR: 0, fogG: 0, fogB: 0, fogT: new Float32Array(700), amb: 0.5, sun: 0.5, sx: 0, sy: 1, sz: 0, night: 0, lamps: 0, skyR: 0, skyG: 0, skyB: 0 };
const _lsrgb = new Uint8Array(1025);
for (let i = 0; i <= 1024; i++) { const v = i / 1024; _lsrgb[i] = Math.round(255 * (v <= 0.0031308 ? v * 12.92 : 1.055 * Math.pow(v, 1 / 2.4) - 0.055)); }
const toS = v => _lsrgb[v <= 0 ? 0 : v >= 1 ? 1024 : (v * 1024) | 0];
const _lv = new Float32Array(24), _lw = new Float32Array(24);
const PX = new Float32Array(16), PY = new Float32Array(16), PZ = new Float32Array(16), PU = new Float32Array(16), PV = new Float32Array(16);
const QX = new Float32Array(16), QY = new Float32Array(16), QZ = new Float32Array(16), QU = new Float32Array(16), QV = new Float32Array(16);
const LITE_FACES = [[0, 2, 6, 4], [1, 3, 7, 5], [0, 1, 5, 4], [2, 3, 7, 6], [0, 1, 3, 2], [4, 5, 7, 6]];
const LITE_FACE_TAN = [[0, 4], [1, 5], null, null, [0, 1], [4, 5]];

// one triangle, screen space, depth-tested. mode 0: flat colour; 1: facade with windows
function liteTri(i0, i1, i2, R, G, B, mode, fs) {
  const W = LITE.W, H = LITE.H, buf = LITE.buf, dep = LITE.depth, fogT = LT.fogT;
  let x0 = QX[i0], y0 = QY[i0], z0 = QZ[i0], x1 = QX[i1], y1 = QY[i1], z1 = QZ[i1], x2 = QX[i2], y2 = QY[i2], z2 = QZ[i2];
  let u0 = QU[i0], v0 = QV[i0], u1 = QU[i1], v1 = QV[i1], u2 = QU[i2], v2 = QV[i2];
  let area = (x1 - x0) * (y2 - y0) - (x2 - x0) * (y1 - y0);
  if (area > -1e-6 && area < 1e-6) return;
  if (area < 0) { let t = x1; x1 = x2; x2 = t; t = y1; y1 = y2; y2 = t; t = z1; z1 = z2; z2 = t; t = u1; u1 = u2; u2 = t; t = v1; v1 = v2; v2 = t; area = -area; }
  const minX = Math.max(0, Math.floor(Math.min(x0, x1, x2))), maxX = Math.min(W - 1, Math.ceil(Math.max(x0, x1, x2)));
  const minY = Math.max(0, Math.floor(Math.min(y0, y1, y2))), maxY = Math.min(H - 1, Math.ceil(Math.max(y0, y1, y2)));
  if (minX > maxX || minY > maxY) return;
  const A01 = y0 - y1, B01 = x1 - x0, C01 = x0 * y1 - x1 * y0;
  const A12 = y1 - y2, B12 = x2 - x1, C12 = x1 * y2 - x2 * y1;
  const A20 = y2 - y0, B20 = x0 - x2, C20 = x2 * y0 - x0 * y2;
  const inv = 1 / area, fR = LT.fogR, fG = LT.fogG, fB = LT.fogB;
  // z holds 1/depth; u and v are pre-divided by depth for perspective-correct windows
  const fcol = (255 << 24) | (B << 16) | (G << 8) | R;
  for (let y = minY; y <= maxY; y++) {
    const py = y + 0.5, px0 = minX + 0.5;
    let e12 = A12 * px0 + B12 * py + C12, e20 = A20 * px0 + B20 * py + C20, e01 = A01 * px0 + B01 * py + C01;
    let i = y * W + minX;
    for (let x = minX; x <= maxX; x++, i++, e12 += A12, e20 += A20, e01 += A01) {
      if (e12 < 0 || e20 < 0 || e01 < 0) continue;
      const w0 = e12 * inv, w1 = e20 * inv, w2 = e01 * inv;
      const iz = w0 * z0 + w1 * z1 + w2 * z2;
      if (iz <= dep[i]) continue;
      dep[i] = iz;
      const d = 1 / iz, fi = d * 4, f = fi < 699 ? fogT[fi | 0] : 1;
      let r = R, g = G, b = B;
      if (mode === 1) {
        const u = (w0 * u0 + w1 * u1 + w2 * u2) * d, v = (w0 * v0 + w1 * v1 + w2 * v2) * d;
        const cu = Math.floor(u / fs.du), cv = Math.floor(v / fs.dv), fu = u - cu * fs.du, fv = v - cv * fs.dv;
        if (v > fs.v0 && v < fs.vMax && fu > fs.u0 && fu < fs.u1 && fv > fs.w0 && fv < fs.w1) {
          const h = (Math.imul(cu, 73856093) ^ Math.imul(cv, 19349663) ^ fs.seed) >>> 0;
          if ((h % 100) < fs.lit) { r = fs.lR; g = fs.lG; b = fs.lB; } else { r = fs.gR; g = fs.gG; b = fs.gB; }
        } else if (fv < 0.18 && v > 2.5) { r = (r * 0.8) | 0; g = (g * 0.8) | 0; b = (b * 0.8) | 0; }
      } else if (f === 0) { buf[i] = fcol; continue; }
      if (f > 0) { r = r + (fR - r) * f; g = g + (fG - g) * f; b = b + (fB - b) * f; }
      buf[i] = (255 << 24) | (b << 16) | (g << 8) | r;
    }
  }
}
// clip a polygon (view space, in P*) at the near plane, project into Q*, fan into triangles
function litePoly(n, R, G, B, mode, fs) {
  let m = 0;
  for (let i = 0; i < n; i++) {
    const j = (i + 1) % n, zi = PZ[i], zj = PZ[j], inI = zi < -LITE_NEAR, inJ = zj < -LITE_NEAR;
    if (inI) { QX[m] = PX[i]; QY[m] = PY[i]; QZ[m] = zi; QU[m] = PU[i]; QV[m] = PV[i]; m++; }
    if (inI !== inJ) { const t = (-LITE_NEAR - zi) / (zj - zi); QX[m] = PX[i] + (PX[j] - PX[i]) * t; QY[m] = PY[i] + (PY[j] - PY[i]) * t; QZ[m] = -LITE_NEAR; QU[m] = PU[i] + (PU[j] - PU[i]) * t; QV[m] = PV[i] + (PV[j] - PV[i]) * t; m++; }
  }
  if (m < 3) return;
  const f = LT.f, cx = LT.cx, cy = LT.cy;
  for (let i = 0; i < m; i++) { const iz = -1 / QZ[i]; QX[i] = cx + QX[i] * iz * f; QY[i] = cy - QY[i] * iz * f; QZ[i] = iz; QU[i] *= iz; QV[i] *= iz; }
  for (let i = 1; i < m - 1; i++) liteTri(0, i, i + 1, R, G, B, mode, fs);
}
const _fs = { du: 3.2, dv: 3, u0: 0.7, u1: 2.3, w0: 0.9, w1: 2.4, v0: 0.8, vMax: 99, seed: 0, lit: 0, lR: 0, lG: 0, lB: 0, gR: 0, gG: 0, gB: 0 };
// a box given as 8 world-space corners
function liteBox(c, r, g, b, em, fac, seed) {
  const e = LT.e;
  let cx = 0, cy = 0, cz = 0; for (let i = 0; i < 8; i++) { cx += c[i * 3]; cy += c[i * 3 + 1]; cz += c[i * 3 + 2]; }
  cx /= 8; cy /= 8; cz /= 8;
  let rad = 0; for (let i = 0; i < 8; i++) { const dx = c[i * 3] - cx, dy = c[i * 3 + 1] - cy, dz = c[i * 3 + 2] - cz; const d2 = dx * dx + dy * dy + dz * dz; if (d2 > rad) rad = d2; }
  rad = Math.sqrt(rad);
  // cull: behind, too far, outside the view, or smaller than a pixel
  const vz = e[2] * cx + e[6] * cy + e[10] * cz + e[14];
  if (vz - rad > -LITE_NEAR || -vz - rad > LITE_FAR) return;
  const vx = e[0] * cx + e[4] * cy + e[8] * cz + e[12], vy = e[1] * cx + e[5] * cy + e[9] * cz + e[13];
  const zz = Math.max(LITE_NEAR, -vz);
  if (Math.abs(vx) - rad > (zz + rad) * LT.tanX || Math.abs(vy) - rad > (zz + rad) * LT.tanY) return;
  if (-vz > rad && rad / -vz * LT.f < 0.45) return;
  for (let i = 0; i < 8; i++) { const x = c[i * 3], y = c[i * 3 + 1], z = c[i * 3 + 2]; _lv[i * 3] = e[0] * x + e[4] * y + e[8] * z + e[12]; _lv[i * 3 + 1] = e[1] * x + e[5] * y + e[9] * z + e[13]; _lv[i * 3 + 2] = e[2] * x + e[6] * y + e[10] * z + e[14]; }
  for (let f = 0; f < 6; f++) {
    const q = LITE_FACES[f], a = q[0] * 3, b1 = q[1] * 3, c2 = q[2] * 3, d3 = q[3] * 3;
    // face normal from two edges, pointed away from the box centre
    const ex = c[b1] - c[a], ey = c[b1 + 1] - c[a + 1], ez = c[b1 + 2] - c[a + 2], fx = c[d3] - c[a], fy = c[d3 + 1] - c[a + 1], fz = c[d3 + 2] - c[a + 2];
    let nx = ey * fz - ez * fy, ny = ez * fx - ex * fz, nz = ex * fy - ey * fx;
    const nl = Math.sqrt(nx * nx + ny * ny + nz * nz); if (nl < 1e-9) continue;
    nx /= nl; ny /= nl; nz /= nl;
    const mx = (c[a] + c[c2]) / 2, my = (c[a + 1] + c[c2 + 1]) / 2, mz = (c[a + 2] + c[c2 + 2]) / 2;
    if (nx * (mx - cx) + ny * (my - cy) + nz * (mz - cz) < 0) { nx = -nx; ny = -ny; nz = -nz; }
    if (nx * (LT.px - mx) + ny * (LT.py - my) + nz * (LT.pz - mz) <= 0) continue;
    let L = em ? 1.25 : LT.amb + LT.sun * Math.max(0, nx * LT.sx + ny * LT.sy + nz * LT.sz) + (ny > 0.7 ? 0.08 : ny < -0.7 ? -0.15 : 0);
    const R = toS(r * L), G = toS(g * L), B = toS(b * L);
    for (let k = 0; k < 4; k++) { const v = q[k] * 3; PX[k] = _lv[v]; PY[k] = _lv[v + 1]; PZ[k] = _lv[v + 2]; PU[k] = 0; PV[k] = 0; }
    let mode = 0;
    const tn = LITE_FACE_TAN[f];
    if (fac >= 0 && tn && Math.abs(ny) < 0.5) {
      const ta = tn[0] * 3, tb = tn[1] * 3; let tx = c[tb] - c[ta], tz = c[tb + 2] - c[ta + 2]; const tl = Math.hypot(tx, tz) || 1; tx /= tl; tz /= tl;
      for (let k = 0; k < 4; k++) { const v = q[k] * 3; PU[k] = c[v] * tx + c[v + 2] * tz + 1000; PV[k] = c[v + 1]; }
      const ware = fac === 5, fs = _fs;
      fs.du = ware ? 4 : 3.2; fs.dv = ware ? 4.5 : 3; fs.u0 = ware ? 0.4 : 0.85; fs.u1 = ware ? 3.6 : 2.25; fs.w0 = ware ? 2.6 : 0.85; fs.w1 = ware ? 3.6 : 2.35;
      fs.v0 = ware ? 2 : 0.6; fs.vMax = Math.max(c[1], c[4], c[7], c[10], c[13], c[16], c[19], c[22]) - 1.2; fs.seed = seed;
      fs.lit = Math.round(55 * LT.lamps); const lk = 0.6 + 0.4 * LT.lamps;
      fs.lR = toS(1.0 * lk); fs.lG = toS(0.62 * lk); fs.lB = toS(0.3 * lk);
      const gk = 0.15 + 0.3 * (1 - LT.night); fs.gR = toS(LT.skyR * gk + 0.02); fs.gG = toS(LT.skyG * gk + 0.025); fs.gB = toS(LT.skyB * gk + 0.035);
      mode = 1;
    }
    litePoly(4, R, G, B, mode, _fs);
  }
}
// sky and ground for every pixel, row by row (a flat floor at y = 0)
function liteBackground() {
  const W = LITE.W, H = LITE.H, buf = LITE.buf, dep = LITE.depth, e = camera.matrixWorld.elements, f = LT.f, cx = LT.cx, cy = LT.cy;
  const camY = Math.max(0.05, LT.py), gm = LITE.ground, N = LITE.gN, gk = N / (2 * LITE.gHalf), gh = LITE.gHalf, fogT = LT.fogT;
  const hR = LT.fogR, hG = LT.fogG, hB = LT.fogB, tR = toS(LT.skyR), tG = toS(LT.skyG), tB = toS(LT.skyB);
  const gl = Math.min(1.25, LT.amb + LT.sun * Math.max(0, LT.sy)) * 0.92;
  const lut = new Uint8Array(256); for (let i = 0; i < 256; i++) lut[i] = Math.min(255, (i * gl) | 0);
  for (let y = 0; y < H; y++) {
    const vy = -(y + 0.5 - cy) / f;
    let i = y * W;
    for (let x = 0; x < W; x++, i++) {
      const vx = (x + 0.5 - cx) / f;
      const dx = e[0] * vx + e[4] * vy - e[8], dy = e[1] * vx + e[5] * vy - e[9], dz = e[2] * vx + e[6] * vy - e[10];
      if (dy > -1e-4) {
        const el = dy / Math.sqrt(vx * vx + vy * vy + 1), k = el > 0.45 ? 1 : el / 0.45;
        buf[i] = (255 << 24) | ((hB + (tB - hB) * k) << 16) | ((hG + (tG - hG) * k) << 8) | (hR + (tR - hR) * k); dep[i] = 0; continue;
      }
      const t = -camY / dy;
      if (t > LITE_FAR) { buf[i] = (255 << 24) | (hB << 16) | (hG << 8) | hR; dep[i] = 0; continue; }
      const wx = LT.px + dx * t, wz = LT.pz + dz * t;
      const gx = ((wx + gh) * gk) | 0, gz = ((wz + gh) * gk) | 0;
      const c = gx >= 0 && gz >= 0 && gx < N && gz < N ? gm[gz * N + gx] : LITE.groundOut;
      let r = lut[c & 255], g = lut[(c >> 8) & 255], b = lut[(c >> 16) & 255];
      const fi = t * 4, fo = fi < 699 ? fogT[fi | 0] : 1;
      r = r + (hR - r) * fo; g = g + (hG - g) * fo; b = b + (hB - b) * fo;
      buf[i] = (255 << 24) | (b << 16) | (g << 8) | r; dep[i] = 1 / t;
    }
  }
}
const _lm = new THREE.Matrix4(), _lim = new THREE.Matrix4(), _lcol = new THREE.Color(), _lavg = new WeakMap(), _lwp = new THREE.Vector3();
function liteAvgColor(geo) {
  let c = _lavg.get(geo); if (c) return c;
  const a = geo.attributes.color; c = { r: 1, g: 1, b: 1 };
  if (a) { let r = 0, g = 0, b = 0; const n = a.count; for (let i = 0; i < n; i++) { r += a.getX(i); g += a.getY(i); b += a.getZ(i); } c = { r: r / n, g: g / n, b: b / n }; }
  _lavg.set(geo, c); return c;
}
function liteMesh(o) {
  const g = o.geometry; if (!g || !g.attributes || !g.attributes.position) return;
  const mat = Array.isArray(o.material) ? o.material[0] : o.material;
  if (!mat || mat.visible === false || (mat.transparent && (mat.opacity < 0.5 || mat.map || mat.alphaMap || mat.depthWrite === false)) || mat.isShaderMaterial || mat.isPointsMaterial) return;
  const bb = liteGeoBox(g); if (bb.isEmpty()) return;
  const sz = Math.max(bb.max.x - bb.min.x, bb.max.y - bb.min.y, bb.max.z - bb.min.z); if (sz > 90) return;
  let r = mat.color ? mat.color.r : 1, gg = mat.color ? mat.color.g : 1, b = mat.color ? mat.color.b : 1;
  if (mat.vertexColors) { const a = liteAvgColor(g); r *= a.r; gg *= a.g; b *= a.b; }
  const em = !!(mat.isMeshBasicMaterial || (mat.emissive && mat.emissive.r + mat.emissive.g + mat.emissive.b > 0.6 && (mat.emissiveIntensity || 0) > 0.5));
  if (em && mat.emissive && !mat.isMeshBasicMaterial) { r = mat.emissive.r; gg = mat.emissive.g; b = mat.emissive.b; }
  if (o.isInstancedMesh) {
    const ic = o.instanceColor;
    for (let i = 0; i < o.count; i++) {
      o.getMatrixAt(i, _lim); if (Math.abs(_lim.elements[0]) + Math.abs(_lim.elements[5]) + Math.abs(_lim.elements[10]) < 1e-6) continue;
      _lm.multiplyMatrices(o.matrixWorld, _lim);
      const px = _lm.elements[12] - LT.px, pz = _lm.elements[14] - LT.pz; if (px * px + pz * pz > 120 * 120) continue;
      let rr = r, rg = gg, rb = b; if (ic) { o.getColorAt(i, _lcol); rr *= _lcol.r; rg *= _lcol.g; rb *= _lcol.b; }
      liteBox(liteCorners(bb, _lm.elements, _lw), rr, rg, rb, em, -1, 0);
    }
  } else {
    const me = o.matrixWorld.elements, px = me[12] - LT.px, pz = me[14] - LT.pz;
    if (px * px + pz * pz > 120 * 120) return;
    liteBox(liteCorners(bb, me, _lw), r, gg, b, em, -1, 0);
  }
}
const _skipNames = new Set();
function liteDynamic(root) {
  const stack = [root];
  while (stack.length) {
    const o = stack.pop();
    if (!o.visible) continue;
    if (o.userData.liteSkip) continue;
    if (o.isMesh) liteMesh(o);
    else if (o.isSprite) LITE.vis.push(o);
    const ch = o.children; for (let i = 0; i < ch.length; i++) stack.push(ch[i]);
  }
}
function liteFrame() {
  const W = LITE.W, H = LITE.H;
  camera.updateMatrixWorld(); scene.updateMatrixWorld();
  LT.e = camera.matrixWorldInverse.elements;
  const me = camera.matrixWorld.elements; LT.px = me[12]; LT.py = me[13]; LT.pz = me[14];
  LT.f = (H / 2) / Math.tan(THREE.MathUtils.degToRad(camera.fov) / 2); LT.cx = W / 2; LT.cy = H / 2;
  LT.tanX = (W / 2) / LT.f; LT.tanY = (H / 2) / LT.f;
  // light and air from the day / night state
  const fc = scene.fog ? scene.fog.color : { r: 0.5, g: 0.55, b: 0.6 };
  LT.fogR = toS(fc.r); LT.fogG = toS(fc.g); LT.fogB = toS(fc.b);
  const top = envDomeMat.uniforms.top.value; LT.skyR = top.r * 1.4; LT.skyG = top.g * 1.4; LT.skyB = top.b * 1.4;
  LT.night = DN.night; LT.lamps = DN.lamps;
  const sd = DN.sunDir.lengthSq() > 0 ? DN.sunDir : _lwp.set(0.3, 0.8, 0.3);
  LT.sx = sd.x; LT.sy = sd.y; LT.sz = sd.z;
  LT.amb = lerp(0.62, 0.3, DN.night); LT.sun = Math.max(0, sd.y) > 0 ? lerp(0.55, 0, DN.night) : 0;
  const dens = scene.fog && scene.fog.density ? scene.fog.density * 0.85 : 0.008;
  for (let i = 0; i < 700; i++) { const d = i / 4, k = dens * d; let fo = 1 - Math.exp(-k * k); if (d > LITE_FAR * 0.75) fo = Math.max(fo, (d - LITE_FAR * 0.75) / (LITE_FAR * 0.25)); LT.fogT[i] = Math.min(1, fo); }
  liteBackground();
  // static city: cells around the camera, nearest first
  const S2 = LITE.cell, R = Math.ceil(LITE_FAR / S2), cx = Math.floor(LT.px / S2), cz = Math.floor(LT.pz / S2), fr = ++LITE.frame;
  const fx = -me[8], fz = -me[10], fl = Math.hypot(fx, fz) || 1;
  const list = [];
  for (let ix = cx - R; ix <= cx + R; ix++) for (let iz = cz - R; iz <= cz + R; iz++) {
    const ox = (ix + 0.5) * S2 - LT.px, oz = (iz + 0.5) * S2 - LT.pz, d = Math.hypot(ox, oz);
    if (d > LITE_FAR + S2) continue;
    if (d > S2 * 1.5 && (ox * fx + oz * fz) / fl < -S2) continue;
    const a = LITE.grid.get(ix * 4096 + iz); if (!a) continue;
    for (let k = 0; k < a.length; k++) { const s = a[k]; if (s.f === fr) continue; s.f = fr; s.d = Math.hypot(s.cx - LT.px, s.cz - LT.pz); list.push(s); }
  }
  list.sort((a, b) => a.d - b.d);
  for (const s of list) liteBox(s.c, s.r, s.g, s.b, s.em, s.fac, s.seed);
  // live things: people, cars, the train, your hands
  LITE.vis.length = 0;
  liteDynamic(scene);
  liteDynamic(camera);
  LITE.ctx.putImageData(LITE.img, 0, 0);
}
// screen-resolution extras on top: name tags, tracers, lamp glow, snow, hurt flash
function liteOverlay(dt) {
  const o = LITE.octx, Wd = LITE.over.width, Hd = LITE.over.height, sx = Wd / LITE.W, sy = Hd / LITE.H, e = LT.e;
  o.clearRect(0, 0, Wd, Hd);
  const proj = (x, y, z) => { const vx = e[0] * x + e[4] * y + e[8] * z + e[12], vy = e[1] * x + e[5] * y + e[9] * z + e[13], vz = e[2] * x + e[6] * y + e[10] * z + e[14]; if (vz > -0.2) return null; const iz = -1 / vz; return { x: (LT.cx + vx * iz * LT.f) * sx, y: (LT.cy - vy * iz * LT.f) * sy, d: -vz }; };
  // street lamps glow at night
  if (DN.lamps > 0.05) {
    o.globalCompositeOperation = 'lighter';
    for (const L of LAMPS) {
      const lx = L.x !== undefined ? L.x : L[0], lz = L.z !== undefined ? L.z : L[1]; if (lx === undefined) continue;
      const p = proj(lx, L.y || 5.2, lz); if (!p || p.d > 70) continue;
      const r = 5.5 * LT.f * sy / p.d; if (r < 2) continue;
      const g = o.createRadialGradient(p.x, p.y, 0, p.x, p.y, r); g.addColorStop(0, `rgba(255,190,120,${0.35 * DN.lamps})`); g.addColorStop(1, 'rgba(255,170,90,0)');
      o.fillStyle = g; o.fillRect(p.x - r, p.y - r, r * 2, r * 2);
    }
    o.globalCompositeOperation = 'source-over';
  }
  // name tags (sprites)
  for (const s of LITE.vis) {
    const m = s.material; if (!m || !m.map || !m.map.image || (m.opacity !== undefined && m.opacity < 0.1)) continue;
    s.getWorldPosition(_lwp); const p = proj(_lwp.x, _lwp.y, _lwp.z); if (!p || p.d > 32) continue;
    const ws = new THREE.Vector3(); s.getWorldScale(ws);
    const w = ws.x * LT.f * sx / p.d, h = ws.y * LT.f * sy / p.d; if (w < 6) continue;
    try { o.globalAlpha = m.opacity === undefined ? 1 : m.opacity; o.drawImage(m.map.image, p.x - w / 2, p.y - h / 2, w, h); } catch (err) { }
  }
  o.globalAlpha = 1;
  // tracers
  if (typeof tracerPos !== 'undefined') for (let i = 0; i < TRACER_N; i++) {
    if (!(tracerLife[i] > 0)) continue;
    const a = proj(tracerPos[i * 6], tracerPos[i * 6 + 1], tracerPos[i * 6 + 2]), b = proj(tracerPos[i * 6 + 3], tracerPos[i * 6 + 4], tracerPos[i * 6 + 5]);
    if (!a || !b) continue;
    o.strokeStyle = 'rgba(255,214,150,.9)'; o.lineWidth = 2; o.beginPath(); o.moveTo(a.x, a.y); o.lineTo(b.x, b.y); o.stroke();
  }
  // muzzle flash
  if (typeof FLASH !== 'undefined' && FLASH.intensity > 0.5) { const p = proj(FLASH.position.x, FLASH.position.y, FLASH.position.z); if (p) { const r = Math.min(120, 2.5 * LT.f * sy / p.d); const g = o.createRadialGradient(p.x, p.y, 0, p.x, p.y, r); g.addColorStop(0, 'rgba(255,220,150,.9)'); g.addColorStop(1, 'rgba(255,160,60,0)'); o.fillStyle = g; o.fillRect(p.x - r, p.y - r, r * 2, r * 2); } }
  // snow
  if (!LITE.snow.length) for (let i = 0; i < 110; i++) LITE.snow.push({ x: Math.random(), y: Math.random(), v: 0.05 + Math.random() * 0.12, s: 1 + Math.random() * 2 });
  o.fillStyle = 'rgba(240,245,255,.75)';
  for (const p of LITE.snow) { p.y += p.v * dt; p.x += (WIND.dx * WIND.gust * 0.15 + Math.sin(REAL_T + p.v * 40) * 0.01) * dt; if (p.y > 1) { p.y = 0; p.x = Math.random(); } if (p.x > 1) p.x -= 1; if (p.x < 0) p.x += 1; o.fillRect(p.x * Wd, p.y * Hd, p.s, p.s); }
  // hurt
  const hurt = GRADE.uniforms.uHurt.value;
  if (hurt > 0.02) { const g = o.createRadialGradient(Wd / 2, Hd / 2, Math.min(Wd, Hd) * 0.3, Wd / 2, Hd / 2, Math.max(Wd, Hd) * 0.7); g.addColorStop(0, 'rgba(120,0,0,0)'); g.addColorStop(1, `rgba(140,0,0,${Math.min(0.6, hurt * 0.7)})`); o.fillStyle = g; o.fillRect(0, 0, Wd, Hd); }
}
function liteRender(dt) {
  if (!LITE.ground) liteGroundMap();
  if (LITE.over.width !== innerWidth || LITE.over.height !== innerHeight) { LITE.over.width = innerWidth; LITE.over.height = innerHeight; }
  const t0 = performance.now();
  liteFrame();
  LITE.ms = LITE.ms * 0.9 + (performance.now() - t0) * 0.1;
  liteOverlay(dt);
  // keep it smooth: aim for ~30 fps of drawing time
  LITE.adaptT -= dt;
  if (LITE.adaptT <= 0) {
    LITE.adaptT = 1.5;
    const s0 = LITE.scale;
    if (LITE.ms > 26) LITE.scale = Math.max(0.5, LITE.scale * 0.88); else if (LITE.ms < 11) LITE.scale = Math.min(1.5, LITE.scale * 1.08);
    if (Math.abs(LITE.scale - s0) > 0.01) liteResize();
  }
}
