
/* =========================================================
   MULTIPLAYER - live room presence + shared charts/feed
   Everyone on the block is a username. Works solo when the
   viewer cannot connect.
   ========================================================= */
const NET = { room: null, db: null, user: null, uid: null, myPeer: null, remotes: new Map(), shotSeq: 0, shots: [], presT: 0, downSeq: 0, waSeq: 0, players: [], status: 'solo', saveT: 0, lastSaved: '', standoffPeer: null, standoffHold: 0, waCd: {} };
const GUN_IDX = ['k9', 'draft', 'plow'];
const netName = () => S.name || 'artist';
function hashColor(str) { let h = 0; for (const c of String(str)) h = (h * 31 + c.charCodeAt(0)) | 0; return `hsl(${Math.abs(h) % 360},70%,62%)`; }
async function initNet() {
  let C = window.claude;
  if (!C || typeof C.use !== 'function') {
    // not on claude.ai: go peer-to-peer if this build ships the P2P transport
    if (!p2pAvailable()) { NET.status = 'solo'; return; }
    try { C = makeP2PClient(); NET.p2p = true; } catch (e) { console.error('p2p', e); NET.status = 'solo'; return; }
  }
  try { NET.user = await C.use('user'); } catch (e) { NET.user = null; }
  try { NET.uid = NET.user ? await NET.user.id() : null; } catch (e) { NET.uid = null; }
  try { NET.room = await C.use('room'); } catch (e) { NET.room = null; }
  if (NET.room) {
    NET.status = 'connecting';
    NET.room.onPeers(ch => onPeersChange(ch), () => { NET.status = 'solo'; for (const r of NET.remotes.values()) removeRemote(r); NET.remotes.clear(); });
    NET.room.onConnection(c => { NET.status = c ? 'live' : 'connecting'; hudDirty = true; }, () => { NET.status = 'solo'; });
  }
  try { NET.db = await C.use('db'); } catch (e) { NET.db = null; }
  if (NET.db && NET.uid) {
    try {
      NET.db.collection('players').orderBy('updated', 'desc').limit(80).onSnapshot(snap => {
        NET.players = snap.docs.map(d => Object.assign({ id: d.id }, d.data()));
        if (MODE === 'phone') renderPhone();
      }, () => { });
    } catch (e) { }
    netSaveProfile(true);
  }
}
function presencePayload() {
  const r1 = v => Math.round(v * 10) / 10;
  const f = (P.crouch ? 1 : 0) | (P.aimT > 0.5 || GAME_T - P.lastShot < 0.5 ? 2 : 0) | (P.dead || P.downT > 0 ? 4 : 0) | (P.sprinting ? 8 : 0) | (MODE !== 'play' && MODE !== 'phone' ? 16 : 0);
  return {
    v: 1, n: netName().slice(0, 16), x: r1(P.pos.x), y: r1(P.pos.y), z: r1(P.pos.z), r: Math.round(P.bodyYaw * 100) / 100, p: Math.round(camPitch * 100) / 100,
    s: r1(P.speed), f, g: GUN_IDX.indexOf(S.cur), h: Math.round(S.heat), b: Math.round(S.buzz), sh: NET.shots.slice(-6),
    dn: NET.down || null, wa: NET.wa || null,
    car: P.car ? [CAR_MODELS.indexOf(P.car.model), P.car.color, r1(P.car.pos.x), r1(P.car.pos.z), Math.round(P.car.yaw * 100) / 100, r1(P.car.speed), RADIO.on ? S.settings.radio : 0] : null,
    wl: WANTED.level,
  };
}
function updateNetPresence(dt) {
  if (!NET.room || NET.status === 'solo' || MODE === 'title') return;
  NET.presT -= dt;
  if (NET.presT > 0) return;
  NET.presT = 1 / 12;
  NET.room.presence(presencePayload()).catch(() => { });
}
// called from tryFire (local shots)
function netShot(org, dir, gunId) {
  if (!NET.room) return;
  NET.shotSeq++;
  NET.shots.push([NET.shotSeq, Math.round(org.x * 100) / 100, Math.round(org.y * 100) / 100, Math.round(org.z * 100) / 100, Math.round(dir.x * 1000) / 1000, Math.round(dir.y * 1000) / 1000, Math.round(dir.z * 1000) / 1000, GUN_IDX.indexOf(gunId)]);
  if (NET.shots.length > 6) NET.shots.shift();
  NET.presT = 0;
}
function onPeersChange(ch) {
  for (const p of ch.peers) if (p.isMe && p.sameTab) NET.myPeer = p.peer;
  for (const p of ch.joined.concat(ch.updated)) {
    if (p.isMe || p.kind !== 'viewer') continue;
    const pr = p.presence || {};
    if (typeof pr.x !== 'number' || typeof pr.z !== 'number') continue;
    let R = NET.remotes.get(p.peer);
    if (!R) { R = makeRemote(p.peer, pr); NET.remotes.set(p.peer, R); toast(null, `@${cleanName(pr.n)} is on the block`, '#71c6ff'); }
    applyPresence(R, pr);
  }
  for (const p of ch.left) { const R = NET.remotes.get(p.peer); if (R) { removeRemote(R); NET.remotes.delete(p.peer); } }
  hudDirty = true;
}
function cleanName(n) { return String(n || 'artist').replace(/[^\w.\-]/g, '').slice(0, 16) || 'artist'; }
function makeRemote(peer, pr) {
  const name = cleanName(pr.n);
  const col = hashColor(name);
  const c = new THREE.Color(col);
  const h = buildHuman({ jacket: c.clone().multiplyScalar(0.35).getHex(), jacket2: c.clone().multiplyScalar(0.5).getHex(), pants: 0x1b2230, skin: pick([0x5a3a26, 0x7a4a30, 0x6b4630, 0x8a5a3a, 0xa87a58]), hat: c.getHex(), pom: c.getHex(), shoes: 0xdedede, hood: true });
  scene.add(h.group);
  const R = { peer, name, col, h, pos: new THREE.Vector3(pr.x, pr.y || 0, pr.z), tgt: new THREE.Vector3(pr.x, pr.y || 0, pr.z), yaw: pr.r || 0, tyaw: pr.r || 0, f: 0, s: 0, p: 0, g: -1, gun: null, plate: null, lastShot: 0, lastDn: null, lastWa: null, h_: 0, b_: 0, seen: performance.now(), created: performance.now() };
  setRemotePlate(R);
  return R;
}
function setRemotePlate(R) {
  if (R.plate) R.h.group.remove(R.plate);
  R.plate = makeNameplate('@' + R.name, R.col, heatTier(R.h_ || 0) === 'Cool' ? '' : 'HEAT ' + heatTier(R.h_).toUpperCase());
  R.h.group.add(R.plate);
}
function removeRemote(R) { scene.remove(R.h.group); if (R.veh) { removeVehicle(R.veh); R.veh = null; } }
function applyPresence(R, pr) {
  R.seen = performance.now();
  const nm = cleanName(pr.n);
  const tier = heatTier(+pr.h || 0);
  if (nm !== R.name || tier !== heatTier(R.h_)) { R.name = nm; R.h_ = +pr.h || 0; setRemotePlate(R); }
  R.h_ = +pr.h || 0; R.b_ = +pr.b || 0;
  R.tgt.set(+pr.x || 0, +pr.y || 0, +pr.z || 0);
  if (R.tgt.distanceTo(R.pos) > 10) R.pos.copy(R.tgt);
  R.tyaw = +pr.r || 0; R.f = +pr.f || 0; R.s = +pr.s || 0; R.p = +pr.p || 0;
  const g = +pr.g;
  if (g !== R.g && GUN_IDX[g]) {
    if (R.gun) R.h.AR.hand.remove(R.gun);
    R.gun = buildGun(GUN_IDX[g], DEF_CFG()); R.gun.rotation.x = Math.PI / 2; R.gun.scale.setScalar(1.35); R.gun.position.set(0, -0.03, 0.02); R.h.AR.hand.add(R.gun); R.g = g;
  }
  R.h.group.visible = !(R.f & 16);
  // their car
  const c = Array.isArray(pr.car) ? pr.car : null;
  if (c && CAR_MODELS[c[0]] && !(R.f & 16)) {
    const model = CAR_MODELS[c[0]];
    if (R.veh && (R.veh.model !== model || R.veh.color !== (c[1] | 0))) { removeVehicle(R.veh); R.veh = null; }
    if (!R.veh) { R.veh = spawnVehicle(model, +c[2] || 0, +c[3] || 0, +c[4] || 0, { color: c[1] | 0 }); if (R.veh) { R.veh.remote = R; R.veh.driver = 'remote'; R.veh.locked = true; } }
    if (R.veh) { R.vt = { x: +c[2] || 0, z: +c[3] || 0, yaw: +c[4] || 0, sp: +c[5] || 0 }; } R.rd = (+c[6] | 0);
    R.h.root.visible = false; R.h.shadow.visible = false; if (R.plate) R.plate.position.y = 2.6;
  } else { R.rd = 0; if (R.veh) { removeVehicle(R.veh); R.veh = null; } R.h.root.visible = true; R.h.shadow.visible = true; if (R.plate) R.plate.position.y = 2.15; }
  R.wl = +pr.wl || 0;
  // their shots
  if (Array.isArray(pr.sh)) for (const s of pr.sh) {
    if (!Array.isArray(s) || s.length < 8) continue;
    const seq = +s[0]; if (!(seq > R.lastShot)) continue;
    const first = R.lastShot === 0 && performance.now() - R.created < 500;
    R.lastShot = seq; if (first) continue;
    remoteShot(R, s);
  }
  // they went down - was it us?
  if (pr.dn && typeof pr.dn === 'object' && pr.dn.i !== (R.lastDn && R.lastDn.i)) {
    const prev = R.lastDn; R.lastDn = pr.dn;
    if (prev !== null && pr.dn.by === NET.myPeer) {
      S.stats.pvpDowns++; addHeat(10);
      banner(`You dropped @${R.name}`, 'Heat +10');
      postFeed(pick(FEED_HANDLES), `${n_()} and @${R.name} got into it on ${streetName(R.pos.x, R.pos.z)} 😳`);
      netPost({ k: 'pvp', vs: R.name });
    }
  } else if (!R.lastDn) R.lastDn = pr.dn || { i: -1 };
  if (pr.wa && typeof pr.wa === 'object' && pr.wa.i !== (R.lastWa && R.lastWa.i)) {
    const prev = R.lastWa; R.lastWa = pr.wa;
    if (prev && pr.wa.to === NET.myPeer) toast(null, `@${R.name} walked away from you`, '#86e3b0');
  } else if (!R.lastWa) R.lastWa = pr.wa || { i: -1 };
}
const _ro = new THREE.Vector3(), _rd = new THREE.Vector3(), _rh = new THREE.Vector3();
function remoteShot(R, s) {
  const gid = GUN_IDX[s[7]] || 'k9', W = WEAPONS[gid];
  _ro.set(+s[1], +s[2], +s[3]); _rd.set(+s[4], +s[5], +s[6]);
  if (!(_rd.lengthSq() > 0.5) || !isFinite(_ro.x + _ro.y + _ro.z)) return;
  if (Math.hypot(_ro.x - R.tgt.x, _ro.z - R.tgt.z) > 8) return; // shots must come from where they stand
  _rd.normalize();
  if (_ro.distanceTo(P.pos) > 220) return;
  const R0 = rng(s[0] * 7919 + R.name.length);
  const pellets = W.pellets;
  let dmg = 0, head = false;
  for (let i = 0; i < pellets; i++) {
    const d = _rd.clone();
    if (i > 0) { const a = R0() * TAU, r = THREE.MathUtils.degToRad(W.aimSpread) * Math.sqrt(R0()) * 0.6; const side = new THREE.Vector3().crossVectors(d, new THREE.Vector3(0, 1, 0)).normalize(); const up = new THREE.Vector3().crossVectors(side, d).normalize(); d.addScaledVector(side, Math.cos(a) * r).addScaledVector(up, Math.sin(a) * r).normalize(); }
    const tw = raycastWorld(_ro.x, _ro.y, _ro.z, d.x, d.y, d.z, W.range * 2.2);
    let end = tw === Infinity ? W.range * 2 : tw;
    if (!P.dead && (MODE === 'play' || MODE === 'phone')) {
      const me = { pos: P.pos, crouched: P.crouch && !P.aiming };
      const hit = rayEnemy(_ro, d, me);
      if (hit && hit.t < end) { end = hit.t; dmg += W.dmg * 0.7 * (hit.head ? 1.5 : 1) * (hit.t > W.range ? 0.5 : 1); head = head || hit.head; }
    }
    if (i < 2) { _rh.copy(_ro).addScaledVector(d, end); addTracer(_ro, _rh, [1, 0.55, 0.4]); }
  }
  PFX_ADD.spawn(_ro.x, _ro.y, _ro.z, 0, 0, 0, 0.05, 0.4, 0.2, 1, 1, 0.7, 0.3);
  sfxShot(gid, _ro.x, _ro.y, _ro.z, false, 0.85);
  alertPeds(_ro.x, _ro.z, 40);
  R.lastFire = GAME_T;
  if (P.car) dmg *= 0.35;
  if (GAME_T - (R.dmgT || -9) > 1) { R.dmgT = GAME_T; R.dmgAcc = 0; }
  dmg = Math.min(dmg, Math.max(0, 45 - R.dmgAcc)); R.dmgAcc += dmg;
  if (dmg > 0) {
    P.lastAttacker = R;
    const before = S.health;
    hurtPlayer(dmg, R.pos);
    if (before > 0 && S.health <= 0) { NET.downSeq++; NET.down = { by: R.peer, i: NET.downSeq }; NET.presT = 0; setTimeout(() => toast(null, `@${R.name} dropped you`, '#ff4b3a'), 300); }
  }
}
function updateRemotes(dt) {
  if (!NET.remotes.size) { NET.standoffPeer = null; return; }
  const k = 1 - Math.exp(-dt * 10);
  let draw = null, dd = Infinity;
  for (const R of NET.remotes.values()) {
    if (R.veh && R.vt) {
      const v = R.veh;
      if (Math.hypot(R.vt.x - v.pos.x, R.vt.z - v.pos.z) > 12) { v.pos.x = R.vt.x; v.pos.z = R.vt.z; }
      const f = { x: Math.sin(R.vt.yaw), z: Math.cos(R.vt.yaw) };
      v.pos.x += (R.vt.x + f.x * R.vt.sp * 0.06 - v.pos.x) * k; v.pos.z += (R.vt.z + f.z * R.vt.sp * 0.06 - v.pos.z) * k;
      v.yaw += angDiff(v.yaw, R.vt.yaw) * k; v.vel.set(f.x * R.vt.sp, f.z * R.vt.sp); v.speed = R.vt.sp;
      placeVehInstance(v); vehHitPeople(v);
      R.pos.set(v.pos.x, 0, v.pos.z); R.tgt.copy(R.pos); R.h.group.position.copy(R.pos);
      continue;
    }
    R.pos.lerp(R.tgt, k);
    R.yaw += angDiff(R.yaw, R.tyaw) * k;
    R.h.group.position.copy(R.pos); R.h.group.rotation.y = R.yaw;
    const aim = (R.f & 2) ? 1 : 0, down = (R.f & 4) ? 1 : 0;
    animHuman(R.h, dt, { speed: R.s, crouch: (R.f & 1) && !aim, aim, pitch: R.p, down, twoHand: R.g > 0 });
    // soft body push so players don't overlap
    const dx = P.pos.x - R.pos.x, dz = P.pos.z - R.pos.z, d = Math.hypot(dx, dz);
    if (d < 0.75 && d > 0.01 && Math.abs(P.pos.y - R.pos.y) < 1.5) { P.pos.x += dx / d * (0.75 - d) * 0.5; P.pos.z += dz / d * (0.75 - d) * 0.5; }
    // are they drawing on us?
    if (aim && !down && d < 16 && d > 1.5) {
      const toMe = Math.atan2(dx, dz);
      if (Math.abs(angDiff(R.yaw, toMe)) < 0.35 && d < dd) { dd = d; draw = R; }
    }
  }
  NET.standoffPeer = draw && !(NET.waCd[draw.peer] > GAME_T) ? draw : null;
}
function netWalkAway(R) {
  NET.waSeq++; NET.wa = { to: R.peer, i: NET.waSeq }; NET.presT = 0;
  NET.waCd[R.peer] = GAME_T + 30;
  addHeat(-6); S.stats.walkAways++; sfx.whoosh();
  banner('Walked away', `from @${R.name} · Heat −6`);
  postFeed(pick(FEED_HANDLES), `${n_()} walked away from @${R.name}. respect`);
  netPost({ k: 'walk', vs: R.name });
}
/* ---- shared charts + feed (db) ---- */
function myProfile() {
  return {
    name: netName(), color: hashColor(netName()), buzz: Math.round(S.buzz), heat: Math.round(S.heat), day: S.day,
    tracks: S.stats.tracks, best: S.stats.best ? { title: String(S.stats.best.title).slice(0, 40), grade: S.stats.best.grade } : null,
    endings: Object.keys(S.endings), posts: (S.netPosts || []).slice(0, 8), updated: Date.now(),
    followers: socialFollowers(), photos: S.social.posts.filter(p => p.thumb).slice(0, 3).map(p => ({ at: p.at, cap: String(p.caption || '').slice(0, 80), img: p.thumb, likes: p.likes | 0 })),
  };
}
async function netSaveProfile(force) {
  if (!NET.db || !NET.uid) return;
  const prof = myProfile();
  const key = JSON.stringify(Object.assign({}, prof, { updated: 0 }));
  if (!force && key === NET.lastSaved) return;
  if (NET.saving) { NET.pendingSave = true; return; }
  NET.saving = true; NET.lastSaved = key;
  try { await NET.db.doc('players/' + NET.uid).set(prof); } catch (e) { }
  NET.saving = false;
  if (NET.pendingSave) { NET.pendingSave = false; netSaveProfile(); }
}
function netPost(post) {
  S.netPosts = S.netPosts || [];
  S.netPosts.unshift(Object.assign({ at: Date.now() }, post));
  if (S.netPosts.length > 8) S.netPosts.length = 8;
  netSaveProfile();
}
function netPostText(name, p) {
  const at = '@' + cleanName(name);
  switch (p.k) {
    case 'track': return `${at} dropped “${p.title}” · ${p.type === 'wayout' ? 'way out' : p.type} · ${p.grade}`;
    case 'video': return `${at} shot a video on the Calder platform${p.train ? ' with the L in frame 🚆' : ''}`;
    case 'merch': return `${at} sold out a hoodie drop`;
    case 'walk': return p.vs ? `${at} walked away from @${cleanName(p.vs)}` : `${at} walked away from @halo crew`;
    case 'pvp': return `${at} and @${cleanName(p.vs)} got into it on the block`;
    case 'photo': return `${at} posted a photo`;
    case 'ending': return `${at} reached the ${({ wayout: 'Way Out', witness: 'Witness', crown: 'Crown', locked: 'Locked Up' })[p.e] || ''} ending`;
    default: return `${at} is out in the cold`;
  }
}
