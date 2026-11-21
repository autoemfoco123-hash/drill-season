
/* =========================================================
   REAL-WORLD ASSETS - CC0 photo textures and HDR skies from
   Poly Haven (polyhaven.com), loaded after start-up and swapped
   into the procedural materials. Opened from disk, the game keeps
   its procedural look. Credits: assets/CREDITS.md
   ========================================================= */
const REAL = { on: false, sets: {}, aniso: 1 };
const _TL = new THREE.TextureLoader();
function realTex(path, srgb, rep) {
  return new Promise(res => _TL.load('assets/' + path, t => {
    t.wrapS = t.wrapT = THREE.RepeatWrapping; t.anisotropy = REAL.aniso;
    if (srgb) t.colorSpace = THREE.SRGBColorSpace;
    if (rep) t.repeat.set(rep, rep);
    res(t);
  }, undefined, () => res(null)));
}
function rgbeTex(path) {
  return new Promise(res => _TL.load('assets/' + path, t => {
    t.magFilter = t.minFilter = THREE.NearestFilter; t.generateMipmaps = false; res(t);
  }, undefined, () => res(null)));
}
// facade materials keep their window layout; photo detail goes on the wall only
function facadeDetail(mat, set, mask) {
  mat.normalMap = set.nor; mat.normalScale.set(1.15, 1.15);
  mat.roughnessMap = set.rough; mat.roughness = 1;
  mat.envMapIntensity = 0.7;
  mat.onBeforeCompile = sh => {
    sh.uniforms.detailMap = { value: set.detail }; sh.uniforms.wallMask = { value: mask }; sh.uniforms.detailRep = { value: set.rep };
    sh.fragmentShader = sh.fragmentShader
      .replace('#include <common>', '#include <common>\nuniform sampler2D detailMap; uniform sampler2D wallMask; uniform float detailRep;')
      .replace('#include <map_fragment>', '#include <map_fragment>\nfloat wm = texture2D(wallMask, vMapUv).r;\ndiffuseColor.rgb *= mix(1.0, texture2D(detailMap, vMapUv * detailRep).r * 2.0, wm);')
      .replace('#include <roughnessmap_fragment>', '#include <roughnessmap_fragment>\nroughnessFactor = mix(0.12, roughnessFactor * 0.95, wm);')
      .replace('#include <normal_fragment_maps>', '#include <normal_fragment_maps>\nnormal = normalize(mix(nonPerturbedNormal, normal, wm));');
  };
  mat.needsUpdate = true;
}
// ground surfaces: the photo is the micro detail, the old canvas keeps the macro layout (lanes, tracks, drifts)
function groundDetail(mat, set, macro, mean) {
  mat.map = set.diff; mat.normalMap = set.nor; mat.roughnessMap = set.rough; mat.roughness = 1;
  mat.onBeforeCompile = sh => {
    sh.uniforms.macroMap = { value: macro }; sh.uniforms.macroMean = { value: mean }; sh.uniforms.macroRep = { value: set.rep };
    sh.fragmentShader = sh.fragmentShader
      .replace('#include <common>', '#include <common>\nuniform sampler2D macroMap; uniform vec3 macroMean; uniform float macroRep;')
      .replace('#include <map_fragment>', '#include <map_fragment>\ndiffuseColor.rgb *= clamp(texture2D(macroMap, vMapUv / macroRep).rgb / macroMean, 0.0, 2.2);');
  };
  mat.needsUpdate = true;
}
function canvasMean(tex) {
  const c = tex.image, g = c.getContext && c.getContext('2d'); if (!g) return new THREE.Vector3(0.5, 0.5, 0.5);
  const d = g.getImageData(0, 0, c.width, c.height).data; let r = 0, gg = 0, b = 0, n = 0;
  for (let i = 0; i < d.length; i += 16) { r += d[i]; gg += d[i + 1]; b += d[i + 2]; n++; }
  const lin = v => Math.pow(v / n / 255, 2.2);
  return new THREE.Vector3(lin(r), lin(gg), lin(b));
}
async function loadRealism() {
  if (location.protocol === 'file:') return;
  REAL.aniso = Math.min(8, renderer.capabilities.getMaxAnisotropy());
  const lite = LOW_POWER || S.settings.quality === 'low';
  const set = async (name, rep, color) => {
    const [diff, nor, rough] = await Promise.all([realTex(`tex/${name}_${color ? 'diff' : 'detail'}.jpg`, color, color ? rep : 0), realTex(`tex/${name}_nor.jpg`, false, rep), realTex(`tex/${name}_rough.jpg`, false, rep)]);
    if (!(diff && nor && rough)) return null;
    return color ? { diff, nor, rough, rep } : { detail: diff, nor, rough, rep };
  };
  const [brick, blocks, planks, metal, snow, road, walk, day, night] = await Promise.all([
    set('red_brick_03', 10), set('medieval_blocks_03', 6), set('weathered_brown_planks', 7), set('corrugated_iron', 6),
    set('snow_02', 4.7, true), set('asphalt_snow', 4, true), set('scuffed_cement', 2, true),
    rgbeTex('hdri/urban_street_01.png'), rgbeTex('hdri/cobblestone_street_night.png'),
  ]);
  const byStyle = { brick, brown: brick, cream: brick, grey: blocks, siding: planks, ware: metal };
  for (const F of FACADES) { const st = byStyle[F.style]; if (!st) continue; for (const m of F.mats) facadeDetail(m, st, m.userData.mask); }
  if (snow) groundDetail(MAT.ground, snow, TEX.snow, canvasMean(TEX.snow));
  if (road) groundDetail(MAT.road, road, TEX.road, canvasMean(TEX.road));
  if (walk) groundDetail(MAT.walk, walk, TEX.walk, canvasMean(TEX.walk));
  if (day && night) {
    const U = envDomeMat.uniforms;
    U.hdrDay.value = day; U.hdrNight.value = night; U.hdrAmt.value = lite ? 0.7 : 0.85;
    U.dayNorm.value = 0.486; U.nightNorm.value = 0.778;
    DN.envT = 0;
  }
  REAL.on = true;
  loadProps().catch(e => console.warn('props', e));
}
/* ---- scanned props (CC0, Poly Haven), drawn instanced ---- */
const _gl = new GLTFLoader();
// models are stored as glTF JSON (buffer in base64) + JPEG textures, served as plain data files;
// the buffer is packed back into a GLB here so the loader never has to fetch a data: URL
function packGLB(json) {
  const b64 = json.buffers[0].uri.split(',')[1]; delete json.buffers[0].uri;
  const bs = atob(b64), bin = new Uint8Array(bs.length); for (let i = 0; i < bs.length; i++) bin[i] = bs.charCodeAt(i);
  const js = new TextEncoder().encode(JSON.stringify(json)), jl = (js.length + 3) & ~3, bl = (bin.length + 3) & ~3, total = 28 + jl + bl;
  const buf = new ArrayBuffer(total), dv = new DataView(buf), u8 = new Uint8Array(buf);
  dv.setUint32(0, 0x46546C67, true); dv.setUint32(4, 2, true); dv.setUint32(8, total, true);
  dv.setUint32(12, jl, true); dv.setUint32(16, 0x4E4F534A, true); u8.set(js, 20); u8.fill(0x20, 20 + js.length, 20 + jl);
  dv.setUint32(20 + jl, bl, true); dv.setUint32(24 + jl, 0x004E4942, true); u8.set(bin, 28 + jl);
  return buf;
}
const loadModel = n => fetch('assets/models/' + n + '.json').then(r => r.ok ? r.json() : null)
  .then(j => j && new Promise(res => _gl.parse(packGLB(j), 'assets/models/', g => res(g), () => res(null))))
  .catch(() => null);
const _pm = new THREE.Matrix4(), _pq = new THREE.Quaternion(), _pv = new THREE.Vector3(), _ps = new THREE.Vector3(), _pUp = new THREE.Vector3(0, 1, 0);
// place copies of a model; each placement is { x, y, z, ry, s } and the model's base sits on y
function instanceModel(g, list, o) {
  if (!g || !list.length) return [];
  o = o || {};
  const root = g.scene; root.updateMatrixWorld(true);
  const box = new THREE.Box3().setFromObject(root), c = box.getCenter(new THREE.Vector3());
  const fix = new THREE.Matrix4().makeTranslation(-c.x, -box.min.y, -c.z);
  const out = [];
  root.traverse(m => {
    if (!m.isMesh) return;
    const local = new THREE.Matrix4().multiplyMatrices(fix, m.matrixWorld);
    const mats = Array.isArray(m.material) ? m.material : [m.material];
    for (const mt of mats) { mt.envMapIntensity = o.env || 0.9; if (o.tint) mt.color.multiply(o.tint); }
    const im = new THREE.InstancedMesh(m.geometry, m.material, list.length);
    list.forEach((p, i) => { _pq.setFromAxisAngle(_pUp, p.ry || 0); _ps.setScalar(p.s || 1); if (p.sv) _ps.copy(p.sv); _pm.compose(_pv.set(p.x, p.y || 0, p.z), _pq, _ps); im.setMatrixAt(i, _pm.multiply(local)); });
    im.instanceMatrix.needsUpdate = true; im.castShadow = o.shadow !== false; im.receiveShadow = true;
    im.computeBoundingSphere(); scene.add(im); out.push(im);
  });
  return { meshes: out, size: box.getSize(new THREE.Vector3()) };
}
const PROP_SPOTS = { hydrants: [], bins: [], bags: [] };
function planProps() {
  const R = rng(2024), free = (x, z, r) => !queryBoxes(x - r, z - r, x + r, z + r, []).some(b => b.x0 < x + r && b.x1 > x - r && b.z0 < z + r && b.z1 > z - r && b.y1 > 0.1);
  // hydrants on the curb near corners and mid-block
  for (const xc of XL) for (let z = -(MAP_HALF - 20); z < MAP_HALF - 20; z += 46) {
    if (ZL.some(l => Math.abs(z - l) < 12) || xc === LX) continue;
    const side = R() < 0.5 ? -1 : 1, x = xc + side * 7.0;
    if (free(x, z, 0.6)) PROP_SPOTS.hydrants.push({ x, z, ry: side > 0 ? Math.PI / 2 : -Math.PI / 2 });
  }
  for (const zc of ZL) for (let x = -(MAP_HALF - 20); x < SHORE_X - 14; x += 52) {
    if (XL.some(l => Math.abs(x - l) < 12)) continue;
    const side = R() < 0.5 ? -1 : 1, z = zc + side * 7.0;
    if (free(x, z, 0.6)) PROP_SPOTS.hydrants.push({ x, z, ry: side > 0 ? 0 : Math.PI });
  }
  // bag piles and bin rows by the dumpsters in the alleys
  for (const d of DUMPSTERS) {
    const n = 2 + Math.floor(R() * 3);
    for (let k = 0; k < n; k++) { const x = d.x + (d.alongX ? (R() - 0.5) * 3 + 1.6 * (k % 2 ? 1 : -1) : (R() - 0.5) * 1.2), z = d.z + (d.alongX ? (R() - 0.5) * 1.2 : (R() - 0.5) * 3); if (free(x, z, 0.25)) PROP_SPOTS.bags.push({ x, z, ry: R() * TAU, s: 0.8 + R() * 0.35 }); }
    if (R() < 0.45) { const x = d.x + (d.alongX ? 2.8 : 0), z = d.z + (d.alongX ? 0 : 2.8); if (free(x, z, 0.9)) PROP_SPOTS.bins.push({ x, z, ry: d.alongX ? 0 : Math.PI / 2 }); }
  }
}
async function loadProps() {
  planProps();
  const [barrel, hydrant, bins, jersey, manhole, bag] = await Promise.all(['Barrel_02', 'fire_hydrant', 'metal_trash_can', 'concrete_road_barrier', 'water_manhole_cover', 'trashbag'].map(loadModel));
  if (barrel) {
    const r = instanceModel(barrel, BARRELS.map(b => ({ x: b.x, z: b.z, ry: (b.x * 13.7 + b.z) % TAU, s: 1.08 })), { env: 0.8, tint: new THREE.Color(0.75, 0.62, 0.55) });
    if (r.meshes) {
      FALLBACK.barrel.visible = false; FALLBACK.barrelFire.visible = false;
      const fire = new Batch(); for (const b of BARRELS) vcyl(fire, b.x, r.size.y * 1.08 - 0.06, b.z, 0.26, 0.04, 0xff7a2a); fire.mesh(MAT.emis, false, false);
    }
  }
  if (jersey) {
    const list = [];
    for (const b of BARRIERS) { const n = Math.max(1, Math.round(b.len / 1.5)), step = b.len / n; for (let k = 0; k < n; k++) { const off = -b.len / 2 + step * (k + 0.5); list.push({ x: b.x + (b.alongX ? off : 0), z: b.z + (b.alongX ? 0 : off), ry: b.alongX ? 0 : Math.PI / 2, s: 1.15 }); } }
    if (instanceModel(jersey, list, { env: 0.6 }).meshes) FALLBACK.barrier.visible = false;
  }
  if (manhole && instanceModel(manhole, VENTS.map(v => ({ x: v.x, y: 0.005, z: v.z, ry: v.t, s: 1.6 })), { shadow: false, env: 0.8 }).meshes) FALLBACK.vent.visible = false;
  if (hydrant && instanceModel(hydrant, PROP_SPOTS.hydrants, { env: 0.9 }).meshes) for (const h of PROP_SPOTS.hydrants) addCol(h.x - 0.22, 0, h.z - 0.22, h.x + 0.22, 0.85, h.z + 0.22, 'cover');
  if (bag) instanceModel(bag, PROP_SPOTS.bags, { env: 0.7 });
  if (bins && instanceModel(bins, PROP_SPOTS.bins, { env: 0.8 }).meshes) for (const b of PROP_SPOTS.bins) { const ax = b.ry === 0; addCol(b.x - (ax ? 0.95 : 0.3), 0, b.z - (ax ? 0.3 : 0.95), b.x + (ax ? 0.95 : 0.3), 0.92, b.z + (ax ? 0.3 : 0.95), 'cover'); }
  REAL.props = true;
}
