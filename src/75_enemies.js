
/* =========================================================
   HALO CREW - rivals with standoffs, cover and peeking
   ========================================================= */
const ENEMIES = [], CREWS = [];
const ETYPES = {
  runner: { hp: 60, speed: 5.0, gun: 'k9', rate: 0.6, burst: 1, dmg: 7, acc: 0.4, jacket: 0x2a2d33, jacket2: 0x3a1c20 },
  shooter: { hp: 80, speed: 3.9, gun: 'draft', rate: 0.1, burst: 4, dmg: 5, acc: 0.28, jacket: 0x323a2c, jacket2: 0x40262a },
  saint: { hp: 280, speed: 4.3, gun: 'draft', rate: 0.09, burst: 5, dmg: 6, acc: 0.34, jacket: 0xe6e6e8, jacket2: 0xcfcfd4 },
};
const CREW_HANDLES = ['@halo.dre', '@halo_kj', '@halo.moe', '@halo.tay', '@halo_bigs', '@halo.nunu', '@halo_lex', '@halo.zay', '@halo_ock', '@halo.rell', '@halo.sosa', '@halo_trey'];
const LINES = {
  standoff: ['You lost?', 'Wrong block.', '@saint.halo said you been talking.', "Keep walking or don't.", "Ain't nothing for you out here.", 'Heard the track. Say it again.'],
  saintStandoff: ['Look who it is. The rapper.', 'Say my name again. Go ahead.', "Calder Ave ain't yours.", 'You made a song. I made this block.'],
  walk: ['Yeah. Keep walking.', 'Smart.', "Next time it's different."],
  saintWalk: ["That's what you do. Walk."],
  engage: ['Bad move.', 'Here we go.', 'Now you did it.'],
  skip: ['No talking tonight.', "We're done talking."],
};
let crewSeq = 0;
function spawnEnemy(type, x, z, crew) {
  const T = ETYPES[type];
  const h = buildHuman({ jacket: T.jacket, jacket2: T.jacket2, pants: 0x18191c, skin: pick([0x5a3a26, 0x7a4a30, 0x4a2e1e, 0x8a5a3a, 0x6b4630]), hat: 0x8a1c24, chain: type === 'saint', hood: type === 'runner', mask: type !== 'saint' && Math.random() < 0.6 ? 0x111214 : undefined });
  scene.add(h.group);
  const gun = buildGun(T.gun, DEF_CFG()); gun.rotation.x = Math.PI / 2; gun.scale.setScalar(1.35); gun.position.set(0, -0.03, 0.02); h.AR.hand.add(gun);
  const used = new Set(ENEMIES.map(e => e.name));
  const name = type === 'saint' ? CAST.saint.name : (CREW_HANDLES.find(n => !used.has(n) && Math.random() < 0.5) || pick(CREW_HANDLES));
  const plate = makeNameplate(name, '#ff4b3a'); h.group.add(plate);
  const e = {
    type, T, h, gun, plate, name, crew, pos: new THREE.Vector3(x, 0, z), vel: new THREE.Vector3(), radius: 0.36, height: 1.75, onGround: true, airY: 0,
    yaw: 0, hp: T.hp, state: 'alive', knockT: 0, crouched: false, canSee: null, losT: Math.random() * 0.2, seeT: 0, fireCd: rand(0.6, 1.2), burstLeft: 0,
    path: null, pathT: 0, pathAge: 99, cover: null, coverT: 0, phase: 'seek', phaseT: 0, strafe: Math.random() < 0.5 ? 1 : -1, strafeT: rand(1, 2),
    stuckT: 0, lastX: x, lastZ: z, side: 0, sideT: 0, downT: 0, flash: 0, leaveTo: null,
  };
  h.group.position.copy(e.pos);
  ENEMIES.push(e); crew.members.push(e);
  return e;
}
function isBlocked(x, z, m) {
  m = m || 0.5;
  const list = queryBoxes(x - m, z - m, x + m, z + m);
  return list.some(b => b.y0 < 1.8 && b.y1 > 0.3 && x > b.x0 - m && x < b.x1 + m && z > b.z0 - m && z < b.z1 + m);
}
function spawnCrew(o) {
  const c = { id: ++crewSeq, members: [], state: 'approach', t: 0, so: 0, aimHold: 0, walkHold: 0, saint: !!o.saint, challenge: !!o.challenge, fought: false, over: false, leaveT: 0 };
  CREWS.push(c);
  const types = [];
  if (o.saint) types.push('saint');
  for (let i = 0; i < (o.shooters || 0); i++) types.push('shooter');
  while (types.length < o.n) types.push('runner');
  types.forEach((t, i) => {
    let x = o.x, z = o.z;
    for (let k = 0; k < 12; k++) { const a = rand(0, TAU), r = i === 0 ? 0 : rand(1.5, 3.5); x = o.x + Math.cos(a) * r; z = o.z + Math.sin(a) * r; if (!isBlocked(x, z)) break; }
    const e = spawnEnemy(t, x, z, c); e.yaw = Math.atan2(P.pos.x - x, P.pos.z - z); e.h.group.rotation.y = e.yaw;
  });
  if (o.state) c.state = o.state;
  if (o.challenge) setTimeout(() => { if (MODE === 'play' && !c.over) playCutscene(cutSaint(c)); }, 600);
  return c;
}
function clearCrews() {
  for (const e of ENEMIES) { scene.remove(e.h.group); }
  ENEMIES.length = 0; CREWS.length = 0;
  $('standoff').hidden = true;
}
function crewLeader(c) { return c.members.find(e => e.type === 'saint' && e.state !== 'down') || c.members.find(e => e.state !== 'down'); }
function crewNotice(c) {
  if (c.state !== 'approach') return;
  const L = crewLeader(c); if (!L) return;
  if (S.heat >= 75) { crewEngage(c, 'skip'); return; }
  c.state = 'standoff'; c.so = 0; c.aimHold = 0; c.walkHold = 0;
  say(L.name, c.saint && L.type === 'saint' ? pick(LINES.saintStandoff) : pick(LINES.standoff), '#ff4b3a');
  P.shake = 0.2;
}
function crewEngage(c, why) {
  if (c.state === 'combat' || c.over) return;
  const wasStand = c.state === 'standoff';
  c.state = 'combat'; c.fought = true;
  S.stats.fights++;
  addHeat(5);
  const L = crewLeader(c);
  if (L) say(L.name, why === 'skip' ? pick(LINES.skip) : pick(LINES.engage), '#ff4b3a');
  if (S.job && S.job.id === 'kiara') S.job.fight = true;
  if (why === 'skip') banner('No standoff', 'Your Heat is too high to talk');
  else if (wasStand) banner('Fight', '');
  for (const e of c.members) { e.phase = 'seek'; e.seeT = 0.2; }
}
function crewWalkAway(c, distance) {
  if (c.state !== 'standoff') return;
  c.state = 'leave'; c.leaveT = 0;
  const L = crewLeader(c);
  if (L) say(L.name, c.saint && L.type === 'saint' ? pick(LINES.saintWalk) : pick(LINES.walk), '#ff4b3a');
  const dh = distance ? -5 : (c.saint ? -12 : -9);
  addHeat(dh);
  S.stats.walkAways++;
  sfx.whoosh();
  banner('Walked away', `Heat ${dh}`);
  for (const e of c.members) { const a = Math.atan2(e.pos.x - P.pos.x, e.pos.z - P.pos.z); e.leaveTo = { x: clamp(e.pos.x + Math.sin(a) * 60, -(MAP_HALF - 10), MAP_HALF - 10), z: clamp(e.pos.z + Math.cos(a) * 60, -(MAP_HALF - 10), MAP_HALF - 10) }; e.path = null; }
  onWalkAway(c);
}
function crewDefeated(c) {
  if (!c.fought) return;
  addHeat(4);
  if (!c.saint || !S.flags.saintDown) banner('Fight over', 'Heat +4');
  const where = streetName(P.pos.x, P.pos.z);
  setTimeout(() => postFeed(pick(FEED_HANDLES), pick([`shots on ${where} again. everybody ok?`, `${where} was loud tonight. stay inside`, `heard @halo crew got sent home on ${where}`])), 4000);
  if (c.challenge) S.flags.saintChallengeDone = true;
}
function enemySees(e) {
  const eye = e.pos.y + (e.crouched ? 1.0 : 1.55);
  const dx = P.pos.x - e.pos.x, dz = P.pos.z - e.pos.z;
  if (dx * dx + dz * dz > 60 * 60 || P.dead) return null;
  if (P.car) return segClear(e.pos.x, eye, e.pos.z, P.car.pos.x, 1.0, P.car.pos.z) ? [P.car.pos.x, 1.0, P.car.pos.z] : null;
  for (const t of playerTargets()) if (segClear(e.pos.x, eye, e.pos.z, t[0], t[1], t[2])) return t;
  return null;
}
function directClear(ax, az, bx, bz, y) {
  const dx = bx - ax, dz = bz - az, L = Math.hypot(dx, dz);
  if (L < 0.5) return true;
  const nx = -dz / L * 0.32, nz = dx / L * 0.32;
  return segClear(ax + nx, y + 0.5, az + nz, bx + nx, y + 0.5, bz + nz) && segClear(ax - nx, y + 0.5, az - nz, bx - nx, y + 0.5, bz - nz);
}
const STAIR_NODES = [{ b: { x: 62, z: 46 }, t: { x: 62, z: 19 } }, { b: { x: 78, z: 46 }, t: { x: 78, z: 19 } }];
function navTarget(e, gx, gz, gy, dt) {
  e.pathT -= dt; e.pathAge += dt;
  const elevated = gy > 5 && e.pos.y < 5, desc = gy < 5 && e.pos.y > 5;
  if (e.pathT <= 0) {
    e.pathT = 0.45 + Math.random() * 0.3;
    if (!elevated && !desc && directClear(e.pos.x, e.pos.z, gx, gz, e.pos.y)) { e.path = [{ x: gx, z: gz }]; e.pathAge = 0; }
    else if (!e.path || e.path.length <= 1 || e.pathAge > 4) {
      if (elevated || desc) {
        const s = STAIR_NODES.reduce((a, b) => Math.hypot(a.b.x - (elevated ? e.pos.x : gx), a.b.z - (elevated ? e.pos.z : gz)) < Math.hypot(b.b.x - (elevated ? e.pos.x : gx), b.b.z - (elevated ? e.pos.z : gz)) ? a : b);
        e.path = elevated ? navPath(e.pos.x, e.pos.z, s.b.x, s.b.z).concat([s.t, { x: gx, z: gz }]) : [s.t, s.b].concat(navPath(s.b.x, s.b.z, gx, gz));
      } else e.path = navPath(e.pos.x, e.pos.z, gx, gz);
      e.pathAge = 0;
    }
  }
  if (!e.path || !e.path.length) return { x: gx, z: gz };
  e.path[e.path.length - 1] = { x: gx, z: gz };
  while (e.path.length > 1 && Math.hypot(e.path[0].x - e.pos.x, e.path[0].z - e.pos.z) < 1.6) e.path.shift();
  return e.path[0];
}
function findCover(e) {
  const list = queryBoxes(e.pos.x - 24, e.pos.z - 24, e.pos.x + 24, e.pos.z + 24, []);
  let best = null, bs = Infinity, n = 0;
  for (const b of list) {
    if (b.tag !== 'cover' || b.y1 < 0.95 || b.y1 > 1.7) continue;
    if (++n > 30) break;
    const cx = (b.x0 + b.x1) / 2, cz = (b.z0 + b.z1) / 2;
    let dx = cx - P.pos.x, dz = cz - P.pos.z; const dl = Math.hypot(dx, dz); if (dl < 6 || dl > 34) continue;
    dx /= dl; dz /= dl;
    const ext = Math.abs(dx) * (b.x1 - b.x0) / 2 + Math.abs(dz) * (b.z1 - b.z0) / 2;
    const px = cx + dx * (ext + 0.75), pz = cz + dz * (ext + 0.75);
    if (isBlocked(px, pz, 0.35)) continue;
    if (segClear(P.pos.x, P.pos.y + 1.4, P.pos.z, px, 0.95, pz)) continue;
    const sc = Math.hypot(px - e.pos.x, pz - e.pos.z) + Math.random() * 4 + (ENEMIES.some(o => o !== e && o.cover && Math.hypot(o.cover.x - px, o.cover.z - pz) < 2) ? 20 : 0);
    if (sc < bs) { bs = sc; best = { x: px, z: pz, b }; }
  }
  return best;
}
const _emz = new THREE.Vector3(), _ehp = new THREE.Vector3();
function enemyShoot(e) {
  const tp = e.canSee; if (!tp) return;
  e.gun.userData.muzzle.getWorldPosition(_emz);
  const d = Math.hypot(P.pos.x - e.pos.x, P.pos.z - e.pos.z);
  let p = e.T.acc * clamp(1.25 - d / 38, 0.25, 1.05);
  if (P.crouch && !P.aiming) p *= 0.6;
  if (P.speed > 3.5) p *= 0.65;
  if (P.downT > 0) p *= 0.5;
  const hit = Math.random() < p;
  let tx = tp[0], ty = tp[1], tz = tp[2];
  if (!hit) { tx += rand(-1.3, 1.3); ty += rand(-0.6, 0.9); tz += rand(-1.3, 1.3); }
  const dx = tx - _emz.x, dy = ty - _emz.y, dz = tz - _emz.z, L = Math.hypot(dx, dy, dz) || 1;
  const tw = raycastWorld(_emz.x, _emz.y, _emz.z, dx / L, dy / L, dz / L, hit ? L : 80);
  const end = hit ? L : (tw === Infinity ? 80 : tw);
  _ehp.set(_emz.x + dx / L * end, _emz.y + dy / L * end, _emz.z + dz / L * end);
  addTracer(_emz, _ehp, [1, 0.5, 0.35]);
  PFX_ADD.spawn(_emz.x, _emz.y, _emz.z, 0, 0, 0, 0.05, 0.4, 0.2, 1, 1, 0.7, 0.3);
  if (!hit && tw !== Infinity) PFX_SMOKE.spawn(_ehp.x, _ehp.y, _ehp.z, 0, 0.5, 0, 0.6, 0.2, 0.7, 0.4, 0.85, 0.9, 0.95, 1.5, -1);
  sfxShot(e.T.gun, _emz.x, _emz.y, _emz.z, false, 0.8);
  alertPeds(e.pos.x, e.pos.z, 40);
  if (hit && P.car) { P.car.hp -= 3; if (Math.random() < 0.35) hurtPlayer(e.T.dmg * 0.6, e.pos); }
  else if (hit) hurtPlayer(e.T.dmg, e.pos);
  else {
    if (tw !== Infinity) sfxImpact(hitMaterial(_ehp.x, _ehp.y, _ehp.z), _ehp.x, _ehp.y, _ehp.z, 0.45);
    const near = nearMiss(_emz, _ehp, P.pos.x, P.pos.y + 1.5, P.pos.z);
    if (near) sfx.whiz(near.x, near.y, near.z);
  }
}
function damageEnemy(e, dmg, head, dir) {
  if (e.state === 'down') return;
  e.hp -= dmg; e.flash = 0.1;
  bloodBurst(e.pos.x, e.pos.y + (head ? 1.6 : 1.15), e.pos.z, dir ? dir.x : 0, dir ? dir.z : 0, head ? 12 : 8);
  for (const m of e.h.mats) m.emissive.setRGB(0.6, 0.6, 0.6);
  const c = e.crew;
  if (c.state !== 'combat') crewEngage(c, 'shot');
  e.seeT = Math.max(e.seeT, 0.3);
  if (e.hp <= 0) downEnemy(e);
}
function downEnemy(e) {
  e.state = 'down'; e.downT = 0; e.crouched = false;
  sfx.down(e.pos.x, e.pos.z);
  setTimeout(() => bloodPool(e.pos.x, e.pos.y, e.pos.z, rand(1.4, 2.1)), 700);
  S.stats.downs++;
  addHeat(3);
  if (e.type === 'saint') {
    S.flags.saintDown = true;
    banner('@saint.halo is down', '');
    setTimeout(() => triggerEnding('crown'), 2600);
  }
}
function onPlayerShot(x, z, supp) {
  const r = supp ? 22 : 65;
  for (const c of CREWS) {
    if (c.state !== 'approach' && c.state !== 'standoff') continue;
    if (c.members.some(e => Math.hypot(e.pos.x - x, e.pos.z - z) < r)) crewEngage(c, 'shot');
  }
}
function updateCrews(dt) {
  for (let i = CREWS.length - 1; i >= 0; i--) {
    const c = CREWS[i];
    const alive = c.members.filter(e => e.state !== 'down');
    if (!alive.length) { if (!c.over) { c.over = true; crewDefeated(c); } if (!c.members.some(e => !e.dead)) CREWS.splice(i, 1); continue; }
    let dmin = Infinity; for (const e of alive) dmin = Math.min(dmin, Math.hypot(e.pos.x - P.pos.x, e.pos.z - P.pos.z));
    c.t += dt;
    if (c.state === 'approach') {
      if (dmin < 18 && alive.some(e => e.canSee)) crewNotice(c);
      else if (dmin < 8) crewNotice(c);
      if (c.t > 100) c.state = 'leave';
    } else if (c.state === 'standoff') {
      c.so += dt;
      if (P.aiming) c.aimHold += dt; else c.aimHold = Math.max(0, c.aimHold - dt * 2);
      if (c.aimHold > 0.35) crewEngage(c, 'aim');
      else if (dmin < 5.2) crewEngage(c, 'close');
      else if (c.so > 20) crewEngage(c, 'time');
      else if (dmin > 42) crewWalkAway(c, true);
    } else if (c.state === 'combat') {
      if (dmin > 95 || P.dead) { c.state = 'leave'; c.leaveT = 0; for (const e of alive) e.leaveTo = { x: e.pos.x + rand(-40, 40), z: e.pos.z + rand(-40, 40) }; }
    } else if (c.state === 'leave') {
      c.leaveT += dt;
      if (dmin > 70 || c.leaveT > 25) { for (const e of c.members) { scene.remove(e.h.group); e.dead = true; } }
    }
    if (c.members.every(e => e.dead)) { for (const e of c.members) { const k = ENEMIES.indexOf(e); if (k >= 0) ENEMIES.splice(k, 1); } CREWS.splice(i, 1); }
  }
}
function updateEnemies(dt) {
  updateCrews(dt);
  for (let i = ENEMIES.length - 1; i >= 0; i--) {
    const e = ENEMIES[i];
    if (e.dead) { scene.remove(e.h.group); ENEMIES.splice(i, 1); continue; }
    updateEnemy(e, dt);
  }
}
function updateEnemy(e, dt) {
  const H = e.h;
  if (e.flash > 0) { e.flash -= dt; if (e.flash <= 0) for (const m of H.mats) m.emissive.setRGB(0, 0, 0); }
  if (e.state === 'down') {
    e.downT += dt;
    if (e.vel.lengthSq() > 0.01) { e.vel.x *= Math.exp(-dt * 3); e.vel.z *= Math.exp(-dt * 3); moveBody(e, e.vel.x * dt, e.vel.z * dt, dt); H.group.position.copy(e.pos); }
    animHuman(H, dt, { down: Math.min(1, e.downT / 0.55) });
    e.gun.visible = false; e.plate.visible = false;
    if (e.downT > 24) {
      const f = Math.max(0, 1 - (e.downT - 24) / 2);
      for (const m of H.mats) { m.transparent = true; m.opacity = f; m.depthWrite = f > 0.5; }
      e.plate.material.opacity = f; e.gun.visible = false; H.shadow.visible = false;
    }
    if (e.downT > 26.5) e.dead = true;
    return;
  }
  if (e.knockT > 0) { e.knockT -= dt; e.vel.x *= Math.exp(-dt * 2); e.vel.z *= Math.exp(-dt * 2); moveBody(e, e.vel.x * dt, e.vel.z * dt, dt); H.group.position.copy(e.pos); animHuman(H, dt, { down: Math.min(1, e.knockT * 1.5) }); return; }
  const c = e.crew;
  const dx = P.pos.x - e.pos.x, dz = P.pos.z - e.pos.z, d = Math.hypot(dx, dz);
  e.losT -= dt; if (e.losT <= 0) { e.losT = 0.16 + Math.random() * 0.12; e.canSee = enemySees(e); }
  if (e.canSee) e.seeT += dt; else e.seeT = Math.max(0, e.seeT - dt * 2);
  let goal = null, speed = 0, aim = 0, face = Math.atan2(dx, dz), wantCrouch = false, strafe = 0;
  if (c.state === 'approach') { goal = navTarget(e, P.pos.x, P.pos.z, P.pos.y, dt); speed = e.T.speed * 0.75; if (d < 25) face = Math.atan2(dx, dz); else face = null; }
  else if (c.state === 'standoff') {
    aim = 0.35;
    if (d > 15) { goal = navTarget(e, P.pos.x, P.pos.z, P.pos.y, dt); speed = 2.0; }
    else if (d < 8.5) { goal = { x: e.pos.x - dx / d * 3, z: e.pos.z - dz / d * 3 }; speed = 1.2; }
  } else if (c.state === 'combat') {
    aim = e.canSee ? 1 : 0.6;
    if (e.type === 'runner') {
      if (!e.canSee || d > 13) { goal = navTarget(e, P.pos.x, P.pos.z, P.pos.y, dt); speed = e.T.speed; }
      else {
        e.strafeT -= dt; if (e.strafeT <= 0) { e.strafeT = rand(0.9, 2); e.strafe *= -1; }
        strafe = e.strafe; speed = 2.8;
        if (d > 9) goal = { x: P.pos.x, z: P.pos.z };
        else if (d < 5) goal = { x: e.pos.x - dx, z: e.pos.z - dz };
      }
    } else {
      e.phaseT -= dt; e.coverT -= dt;
      if (e.phase === 'seek') {
        if (!e.cover || e.coverT <= 0) { e.cover = findCover(e); e.coverT = 4; }
        if (e.cover) {
          goal = navTarget(e, e.cover.x, e.cover.z, 0, dt); speed = e.T.speed;
          if (Math.hypot(e.cover.x - e.pos.x, e.cover.z - e.pos.z) < 0.9) { e.phase = 'hide'; e.phaseT = rand(1.0, 2.0); }
        } else {
          if (!e.canSee || d > 17) { goal = navTarget(e, P.pos.x, P.pos.z, P.pos.y, dt); speed = e.T.speed * 0.8; }
          else if (d < 11) { goal = { x: e.pos.x - dx, z: e.pos.z - dz }; speed = 2; }
          else { e.strafeT -= dt; if (e.strafeT <= 0) { e.strafeT = rand(1.2, 2.4); e.strafe *= -1; } strafe = e.strafe; speed = 2.2; }
        }
      } else if (e.phase === 'hide') {
        wantCrouch = true; aim = 0.3;
        if (e.losT < 0.05 && e.canSee) { e.phase = 'seek'; e.cover = null; }
        if (e.phaseT <= 0) { e.phase = 'peek'; e.phaseT = rand(1.3, 2.0); e.burstLeft = 0; }
      } else if (e.phase === 'peek') {
        wantCrouch = false; aim = 1;
        if (e.phaseT <= 0) { e.phase = 'hide'; e.phaseT = rand(1.2, 2.4); if (Math.hypot(P.pos.x - e.pos.x, P.pos.z - e.pos.z) < 6) e.phase = 'seek'; }
      }
    }
    // shooting
    e.fireCd -= dt;
    if (e.canSee && e.seeT > 0.35 && e.fireCd <= 0 && !wantCrouch) {
      enemyShoot(e);
      if (e.burstLeft > 0) { e.burstLeft--; e.fireCd = e.burstLeft > 0 ? e.T.rate : rand(0.9, 1.5); }
      else { e.burstLeft = e.T.burst - 1; e.fireCd = e.burstLeft > 0 ? e.T.rate : rand(0.55, 1.05); }
    }
  } else if (c.state === 'leave') {
    if (e.leaveTo) { goal = navTarget(e, e.leaveTo.x, e.leaveTo.z, 0, dt); speed = 3.2; face = null; }
  }
  e.crouched = wantCrouch;
  // steering
  let vx = 0, vz = 0;
  if (goal) { const gx = goal.x - e.pos.x, gz = goal.z - e.pos.z, gl = Math.hypot(gx, gz); if (gl > 0.3) { vx = gx / gl * speed; vz = gz / gl * speed; } }
  if (strafe && d > 0.1) { vx += -dz / d * strafe * speed; vz += dx / d * strafe * speed; }
  for (const o of ENEMIES) { if (o === e || o.state === 'down') continue; const ox = e.pos.x - o.pos.x, oz = e.pos.z - o.pos.z, ol = Math.hypot(ox, oz); if (ol < 1.3 && ol > 0.01) { vx += ox / ol * 2; vz += oz / ol * 2; } }
  if (e.sideT > 0) { e.sideT -= dt; vx += e.side * -vz * 0 + e.sideX * 3; vz += e.sideZ * 3; }
  const k = 1 - Math.exp(-dt * 8);
  e.vel.x += (vx - e.vel.x) * k; e.vel.z += (vz - e.vel.z) * k;
  moveBody(e, e.vel.x * dt, e.vel.z * dt, dt);
  // stuck detection
  e.stuckT += dt;
  if (e.stuckT > 1) {
    const moved = Math.hypot(e.pos.x - e.lastX, e.pos.z - e.lastZ);
    if (speed > 1 && moved < 0.35) { const a = Math.atan2(vx, vz) + (Math.random() < 0.5 ? 1.57 : -1.57); e.sideX = Math.sin(a); e.sideZ = Math.cos(a); e.sideT = 0.8; e.pathAge = 99; e.pathT = 0; }
    e.stuckT = 0; e.lastX = e.pos.x; e.lastZ = e.pos.z;
  }
  const sp = Math.hypot(e.vel.x, e.vel.z);
  if (face === null && sp > 0.5) face = Math.atan2(e.vel.x, e.vel.z);
  if (face !== null) e.yaw += angDiff(e.yaw, face) * (1 - Math.exp(-dt * 9));
  H.group.position.copy(e.pos); H.group.rotation.y = e.yaw;
  const pitch = Math.atan2((P.pos.y + 1.2) - (e.pos.y + 1.4), Math.max(1, d));
  animHuman(H, dt, { speed: sp, crouch: e.crouched, aim, pitch, twoHand: e.T.gun !== 'k9' });
  e.plate.position.y = e.crouched ? 1.55 : 2.15;
}

/* =========================================================
   AMBUSH DIRECTOR
   ========================================================= */
let ambushT = 90;
function findSpawnPoint(minD, maxD) {
  for (let i = 0; i < 50; i++) {
    let x, z;
    if (Math.random() < 0.5) { x = pick(XL) + rand(-3, 3); z = P.pos.z + rand(-maxD, maxD); }
    else { z = pick(ZL) + rand(-3, 3); x = P.pos.x + rand(-maxD, maxD); }
    if (Math.abs(x) > MAP_HALF - 10 || Math.abs(z) > MAP_HALF - 10 || x > SHORE_X + 8) continue;
    const d = Math.hypot(x - P.pos.x, z - P.pos.z); if (d < minD || d > maxD) continue;
    if (isBlocked(x, z)) continue;
    if (i < 35 && segClear(P.pos.x, P.pos.y + 1.5, P.pos.z, x, 1.5, z)) continue;
    return { x, z };
  }
  return null;
}
function ambushDirector(dt) {
  if (CREWS.some(c => c.state !== 'leave')) return;
  if (S.heat < 30 || S.playTime < 40) { ambushT = Math.max(ambushT, 20); return; }
  ambushT -= dt; if (ambushT > 0) return;
  ambushT = S.heat >= 75 ? rand(40, 65) : S.heat >= 50 ? rand(70, 105) : rand(110, 160);
  if ((S.flags.calmUntil || 0) > S.playTime) ambushT *= 2;
  const sp = findSpawnPoint(42, 75); if (!sp) { ambushT = 8; return; }
  const n = S.heat >= 75 ? 4 : S.heat >= 50 ? 3 : 2;
  const shooters = S.heat >= 75 ? 2 : S.heat >= 50 ? 1 : 0;
  const saint = !S.flags.saintDown && S.stats.disses >= 1 && S.heat >= 60 && Math.random() < 0.4 && !((S.flags.calmUntil || 0) > S.playTime);
  spawnCrew({ x: sp.x, z: sp.z, n, shooters, saint });
  if (saint) sendMsg('saint', 'I see you.');
  else if (Math.random() < 0.5) postFeed(pick(FEED_HANDLES), pick(['halo crew rolling deep tonight 👀', `seen @halo crew walking ${streetName(sp.x, sp.z)}`, 'somebody about to get a visit']));
}
