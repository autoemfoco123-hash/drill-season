// Exports the web build's content into the Godot project (godot/assets):
//   world/city.glb    every static mesh of the city, split into 128 m chunks (CHUNK=...)
//   cars/<model>.glb  the eight car models (paint, trim, lights, light bar)
//   guns/<id>.glb     the three guns, train/train.glb the L train
//   data.json         map layout, collision boxes, locations, specs, skins, recruit types
//   sfx/*.ogg         the synthesized sound bank, rendered to files
// Needs: npm install (three), Playwright with Chromium, ffmpeg.  Usage: node tools/export-godot.js
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const ROOT = path.resolve(__dirname, '..'), OUT = path.join(ROOT, 'godot', 'assets');
const THREE_DIR = path.join(ROOT, 'node_modules', 'three');
const only = process.argv.slice(2);
const want = k => !only.length || only.includes(k);

function debugPage() {
  const s = fs.readFileSync(path.join(ROOT, 'dist', 'artifact.html'), 'utf8');
  const i = s.lastIndexOf('</script>');
  const page = '<meta charset="utf-8">\n' + s.slice(0, i) + '\nwindow.__DS = { ev: src => eval(src) };\n' + s.slice(i);
  const f = path.join(ROOT, 'build', 'export-page.html');
  fs.mkdirSync(path.dirname(f), { recursive: true }); fs.writeFileSync(f, page);
  return f;
}
const save = (rel, b64) => { const f = path.join(OUT, rel); fs.mkdirSync(path.dirname(f), { recursive: true }); fs.writeFileSync(f, Buffer.from(b64, 'base64')); return f; };

(async () => {
  const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--autoplay-policy=no-user-gesture-required'] });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  page.on('pageerror', e => console.log('PAGEERROR', e.message));
  await page.route(/https:\/\/cdn\.jsdelivr\.net\/npm\/three@0\.160\.0\/(.*)/, r => { const rel = r.request().url().split('three@0.160.0/')[1]; r.fulfill({ path: path.join(THREE_DIR, rel), contentType: 'text/javascript' }); });
  await page.route(/fonts\.(googleapis|gstatic)\.com/, r => r.abort());
  await page.goto('file://' + debugPage());
  await page.waitForFunction(() => window.__DS && window.__DS.ev, null, { timeout: 120000 });
  await page.addScriptTag({ type: 'module', content: "import { GLTFExporter } from 'three/addons/exporters/GLTFExporter.js'; import * as BGU from 'three/addons/utils/BufferGeometryUtils.js'; window.__GLTFExporter = GLTFExporter; window.__BGU = BGU;" });
  await page.waitForFunction(() => window.__GLTFExporter && window.__BGU, null, { timeout: 60000 });
  const ev = s => page.evaluate(src => window.__DS.ev(src), s);
  // helpers inside the page
  await ev(`window.__b64 = buf => { const u = new Uint8Array(buf); let s = ''; for (let i = 0; i < u.length; i += 0x8000) s += String.fromCharCode.apply(null, u.subarray(i, i + 0x8000)); return btoa(s); };
    window.__glb = obj => new Promise((res, rej) => new window.__GLTFExporter().parse(obj, b => res(window.__b64(b)), rej, { binary: true, onlyVisible: false }));
    0`);

  if (want('world')) {
    const b64 = await ev(`(async () => {
      for (const k in MAT) MAT[k].name = k;
      FACADES.forEach(F => F.mats.forEach((m, i) => { m.name = 'facade_' + F.style + '_' + i; }));
      const BGU = window.__BGU, root = new THREE.Scene(), CH = ${+(process.env.CHUNK || 128)};
      const skip = new Set(TRAINS.map(T => T.mesh));
      let n = 0, tris = 0, unnamed = 0;
      const addChunked = (geo0, mat, name) => {
        let geo = geo0.index ? geo0.toNonIndexed() : geo0.clone();
        for (const an of Object.keys(geo.attributes)) if (!['position', 'normal', 'uv', 'color'].includes(an)) geo.deleteAttribute(an);
        const pos = geo.attributes.position, nt = pos.count / 3, buckets = new Map();
        for (let t = 0; t < nt; t++) {
          const cx = (pos.getX(t * 3) + pos.getX(t * 3 + 1) + pos.getX(t * 3 + 2)) / 3, cz = (pos.getZ(t * 3) + pos.getZ(t * 3 + 1) + pos.getZ(t * 3 + 2)) / 3;
          const key = Math.floor(cx / CH) + '_' + Math.floor(cz / CH);
          let b = buckets.get(key); if (!b) buckets.set(key, b = []); b.push(t);
        }
        for (const [key, list] of buckets) {
          const g = new THREE.BufferGeometry();
          for (const an of Object.keys(geo.attributes)) {
            const a = geo.attributes[an], isz = a.itemSize, arr = new Float32Array(list.length * 3 * isz); let o = 0;
            for (const t of list) for (let v = 0; v < 3; v++) for (let c = 0; c < isz; c++) arr[o++] = a.getComponent ? a.getComponent(t * 3 + v, c) : a.array[(t * 3 + v) * isz + c];
            g.setAttribute(an, new THREE.BufferAttribute(arr, isz));
          }
          const gi = BGU.mergeVertices(g, 1e-4);
          const m = new THREE.Mesh(gi, mat); m.name = name + '@' + key; root.add(m); n++; tris += list.length;
        }
      };
      for (const o of [...scene.children]) {
        if (!o.isMesh || o.isInstancedMesh || skip.has(o) || !o.geometry || !o.geometry.attributes.position) continue;
        const mat = Array.isArray(o.material) ? o.material[0] : o.material;
        if (!mat || mat.isShaderMaterial || mat.isPointsMaterial || o.visible === false) continue;
        if (!mat.name) mat.name = 'mat_' + (++unnamed);
        o.updateMatrixWorld(true);
        const g = o.geometry.clone(); g.applyMatrix4(o.matrixWorld);
        g.computeBoundingSphere();
        if (g.boundingSphere.radius > 900) continue;   // the sky dome: Godot draws its own sky
        addChunked(g, mat, mat.name);
      }
      window.__worldInfo = { meshes: n, tris };
      return window.__glb(root);
    })()`);
    const f = save('world/city.glb', b64);
    console.log('world', JSON.stringify(await ev('window.__worldInfo')), (fs.statSync(f).size / 1048576).toFixed(1) + ' MB');
  }

  if (want('cars')) {
    for (const model of await ev('JSON.stringify(CAR_MODELS)').then(JSON.parse)) {
      const b64 = await ev(`(() => {
        const M = CARMESH['${model}'], g = new THREE.Group();
        const mk = (geo, mat, name) => { if (!geo) return; const m = new THREE.Mesh(geo.geometry || geo, mat); m.name = name; g.add(m); };
        mk(M.paint.geometry, Object.assign(new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.35, metalness: 0.4 }), { name: 'car_paint' }), 'paint');
        mk(M.trim.geometry, Object.assign(new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.5, metalness: 0.2 }), { name: 'car_trim' }), 'trim');
        mk(M.emis.geometry, Object.assign(new THREE.MeshBasicMaterial({ vertexColors: true }), { name: 'car_lights' }), 'lights');
        if (M.bar) mk(M.bar.geometry, Object.assign(new THREE.MeshBasicMaterial({ vertexColors: true }), { name: 'car_bar' }), 'bar');
        return window.__glb(g);
      })()`);
      save('cars/' + model + '.glb', b64);
    }
    console.log('cars done');
  }

  if (want('guns')) {
    for (const id of ['k9', 'draft', 'plow']) {
      const b64 = await ev(`(() => { const gun = buildGun('${id}', DEF_CFG()); gun.traverse(o => { if (o.material && !o.material.name) o.material.name = 'gun_' + (o.material.color ? o.material.color.getHexString() : 'x'); }); return window.__glb(gun); })()`);
      save('guns/' + id + '.glb', b64);
    }
    const tb = await ev(`(() => { const m = TRAINS[0].mesh.clone(); m.position.set(0, 0, 0); m.rotation.set(0, 0, 0); m.visible = true; m.traverse(o => { o.visible = true; if (o.material && !o.material.name) o.material.name = 'train_' + (o.material.color ? o.material.color.getHexString() : 'x'); }); return window.__glb(m); })()`);
    save('train/train.glb', tb);
    console.log('guns and train done');
  }

  if (want('data')) {
    const data = await ev(`JSON.stringify({
      MAP_HALF, XL, ZL, XN, ZN, ROAD_HW, WALK_EDGE, ROAD_X_END, LAKE_X, SHORE_X, LX, DECK_Y0, DECK_Y, PLAT_Y, DECK_X0, DECK_X1, TRACKS, STEP_UP, GRAV, LANE,
      LOC, POND, CAST,
      BOXES: BOXES.map(b => [+b.x0.toFixed(3), +b.y0.toFixed(3), +b.z0.toFixed(3), +b.x1.toFixed(3), +b.y1.toFixed(3), +b.z1.toFixed(3), b.tag || '']),
      LAMPS: LAMPS.map(l => [l.x, l.y === undefined ? 5.2 : l.y, l.z]), BARRELS: BARRELS.map(b => [b.x, b.z]), VENTS: VENTS.map(v => [v.x, v.z]),
      HEATERS: HEATERS.map(h => [h.x, h.y || 0, h.z]), PARK_SPOTS, NAV: NAV.map(n => [n.x, n.z, n.n]),
      CAR_SPECS: Object.fromEntries(Object.entries(CAR_SPECS).map(([k, s]) => [k, { name: s.name, len: s.len, wid: s.wid, r: s.r, wb: s.wb, acc: s.acc, top: s.top, price: s.price || 0, buzz: s.buzz || 0, roofY: s.roofY, wbLen: s.wbLen, police: !!s.police, taxi: !!s.taxi, van: !!s.van }])),
      CAR_MODELS, CIVIL_MODELS, CAR_PAINTS, WEAPONS,
      SKIN: { SKIN_TONES, SWATCHES, HAIR_COLS, SKIN_OPTS, SKIN_FIELDS, PRESETS, LABELS: SKIN_LABELS },
      RTYPES, GANG_COLORS, STATIONS: STATIONS.map(s => ({ name: s.name, short: s.short })),
      INTERACT: INTERACT.map(it => ({ id: it.id, x: it.x, y: it.y || 0, z: it.z, r: it.r })),
      ETYPES: Object.fromEntries(Object.entries(ETYPES).map(([k, t]) => [k, { hp: t.hp, speed: t.speed, gun: t.gun, rate: t.rate, burst: t.burst, dmg: t.dmg, acc: t.acc, jacket: t.jacket, jacket2: t.jacket2 }])),
    })`);
    fs.mkdirSync(OUT, { recursive: true });
    fs.writeFileSync(path.join(OUT, 'data.json'), data);
    console.log('data.json', (data.length / 1024).toFixed(0) + ' KB');
  }

  if (want('sfx')) {
    await ev(`initAudio(); 0`);
    await page.waitForFunction(() => window.__DS.ev('AU.bankReady === true'), null, { timeout: 180000 });
    const names = JSON.parse(await ev(`JSON.stringify(Object.keys(AU.bank))`));
    const tmp = path.join(ROOT, 'build', 'wav'); fs.mkdirSync(tmp, { recursive: true });
    let count = 0;
    for (const name of names) {
      const list = JSON.parse(await ev(`(() => {
        const v = AU.bank['${name}'], arr = (Array.isArray(v) ? v : [v]).slice(0, 3);
        return JSON.stringify(arr.map(buf => {
          const ch = Math.min(2, buf.numberOfChannels), n = buf.length, sr = buf.sampleRate, dv = new DataView(new ArrayBuffer(44 + n * ch * 2));
          const ws = (o, s) => { for (let i = 0; i < s.length; i++) dv.setUint8(o + i, s.charCodeAt(i)); };
          ws(0, 'RIFF'); dv.setUint32(4, 36 + n * ch * 2, true); ws(8, 'WAVE'); ws(12, 'fmt '); dv.setUint32(16, 16, true); dv.setUint16(20, 1, true); dv.setUint16(22, ch, true);
          dv.setUint32(24, sr, true); dv.setUint32(28, sr * ch * 2, true); dv.setUint16(32, ch * 2, true); dv.setUint16(34, 16, true); ws(36, 'data'); dv.setUint32(40, n * ch * 2, true);
          const d = []; for (let c = 0; c < ch; c++) d.push(buf.getChannelData(c));
          let o = 44; for (let i = 0; i < n; i++) for (let c = 0; c < ch; c++) { const s = Math.max(-1, Math.min(1, d[c][i])); dv.setInt16(o, s < 0 ? s * 32768 : s * 32767, true); o += 2; }
          return window.__b64(dv.buffer);
        }));
      })()`));
      list.forEach((b64, i) => {
        const wav = path.join(tmp, name + (list.length > 1 ? '_' + i : '') + '.wav');
        fs.writeFileSync(wav, Buffer.from(b64, 'base64'));
        const ogg = path.join(OUT, 'sfx', path.basename(wav).replace(/\.wav$/, '.ogg'));
        fs.mkdirSync(path.dirname(ogg), { recursive: true });
        execFileSync('ffmpeg', ['-y', '-loglevel', 'error', '-i', wav, '-c:a', 'libvorbis', '-q:a', '5', ogg]);
        count++;
      });
    }
    console.log('sfx files', count);
  }
  await browser.close();
})();
