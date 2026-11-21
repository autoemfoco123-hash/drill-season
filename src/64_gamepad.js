/* =========================================================
   GAMEPAD - any controller the browser can see (Xbox,
   PlayStation and most others). In play it drives the same
   actions as the keyboard; in menus, the phone and the title
   screen the D-pad moves a highlight and A / ✕ presses it.
   Settings live in the Controller app on the phone.
   ========================================================= */
const GP = { idx: -1, id: '', pad: null, prev: [], held: {}, lx: 0, ly: 0, rx: 0, ry: 0, lt: 0, rt: 0, fire: false, aim: false, sprint: false, active: false, lastUse: -99, focus: null, lastRect: null, navDir: '', navT: 0, snap: null, live: [] };
function padSet() {
  const s = S.settings; if (!s.pad || typeof s.pad !== 'object') s.pad = {};
  const p = s.pad;
  if (p.on === undefined) p.on = true; if (!(p.sens > 0)) p.sens = 1; if (p.invertY === undefined) p.invertY = false;
  if (p.rumble === undefined) p.rumble = true; if (p.assist === undefined) p.assist = true; if (!['auto', 'xbox', 'ps'].includes(p.layout)) p.layout = 'auto';
  return p;
}
function padLayout() { const l = padSet().layout; if (l !== 'auto') return l; if (/xbox|xinput|045e/i.test(GP.id)) return 'xbox'; return /054c|playstation|dualsense|dualshock|^wireless controller/i.test(GP.id) ? 'ps' : 'xbox'; }
const PAD_NAMES = {
  xbox: ['A', 'B', 'X', 'Y', 'LB', 'RB', 'LT', 'RT', 'View', 'Menu', 'L3', 'R3', 'D↑', 'D↓', 'D←', 'D→'],
  ps: ['✕', '○', '□', '△', 'L1', 'R1', 'L2', 'R2', 'Create', 'Options', 'L3', 'R3', 'D↑', 'D↓', 'D←', 'D→'],
};
const padName = i => PAD_NAMES[padLayout()][i];
function padShort() { return (GP.id || 'Controller').replace(/\(.*?\)/g, '').replace(/STANDARD GAMEPAD|Vendor:.*$/i, '').replace(/\s+/g, ' ').trim().slice(0, 40) || 'Controller'; }
// the key shown in prompts: the pad button while a controller is in use
const KEY_TO_PAD = { E: 5, F: 3, R: 2, Space: 0, C: 1, B: 13, T: 15, G: 14, Tab: 12, V: 11, Q: 4, H: 1 };
function keyCap(k) { return GP.active && KEY_TO_PAD[k] !== undefined ? `<kbd class="pad">${padName(KEY_TO_PAD[k])}</kbd>` : `<kbd>${k}</kbd>`; }
function setPadActive(on) {
  if (GP.active === on) return;
  GP.active = on; document.body.classList.toggle('pad', on); hudDirty = true;
  if (!on) { padClearFocus(); padRelease(); }
}
// the keyboard and mouse take over again as soon as they are used
addEventListener('keydown', e => { if (e.isTrusted && GP.active) setPadActive(false); }, true);
addEventListener('mousemove', e => { if (e.isTrusted && GP.active && Math.abs(e.movementX || 0) + Math.abs(e.movementY || 0) > 6) setPadActive(false); });
addEventListener('pointerdown', e => { if (e.isTrusted && GP.active && e.pointerType === 'touch') setPadActive(false); }, true);
addEventListener('gamepadconnected', e => {
  GP.idx = e.gamepad.index; GP.id = e.gamepad.id;
  if (MODE !== 'title') toast(null, 'Controller connected · ' + padShort(), '#7be0a6');
  if (MODE === 'phone' && PHONE.app === 'pad') renderApp();
});
addEventListener('gamepaddisconnected', e => {
  if (e.gamepad.index !== GP.idx) return;
  GP.idx = -1; GP.pad = null; setPadActive(false);
  toast(null, 'Controller disconnected', '#ffb347');
  if (MODE === 'phone' && PHONE.app === 'pad') renderApp();
});
// synthetic key presses reuse every keyboard action the game already has
function vkey(code, down) { window.dispatchEvent(new KeyboardEvent(down ? 'keydown' : 'keyup', { code, bubbles: true })); }
function padRelease() {
  for (const i in GP.held) vkey(GP.held[i], false);
  GP.held = {}; GP.fire = GP.aim = GP.sprint = false; GP.snap = null;
}
function rumble(strong, weak, ms) {
  if (!GP.active || !padSet().rumble || !GP.pad) return;
  const a = GP.pad.vibrationActuator;
  try { if (a && a.playEffect) a.playEffect('dual-rumble', { startDelay: 0, duration: ms || 120, strongMagnitude: clamp(strong, 0, 1), weakMagnitude: clamp(weak, 0, 1) }).catch(() => { }); } catch (e) { }
}
const PAD_FOOT = { 0: 'Space', 1: 'KeyC', 2: 'KeyR', 3: 'KeyF', 4: 'KeyQ', 5: 'KeyE', 11: 'KeyV', 12: 'Tab', 13: 'KeyB', 14: 'KeyG', 15: 'KeyT' };
const PAD_CAR = { 0: 'Space', 1: 'KeyH', 2: 'KeyR', 3: 'KeyF', 11: 'KeyV', 12: 'Tab', 13: 'KeyB', 15: 'KeyT' };
const PAD_LANES = { 6: 'KeyD', 4: 'KeyF', 5: 'KeyJ', 7: 'KeyK', 2: 'KeyD', 0: 'KeyF', 1: 'KeyJ', 3: 'KeyK' };
function pollGamepad(dt) {
  const pads = navigator.getGamepads ? navigator.getGamepads() : [];
  let pad = GP.idx >= 0 ? pads[GP.idx] : null;
  if (!pad || !pad.connected) { pad = null; for (const p of pads) if (p && p.connected && p.buttons && p.buttons.length >= 12) { pad = p; GP.idx = p.index; GP.id = p.id; break; } }
  GP.pad = pad;
  if (!pad || !padSet().on) { if (GP.active) setPadActive(false); GP.lx = GP.ly = GP.rx = GP.ry = GP.lt = GP.rt = 0; return; }
  const dz = 0.17, ax = i => { const v = pad.axes[i] || 0; return Math.abs(v) < dz ? 0 : Math.sign(v) * (Math.abs(v) - dz) / (1 - dz); };
  GP.lx = ax(0); GP.ly = ax(1); GP.rx = ax(2); GP.ry = ax(3);
  const bv = i => { const b = pad.buttons[i]; return !b ? 0 : typeof b === 'object' ? (b.value || (b.pressed ? 1 : 0)) : +b; };
  const now = []; for (let i = 0; i < Math.min(17, pad.buttons.length); i++) now[i] = bv(i) > 0.35;
  GP.lt = bv(6); GP.rt = bv(7); GP.live = now;
  if (now.some(Boolean) || Math.hypot(GP.lx, GP.ly) > 0.25 || Math.hypot(GP.rx, GP.ry) > 0.25) { GP.lastUse = REAL_T; setPadActive(true); }
  if (!GP.active) { GP.prev = now; return; }
  const hit = i => now[i] && !GP.prev[i], up = i => !now[i] && GP.prev[i];
  // buttons held as keys are let go when the screen changes
  const ctx = MODE + (P.car ? ':car' : '');
  if (GP.ctx !== ctx) { padRelease(); GP.ctx = ctx; }
  if (MODE === 'play') {
    padClearFocus();
    const map = P.car ? PAD_CAR : PAD_FOOT;
    for (const i in map) { if (hit(+i)) { vkey(map[i], true); GP.held[i] = map[i]; } else if (up(+i) && GP.held[i]) { vkey(GP.held[i], false); delete GP.held[i]; } }
    if (hit(9)) { padRelease(); openPause(); GP.prev = now; return; }
    if (hit(8)) { padRelease(); openPhone('maps'); GP.prev = now; return; }
    if (hit(10) && !P.car) GP.sprint = !GP.sprint;
    if (Math.hypot(GP.lx, GP.ly) < 0.3) GP.sprint = false;
    GP.fire = !P.car && GP.rt > 0.35;
    GP.aim = !P.car && GP.lt > 0.35;
    if (hit(6) && !P.car && padSet().assist && !S.fists) aimAssist();
    // right stick looks around (a curve keeps small moves precise)
    const curve = v => Math.sign(v) * Math.pow(Math.abs(v), 1.6);
    const sp = 1100 * padSet().sens * dt / (S.settings.sens || 1);
    if (GP.rx || GP.ry) look(curve(GP.rx) * sp, curve(GP.ry) * sp * 0.72 * (padSet().invertY ? -1 : 1) * (S.settings.invertY ? -1 : 1));
    if (GP.snap) {
      GP.snap.t -= dt; const k = 1 - Math.exp(-dt * 16);
      camYaw += angDiff(camYaw, GP.snap.yaw) * k; camPitch += (GP.snap.pitch - camPitch) * k;
      if (GP.snap.t <= 0 || Math.hypot(GP.rx, GP.ry) > 0.5) GP.snap = null;
    }
  } else if (MODE === 'cutscene') {
    if (hit(0) || hit(1) || hit(9)) skipCutscene();
  } else if (MODE === 'rhythm' && !RH.select) {
    for (const i in PAD_LANES) { if (hit(+i)) vkey(PAD_LANES[i], true); else if (up(+i)) vkey(PAD_LANES[i], false); }
    if (hit(9) || hit(8)) vkey('Escape', true);
  } else {
    padMenus(dt, now, hit);
  }
  GP.prev = now;
}
// LT snaps the aim onto the closest threat near the crosshair
function aimAssist() {
  const c = camera.position, fx = -Math.sin(camYaw), fz = -Math.cos(camYaw);
  let best = null, bs = Infinity;
  const consider = (pos, h) => {
    const dx = pos.x - c.x, dy = pos.y + h - c.y, dz = pos.z - c.z, d = Math.hypot(dx, dz);
    if (d < 1.5 || d > 45) return;
    const ang = Math.acos(clamp((dx * fx + dz * fz) / d, -1, 1));
    if (ang > 0.22) return;
    if (!segClear(c.x, c.y, c.z, pos.x, pos.y + h, pos.z)) return;
    const s = ang * 30 + d * 0.05;
    if (s < bs) { bs = s; best = { yaw: Math.atan2(-dx, -dz), pitch: clamp(Math.atan2(dy, d), -1.2, 1) }; }
  };
  for (const e of ENEMIES) if (e.state !== 'down' && e.crew.state === 'combat') consider(e.pos, e.crouched ? 0.9 : 1.3);
  if (WANTED.hostile) for (const cp of COPS) if (cp.state !== 'down') consider(cp.pos, 1.3);
  if (best) GP.snap = Object.assign(best, { t: 0.22 });
}

/* ---- menus: a highlight you move with the D-pad ---- */
const PAD_FOCUSABLE = 'button, input, select, a[href], .app';
function padRoot() {
  if (MODE === 'phone') return $('ph-app').hidden ? $('phone') : $('ph-app');
  if (MODE === 'pause') return $('pause');
  if (MODE === 'menu') return $('menu');
  if (MODE === 'bench') return $('bench');
  if (MODE === 'wardrobe') return $('ward');
  if (MODE === 'ending') return $('ending');
  if (MODE === 'rhythm') return $('rhythm');
  if (MODE === 'title') { const c = $('t-confirm'); return c && !c.hidden ? c : $('title'); }
  return null;
}
function padItems(root) {
  return [...root.querySelectorAll(PAD_FOCUSABLE)].filter(el => {
    if (el.disabled || el.type === 'hidden' || el.closest('[hidden]')) return false;
    const r = el.getBoundingClientRect(); if (r.width < 3 || r.height < 3) return false;
    const st = getComputedStyle(el); return st.visibility !== 'hidden' && st.display !== 'none' && st.pointerEvents !== 'none';
  });
}
function padClearFocus() { if (GP.focus) { GP.focus.classList.remove('gp-focus'); GP.focus = null; } }
function padFocus(el, quiet) {
  if (GP.focus === el) return;
  if (GP.focus) GP.focus.classList.remove('gp-focus');
  GP.focus = el; el.classList.add('gp-focus');
  const r = el.getBoundingClientRect(); GP.lastRect = { x: r.left + r.width / 2, y: r.top + r.height / 2 };
  try { el.scrollIntoView({ block: 'nearest', inline: 'nearest' }); } catch (e) { }
  if (!quiet) play('tap', { vol: 0.25, rate: 1.3 });
}
function padMove(dx, dy) {
  const root = padRoot(); if (!root) return;
  const items = padItems(root); if (!items.length) return;
  const cur = GP.focus;
  const a = cur.getBoundingClientRect(), ax = a.left + a.width / 2, ay = a.top + a.height / 2;
  let best = null, bs = Infinity;
  for (const el of items) {
    if (el === cur) continue;
    const b = el.getBoundingClientRect(), vx = b.left + b.width / 2 - ax, vy = b.top + b.height / 2 - ay;
    const along = vx * dx + vy * dy; if (along <= 3) continue;
    const s = along + Math.abs(vx * dy - vy * dx) * 2.4;
    if (s < bs) { bs = s; best = el; }
  }
  if (best) padFocus(best);
}
function padBack() {
  if (MODE === 'phone') { if (PHONE.app) $('pa-back').click(); else closePhone(); }
  else if (MODE === 'pause') resumeGame();
  else if (MODE === 'menu') closeMenu();
  else if (MODE === 'bench') closeBench();
  else if (MODE === 'wardrobe') closeWardrobe();
  else if (MODE === 'rhythm') vkey('Escape', true);
  else if (MODE === 'title') { const b = [...document.querySelectorAll('#title .t-back')].find(x => !x.closest('[hidden]')); if (b) b.click(); else { const c = $('t-cancel'); if (c && !$('t-confirm').hidden) c.click(); } }
}
function padMenus(dt, now, hit) {
  const root = padRoot(); if (!root) return;
  // keep a highlight on something on this screen
  if (!GP.focus || !document.contains(GP.focus) || !root.contains(GP.focus) || GP.focus.closest('[hidden]') || GP.focus.disabled) {
    if (GP.focus) GP.focus.classList.remove('gp-focus'); GP.focus = null;
    const items = padItems(root);
    if (items.length) {
      let pickEl = items[0];
      if (GP.lastRect) { let bd = Infinity; for (const el of items) { const r = el.getBoundingClientRect(), d = Math.hypot(r.left + r.width / 2 - GP.lastRect.x, r.top + r.height / 2 - GP.lastRect.y); if (d < bd) { bd = d; pickEl = el; } } }
      padFocus(pickEl, true);
    }
  }
  // D-pad or left stick, with key repeat
  let dir = '';
  if (now[12] || GP.ly < -0.6) dir = 'u'; else if (now[13] || GP.ly > 0.6) dir = 'd'; else if (now[14] || GP.lx < -0.6) dir = 'l'; else if (now[15] || GP.lx > 0.6) dir = 'r';
  if (dir !== GP.navDir) { GP.navDir = dir; GP.navT = 0.38; if (dir) padStep(dir); }
  else if (dir) { GP.navT -= dt; if (GP.navT <= 0) { GP.navT = 0.11; padStep(dir); } }
  const f = GP.focus;
  if (hit(0) && f) {
    if (f.tagName === 'INPUT' && (f.type === 'text' || f.type === 'search')) f.focus();
    else if (f.tagName !== 'INPUT' || f.type === 'checkbox') { f.click(); if (f.type === 'checkbox') f.dispatchEvent(new Event('change', { bubbles: true })); }
  }
  if (hit(1)) padBack();
  if (hit(9)) { if (MODE === 'pause') resumeGame(); else if (MODE === 'phone') closePhone(); }
  // right stick scrolls long lists; in the wardrobe and title it turns your character
  if (Math.abs(GP.ry) > 0.1) { let sc = f && f.closest('#pa-body, .t-panel, #ward .w-body, .w-list, #mn-items, #bn-body'); if (!sc && MODE === 'phone') sc = $('pa-body'); if (sc) sc.scrollTop += GP.ry * 900 * dt; }
  if ((MODE === 'title' || MODE === 'wardrobe') && Math.abs(GP.rx) > 0.1 && typeof TITLE !== 'undefined') TITLE.ang += GP.rx * 2.6 * dt;
}
function padStep(dir) {
  const f = GP.focus;
  // sliders move with left / right
  if (f && f.tagName === 'INPUT' && f.type === 'range' && (dir === 'l' || dir === 'r')) {
    if (dir === 'l') f.stepDown(); else f.stepUp();
    f.dispatchEvent(new Event('input', { bubbles: true })); f.dispatchEvent(new Event('change', { bubbles: true }));
    return;
  }
  padMove(dir === 'l' ? -1 : dir === 'r' ? 1 : 0, dir === 'u' ? -1 : dir === 'd' ? 1 : 0);
}

/* ---- the Controller app ---- */
function renderPadApp(body, add) {
  const p = padSet(), pad = GP.pad, L = padLayout();
  const nm = i => esc(PAD_NAMES[L][i]);
  if (pad) add(`<div class="pad-card"><b>${esc(padShort())}</b><span>${L === 'ps' ? 'PlayStation' : 'Xbox'} buttons · ${GP.active ? 'in use' : 'press any button to use it'}</span></div>`);
  else add(`<div class="pad-card off"><b>No controller found</b><span>Plug one in or pair it over Bluetooth, then press any button. Xbox, PlayStation and most other controllers work in Chrome, Edge, Firefox and Safari.</span></div>`);
  add(`<div class="sec">Test</div><div class="pad-test" id="pad-test">${PAD_NAMES[L].map((n, i) => `<span data-b="${i}">${esc(n)}</span>`).join('')}<i class="stick" data-s="l"><em></em></i><i class="stick" data-s="r"><em></em></i></div>`);
  add(`<div class="sec">Settings</div>
    <div class="seg"><button data-pon="1" class="${p.on ? 'on' : ''}">Controller on</button><button data-pon="0" class="${!p.on ? 'on' : ''}">Off<small>keyboard and touch only</small></button></div>
    <div class="set-row"><span>Look speed</span><input type="range" id="pad-sens" min="0.4" max="2.5" step="0.05" value="${p.sens}"><output>${(+p.sens).toFixed(1)}</output></div>
    <div class="seg"><button data-pinv="0" class="${!p.invertY ? 'on' : ''}">Normal look</button><button data-pinv="1" class="${p.invertY ? 'on' : ''}">Invert Y</button></div>
    <div class="seg"><button data-prm="1" class="${p.rumble ? 'on' : ''}">Vibration</button><button data-prm="0" class="${!p.rumble ? 'on' : ''}">No vibration</button></div>
    <div class="seg"><button data-pas="1" class="${p.assist ? 'on' : ''}">Aim assist<small>${nm(6)} snaps to targets</small></button><button data-pas="0" class="${!p.assist ? 'on' : ''}">No assist</button></div>
    <div class="seg"><button data-plo="auto" class="${p.layout === 'auto' ? 'on' : ''}">Auto</button><button data-plo="xbox" class="${p.layout === 'xbox' ? 'on' : ''}">Xbox</button><button data-plo="ps" class="${p.layout === 'ps' ? 'on' : ''}">PlayStation</button></div>
    <button class="btn" id="pad-buzz" style="width:100%;margin-top:8px">Test vibration</button>`);
  const rows = (title, list) => add(`<div class="sec">${title}</div>` + list.map(([k, v]) => `<div class="row"><span>${v}</span><span class="g"><kbd class="pad">${k}</kbd></span></div>`).join(''));
  rows('On foot', [['L stick', 'Move'], ['L3', 'Sprint'], ['R stick', 'Look'], [nm(7), 'Shoot · punch'], [nm(6), 'Aim · block'], [nm(0), 'Jump'], [nm(1), 'Crouch'], [nm(2), 'Reload'], [nm(3), 'Get in a car'], [nm(4), 'Next weapon · fists'], [nm(5), 'Use · hold to walk away · recruit'], ['R3', 'First / third person'], ['D↑', 'Phone'], ['D↓', 'Bandage'], ['D←', 'Wave'], ['D→', 'Middle finger'], [nm(9), 'Pause'], [nm(8), 'Map']]);
  rows('Driving', [['L stick', 'Steer'], [nm(7), 'Gas'], [nm(6), 'Brake · reverse'], [nm(0), 'Handbrake'], [nm(1), 'Horn'], [nm(2), 'Next radio station'], [nm(3), 'Get out']]);
  rows('Menus and phone', [['D-pad · L stick', 'Move'], [nm(0), 'Select'], [nm(1), 'Back'], ['R stick', 'Scroll']]);
  rows('Studio', [[`${nm(6)} ${nm(4)} ${nm(5)} ${nm(7)}`, 'The four lanes'], [`${nm(2)} ${nm(0)} ${nm(1)} ${nm(3)}`, 'Or these'], [nm(9), 'Stop']]);
  body.querySelectorAll('[data-pon]').forEach(b => b.onclick = () => { p.on = b.dataset.pon === '1'; if (!p.on) setPadActive(false); renderApp(); });
  body.querySelectorAll('[data-pinv]').forEach(b => b.onclick = () => { p.invertY = b.dataset.pinv === '1'; renderApp(); });
  body.querySelectorAll('[data-prm]').forEach(b => b.onclick = () => { p.rumble = b.dataset.prm === '1'; renderApp(); });
  body.querySelectorAll('[data-pas]').forEach(b => b.onclick = () => { p.assist = b.dataset.pas === '1'; renderApp(); });
  body.querySelectorAll('[data-plo]').forEach(b => b.onclick = () => { p.layout = b.dataset.plo; renderApp(); });
  const s = $('pad-sens'); s.oninput = () => { p.sens = +s.value; s.nextElementSibling.textContent = (+s.value).toFixed(1); };
  $('pad-buzz').onclick = () => { const was = GP.active; GP.active = true; rumble(0.8, 0.6, 400); GP.active = was; };
}
// lights up the test panel while the app is open
function padAppTick() {
  if (MODE !== 'phone' || PHONE.app !== 'pad') return;
  const box = $('pad-test'); if (!box) return;
  box.querySelectorAll('[data-b]').forEach(el => el.classList.toggle('on', !!GP.live[+el.dataset.b]));
  const st = (k, x, y) => { const e = box.querySelector(`[data-s="${k}"] em`); if (e) e.style.transform = `translate(${x * 14}px,${y * 14}px)`; };
  st('l', GP.lx, GP.ly); st('r', GP.rx, GP.ry);
}
