/* =========================================================
   GANGS - start your own (name, tag, colour), recruit people
   off the street or through the Gang app, and invite other
   players. Up to three recruits roll with you; the rest hold
   the block and keep working for you. Everything is made up.
   ========================================================= */
const RTYPES = {
  brawler: { name: 'Brawler', icon: '✊', col: '#ff8a5a', cost: 250, buzz: 0, hp: 150, line: 'Hands first, questions later.', perk: 'Fights hand to hand and can take a beating.' },
  shooter: { name: 'Shooter', icon: '◎', col: '#ff4b3a', cost: 650, buzz: 20, hp: 100, line: 'I keep it on me.', perk: 'Carries a K9 and backs you up when rivals start shooting.' },
  medic: { name: 'Medic', icon: '✚', col: '#7be0a6', cost: 450, buzz: 10, hp: 80, line: 'Hold still. This is gonna sting.', perk: 'Patches you up whenever you are hurt.' },
  lookout: { name: 'Lookout', icon: '◉', col: '#71c6ff', cost: 300, buzz: 0, hp: 80, line: 'I see everything on this block.', perk: 'Calls out police early; your Wanted level cools off faster.' },
  hustler: { name: 'Hustler', icon: '$', col: '#ffd84a', cost: 500, buzz: 15, hp: 80, line: "Money don't sleep. Neither do I.", perk: 'Brings in cash every in-game hour, even from the block.' },
  producer: { name: 'Producer', icon: '♪', col: '#c79bff', cost: 800, buzz: 30, hp: 70, line: 'Your 808s are muddy. I can fix that.', perk: 'Tracks you record earn more Buzz.' },
};
const RTYPE_KEYS = Object.keys(RTYPES);
const GANG_COLORS = ['#ff4b3a', '#ff9a3c', '#ffd84a', '#7be0a6', '#4aa3ff', '#c79bff', '#ff6ab0', '#e8e8ea'];
const MAX_RECRUITS = 8, MAX_WITH = 3;
const R_FIRST = ['Dre', 'Moe', 'Tay', 'Nunu', 'Lex', 'Zay', 'Kay', 'Jojo', 'Quan', 'Mel', 'Trey', 'Bink', 'Deuce', 'Kiki', 'Vonnie', 'Shay', 'Nia', 'Bree', 'Toya', 'Dee', 'Rico', 'Manny', 'Luis', 'Petey', 'Sal', 'Gino', 'Ty', 'Bo', 'Rae', 'Jaz', 'Mook', 'Smoke', 'Tink', 'Ace', 'Yaya', 'Pooh'];
const R_PRE = ['Lil ', 'Big ', 'Young ', '', '', '', '', ''];
const GANG = { invites: [], inv: null, invSeq: 0, kick: null, kickSeq: 0, tab: 'crew', leaveArm: 0, form: { name: '', tag: '', color: 0 }, payAcc: 0, paid: 0, payToastT: 0, lookT: 0, warned: new Set(), seen: new Set() };
const FOL = [];
let _gangT = 0;

/* ---- names: fictional only, nothing hateful ---- */
const GANG_REAL = ['gangsterdisciple', 'blackdisciple', 'vicelord', 'latinking', 'blackpstone', 'fourcornerhustler', 'crips', 'bloods', 'ms13', 'marasalvatrucha', 'latindisciple', 'mickeycobra', 'blackgangster', 'satandisciple', 'twotwoboys', 'ambrose'];
const _NOPE = atob('bmlnZyxuaWdhLGZhZ2dvdCxmYWdvdCxyZXRhcmQsa2lrZSxjaGluayx0cmFubnksd2V0YmFjayxiZWFuZXIsZ29vayxzcGljayxkeWtlLGNvb24=').split(',');
function gangTextOk(s) {
  const low = String(s).toLowerCase().replace(/0/g, 'o').replace(/[1!|]/g, 'i').replace(/3/g, 'e').replace(/[4@]/g, 'a').replace(/[5$]/g, 's').replace(/7/g, 't');
  const tokens = low.split(/[^a-z]+/).filter(Boolean), flat = tokens.join('');
  for (const w of _NOPE) { if (w.length >= 5 || w === 'nigg') { if (flat.includes(w)) return false; } else if (tokens.some(t => t === w || t === w + 's')) return false; }
  return !GANG_REAL.some(w => flat.includes(w));
}
function recruitName(seed) { const R = rng(seed ^ 0x9e37); return R_PRE[Math.floor(R() * R_PRE.length)] + R_FIRST[Math.floor(R() * R_FIRST.length)]; }
// each recruit's look comes from a seed, so other players build the same person
function recruitSkin(seed, type) {
  const s = randomSkin(rng(seed));
  if (type === 'brawler') Object.assign(s, { build: 2, top: rng(seed + 1)() < 0.5 ? 'track' : 'hoodie', head: rng(seed + 2)() < 0.5 ? 'durag' : 'none' });
  if (type === 'shooter') Object.assign(s, { top: 'puffer', topCol: 0x15171a, top2: 0x262b33, head: 'beanie', headCol: 0x15171a, pom: 0 });
  if (type === 'medic') Object.assign(s, { top: 'parka', topCol: 0xe8e8ea, top2: 0xc8202a, bag: 'cross', bagCol: 0xc8202a });
  if (type === 'lookout') Object.assign(s, { head: 'hood', glasses: 1, top: 'hoodie' });
  if (type === 'hustler') Object.assign(s, { chain: 1, watch: 1, top: 'leather', topCol: 0x15171a });
  if (type === 'producer') Object.assign(s, { head: 'headphones', headCol: 0xe8e8ea, bag: 'cross' });
  return cleanSkin(s);
}
const recruitOpts = (seed, type) => skinHumanOpts(recruitSkin(seed, type));
// some people on the street are open to joining
function tagPed(p, look) {
  if (look || Math.random() > 0.2) return null;
  p.rqSeed = (Math.random() * 2 ** 31) >>> 0; p.rq = pick(RTYPE_KEYS); p.rqName = recruitName(p.rqSeed);
  return recruitOpts(p.rqSeed, p.rq);
}

/* ---- your gang ---- */
function gangState() { if (!Array.isArray(S.recruits)) S.recruits = []; if (S.gang === undefined) S.gang = null; return S.gang; }
const gangColor = g => GANG_COLORS[(g && g.color) | 0] || GANG_COLORS[0];
function sameGang(R) { return !!(S.gang && R && R.gg && R.gg[0] === S.gang.id); }
function gangRep(n) { if (S.gang) { S.gang.rep = Math.max(0, (S.gang.rep || 0) + n); netSaveProfile(); } }
function createGang(name, tag, color) {
  name = String(name || '').replace(/[^A-Za-z0-9 '&.\-]/g, '').replace(/\s+/g, ' ').trim().slice(0, 18);
  tag = String(tag || '').toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 4);
  if (name.length < 3) return 'Give the gang a name, 3 to 18 letters.';
  if (tag.length < 2) return 'Pick a tag: 2 to 4 letters or numbers.';
  if (!gangTextOk(name) || !gangTextOk(tag)) return 'Pick a different name. Keep it made up and keep it clean.';
  S.gang = { id: (Date.now().toString(36) + Math.random().toString(36).slice(2, 6)).slice(-10), name, tag, color: color | 0, role: 'leader', leader: S.name, rep: 0, created: Date.now() };
  banner(`[${tag}] ${name}`, 'Your gang is on the map'); sfx.cheer();
  addSocialPost('photo', `new gang just dropped: [${tag}] ${name}`, null);
  postFeed(pick(FEED_HANDLES), `${n_()} started a gang called ${name} 👀`);
  netPost({ k: 'gang', g: name.slice(0, 18) });
  saveGame(); netSaveProfile(); NET.presT = 0; hudDirty = true;
  return null;
}
function leaveGang() {
  if (!S.gang) return;
  const g = S.gang; S.gang = null;
  toast(null, `You left [${g.tag}] ${g.name}`, '#ffb347');
  saveGame(); netSaveProfile(); NET.presT = 0;
}
function joinGang(inv) {
  const g = inv.g;
  S.gang = { id: String(g[0]).slice(0, 12), name: String(g[1]).slice(0, 18), tag: String(g[2]).slice(0, 4), color: (g[3] | 0) % GANG_COLORS.length, role: 'member', leader: cleanName(inv.from), rep: 0, created: Date.now() };
  GANG.invites = GANG.invites.filter(i => i !== inv);
  banner(`[${S.gang.tag}] ${S.gang.name}`, 'You joined the gang'); sfx.cheer();
  saveGame(); netSaveProfile(); NET.presT = 0;
}
function inviteRemote(R) {
  if (!S.gang) return;
  GANG.invSeq++; GANG.inv = { to: R.peer, i: GANG.invSeq, g: [S.gang.id, S.gang.name, S.gang.tag, S.gang.color] };
  NET.presT = 0; toast(null, `Invite sent to @${R.name}`, gangColor(S.gang));
}
function kickRemote(R) {
  if (!S.gang || S.gang.role !== 'leader') return;
  GANG.kickSeq++; GANG.kick = { to: R.peer, i: GANG.kickSeq, id: S.gang.id }; NET.presT = 0;
  toast(null, `@${R.name} is out of [${S.gang.tag}]`, '#ffb347');
}

/* ---- recruits ---- */
function canRecruit(type) {
  const T = RTYPES[type];
  if (!S.gang) return 'Start a gang first';
  if (S.recruits.length >= MAX_RECRUITS) return `Your gang is full (${MAX_RECRUITS})`;
  if (S.buzz < T.buzz) return `Needs Buzz ${T.buzz}`;
  if (S.cash < T.cost) return `Needs ${fmtMoney(T.cost)}`;
  return null;
}
function hireRecruit(type, seed, name, at) {
  gangState();
  if (canRecruit(type)) return null;
  addCash(-RTYPES[type].cost);
  const rec = { id: seed.toString(36), seed, type, name, with: S.recruits.filter(r => r.with).length < MAX_WITH, hurtUntil: 0, joined: Date.now() };
  S.recruits.push(rec);
  gangRep(5);
  if (rec.with) spawnFollower(rec, at);
  toast(null, `${name} (${RTYPES[type].name}) is down with [${S.gang.tag}]`, gangColor(S.gang));
  sfx.cash(); saveGame(); netSaveProfile();
  return rec;
}
function dropRecruit(rec) {
  S.recruits = S.recruits.filter(r => r !== rec);
  const f = FOL.find(f => f.rec === rec); if (f) removeFollower(f);
  saveGame(); netSaveProfile();
}
function setWith(rec, on) {
  if (on && S.recruits.filter(r => r.with).length >= MAX_WITH) { toast(null, `Only ${MAX_WITH} can roll with you at once`, '#ffb347'); return; }
  rec.with = on; saveGame();
  if (!on) { const f = FOL.find(f => f.rec === rec); if (f) removeFollower(f); }
  else syncFollowers();
}
// three people looking for a crew today
function streetCandidates() {
  const base = ((S.day || 1) * 7919 + (S.gang ? S.gang.id.length * 131 : 0)) >>> 0, out = [];
  for (let i = 0; i < 4; i++) { const seed = (base * 31 + i * 977 + 13) >>> 0, R = rng(seed); out.push({ seed, type: RTYPE_KEYS[Math.floor(R() * RTYPE_KEYS.length)], name: recruitName(seed) }); }
  return out.filter(c => !S.recruits.some(r => r.seed === c.seed));
}
function nearestRecruitPed() {
  if (P.car) return null;
  let best = null, bd = 2.3;
  for (const p of PEDS) { if (!p.rq || p.state !== 'walk') continue; const d = Math.hypot(p.pos.x - P.pos.x, p.pos.z - P.pos.z); if (d < bd) { bd = d; best = p; } }
  return best;
}
function talkRecruit(p) {
  p.idleT = Math.max(p.idleT || 0, 10);
  const T = RTYPES[p.rq], why = canRecruit(p.rq);
  openMenu({
    eyebrow: 'On the street', title: p.rqName, sub: `${T.name} · ${T.perk}`,
    items: () => [
      { label: `Recruit for ${fmtMoney(T.cost)}`, desc: `“${T.line}”`, hint: why || (S.gang ? `[${S.gang.tag}]` : ''), disabled: !!why, act: () => { const at = { x: p.pos.x, z: p.pos.z, yaw: p.yaw }; const i = PEDS.indexOf(p); if (i >= 0) { scene.remove(p.h.group); PEDS.splice(i, 1); } hireRecruit(p.rq, p.rqSeed, p.rqName, at); closeMenu(); } },
      !S.gang ? { label: 'Open the Gang app', desc: 'Start your own gang first', act: () => { closeMenu(); openPhone('gang'); } } : null,
      { label: 'Not now', act: () => closeMenu() },
    ],
  });
}

/* ---- the people rolling with you ---- */
function followerSpot(near) {
  for (let k = 0; k < 24; k++) {
    const a = rand(0, TAU), r = near ? rand(1.5, 3.5) : rand(16, 26), x = P.pos.x + Math.cos(a) * r, z = P.pos.z + Math.sin(a) * r;
    if (!isBlocked(x, z, 0.4) && Math.abs(x) < MAP_HALF - 4 && Math.abs(z) < MAP_HALF - 4) return { x, z };
  }
  return { x: P.pos.x + 1.5, z: P.pos.z + 1.5 };
}
function spawnFollower(rec, at) {
  if (FOL.some(f => f.rec === rec)) return;
  const h = buildHuman(recruitOpts(rec.seed, rec.type)); scene.add(h.group);
  const sp = at || followerSpot(false);
  const f = { rec, h, pos: new THREE.Vector3(sp.x, 0, sp.z), vel: new THREE.Vector3(), radius: 0.34, height: 1.75, onGround: true, airY: 0, yaw: at && at.yaw || 0, hp: RTYPES[rec.type].hp, state: 'follow', trail: [], tgt: null, tgtT: 0, fireCd: 1, atkCd: 0.5, punchT: 0, punchSide: 1, hitT: 0, healT: 1, downT: 0, riding: false, slot: FOL.length, lastSay: GAME_T };
  if (rec.type === 'shooter') { f.gun = buildGun('k9', DEF_CFG()); f.gun.rotation.x = Math.PI / 2; f.gun.scale.setScalar(1.35); f.gun.position.set(0, -0.03, 0.02); h.AR.hand.add(f.gun); }
  f.plate = makeNameplate(rec.name, gangColor(S.gang), RTYPES[rec.type].name.toUpperCase()); f.plate.scale.multiplyScalar(0.8); h.group.add(f.plate);
  h.group.position.copy(f.pos);
  FOL.push(f);
}
function removeFollower(f) { scene.remove(f.h.group); const i = FOL.indexOf(f); if (i >= 0) FOL.splice(i, 1); FOL.forEach((o, k) => o.slot = k); }
function syncFollowers() {
  gangState();
  const want = S.gang ? S.recruits.filter(r => r.with && !(r.hurtUntil > S.playTime)) : [];
  for (const f of [...FOL]) if (!want.includes(f.rec)) removeFollower(f);
  if (MODE === 'title') return;
  for (const r of want) if (!FOL.some(f => f.rec === r)) spawnFollower(r);
}
function followerTarget(f) {
  let best = null, bd = f.rec.type === 'shooter' ? 32 : 22;
  for (const e of ENEMIES) { if (e.state === 'down' || e.crew.state !== 'combat') continue; const d = Math.hypot(e.pos.x - f.pos.x, e.pos.z - f.pos.z); if (d < bd) { bd = d; best = { kind: 'enemy', ref: e }; } }
  if (f.rec.type === 'brawler') for (const p of PEDS) { if (p.state !== 'brawl') continue; const d = Math.hypot(p.pos.x - f.pos.x, p.pos.z - f.pos.z); if (d < bd) { bd = d; best = { kind: 'ped', ref: p }; } }
  return best;
}
const _fmz = new THREE.Vector3(), _fhp = new THREE.Vector3();
function followerShoot(f, e) {
  f.gun.userData.muzzle.getWorldPosition(_fmz);
  const tx = e.pos.x, ty = e.pos.y + (e.crouched ? 0.9 : 1.3), tz = e.pos.z;
  if (!segClear(_fmz.x, _fmz.y, _fmz.z, tx, ty, tz)) return false;
  const hit = Math.random() < 0.42, dx = tx - _fmz.x, dz = tz - _fmz.z, d = Math.hypot(dx, dz) || 1;
  _fhp.set(tx + (hit ? 0 : rand(-1.2, 1.2)), ty + (hit ? 0 : rand(-0.4, 0.8)), tz + (hit ? 0 : rand(-1.2, 1.2)));
  addTracer(_fmz, _fhp, [1, 0.7, 0.4]);
  PFX_ADD.spawn(_fmz.x, _fmz.y, _fmz.z, 0, 0, 0, 0.05, 0.4, 0.2, 1, 1, 0.7, 0.3);
  sfxShot('k9', _fmz.x, _fmz.y, _fmz.z, false, 0.75);
  alertPeds(f.pos.x, f.pos.z, 35); addHeat(0.3);
  if (hit) damageEnemy(e, 9, false, { x: dx / d, z: dz / d });
  return true;
}
function hurtFollower(f, dmg, from) {
  if (f.state === 'down') return;
  f.hp -= dmg; bloodBurst(f.pos.x, f.pos.y + 1.2, f.pos.z, from ? f.pos.x - from.x : 0, from ? f.pos.z - from.z : 0, 6);
  if (f.hp <= 0) { f.state = 'down'; f.downT = 0; sfx.down(f.pos.x, f.pos.z); f.plate.visible = false; if (f.gun) f.gun.visible = false; }
}
// rivals shoot at your people too, not only at you
function gangDivertShot(e) {
  if (!FOL.length || Math.random() > 0.45) return false;
  const dP = Math.hypot(P.pos.x - e.pos.x, P.pos.z - e.pos.z);
  let f = null, bd = Math.min(24, dP + 4);
  for (const o of FOL) { if (o.state === 'down' || o.riding) continue; const d = Math.hypot(o.pos.x - e.pos.x, o.pos.z - e.pos.z); if (d < bd && segClear(e.pos.x, 1.4, e.pos.z, o.pos.x, 1.3, o.pos.z)) { bd = d; f = o; } }
  if (!f) return false;
  e.gun.userData.muzzle.getWorldPosition(_fmz);
  const hit = Math.random() < e.T.acc * 1.1;
  _fhp.set(f.pos.x + (hit ? 0 : rand(-1.2, 1.2)), f.pos.y + 1.3 + (hit ? 0 : rand(-0.4, 0.8)), f.pos.z + (hit ? 0 : rand(-1.2, 1.2)));
  addTracer(_fmz, _fhp, [1, 0.5, 0.35]);
  PFX_ADD.spawn(_fmz.x, _fmz.y, _fmz.z, 0, 0, 0, 0.05, 0.4, 0.2, 1, 1, 0.7, 0.3);
  sfxShot(e.T.gun, _fmz.x, _fmz.y, _fmz.z, false, 0.8);
  if (hit) hurtFollower(f, e.T.dmg, e.pos);
  return true;
}
function updateFollower(f, dt) {
  const H = f.h, T = RTYPES[f.rec.type];
  if (f.state === 'down') {
    f.downT += dt; animHuman(H, dt, { down: Math.min(1, f.downT / 0.5) });
    if (f.downT > 5) { f.rec.hurtUntil = S.playTime + 150; toast(null, `${f.rec.name} is at Calder General. Back in a few minutes.`, '#ff9a8a'); removeFollower(f); saveGame(); }
    return;
  }
  if (P.car) { if (!f.riding) { f.riding = true; H.group.visible = false; } f.pos.set(P.pos.x, 0, P.pos.z); f.trail.length = 0; return; }
  if (f.riding) { f.riding = false; const sp = followerSpot(true); f.pos.set(sp.x, 0, sp.z); f.vel.set(0, 0, 0); H.group.visible = true; }
  const dP = Math.hypot(P.pos.x - f.pos.x, P.pos.z - f.pos.z);
  if (dP > 45) { const sp = followerSpot(true); f.pos.set(sp.x, P.pos.y, sp.z); f.trail.length = 0; f.vel.set(0, 0, 0); }
  f.tgtT -= dt; if (f.tgtT <= 0) { f.tgtT = 0.4; f.tgt = followerTarget(f); if (f.tgt && f.tgt.ref.state === 'down') f.tgt = null; }
  let gx = null, gz = null, speed = 0, face = null, aim = 0, fighting = false;
  const tg = f.tgt && f.tgt.ref.state !== 'down' ? f.tgt : null;
  if (f.punchT > 0) { f.punchT += dt; if (f.punchT > 0.3) f.punchT = 0; }
  if (tg && f.rec.type === 'shooter' && dP < 16) {
    const e = tg.ref, d = Math.hypot(e.pos.x - f.pos.x, e.pos.z - f.pos.z);
    face = Math.atan2(e.pos.x - f.pos.x, e.pos.z - f.pos.z); aim = 1; fighting = true;
    if (d > 20) { gx = e.pos.x; gz = e.pos.z; speed = 3.2; }
    f.fireCd -= dt; if (f.fireCd <= 0) { f.fireCd = rand(0.45, 0.85); followerShoot(f, e); }
  } else if (tg && f.rec.type === 'brawler' && dP < 22) {
    const o = tg.ref, d = Math.hypot(o.pos.x - f.pos.x, o.pos.z - f.pos.z);
    face = Math.atan2(o.pos.x - f.pos.x, o.pos.z - f.pos.z); fighting = true;
    if (d > 1.1) { gx = o.pos.x; gz = o.pos.z; speed = 5.4; }
    f.atkCd -= dt;
    if (d < 1.3 && f.atkCd <= 0) { f.atkCd = rand(0.6, 0.9); f.punchT = 0.0001; f.punchSide = -f.punchSide; f.hitT = 0.12; sfx.swing(f.pos.x, f.pos.z); }
    if (f.hitT > 0) { f.hitT -= dt; if (f.hitT <= 0 && d < 1.6) { const dir = { x: (o.pos.x - f.pos.x) / (d || 1), z: (o.pos.z - f.pos.z) / (d || 1) }; sfx.punch(o.pos.x, o.pos.y + 1.45, o.pos.z, false); if (tg.kind === 'enemy') { damageEnemy(o, 11, false, dir, true); o.vel.x += dir.x * 2; o.vel.z += dir.z * 2; } else pedPunched(o, 10, dir, false); } }
  }
  if (gx === null && !fighting) {
    // follow your trail, keeping a little space
    const tr = f.trail, last = tr[tr.length - 1];
    if (!last || Math.hypot(last.x - P.pos.x, last.z - P.pos.z) > 0.6) tr.push({ x: P.pos.x, z: P.pos.z });
    while (tr.length > 1 && Math.hypot(tr[0].x - f.pos.x, tr[0].z - f.pos.z) < 0.8) tr.shift();
    if (tr.length > 40) tr.splice(0, tr.length - 40);
    const keep = 2.0 + f.slot * 1.1;
    if (dP > keep && tr.length) { gx = tr[0].x; gz = tr[0].z; speed = dP > 10 ? 6.6 : dP > keep + 2 ? 4.6 : 2.4; }
  }
  // the medic keeps you on your feet
  if (f.rec.type === 'medic' && S.health < 70 && dP < 5 && !P.dead) {
    f.healT -= dt;
    if (f.healT <= 0) { f.healT = 1; S.health = Math.min(100, S.health + 6); hudDirty = true; PFX_ADD.spawn(P.pos.x, P.pos.y + 1.2, P.pos.z, 0, 0.8, 0, 0.6, 0.2, 0.4, 0.4, 1, 0.5, 0.6); if (GAME_T - f.lastSay > 25) { f.lastSay = GAME_T; say(f.rec.name, pick(['Hold still.', 'You good. Breathe.', "That's gonna bruise.", 'Stay behind me.']), T.col); } }
  }
  let vx = 0, vz = 0;
  if (gx !== null) { const dx = gx - f.pos.x, dz = gz - f.pos.z, l = Math.hypot(dx, dz); if (l > 0.3) { vx = dx / l * speed; vz = dz / l * speed; } }
  const px = f.pos.x - P.pos.x, pz = f.pos.z - P.pos.z; if (dP < 1.0 && dP > 0.01) { vx += px / dP * 2; vz += pz / dP * 2; }
  for (const o of FOL) { if (o === f || o.riding) continue; const ox = f.pos.x - o.pos.x, oz = f.pos.z - o.pos.z, ol = Math.hypot(ox, oz); if (ol < 0.9 && ol > 0.01) { vx += ox / ol * 1.6; vz += oz / ol * 1.6; } }
  const k = 1 - Math.exp(-dt * 8);
  f.vel.x += (vx - f.vel.x) * k; f.vel.z += (vz - f.vel.z) * k;
  moveBody(f, f.vel.x * dt, f.vel.z * dt, dt);
  const sp = Math.hypot(f.vel.x, f.vel.z);
  if (face === null && sp > 0.4) face = Math.atan2(f.vel.x, f.vel.z);
  if (face === null && dP < 4) face = Math.atan2(P.pos.x - f.pos.x, P.pos.z - f.pos.z);
  if (face !== null) f.yaw += angDiff(f.yaw, face) * (1 - Math.exp(-dt * 9));
  H.group.position.copy(f.pos); H.group.rotation.y = f.yaw;
  const box = f.rec.type === 'brawler' && fighting;
  animHuman(H, dt, { speed: sp, aim, pitch: 0, twoHand: false, fists: box, guard: box, punch: f.punchT > 0 ? f.punchT / 0.3 : 0, punchSide: f.punchSide, shiver: S.warmth < 25 ? 1 : 0 });
  f.fighting = fighting;
}

/* ---- passive perks ---- */
const gangCount = (type, withOnly) => gangState() ? S.recruits.filter(r => r.type === type && !(r.hurtUntil > S.playTime) && (!withOnly || FOL.some(f => f.rec === r && f.state !== 'down'))).length : 0;
function gangProducerBoost() { return 1 + 0.15 * Math.min(2, gangCount('producer')); }
function gangLookoutBoost() { return gangCount('lookout', true) ? 1.6 : 1; }
function gangTick(dt) {
  if (!gangState()) return;
  // hustlers: one in-game hour is one real minute
  const hu = gangCount('hustler');
  if (hu) {
    GANG.payAcc += dt;
    if (GANG.payAcc >= 60) { GANG.payAcc = 0; const pay = 12 * hu; addCash(pay); GANG.paid += pay; }
    GANG.payToastT -= dt; if (GANG.payToastT <= 0 && GANG.paid) { GANG.payToastT = 300; toast(null, `Your hustlers brought in ${fmtMoney(GANG.paid)}`, '#ffd84a'); GANG.paid = 0; }
  }
  // lookouts call out police before they reach you
  const lo = FOL.find(f => f.rec.type === 'lookout' && f.state !== 'down');
  GANG.lookT -= dt;
  if (lo && GANG.lookT <= 0) {
    GANG.lookT = 2;
    for (const v of VEH) {
      if (!v.copAI || GANG.warned.has(v)) continue;
      const d = Math.hypot(v.pos.x - P.pos.x, v.pos.z - P.pos.z);
      if (d < 80) { GANG.warned.add(v); say(lo.rec.name, pick([`12 coming up ${streetName(v.pos.x, v.pos.z)}.`, 'Cop car. Heads down.', `Police on ${streetName(v.pos.x, v.pos.z)}, be cool.`]), RTYPES.lookout.col); GANG.lookT = 20; break; }
    }
  }
}
function updateGang(dt) {
  _gangT -= dt;
  if (_gangT <= 0) { _gangT = 1; syncFollowers(); gangTick(1); }
  for (const f of [...FOL]) updateFollower(f, dt);
  updateRemoteFollowers(dt);
  updateRecruitPlates();
}
// street recruits show who they are when you get close
function updateRecruitPlates() {
  for (const p of PEDS) {
    if (!p.rq) continue;
    const near = p.state === 'walk' && Math.hypot(p.pos.x - P.pos.x, p.pos.z - P.pos.z) < 14 && !P.car;
    if (near && !p.rqPlate) { p.rqPlate = makeNameplate(p.rqName, RTYPES[p.rq].col, 'RECRUIT · ' + RTYPES[p.rq].name.toUpperCase()); p.rqPlate.scale.multiplyScalar(0.75); p.h.group.add(p.rqPlate); }
    if (p.rqPlate) p.rqPlate.visible = near;
  }
}

/* ---- online: tags, invites and everybody's crews ---- */
function gangPresence() {
  const out = [];
  for (const f of FOL) { if (f.riding) continue; out.push([RTYPE_KEYS.indexOf(f.rec.type), f.rec.seed, Math.round(f.pos.x * 10) / 10, Math.round(f.pos.z * 10) / 10, Math.round(f.yaw * 100) / 100, Math.round(Math.hypot(f.vel.x, f.vel.z) * 10) / 10, (f.state === 'down' ? 2 : 0) | (f.fighting ? 1 : 0) | (f.punchT > 0 ? 4 : 0)]); }
  return out;
}
function gangPresenceFields() {
  return { gg: S.gang ? [S.gang.id, S.gang.tag, S.gang.color | 0, S.gang.name] : null, gf: gangPresence(), gi: GANG.inv, gk: GANG.kick };
}
function gangApplyPresence(R, pr) {
  const gg = Array.isArray(pr.gg) && pr.gg.length >= 4 ? [String(pr.gg[0]).slice(0, 12), String(pr.gg[1]).replace(/[^A-Z0-9]/g, '').slice(0, 4), (pr.gg[2] | 0) % GANG_COLORS.length, String(pr.gg[3]).replace(/[^A-Za-z0-9 '&.\-]/g, '').slice(0, 18)] : null;
  const key = gg ? gg.join('|') : '';
  if (key !== (R.ggKey || '')) {
    const was = R.gg; R.ggKey = key; R.gg = gg; setRemotePlate(R);
    if (gg && S.gang && gg[0] === S.gang.id && !(was && was[0] === gg[0]) && performance.now() - R.created > 1500) { toast(null, `@${R.name} joined [${S.gang.tag}]`, gangColor(S.gang)); if (S.gang.role === 'leader') gangRep(10); }
  }
  // an invite for us?
  if (pr.gi && typeof pr.gi === 'object' && pr.gi.i !== (R.lastGi && R.lastGi.i)) {
    const prev = R.lastGi; R.lastGi = pr.gi;
    if (prev !== undefined && pr.gi.to === NET.myPeer && Array.isArray(pr.gi.g) && !(S.gang && S.gang.id === pr.gi.g[0])) {
      const g = pr.gi.g, inv = { from: R.name, peer: R.peer, g: [String(g[0]).slice(0, 12), String(g[1]).replace(/[^A-Za-z0-9 '&.\-]/g, '').slice(0, 18), String(g[2]).replace(/[^A-Z0-9]/g, '').slice(0, 4), (g[3] | 0) % GANG_COLORS.length] };
      if (gangTextOk(inv.g[1]) && gangTextOk(inv.g[2])) { GANG.invites = GANG.invites.filter(x => x.peer !== R.peer); GANG.invites.push(inv); toast(null, `@${R.name} invited you to [${inv.g[2]}] ${inv.g[1]} · open the Gang app`, GANG_COLORS[inv.g[3]]); if (MODE === 'phone' && PHONE.app === 'gang') renderApp(); }
    }
  } else if (R.lastGi === undefined) R.lastGi = pr.gi || null;
  // kicked by our leader?
  if (pr.gk && typeof pr.gk === 'object' && pr.gk.i !== (R.lastGk && R.lastGk.i)) {
    const prev = R.lastGk; R.lastGk = pr.gk;
    if (prev !== undefined && pr.gk.to === NET.myPeer && S.gang && pr.gk.id === S.gang.id && S.gang.role !== 'leader') { toast(null, `@${R.name} put you out of [${S.gang.tag}]`, '#ff9a8a'); S.gang = null; saveGame(); netSaveProfile(); NET.presT = 0; }
  } else if (R.lastGk === undefined) R.lastGk = pr.gk || null;
  // their crew on the street
  const list = Array.isArray(pr.gf) ? pr.gf.slice(0, MAX_WITH) : [];
  if (!R.fol) R.fol = new Map();
  const seen = new Set();
  for (const a of list) {
    if (!Array.isArray(a) || a.length < 7) continue;
    const type = RTYPE_KEYS[a[0] | 0] || 'brawler', seed = a[1] >>> 0; seen.add(seed);
    let o = R.fol.get(seed);
    if (!o) {
      const h = buildHuman(recruitOpts(seed, type)); scene.add(h.group);
      o = { h, type, pos: new THREE.Vector3(+a[2] || 0, 0, +a[3] || 0), tgt: new THREE.Vector3(+a[2] || 0, 0, +a[3] || 0), yaw: +a[4] || 0, tyaw: +a[4] || 0, s: 0, fl: 0, punchT: 0 };
      if (type === 'shooter') { o.gun = buildGun('k9', DEF_CFG()); o.gun.rotation.x = Math.PI / 2; o.gun.scale.setScalar(1.35); o.gun.position.set(0, -0.03, 0.02); h.AR.hand.add(o.gun); }
      R.fol.set(seed, o);
    }
    o.tgt.set(+a[2] || 0, 0, +a[3] || 0); o.tyaw = +a[4] || 0; o.s = +a[5] || 0;
    if ((a[6] & 4) && !(o.fl & 4)) o.punchT = 0.0001;
    o.fl = a[6] | 0;
    if (o.tgt.distanceTo(o.pos) > 12) o.pos.copy(o.tgt);
    const lbl = recruitName(seed), col = R.gg ? GANG_COLORS[R.gg[2]] : R.col;
    if (o.plateKey !== lbl + col) { if (o.plate) o.h.group.remove(o.plate); o.plate = makeNameplate(lbl, col, R.gg ? `[${R.gg[1]}] ${RTYPES[type].name.toUpperCase()}` : RTYPES[type].name.toUpperCase()); o.plate.scale.multiplyScalar(0.8); o.h.group.add(o.plate); o.plateKey = lbl + col; }
  }
  for (const [seed, o] of R.fol) if (!seen.has(seed)) { scene.remove(o.h.group); R.fol.delete(seed); }
}
function updateRemoteFollowers(dt) {
  const k = 1 - Math.exp(-dt * 10);
  for (const R of NET.remotes.values()) {
    if (!R.fol) continue;
    for (const o of R.fol.values()) {
      o.pos.lerp(o.tgt, k); o.yaw += angDiff(o.yaw, o.tyaw) * k;
      o.h.group.position.copy(o.pos); o.h.group.rotation.y = o.yaw;
      if (o.punchT > 0) { o.punchT += dt; if (o.punchT > 0.3) o.punchT = 0; }
      const box = o.type === 'brawler' && (o.fl & 1);
      animHuman(o.h, dt, { speed: o.s, aim: o.type === 'shooter' && (o.fl & 1) ? 1 : 0, down: (o.fl & 2) ? 1 : 0, fists: box, guard: box, punch: o.punchT > 0 ? o.punchT / 0.3 : 0, punchSide: 1 });
      if (o.plate) o.plate.visible = !(o.fl & 2);
    }
  }
}
function dropRemoteFollowers(R) { if (R.fol) { for (const o of R.fol.values()) scene.remove(o.h.group); R.fol.clear(); } }
function gangPlateFor(R) { return R.gg ? { text: `[${R.gg[1]}] @${R.name}`, col: GANG_COLORS[R.gg[2]] } : { text: '@' + R.name, col: R.col }; }
// every gang anyone on the block has seen, from the shared profiles
function gangBoard() {
  const by = new Map();
  const add = (g, name, recruits, online) => {
    if (!g || !g.id) return;
    let e = by.get(g.id); if (!e) { e = { id: g.id, name: String(g.name || '').slice(0, 18), tag: String(g.tag || '').slice(0, 4), color: (g.color | 0) % GANG_COLORS.length, members: [], rep: 0, recruits: 0 }; by.set(g.id, e); }
    if (!e.members.some(m => m.name === name)) { e.members.push({ name, online }); e.rep += (g.rep | 0); e.recruits += recruits | 0; }
  };
  if (S.gang) add(S.gang, S.name, S.recruits.length, true);
  const online = new Set([...NET.remotes.values()].map(R => R.name));
  for (const p of NET.players) if (p.gang && p.id !== NET.uid) add(p.gang, cleanName(p.name), p.recruits, online.has(cleanName(p.name)));
  for (const R of NET.remotes.values()) if (R.gg) add({ id: R.gg[0], tag: R.gg[1], color: R.gg[2], name: R.gg[3] }, R.name, 0, true);
  return [...by.values()].filter(g => gangTextOk(g.name) && gangTextOk(g.tag)).sort((a, b) => (b.rep + b.members.length * 10 + b.recruits * 5) - (a.rep + a.members.length * 10 + a.recruits * 5));
}

/* ---- the Gang app ---- */
function renderGangApp(body, add) {
  gangState();
  const G = S.gang;
  if (!G) {
    if (GANG.invites.length) {
      add('<div class="sec">Invites</div>');
      GANG.invites.forEach((inv, i) => add(`<div class="row"><span><span style="color:${GANG_COLORS[inv.g[3]]}">■</span> [${esc(inv.g[2])}] ${esc(inv.g[1])}<br><span style="font-size:12px;color:#8a96a2">from @${esc(inv.from)}</span></span><span><button class="pill blue" data-gacc="${i}">Join</button> <button class="pill" data-gdec="${i}">No</button></span></div>`));
    }
    const F = GANG.form;
    add(`<div class="gang-hero"><b>Start a gang</b><span>Pick a name, a tag and a colour. Then recruit people off the street or from this app, and invite other players. Keep it made up: no real gangs.</span></div>
      <div class="sec">Name</div><input id="g-name" maxlength="18" placeholder="e.g. Lakeshore Kings" value="${esc(F.name)}">
      <div class="sec">Tag</div><input id="g-tag" maxlength="4" placeholder="e.g. LSK" value="${esc(F.tag)}" style="text-transform:uppercase">
      <div class="sec">Colour</div><div class="g-cols">${GANG_COLORS.map((c, i) => `<button data-gcol="${i}" class="${F.color === i ? 'on' : ''}" style="background:${c}" aria-label="Colour ${i + 1}"></button>`).join('')}</div>
      <div id="g-msg" class="job-s" style="color:#ff9a8a;min-height:16px"></div>
      <button class="btn primary" id="g-make" style="width:100%">Start the gang</button>`);
    $('g-name').oninput = e => { F.name = e.target.value; };
    $('g-tag').oninput = e => { F.tag = e.target.value.toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 4); e.target.value = F.tag; };
    body.querySelectorAll('[data-gcol]').forEach(b => b.onclick = () => { F.color = +b.dataset.gcol; renderApp(); });
    $('g-make').onclick = () => { const err = createGang(F.name, F.tag, F.color); if (err) $('g-msg').textContent = err; else renderApp(); };
    body.querySelectorAll('[data-gacc]').forEach(b => b.onclick = () => { const inv = GANG.invites[+b.dataset.gacc]; if (inv) { joinGang(inv); renderApp(); } });
    body.querySelectorAll('[data-gdec]').forEach(b => b.onclick = () => { GANG.invites.splice(+b.dataset.gdec, 1); renderApp(); });
    return;
  }
  const col = gangColor(G), mates = [...NET.remotes.values()].filter(R => sameGang(R));
  add(`<div class="gang-card" style="--gc:${col}"><b>[${esc(G.tag)}] ${esc(G.name)}</b><span>${G.role === 'leader' ? 'You run it' : 'Member · started by @' + esc(G.leader || '')} · Rep ${G.rep | 0} · ${mates.length + 1} player${mates.length ? 's' : ''} online · ${S.recruits.length}/${MAX_RECRUITS} recruits</span></div>`);
  add(`<div class="seg">${[['crew', 'Crew'], ['hire', 'Recruit'], ['online', 'Invite'], ['board', 'Gangs']].map(([k, l]) => `<button data-gt="${k}" class="${GANG.tab === k ? 'on' : ''}">${l}</button>`).join('')}</div>`);
  if (GANG.tab === 'crew') {
    add('<div class="sec">Your recruits</div>');
    if (!S.recruits.length) add('<div class="empty">Nobody yet. Walk up to people marked RECRUIT on the street and press E, or check the Recruit tab.</div>');
    S.recruits.forEach((r, i) => {
      const T = RTYPES[r.type], hurt = r.hurtUntil > S.playTime;
      const st = hurt ? `At Calder General · ${Math.ceil((r.hurtUntil - S.playTime) / 60)} min` : r.with ? 'With you' : 'Holding the block';
      add(`<div class="row"><span><span style="color:${T.col}">${T.icon}</span> ${esc(r.name)} <span style="font-size:12px;color:#8a96a2">· ${T.name}</span><br><span style="font-size:12px;color:${r.with && !hurt ? '#7be0a6' : '#8a96a2'}">${st}</span></span><span>${hurt ? '' : `<button class="pill ${r.with ? '' : 'blue'}" data-gw="${i}">${r.with ? 'Send home' : 'Call'}</button>`} <button class="pill" data-gx="${i}">${GANG.dropArm === r ? 'Sure?' : 'Let go'}</button></span></div>`);
    });
    add(`<div class="job-s">Up to ${MAX_WITH} roll with you. The rest still work: hustlers earn, producers help in the booth.</div>`);
    add('<div class="sec">Members</div>');
    add(`<div class="row"><span><span style="color:${col}">●</span> @${esc(S.name)} (you)</span><span class="g">${G.role === 'leader' ? 'Leader' : 'Member'}</span></div>`);
    mates.forEach(R => add(`<div class="row"><span><span style="color:${col}">●</span> @${esc(R.name)} <span style="font-size:12px;color:#7be0a6">online</span></span><span>${G.role === 'leader' ? `<button class="pill" data-gkick="${esc(R.peer)}">Kick</button>` : `<span class="g">${Math.round(R.pos.distanceTo(P.pos))} m</span>`}</span></div>`));
    const off = NET.players.filter(p => p.gang && p.gang.id === G.id && p.id !== NET.uid && !mates.some(R => R.name === cleanName(p.name)));
    off.forEach(p => add(`<div class="row"><span><span style="color:#56606a">●</span> @${esc(cleanName(p.name))}</span><span class="g">${ago(p.updated || 0)}</span></div>`));
    add(`<button class="btn" id="g-leave" style="width:100%;margin-top:12px">${GANG.leaveArm > REAL_T ? 'Tap again to leave the gang' : 'Leave the gang'}</button>`);
  } else if (GANG.tab === 'hire') {
    add('<div class="sec">Looking for a crew today</div>');
    const list = streetCandidates();
    if (!list.length) add('<div class="empty">Everyone looking today is already with you. More people tomorrow.</div>');
    list.forEach(c => { const T = RTYPES[c.type], why = canRecruit(c.type); add(`<div class="row"><span><span style="color:${T.col}">${T.icon}</span> ${esc(c.name)} · ${T.name}<br><span style="font-size:12px;color:#8a96a2">${esc(T.perk)}</span></span><span><button class="pill ${why ? '' : 'blue'}" data-ghire="${c.seed}" ${why ? 'disabled' : ''}>${why ? esc(why) : fmtMoney(T.cost)}</button></span></div>`); });
    add('<div class="sec">Types</div>');
    RTYPE_KEYS.forEach(k => { const T = RTYPES[k]; add(`<div class="row"><span><span style="color:${T.col}">${T.icon}</span> ${T.name}<br><span style="font-size:12px;color:#8a96a2">${esc(T.perk)}</span></span><span class="g">${fmtMoney(T.cost)}${T.buzz ? ' · Buzz ' + T.buzz : ''}</span></div>`); });
    add('<div class="job-s">People open to joining walk around with a RECRUIT tag. Walk up and press E.</div>');
  } else if (GANG.tab === 'online') {
    const others = [...NET.remotes.values()].filter(R => !sameGang(R));
    add('<div class="sec">Players on the block</div>');
    if (NET.status === 'solo') add('<div class="empty">Playing solo right now, so there is nobody to invite.</div>');
    else if (!others.length) add('<div class="empty">Nobody else outside your gang is online.</div>');
    others.forEach(R => add(`<div class="row"><span><span style="color:${R.gg ? GANG_COLORS[R.gg[2]] : R.col}">●</span> @${esc(R.name)}${R.gg ? ` <span style="font-size:12px;color:#8a96a2">[${esc(R.gg[1])}]</span>` : ''}</span><span><button class="pill blue" data-ginv="${esc(R.peer)}">Invite</button></span></div>`));
    if (GANG.invites.length) { add('<div class="sec">Invites to other gangs</div>'); GANG.invites.forEach((inv, i) => add(`<div class="row"><span>[${esc(inv.g[2])}] ${esc(inv.g[1])} · @${esc(inv.from)}</span><span><button class="pill blue" data-gacc="${i}">Switch</button> <button class="pill" data-gdec="${i}">No</button></span></div>`)); }
  } else {
    add('<div class="sec">Gangs on the block</div>');
    const board = gangBoard();
    if (!board.length) add('<div class="empty">No gangs yet.</div>');
    board.slice(0, 12).forEach((g, i) => add(`<div class="row"><span>${i + 1}. <span style="color:${GANG_COLORS[g.color]}">■</span> [${esc(g.tag)}] ${esc(g.name)}${S.gang && g.id === S.gang.id ? ' (yours)' : ''}<br><span style="font-size:12px;color:#8a96a2">${g.members.length} player${g.members.length === 1 ? '' : 's'} · ${g.recruits} recruits · ${g.members.filter(m => m.online).length} online</span></span><span class="g">${g.rep + g.members.length * 10 + g.recruits * 5}</span></div>`));
  }
  body.querySelectorAll('[data-gt]').forEach(b => b.onclick = () => { GANG.tab = b.dataset.gt; renderApp(); });
  body.querySelectorAll('[data-gw]').forEach(b => b.onclick = () => { const r = S.recruits[+b.dataset.gw]; if (r) { setWith(r, !r.with); renderApp(); } });
  body.querySelectorAll('[data-gx]').forEach(b => b.onclick = () => { const r = S.recruits[+b.dataset.gx]; if (!r) return; if (GANG.dropArm === r) { GANG.dropArm = null; dropRecruit(r); toast(null, `${r.name} is on their own now`, '#8a96a2'); } else GANG.dropArm = r; renderApp(); });
  body.querySelectorAll('[data-ghire]').forEach(b => b.onclick = () => { const c = streetCandidates().find(c => String(c.seed) === b.dataset.ghire); if (c && hireRecruit(c.type, c.seed, c.name)) { toast(null, `${c.name} is on the way to you`, gangColor(S.gang)); renderApp(); } });
  body.querySelectorAll('[data-ginv]').forEach(b => b.onclick = () => { const R = [...NET.remotes.values()].find(R => R.peer === b.dataset.ginv); if (R) { inviteRemote(R); b.textContent = 'Sent'; b.disabled = true; } });
  body.querySelectorAll('[data-gkick]').forEach(b => b.onclick = () => { const R = [...NET.remotes.values()].find(R => R.peer === b.dataset.gkick); if (R) { kickRemote(R); renderApp(); } });
  body.querySelectorAll('[data-gacc]').forEach(b => b.onclick = () => { const inv = GANG.invites[+b.dataset.gacc]; if (inv) { joinGang(inv); renderApp(); } });
  body.querySelectorAll('[data-gdec]').forEach(b => b.onclick = () => { GANG.invites.splice(+b.dataset.gdec, 1); renderApp(); });
  const lv = $('g-leave'); if (lv) lv.onclick = () => { if (GANG.leaveArm > REAL_T) { GANG.leaveArm = 0; leaveGang(); } else GANG.leaveArm = REAL_T + 4; renderApp(); };
}
