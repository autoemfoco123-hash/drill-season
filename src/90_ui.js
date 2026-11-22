
/* =========================================================
   HUD - minimap, status, weapon, prompts, notifications
   ========================================================= */
const HU = {
  time: $('st-time'), cash: $('st-cash'), flash: $('st-flash'), wanted: $('st-wanted'), pips: [...$('st-wanted').children],
  buzzI: $('m-buzz').querySelector('i'), buzzV: $('m-buzz').querySelector('b'), heatI: $('m-heat').querySelector('i'), heatV: $('m-heat').querySelector('b'),
  temp: $('w-temp'), feels: $('w-feels'), hawk: $('w-hawk'), buffs: $('buffs'), street: $('mm-street'),
  weapIc: $('weap-ic'), ammo: $('weap-ammo'), note: $('weap-note'), weap: $('weap'), cross: $('cross'), ring: $('cross').querySelector('i'),
  prompt: $('prompt'), objective: $('objective'), so: $('standoff'), soProg: $('so-prog'), soTime: $('so-time'), soText: $('so-text'),
  bust: $('bust'), bustProg: $('bust-prog'), car: $('carhud'), spd: $('c-spd'), radio: $('radio'), carhp: $('carhp').querySelector('i'),
};
const WEAP_SVG = {
  k9: '<polygon points="14,9 66,9 66,18 40,18 35,35 22,35 27,18 14,18"/><rect x="58" y="6" width="5" height="3"/>',
  draft: '<polygon points="6,12 72,12 72,10 88,10 88,16 72,16 72,20 48,20 45,35 36,35 38,20 31,20 31,32 24,32 24,20 6,20"/><rect x="0" y="13" width="8" height="5"/>',
  plow: '<polygon points="4,12 97,12 97,16 62,16 62,20 42,20 36,32 26,32 31,20 4,20"/><rect x="62" y="17" width="20" height="5" rx="1"/>',
};
const MAP = { c: null, s: 3 };
function buildStaticMap() {
  const s = MAP.s, W = 2 * MAP_HALF * s;
  const c = document.createElement('canvas'); c.width = c.height = W;
  const g = c.getContext('2d');
  const X = x => (x + MAP_HALF) * s;
  g.fillStyle = '#121a24'; g.fillRect(0, 0, W, W);
  g.fillStyle = '#9fc3dc'; g.fillRect(X(LAKE_X), 0, W - X(LAKE_X), W);
  g.fillStyle = '#1b2531'; g.fillRect(X(ROAD_X_END), 0, (LAKE_X - ROAD_X_END) * s, W);
  g.fillStyle = '#2a2622'; g.fillRect(X(-MAP_HALF), 0, (XL[0] - WALK_EDGE + MAP_HALF) * s, W);
  g.fillStyle = '#3a4048'; g.fillRect(X(LOC.court.x - 15), X(LOC.court.z - 10), 30 * s, 20 * s);
  g.fillStyle = '#163024'; g.fillRect(X(-85), X(10), 75 * s, 70 * s);
  g.fillStyle = '#4b7ea6'; g.beginPath(); g.arc(X(POND.x), X(POND.z), POND.r * s, 0, TAU); g.fill();
  g.fillStyle = '#26313e';
  for (const z of ZL) g.fillRect(0, X(z - 10), X(ROAD_X_END), 20 * s);
  for (const x of XL) g.fillRect(X(x - 10), 0, 20 * s, W);
  g.fillStyle = '#566476';
  for (const z of ZL) g.fillRect(0, X(z - 6), X(ROAD_X_END - 4), 12 * s);
  for (const x of XL) g.fillRect(X(x - 6), 0, 12 * s, W);
  g.fillStyle = '#2c3644';
  for (const [x0, x1, z] of ALLEYS) g.fillRect(X(x0), X(z - 3), (x1 - x0) * s, 6 * s);
  g.fillStyle = '#0b1017';
  for (const b of BOXES) if (b.tag === 'building') g.fillRect(X(b.x0), X(b.z0), (b.x1 - b.x0) * s, (b.z1 - b.z0) * s);
  g.strokeStyle = 'rgba(255,179,71,.85)'; g.lineWidth = 3 * s / 2; g.setLineDash([6 * s, 4 * s]); g.beginPath(); g.moveTo(X(LX), 0); g.lineTo(X(LX), W); g.stroke(); g.setLineDash([]);
  g.fillStyle = 'rgba(238,243,248,.7)'; g.font = `700 ${7 * s}px Inter, sans-serif`;
  ZN.forEach((n, i) => g.fillText(n.toUpperCase(), X(-(MAP_HALF - 12)), X(ZL[i]) + 2.5 * s));
  XN.forEach((n, i) => { g.save(); g.translate(X(XL[i]) + 2.5 * s, X(MAP_HALF - 12)); g.rotate(-Math.PI / 2); g.fillText(n.toUpperCase(), 0, 0); g.restore(); });
  MAP.c = c;
}
const MM = { c: $('minimap'), g: $('minimap').getContext('2d'), route: null, routeT: 0 };
function routeTarget() {
  if (S.waypoint) return S.waypoint;
  const J = S.job ? jobById(S.job.id) : S.tracked ? jobById(S.tracked) : null;
  if (J && jobAvailable(J.id)) return J.where();
  return null;
}
function drawMinimap(dt) {
  if (!MAP.c) buildStaticMap();
  const c = MM.c, g = MM.g, W = c.width, R = W / 2, s = 2.5;
  const px = P.pos.x, pz = P.pos.z, yaw = camYaw;
  g.clearRect(0, 0, W, W);
  g.save();
  g.beginPath(); g.arc(R, R, R - 3, 0, TAU); g.clip();
  g.translate(R, R); g.rotate(yaw);
  g.save(); g.scale(s / MAP.s, s / MAP.s); g.drawImage(MAP.c, -(px + MAP_HALF) * MAP.s, -(pz + MAP_HALF) * MAP.s); g.restore();
  MM.routeT -= dt;
  const tgt = routeTarget();
  if (tgt && MM.routeT <= 0) { MM.routeT = 1; MM.route = navPath(px, pz, tgt.x, tgt.z); }
  if (!tgt) MM.route = null;
  if (MM.route) {
    g.strokeStyle = S.waypoint ? '#c79bff' : '#ffb347'; g.lineWidth = 6; g.lineJoin = 'round'; g.globalAlpha = 0.9;
    g.beginPath(); g.moveTo(0, 0);
    for (const p of MM.route) g.lineTo((p.x - px) * s, (p.z - pz) * s);
    g.stroke(); g.globalAlpha = 1;
  }
  g.restore();
  const cs = Math.cos(yaw), sn = Math.sin(yaw);
  const toMM = (x, z) => {
    const dx = (x - px) * s, dz = (z - pz) * s;
    let rx = dx * cs - dz * sn, ry = dx * sn + dz * cs;
    const l = Math.hypot(rx, ry), lim = R - 14;
    if (l > lim) { rx *= lim / l; ry *= lim / l; }
    return { x: R + rx, y: R + ry };
  };
  const dot = (x, z, col, r, shape) => {
    const p = toMM(x, z); g.fillStyle = col; g.strokeStyle = 'rgba(0,0,0,.6)'; g.lineWidth = 2;
    g.beginPath();
    if (shape === 'diamond') { g.moveTo(p.x, p.y - r); g.lineTo(p.x + r, p.y); g.lineTo(p.x, p.y + r); g.lineTo(p.x - r, p.y); g.closePath(); }
    else if (shape === 'sq') g.rect(p.x - r, p.y - r * 0.7, r * 2, r * 1.4);
    else g.arc(p.x, p.y, r, 0, TAU);
    g.stroke(); g.fill();
  };
  if (S.warmth < 55) for (const B of BARRELS) dot(B.x, B.z, '#ff7a2a', 5);
  for (const j of JOBS) { if (!jobAvailable(j.id)) continue; const w = j.where(); if (w) dot(w.x, w.z, CAST[j.giver].color, S.tracked === j.id ? 11 : 7, 'diamond'); }
  if (S.waypoint) dot(S.waypoint.x, S.waypoint.z, '#c79bff', 9, 'diamond');
  if (OWN_CAR && !OWN_CAR.dead && P.car !== OWN_CAR) dot(OWN_CAR.pos.x, OWN_CAR.pos.z, '#7be0a6', 7, 'sq');
  for (const R2 of NET.remotes.values()) { dot(R2.pos.x, R2.pos.z, R2.gg ? GANG_COLORS[R2.gg[2]] : R2.col, 7); if (R2.fol) for (const o of R2.fol.values()) dot(o.pos.x, o.pos.z, R2.gg ? GANG_COLORS[R2.gg[2]] : R2.col, 4); }
  for (const f of FOL) if (!f.riding && f.state !== 'down') dot(f.pos.x, f.pos.z, gangColor(S.gang), 4.5);
  for (const e of ENEMIES) if (e.state !== 'down' && e.crew.state !== 'leave') dot(e.pos.x, e.pos.z, '#ff4b3a', 6);
  const flash = Math.floor(REAL_T * 4) % 2;
  for (const cp of COPS) if (cp.state !== 'down') dot(cp.pos.x, cp.pos.z, flash ? '#ff3b3b' : '#3b7bff', 6);
  for (const v of VEH) if (v.copAI && v.copAI.mode !== 'leave') dot(v.pos.x, v.pos.z, flash ? '#3b7bff' : '#ff3b3b', 7, 'sq');
  if (S.job && S.job.id === 'kiara') dot(NPCS.kiara.pos.x, NPCS.kiara.pos.z, '#c79bff', 6);
  g.save(); g.translate(R, R); g.rotate(Math.PI - P.bodyYaw + yaw);
  g.fillStyle = '#fff'; g.strokeStyle = 'rgba(0,0,0,.7)'; g.lineWidth = 3;
  g.beginPath(); g.moveTo(0, -13); g.lineTo(9, 10); g.lineTo(0, 5); g.lineTo(-9, 10); g.closePath(); g.stroke(); g.fill();
  g.restore();
  const nx = R + Math.sin(yaw) * (R - 16), ny = R - Math.cos(yaw) * (R - 16);
  g.fillStyle = 'rgba(5,8,12,.85)'; g.beginPath(); g.arc(nx, ny, 12, 0, TAU); g.fill();
  g.fillStyle = '#fff'; g.font = '800 15px Inter, sans-serif'; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillText('N', nx, ny + 1);
  g.lineCap = 'round';
  const arc = (a0, a1, col, k) => { g.strokeStyle = 'rgba(0,0,0,.45)'; g.lineWidth = 9; g.beginPath(); g.arc(R, R, R - 5, Math.min(a0, a1), Math.max(a0, a1)); g.stroke(); g.strokeStyle = col; g.lineWidth = 6; g.beginPath(); g.arc(R, R, R - 5, a0, a0 + (a1 - a0) * clamp(k, 0, 1), a1 < a0); g.stroke(); };
  arc(Math.PI * 0.94, Math.PI * 0.56, S.health < 30 ? '#ff5a4e' : '#eef3f8', S.health / 100);
  arc(Math.PI * 0.06, Math.PI * 0.44, S.warmth < 35 ? '#7cc8ff' : '#ffb347', S.warmth / 100);
  if (P.stamina < 99 && !P.car) { g.strokeStyle = 'rgba(238,243,248,.5)'; g.lineWidth = 3; g.beginPath(); g.arc(R, R, R - 13, Math.PI * 0.6, Math.PI * 0.6 + Math.PI * 0.8 * P.stamina / 100); g.stroke(); }
  g.strokeStyle = 'rgba(238,243,248,.25)'; g.lineWidth = 2; g.beginPath(); g.arc(R, R, R - 2, 0, TAU); g.stroke();
}
let hudT = 0, streetT = 0;
function updateHUD(dt) {
  drawMinimap(dt);
  const st = P.stats;
  if (st && !P.car) {
    const spreadDeg = lerp(st.spread, st.aimSpread, P.aimT) * (P.speed > 1 ? 1.35 : 1) * (P.crouch ? 0.8 : 1) * (1 + P.bloom);
    const r = 4 + spreadDeg * 6 * (62 / camera.fov);
    HU.ring.style.width = HU.ring.style.height = (r * 2) + 'px'; HU.ring.style.left = HU.ring.style.top = (-r - 1.5) + 'px';
    HU.ring.style.opacity = P.aimT > 0.3 ? 0.85 : 0;
    HU.cross.style.opacity = MODE === 'play' && !P.sprinting && P.downT <= 0 ? 1 : 0;
  } else HU.cross.style.opacity = 0;
  updatePrompts();
  const W = WANTED;
  HU.pips.forEach((p, i) => p.classList.toggle('on', i < W.level));
  HU.wanted.classList.toggle('chase', W.level > 0 && W.seenT < 4);
  HU.wanted.classList.toggle('search', W.level > 0 && W.seenT >= 4);
  HU.bust.hidden = !(W.bustT > 0.05);
  if (!HU.bust.hidden) HU.bustProg.style.strokeDashoffset = 106.8 * (1 - clamp(W.bustT / 1.6, 0, 1));
  HU.car.hidden = !P.car;
  if (P.car) { HU.spd.textContent = Math.round(Math.abs(P.car.speed) * 2.237); HU.radio.textContent = '♪ ' + (STATIONS[S.settings.radio] || STATIONS[0]).name; HU.carhp.style.width = clamp(P.car.hp, 0, 100) + '%'; }
  HU.weap.style.opacity = P.car ? 0 : 1;
  hudT -= dt;
  if (hudT > 0 && !hudDirty) return;
  hudT = 0.15; hudDirty = false;
  const online = NET.status === 'solo' ? 'Solo' : (NET.remotes.size + 1) + ' online';
  HU.time.textContent = `${clockStr()} · Day ${S.day} · ${online}`;
  HU.cash.textContent = fmtMoney(S.cash);
  HU.flash.textContent = P.streamFlash && REAL_T - P.streamFlash.t < 4 ? `+${fmtMoney(P.streamFlash.v)} streams` : '';
  HU.buzzI.style.width = S.buzz + '%'; HU.buzzV.textContent = Math.round(S.buzz);
  HU.heatI.style.width = S.heat + '%'; HU.heatV.textContent = Math.round(S.heat);
  const tf = tempF(); HU.temp.textContent = tf + '°F';
  HU.feels.textContent = `feels ${tf - 12 - Math.round(WIND.gust * 14)}°`;
  HU.hawk.classList.toggle('on', WIND.gust > 0.5 && !P.car);
  const buffs = [];
  if (P.warmLabel) buffs.push(P.warmLabel);
  if (S.buffs.coffee > 0) buffs.push('coffee ' + Math.ceil(S.buffs.coffee) + 's');
  if (S.buffs.warmers > 0) buffs.push('hand warmers ' + Math.ceil(S.buffs.warmers) + 's');
  if (S.bandages) buffs.push(S.bandages + ' bandage' + (S.bandages > 1 ? 's' : '') + ' [B]');
  HU.buffs.textContent = buffs.join(' · ');
  const g = S.guns[S.cur];
  if (S.fists) {
    if (HU.weapIc.dataset.k !== 'fists') { HU.weapIc.innerHTML = FIST_SVG; HU.weapIc.dataset.k = 'fists'; }
    HU.ammo.innerHTML = '<b style="font-size:22px">FISTS</b>'; HU.ammo.classList.remove('low');
    HU.note.textContent = P.aiming ? 'GUARD UP' : '';
  } else {
    if (HU.weapIc.dataset.k !== S.cur) { HU.weapIc.innerHTML = WEAP_SVG[S.cur]; HU.weapIc.dataset.k = S.cur; }
    HU.ammo.innerHTML = `<b>${g.mag}</b><span>${g.res}</span>`;
    HU.ammo.classList.toggle('low', g.mag <= Math.ceil(P.stats.mag * 0.25));
    HU.note.textContent = P.reloadT > 0 ? 'RELOADING' : (g.mag === 0 && g.res === 0 ? 'NO AMMO · MINI MART' : '');
  }
  streetT -= 0.15;
  if (streetT <= 0) { streetT = 1; HU.street.innerHTML = `${esc(streetName(P.pos.x, P.pos.z))}<small>${esc(P.car ? P.car.sp.name : 'Calder Park district')}</small>`; }
  let obj = '';
  const J = S.job;
  if (J) {
    const j = jobById(J.id), w = j.where();
    let o = j.title;
    if (J.id === 'kiara') o = `Walk ${CAST.kiara.name} home`;
    if (J.id === 'merch') o = `Merch drop · ${J.done.length}/3 · ${Math.max(0, Math.ceil(200 - J.t))}s`;
    if (J.id === 'video') o = `Video shoot · mark ${Math.min(J.stage + 1, 3)}/3${J.train ? ' · train in shot' : ''}`;
    obj = esc(o) + (w ? `<small>${Math.round(Math.hypot(w.x - P.pos.x, w.z - P.pos.z))} m</small>` : '');
  } else if (S.waypoint) obj = `Waypoint<small>${Math.round(Math.hypot(S.waypoint.x - P.pos.x, S.waypoint.z - P.pos.z))} m</small>`;
  else if (S.tracked && jobAvailable(S.tracked)) { const j = jobById(S.tracked), w = j.where(); obj = esc(j.title) + (w ? `<small>${Math.round(Math.hypot(w.x - P.pos.x, w.z - P.pos.z))} m</small>` : ''); }
  HU.objective.innerHTML = obj;
  if (S.waypoint && Math.hypot(S.waypoint.x - P.pos.x, S.waypoint.z - P.pos.z) < 8) { S.waypoint = null; toast(null, 'You arrived', '#c79bff'); }
}
let walkHoldUI = 0;
function activeStandoff() {
  let best = null, bd = Infinity;
  for (const c of CREWS) { if (c.state !== 'standoff') continue; for (const e of c.members) { const d = Math.hypot(e.pos.x - P.pos.x, e.pos.z - P.pos.z); if (d < bd) { bd = d; best = c; } } }
  return bd < 40 ? best : null;
}
function updatePrompts() {
  if (MODE !== 'play') { HU.prompt.classList.remove('on'); HU.so.hidden = true; return; }
  const c = activeStandoff(), R = NET.standoffPeer;
  if ((c || R) && !P.car) {
    HU.so.hidden = false;
    HU.soProg.style.strokeDashoffset = 106.8 * (1 - clamp(walkHoldUI / 1.4, 0, 1));
    HU.soTime.style.width = c ? (100 * clamp(1 - c.so / 20, 0, 1)) + '%' : '100%';
    HU.soText.innerHTML = c ? `Hold ${keyCap('E')} to walk away · aim to engage` : `@${esc(R.name)} is drawing on you · hold ${keyCap('E')} to walk away`;
    HU.prompt.classList.remove('on');
    return;
  }
  HU.so.hidden = true;
  let html = '';
  if (!P.car) {
    const it = nearestInteract();
    const rp = !it && nearestRecruitPed();
    if (it) html = `${keyCap('E')}${esc(it.l)}`;
    else if (rp) html = `${keyCap('E')}Talk to ${esc(rp.rqName)} · ${RTYPES[rp.rq].name}`;
    else { const v = nearestCar(); if (v) html = `${keyCap('F')}${v.owned ? 'Get in your ' : v.driver === 'ai' ? 'Carjack the ' : v.locked ? 'Locked · ' : 'Break into the '}${esc(v.sp.name)}`; }
  }
  if (!html && !IS_TOUCH && !GP.active && !pointerLocked && REAL_T % 8 < 5) html = LITE_MODE ? 'Arrow keys look around · WASD to move' : lockFailed ? 'Drag with the mouse to look' : 'Click to control the camera';
  if (html) { if (HU.prompt.innerHTML !== html) HU.prompt.innerHTML = html; HU.prompt.classList.add('on'); }
  else HU.prompt.classList.remove('on');
}
function toast(who, text, color) {
  const box = $('notifs');
  const el = document.createElement('div'); el.className = 'nf';
  const isCast = who && CAST[who];
  const c = isCast ? CAST[who].color : (color || '#4aa3ff');
  const ic = document.createElement('div'); ic.className = 'ic'; ic.style.background = who === 'blok' ? 'linear-gradient(135deg,#ff4f81,#ff9a3c)' : c;
  ic.textContent = isCast ? CAST[who].init : who === 'blok' ? 'B' : '●';
  if (isCast) ic.style.color = '#0a0d12';
  const t = document.createElement('div');
  const a = document.createElement('b'); a.textContent = isCast ? CAST[who].name : who === 'blok' ? 'Blok' : 'Calder';
  const b = document.createElement('span'); b.textContent = text;
  t.append(a, b); el.append(ic, t); box.prepend(el);
  while (box.children.length > 2) box.lastChild.remove();
  if (isCast || who === 'blok') sfx.ping();
  setTimeout(() => { el.classList.add('out'); setTimeout(() => el.remove(), 400); }, 4600);
}
let bannerTimer = null;
function banner(title, sub) {
  const b = $('banner'); b.innerHTML = ''; b.append(document.createTextNode(title));
  if (sub) { const s = document.createElement('small'); s.textContent = sub; b.append(s); }
  b.classList.add('on'); clearTimeout(bannerTimer); bannerTimer = setTimeout(() => b.classList.remove('on'), 2300);
}

/* =========================================================
   LOCATION MENUS
   ========================================================= */
let MENU = null;
function openMenu(m) {
  MENU = m; MODE = 'menu'; unlockPointer(); P.aiming = false; mouse.left = mouse.right = false;
  $('menu').hidden = false; renderMenu(); sfx.ui();
  if (m.title === 'Calder Mini Mart' || m.title === 'Ironside Fuel') play('shopbell', { vol: 0.45 }); else if (m.indoor) sfx.door(P.pos.x, P.pos.z);
}
function renderMenu() {
  const m = MENU; if (!m) return;
  $('mn-eyebrow').textContent = m.eyebrow || ''; $('mn-title').textContent = m.title; $('mn-sub').textContent = typeof m.sub === 'function' ? m.sub() : (m.sub || '');
  const box = $('mn-items'); box.innerHTML = '';
  const items = (typeof m.items === 'function' ? m.items() : m.items).filter(Boolean);
  m._items = items;
  items.forEach((it, i) => {
    const b = document.createElement('button'); b.className = 'opt'; if (it.disabled) b.setAttribute('disabled', '');
    b.innerHTML = `<span class="k">${i + 1}</span><span class="ol"></span><span class="oh"></span>`;
    b.querySelector('.ol').textContent = it.label;
    if (it.desc) { const d = document.createElement('span'); d.className = 'od'; d.textContent = it.desc; b.querySelector('.ol').append(d); }
    b.querySelector('.oh').textContent = it.hint || '';
    b.onclick = () => { if (!it.disabled) { sfx.ui(); it.act(); } };
    box.append(b);
  });
  $('mn-warm').textContent = m.indoor ? `Warming up · ${Math.round(S.warmth)}%` : '';
  $('mn-foot').textContent = 'Esc or ' + items.length + ' to leave';
}
function closeMenu(stay) { $('menu').hidden = true; MENU = null; if (!stay) { MODE = 'play'; lockPointer(); } }
const leaveItem = () => ({ label: 'Leave', act: () => closeMenu() });
function blockedInside() {
  if (!canGoInside()) { banner("Can't go in", 'Lose them first'); return true; }
  if (WANTED.level >= 2) { banner("Can't go in", 'Police are on you'); return true; }
  return false;
}
function openStudioMenu() {
  if (blockedInside()) return;
  if (!S.flags.studioCut) { S.flags.studioCut = true; playCutscene(cutStudio(), () => openStudioMenu()); return; }
  openMenu({
    eyebrow: LOC.studio.addr, title: 'Basement 808', indoor: true,
    sub: () => `${CAST.benny.name}: "${pick(NPC_LINES.benny())}"`,
    items: () => {
      const cd = cdLeft('studio');
      return [
        { label: 'Record a session', desc: 'Pick a verse and a beat style.' + (S.flags.vanceOffer ? ` Diss pays ${fmtMoney(vancePay())}.` : ''), hint: cd > 0 ? `booth busy ${Math.ceil(cd)}s` : 'free', disabled: cd > 0, act: () => openVerseSelect() },
        { label: 'Workbench', desc: 'Parts, finishes, charms and new guns.', hint: fmtMoney(S.cash), act: () => openBench() },
        jobAvailable('merch') && !S.job ? { label: 'Pick up the merch', desc: 'Hoodies for 3 drop spots. 200 seconds.', hint: '+$360', act: () => { startJob('merch', { done: [] }); closeMenu(); banner('Merch drop', '3 spots · 200s'); } } : null,
        leaveItem(),
      ];
    },
  });
}
function openStoreMenu(kind) {
  if (blockedInside()) return;
  const buy = (price, fn, msg) => () => { if (S.cash < price) { $('mn-sub').textContent = 'Not enough cash.'; return; } addCash(-price); fn(); $('mn-sub').textContent = msg; renderMenu(); hudDirty = true; };
  openMenu({
    eyebrow: kind === 'gas' ? 'Ironside Rd · open 24 hours' : LOC.store.addr, title: kind === 'gas' ? 'Ironside Fuel' : 'Calder Mini Mart', indoor: true, sub: 'Hot coffee, hand warmers, first aid. Ammo behind the counter.',
    items: () => {
      const it = [
        { label: 'Hot coffee', desc: 'Warmth +35 now, slower chill for 60s.', hint: '$8', act: buy(8, () => { S.warmth = Math.min(100, S.warmth + 35); S.buffs.coffee = 60; }, 'Coffee. Black, still hot.') },
        { label: 'Hand warmers', desc: 'Warmth drains half as fast for 2 minutes.', hint: '$15', act: buy(15, () => { S.buffs.warmers = 120; }, 'Hand warmers cracked and in your pockets.') },
        { label: 'Bandage', desc: 'Press B to heal 40 health.', hint: '$25', act: buy(25, () => { S.bandages++; }, 'Bandage in your pocket.') },
      ];
      for (const id of ['k9', 'draft', 'plow']) if (S.guns[id].owned) { const A = WEAPONS[id].ammo; it.push({ label: `${WEAPONS[id].short} ammo`, desc: `${A.n} rounds.`, hint: fmtMoney(A.price), act: buy(A.price, () => { S.guns[id].res += A.n; }, `${A.n} rounds for the ${WEAPONS[id].short}.`) }); }
      it.push(leaveItem());
      return it;
    },
  });
}
function openRecMenu() {
  if (blockedInside()) return;
  openMenu({
    eyebrow: LOC.rec.addr, title: 'Calder Park Rec', indoor: true, sub: () => `${CAST.coach.name}: "${pick(NPC_LINES.coach())}"`,
    items: () => [
      S.flags.kiaraAsk && !S.job ? { label: `Walk ${CAST.kiara.name} home`, desc: 'She follows you to Bishop St. Family time lowers Heat.', hint: 'Heat −12', act: () => { startJob('kiara', { fight: false }); const K = NPCS.kiara; K.pos.set(LOC.rec.x + 1, 0, LOC.rec.z); K.trail = []; K.lineT = 4; closeMenu(); } } : null,
      { label: 'Perform at the showcase', desc: jobAvailable('showcase') ? 'One take in front of the whole rec. Hit 60% to land it.' : jobById('showcase').lock(), hint: 'Way Out', disabled: !jobAvailable('showcase'), act: () => { closeMenu(true); startRhythm('wayout', { showcase: true, style: 'chi' }); } },
      { label: 'Warm up by the radiator', desc: 'Stay inside a minute.', hint: Math.round(S.warmth) + '%', act: () => renderMenu() },
      leaveItem(),
    ],
  });
}
function openHomeMenu() {
  if (blockedInside()) return;
  openMenu({
    eyebrow: LOC.home.addr, title: 'Home', indoor: true, sub: 'Radiator clanking. Mama asleep on the couch with the TV on.',
    items: () => {
      const cd = cdLeft('laylow');
      return [
        { label: 'Lay low', desc: 'Stay in a while. Heat −20, health and warmth back up, Buzz −2.', hint: cd > 0 ? `${Math.ceil(cd)}s` : 'Heat −20', disabled: cd > 0, act: () => layLow() },
        { label: 'Wardrobe', desc: 'Change your fit. Other players see it right away.', hint: 'Skins', act: () => { closeMenu(true); openWardrobe('game'); } },
        { label: 'Save progress', desc: 'Saved in this browser.', hint: '', act: () => { saveGame(); $('mn-sub').textContent = 'Saved.'; } },
        leaveItem(),
      ];
    },
  });
}
function openReyesMenu() {
  openMenu({
    eyebrow: 'Under the L · Low End Rd', title: CAST.reyes.name, indoor: false, sub: `"You came. Good. Tell me about ${CAST.saint.name} and this ends tonight."`,
    items: [
      { label: 'Talk', desc: 'Tell the detective everything. Your Heat is cleared. Ending: Witness.', hint: 'Witness', act: () => { closeMenu(true); triggerEnding('witness'); } },
      { label: 'Walk away', desc: 'Say nothing and leave.', act: () => { sayCast('reyes', 'Then I will see you when it is too late.'); closeMenu(); } },
    ],
  });
}

/* =========================================================
   SOCIAL - Blok
   ========================================================= */
const COMMENTS = {
  photo: ['this hard 🔥', 'Calder stand up', 'cold out there fr', 'where is this??', 'drop the song already', 'the Hawk is crazy', 'love this', 'that jacket tho'],
  track: ['on repeat', 'this the one', 'the 808 on this 😮‍💨', 'Calder anthem', 'need the video', 'snapped', 'who produced this??'],
  video: ['the L in the back 😭', 'cinema', 'that platform shot!!', 'video of the year on the block'],
};
function socialFollowers() { return Math.round((S.social.followers || 0) + Math.pow(S.buzz, 1.7) * 14); }
function coverArt(title, type) {
  const c = document.createElement('canvas'); c.width = 320; c.height = 180;
  const g = c.getContext('2d');
  const col = type === 'diss' ? ['#2a0608', '#a3141c'] : type === 'wayout' ? ['#0a1a2e', '#3a6aa0'] : ['#1a0f04', '#c0701a'];
  const gr = g.createLinearGradient(0, 0, 320, 180); gr.addColorStop(0, col[0]); gr.addColorStop(1, col[1]); g.fillStyle = gr; g.fillRect(0, 0, 320, 180);
  for (let i = 0; i < 260; i++) { g.fillStyle = `rgba(255,255,255,${Math.random() * 0.4})`; g.fillRect(Math.random() * 320, Math.random() * 180, 1.5, 1.5); }
  g.fillStyle = 'rgba(0,0,0,.35)'; for (let x = 0; x < 320; x += 22) { const h = 30 + Math.random() * 70; g.fillRect(x, 180 - h, 20, h); }
  g.fillStyle = '#fff'; g.font = '900 34px "Big Shoulders Display", Impact, sans-serif'; g.textBaseline = 'top';
  g.fillText(title.toUpperCase(), 16, 16, 288);
  g.font = '600 13px Inter, sans-serif'; g.fillStyle = 'rgba(255,255,255,.8)'; g.fillText('@' + S.name + ' · prod. ' + CAST.benny.name, 16, 58, 288);
  return c.toDataURL('image/jpeg', 0.72);
}
function thumbOf(dataUrl, w, h, cb) { const img = new Image(); img.onload = () => { const c = document.createElement('canvas'); c.width = w; c.height = h; c.getContext('2d').drawImage(img, 0, 0, w, h); cb(c.toDataURL('image/jpeg', 0.6)); }; img.src = dataUrl; }
function addSocialPost(kind, caption, img) {
  const eng = kind === 'track' ? 0.09 : kind === 'video' ? 0.12 : 0.06;
  const post = { id: Date.now() + '' + Math.floor(Math.random() * 999), at: Date.now(), kind, caption: String(caption || '').slice(0, 80), img: img || null, thumb: null, likes: 0, target: Math.round(socialFollowers() * eng * rand(0.7, 1.4)) + randi(3, 12), comments: [] };
  S.social.posts.unshift(post);
  if (S.social.posts.length > 12) S.social.posts.length = 12;
  if (img) thumbOf(img, 160, 90, t => { post.thumb = t; netPost({ k: 'photo' }); saveGame(); });
  if (kind === 'photo') S.stats.photos++;
  hudDirty = true;
  return post;
}
let socialT = 4;
function socialTick(dt) {
  socialT -= dt; if (socialT > 0) return; socialT = 4;
  for (const p of S.social.posts) {
    if (Date.now() - p.at > 40 * 60000 || p.likes >= p.target) continue;
    const add = Math.max(1, Math.ceil((p.target - p.likes) * rand(0.06, 0.2)));
    p.likes += add; if (Math.random() < 0.4) S.social.followers += Math.ceil(add / 8);
    if (Math.random() < 0.18 && p.comments.length < 6) {
      const c = { h: pick(FEED_HANDLES), t: pick(COMMENTS[p.kind] || COMMENTS.photo) };
      p.comments.push(c);
      if (Math.random() < 0.5 && MODE === 'play') toast('blok', `${c.h} commented: ${c.t}`);
    }
  }
}

/* =========================================================
   PHONE OS
   ========================================================= */
const PHONE = { app: null, thread: null, selfie: false, photo: null, cap: null, capText: '', wantShot: false, blokTab: 'feed', preview: null, carColor: {} };
const ICON = {
  msgs: '<svg viewBox="0 0 24 24"><path d="M12 3C6.5 3 2 6.6 2 11c0 2.4 1.3 4.6 3.4 6L4 21l4.3-2.2c1.2.3 2.4.5 3.7.5 5.5 0 10-3.6 10-8S17.5 3 12 3z"/></svg>',
  blok: '<b style="font:900 26px/1 \'Big Shoulders Display\',Impact,sans-serif;color:#fff">B</b>',
  gigs: '<svg viewBox="0 0 24 24"><path d="M9 4h6a2 2 0 0 1 2 2v1h3a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V9a2 2 0 0 1 2-2h3V6a2 2 0 0 1 2-2zm0 3h6V6H9v1z"/></svg>',
  maps: '<svg viewBox="0 0 24 24"><path d="M12 2a7 7 0 0 0-7 7c0 5.2 7 13 7 13s7-7.8 7-13a7 7 0 0 0-7-7zm0 9.5A2.5 2.5 0 1 1 12 6.5a2.5 2.5 0 0 1 0 5z"/></svg>',
  camera: '<svg viewBox="0 0 24 24"><path d="M9 4l-1.8 2H4a2 2 0 0 0-2 2v10a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-3.2L15 4H9zm3 4.5a4.5 4.5 0 1 1 0 9 4.5 4.5 0 0 1 0-9z"/></svg>',
  garage: '<svg viewBox="0 0 24 24"><path d="M5 11l1.5-4.5A2 2 0 0 1 8.4 5h7.2a2 2 0 0 1 1.9 1.5L19 11a2 2 0 0 1 2 2v4h-2v2h-3v-2H8v2H5v-2H3v-4a2 2 0 0 1 2-2zm2.2 0h9.6l-1-3H8.2l-1 3zM6.5 15.5a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3zm11 0a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3z"/></svg>',
  music: '<svg viewBox="0 0 24 24"><path d="M19 3v12.5a3.5 3.5 0 1 1-2-3.2V7.3L9 9v8.5A3.5 3.5 0 1 1 7 14.3V5l12-2z"/></svg>',
  live: '<svg viewBox="0 0 24 24"><path d="M4 20V10h3v10H4zm6.5 0V4h3v16h-3zM17 20v-7h3v7h-3z"/></svg>',
  pad: '<svg viewBox="0 0 24 24"><path d="M7 6h10a5 5 0 0 1 4.9 6l-1 5a3 3 0 0 1-5.2 1.4L14 16h-4l-1.7 2.4A3 3 0 0 1 3.1 17l-1-5A5 5 0 0 1 7 6zm0 3v2H5v2h2v2h2v-2h2v-2H9V9H7zm9.5 1a1.2 1.2 0 1 0 0 2.4 1.2 1.2 0 0 0 0-2.4zm2 2.6a1.2 1.2 0 1 0 0 2.4 1.2 1.2 0 0 0 0-2.4z"/></svg>',
  gang: '<svg viewBox="0 0 24 24"><path d="M12 4a3 3 0 1 1 0 6 3 3 0 0 1 0-6zM5.5 6.5a2.5 2.5 0 1 1 0 5 2.5 2.5 0 0 1 0-5zm13 0a2.5 2.5 0 1 1 0 5 2.5 2.5 0 0 1 0-5zM12 12c3.3 0 6 1.8 6 4v3H6v-3c0-2.2 2.7-4 6-4zm-6.5.5c.5 0 1 .1 1.4.2A5 5 0 0 0 4.6 16v3H1v-2.5c0-2.2 2-4 4.5-4zm13 0c2.5 0 4.5 1.8 4.5 4V19h-3.6v-3a5 5 0 0 0-2.3-3.3c.4-.1.9-.2 1.4-.2z"/></svg>',
  settings: '<svg viewBox="0 0 24 24"><path d="M19.4 13a7.5 7.5 0 0 0 0-2l2.1-1.6-2-3.5-2.5 1a7.3 7.3 0 0 0-1.7-1L15 3h-4l-.3 2.9a7.3 7.3 0 0 0-1.7 1l-2.5-1-2 3.5L6.6 11a7.5 7.5 0 0 0 0 2l-2.1 1.6 2 3.5 2.5-1c.5.4 1.1.7 1.7 1L11 21h4l.3-2.9c.6-.3 1.2-.6 1.7-1l2.5 1 2-3.5-2.1-1.6zM13 15.5a3.5 3.5 0 1 1 0-7 3.5 3.5 0 0 1 0 7z"/></svg>',
};
const APPS = {
  msgs: { name: 'Messages', bg: 'linear-gradient(#65f07f,#25c046)' },
  blok: { name: 'Blok', bg: 'linear-gradient(135deg,#ff4f81,#ff9a3c)' },
  gigs: { name: 'Gigs', bg: 'linear-gradient(#ffc061,#ff7a1a)' },
  maps: { name: 'Maps', bg: 'linear-gradient(#5ac8fa,#0a84ff)' },
  camera: { name: 'Camera', bg: 'linear-gradient(#9a9aa0,#3a3a3c)' },
  garage: { name: 'Garage', bg: 'linear-gradient(#34d65f,#0a7a3a)' },
  music: { name: 'Music', bg: 'linear-gradient(#ff4a6e,#c5103a)' },
  live: { name: 'Live', bg: 'linear-gradient(#c36bff,#5e2ab8)' },
  settings: { name: 'Settings', bg: 'linear-gradient(#9a9aa0,#48484a)' },
  pad: { name: 'Controller', bg: 'linear-gradient(#3a4250,#15181d)' },
  gang: { name: 'Gang', bg: 'linear-gradient(#ff6a3a,#a8162a)' },
};
function appBadge(id) {
  if (id === 'msgs') return Object.values(S.unread).reduce((a, b) => a + b, 0);
  if (id === 'gang') return GANG.invites.length;
  if (id === 'gigs') return JOBS.filter(j => jobAvailable(j.id) && ['showcase', 'reyes', 'saint', 'diss'].includes(j.id)).length;
  return 0;
}
function renderHome() {
  const mk = id => { const A = APPS[id]; const n = appBadge(id); return `<button class="app" data-app="${id}"><i style="background:${A.bg}">${ICON[id]}</i><span>${A.name}</span>${n ? `<em>${n}</em>` : ''}</button>`; };
  $('ph-grid').innerHTML = ['gigs', 'gang', 'garage', 'music', 'settings', 'live', 'pad'].map(mk).join('');
  $('ph-dock').innerHTML = ['msgs', 'blok', 'maps', 'camera'].map(mk).join('');
  document.querySelectorAll('#phone .app').forEach(b => b.onclick = () => openApp(b.dataset.app));
  $('ph-wt').textContent = clockStr().replace(/ (AM|PM)/, '');
  $('ph-wd').textContent = `Day ${S.day} · ${tempF()}°F · Calder Park`;
}
function openPhone(app) {
  sfx.lock();
  if (MODE !== 'play') return;
  MODE = 'phone'; unlockPointer(); P.aiming = false; mouse.left = mouse.right = false;
  $('phone').hidden = false;
  PHONE.selfie = false; PHONE.photo = null;
  if (app) openApp(app); else { PHONE.app = null; $('ph-app').hidden = true; renderHome(); }
  phoneClock(); sfx.ui();
}
function closePhone() { sfx.lock(); $('phone').hidden = true; PHONE.selfie = false; PHONE.app = null; MODE = 'play'; lockPointer(); }
function phoneClock() { $('ph-time').textContent = clockStr().replace(/ (AM|PM)/, ''); }
function goHome() { PHONE.app = null; PHONE.selfie = false; PHONE.photo = null; $('ph-app').hidden = true; renderHome(); }
$('ph-homebar').onclick = () => goHome();
$('pa-back').onclick = () => { if (PHONE.app === 'msgs' && PHONE.thread) { PHONE.thread = null; renderApp(); } else goHome(); };
function openApp(id) { PHONE.app = id; PHONE.thread = null; PHONE.photo = null; PHONE.selfie = false; $('ph-app').hidden = false; $('ph-app').style.animation = 'none'; void $('ph-app').offsetWidth; $('ph-app').style.animation = ''; renderApp(); }
function renderApp() {
  if ($('phone').hidden || !PHONE.app) return;
  const id = PHONE.app, body = $('pa-body'), act = $('pa-act');
  $('pa-title').textContent = id === 'msgs' && PHONE.thread ? CAST[PHONE.thread].name : APPS[id].name;
  act.textContent = ''; act.onclick = null;
  body.innerHTML = '';
  const add = html => { const d = document.createElement('div'); d.innerHTML = html; while (d.firstChild) body.append(d.firstChild); };
  if (id === 'msgs') {
    if (PHONE.thread) {
      const k = PHONE.thread; S.unread[k] = 0;
      add(`<div class="sec" style="text-align:center">${esc(CAST[k].role)}</div>`);
      for (const m of S.threads[k]) { const d = document.createElement('div'); d.className = 'bub'; d.textContent = m.text; body.append(d); }
      body.scrollTop = 1e6;
    } else {
      const ks = Object.keys(CAST).filter(k => S.threads[k].length).sort((a, b) => S.threads[b][S.threads[b].length - 1].t - S.threads[a][S.threads[a].length - 1].t);
      if (!ks.length) add('<div class="empty">No messages yet.</div>');
      for (const k of ks) { const last = S.threads[k][S.threads[k].length - 1]; add(`<button class="list-row" data-th="${k}"><span class="av" style="--c:${CAST[k].color}">${CAST[k].init}</span><span style="min-width:0"><span class="lr-n">${esc(CAST[k].name)}</span><br><span class="lr-t">${esc(last.text)}</span></span>${S.unread[k] ? '<span class="dot-u"></span>' : '<span></span>'}</button>`); }
      body.querySelectorAll('[data-th]').forEach(b => b.onclick = () => { PHONE.thread = b.dataset.th; renderApp(); });
    }
  } else if (id === 'gigs') {
    for (const j of JOBS.filter(j => jobAvailable(j.id) || j.lock || (j.cd && cdLeft(j.cd) > 0 && j.avail()))) {
      const av = jobAvailable(j.id), w = av ? j.where() : null, cd = j.cd ? cdLeft(j.cd) : 0, active = S.job && S.job.id === j.id;
      const status = active ? 'Active' : av ? Math.round(Math.hypot(w.x - P.pos.x, w.z - P.pos.z)) + ' m · ' + streetName(w.x, w.z) : cd > 0 && j.avail() ? `Back in ${Math.floor(cd / 60)}:${String(Math.floor(cd % 60)).padStart(2, '0')}` : (j.lock ? j.lock() : 'Not now');
      add(`<div class="job ${S.tracked === j.id ? 'trk' : ''}" style="--c:${CAST[j.giver].color};${av ? '' : 'opacity:.5'}"><div class="job-t"><b>${esc(j.title)}</b><span>${esc(CAST[j.giver].name)}</span></div><div class="job-d">${esc(j.desc())}</div><div class="job-r">${j.chips().map(([k, t]) => `<span class="chip ${k}">${esc(t)}</span>`).join('')}${av ? `<button class="pill ${S.tracked === j.id ? 'on' : ''}" data-track="${j.id}">${S.tracked === j.id ? 'Tracking' : 'Track'}</button>` : ''}</div><div class="job-s">${esc(status)}</div></div>`);
    }
    body.querySelectorAll('[data-track]').forEach(b => b.onclick = () => { S.waypoint = null; trackJob(b.dataset.track); MM.routeT = 0; renderApp(); });
  } else if (id === 'blok') renderBlok(body, add, act);
  else if (id === 'maps') {
    add('<canvas id="ph-map" width="600" height="600"></canvas><div class="legend"></div><div class="job-s" style="margin-top:8px">Tap the map to drop a waypoint.</div>');
    const cv = $('ph-map'); drawBigMap(cv);
    cv.onclick = e => { const r = cv.getBoundingClientRect(); const x = (e.clientX - r.left) / r.width * 2 * MAP_HALF - MAP_HALF, z = (e.clientY - r.top) / r.height * 2 * MAP_HALF - MAP_HALF; S.waypoint = { x, z }; MM.routeT = 0; drawBigMap(cv); act.textContent = 'Clear'; sfx.ui(); };
    act.textContent = S.waypoint ? 'Clear' : ''; act.onclick = () => { S.waypoint = null; renderApp(); };
    body.querySelector('.legend').innerHTML = [['#fff', 'You'], ['#7be0a6', 'Your car'], ['#ff7a2a', 'Fire barrels'], ['#4aa3ff', 'Players'], ['#ff4b3a', 'Halo crew']].map(([c, t]) => `<span><i style="--c:${c}"></i>${t}</span>`).join('') + `<span>Next L at Calder: ${Math.ceil(nextTrainIn())}s</span>`;
  } else if (id === 'camera') renderCamera(body, add);
  else if (id === 'garage') {
    add('<div class="sec">Your cars</div>');
    S.garage.forEach((g, i) => { const sp = CAR_SPECS[g.model]; const out = OWN_CAR && !OWN_CAR.dead && OWN_CAR.model === g.model && OWN_CAR.color === g.color; add(`<div class="car-row"><span class="swatch" style="background:#${new THREE.Color(g.color).getHexString()}"></span><span><b>${esc(sp.name)}</b><span>${out ? Math.round(Math.hypot(OWN_CAR.pos.x - P.pos.x, OWN_CAR.pos.z - P.pos.z)) + ' m away' : 'In the garage'}</span></span><button class="pill blue" data-del="${i}">Deliver</button></div>`); });
    add(`<div class="sec">Marrow Motors · Calder Ave</div>`);
    for (const m of ['sedan', 'suv', 'pickup', 'van', 'coupe']) {
      const sp = CAR_SPECS[m], owned = S.garage.some(g => g.model === m), can = S.cash >= sp.price && S.buzz >= sp.buzz;
      const col = PHONE.carColor[m] || CAR_PAINTS[0];
      add(`<div class="car-row"><button class="swatch" data-col="${m}" style="background:#${new THREE.Color(col).getHexString()}" aria-label="Change color"></button><span><b>${esc(sp.name)}</b><span>${fmtMoney(sp.price)} · Buzz ${sp.buzz} · top ${Math.round(sp.top * 2.237)} mph</span></span><button class="pill ${can ? 'on' : ''}" data-buy="${m}" ${can ? '' : 'disabled style="opacity:.45"'}>${owned ? 'Buy again' : 'Buy'}</button></div>`);
    }
    add('<div class="job-s">Tap a swatch to change the paint before you buy.</div>');
    body.querySelectorAll('[data-del]').forEach(b => b.onclick = () => { if (P.car) { toast(null, 'Get out of this car first', '#ffb347'); return; } const v = spawnOwnedCar(+b.dataset.del, true); if (v) { toast(null, `${v.sp.name} delivered nearby`, '#7be0a6'); S.waypoint = { x: v.pos.x, z: v.pos.z }; } renderApp(); });
    body.querySelectorAll('[data-col]').forEach(b => b.onclick = () => { const m = b.dataset.col; const i = CAR_PAINTS.indexOf(PHONE.carColor[m] || CAR_PAINTS[0]); PHONE.carColor[m] = CAR_PAINTS[(i + 1) % CAR_PAINTS.length]; renderApp(); });
    body.querySelectorAll('[data-buy]').forEach(b => b.onclick = () => { const m = b.dataset.buy, sp = CAR_SPECS[m]; if (S.cash < sp.price || S.buzz < sp.buzz) return; addCash(-sp.price); S.garage.push({ model: m, color: PHONE.carColor[m] || CAR_PAINTS[0] }); toast(null, `${sp.name} is yours`, '#7be0a6'); addSocialPost('photo', 'new whip 🥶 ' + sp.name, null); saveGame(); renderApp(); });
  } else if (id === 'music') {
    add(`<div class="stat-g"><div><b>${S.stats.tracks}</b><span>Tracks</span></div><div><b>${S.stats.best ? S.stats.best.grade : '–'}</b><span>Best grade</span></div></div>`);
    add('<div class="sec">Your tracks</div>');
    if (!S.tracks.length) add('<div class="empty">No tracks yet. Basement 808 is on Calder Ave by the Mini Mart.</div>');
    S.tracks.slice().reverse().slice(0, 20).forEach((t, i) => { const idx = S.tracks.length - 1 - i; const playing = PHONE.preview && PHONE.preview.idx === idx; add(`<div class="row"><span>${esc(t.title)}<br><span style="font-size:12px;color:#8a96a2">${({ chi: 'Chicago', uk: 'UK', ny: 'NY' })[t.style || 'chi']} drill · ${t.type === 'wayout' ? 'way out' : t.type}</span></span><span><span class="g">${t.grade}</span> <button class="pill ${playing ? 'on' : 'blue'}" data-play="${idx}">${playing ? 'Stop' : 'Play'}</button></span></div>`); });
    body.querySelectorAll('[data-play]').forEach(b => b.onclick = () => { const i = +b.dataset.play; if (PHONE.preview && PHONE.preview.idx === i) stopPreview(); else playPreview(i); renderApp(); });
  } else if (id === 'live') {
    const st = S.stats;
    add(`<div class="stat-g"><div><b>@${esc(S.name)}</b><span>${buzzTier(S.buzz)} · ${heatTier(S.heat)} heat</span></div><div><b>${socialFollowers().toLocaleString('en-US')}</b><span>Followers</span></div><div><b>${st.tracks}</b><span>Tracks</span></div><div><b>${Object.keys(S.endings).length}/4</b><span>Endings</span></div></div>`);
    add('<div class="sec">On the block now</div>');
    if (NET.status === 'solo') add(`<div class="empty" style="text-align:left;padding:6px 2px">Playing solo. ${location.protocol === 'file:' ? 'Open the game from its web address (not a saved file) to play with others.' : 'This browser could not open a peer-to-peer connection, so other players cannot reach you.'}</div>`);
    else if (NET.p2p) add(`<div class="empty" style="text-align:left;padding:6px 2px">${NET.status === 'live' ? 'Connected' : 'Looking for players'} · peer-to-peer. Everyone who opens this page joins the same block.</div>`);
    else { add(`<div class="row"><span><span style="color:#ffb347">●</span> @${esc(S.name)} (you)</span><span class="g">${heatTier(S.heat)}</span></div>`); for (const R of NET.remotes.values()) add(`<div class="row"><span><span style="color:${R.col}">●</span> @${esc(R.name)}${R.veh ? ' · driving' : ''}${R.wl ? ' · wanted ' + R.wl : ''}</span><span class="g">${Math.round(R.pos.distanceTo(P.pos))} m</span></div>`); }
    add('<div class="sec">Charts · top Buzz</div>');
    const chart = NET.players.length ? [...NET.players].sort((a, b) => (b.buzz || 0) - (a.buzz || 0)).slice(0, 15) : [{ id: NET.uid, name: S.name, buzz: Math.round(S.buzz), best: S.stats.best }];
    chart.forEach((p, i) => add(`<div class="row"><span>${i + 1}. @${esc(cleanName(p.name))}${p.id === NET.uid ? ' (you)' : ''}${p.best ? ` <span style="color:#6e7a86">· ${esc(String(p.best.title).slice(0, 20))}</span>` : ''}</span><span class="g">${Math.round(p.buzz || 0)}</span></div>`));
  } else if (id === 'pad') {
    renderPadApp(body, add);
  } else if (id === 'gang') {
    renderGangApp(body, add);
  } else if (id === 'settings') {
    const st = S.settings;
    add(`<div class="set-row"><span>Look speed</span><input type="range" id="ps-sens" min="0.3" max="2.5" step="0.05" value="${st.sens}"><output>${(+st.sens).toFixed(1)}</output></div>
      <div class="set-row"><span>Volume</span><input type="range" id="ps-vol" min="0" max="1" step="0.05" value="${st.vol}"><output>${Math.round(st.vol * 100)}</output></div>
      <div class="set-row"><span>Music</span><input type="range" id="ps-music" min="0" max="1" step="0.05" value="${st.music}"><output>${Math.round(st.music * 100)}</output></div>
      <div class="sec">Sound check</div><div class="set-row" style="display:block"><div id="ps-audio" style="font:500 12px/1.4 var(--f-mono);color:var(--ink-2);margin-bottom:8px">${esc(audioInfo())}</div><button class="btn" id="ps-test" style="width:100%">Play test sound</button></div>
      <div class="sec">Camera</div><div class="seg"><button data-fp="0" class="${!st.fp ? 'on' : ''}">Third person<small>over the shoulder</small></button><button data-fp="1" class="${st.fp ? 'on' : ''}">First person<small>V to switch</small></button></div>
      <div class="set-row"><span>Field of view</span><input type="range" id="ps-fov" min="60" max="95" step="1" value="${st.fov || 70}"><output>${Math.round(st.fov || 70)}</output></div>
      <div class="sec">Graphics</div><div class="seg"><button data-q="high" class="${!LITE_MODE && st.quality !== 'low' ? 'on' : ''}">High<small>shadows · AA</small></button><button data-q="low" class="${!LITE_MODE && st.quality === 'low' ? 'on' : ''}">Fast<small>no shadows</small></button><button data-q="lite" class="${LITE_MODE ? 'on' : ''}">Simple<small>for consoles · old browsers</small></button></div>
      ${LITE_MODE && PLAT.webgl === false ? '<div class="job-s">This browser has no WebGL, so the game draws with its simple renderer.</div>' : ''}
      <div class="sec">Car radio</div><div class="seg seg-wrap">${STATIONS.map((n, i) => `<button data-r="${i}" class="${st.radio === i ? 'on' : ''}">${n.short}</button>`).join('')}</div>
      <div class="sec">Audio</div><div class="seg"><button data-sc="1" class="${st.score !== false ? 'on' : ''}">Score<small>music on foot</small></button><button data-sc="0" class="${st.score === false ? 'on' : ''}">No score<small>city only</small></button></div>
      <div class="seg"><button data-vo="1" class="${st.voices !== false ? 'on' : ''}">Voices<small>PA · megaphone</small></button><button data-vo="0" class="${st.voices === false ? 'on' : ''}">Mute voices<small>subtitles only</small></button></div>
      <div class="sec">Game</div>${document.fullscreenEnabled ? `<button class="btn" id="ps-fs" style="width:100%;margin-bottom:8px">${document.fullscreenElement ? 'Leave full screen' : 'Full screen'}</button>` : ''}<button class="btn" id="ps-export" style="width:100%;margin-bottom:8px">Export my progress</button><div class="job-s" style="margin:-2px 0 10px">Saves drill-season-save.json to Downloads. The Godot version of the game imports it from there.</div><button class="btn" id="ps-exit" style="width:100%">Save &amp; exit to title</button>`);
    const bind = (id2, key, f) => { const el = $(id2); el.oninput = () => { st[key] = +el.value; el.nextElementSibling.textContent = f(+el.value); applyVolumes(); }; };
    bind('ps-sens', 'sens', v => v.toFixed(1)); bind('ps-fov', 'fov', v => Math.round(v));
    body.querySelectorAll('[data-fp]').forEach(b => b.onclick = () => { st.fp = b.dataset.fp === '1'; if (!st.fp) fpHide(); renderApp(); }); bind('ps-vol', 'vol', v => Math.round(v * 100)); bind('ps-music', 'music', v => Math.round(v * 100));
    body.querySelectorAll('[data-q]').forEach(b => b.onclick = () => {
      const q = b.dataset.q, wantLite = q === 'lite';
      if (wantLite !== LITE_MODE && PLAT.webgl !== false) { try { localStorage.setItem('ds.lite', wantLite ? '1' : '0'); } catch (e) { } if (!wantLite) st.quality = q; saveGame(); location.replace(location.pathname + location.hash); return; }
      if (!wantLite) { st.quality = q; applyQuality(); } renderApp();
    });
    body.querySelectorAll('[data-r]').forEach(b => b.onclick = () => { st.radio = +b.dataset.r; radioRefresh(true); renderApp(); });
    body.querySelectorAll('[data-sc]').forEach(b => b.onclick = () => { st.score = b.dataset.sc === '1'; renderApp(); });
    body.querySelectorAll('[data-vo]').forEach(b => b.onclick = () => { st.voices = b.dataset.vo === '1'; if (!st.voices && window.speechSynthesis) speechSynthesis.cancel(); renderApp(); });
    $('ps-exit').onclick = () => { closePhone(); exitToTitle(); };
    $('ps-export').onclick = () => { exportProgress(); };
    if ($('ps-fs')) $('ps-fs').onclick = () => { const p = document.fullscreenElement ? document.exitFullscreen() : document.documentElement.requestFullscreen(); if (p && p.then) p.then(() => setTimeout(renderApp, 200), () => { }); };
    $('ps-test').onclick = () => { soundTest(); setTimeout(() => { const el = $('ps-audio'); if (el) el.textContent = audioInfo(); }, 400); };
  }
}
/* the whole save as a file, for the Godot version (Settings → Import progress there).
   Inside claude.ai the page cannot start downloads itself, so it asks the viewer through
   the downloads capability; anywhere else it uses a plain download link. */
async function exportProgress() {
  saveGame();
  const json = JSON.stringify(S, null, 1), name = 'drill-season-save.json';
  const done = () => toast(null, 'Progress exported: ' + name + '. Import it in the Godot version.', '#4cd98a');
  const C = window.claude;
  if (C && typeof C.use === 'function' && !NET.p2p) {
    let dl = null;
    try { dl = await C.use('downloads'); } catch (e) { dl = null; }
    if (dl) {
      try { await dl.save({ filename: name, data: json }); done(); }
      catch (e) { if (e && e.code !== 'declined') toast(null, 'Could not save the file here', '#ff6b5a'); }
      return;
    }
  }
  try {
    const blob = new Blob([json], { type: 'application/json' });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob); a.download = name;
    document.body.appendChild(a); a.click(); a.remove();
    setTimeout(() => URL.revokeObjectURL(a.href), 4000);
    done();
  } catch (e) { toast(null, 'This browser cannot save files', '#ff6b5a'); }
}
const ago = ms => { const s = Math.max(0, (Date.now() - ms) / 1000); return s < 60 ? 'now' : s < 3600 ? Math.floor(s / 60) + 'm' : s < 86400 ? Math.floor(s / 3600) + 'h' : Math.floor(s / 86400) + 'd'; };
function renderBlok(body, add, act) {
  add(`<div class="seg"><button data-bt="feed" class="${PHONE.blokTab === 'feed' ? 'on' : ''}">Feed</button><button data-bt="me" class="${PHONE.blokTab === 'me' ? 'on' : ''}">Profile</button></div>`);
  act.textContent = 'Post'; act.onclick = () => openApp('camera');
  const avatar = (h, col) => `<span class="av" style="--c:${col}">${esc(String(h).replace('@', '').slice(0, 2).toUpperCase())}</span>`;
  if (PHONE.blokTab === 'me') {
    const mine = S.social.posts;
    add(`<div class="prof">${avatar(S.name, '#ffb347')}<div><b style="font-size:17px">@${esc(S.name)}</b><div style="font-size:13px;color:#9aa6b2;margin:2px 0 8px">${esc(S.social.bio)}</div><div class="pc"><div><b>${mine.length}</b><span>posts</span></div><div><b>${socialFollowers().toLocaleString('en-US')}</b><span>followers</span></div><div><b>${S.social.following}</b><span>following</span></div></div></div></div>`);
    add('<div class="grid3">' + (mine.length ? mine.map(p => p.img ? `<img src="${p.img}" alt="">` : `<div>${esc(p.caption)}</div>`).join('') : '<div>No posts yet</div><div></div><div></div>') + '</div>');
  } else {
    const posts = [];
    for (const p of S.social.posts) posts.push({ h: '@' + S.name, col: '#ffb347', at: p.at, text: p.caption, img: p.img, likes: p.likes, comments: p.comments });
    for (const f of S.feed) posts.push({ h: f.h, col: '#5a6a7a', at: f.at, text: f.text, likes: f.likes });
    for (const pl of NET.players) {
      if (pl.id === NET.uid) continue;
      const col = hashColor(cleanName(pl.name));
      for (const ph of (pl.photos || [])) posts.push({ h: '@' + cleanName(pl.name), col, at: +ph.at || 0, text: ph.cap, img: typeof ph.img === 'string' && ph.img.startsWith('data:image/') ? ph.img : null, likes: ph.likes | 0, live: true });
      for (const p of (pl.posts || []).slice(0, 3)) if (p.k !== 'photo') posts.push({ h: '@' + cleanName(pl.name), col, at: +p.at || 0, text: netPostText(pl.name, p), live: true });
    }
    posts.sort((a, b) => b.at - a.at);
    if (!posts.length) add('<div class="empty">Nothing yet. Post a photo from the Camera.</div>');
    for (const p of posts.slice(0, 40)) {
      const d = document.createElement('div'); d.className = 'post';
      d.innerHTML = `<div class="post-h">${avatar(p.h, p.col)}<b></b>${p.live ? '<span class="tag">PLAYER</span>' : ''}<span>${ago(p.at)}</span></div>${p.img ? '<img alt="">' : ''}<div class="post-t"></div>${p.likes !== undefined ? `<div class="post-l">♥ ${Number(p.likes).toLocaleString('en-US')} likes</div>` : ''}`;
      d.querySelector('b').textContent = p.h; d.querySelector('.post-t').textContent = p.text || '';
      if (p.img) d.querySelector('img').src = p.img;
      if (p.comments) for (const c of p.comments.slice(-2)) { const cc = document.createElement('div'); cc.className = 'post-c'; const b = document.createElement('b'); b.textContent = c.h + ' '; cc.append(b, document.createTextNode(c.t)); d.append(cc); }
      body.append(d);
    }
  }
  body.querySelectorAll('[data-bt]').forEach(b => b.onclick = () => { PHONE.blokTab = b.dataset.bt; renderApp(); });
}
const CAPTIONS = ['Calder never sleeps', 'cold out here 🥶', 'new music soon', 'the Hawk is disrespectful', 'Bishop St forever', 'under the L', 'studio tonight', 'day ones only'];
function renderCamera(body, add) {
  if (PHONE.photo) {
    add(`<div class="cam-vf"><img src="${PHONE.photo}" alt="Your photo"></div><div class="sec">Caption</div><div class="cap-list">${CAPTIONS.map(c => `<button data-cap="${esc(c)}" class="${PHONE.cap === c ? 'on' : ''}">${esc(c)}</button>`).join('')}</div><input id="cap-in" maxlength="80" placeholder="Or write your own" value="${esc(PHONE.capText || '')}"><div class="cam-ctl"><button class="btn" id="cam-retake">Retake</button><button class="btn primary" id="cam-post">Post to Blok</button></div>`);
    body.querySelectorAll('[data-cap]').forEach(b => b.onclick = () => { PHONE.cap = b.dataset.cap; PHONE.capText = ''; renderApp(); });
    $('cap-in').oninput = e => { PHONE.capText = e.target.value; PHONE.cap = null; };
    $('cap-in').onkeydown = e => e.stopPropagation();
    $('cam-retake').onclick = () => { PHONE.photo = null; renderApp(); };
    $('cam-post').onclick = () => { const cap = (PHONE.capText || PHONE.cap || pick(CAPTIONS)).trim(); addSocialPost('photo', cap, PHONE.photo); PHONE.photo = null; PHONE.capText = ''; PHONE.cap = null; toast('blok', 'Posted. Likes are coming in.'); PHONE.blokTab = 'me'; openApp('blok'); };
    return;
  }
  add(`<div class="cam-vf"><canvas id="cam-vf" width="480" height="270"></canvas></div><div class="seg" style="margin-top:12px"><button data-m="rear" class="${PHONE.selfie ? '' : 'on'}">Photo</button><button data-m="selfie" class="${PHONE.selfie ? 'on' : ''}">Selfie</button></div><div class="cam-ctl"><button class="shutter" id="cam-shot" aria-label="Take photo"></button></div><div class="job-s" style="text-align:center">Photos post to Blok, where other players see them.</div>`);
  body.querySelectorAll('[data-m]').forEach(b => b.onclick = () => { PHONE.selfie = b.dataset.m === 'selfie'; body.querySelectorAll('[data-m]').forEach(x => x.classList.toggle('on', x === b)); });
  $('cam-shot').onclick = () => { PHONE.wantShot = true; };
}
// runs right after each frame is rendered, while the drawing buffer is still valid
function phoneAfterRender() {
  if (MODE !== 'phone' || PHONE.app !== 'camera' || PHONE.photo) return;
  const src = renderer.domElement, sw = src.width, sh = src.height;
  const tw = Math.min(sw, sh * 16 / 9), th = tw * 9 / 16, sx = (sw - tw) / 2, sy = (sh - th) / 2;
  if (PHONE.wantShot) {
    PHONE.wantShot = false;
    const c = document.createElement('canvas'); c.width = 480; c.height = 270;
    c.getContext('2d').drawImage(src, sx, sy, tw, th, 0, 0, 480, 270);
    PHONE.photo = c.toDataURL('image/jpeg', 0.72); sfx.shutter(); renderApp(); return;
  }
  const vf = $('cam-vf'); if (vf) vf.getContext('2d').drawImage(src, sx, sy, tw, th, 0, 0, 480, 270);
}
function playPreview(idx) {
  stopPreview(); initAudio(); if (!AU.ready) return;
  const t = S.tracks[idx]; const beat = buildBeat(t.seed || (t.title.length * 7919), t.type || 'wayout', t.style || 'chi');
  const B = makeBus(AU.music, { gain: 0.5 }); scheduleBeat(B, beat, AU.ctx.currentTime + 0.1);
  PHONE.preview = { idx, B, end: setTimeout(() => { if (PHONE.preview && PHONE.preview.B === B) { PHONE.preview = null; if (PHONE.app === 'music') renderApp(); } }, beat.dur * 1000 + 300) };
}
function stopPreview() { if (PHONE.preview) { killBus(PHONE.preview.B); clearTimeout(PHONE.preview.end); PHONE.preview = null; } }
function drawBigMap(cv) {
  if (!MAP.c) buildStaticMap();
  const g = cv.getContext('2d'), W = cv.width, s = W / (2 * MAP_HALF), X = x => (x + MAP_HALF) * s;
  g.drawImage(MAP.c, 0, 0, W, W);
  const lm = [[LOC.studio, 'Basement 808'], [LOC.store, 'Mini Mart'], [LOC.rec, 'Rec'], [LOC.home, 'Home'], [{ x: 70, z: 0 }, 'Calder L'], [POND, 'Pond'], [LOC.station, 'Area 7'], [LOC.hospital, 'Hospital'], [LOC.dealer, 'Marrow Motors'], [LOC.court, 'Garnet Courts'], [LOC.gas, 'Ironside Fuel'], [LOC.lakefront, 'Lakefront'], [LOC.yard, 'Rail yard']];
  g.font = '700 13px Inter, sans-serif';
  for (const [p, t] of lm) { g.fillStyle = '#fff'; g.fillRect(X(p.x) - 3, X(p.z) - 3, 6, 6); g.fillStyle = 'rgba(255,255,255,.85)'; g.fillText(t, X(p.x) + 6, X(p.z) - 5); }
  for (const B of BARRELS) { g.fillStyle = '#ff7a2a'; g.beginPath(); g.arc(X(B.x), X(B.z), 4, 0, TAU); g.fill(); }
  for (const j of JOBS) { if (!jobAvailable(j.id)) continue; const w = j.where(); if (!w) continue; g.fillStyle = CAST[j.giver].color; const r = S.tracked === j.id ? 9 : 6; g.beginPath(); g.moveTo(X(w.x), X(w.z) - r); g.lineTo(X(w.x) + r, X(w.z)); g.lineTo(X(w.x), X(w.z) + r); g.lineTo(X(w.x) - r, X(w.z)); g.fill(); }
  if (OWN_CAR && !OWN_CAR.dead) { g.fillStyle = '#7be0a6'; g.fillRect(X(OWN_CAR.pos.x) - 5, X(OWN_CAR.pos.z) - 4, 10, 8); }
  for (const R of NET.remotes.values()) { g.fillStyle = R.col; g.beginPath(); g.arc(X(R.pos.x), X(R.pos.z), 6, 0, TAU); g.fill(); }
  for (const e of ENEMIES) if (e.state !== 'down') { g.fillStyle = '#ff4b3a'; g.beginPath(); g.arc(X(e.pos.x), X(e.pos.z), 4, 0, TAU); g.fill(); }
  if (S.waypoint) { g.fillStyle = '#c79bff'; g.beginPath(); g.arc(X(S.waypoint.x), X(S.waypoint.z), 8, 0, TAU); g.fill(); }
  g.save(); g.translate(X(P.pos.x), X(P.pos.z)); g.rotate(Math.PI - P.bodyYaw); g.fillStyle = '#fff'; g.strokeStyle = '#000'; g.lineWidth = 2; g.beginPath(); g.moveTo(0, -11); g.lineTo(7, 8); g.lineTo(0, 4); g.lineTo(-7, 8); g.closePath(); g.stroke(); g.fill(); g.restore();
}

/* =========================================================
   ENDINGS (a cutscene first, then the stats)
   ========================================================= */
const ENDINGS = {
  wayout: { title: 'Way Out', color: '#7be0a6', line: 'The rec center showcase. Buzz high, Heat low, and a stage that was yours.' },
  witness: { title: 'Witness', color: '#7cc8ff', line: () => `You sat in ${CAST.reyes.name}'s car under the L and talked. Your Heat is cleared. The block remembers.` },
  crown: { title: 'Crown', color: '#ffd166', line: () => `${CAST.saint.name} went down in the snow. Calder Ave is yours, and so is everything that comes with it.` },
  locked: { title: 'Locked Up', color: '#ff5a4e', line: () => `Heat hit the ceiling. ${CAST.reyes.name} came for you.` },
};
let pendingEnding = null;
function triggerEnding(id) {
  if (MODE === 'ending' || pendingEnding) return;
  pendingEnding = id;
  if (P.car) exitVehicle();
  for (const el of ['menu', 'phone', 'bench', 'rhythm', 'pause']) $(el).hidden = true;
  $('hud').hidden = false;
  MODE = 'play';
  playCutscene(cutEnding(id), () => showEnding(id));
}
function showEnding(id) {
  const E = ENDINGS[id];
  S.endings[id] = (S.endings[id] || 0) + 1;
  MODE = 'ending'; unlockPointer();
  $('hud').hidden = true;
  const st = S.stats;
  $('en-eyebrow').textContent = `Ending · @${S.name} · day ${S.day}`;
  $('en-title').textContent = E.title; $('ending').style.setProperty('--c', E.color);
  $('en-line').textContent = typeof E.line === 'function' ? E.line() : E.line;
  const cells = [
    ['Buzz peak', Math.round(st.buzzPeak)], ['Heat peak', Math.round(st.heatPeak)], ['Tracks', st.tracks], ['Best track', st.best ? `${st.best.title} (${st.best.grade})` : 'none'],
    ['Followers', socialFollowers().toLocaleString('en-US')], ['Walk-aways', st.walkAways], ['Rides for sis', st.rides], ['Cash earned', fmtMoney(st.cashEarned)],
    ['Fights', st.fights], ['Busted', st.busted || 0], ['Miles driven', ((st.drive || 0) / 1609).toFixed(1)], ['Cold time', Math.round(st.coldTime / 60) + ' min'],
  ];
  $('en-stats').innerHTML = cells.map(([k, v]) => `<div><b>${esc(v)}</b><span>${k}</span></div>`).join('');
  $('en-found').innerHTML = Object.entries(ENDINGS).map(([k, e]) => `<span class="${S.endings[k] ? 'got' : ''}">${e.title}</span>`).join('');
  $('ending').hidden = false;
  netPost({ k: 'ending', e: id });
  postFeed(pick(FEED_HANDLES), { wayout: `${n_()} shut down the rec showcase. that's a way out 🙏`, witness: `heard ${n_()} been talking to detectives... block is quiet tonight`, crown: `${n_()} vs @saint.halo is OVER. new name on Calder`, locked: `${n_()} got picked up under the L. free ${n_()}` }[id]);
  saveGame();
}
$('en-go').onclick = () => {
  const id = pendingEnding; pendingEnding = null;
  $('ending').hidden = true; $('hud').hidden = false;
  clearCrews(); clearWanted(); P.lockSeq = false;
  for (const c of [...COPS]) removeCop(c);
  if (id === 'wayout') { addBuzz(10); addCash(1500); S.social.followers += 2500; }
  if (id === 'witness') { S.heat = 0; S.flags.reyesOffer = false; S.flags.calmUntil = S.playTime + 300; addBuzz(-8); setTimeout(() => sendMsg('saint', 'Heard you been talking to detectives. Block heard too.'), 12000); }
  if (id === 'crown') { addHeat(5); addBuzz(15); S.social.followers += 1500; }
  if (id === 'locked') { S.heat = 15; S.cash = Math.floor(S.cash * 0.6); addBuzz(-10); S.day += 30; S.flags.reyesOffer = false; S.flags.reyes40 = S.flags.reyes60 = S.flags.reyes95 = false; placePlayer(LOC.station.x, 0, LOC.station.z + 1.5, 0); banner('Released', '30 days later'); }
  S.health = Math.max(S.health, 60); S.warmth = Math.max(S.warmth, 60);
  if (S.job) endJob();
  MODE = 'play'; hudDirty = true; saveGame(); lockPointer();
};
