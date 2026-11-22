
/* =========================================================
   INPUT
   ========================================================= */
let pointerLocked = false, ignoreUnlock = false, lockFailed = false;
function lockPointer(fromClick) {
  if (IS_TOUCH || MODE !== 'play') return;
  try { const p = renderer.domElement.requestPointerLock(); if (p && p.catch) p.catch(() => { if (fromClick) lockFailed = true; }); } catch (e) { if (fromClick) lockFailed = true; }
  if (fromClick) setTimeout(() => { if (!pointerLocked && MODE === 'play') lockFailed = true; }, 900);
}
function unlockPointer() { if (document.pointerLockElement) { ignoreUnlock = true; document.exitPointerLock(); } }
document.addEventListener('pointerlockchange', () => {
  pointerLocked = document.pointerLockElement === renderer.domElement;
  if (pointerLocked) { lockFailed = false; return; }
  if (ignoreUnlock) { ignoreUnlock = false; return; }
  if (MODE === 'play') openPause();
});
document.addEventListener('pointerlockerror', () => { lockFailed = true; });
renderer.domElement.addEventListener('mousedown', e => {
  if (MODE === 'cutscene') { skipCutscene(); return; }
  if (MODE === 'play' && !pointerLocked && !lockFailed) { lockPointer(true); e.preventDefault(); }
});
function look(dx, dy) {
  const s = 0.0022 * S.settings.sens * (P.aimT > 0.5 ? 0.6 : 1);
  camYaw -= dx * s;
  camPitch = clamp(camPitch - dy * s * (S.settings.invertY ? -1 : 1), -1.25, 1.0);
  if (Math.abs(dx) + Math.abs(dy) > 1) P.lastLook = REAL_T;
}
addEventListener('mousemove', e => {
  if (MODE !== 'play') return;
  if (pointerLocked || (lockFailed && e.buttons)) look(e.movementX || 0, e.movementY || 0);
});
addEventListener('mousedown', e => {
  if (MODE !== 'play' || !(pointerLocked || lockFailed)) return;
  if (e.button === 0) mouse.left = true;
  if (e.button === 2) mouse.right = true;
});
addEventListener('mouseup', e => { if (e.button === 0) mouse.left = false; if (e.button === 2) mouse.right = false; });
addEventListener('contextmenu', e => { if (MODE === 'play' || MODE === 'rhythm') e.preventDefault(); });
addEventListener('wheel', e => { if (MODE === 'play' && pointerLocked && !P.car) cycleWeapon(e.deltaY > 0 ? 1 : -1); }, { passive: true });
addEventListener('blur', () => { for (const k in keys) keys[k] = false; mouse.left = mouse.right = false; });
function useBandage() { if (S.bandages > 0 && S.health < 100 && P.healT <= 0) { S.bandages--; P.healT = 1.6; sfx.ui(); banner('Bandaged up', '+40 health'); hudDirty = true; } }
function ePress() {
  if (P.car) return;
  if (activeStandoff() || NET.standoffPeer) return;
  const it = nearestInteract();
  if (it) it.it.act();
  else { const rp = nearestRecruitPed(); if (rp) talkRecruit(rp); }
}
function carPress() {
  if (MODE !== 'play') return;
  if (P.car) { if (Math.abs(P.car.speed) > 9) { toast(null, 'Slow down first', '#ffb347'); return; } exitVehicle(); }
  else { const v = nearestCar(); if (v) enterVehicle(v); }
}
addEventListener('keydown', e => {
  const tag = e.target && e.target.tagName;
  if (tag === 'INPUT' && e.target.type !== 'range' && e.target.type !== 'checkbox') return;
  const code = e.code;
  if (code === 'Tab') e.preventDefault();
  if (MODE === 'cutscene') { if (code === 'Space' || code === 'Escape' || code === 'Enter') { e.preventDefault(); skipCutscene(); } return; }
  if (MODE === 'title' || MODE === 'ending' || MODE === 'cut') return;
  if (MODE === 'rhythm') {
    if (RH_KEYS[code] !== undefined) { e.preventDefault(); if (!e.repeat) rhHit(RH_KEYS[code]); }
    else if (code === 'Escape') rhAbort();
    else if (RH.select && /^Digit[1-3]$/.test(code)) startRhythm(['tribute', 'wayout', 'diss'][+code.slice(5) - 1], { style: VS.style });
    return;
  }
  if (MODE === 'menu') {
    if (code === 'Escape') closeMenu();
    else if (/^Digit[1-9]$/.test(code) && MENU) { const it = MENU._items[+code.slice(5) - 1]; if (it && !it.disabled) { sfx.ui(); it.act(); } }
    return;
  }
  if (MODE === 'bench') { if (code === 'Escape') closeBench(); return; }
  if (MODE === 'wardrobe') { if (code === 'Escape') closeWardrobe(); return; }
  if (MODE === 'phone') { if (code === 'Tab' || code === 'Escape' || code === 'KeyP') closePhone(); return; }
  if (MODE === 'pause') { if (code === 'Escape') resumeGame(); return; }
  keys[code] = true;
  if (e.repeat) return;
  if (code === 'Space' && P.car) e.preventDefault();
  switch (code) {
    case 'Tab': case 'KeyP': openPhone(); break;
    case 'KeyR': if (P.car) cycleRadio(); else startReload(); break;
    case 'KeyV': toggleFP(); break;
    case 'KeyG': if (!P.car) { P.waveT = 2.2; NET.presT = 0; } break;
    case 'KeyT': startFlip(); break;
    case 'KeyF': carPress(); break;
    case 'KeyH': if (P.car) sfx.honk(P.car.pos.x, P.car.pos.z); break;
    case 'Digit1': switchWeapon('k9'); break;
    case 'Digit2': switchWeapon('draft'); break;
    case 'Digit3': switchWeapon('plow'); break;
    case 'Digit4': setFists(true); break;
    case 'KeyC': case 'ControlLeft': if (!P.car) P.crouch = !P.crouch; break;
    case 'KeyB': useBandage(); break;
    case 'KeyE': ePress(); break;
    case 'KeyQ': if (!P.car) cycleWeapon(1); break;
    case 'Escape': if (!pointerLocked) openPause(); break;
  }
});
addEventListener('keyup', e => { keys[e.code] = false; });

/* ---- touch ---- */
let touchReady = false;
function setupTouch() {
  if (touchReady) return; touchReady = true;
  document.body.classList.add('touch');
  const joy = $('tc-joy'), knob = $('tc-knob'), lookEl = $('tc-look');
  let lookId = null, lx = 0, ly = 0;
  joy.addEventListener('pointerdown', e => { TOUCH.joy.active = true; TOUCH.joy.id = e.pointerId; joy.setPointerCapture(e.pointerId); moveJoy(e); });
  joy.addEventListener('pointermove', e => { if (e.pointerId === TOUCH.joy.id) moveJoy(e); });
  const endJoy = e => { if (e.pointerId !== TOUCH.joy.id) return; TOUCH.joy.active = false; TOUCH.joy.x = TOUCH.joy.y = 0; knob.style.transform = ''; };
  joy.addEventListener('pointerup', endJoy); joy.addEventListener('pointercancel', endJoy);
  function moveJoy(e) { const r = joy.getBoundingClientRect(); let x = (e.clientX - r.left - r.width / 2) / (r.width / 2), y = (e.clientY - r.top - r.height / 2) / (r.height / 2); const l = Math.hypot(x, y); if (l > 1) { x /= l; y /= l; } TOUCH.joy.x = x; TOUCH.joy.y = -y; knob.style.transform = `translate(${x * 38}px,${y * 38}px)`; }
  lookEl.addEventListener('pointerdown', e => { if (MODE === 'cutscene') { skipCutscene(); return; } lookId = e.pointerId; lx = e.clientX; ly = e.clientY; lookEl.setPointerCapture(e.pointerId); });
  lookEl.addEventListener('pointermove', e => { if (e.pointerId !== lookId || MODE !== 'play') return; look((e.clientX - lx) * 1.7, (e.clientY - ly) * 1.7); lx = e.clientX; ly = e.clientY; });
  const endLook = e => { if (e.pointerId === lookId) lookId = null; };
  lookEl.addEventListener('pointerup', endLook); lookEl.addEventListener('pointercancel', endLook);
  const hold = (id, on, off) => { const b = $(id); b.addEventListener('pointerdown', e => { e.preventDefault(); b.setPointerCapture(e.pointerId); on(); }); const f = () => off && off(); b.addEventListener('pointerup', f); b.addEventListener('pointercancel', f); };
  let fireLook = null;
  const fb = $('tc-fire');
  fb.addEventListener('pointerdown', e => { TOUCH.fire = true; fireLook = { x: e.clientX, y: e.clientY }; fb.setPointerCapture(e.pointerId); });
  fb.addEventListener('pointermove', e => { if (!fireLook || MODE !== 'play') return; look((e.clientX - fireLook.x) * 1.5, (e.clientY - fireLook.y) * 1.5); fireLook = { x: e.clientX, y: e.clientY }; });
  const fe = () => { TOUCH.fire = false; fireLook = null; }; fb.addEventListener('pointerup', fe); fb.addEventListener('pointercancel', fe);
  hold('tc-aim', () => { TOUCH.aim = !TOUCH.aim; $('tc-aim').classList.toggle('on', TOUCH.aim); });
  hold('tc-crouch', () => { P.crouch = !P.crouch; $('tc-crouch').classList.toggle('on', P.crouch); });
  hold('tc-jump', () => { TOUCH.jump = true; TOUCH.jumpHeld = true; }, () => { TOUCH.jumpHeld = false; });
  hold('tc-reload', () => { if (P.car) cycleRadio(); else startReload(); });
  hold('tc-use', () => { TOUCH.useHeld = true; ePress(); }, () => { TOUCH.useHeld = false; });
  hold('tc-car', () => carPress());
  hold('tc-sprint', () => { TOUCH.sprint = !TOUCH.sprint; $('tc-sprint').classList.toggle('on', TOUCH.sprint); });
  hold('tc-swap', () => cycleWeapon(1));
  hold('tc-band', () => useBandage());
  hold('tc-phone', () => { if (MODE === 'play') openPhone(); else if (MODE === 'phone') closePhone(); });
  hold('tc-pause', () => openPause());
  hold('tc-flip', () => { TOUCH.flip = true; startFlip(); }, () => { TOUCH.flip = false; });
  hold('tc-cam', () => toggleFP());
}

/* =========================================================
   TITLE, PAUSE
   ========================================================= */
let SAVED = null, pendingName = '';
const sanitizeName = v => String(v || '').trim().replace(/^@+/, '').replace(/[^A-Za-z0-9_.\-]/g, '').slice(0, 16);
function setupTitle() {
  SAVED = loadSave();
  const cont = $('t-continue');
  if (SAVED) { cont.hidden = false; $('t-cont-d').textContent = `@${SAVED.name} · Day ${SAVED.day || 1} · $${Math.round(SAVED.cash || 0).toLocaleString('en-US')} · Buzz ${Math.round(SAVED.buzz || 0)}`; $('t-name-l').textContent = 'Or start a new artist'; }
  else { cont.hidden = true; $('t-name-l').textContent = 'New artist'; }
  $('t-confirm').hidden = true; $('t-msg').textContent = '';
  // the menu shows your saved look (or the one you picked last time)
  let look = SAVED && SAVED.skin;
  if (!look) { try { look = JSON.parse(localStorage.getItem('ds.skin') || 'null'); } catch (e) { look = null; } }
  S.skin = cleanSkin(look || S.skin);
  if (SAVED && SAVED.settings) S.settings = Object.assign({}, S.settings, SAVED.settings);
  TITLE.prefsTouched = false; TITLE.wave = 2.2; TITLE.turn = 0;
  applyPlayerSkin(); titleWho();
  for (const p of ['main', 'set', 'help']) $('t-' + p).hidden = p !== 'main';
  $('title').querySelector('.t-wrap').hidden = false;
}
$('t-name').addEventListener('input', e => { const s = sanitizeName(e.target.value); if (s !== e.target.value.replace(/^@+/, '')) e.target.value = s; titleWho(); });
$('t-form').addEventListener('submit', e => {
  e.preventDefault();
  const nm = sanitizeName($('t-name').value);
  if (nm.length < 2) { $('t-msg').textContent = 'Pick a username: 2 to 16 letters, numbers, dots or underscores.'; $('t-name').focus(); return; }
  if (SAVED && SAVED.name.toLowerCase() === nm.toLowerCase()) { startGame(SAVED); return; }
  if (SAVED) { pendingName = nm; $('t-confirm-text').textContent = `Starting as @${nm} erases the save for @${SAVED.name}.`; $('t-confirm').hidden = false; return; }
  startGame(newState(nm));
});
$('t-continue').onclick = () => { if (SAVED) startGame(SAVED); };
$('t-continue').addEventListener('pointerenter', () => { TITLE.wave = 1.4; });
$('t-erase').onclick = () => { wipeSave(); startGame(newState(pendingName)); };
$('t-cancel').onclick = () => { $('t-confirm').hidden = true; };
function startGame(state) {
  initAudio();
  if (WARD.open) { WARD.open = false; $('ward').hidden = true; document.body.classList.toggle('ward', false); }
  stageLights(false);
  const titleS = S;
  S = state; S.job = null; S.flags.saintChallengeLive = false;
  if (titleS && titleS !== state && titleS.skin) S.skin = cleanSkin(titleS.skin);
  if (titleS && titleS !== state && TITLE.prefsTouched) Object.assign(S.settings, titleS.settings);
  S.skin = cleanSkin(S.skin);
  applyPlayerSkin();
  if (S.settings.score === undefined) S.settings.score = true;
  if (S.settings.voices === undefined) S.settings.voices = true;
  if (!(S.settings.radio >= 0 && S.settings.radio < STATIONS.length)) S.settings.radio = 1;
  if (!Array.isArray(S.garage) || !S.garage.length) S.garage = [{ model: 'hatch', color: 0x2a6a8a }];
  if (!S.social || !Array.isArray(S.social.posts)) S.social = newState(S.name).social;
  gangState(); S.fists = !!S.fists; padSet();
  for (const f of [...FOL]) removeFollower(f);
  applyVolumes(); applyQuality();
  $('title').hidden = true; $('hud').hidden = false;
  MODE = 'play';
  clearCrews(); clearWanted();
  if (S.pos && isFinite(S.pos.x)) placePlayer(S.pos.x, S.pos.y || 0, S.pos.z, S.pos.yaw);
  else placePlayer(-6.5, 0, -42, -0.8);
  camPitch = -0.08;
  P.gunKey = ''; refreshPlayerGun(); hudDirty = true;
  spawnOwnedCar(0, false);
  syncFollowers();
  if (SHOW_TOUCH) { $('touch').hidden = false; setupTouch(); }
  if (!NET.started) { NET.started = true; initNet(); }
  if (!S.flags.introSeen) { S.flags.introSeen = true; playCutscene(cutIntro(), () => banner('@' + S.name, 'Calder Park · Day ' + S.day)); }
  else { banner('@' + S.name, 'Calder Park · Day ' + S.day); lockPointer(); }
  saveGame();
}
function exitToTitle() {
  saveGame();
  if (P.car) { P.car.driver = null; P.car = null; stopEngine(); radioOff(); }
  $('pause').hidden = true; $('hud').hidden = true; $('touch').hidden = true; $('phone').hidden = true;
  MODE = 'title'; clearCrews(); clearWanted();
  for (const f of [...FOL]) removeFollower(f);
  for (const c of [...COPS]) removeCop(c);
  for (const v of [...VEH]) if (v.copAI) removeVehicle(v);
  if (NET.room) NET.room.presence({ f: 16, car: null }).catch(() => { });
  $('title').hidden = false; setupTitle();
}
function openPause() {
  if (MODE !== 'play') return;
  MODE = 'pause'; mouse.left = mouse.right = false; for (const k in keys) keys[k] = false;
  $('pause').hidden = false;
  const st = S.settings;
  $('set-sens').value = st.sens; $('set-vol').value = st.vol; $('set-music').value = st.music; $('set-inv').checked = !!st.invertY;
  syncOutputs();
}
function syncOutputs() { $('o-sens').textContent = (+S.settings.sens).toFixed(2); $('o-vol').textContent = Math.round(S.settings.vol * 100); $('o-music').textContent = Math.round(S.settings.music * 100); }
function resumeGame() { $('pause').hidden = true; MODE = 'play'; lockPointer(); }
$('set-sens').oninput = e => { S.settings.sens = +e.target.value; syncOutputs(); };
$('set-vol').oninput = e => { S.settings.vol = +e.target.value; applyVolumes(); syncOutputs(); };
$('set-music').oninput = e => { S.settings.music = +e.target.value; applyVolumes(); syncOutputs(); };
$('set-inv').onchange = e => { S.settings.invertY = e.target.checked; };
$('ps-resume').onclick = () => resumeGame();
$('ps-title').onclick = () => exitToTitle();
addEventListener('resize', () => { resizeRender(); setParticleScale(); resizeRhythm(); });
document.addEventListener('visibilitychange', () => { if (document.hidden) saveGame(); });

/* =========================================================
   MAIN LOOP
   ========================================================= */
let castT = 1, saveT = 20, netSaveT = 30, lastFrame = performance.now();
const _focus = new THREE.Vector3();
function frame(now) {
  requestAnimationFrame(frame);
  let dt = (now - lastFrame) / 1000; lastFrame = now;
  perfTick(dt);
  if (!(dt > 0)) return; if (dt > 0.05) dt = 0.05;
  REAL_T += dt;
  pollGamepad(dt);
  updateWind(dt);
  const live = MODE === 'play' || MODE === 'phone' || MODE === 'cut' || MODE === 'cutscene';
  const indoor = MODE === 'menu' || MODE === 'bench' || MODE === 'rhythm';
  if (MODE !== 'pause' && MODE !== 'ending') GAME_T += dt;
  if (MODE === 'title') {
    titleStage(dt);
    updateVehicles(dt); updatePeds(dt);
    updateAmbience(dt, WIND.gust, false, 0);
  } else if (MODE !== 'pause' && MODE !== 'ending') {
    S.playTime += dt;
    if (live) {
      updatePlayer(dt);
      updateVehicles(dt);
      updatePeds(dt);
      updateGang(dt);
      if (MODE !== 'cutscene') { updateEnemies(dt); updatePolice(dt); ambushDirector(dt); }
      updateJobs(dt);
      socialTick(dt);
      P.inFight = CREWS.some(c => c.state === 'combat');
      padAppTick();
      const sc = activeStandoff(), sp = NET.standoffPeer;
      if ((sc || sp) && !P.car && (keys.KeyE || TOUCH.useHeld) && MODE === 'play') { walkHoldUI += dt; if (walkHoldUI >= 1.4) { walkHoldUI = 0; if (sc) crewWalkAway(sc); else netWalkAway(sp); } }
      else walkHoldUI = Math.max(0, walkHoldUI - dt * 2);
      castT -= dt; if (castT <= 0) { castT = 1; castTick(); }
    }
    updateNPCs(dt);
    updateEconomy(dt);
    const fire = updateVitals(dt, indoor);
    updateAmbience(dt, WIND.gust * (indoor || P.car ? 0.3 : windExposure(P.pos.x, P.pos.z, P.pos.y)), indoor || !!P.car, fire);
    if (MODE === 'wardrobe') { updateVehicles(dt); updatePeds(dt); wardrobeStage(dt); }
    if (MODE === 'cutscene') updateCutscene(dt);
    else if (live) updateCamera(dt);
    updateGestures();
    saveT -= dt; if (saveT <= 0) { saveT = 20; saveGame(); }
    netSaveT -= dt; if (netSaveT <= 0) { netSaveT = 30; netSaveProfile(); }
  }
  _focus.copy(MODE === 'title' ? camera.position : P.pos);
  updateDayNight(dt, _focus);
  updateTrains(dt);
  updateRemotes(dt); updateNetPresence(dt);
  updateBeacons(dt); updateVideoRings(); updateSignals(dt);
  updateLightPool(dt); updateAmbientFX(dt); updateBlood(dt);
  const ws = 2 + WIND.gust * 12;
  updateSnow(dt, WIND.dx * ws, WIND.dz * ws, WIND.gust, REAL_T);
  PFX_ADD.update(dt, 0, 0); PFX_SMOKE.update(dt, WIND.dx * (1 + WIND.gust * 4), WIND.dz * (1 + WIND.gust * 4)); updateTracers(dt);
  SKY_BEACONS.mat.opacity = 0.5 + 0.5 * Math.max(0, Math.sin(REAL_T * 2.2));
  const U = GRADE.uniforms;
  U.uTime.value = REAL_T % 100;
  U.uHurt.value = Math.max(U.uHurt.value * Math.exp(-dt * 1.8), MODE !== 'title' && S.health < 30 ? 0.3 + Math.sin(REAL_T * 5) * 0.08 : 0);
  if (MODE !== 'title' && MODE !== 'ending' && MODE !== 'cutscene') updateHUD(dt);
  $('touch').hidden = !(SHOW_TOUCH && (MODE === 'play' || MODE === 'phone'));
  if (MODE === 'phone' && REAL_T % 1 < dt) phoneClock();
  if (MODE === 'rhythm') { rhUpdate(); drawRhythm(); }
  else if (MODE === 'bench') drawBench(dt);
  else { if (LITE_MODE) liteRender(dt); else renderMain(dt); phoneAfterRender(); }
}

/* ---- boot ---- */
// sound may only start from a real tap/click/key press: try on every kind, in every mode, until it runs
for (const ev of ['pointerdown', 'pointerup', 'mousedown', 'touchend', 'click', 'keydown']) addEventListener(ev, () => { if (!AU.ctx || AU.ctx.state !== 'running' || AU.stalled || (AU.unmuteEl && AU.unmuteEl.paused)) unlockAudio(); }, { capture: true, passive: true });
document.addEventListener('visibilitychange', () => {
  if (!AU.ctx) return;
  if (document.hidden) { if (AU.unmuteEl) AU.unmuteEl.pause(); }
  else if (AU.ctx.state !== 'running') { try { AU.ctx.resume().then(soundBadge, soundBadge); } catch (e) { } }
});
$('snd').addEventListener('click', e => { e.stopPropagation(); soundTest(); soundBadge(); });
soundBadge();
buildPlayer();
buildNPCs();
buildBeacons();
spawnParkedCars();
placePlayer(-6.5, 0, -42, -0.8);
setParticleScale();
resizeRender();
setupTitle();
requestAnimationFrame(frame);
window.__dsBooted = true; { const ng = document.getElementById('ds-nogo'); if (ng && PLAT.webgl !== false) ng.remove(); }
loadRealism().catch(e => console.warn('assets', e));
