
/* =========================================================
   MAIN MENU + WARDROBE - your character on a lit stage under
   the L. The wardrobe opens here and from home in the game.
   ========================================================= */
const TITLE = { spot: { x: 62.4, z: -29.4 }, ang: 0.62, turn: 0, turnV: 0, dist: 4.3, distT: 4.3, fy: 1.0, fyT: 1.0, pose: 0, wave: 2.2, prefsTouched: false, panel: 'main', key: null, rim: null, drag: null };
const WARD = { open: false, ctx: 'title', tab: 'fits' };
const W_TABS = [['fits', 'Fits'], ['head', 'Head'], ['hair', 'Hair'], ['top', 'Top'], ['bottom', 'Bottom'], ['shoes', 'Shoes'], ['extras', 'Extras'], ['body', 'Body']];
const W_FRAME = { fits: [4.3, 1.0], head: [1.35, 1.74], hair: [1.35, 1.74], top: [2.3, 1.28], bottom: [2.4, 0.62], shoes: [1.7, 0.24], extras: [2.4, 1.2], body: [3.6, 1.0] };
const hex = c => '#' + (c >>> 0).toString(16).padStart(6, '0');
function stageLights(on) {
  if (!TITLE.key) { TITLE.key = new THREE.PointLight(0xffd6ae, 0, 10, 1.5); TITLE.rim = new THREE.PointLight(0x7aa6ff, 0, 10, 1.5); scene.add(TITLE.key, TITLE.rim); }
  TITLE.key.intensity = on ? 9 : 0; TITLE.rim.intensity = on ? 9 : 0;
  if (!on && (camera.filmOffset || camera.view)) { camera.filmOffset = 0; camera.clearViewOffset(); TITLE.vo = null; camera.updateProjectionMatrix(); }
}
function stageCamera(cx, cy, cz, dt) {
  TITLE.dist += (TITLE.distT - TITLE.dist) * (1 - Math.exp(-dt * 5));
  TITLE.fy += (TITLE.fyT - TITLE.fy) * (1 - Math.exp(-dt * 5));
  const wide = innerWidth > 720, a = TITLE.ang + Math.sin(REAL_T * 0.11) * 0.1, d = TITLE.dist * (wide ? 1 : 1.12);
  const camY = cy + TITLE.fy + 0.12 + d * 0.05;
  camera.position.set(cx + Math.sin(a) * d, camY, cz + Math.cos(a) * d);
  camera.lookAt(cx, cy + TITLE.fy, cz);
  // keep the character clear of the menu: to the right on wide screens, above the panel on phones
  const fov = wide ? 40 : 50, off = wide ? -7 : 0, vo = wide ? null : innerWidth + 'x' + innerHeight;
  if (vo !== TITLE.vo) { TITLE.vo = vo; if (vo) camera.setViewOffset(innerWidth, innerHeight, 0, innerHeight * 0.13, innerWidth, innerHeight); else camera.clearViewOffset(); }
  if (Math.abs(camera.fov - fov) > 0.01 || camera.filmOffset !== off) { camera.fov = fov; camera.filmOffset = off; camera.updateProjectionMatrix(); setParticleScale(); }
  camera.updateMatrixWorld();
  TITLE.key.position.set(cx + Math.sin(a + 0.9) * 2.8, cy + 2.4, cz + Math.cos(a + 0.9) * 2.8);
  TITLE.rim.position.set(cx - Math.sin(a - 0.6) * 2.2, cy + 2.6, cz - Math.cos(a - 0.6) * 2.2);
}
function poseStage(H, dt) {
  if (!TITLE.drag) { TITLE.turn += TITLE.turnV * dt; TITLE.turnV *= Math.exp(-dt * 3); }
  TITLE.wave -= dt; TITLE.pose -= dt;
  animHuman(H, dt, { speed: 0, wave: TITLE.wave > 0 && TITLE.wave < 1.5, pose: TITLE.pose > 0 });
  H.spine.rotation.x += Math.sin(REAL_T * 1.6) * 0.012;
  H.headG.rotation.y = Math.sin(REAL_T * 0.37) * 0.18;
  if (P.gun) P.gun.visible = false;
}
function titleStage(dt) {
  const s = TITLE.spot, H = P.human;
  H.group.visible = true;
  H.group.position.set(s.x, 0, s.z);
  H.group.rotation.y = TITLE.ang + TITLE.turn;
  poseStage(H, dt);
  stageLights(true);
  stageCamera(s.x, 0, s.z, dt);
}
function wardrobeStage(dt) {
  const H = P.human;
  H.group.visible = true;
  H.group.position.copy(P.pos);
  H.group.rotation.y = TITLE.ang + TITLE.turn;
  poseStage(H, dt);
  stageLights(true);
  stageCamera(P.pos.x, P.pos.y, P.pos.z, dt);
}
// drag anywhere outside the panels to turn the character
addEventListener('pointerdown', e => {
  if (!(MODE === 'title' || MODE === 'wardrobe')) return;
  if (e.target.closest && e.target.closest('.t-wrap,#ward,button,input,#pause')) return;
  TITLE.drag = { x: e.clientX, t: performance.now() }; TITLE.turnV = 0;
});
addEventListener('pointermove', e => {
  if (!TITLE.drag) return;
  const dx = e.clientX - TITLE.drag.x, now = performance.now();
  TITLE.turn += dx * 0.012; TITLE.turnV = dx * 0.012 / Math.max(0.008, (now - TITLE.drag.t) / 1000);
  TITLE.drag.x = e.clientX; TITLE.drag.t = now;
});
addEventListener('pointerup', () => { if (TITLE.drag) { TITLE.drag = null; TITLE.turnV = clamp(TITLE.turnV, -8, 8); } });

/* ---- title panels ---- */
function showTitlePanel(name) {
  TITLE.panel = name;
  if (name === 'ward') { openWardrobe('title'); return; }
  for (const p of ['main', 'set', 'help']) $('t-' + p).hidden = p !== name;
  if (name === 'set') renderTitleSettings();
  sfx.tap();
}
document.querySelectorAll('#title [data-t]').forEach(b => b.addEventListener('click', () => showTitlePanel(b.dataset.t)));
function titleWho() {
  const typed = sanitizeName(($('t-name') && $('t-name').value) || '');
  $('t-who').textContent = '@' + (typed || (SAVED && SAVED.name) || 'you');
  const k = skinKey(cleanSkin(S.skin)), i = PRESETS.findIndex((p, n) => skinKey(presetSkin(n)) === k);
  $('t-fit').textContent = i >= 0 ? PRESETS[i][0] : 'Custom fit';
}
function persistTitleLook() {
  try { localStorage.setItem('ds.skin', JSON.stringify(cleanSkin(S.skin))); } catch (e) { }
  if (SAVED) { SAVED.skin = cleanSkin(S.skin); if (TITLE.prefsTouched) SAVED.settings = Object.assign({}, SAVED.settings, S.settings); try { localStorage.setItem(SAVE_KEY, JSON.stringify(SAVED)); } catch (e) { } }
}
function renderTitleSettings() {
  const st = S.settings, b = $('t-set-body');
  const seg = (attr, opts, cur) => `<div class="seg">${opts.map(([v, t, sm]) => `<button type="button" data-${attr}="${v}" class="${String(cur) === String(v) ? 'on' : ''}">${t}${sm ? `<small>${sm}</small>` : ''}</button>`).join('')}</div>`;
  const row = (id, label, min, max, step, val, fmt) => `<div class="srow"><span>${label}</span><input type="range" id="${id}" min="${min}" max="${max}" step="${step}" value="${val}"><output>${fmt(val)}</output></div>`;
  b.innerHTML = `<div class="lbl">Camera</div>${seg('cam', [[0, 'Third person', 'over the shoulder'], [1, 'First person', 'V switches in game']], st.fp ? 1 : 0)}
    ${row('ts-fov', 'Field of view', 60, 95, 1, st.fov || 70, v => Math.round(v))}
    ${row('ts-sens', 'Look speed', 0.3, 2.5, 0.05, st.sens, v => (+v).toFixed(1))}
    ${row('ts-vol', 'Volume', 0, 1, 0.05, st.vol, v => Math.round(v * 100))}
    ${row('ts-music', 'Music', 0, 1, 0.05, st.music, v => Math.round(v * 100))}
    <div class="lbl">Graphics</div>${seg('q', [['high', 'High', 'shadows · AA'], ['low', 'Fast', 'no shadows']], st.quality === 'low' ? 'low' : 'high')}
    <div class="lbl">Audio</div>${seg('sc', [[1, 'Score', 'music on foot'], [0, 'City only', 'no score']], st.score === false ? 0 : 1)}${seg('vo', [[1, 'Voices', 'PA · megaphone'], [0, 'Muted', 'subtitles only']], st.voices === false ? 0 : 1)}`;
  const touch = () => { TITLE.prefsTouched = true; persistTitleLook(); };
  const bind = (id, key, fmt) => { const el = $(id); el.oninput = () => { st[key] = +el.value; el.nextElementSibling.textContent = fmt(+el.value); applyVolumes(); touch(); }; };
  bind('ts-fov', 'fov', v => Math.round(v)); bind('ts-sens', 'sens', v => v.toFixed(1)); bind('ts-vol', 'vol', v => Math.round(v * 100)); bind('ts-music', 'music', v => Math.round(v * 100));
  b.querySelectorAll('[data-cam]').forEach(x => x.onclick = () => { st.fp = x.dataset.cam === '1'; touch(); renderTitleSettings(); sfx.tap(); });
  b.querySelectorAll('[data-q]').forEach(x => x.onclick = () => { st.quality = x.dataset.q; applyQuality(); touch(); renderTitleSettings(); sfx.tap(); });
  b.querySelectorAll('[data-sc]').forEach(x => x.onclick = () => { st.score = x.dataset.sc === '1'; touch(); renderTitleSettings(); sfx.tap(); });
  b.querySelectorAll('[data-vo]').forEach(x => x.onclick = () => { st.voices = x.dataset.vo === '1'; touch(); renderTitleSettings(); sfx.tap(); });
}

/* ---- wardrobe ---- */
function openWardrobe(ctx) {
  WARD.open = true; WARD.ctx = ctx;
  $('ward').hidden = false; document.body.classList.add('ward');
  if (ctx === 'game') { MODE = 'wardrobe'; unlockPointer(); fpHide(); TITLE.ang = P.bodyYaw; TITLE.turn = 0; TITLE.wave = 1.4; }
  else { $('title').querySelector('.t-wrap').hidden = true; }
  setWardTab(WARD.tab);
  sfx.tap();
}
function closeWardrobe() {
  WARD.open = false;
  $('ward').hidden = true; document.body.classList.remove('ward');
  TITLE.distT = 4.3; TITLE.fyT = 1.0;
  if (WARD.ctx === 'game') {
    stageLights(false); camera.fov = 62; camera.updateProjectionMatrix(); setParticleScale();
    MODE = 'play'; camYaw = P.bodyYaw + Math.PI; saveGame(); netSaveProfile(); NET.presT = 0; lockPointer();
    toast(null, 'Fit saved · other players see it now', '#ffb347');
  } else {
    $('title').querySelector('.t-wrap').hidden = false; showTitlePanel('main'); persistTitleLook(); titleWho();
  }
  sfx.tap();
}
function setWardTab(t) {
  WARD.tab = t; const f = W_FRAME[t] || W_FRAME.fits; TITLE.distT = f[0]; TITLE.fyT = f[1];
  renderWard();
}
function setSkin(patch) {
  S.skin = cleanSkin(Object.assign({}, S.skin, patch));
  applyPlayerSkin(); TITLE.pose = 0.9; sfx.tap();
  if (WARD.ctx === 'title') { persistTitleLook(); titleWho(); }
  renderWard();
}
function renderWard() {
  const sk = cleanSkin(S.skin), body = $('w-body');
  $('w-tabs').innerHTML = W_TABS.map(([k, t]) => `<button type="button" data-wt="${k}" class="${WARD.tab === k ? 'on' : ''}">${t}</button>`).join('');
  $('w-tabs').querySelectorAll('[data-wt]').forEach(b => b.onclick = () => { setWardTab(b.dataset.wt); sfx.tap(); });
  const chips = (field, list) => `<div class="w-opts">${list.map(v => `<button type="button" data-f="${field}" data-v="${v}" class="${sk[field] === v ? 'on' : ''}">${SKIN_LABELS[v] || v}</button>`).join('')}</div>`;
  const sw = (field, cols) => `<div class="w-sw">${cols.map(c => `<button type="button" data-f="${field}" data-c="${c}" class="${sk[field] === c ? 'on' : ''}" style="background:${hex(c)}" aria-label="colour ${hex(c)}"></button>`).join('')}</div>`;
  const tog = (field, label) => `<button type="button" data-f="${field}" data-t="1" class="${sk[field] ? 'on' : ''}">${label}</button>`;
  const sec = t => `<div class="w-sec">${t}</div>`;
  let h = '';
  switch (WARD.tab) {
    case 'fits': h = sec('Presets') + `<div class="w-opts w-pre">${PRESETS.map(([name], i) => { const p = presetSkin(i); return `<button type="button" data-pre="${i}" class="${skinKey(p) === skinKey(sk) ? 'on' : ''}"><span>${name}</span><span class="w-dots"><i style="background:${hex(p.topCol)}"></i><i style="background:${hex(p.top2)}"></i><i style="background:${hex(p.headCol)}"></i><i style="background:${hex(p.pantsCol)}"></i></span></button>`; }).join('')}</div>`; break;
    case 'head': h = sec('Headwear') + chips('head', SKIN_OPTS.head) + sec('Colour') + sw('headCol', SWATCHES) + (sk.head === 'beanie' ? `<div class="w-tog">${tog('pom', 'Pom pom')}</div>` : ''); break;
    case 'hair': h = sec('Style') + chips('hair', SKIN_OPTS.hair) + sec('Colour') + sw('hairCol', HAIR_COLS) + `<div class="w-tog">${tog('beard', 'Beard')}</div>`; break;
    case 'top': h = sec('Jacket') + chips('top', SKIN_OPTS.top) + sec('Main colour') + sw('topCol', SWATCHES) + sec('Accent') + sw('top2', SWATCHES); break;
    case 'bottom': h = sec('Pants') + chips('pants', SKIN_OPTS.pants) + sec('Colour') + sw('pantsCol', SWATCHES) + (sk.pants === 'joggers' ? sec('Stripe') + sw('pants2', SWATCHES) : ''); break;
    case 'shoes': h = sec('Shoes') + chips('shoes', SKIN_OPTS.shoes) + sec('Colour') + sw('shoesCol', SWATCHES); break;
    case 'extras': h = sec('Ice and shades') + `<div class="w-tog">${tog('chain', 'Chain')}${tog('watch', 'Watch')}${tog('glasses', 'Shades')}</div>` + sec('Bag') + chips('bag', SKIN_OPTS.bag) + (sk.bag !== 'none' ? sec('Bag colour') + sw('bagCol', SWATCHES) : ''); break;
    case 'body': h = sec('Skin tone') + sw('tone', SKIN_TONES.map((c, i) => i)).replace(/style="background:#0{5}(\d)"/g, (m, i) => `style="background:${hex(SKIN_TONES[+i])}"`) + sec('Build') + `<div class="w-opts">${['Slim', 'Regular', 'Heavy'].map((t, i) => `<button type="button" data-f="build" data-n="${i}" class="${sk.build === i ? 'on' : ''}">${t}</button>`).join('')}</div>`; break;
  }
  body.innerHTML = h;
  body.querySelectorAll('[data-pre]').forEach(b => b.onclick = () => setSkin(presetSkin(+b.dataset.pre)));
  body.querySelectorAll('[data-v]').forEach(b => b.onclick = () => setSkin({ [b.dataset.f]: b.dataset.v }));
  body.querySelectorAll('[data-c]').forEach(b => b.onclick = () => setSkin({ [b.dataset.f]: +b.dataset.c }));
  body.querySelectorAll('[data-n]').forEach(b => b.onclick = () => setSkin({ [b.dataset.f]: +b.dataset.n }));
  body.querySelectorAll('[data-t]').forEach(b => b.onclick = () => setSkin({ [b.dataset.f]: sk[b.dataset.f] ? 0 : 1 }));
}
$('w-done').onclick = closeWardrobe;
$('w-back').onclick = closeWardrobe;
$('w-rand').onclick = () => setSkin(randomSkin());
