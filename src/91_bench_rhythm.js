/* =========================================================
   WORKBENCH (rotating 3D preview)
   ========================================================= */
const BENCH = { gun: 'k9', r: null, scene: null, cam: null, model: null, rotY: 0.6, drag: null, key: '' };
function openBench() {
  $('menu').hidden = true; MODE = 'bench'; $('bench').hidden = false;
  BENCH.gun = S.cur;
  if (!BENCH.r) {
    BENCH.r = new THREE.WebGLRenderer({ antialias: true, alpha: true });
    BENCH.r.setPixelRatio(Math.min(devicePixelRatio || 1, 2)); BENCH.r.toneMapping = THREE.ACESFilmicToneMapping; BENCH.r.toneMappingExposure = 1.1;
    $('bn-view').append(BENCH.r.domElement);
    BENCH.scene = new THREE.Scene(); BENCH.scene.environment = ENV;
    BENCH.cam = new THREE.PerspectiveCamera(30, 1, 0.01, 20); BENCH.cam.position.set(0, 0.14, 1.25); BENCH.cam.lookAt(0, 0.02, 0);
    const k = new THREE.DirectionalLight(0xffc08a, 3.2); k.position.set(1, 1.2, 1); BENCH.scene.add(k);
    const fill = new THREE.DirectionalLight(0xdfe8ff, 1.6); fill.position.set(-0.4, 0.3, 1.5); BENCH.scene.add(fill);
    const rim = new THREE.DirectionalLight(0x7ac0ff, 2.0); rim.position.set(-1.2, 0.6, -1); BENCH.scene.add(rim);
    BENCH.scene.add(new THREE.HemisphereLight(0xa8c4ec, 0x2a2018, 1.4));
    const v = $('bn-view');
    v.addEventListener('pointerdown', e => { BENCH.drag = e.clientX; v.setPointerCapture(e.pointerId); });
    v.addEventListener('pointermove', e => { if (BENCH.drag !== null) { BENCH.rotY += (e.clientX - BENCH.drag) * 0.01; BENCH.drag = e.clientX; } });
    v.addEventListener('pointerup', () => BENCH.drag = null);
  }
  renderBench();
}
function closeBench() { $('bench').hidden = true; MODE = 'menu'; $('menu').hidden = false; renderMenu(); }
function benchOwnsPart(gid, cat, id) { if (cat === 'finish' || cat === 'charm') return S.cos.includes(cat + ':' + id); return S.parts[gid].includes(cat + ':' + id); }
function renderBench() {
  const gid = BENCH.gun, W = WEAPONS[gid], G = S.guns[gid];
  $('bn-gun').textContent = W.name; $('bn-cls').textContent = W.cls;
  $('bn-cash').textContent = fmtMoney(S.cash) + ' · Buzz ' + Math.round(S.buzz);
  $('bn-tabs').innerHTML = ['k9', 'draft', 'plow'].map(id => `<button data-g="${id}" class="${id === gid ? 'on' : ''}">${WEAPONS[id].short}<small>${S.guns[id].owned ? (S.cur === id ? 'equipped' : 'owned') : fmtMoney(WEAPONS[id].price) + ' · Buzz ' + WEAPONS[id].buzz}</small></button>`).join('');
  $('bn-tabs').querySelectorAll('button').forEach(b => b.onclick = () => { BENCH.gun = b.dataset.g; $('bn-msg').textContent = ''; renderBench(); });
  const parts = $('bn-parts'); parts.innerHTML = '';
  if (!G.owned) {
    const can = S.cash >= W.price && S.buzz >= W.buzz;
    parts.innerHTML = `<div class="unlock"><div class="eyebrow">Locked</div><p>${esc(W.cls)}. Unlocks with ${fmtMoney(W.price)} and Buzz ${W.buzz}.</p><button class="btn primary" id="bn-buy" ${can ? '' : 'disabled'}>Unlock ${esc(W.short)}</button></div>`;
    $('bn-buy').onclick = () => { if (S.cash >= W.price && S.buzz >= W.buzz) { addCash(-W.price); G.owned = true; G.mag = W.mag; switchWeapon(gid); $('bn-msg').textContent = W.short + ' unlocked and equipped.'; saveGame(); renderBench(); } };
  } else {
    const cats = [['optic', 'Optic'], ['barrel', 'Barrel'], ['mag', 'Mag'], ['muzzle', 'Muzzle'], ['finish', 'Finish'], ['charm', 'Charm']];
    for (const [cat, label] of cats) {
      const sec = document.createElement('div'); sec.className = 'pc2';
      sec.innerHTML = `<h3>${label}</h3><div class="pc-row"></div>`;
      const row = sec.querySelector('.pc-row');
      for (const p of PARTS[cat]) {
        const own = benchOwnsPart(gid, cat, p.id), on = G.cfg[cat] === p.id;
        const lockB = p.buzz && S.buzz < p.buzz;
        const b = document.createElement('button'); b.className = 'pt' + (on ? ' on' : '') + (!own && (lockB || S.cash < p.price) ? ' lock' : '');
        const sw = cat === 'finish' ? `<span class="sw" style="background:#${new THREE.Color(p.c).getHexString()}"></span>` : '';
        b.innerHTML = `${sw}${esc(p.name)}<small>${on ? 'equipped' : own ? 'owned' : lockB ? 'Buzz ' + p.buzz : fmtMoney(p.price)}${p.note ? ' · ' + esc(p.note) : ''}</small>`;
        b.onclick = () => {
          if (!own) {
            if (lockB) { $('bn-msg').textContent = `Needs Buzz ${p.buzz}.`; return; }
            if (S.cash < p.price) { $('bn-msg').textContent = 'Not enough cash.'; return; }
            addCash(-p.price); if (cat === 'finish' || cat === 'charm') S.cos.push(cat + ':' + p.id); else S.parts[gid].push(cat + ':' + p.id);
          }
          G.cfg[cat] = p.id;
          if (cat === 'mag') { const st = gunStats(gid); G.res += Math.max(0, G.mag - st.mag); G.mag = Math.min(G.mag, st.mag); }
          if (gid === S.cur) { P.gunKey = ''; refreshPlayerGun(); }
          $('bn-msg').textContent = `${p.name} on the ${W.short}.`; sfx.reload(); renderBench();
        };
        row.append(b);
      }
      parts.append(sec);
    }
    if (S.cur !== gid) { const eq = document.createElement('button'); eq.className = 'btn'; eq.textContent = 'Equip ' + W.short; eq.onclick = () => { switchWeapon(gid); renderBench(); }; parts.append(eq); }
  }
  // stats
  const st = gunStats(gid), base = gunStats(gid, DEF_CFG());
  const rows = [
    ['Damage', st.dmg * st.pellets, base.dmg * base.pellets, 110, v => Math.round(v)],
    ['Accuracy', 10 / st.aimSpread, 10 / base.aimSpread, 25, v => Math.round(v * 4)],
    ['Range', st.range, base.range, 70, v => Math.round(v) + 'm'],
    ['Mag', st.mag, base.mag, 50, v => v],
    ['Reload', 1 / st.reload, 1 / base.reload, 1.2, v => (1 / v).toFixed(1) + 's'],
    ['Control', 1 / st.recoil, 1 / base.recoil, 2.2, v => Math.round(v * 45)],
    ['Zoom', st.zoom, base.zoom, 2.2, v => v.toFixed(2) + 'x'],
    ['Heat/shot', st.heatPerShot, base.heatPerShot, 2.2, v => v.toFixed(2)],
  ];
  $('bn-stats').innerHTML = rows.map(([n, v, b, mx, f]) => {
    const worse = n === 'Heat/shot' ? v > b + 1e-6 : v < b - 1e-6, better = n === 'Heat/shot' ? v < b - 1e-6 : v > b + 1e-6;
    return `<div class="st"><span>${n}</span><div class="bar"><i class="${better ? 'up' : worse ? 'dn' : ''}" style="width:${clamp(v / mx * 100, 3, 100)}%"></i></div><b>${f(v)}</b></div>`;
  }).join('');
  const key = gid + JSON.stringify(G.cfg);
  if (key !== BENCH.key) {
    if (BENCH.model) BENCH.scene.remove(BENCH.model);
    const gun = buildGun(gid, G.cfg);
    const box = new THREE.Box3().setFromObject(gun), c = box.getCenter(new THREE.Vector3()), size = box.getSize(new THREE.Vector3());
    const holder = new THREE.Group(); gun.position.sub(c); holder.add(gun);
    holder.scale.setScalar(0.62 / Math.max(size.x, size.y, size.z));
    gun.rotation.y = 0; holder.userData.gun = gun;
    BENCH.model = holder; BENCH.scene.add(holder); BENCH.key = key;
  }
}
function drawBench(dt) {
  if (!BENCH.r || $('bench').hidden) return;
  const v = $('bn-view'), w = v.clientWidth, h = v.clientHeight;
  if (w < 2 || h < 2) return;
  const cv = BENCH.r.domElement;
  if (cv.width !== Math.floor(w * BENCH.r.getPixelRatio()) || cv.height !== Math.floor(h * BENCH.r.getPixelRatio())) { BENCH.r.setSize(w, h, false); BENCH.cam.aspect = w / h; BENCH.cam.updateProjectionMatrix(); }
  if (BENCH.drag === null) BENCH.rotY += dt * 0.45;
  if (BENCH.model) { BENCH.model.rotation.y = BENCH.rotY + Math.PI / 2; BENCH.model.rotation.x = Math.sin(REAL_T * 0.6) * 0.06; const ch = BENCH.model.userData.gun.userData.charm; if (ch) ch.rotation.z = Math.sin(REAL_T * 3) * 0.3; }
  BENCH.r.render(BENCH.scene, BENCH.cam);
}
$('bn-close').onclick = () => closeBench();

/* =========================================================
   STUDIO RHYTHM GAME (D F J K)
   ========================================================= */
const RH = { on: false, beat: null, B: null, t0: 0, notes: [], type: null, opts: null, combo: 0, maxCombo: 0, pts: 0, counts: null, flash: [0, 0, 0, 0], judge: null, title: '', ended: false, clock0: 0 };
const VERSES = {
  tribute: { name: 'Tribute', desc: 'For the block and the people in it. Calm chart.', chips: [['b', 'Buzz +'], ['h', 'Heat −4'], ['c', '$']] },
  wayout: { name: 'Way out', desc: 'About getting out of the cold. Medium chart.', chips: [['b', 'Buzz ++'], ['c', '$$']] },
  diss: { name: 'Diss', desc: () => `Aimed at ${CAST.saint.name}. Hard chart.${S.flags.vanceOffer ? ` ${CAST.vance.name} pays ${fmtMoney(vancePay())}.` : ''}`, chips: [['b', 'Buzz +++'], ['h', 'Heat ++'], ['c', '$$$']] },
};
const TITLE_WORDS = {
  tribute: { fixed: ['For Sis', 'Rec Center Lights', 'Bishop St Prayer', "Grandma's Porch Light", 'Lake Effect', 'Warm Hands', 'Calder Park Days', 'Coat Drive', 'Sodium Glow', 'Front Stoop', 'Radiator Season'], a: ['Cold', 'Warm', 'Late', 'Long', 'Quiet', 'Golden', 'Frozen'], b: ['Nights', 'Prayers', 'Blocks', 'Winters', 'Mornings', 'Porches'] },
  wayout: { fixed: ['One Way Out', 'Loop Dreams', 'Skyline', 'Out the Cold', 'Last Stop', 'Northbound', 'Ticket Out', 'Big Shoulders', 'Above the L', 'Platform 2'], a: ['North', 'Higher', 'Far', 'Gone', 'Clear', 'Bright'], b: ['Lights', 'Lanes', 'Tracks', 'Views', 'Floors', 'Signals'] },
  diss: { fixed: ['No Halo', 'Fallen Saint', 'Saint Who?', 'Halo Slipping', 'Cold Shoulder', 'Snow Job', 'Black Ice', 'Thin Ice', 'Frostbite', 'Wind Chill', 'Hawk Talk', 'Melted Crown'], a: ['Thin', 'Black', 'Broke', 'Cracked', 'Fake', 'Dim'], b: ['Halo', 'Saints', 'Crowns', 'Ice', 'Smoke', 'Wings'] },
};
function genTitle(type) {
  const T = TITLE_WORDS[type];
  const used = new Set(S.tracks.map(t => t.title));
  for (let i = 0; i < 20; i++) {
    let t = Math.random() < 0.6 ? pick(T.fixed) : pick(T.a) + ' ' + pick(T.b);
    if (Math.random() < 0.18) t += pick([' (Freestyle)', ' Pt. 2', ' (Calder Mix)', ' (Intro)']);
    if (!used.has(t)) return t;
  }
  return pick(T.fixed) + ' Pt. ' + (S.tracks.length + 2);
}
const STYLES = { chi: { name: 'Chicago', note: '140 · sliding 808s' }, uk: { name: 'UK', note: '142 · swung hats' }, ny: { name: 'NY', note: '144 · bounce + strings' } };
let VS = { type: 'tribute', style: 'chi' };
function openVerseSelect() {
  closeMenu(true); MODE = 'rhythm';
  $('rhythm').hidden = false; $('hud').hidden = true;
  RH.on = false; RH.beat = null; resizeRhythm();
  RH.select = true;
  renderVerseSelect();
}
function renderVerseSelect() {
  const ui = $('rh-ui');
  ui.innerHTML = `<div class="card"><div class="eyebrow">Basement 808 · the booth</div><h2>Pick the verse</h2><p>The beat is ${esc(CAST.benny.name)}'s. Hit <kbd>D</kbd> <kbd>F</kbd> <kbd>J</kbd> <kbd>K</kbd> as notes cross the line. Accuracy and verse decide Buzz, Heat and cash.</p><div class="eyebrow" style="color:var(--ink-3)">Beat</div><div class="seg">${Object.entries(STYLES).map(([k, s]) => `<button data-st="${k}" class="${VS.style === k ? 'on' : ''}">${s.name} drill<small>${s.note}</small></button>`).join('')}</div><div class="eyebrow" style="color:var(--ink-3);margin-bottom:6px">Verse</div><div class="verse"></div><div class="c-foot"><span>1-3 pick · Esc to step out</span></div></div>`;
  const box = ui.querySelector('.verse');
  Object.entries(VERSES).forEach(([k, v], i) => {
    const b = document.createElement('button'); b.className = 'opt';
    b.innerHTML = `<span class="k">${i + 1}</span><span class="ol"></span><span class="oh"></span>`;
    b.querySelector('.ol').textContent = v.name;
    const d = document.createElement('span'); d.className = 'od'; d.textContent = typeof v.desc === 'function' ? v.desc() : v.desc; b.querySelector('.ol').append(d);
    b.querySelector('.oh').innerHTML = v.chips.map(([c, t]) => `<span class="chip ${c}">${t}</span>`).join(' ');
    b.onclick = () => startRhythm(k, { style: VS.style });
    box.append(b);
  });
  ui.querySelectorAll('[data-st]').forEach(b => b.onclick = () => { VS.style = b.dataset.st; renderVerseSelect(); });
}
function startRhythm(type, opts) {
  initAudio();
  MODE = 'rhythm'; RH.select = false;
  $('rhythm').hidden = false; $('hud').hidden = true; $('rh-ui').innerHTML = '';
  resizeRhythm();
  const seed = (Date.now() ^ (S.stats.tracks * 7919)) >>> 0;
  RH.style = (opts && opts.style) || 'chi'; RH.seed = seed;
  RH.beat = buildBeat(seed, type, RH.style);
  RH.notes = RH.beat.notes.map(n => ({ t: n.t, lane: n.lane, hit: null }));
  RH.type = type; RH.opts = opts || {}; RH.title = RH.opts.showcase ? 'Showcase · ' + genTitle('wayout') : genTitle(type);
  RH.combo = 0; RH.maxCombo = 0; RH.pts = 0; RH.counts = { perfect: 0, great: 0, good: 0, miss: 0 }; RH.judge = null; RH.ended = false; RH.flash = [0, 0, 0, 0];
  if (AU.ready) { RH.B = makeBus(AU.music, { gain: 0.5 }); RH.t0 = AU.ctx.currentTime + 1.6; scheduleBeat(RH.B, RH.beat, RH.t0); }
  else { RH.B = null; RH.clock0 = performance.now() / 1000 + 1.6; }
  RH.on = true;
  if (RH.opts.showcase) sfx.cheer();
}
function rhNow() {
  if (RH.B && AU.ready) return AU.ctx.currentTime - (AU.ctx.outputLatency || AU.ctx.baseLatency || 0) - RH.t0;
  return performance.now() / 1000 - RH.clock0;
}
const RH_KEYS = { KeyD: 0, KeyF: 1, KeyJ: 2, KeyK: 3 };
function rhHit(lane) {
  if (!RH.on || RH.ended) return;
  RH.flash[lane] = 1;
  const t = rhNow();
  let best = null, bd = 0.17;
  for (const n of RH.notes) { if (n.hit || n.lane !== lane) continue; const d = Math.abs(n.t - t); if (d < bd) { bd = d; best = n; } if (n.t > t + 0.2) break; }
  if (!best) return;
  const j = bd < 0.05 ? 'perfect' : bd < 0.1 ? 'great' : 'good';
  best.hit = j; RH.counts[j]++; RH.pts += j === 'perfect' ? 1 : j === 'great' ? 0.75 : 0.4;
  RH.combo++; RH.maxCombo = Math.max(RH.maxCombo, RH.combo);
  RH.judge = { j, t: performance.now() };
}
function rhUpdate() {
  if (!RH.on || RH.ended) return;
  const t = rhNow();
  for (const n of RH.notes) { if (!n.hit && n.t < t - 0.17) { n.hit = 'miss'; RH.counts.miss++; RH.combo = 0; RH.judge = { j: 'miss', t: performance.now() }; } }
  if (t > RH.beat.dur + 0.5) rhFinish();
}
function rhFinish() {
  RH.ended = true; RH.on = false;
  const total = RH.notes.length || 1, acc = RH.pts / total;
  const grade = acc >= 0.92 ? 'S' : acc >= 0.8 ? 'A' : acc >= 0.65 ? 'B' : acc >= 0.5 ? 'C' : 'D';
  const q = Math.pow(acc, 1.4);
  const type = RH.type, showcase = RH.opts.showcase;
  let buzz, heat, cash;
  if (type === 'tribute') { buzz = Math.round(3 + 9 * q); heat = -4; cash = Math.round(80 + 260 * q); }
  else if (type === 'wayout') { buzz = Math.round(5 + 12 * q); heat = 0; cash = Math.round(120 + 380 * q); }
  else { buzz = Math.round(9 + 16 * q); heat = Math.round(16 + 8 * (1 - q * 0.4)); cash = S.flags.vanceOffer ? Math.round(vancePay() * (0.6 + 0.4 * q)) : Math.round(200 + 300 * q); }
  if (showcase) { buzz = Math.round(buzz * 1.5); cash = Math.round(cash * 2); }
  const comment = { S: "That's the one. Don't touch it.", A: "Hard. I'm mixing it tonight.", B: 'Solid. We can punch in the rough spots.', C: 'Eh. The beat carried you.', D: 'Were you even listening to the 808?' }[grade];
  const ui = $('rh-ui');
  ui.innerHTML = `<div class="card"><div class="eyebrow">${showcase ? 'Rec center showcase' : (type === 'wayout' ? 'Way out' : type[0].toUpperCase() + type.slice(1)) + ' verse'}</div>
    <div class="res-row"><div class="grade">${grade}</div><div><div class="res-t"></div><div class="mono" style="color:var(--ice-2);margin-top:6px">${Math.round(acc * 100)}% · best combo ${RH.maxCombo} · ${RH.counts.perfect}/${RH.counts.great}/${RH.counts.good}/${RH.counts.miss}</div></div></div>
    <p><b style="color:${CAST[showcase ? 'coach' : 'benny'].color}">${showcase ? CAST.coach.name : CAST.benny.name}:</b> <span class="cm"></span></p>
    <div class="rw"><span style="color:var(--buzz)">Buzz +${buzz}</span><span style="color:${heat > 0 ? '#ff9d92' : 'var(--good)'}">Heat ${heat >= 0 ? '+' : ''}${heat}</span><span style="color:var(--good)">+${fmtMoney(cash)}</span></div>
    <button class="btn primary" id="rh-release">${showcase ? (acc >= 0.6 ? 'Take a bow' : 'Step off stage') : 'Release it'}</button></div>`;
  ui.querySelector('.res-t').textContent = RH.title;
  ui.querySelector('.cm').textContent = showcase ? (acc >= 0.6 ? 'That is how you do it. That is your way out.' : 'Shake it off. Come back when you are ready.') : comment;
  if (showcase && acc >= 0.6) sfx.cheer();
  $('rh-release').onclick = () => {
    killBus(RH.B); RH.B = null;
    addBuzz(buzz); addHeat(heat); addCash(cash);
    const tr = { title: RH.title, type: showcase ? 'wayout' : type, acc, grade, at: Date.now(), seed: RH.seed, style: RH.style };
    S.tracks.push(tr); if (S.tracks.length > 60) S.tracks.shift();
    S.stats.tracks++;
    if (!S.stats.best || acc > S.stats.best.acc) S.stats.best = { title: tr.title, grade, acc };
    if (type === 'diss' && !showcase) { S.stats.disses++; if (S.flags.vanceOffer) setTimeout(() => sendMsg('vance', `Now that's content. ${fmtMoney(cash)} sent. Next one pays more.`), 4000); }
    if (!showcase) setCd('studio', 45);
    onTrackReleased(tr);
    addSocialPost('track', `new ${({ chi: 'Chicago', uk: 'UK', ny: 'NY' })[tr.style]} drill out now: “${tr.title}” (${grade})`, coverArt(tr.title, tr.type));
    netPost({ k: 'track', title: tr.title.slice(0, 40), type: tr.type, grade });
    $('rhythm').hidden = true; $('hud').hidden = false; $('rh-ui').innerHTML = '';
    saveGame();
    if (showcase && acc >= 0.6) { S.flags.showcaseDone = true; triggerEnding('wayout'); return; }
    if (showcase) { MODE = 'play'; lockPointer(); return; }
    openStudioMenu();
  };
}
function rhAbort() {
  killBus(RH.B); RH.B = null; RH.on = false; RH.ended = true; RH.select = false;
  $('rhythm').hidden = true; $('hud').hidden = false; $('rh-ui').innerHTML = '';
  if (RH.opts && RH.opts.showcase) { MODE = 'play'; lockPointer(); } else openStudioMenu();
}
const RC = $('rh-canvas'), RX = RC.getContext('2d');
function resizeRhythm() { const d = Math.min(devicePixelRatio || 1, 2); RC.width = innerWidth * d; RC.height = innerHeight * d; }
const LANE_COL = ['#71c6ff', '#ff9a3c', '#f4c64e', '#ff4b3a'], LANE_KEY = ['D', 'F', 'J', 'K'];
function drawRhythm() {
  const W = RC.width, H = RC.height, g = RX, d = W / innerWidth;
  const t = RH.on || RH.ended ? rhNow() : 0;
  const bg = g.createRadialGradient(W / 2, H * 0.35, 0, W / 2, H * 0.35, Math.max(W, H) * 0.8);
  const show = RH.opts && RH.opts.showcase;
  bg.addColorStop(0, show ? '#2a2216' : '#1a1416'); bg.addColorStop(1, '#05070b'); g.fillStyle = bg; g.fillRect(0, 0, W, H);
  // foam panels / gym
  g.globalAlpha = 0.18;
  for (let x = 0; x < W; x += 60 * d) for (let y = 0; y < H * 0.7; y += 60 * d) { g.fillStyle = (x / (60 * d) + y / (60 * d)) % 2 ? '#2a2026' : '#1a1418'; g.fillRect(x, y, 58 * d, 58 * d); }
  g.globalAlpha = 1;
  const beatPh = RH.beat ? ((t / (RH.beat.step * 4)) % 1 + 1) % 1 : 0;
  const pulse = Math.max(0, 1 - beatPh * 3);
  // recording light
  g.fillStyle = RH.on ? `rgba(255,40,30,${0.5 + pulse * 0.5})` : '#401010';
  g.beginPath(); g.arc(W - 40 * d, 40 * d, 9 * d, 0, TAU); g.fill();
  g.font = `700 ${13 * d}px "IBM Plex Mono", monospace`; g.textAlign = 'right'; g.fillStyle = '#ff6a5a'; g.fillText(show ? 'LIVE' : 'REC', W - 56 * d, 45 * d);
  if (!RH.beat) return;
  const laneW = Math.min(110 * d, W * 0.2), x0 = W / 2 - laneW * 2, hitY = H * 0.82, speed = H * 0.62;
  for (let i = 0; i < 4; i++) {
    const x = x0 + i * laneW;
    g.fillStyle = i % 2 ? 'rgba(220,239,255,.035)' : 'rgba(220,239,255,.06)'; g.fillRect(x, 0, laneW, H);
    RH.flash[i] = Math.max(0, RH.flash[i] - 0.08);
    if (RH.flash[i] > 0) { const gr = g.createLinearGradient(0, hitY, 0, hitY - 220 * d); gr.addColorStop(0, LANE_COL[i] + '88'); gr.addColorStop(1, LANE_COL[i] + '00'); g.globalAlpha = RH.flash[i]; g.fillStyle = gr; g.fillRect(x, hitY - 220 * d, laneW, 220 * d); g.globalAlpha = 1; }
  }
  g.fillStyle = `rgba(255,154,60,${0.6 + pulse * 0.4})`; g.fillRect(x0, hitY - 2 * d, laneW * 4, 4 * d);
  for (let i = 0; i < 4; i++) { const x = x0 + i * laneW + laneW / 2; g.strokeStyle = LANE_COL[i]; g.lineWidth = 2 * d; g.globalAlpha = 0.5 + RH.flash[i] * 0.5; g.beginPath(); g.arc(x, hitY, 24 * d, 0, TAU); g.stroke(); g.globalAlpha = 1; g.font = `700 ${16 * d}px "IBM Plex Mono", monospace`; g.textAlign = 'center'; g.fillStyle = '#dcefff'; g.fillText(LANE_KEY[i], x, hitY + 52 * d); }
  for (const n of RH.notes) {
    const y = hitY - (n.t - t) * speed;
    if (y < -40 || y > H + 40) continue;
    if (n.hit && n.hit !== 'miss') continue;
    const x = x0 + n.lane * laneW + laneW * 0.12, w = laneW * 0.76;
    g.globalAlpha = n.hit === 'miss' ? 0.25 : 1;
    g.fillStyle = LANE_COL[n.lane]; g.beginPath(); if (g.roundRect) g.roundRect(x, y - 9 * d, w, 18 * d, 6 * d); else g.rect(x, y - 9 * d, w, 18 * d); g.fill();
    g.fillStyle = 'rgba(255,255,255,.55)'; g.fillRect(x + 6 * d, y - 6 * d, w - 12 * d, 3 * d);
    g.globalAlpha = 1;
  }
  // header
  g.textAlign = 'left'; g.fillStyle = '#dcefff';
  g.font = `900 ${Math.min(40 * d, W * 0.05)}px "Big Shoulders Display", Impact, sans-serif`; g.fillText(RH.title.toUpperCase(), 26 * d, 58 * d);
  g.font = `600 ${12 * d}px "IBM Plex Mono", monospace`; g.fillStyle = '#ff9a3c';
  g.fillText(`${show ? 'SHOWCASE' : VERSES[RH.type].name.toUpperCase() + ' VERSE'} · ${STYLES[RH.style || 'chi'].name.toUpperCase()} DRILL · ${RH.beat.bpm} BPM · ${CAST.benny.name}`, 26 * d, 82 * d);
  const judged = RH.notes.filter(n => n.hit).length;
  const acc = judged ? RH.pts / judged : 1;
  g.font = `600 ${22 * d}px "IBM Plex Mono", monospace`; g.fillStyle = '#dcefff'; g.fillText(`${Math.round(acc * 100)}%`, 26 * d, 122 * d);
  g.font = `600 ${13 * d}px "IBM Plex Mono", monospace`; g.fillStyle = '#a3c2dc'; g.fillText(`combo ${RH.combo}`, 26 * d, 144 * d);
  const prog = clamp(t / RH.beat.dur, 0, 1); g.fillStyle = 'rgba(220,239,255,.15)'; g.fillRect(0, H - 4 * d, W, 4 * d); g.fillStyle = '#ff9a3c'; g.fillRect(0, H - 4 * d, W * prog, 4 * d);
  if (t < 0 && RH.on) { g.textAlign = 'center'; g.font = `900 ${60 * d}px "Big Shoulders Display", Impact, sans-serif`; g.fillStyle = '#dcefff'; g.fillText(Math.ceil(-t), W / 2, H * 0.45); }
  if (RH.judge && performance.now() - RH.judge.t < 450) {
    const k = (performance.now() - RH.judge.t) / 450;
    g.globalAlpha = 1 - k; g.textAlign = 'center';
    g.font = `900 ${38 * d}px "Big Shoulders Display", Impact, sans-serif`;
    g.fillStyle = { perfect: '#f4c64e', great: '#86e3b0', good: '#71c6ff', miss: '#ff4b3a' }[RH.judge.j];
    g.fillText(RH.judge.j.toUpperCase(), W / 2, hitY - 90 * d - k * 20 * d); g.globalAlpha = 1;
  }
}
RC.addEventListener('pointerdown', e => {
  if (!RH.on) return;
  const d = RC.width / innerWidth, W = RC.width, laneW = Math.min(110 * d, W * 0.2), x0 = W / 2 - laneW * 2;
  const lane = Math.floor((e.clientX * d - x0) / laneW);
  if (lane >= 0 && lane < 4) rhHit(lane); else rhHit(e.clientX < innerWidth / 2 ? (e.clientX < innerWidth / 4 ? 0 : 1) : (e.clientX < innerWidth * 0.75 ? 2 : 3));
});

