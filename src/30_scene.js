
/* =========================================================
   RENDERER, SCENE, TEXTURES, BATCHING
   ========================================================= */
const PR = IS_CONSOLE ? Math.min(window.devicePixelRatio || 1, (PLAT.xboxSeries ? 1920 : 1280) / Math.max(1, innerWidth)) : Math.min(window.devicePixelRatio || 1, IS_TOUCH ? 1.25 : 1.5);
// no WebGL (the PS4 browser): the software renderer in 12_lite.js stands in
const renderer = LITE_MODE ? makeLiteRenderer() : (() => { try { return new THREE.WebGLRenderer({ antialias: false, powerPreference: 'high-performance', stencil: false }); } catch (e) { console.warn('WebGL failed, using the software renderer', e); LITE_MODE = true; return makeLiteRenderer(); } })();
renderer.setPixelRatio(PR);
renderer.setSize(innerWidth, innerHeight);
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.0;
renderer.shadowMap.enabled = !LOW_POWER;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.domElement.className = 'gl';
$('app').prepend(renderer.domElement);
if (LITE_MODE) renderer.domElement.after(LITE.over);

const scene = new THREE.Scene();
const FOG_COL = new THREE.Color(0x0e1b2b);
scene.background = FOG_COL.clone();
scene.fog = new THREE.FogExp2(FOG_COL.clone(), 0.0145);
const camera = new THREE.PerspectiveCamera(62, innerWidth / innerHeight, 0.08, 3200);
camera.rotation.order = 'YXZ';
scene.add(camera);

const hemi = new THREE.HemisphereLight(0x7290c4, 0x2a2228, 1.0);
scene.add(hemi);
// one celestial light: the sun by day, the moon by night (always the shadow caster)
const SUN = new THREE.DirectionalLight(0xffffff, 1.0);
SUN.castShadow = !LOW_POWER;
SUN.shadow.mapSize.set(2048, 2048);
{ const c = SUN.shadow.camera; c.left = -48; c.right = 48; c.top = 48; c.bottom = -48; c.near = 1; c.far = 460; }
SUN.shadow.bias = -0.0004; SUN.shadow.normalBias = 0.045;
scene.add(SUN, SUN.target);
const LIGHT_POOL = [];
for (let i = 0; i < (LOW_POWER ? 4 : 8); i++) {
  const L = new THREE.PointLight(0xff9a3c, 0, 26, 1.6);
  scene.add(L); LIGHT_POOL.push(L);
}
const FLASH = new THREE.PointLight(0xffc27a, 0, 14, 2); scene.add(FLASH);

/* ---------- canvas textures ---------- */
function canvasTex(w, h, draw, opt) {
  opt = opt || {};
  const c = document.createElement('canvas'); c.width = w; c.height = h;
  const g = c.getContext('2d'); draw(g, w, h);
  const t = new THREE.CanvasTexture(c);
  if (opt.srgb !== false) t.colorSpace = THREE.SRGBColorSpace;
  if (opt.repeat !== false) { t.wrapS = t.wrapT = THREE.RepeatWrapping; }
  t.anisotropy = 4;
  return t;
}
function speckle(g, w, h, n, cols, smin, smax) {
  for (let i = 0; i < n; i++) { g.fillStyle = pick(cols); const s = rand(smin, smax); g.fillRect(Math.random() * w, Math.random() * h, s, s); }
}
const TEX = {};
TEX.snow = canvasTex(256, 256, (g, w, h) => {
  g.fillStyle = '#c9d6e4'; g.fillRect(0, 0, w, h);
  for (let i = 0; i < 60; i++) { const x = Math.random() * w, y = Math.random() * h, r = rand(10, 40); const gr = g.createRadialGradient(x, y, 0, x, y, r); gr.addColorStop(0, 'rgba(240,246,255,.35)'); gr.addColorStop(1, 'rgba(240,246,255,0)'); g.fillStyle = gr; g.fillRect(x - r, y - r, r * 2, r * 2); }
  speckle(g, w, h, 1400, ['#dfe8f2', '#b8c7d8', '#eef4fb', '#aebfd2'], 1, 2.2);
});
TEX.road = canvasTex(256, 256, (g, w, h) => {
  // u along road length, v across. tire tracks are darker cleared slush
  g.fillStyle = '#8f9cab'; g.fillRect(0, 0, w, h);
  speckle(g, w, h, 900, ['#7c8898', '#a3afbd', '#6e7a8a'], 1, 3);
  const lanes = [0.2, 0.33, 0.67, 0.8];
  for (const l of lanes) { const y = l * h; const gr = g.createLinearGradient(0, y - 16, 0, y + 16); gr.addColorStop(0, 'rgba(40,48,60,0)'); gr.addColorStop(.5, 'rgba(40,48,60,.75)'); gr.addColorStop(1, 'rgba(40,48,60,0)'); g.fillStyle = gr; g.fillRect(0, y - 16, w, 32); }
  g.fillStyle = 'rgba(200,160,60,.35)'; for (let x = 0; x < w; x += 64) g.fillRect(x, h / 2 - 2, 34, 4);
  g.fillStyle = 'rgba(235,242,250,.55)'; g.fillRect(0, 0, w, 10); g.fillRect(0, h - 10, w, 10);
  speckle(g, w, h, 300, ['rgba(255,255,255,.35)'], 1, 2);
});
TEX.walk = canvasTex(128, 128, (g, w, h) => {
  g.fillStyle = '#aab6c3'; g.fillRect(0, 0, w, h);
  speckle(g, w, h, 500, ['#98a5b4', '#bdc8d4', '#c9d3de'], 1, 2.5);
  g.strokeStyle = 'rgba(70,80,95,.45)'; g.lineWidth = 2; g.strokeRect(1, 1, w - 2, h - 2);
  for (let i = 0; i < 6; i++) { g.fillStyle = 'rgba(230,238,246,.5)'; g.beginPath(); g.ellipse(Math.random() * w, Math.random() * h, rand(6, 20), rand(4, 12), Math.random() * 3, 0, TAU); g.fill(); }
});
TEX.glow = canvasTex(128, 128, (g, w) => {
  const gr = g.createRadialGradient(w / 2, w / 2, 0, w / 2, w / 2, w / 2);
  gr.addColorStop(0, 'rgba(255,255,255,1)'); gr.addColorStop(0.25, 'rgba(255,255,255,.45)'); gr.addColorStop(0.6, 'rgba(255,255,255,.1)'); gr.addColorStop(1, 'rgba(255,255,255,0)');
  g.fillStyle = gr; g.fillRect(0, 0, w, w);
}, { repeat: false });
TEX.dot = canvasTex(32, 32, (g, w) => {
  const gr = g.createRadialGradient(w / 2, w / 2, 0, w / 2, w / 2, w / 2);
  gr.addColorStop(0, 'rgba(255,255,255,1)'); gr.addColorStop(0.5, 'rgba(255,255,255,.7)'); gr.addColorStop(1, 'rgba(255,255,255,0)');
  g.fillStyle = gr; g.fillRect(0, 0, w, w);
}, { repeat: false });
TEX.puff = canvasTex(64, 64, (g, w) => {
  for (let i = 0; i < 9; i++) { const x = w / 2 + rand(-10, 10), y = w / 2 + rand(-10, 10), r = rand(12, 22); const gr = g.createRadialGradient(x, y, 0, x, y, r); gr.addColorStop(0, 'rgba(255,255,255,.35)'); gr.addColorStop(1, 'rgba(255,255,255,0)'); g.fillStyle = gr; g.fillRect(0, 0, w, w); }
}, { repeat: false });
TEX.beam = canvasTex(64, 256, (g, w, h) => {
  const gr = g.createLinearGradient(0, 0, 0, h); gr.addColorStop(0, 'rgba(255,255,255,0)'); gr.addColorStop(0.7, 'rgba(255,255,255,.35)'); gr.addColorStop(1, 'rgba(255,255,255,.9)');
  g.fillStyle = gr; g.fillRect(0, 0, w, h);
  const gx = g.createLinearGradient(0, 0, w, 0); gx.addColorStop(0, 'rgba(0,0,0,1)'); gx.addColorStop(.5, 'rgba(0,0,0,0)'); gx.addColorStop(1, 'rgba(0,0,0,1)');
  g.globalCompositeOperation = 'destination-out'; g.fillStyle = gx; g.fillRect(0, 0, w, h);
}, { repeat: false });
TEX.ring = canvasTex(128, 128, (g, w) => {
  g.strokeStyle = 'rgba(255,255,255,.95)'; g.lineWidth = 7; g.beginPath(); g.arc(w / 2, w / 2, w / 2 - 8, 0, TAU); g.stroke();
  g.lineWidth = 2; g.beginPath(); g.arc(w / 2, w / 2, w / 2 - 22, 0, TAU); g.stroke();
}, { repeat: false });
TEX.sky = canvasTex(1024, 512, (g, w, h) => {
  const gr = g.createLinearGradient(0, 0, 0, h);
  gr.addColorStop(0, '#02050b'); gr.addColorStop(0.3, '#060d18'); gr.addColorStop(0.46, '#0d1a2b'); gr.addColorStop(0.5, '#122236'); gr.addColorStop(0.56, '#0e1b2b'); gr.addColorStop(1, '#0a121c');
  g.fillStyle = gr; g.fillRect(0, 0, w, h);
  // the Loop's light pollution, low on the northeast horizon (u ~ 0.625)
  const cx = 0.625 * w, cy = h * 0.5;
  g.save(); g.translate(cx, cy); g.scale(1, 0.42);
  for (const [r, a] of [[300, .2], [170, .26], [80, .22]]) { const gg = g.createRadialGradient(0, 0, 0, 0, 0, r); gg.addColorStop(0, `rgba(255,150,85,${a})`); gg.addColorStop(1, 'rgba(255,150,85,0)'); g.fillStyle = gg; g.fillRect(-r, -r, r * 2, r * 2); }
  g.restore();
  for (const ux of [0.1, 0.35, 0.85]) { const x = ux * w; g.save(); g.translate(x, cy); g.scale(1, 0.35); const g2 = g.createRadialGradient(0, 0, 0, 0, 0, 220); g2.addColorStop(0, 'rgba(255,140,70,.08)'); g2.addColorStop(1, 'rgba(255,140,70,0)'); g.fillStyle = g2; g.fillRect(-220, -220, 440, 440); g.restore(); }
  for (let i = 0; i < 160; i++) { const x = Math.random() * w, y = rand(h * .2, h * .47), rx = rand(40, 140), ry = rand(8, 24); const near = Math.abs(x - cx) < 160 && y > h * .38; g.fillStyle = `rgba(${near ? '110,80,80' : '45,62,88'},${rand(.05, .11)})`; g.beginPath(); g.ellipse(x, y, rx, ry, 0, 0, TAU); g.fill(); }
}, { repeat: false });
TEX.shop = canvasTex(512, 256, (g, w, h) => {
  const gr = g.createLinearGradient(0, 0, 0, h); gr.addColorStop(0, '#fff1d0'); gr.addColorStop(1, '#d9b98a'); g.fillStyle = gr; g.fillRect(0, 0, w, h);
  for (let r = 0; r < 4; r++) { const y = 40 + r * 48; g.fillStyle = '#6a5a48'; g.fillRect(0, y + 30, w, 5); for (let x = 4; x < w; x += rand(9, 16)) { g.fillStyle = pick(['#c0392b', '#e67e22', '#f1c40f', '#2980b9', '#27ae60', '#8e44ad', '#ecf0f1', '#d35400']); g.fillRect(x, y + rand(6, 14), rand(6, 11), 30 - rand(6, 14) + 4); } }
  g.fillStyle = 'rgba(30,20,10,.85)'; for (let x = 0; x <= w; x += 128) g.fillRect(x - 3, 0, 6, h); g.fillRect(0, 0, w, 6); g.fillRect(0, h - 8, w, 8);
  g.fillStyle = '#e82a2a'; g.font = '900 34px Impact, "Arial Narrow", sans-serif'; g.fillText('OPEN', 24, 60);
  g.fillStyle = '#1a1a1a'; g.fillRect(300, 26, 120, 70); g.fillStyle = '#ffd24a'; g.font = '800 22px Impact, sans-serif'; g.fillText('HOT', 334, 56); g.fillText('COFFEE', 316, 84);
  g.fillStyle = 'rgba(255,255,255,.18)'; g.beginPath(); g.moveTo(40, 0); g.lineTo(110, 0); g.lineTo(30, h); g.lineTo(0, h); g.fill();
});
TEX.gym = canvasTex(512, 128, (g, w, h) => {
  const gr = g.createLinearGradient(0, 0, 0, h); gr.addColorStop(0, '#ffe2a8'); gr.addColorStop(1, '#c99a5a'); g.fillStyle = gr; g.fillRect(0, 0, w, h);
  g.strokeStyle = '#e0602a'; g.lineWidth = 4; g.beginPath(); g.arc(200, 70, 18, 0, TAU); g.stroke(); g.fillStyle = '#f4f4f4'; g.fillRect(170, 30, 60, 34);
  g.fillStyle = 'rgba(40,30,20,.9)'; for (let x = 0; x <= w; x += 42) g.fillRect(x - 3, 0, 6, h); g.fillRect(0, h / 2 - 3, w, 6); g.fillRect(0, 0, w, 6); g.fillRect(0, h - 6, w, 6);
});

function facadeTex(style, seed) {
  const R = rng(seed);
  const W = 256, H = 256; // 12m x 12m, 4 cols x 4 floors
  const base = { brick: '#5d2f25', brown: '#3e2a23', grey: '#7a7468', siding: '#46525e', ware: '#4d4f52', cream: '#8a7b62' }[style];
  const lit = [];
  const map = canvasTex(W, H, g => {
    g.fillStyle = base; g.fillRect(0, 0, W, H);
    if (style === 'brick' || style === 'brown' || style === 'cream') {
      for (let y = 0; y < H; y += 4) for (let x = (y / 4) % 2 ? -4 : 0; x < W; x += 9) { const v = R() * 26 - 13; g.fillStyle = `rgba(${v > 0 ? '255,220,200' : '0,0,0'},${Math.abs(v) / 100})`; g.fillRect(x, y, 8, 3); }
      g.fillStyle = 'rgba(0,0,0,.12)'; for (let y = 3; y < H; y += 4) g.fillRect(0, y, W, 1);
    } else if (style === 'grey') {
      for (let y = 0; y < H; y += 12) for (let x = (y / 12) % 2 ? -10 : 0; x < W; x += 22) { g.fillStyle = `rgba(${R() > .5 ? '255,250,240' : '0,0,0'},${R() * .12})`; g.fillRect(x, y, 21, 11); }
      g.fillStyle = 'rgba(0,0,0,.18)'; for (let y = 11; y < H; y += 12) g.fillRect(0, y, W, 1);
    } else if (style === 'siding') {
      for (let y = 0; y < H; y += 5) { g.fillStyle = `rgba(0,0,0,${0.08 + R() * .08})`; g.fillRect(0, y + 4, W, 1); }
    } else {
      for (let x = 0; x < W; x += 32) { g.fillStyle = 'rgba(0,0,0,.2)'; g.fillRect(x, 0, 1, H); }
      speckle(g, W, H, 300, ['rgba(0,0,0,.15)', 'rgba(255,255,255,.06)'], 1, 3);
    }
    // grime gradient toward street
    const gr = g.createLinearGradient(0, 0, 0, H); gr.addColorStop(0, 'rgba(0,0,0,0)'); gr.addColorStop(1, 'rgba(0,0,0,.25)'); g.fillStyle = gr; g.fillRect(0, 0, W, H);
    const ware = style === 'ware';
    for (let f = 0; f < 4; f++) for (let c = 0; c < 4; c++) {
      if (ware && (f % 2 === 1 || c % 2 === 1)) continue;
      const x = c * 64 + (ware ? 8 : 18), y = f * 64 + (ware ? 10 : 12), ww = ware ? 48 : 28, hh = ware ? 14 : 38;
      g.fillStyle = 'rgba(0,0,0,.35)'; g.fillRect(x - 3, y - 4, ww + 6, 4); // lintel shadow
      g.fillStyle = style === 'grey' ? '#a49c8c' : '#6f6458'; g.fillRect(x - 3, y - 5, ww + 6, 3);
      const isLit = R() < (ware ? 0.15 : 0.36);
      g.fillStyle = isLit ? '#2a1f16' : '#0b1420'; g.fillRect(x, y, ww, hh);
      const rg = g.createLinearGradient(x, y, x + ww, y + hh); rg.addColorStop(0, 'rgba(120,150,190,.25)'); rg.addColorStop(.5, 'rgba(255,160,90,.05)'); rg.addColorStop(1, 'rgba(0,0,0,0)'); g.fillStyle = rg; g.fillRect(x, y, ww, hh);
      g.fillStyle = 'rgba(30,24,20,.9)'; g.fillRect(x + ww / 2 - 1, y, 2, hh);
      g.fillStyle = '#e8f0f8'; g.fillRect(x - 3, y + hh, ww + 6, 3); // snow on sill
      g.fillStyle = 'rgba(0,0,0,.4)'; g.fillRect(x - 3, y + hh + 3, ww + 6, 2);
      if (isLit) lit.push({ x, y, ww, hh, k: R() });
    }
  });
  const mask = canvasTex(W, H, g => {
    g.fillStyle = '#fff'; g.fillRect(0, 0, W, H);
    g.fillStyle = '#000';
    for (let f = 0; f < 4; f++) for (let c = 0; c < 4; c++) {
      if (style === 'ware' && (f % 2 === 1 || c % 2 === 1)) continue;
      const ware = style === 'ware', x = c * 64 + (ware ? 8 : 18), y = f * 64 + (ware ? 10 : 12), ww = ware ? 48 : 28, hh = ware ? 14 : 38;
      g.fillRect(x, y, ww, hh);
    }
  });
  const emis = canvasTex(W, H, g => {
    g.fillStyle = '#000'; g.fillRect(0, 0, W, H);
    for (const w of lit) {
      const col = w.k < 0.12 ? [120, 160, 255] : w.k < 0.3 ? [255, 140, 70] : w.k < 0.45 ? [210, 120, 60] : [255, 190, 110];
      const gr = g.createLinearGradient(w.x, w.y, w.x, w.y + w.hh);
      gr.addColorStop(0, `rgba(${col[0]},${col[1]},${col[2]},.55)`); gr.addColorStop(1, `rgba(${col[0]},${col[1]},${col[2]},.95)`);
      g.fillStyle = gr; g.fillRect(w.x, w.y, w.ww, w.hh);
      if (w.k > 0.6) { g.fillStyle = 'rgba(0,0,0,.45)'; for (let y = w.y + 3; y < w.y + w.hh; y += 5) g.fillRect(w.x, y, w.ww, 2); }
      if (w.k > 0.85) { g.fillStyle = 'rgba(0,0,0,.6)'; g.fillRect(w.x + w.ww * .55, w.y + 6, w.ww * .3, w.hh * .7); }
      g.fillStyle = 'rgba(0,0,0,1)'; g.fillRect(w.x + w.ww / 2 - 1, w.y, 2, w.hh);
    }
  });
  return { map, emis, mask };
}

function signTex(text, opts) {
  opts = opts || {};
  const w = opts.w || 512, h = opts.h || 128;
  return canvasTex(w, h, g => {
    g.fillStyle = opts.bg || '#120a06'; g.fillRect(0, 0, w, h);
    if (opts.border) { g.strokeStyle = opts.border; g.lineWidth = 6; g.strokeRect(6, 6, w - 12, h - 12); }
    g.font = `${opts.weight || 900} ${opts.size || 72}px "Big Shoulders Display", Impact, "Arial Narrow", sans-serif`;
    g.textAlign = 'center'; g.textBaseline = 'middle';
    g.shadowColor = opts.glow || opts.fg || '#ff9a3c'; g.shadowBlur = opts.blur === undefined ? 18 : opts.blur;
    g.fillStyle = opts.fg || '#ff9a3c';
    const lines = String(text).split('\n');
    lines.forEach((ln, i) => g.fillText(ln, w / 2, h / 2 + (i - (lines.length - 1) / 2) * (opts.size || 72) * 1.05, w - 28));
  }, { repeat: false });
}

/* ---------- env map for metal guns ---------- */
let ENV = null;
function buildEnv() {
  const pm = new THREE.PMREMGenerator(renderer);
  const es = new THREE.Scene();
  const sky = new THREE.Mesh(new THREE.SphereGeometry(10, 24, 12), new THREE.MeshBasicMaterial({ side: THREE.BackSide, map: TEX.sky }));
  es.add(sky);
  const pan = (c, x, y, z, w, h) => { const m = new THREE.Mesh(new THREE.PlaneGeometry(w, h), new THREE.MeshBasicMaterial({ color: c, side: THREE.DoubleSide })); m.position.set(x, y, z); m.lookAt(0, 0, 0); es.add(m); };
  pan(0xffc890, 6, 5, 3, 6, 3); pan(0x9fd0ff, -6, 3, -2, 4, 6); pan(0xffffff, 0, 8, 0, 8, 2); pan(0xff9a50, -2, 1, 7, 6, 2); pan(0xdfe8f2, 0, 2, -8, 8, 3); pan(0x6a7a8c, 0, -6, 0, 12, 12);
  ENV = pm.fromScene(es, 0.03).texture;
  pm.dispose();
}
if (!LITE_MODE) buildEnv();

/* ---------- shared materials (PBR) ---------- */
const MAT = {};
MAT.props = new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.84, metalness: 0.02, envMapIntensity: 0.55 });
MAT.emis = new THREE.MeshBasicMaterial({ vertexColors: true });
MAT.snow = new THREE.MeshStandardMaterial({ color: 0xeef3f9, roughness: 0.93, envMapIntensity: 0.6 });
MAT.ground = new THREE.MeshStandardMaterial({ map: TEX.snow, roughness: 0.95, envMapIntensity: 0.55 });
MAT.road = new THREE.MeshStandardMaterial({ map: TEX.road, roughness: 0.5, metalness: 0.0, envMapIntensity: 1.0 });
MAT.walk = new THREE.MeshStandardMaterial({ map: TEX.walk, roughness: 0.86, envMapIntensity: 0.6 });
MAT.glowDecal = new THREE.MeshBasicMaterial({ map: TEX.glow, color: 0xff8a33, transparent: true, opacity: 0.55, blending: THREE.AdditiveBlending, depthWrite: false, polygonOffset: true, polygonOffsetFactor: -2, polygonOffsetUnits: -4 });
MAT.ice = new THREE.MeshStandardMaterial({ color: 0x9cc4e0, roughness: 0.08, metalness: 0.05, envMapIntensity: 1.3 });
MAT.glass = new THREE.MeshStandardMaterial({ color: 0x7fa8c8, transparent: true, opacity: 0.14, roughness: 0.1, metalness: 0.1, envMapIntensity: 0.35, depthWrite: false, side: THREE.DoubleSide });
MAT.shop = new THREE.MeshBasicMaterial({ map: TEX.shop });
MAT.gym = new THREE.MeshBasicMaterial({ map: TEX.gym });

/* ---------- geometry batching ---------- */
const GEO = {
  box: new THREE.BoxGeometry(1, 1, 1).toNonIndexed(),
  cyl: new THREE.CylinderGeometry(1, 1, 1, 12).toNonIndexed(),
  cyl6: new THREE.CylinderGeometry(1, 1, 1, 6).toNonIndexed(),
  cone: new THREE.ConeGeometry(1, 1, 7).toNonIndexed(),
  sph: new THREE.SphereGeometry(1, 10, 7).toNonIndexed(),
  ico: new THREE.IcosahedronGeometry(1, 1).toNonIndexed(),
  plane: new THREE.PlaneGeometry(1, 1).toNonIndexed(),
};
const _m4 = new THREE.Matrix4(), _q4 = new THREE.Quaternion(), _s3 = new THREE.Vector3(), _p3 = new THREE.Vector3(), _e3 = new THREE.Euler(), _n3 = new THREE.Matrix3(), _v3 = new THREE.Vector3(), _c3 = new THREE.Color();
function mtx(x, y, z, sx, sy, sz, rx, ry, rz) { _e3.set(rx || 0, ry || 0, rz || 0); _q4.setFromEuler(_e3); return _m4.compose(_p3.set(x, y, z), _q4, _s3.set(sx, sy, sz)); }
class Batch {
  constructor() { this.p = []; this.n = []; this.u = []; this.c = []; }
  add(geo, m, color, from, count) {
    const pa = geo.attributes.position, na = geo.attributes.normal, ua = geo.attributes.uv;
    _n3.getNormalMatrix(m);
    if (color !== undefined && color !== null) { if (color.isColor) _c3.copy(color); else _c3.set(color); } else _c3.setRGB(1, 1, 1);
    const end = Math.min(pa.count, (from || 0) + (count === undefined ? Infinity : count));
    for (let i = from || 0; i < end; i++) {
      _v3.fromBufferAttribute(pa, i).applyMatrix4(m); this.p.push(_v3.x, _v3.y, _v3.z);
      _v3.fromBufferAttribute(na, i).applyMatrix3(_n3).normalize(); this.n.push(_v3.x, _v3.y, _v3.z);
      if (ua) this.u.push(ua.getX(i), ua.getY(i)); else this.u.push(0, 0);
      this.c.push(_c3.r, _c3.g, _c3.b);
    }
    if (LITE_MODE) liteRecord(this, geo, m, _c3);
  }
  build() {
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(this.p, 3));
    g.setAttribute('normal', new THREE.Float32BufferAttribute(this.n, 3));
    g.setAttribute('uv', new THREE.Float32BufferAttribute(this.u, 2));
    g.setAttribute('color', new THREE.Float32BufferAttribute(this.c, 3));
    g.computeBoundingSphere();
    return g;
  }
  mesh(mat, cast, receive) { const m = new THREE.Mesh(this.build(), mat); if (LITE_MODE) { liteCommit(this, mat); m.userData.liteSkip = true; } m.matrixAutoUpdate = false; m.updateMatrix(); m.castShadow = cast !== false; m.receiveShadow = receive !== false; scene.add(m); return m; }
}

/* ---------- GPU particles (one draw call per system) ---------- */
class Particles {
  constructor(n, tex, blending) {
    this.n = n; this.i = 0;
    this.pos = new Float32Array(n * 3); this.vel = new Float32Array(n * 3);
    this.life = new Float32Array(n); this.max = new Float32Array(n);
    this.s0 = new Float32Array(n); this.s1 = new Float32Array(n); this.a0 = new Float32Array(n);
    this.col = new Float32Array(n * 3); this.drag = new Float32Array(n); this.grav = new Float32Array(n);
    this.size = new Float32Array(n); this.alpha = new Float32Array(n);
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.BufferAttribute(this.pos, 3).setUsage(THREE.DynamicDrawUsage));
    g.setAttribute('size', new THREE.BufferAttribute(this.size, 1).setUsage(THREE.DynamicDrawUsage));
    g.setAttribute('alpha', new THREE.BufferAttribute(this.alpha, 1).setUsage(THREE.DynamicDrawUsage));
    g.setAttribute('color', new THREE.BufferAttribute(this.col, 3).setUsage(THREE.DynamicDrawUsage));
    g.boundingSphere = new THREE.Sphere(new THREE.Vector3(), 1e6);
    this.mat = new THREE.ShaderMaterial({
      uniforms: { map: { value: tex }, uScale: { value: 400 } },
      vertexShader: `attribute float size; attribute float alpha; attribute vec3 color; varying float vA; varying vec3 vC; uniform float uScale;
        void main(){ vA=alpha; vC=color; vec4 mv=modelViewMatrix*vec4(position,1.0); gl_PointSize=size*uScale/max(0.1,-mv.z); gl_Position=projectionMatrix*mv; }`,
      fragmentShader: `uniform sampler2D map; varying float vA; varying vec3 vC; void main(){ vec4 t=texture2D(map,gl_PointCoord); gl_FragColor=vec4(vC*t.rgb,t.a*vA); if(gl_FragColor.a<0.004) discard; }`,
      transparent: true, depthWrite: false, blending: blending || THREE.NormalBlending,
    });
    this.pts = new THREE.Points(g, this.mat); this.pts.frustumCulled = false; this.pts.renderOrder = 5;
    scene.add(this.pts); this.geo = g;
  }
  spawn(x, y, z, vx, vy, vz, life, s0, s1, a0, r, gg, b, drag, grav) {
    const i = this.i; this.i = (this.i + 1) % this.n;
    this.pos[i * 3] = x; this.pos[i * 3 + 1] = y; this.pos[i * 3 + 2] = z;
    this.vel[i * 3] = vx; this.vel[i * 3 + 1] = vy; this.vel[i * 3 + 2] = vz;
    this.life[i] = life; this.max[i] = life; this.s0[i] = s0; this.s1[i] = s1; this.a0[i] = a0;
    this.col[i * 3] = r; this.col[i * 3 + 1] = gg; this.col[i * 3 + 2] = b; this.drag[i] = drag || 0; this.grav[i] = grav || 0;
  }
  update(dt, wx, wz) {
    for (let i = 0; i < this.n; i++) {
      if (this.life[i] <= 0) { this.alpha[i] = 0; this.size[i] = 0; continue; }
      this.life[i] -= dt;
      const k = 1 - this.life[i] / this.max[i];
      const d = Math.max(0, 1 - this.drag[i] * dt);
      this.vel[i * 3] = this.vel[i * 3] * d + wx * this.drag[i] * dt; this.vel[i * 3 + 2] = this.vel[i * 3 + 2] * d + wz * this.drag[i] * dt;
      this.vel[i * 3 + 1] = this.vel[i * 3 + 1] * d + this.grav[i] * dt;
      this.pos[i * 3] += this.vel[i * 3] * dt; this.pos[i * 3 + 1] += this.vel[i * 3 + 1] * dt; this.pos[i * 3 + 2] += this.vel[i * 3 + 2] * dt;
      this.size[i] = this.s0[i] + (this.s1[i] - this.s0[i]) * k;
      this.alpha[i] = this.a0[i] * (k < 0.15 ? k / 0.15 : 1 - (k - 0.15) / 0.85);
    }
    this.geo.attributes.position.needsUpdate = true; this.geo.attributes.size.needsUpdate = true; this.geo.attributes.alpha.needsUpdate = true; this.geo.attributes.color.needsUpdate = true;
  }
}
const PFX_ADD = new Particles(700, TEX.dot, THREE.AdditiveBlending);
const PFX_SMOKE = new Particles(500, TEX.puff, THREE.NormalBlending);
function setParticleScale() {
  const s = renderer.domElement.height / (2 * Math.tan(THREE.MathUtils.degToRad(camera.fov) / 2));
  PFX_ADD.mat.uniforms.uScale.value = s; PFX_SMOKE.mat.uniforms.uScale.value = s;
}

/* ---------- tracers ---------- */
const TRACER_N = 48;
const tracerPos = new Float32Array(TRACER_N * 6), tracerCol = new Float32Array(TRACER_N * 6), tracerLife = new Float32Array(TRACER_N), tracerBase = new Float32Array(TRACER_N * 3);
const tracerGeo = new THREE.BufferGeometry();
tracerGeo.setAttribute('position', new THREE.BufferAttribute(tracerPos, 3).setUsage(THREE.DynamicDrawUsage));
tracerGeo.setAttribute('color', new THREE.BufferAttribute(tracerCol, 3).setUsage(THREE.DynamicDrawUsage));
tracerGeo.boundingSphere = new THREE.Sphere(new THREE.Vector3(), 1e6);
const tracers = new THREE.LineSegments(tracerGeo, new THREE.LineBasicMaterial({ vertexColors: true, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false }));
tracers.frustumCulled = false; scene.add(tracers);
let tracerI = 0;
function addTracer(a, b, col) {
  const i = tracerI; tracerI = (tracerI + 1) % TRACER_N;
  tracerPos.set([a.x, a.y, a.z, b.x, b.y, b.z], i * 6);
  tracerBase.set(col || [1, 0.75, 0.45], i * 3);
  tracerLife[i] = 0.07;
}
function updateTracers(dt) {
  for (let i = 0; i < TRACER_N; i++) {
    tracerLife[i] = Math.max(0, tracerLife[i] - dt);
    const k = tracerLife[i] / 0.07;
    for (let j = 0; j < 2; j++) { const f = j === 0 ? k * 0.3 : k; tracerCol[i * 6 + j * 3] = tracerBase[i * 3] * f; tracerCol[i * 6 + j * 3 + 1] = tracerBase[i * 3 + 1] * f; tracerCol[i * 6 + j * 3 + 2] = tracerBase[i * 3 + 2] * f; }
  }
  tracerGeo.attributes.position.needsUpdate = true; tracerGeo.attributes.color.needsUpdate = true;
}

/* ---------- sky: physical day sky + night dome + clouds + stars + Loop skyline ---------- */
const SKY = new Sky(); SKY.scale.setScalar(1800); SKY.renderOrder = -12; scene.add(SKY);
const SU = SKY.material.uniforms;
SU.turbidity.value = 7; SU.rayleigh.value = 1.4; SU.mieCoefficient.value = 0.006; SU.mieDirectionalG.value = 0.82;
const skyMesh = new THREE.Mesh(new THREE.SphereGeometry(1700, 32, 16), new THREE.MeshBasicMaterial({ map: TEX.sky, side: THREE.BackSide, fog: false, depthWrite: false, transparent: true, opacity: 1 }));
skyMesh.renderOrder = -11; scene.add(skyMesh);
TEX.clouds = canvasTex(1024, 512, (g, w, h) => {
  g.clearRect(0, 0, w, h);
  for (let i = 0; i < 520; i++) {
    const y = h * (0.08 + Math.pow(Math.random(), 0.7) * 0.4), x = Math.random() * w, r = rand(18, 70) * (1 - y / h * 0.6);
    const gr = g.createRadialGradient(x, y, 0, x, y, r); gr.addColorStop(0, 'rgba(255,255,255,.22)'); gr.addColorStop(1, 'rgba(255,255,255,0)');
    g.fillStyle = gr; g.beginPath(); g.ellipse(x, y, r * 2.2, r * 0.7, 0, 0, TAU); g.fill();
    if (x < r * 2.2) { g.beginPath(); g.ellipse(x + w, y, r * 2.2, r * 0.7, 0, 0, TAU); g.fill(); }
  }
}, { repeat: true });
const cloudMesh = new THREE.Mesh(new THREE.SphereGeometry(1600, 32, 12, 0, TAU, 0, Math.PI * 0.5), new THREE.MeshBasicMaterial({ map: TEX.clouds, side: THREE.BackSide, transparent: true, depthWrite: false, fog: false, opacity: 0.85 }));
cloudMesh.renderOrder = -10; scene.add(cloudMesh);
const starGeo = new THREE.BufferGeometry(); { const p = []; for (let i = 0; i < 900; i++) { const a = Math.random() * TAU, e = Math.asin(Math.random() * 0.95 + 0.04); p.push(Math.cos(e) * Math.sin(a) * 1550, Math.sin(e) * 1550, Math.cos(e) * Math.cos(a) * 1550); } starGeo.setAttribute('position', new THREE.Float32BufferAttribute(p, 3)); }
const starMat = new THREE.PointsMaterial({ color: 0xdfe8ff, size: 1.6, sizeAttenuation: false, transparent: true, opacity: 0, fog: false, depthWrite: false });
const stars = new THREE.Points(starGeo, starMat); stars.renderOrder = -10.5; scene.add(stars);
const SKY_BEACONS = [];
const SKYLINE = {};
(function buildSkyline() {
  const winTex = canvasTex(128, 256, (g, w, h) => {
    g.fillStyle = '#0a1018'; g.fillRect(0, 0, w, h);
    for (let y = 2; y < h; y += 6) for (let x = 2; x < w; x += 5) {
      const r = Math.random();
      if (r < 0.34) { g.fillStyle = r < 0.05 ? 'rgba(150,190,255,.9)' : r < 0.2 ? 'rgba(255,200,130,.85)' : 'rgba(255,235,200,.6)'; g.fillRect(x, y, 3, 3); }
    }
  });
  const dayTex = canvasTex(128, 256, (g, w, h) => {
    const gr = g.createLinearGradient(0, 0, w, 0); gr.addColorStop(0, '#9aa8b8'); gr.addColorStop(0.5, '#c4ced8'); gr.addColorStop(1, '#8a98a8');
    g.fillStyle = gr; g.fillRect(0, 0, w, h);
    g.fillStyle = 'rgba(40,55,75,.35)'; for (let y = 0; y < h; y += 6) g.fillRect(0, y, w, 2); for (let x = 0; x < w; x += 10) g.fillRect(x, 0, 1, h);
  });
  SKYLINE.night = new THREE.MeshBasicMaterial({ map: winTex, fog: false, color: 0xb8c4dc, transparent: true, opacity: 1, depthWrite: false });
  SKYLINE.day = new THREE.MeshBasicMaterial({ map: dayTex, fog: false, color: 0x8a96a6 });
  const b = new Batch();
  const R = rng(4242);
  const dirA = Math.atan2(-0.72, 0.69);
  for (let i = 0; i < 70; i++) {
    const a = dirA + (R() - 0.5) * 0.6;
    const centre = 1 - Math.abs(R() - 0.5) * 2;
    const dist = 980 + R() * 480;
    const x = Math.cos(a) * dist, z = Math.sin(a) * dist;
    const w = 18 + R() * 28, d = 18 + R() * 28;
    const h = 45 + Math.pow(centre, 2.2) * 250 * (0.5 + R() * 0.7) * (Math.abs(a - dirA) < 0.2 ? 1.3 : 0.8);
    const geo = new THREE.BoxGeometry(1, 1, 1).toNonIndexed();
    const uv = geo.attributes.uv;
    for (let k = 0; k < uv.count; k++) uv.setXY(k, uv.getX(k) * w / 40, uv.getY(k) * h / 80);
    b.add(geo, mtx(x, h / 2 - 8, z, w, h, d, 0, R() * 0.6, 0), 0xffffff);
    if (h > 170) {
      const tw = w * (0.5 + R() * 0.2), th = h * (0.12 + R() * 0.15);
      b.add(geo, mtx(x, h + th / 2 - 8, z, tw, th, tw), 0xffffff);
      SKY_BEACONS.push([x, h + th - 6, z]);
      if (R() < 0.5) SKY_BEACONS.push([x + tw * 0.3, h + th + 22, z]);
    }
  }
  const geo = b.build();
  const md = new THREE.Mesh(geo, SKYLINE.day); md.renderOrder = -9; scene.add(md);
  const mn = new THREE.Mesh(geo, SKYLINE.night); mn.renderOrder = -8; scene.add(mn);
  const vg = canvasTex(4, 128, (g, w, h) => { const gr = g.createLinearGradient(0, 0, 0, h); gr.addColorStop(0, 'rgba(255,255,255,0)'); gr.addColorStop(0.6, 'rgba(255,255,255,.5)'); gr.addColorStop(1, 'rgba(255,255,255,1)'); g.fillStyle = gr; g.fillRect(0, 0, w, h); }, { repeat: false });
  SKYLINE.haze = new THREE.MeshBasicMaterial({ map: vg, color: 0x1a2638, transparent: true, opacity: 0.75, side: THREE.BackSide, fog: false, depthWrite: false });
  const haze = new THREE.Mesh(new THREE.CylinderGeometry(900, 900, 220, 48, 1, true), SKYLINE.haze);
  haze.position.y = 80; haze.renderOrder = -7; scene.add(haze);
  const bg = new THREE.BufferGeometry(); bg.setAttribute('position', new THREE.Float32BufferAttribute(SKY_BEACONS.flat(), 3));
  const bm = new THREE.PointsMaterial({ color: 0xff2a1a, size: 6, sizeAttenuation: false, map: TEX.dot, transparent: true, fog: false, depthWrite: false, blending: THREE.AdditiveBlending });
  const bp = new THREE.Points(bg, bm); bp.renderOrder = -6; scene.add(bp);
  SKY_BEACONS.mat = bm;
})();

/* ---------- falling snow ---------- */
const SNOW_N = LOW_POWER ? 2200 : 4200, SNOW_BOX = [70, 34, 70];
const snowLocal = new Float32Array(SNOW_N * 3), snowWorld = new Float32Array(SNOW_N * 3), snowSpeed = new Float32Array(SNOW_N);
for (let i = 0; i < SNOW_N; i++) { snowLocal[i * 3] = Math.random() * SNOW_BOX[0]; snowLocal[i * 3 + 1] = Math.random() * SNOW_BOX[1]; snowLocal[i * 3 + 2] = Math.random() * SNOW_BOX[2]; snowSpeed[i] = 0.7 + Math.random() * 0.9; }
const snowGeo = new THREE.BufferGeometry();
snowGeo.setAttribute('position', new THREE.BufferAttribute(snowWorld, 3).setUsage(THREE.DynamicDrawUsage));
snowGeo.boundingSphere = new THREE.Sphere(new THREE.Vector3(), 1e6);
const snowMat = new THREE.PointsMaterial({ color: 0xeaf3ff, size: 0.075, map: TEX.dot, transparent: true, opacity: 0.9, depthWrite: false });
const snowPts = new THREE.Points(snowGeo, snowMat); snowPts.frustumCulled = false; scene.add(snowPts);
const DRIFT_N = 700;
const driftLocal = new Float32Array(DRIFT_N * 3), driftWorld = new Float32Array(DRIFT_N * 3);
for (let i = 0; i < DRIFT_N; i++) { driftLocal[i * 3] = Math.random() * 50; driftLocal[i * 3 + 1] = Math.random() * 1.6; driftLocal[i * 3 + 2] = Math.random() * 50; }
const driftGeo = new THREE.BufferGeometry();
driftGeo.setAttribute('position', new THREE.BufferAttribute(driftWorld, 3).setUsage(THREE.DynamicDrawUsage));
driftGeo.boundingSphere = new THREE.Sphere(new THREE.Vector3(), 1e6);
const driftMat = new THREE.PointsMaterial({ color: 0xffffff, size: 0.16, map: TEX.puff, transparent: true, opacity: 0, depthWrite: false });
const driftPts = new THREE.Points(driftGeo, driftMat); driftPts.frustumCulled = false; scene.add(driftPts);
function updateSnow(dt, wx, wz, gust, t) {
  const cx = camera.position.x - SNOW_BOX[0] / 2, cy = camera.position.y - SNOW_BOX[1] / 2, cz = camera.position.z - SNOW_BOX[2] / 2;
  const fall = 1.3 + gust * 0.6;
  for (let i = 0; i < SNOW_N; i++) {
    const k = i * 3, s = snowSpeed[i];
    snowLocal[k] += (wx * s + Math.sin(t * 1.3 + i) * 0.3) * dt;
    snowLocal[k + 1] -= fall * s * dt;
    snowLocal[k + 2] += (wz * s + Math.cos(t * 1.1 + i * 0.7) * 0.3) * dt;
    let lx = (snowLocal[k] - cx) % SNOW_BOX[0]; if (lx < 0) lx += SNOW_BOX[0];
    let ly = (snowLocal[k + 1] - cy) % SNOW_BOX[1]; if (ly < 0) ly += SNOW_BOX[1];
    let lz = (snowLocal[k + 2] - cz) % SNOW_BOX[2]; if (lz < 0) lz += SNOW_BOX[2];
    snowWorld[k] = cx + lx; snowWorld[k + 1] = cy + ly; snowWorld[k + 2] = cz + lz;
  }
  snowGeo.attributes.position.needsUpdate = true;
  const dx0 = camera.position.x - 25, dz0 = camera.position.z - 25;
  for (let i = 0; i < DRIFT_N; i++) {
    const k = i * 3;
    driftLocal[k] += wx * 2.2 * dt; driftLocal[k + 2] += wz * 2.2 * dt;
    driftLocal[k + 1] += Math.sin(t * 3 + i) * 0.2 * dt;
    let lx = (driftLocal[k] - dx0) % 50; if (lx < 0) lx += 50;
    let lz = (driftLocal[k + 2] - dz0) % 50; if (lz < 0) lz += 50;
    driftWorld[k] = dx0 + lx; driftWorld[k + 1] = clamp(driftLocal[k + 1], 0.05, 1.6) + (P ? P.pos.y : 0); driftWorld[k + 2] = dz0 + lz;
  }
  driftGeo.attributes.position.needsUpdate = true;
  driftMat.opacity = clamp((gust - 0.25) * 0.9, 0, 0.55);
}

/* =========================================================
   POST: bloom + film grade, then tone map
   ========================================================= */
const GRADE = {
  uniforms: {
    tDiffuse: { value: null }, uTime: { value: 0 }, uSat: { value: 1.06 }, uVig: { value: 0.95 }, uHurt: { value: 0 }, uFrost: { value: 0 }, uFade: { value: 0 }, uDesat: { value: 0 },
    uLift: { value: new THREE.Vector3(0.94, 1.0, 1.08) }, uGain: { value: new THREE.Vector3(1.07, 1.0, 0.93) }, uGrain: { value: 0.022 }, uAspect: { value: 1.7 },
  },
  vertexShader: 'varying vec2 vUv; void main(){ vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }',
  fragmentShader: `uniform sampler2D tDiffuse; uniform float uTime, uSat, uVig, uHurt, uFrost, uFade, uDesat, uGrain, uAspect; uniform vec3 uLift, uGain; varying vec2 vUv;
  float h(vec2 p){ return fract(sin(dot(p, vec2(12.9898,78.233))) * 43758.5453); }
  void main(){
    vec3 c = texture2D(tDiffuse, vUv).rgb;
    float l = dot(c, vec3(0.2126,0.7152,0.0722));
    c = mix(vec3(l), c, uSat * (1.0 - uDesat));
    c *= mix(uLift, uGain, smoothstep(0.02, 0.9, l));
    vec2 d = (vUv - 0.5) * vec2(uAspect, 1.0) / uAspect * 1.6;
    float r = dot(d, d);
    c *= 1.0 - r * uVig * 0.55;
    float edge = smoothstep(0.25, 1.1, r);
    c = mix(c, c * vec3(1.6, 0.18, 0.15) + vec3(0.12, 0.0, 0.0), uHurt * edge);
    c = mix(c, vec3(0.75, 0.86, 1.0) * (0.6 + l), uFrost * edge * 0.8);
    c += (h(vUv * 1000.0 + uTime) - 0.5) * uGrain * (0.25 + l);
    c *= 1.0 - uFade;
    gl_FragColor = vec4(max(c, 0.0), 1.0);
  }`,
};
const composerRT = new THREE.WebGLRenderTarget(Math.floor(innerWidth * PR), Math.floor(innerHeight * PR), { type: THREE.HalfFloatType, samples: LOW_POWER ? 0 : 4 });
const composer = new EffectComposer(renderer, composerRT);
composer.setPixelRatio(PR); composer.setSize(innerWidth, innerHeight);
const renderPass = new RenderPass(scene, camera);
const bloomPass = new UnrealBloomPass(new THREE.Vector2(innerWidth, innerHeight), 0.5, 0.55, 0.85);
const gradePass = new ShaderPass(GRADE);
const outputPass = new OutputPass();
composer.addPass(renderPass); composer.addPass(bloomPass); composer.addPass(gradePass); composer.addPass(outputPass);
function resizeRender() {
  renderer.setSize(innerWidth, innerHeight); composer.setSize(innerWidth, innerHeight);
  camera.aspect = innerWidth / innerHeight; camera.updateProjectionMatrix();
  gradePass.uniforms.uAspect.value = innerWidth / innerHeight;
}
function applyQuality() {
  const hi = S.settings.quality !== 'low';
  renderer.shadowMap.enabled = hi; SUN.castShadow = hi;
  bloomPass.enabled = true; bloomPass.resolution.set(innerWidth / (hi ? 1 : 2), innerHeight / (hi ? 1 : 2));
  scene.traverse(o => { if (o.material) (Array.isArray(o.material) ? o.material : [o.material]).forEach(m => m.needsUpdate = true); });
}

/* =========================================================
   DAY / NIGHT (shared world clock)
   ========================================================= */
const DN = { night: 1, lamps: 1, elev: -20, sunDir: new THREE.Vector3(), envT: 0, lastEnvN: -1, dusk: 0 };
const _sunC = new THREE.Color(), _tmpC = new THREE.Color(), _tmpC2 = new THREE.Color();
const smooth = (a, b, x) => { const t = clamp((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t); };
function sunAngles(min) {
  const hr = min / 60, rise = 7.1, set = 16.6;
  let elev, az;
  if (hr >= rise && hr <= set) { const k = (hr - rise) / (set - rise); elev = Math.sin(k * Math.PI) * 27; az = 118 + k * 124; }
  else { const span = 24 - set + rise; const k = (hr > set ? hr - set : hr + 24 - set) / span; elev = -Math.sin(k * Math.PI) * 42; az = 242 + k * 236; }
  return { elev, az };
}
const dirFrom = (elev, az, out) => { const e = THREE.MathUtils.degToRad(elev), a = THREE.MathUtils.degToRad(az); return out.set(Math.cos(e) * Math.sin(a), Math.sin(e), -Math.cos(e) * Math.cos(a)); };
// gradient dome used to bake a reflection environment for the current time of day
const ENV_SCENE = new THREE.Scene();
const envDomeMat = new THREE.ShaderMaterial({
  side: THREE.BackSide, depthWrite: false,
  uniforms: { top: { value: new THREE.Color() }, hor: { value: new THREE.Color() }, bot: { value: new THREE.Color() }, sun: { value: new THREE.Vector3(0, 1, 0) }, sunCol: { value: new THREE.Color() }, hdrDay: { value: null }, hdrNight: { value: null }, hdrMix: { value: 0 }, hdrAmt: { value: 0 }, dayNorm: { value: 1 }, nightNorm: { value: 1 } },
  vertexShader: 'varying vec3 vD; void main(){ vD = normalize(position); gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }',
  fragmentShader: `uniform vec3 top, hor, bot, sun, sunCol; uniform sampler2D hdrDay, hdrNight; uniform float hdrMix, hdrAmt, dayNorm, nightNorm; varying vec3 vD;
    vec3 rgbe(vec4 t) { return t.a > 0.0 ? t.rgb * exp2(t.a * 255.0 - 128.0) * (255.0 / 256.0) : vec3(0.0); }
    void main(){ float y = vD.y; vec3 c = y > 0.0 ? mix(hor, top, pow(y, 0.6)) : mix(hor, bot, pow(-y, 0.4)); c += sunCol * pow(max(dot(vD, sun), 0.0), 24.0) * 2.0;
      if (hdrAmt > 0.0) { vec3 d = normalize(vD); vec2 uv = vec2(atan(d.z, d.x) / 6.2831853 + 0.5, asin(clamp(d.y, -1.0, 1.0)) / 3.1415927 + 0.5);
        vec3 h = mix(rgbe(texture2D(hdrDay, uv)) / dayNorm, rgbe(texture2D(hdrNight, uv)) / nightNorm, hdrMix);
        c *= mix(vec3(1.0), min(h, vec3(40.0)), hdrAmt); }
      gl_FragColor = vec4(c, 1.0); }`,
});
ENV_SCENE.add(new THREE.Mesh(new THREE.SphereGeometry(10, 24, 12), envDomeMat));
const PMREM = new THREE.PMREMGenerator(renderer);
let envRT = null;
function bakeEnv() {
  if (envRT) envRT.dispose();
  envRT = PMREM.fromScene(ENV_SCENE, 0.02);
  scene.environment = envRT.texture;
}
function updateDayNight(dt, focus) {
  const min = worldMinutes();
  const { elev, az } = sunAngles(min);
  DN.elev = elev;
  const n = smooth(4, -8, elev); DN.night = n;
  DN.lamps = smooth(7, -1, elev);
  DN.dusk = clamp(1 - Math.abs(elev - 1) / 12, 0, 1);
  dirFrom(elev, az, DN.sunDir);
  SU.sunPosition.value.copy(DN.sunDir);
  // celestial light
  const moonDir = dirFrom(Math.max(18, -elev * 0.9), az + 180, DN.moonDir || (DN.moonDir = new THREE.Vector3()));
  const useMoon = elev < -3;
  const ld = useMoon ? moonDir : DN.sunDir;
  const day = smooth(-3, 10, elev);
  SUN.intensity = useMoon ? 0.42 * n : 3.3 * day;
  if (useMoon) SUN.color.setRGB(0.62, 0.72, 0.95); else { _sunC.setRGB(1.0, 0.56, 0.32).lerp(_tmpC.setRGB(1.0, 0.95, 0.9), smooth(2, 22, elev)); SUN.color.copy(_sunC); }
  // follow the player; snap to shadow texels to stop shimmering
  const tx = Math.round(focus.x / 2) * 2, tz = Math.round(focus.z / 2) * 2;
  SUN.target.position.set(tx, 0, tz);
  SUN.position.set(tx + ld.x * 220, Math.max(30, ld.y * 220), tz + ld.z * 220);
  SUN.target.updateMatrixWorld();
  hemi.color.setRGB(lerp(0.80, 0.36, n), lerp(0.86, 0.46, n), lerp(0.96, 0.68, n));
  hemi.groundColor.setRGB(lerp(0.52, 0.14, n), lerp(0.5, 0.12, n), lerp(0.5, 0.14, n));
  hemi.intensity = lerp(1.15, 0.9, n);
  // fog: snowy haze by day, rose at dusk, deep blue at night
  _tmpC.setRGB(0.64, 0.71, 0.8).lerp(_tmpC2.setRGB(0.62, 0.52, 0.6), DN.dusk * 0.6).lerp(FOG_COL, n);
  scene.fog.color.copy(_tmpC); scene.background.copy(_tmpC);
  scene.fog.density = lerp(0.0056, 0.0145, n);
  renderer.toneMappingExposure = lerp(0.56, 1.12, n);
  skyMesh.material.opacity = n;
  starMat.opacity = n * 0.55;
  cloudMesh.material.color.setRGB(lerp(0.95, 0.32, n), lerp(0.95, 0.3, n), lerp(0.97, 0.34, n)).lerp(_tmpC2.setRGB(1.0, 0.62, 0.45), DN.dusk * (1 - n) * 0.7);
  cloudMesh.material.opacity = lerp(0.8, 0.55, n);
  cloudMesh.rotation.y += dt * 0.0012;
  SKYLINE.night.opacity = n;
  SKYLINE.day.color.copy(scene.fog.color).lerp(_tmpC2.setRGB(0.4, 0.47, 0.56), 0.4);
  SKYLINE.haze.color.copy(scene.fog.color).multiplyScalar(1.2); SKYLINE.haze.opacity = 0.75 * n;
  SKY_BEACONS.mat.size = 6 * (0.3 + n * 0.7);
  // emissives
  MAT.emis.color.setScalar(lerp(0.32, 1, DN.lamps));
  MAT.glowDecal.opacity = 0.55 * DN.lamps;
  if (MAT.halo) MAT.halo.opacity = 0.55 * DN.lamps;
  MAT.shop.color.setScalar(lerp(0.72, 1, n)); MAT.gym.color.setScalar(lerp(0.72, 1, n));
  if (typeof FACADES !== 'undefined') for (const F of FACADES) for (const m of F.mats) m.emissiveIntensity = lerp(0.03, 1.15, n);
  bloomPass.strength = lerp(0.15, 0.62, n); bloomPass.threshold = lerp(1.7, 0.78, n);
  GRADE.uniforms.uLift.value.set(lerp(0.99, 0.93, n), 1.0, lerp(1.03, 1.09, n));
  GRADE.uniforms.uGain.value.set(lerp(1.03, 1.08, n) + DN.dusk * 0.04, 1.0, lerp(0.98, 0.92, n));
  // reflections follow the sky
  DN.envT -= dt;
  if (DN.envT <= 0 || Math.abs(n - DN.lastEnvN) > 0.12) {
    DN.envT = 25; DN.lastEnvN = n;
    envDomeMat.uniforms.hdrMix.value = smooth(0.25, 0.75, n);
    envDomeMat.uniforms.top.value.setRGB(lerp(0.32, 0.015, n), lerp(0.45, 0.025, n), lerp(0.72, 0.05, n));
    envDomeMat.uniforms.hor.value.copy(scene.fog.color).multiplyScalar(lerp(1.1, 1.8, n)).add(_tmpC2.setRGB(0.25, 0.1, 0.02).multiplyScalar(n * 0.6));
    envDomeMat.uniforms.bot.value.setRGB(lerp(0.45, 0.03, n), lerp(0.46, 0.03, n), lerp(0.5, 0.05, n));
    envDomeMat.uniforms.sun.value.copy(DN.sunDir); envDomeMat.uniforms.sunCol.value.copy(SUN.color).multiplyScalar(useMoon ? 0.1 : day * 1.5);
    if (!LITE_MODE) bakeEnv();
  }
}
