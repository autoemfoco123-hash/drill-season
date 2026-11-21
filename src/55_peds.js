
/* =========================================================
   BLOOD - hit spray and pools
   ========================================================= */
const PFX_BLOOD = new Particles(420, TEX.dot, THREE.NormalBlending);
TEX.pool = canvasTex(128, 128, (g, w) => {
  for (let i = 0; i < 14; i++) {
    const x = w / 2 + rand(-24, 24), y = w / 2 + rand(-24, 24), r = rand(12, 34);
    const gr = g.createRadialGradient(x, y, 0, x, y, r); gr.addColorStop(0, 'rgba(70,4,6,.95)'); gr.addColorStop(0.75, 'rgba(60,3,5,.85)'); gr.addColorStop(1, 'rgba(60,3,5,0)');
    g.fillStyle = gr; g.beginPath(); g.ellipse(x, y, r, r * rand(0.6, 1), rand(0, 3), 0, TAU); g.fill();
  }
}, { repeat: false });
const POOLS = [];
const poolGeo = new THREE.PlaneGeometry(1, 1); poolGeo.rotateX(-Math.PI / 2);
function bloodBurst(x, y, z, dx, dz, n) {
  const l = Math.hypot(dx || 0, dz || 0) || 1;
  for (let i = 0; i < (n || 8); i++) PFX_BLOOD.spawn(x, y, z, (dx || 0) / l * rand(0.5, 2.5) + rand(-1.2, 1.2), rand(0.4, 2.8), (dz || 0) / l * rand(0.5, 2.5) + rand(-1.2, 1.2), rand(0.35, 0.7), rand(0.05, 0.11), 0.03, 0.95, 0.36, 0.015, 0.02, 0.4, -9.8);
}
function bloodPool(x, y, z, size) {
  let p = POOLS.length >= 24 ? POOLS.shift() : null;
  if (!p) { p = new THREE.Mesh(poolGeo, new THREE.MeshStandardMaterial({ map: TEX.pool, transparent: true, depthWrite: false, roughness: 0.18, metalness: 0.1, polygonOffset: true, polygonOffsetFactor: -3, polygonOffsetUnits: -6 })); p.receiveShadow = true; p.renderOrder = 1; scene.add(p); }
  p.position.set(x, y + 0.035, z); p.rotation.y = rand(0, TAU);
  p.userData = { t: 0, size: size || rand(1.3, 2.0) }; p.scale.setScalar(0.1); p.material.opacity = 1; p.visible = true;
  POOLS.push(p);
}
function updateBlood(dt) {
  PFX_BLOOD.update(dt, 0, 0);
  for (const p of POOLS) {
    const u = p.userData; u.t += dt;
    p.scale.setScalar(u.size * Math.min(1, 0.15 + u.t / 3.5));
    if (u.t > 50) { p.material.opacity = Math.max(0, 1 - (u.t - 50) / 10); if (u.t > 60) p.visible = false; }
  }
}

/* =========================================================
   PEDESTRIANS - walk the sidewalks, flee gunfire
   ========================================================= */
const PEDS = [];
const N_PEDS = IS_TOUCH ? 8 : 16;
const PED_JACKETS = [0x1d1f24, 0x2a3a4e, 0x4a2a22, 0x5a5e66, 0x6a5040, 0x233a2a, 0x7a1e22, 0x3a2e4a, 0x8a7a5a, 0x15181c, 0xb0a890];
const PED_SKIN = [0x5a3a26, 0x7a4a30, 0x4a2e1e, 0x8a5a3a, 0xa87a58, 0xc89a78, 0x6b4630];
function pedLook() { return skinHumanOpts(randomSkin()); }
// sidewalk corner graph on the 3x3 street grid
const SW = 8;
const cornerPos = (ix, iz, sx, sz) => ({ x: XL[ix] + SW * sx, z: ZL[iz] + SW * sz });
function cornerNext(c, prev) {
  const opts = [];
  opts.push({ ix: c.ix, iz: c.iz, sx: -c.sx, sz: c.sz, cross: true });
  opts.push({ ix: c.ix, iz: c.iz, sx: c.sx, sz: -c.sz, cross: true });
  if (c.ix + c.sx >= 0 && c.ix + c.sx < XL.length) opts.push({ ix: c.ix + c.sx, iz: c.iz, sx: -c.sx, sz: c.sz });
  if (c.iz + c.sz >= 0 && c.iz + c.sz < ZL.length) opts.push({ ix: c.ix, iz: c.iz + c.sz, sx: c.sx, sz: -c.sz });
  const non = opts.filter(o => !prev || !(o.ix === prev.ix && o.iz === prev.iz && o.sx === prev.sx && o.sz === prev.sz));
  const walks = non.filter(o => !o.cross);
  return (walks.length && Math.random() < 0.75) ? pick(walks) : pick(non.length ? non : opts);
}
function makePed(x, z, look) {
  const h = buildHuman(look || pedLook());
  scene.add(h.group);
  const p = { h, pos: new THREE.Vector3(x, 0, z), vel: new THREE.Vector3(), radius: 0.3, height: 1.7, onGround: true, airY: 0, yaw: rand(0, TAU), state: 'walk', node: null, prev: null, target: null, speed: rand(1.15, 1.6), fleeT: 0, from: null, downT: 0, hp: 40, stuckT: 0, lastX: x, lastZ: z, knockT: 0, idleT: 0, phoneT: rand(0, 20) };
  h.group.position.copy(p.pos);
  PEDS.push(p);
  return p;
}
function placePedOnGraph(p, nearX, nearZ, minD, maxD) {
  for (let k = 0; k < 40; k++) {
    const c = { ix: randi(0, XL.length - 1), iz: randi(0, ZL.length - 1), sx: Math.random() < 0.5 ? -1 : 1, sz: Math.random() < 0.5 ? -1 : 1 };
    const n = cornerNext(c, null);
    const a = cornerPos(c.ix, c.iz, c.sx, c.sz), b = cornerPos(n.ix, n.iz, n.sx, n.sz);
    const t = Math.random(), x = lerp(a.x, b.x, t), z = lerp(a.z, b.z, t);
    const d = Math.hypot(x - nearX, z - nearZ);
    if (d < minD || d > maxD || isBlocked(x, z, 0.4)) continue;
    if (k < 30 && segClear(P.pos.x, P.pos.y + 1.6, P.pos.z, x, 1.4, z) && d < 70) continue;
    p.pos.set(x, 0, z); p.vel.set(0, 0, 0); p.node = n; p.prev = c; p.target = b; p.state = 'walk'; p.hp = 40; p.downT = 0;
    for (const m of p.h.mats) { m.transparent = false; m.opacity = 1; }
    p.h.group.visible = true; p.h.shadow.visible = true;
    return true;
  }
  return false;
}
function spawnFleeingDriver(x, z) {
  const p = makePed(x, z);
  p.state = 'flee'; p.fleeT = 9; p.from = { x: P.pos.x, z: P.pos.z }; p.temp = true;
  return p;
}
function alertPeds(x, z, r) {
  for (const p of PEDS) if (p.state !== 'down' && Math.hypot(p.pos.x - x, p.pos.z - z) < r) { p.state = 'flee'; p.fleeT = rand(7, 11); p.from = { x, z }; }
}
function witnesses(x, z, r) {
  let n = 0;
  for (const p of PEDS) if (p.state !== 'down' && Math.hypot(p.pos.x - x, p.pos.z - z) < r) n++;
  for (const c of COPS) if (c.state !== 'down' && Math.hypot(c.pos.x - x, c.pos.z - z) < r * 1.4) n += 3;
  for (const v of TRAFFIC) if (Math.hypot(v.pos.x - x, v.pos.z - z) < r) n++;
  return n;
}
function pedHit(p, dmg, dir, byPlayer) {
  if (p.state === 'down') return;
  p.hp -= dmg;
  bloodBurst(p.pos.x, p.pos.y + 1.2, p.pos.z, dir ? dir.x : 0, dir ? dir.z : 0, 10);
  if (p.hp <= 0) {
    p.state = 'down'; p.downT = 0;
    sfx.down(p.pos.x, p.pos.z);
    setTimeout(() => bloodPool(p.pos.x, p.pos.y, p.pos.z, rand(1.4, 2.1)), 700);
    if (byPlayer) { addWanted(22, p.pos); addHeat(5); S.stats.civilians = (S.stats.civilians || 0) + 1; postFeed(pick(FEED_HANDLES), pick([`somebody got hurt on ${streetName(p.pos.x, p.pos.z)}. police everywhere`, `${streetName(p.pos.x, p.pos.z)} taped off rn`])); }
  } else { p.state = 'flee'; p.fleeT = 10; p.from = { x: p.pos.x - (dir ? dir.x : 0), z: p.pos.z - (dir ? dir.z : 0) }; if (byPlayer) addWanted(10, p.pos); }
  alertPeds(p.pos.x, p.pos.z, 30);
}
let pedSpawnT = 0;
function updatePeds(dt) {
  pedSpawnT -= dt;
  if (pedSpawnT <= 0) {
    pedSpawnT = 1;
    if (PEDS.filter(p => !p.temp).length < N_PEDS) { const p = makePed(0, 0); if (!placePedOnGraph(p, P.pos.x, P.pos.z, 25, 95)) { scene.remove(p.h.group); PEDS.pop(); } }
  }
  for (let i = PEDS.length - 1; i >= 0; i--) {
    const p = PEDS[i];
    const H = p.h;
    const dP = Math.hypot(p.pos.x - P.pos.x, p.pos.z - P.pos.z);
    if (p.state === 'down') {
      p.downT += dt;
      if (p.vel.lengthSq() > 0.01) { p.vel.x *= Math.exp(-dt * 3); p.vel.z *= Math.exp(-dt * 3); moveBody(p, p.vel.x * dt, p.vel.z * dt, dt); H.group.position.copy(p.pos); }
      animHuman(H, dt, { down: Math.min(1, p.downT / 0.5) });
      if (p.downT > 40) {
        const f = Math.max(0, 1 - (p.downT - 40) / 3);
        for (const m of H.mats) { m.transparent = true; m.opacity = f; }
        H.shadow.visible = false;
        if (p.downT > 43) { if (p.temp) { scene.remove(H.group); PEDS.splice(i, 1); } else if (!placePedOnGraph(p, P.pos.x, P.pos.z, 45, 95)) { scene.remove(H.group); PEDS.splice(i, 1); } }
      }
      continue;
    }
    if (dP > 100) { if (p.temp) { scene.remove(H.group); PEDS.splice(i, 1); } else placePedOnGraph(p, P.pos.x, P.pos.z, 45, 90); continue; }
    let tx = null, tz = null, speed = 0;
    if (p.state === 'flee') {
      p.fleeT -= dt;
      const ax = p.pos.x - p.from.x, az = p.pos.z - p.from.z, al = Math.hypot(ax, az) || 1;
      tx = p.pos.x + ax / al * 6; tz = p.pos.z + az / al * 6; speed = 5.4;
      if (p.fleeT <= 0) {
        p.state = 'walk';
        // rejoin the nearest corner
        let best = null, bd = Infinity;
        for (let ix = 0; ix < XL.length; ix++) for (let iz = 0; iz < ZL.length; iz++) for (const sx of [-1, 1]) for (const sz of [-1, 1]) { const c = cornerPos(ix, iz, sx, sz); const d = Math.hypot(c.x - p.pos.x, c.z - p.pos.z); if (d < bd) { bd = d; best = { ix, iz, sx, sz }; } }
        p.node = best; p.prev = null; p.target = cornerPos(best.ix, best.iz, best.sx, best.sz);
      }
    } else {
      if (p.idleT > 0) { p.idleT -= dt; }
      else if (p.target) {
        tx = p.target.x; tz = p.target.z; speed = p.speed;
        if (Math.hypot(p.target.x - p.pos.x, p.target.z - p.pos.z) < 0.9) {
          const n = cornerNext(p.node, p.prev);
          if (n.cross) {
            // cross with the light (or just go, it's Chicago)
            const ix = n.ix, iz = n.iz;
            const axis = n.sx !== p.node.sx ? 'z' : 'x';
            if (signalState(ix, iz, axis) === 'g' && Math.random() < 0.85) { p.idleT = rand(1.5, 4); }
          } else if (Math.random() < 0.15) p.idleT = rand(2, 6);
          p.prev = p.node; p.node = n; p.target = cornerPos(n.ix, n.iz, n.sx, n.sz);
        }
      }
      // react to the player aiming at them up close
      if (P.aimT > 0.6 && !P.car && dP < 12) {
        const toP = Math.atan2(p.pos.x - P.pos.x, p.pos.z - P.pos.z);
        if (Math.abs(angDiff(camYaw + Math.PI, toP)) < 0.25) { p.state = 'flee'; p.fleeT = 8; p.from = { x: P.pos.x, z: P.pos.z }; }
      }
    }
    const answering = p.state === 'walk' && pedFlipBack(p, dt);
    if (answering) tx = null;
    let vx = 0, vz = 0;
    if (tx !== null) { const dx = tx - p.pos.x, dz = tz - p.pos.z, l = Math.hypot(dx, dz); if (l > 0.05) { vx = dx / l * speed; vz = dz / l * speed; } }
    // keep out of each other's way
    for (const o of PEDS) { if (o === p || o.state === 'down') continue; const ox = p.pos.x - o.pos.x, oz = p.pos.z - o.pos.z, ol = Math.hypot(ox, oz); if (ol < 0.8 && ol > 0.01) { vx += ox / ol * 1.2; vz += oz / ol * 1.2; } }
    const k = 1 - Math.exp(-dt * 6);
    p.vel.x += (vx - p.vel.x) * k; p.vel.z += (vz - p.vel.z) * k;
    moveBody(p, p.vel.x * dt, p.vel.z * dt, dt);
    p.stuckT += dt;
    if (p.stuckT > 2) { if (speed > 0.5 && Math.hypot(p.pos.x - p.lastX, p.pos.z - p.lastZ) < 0.4 && p.state === 'walk') { const n = cornerNext(p.node || { ix: 0, iz: 0, sx: 1, sz: 1 }, null); p.prev = p.node; p.node = n; p.target = cornerPos(n.ix, n.iz, n.sx, n.sz); } p.stuckT = 0; p.lastX = p.pos.x; p.lastZ = p.pos.z; }
    const sp = Math.hypot(p.vel.x, p.vel.z);
    if (sp > 0.2 && !answering) p.yaw += angDiff(p.yaw, Math.atan2(p.vel.x, p.vel.z)) * (1 - Math.exp(-dt * 8));
    H.group.position.copy(p.pos); H.group.rotation.y = p.yaw;
    if (dP < 70) animHuman(H, dt, { speed: sp, crouch: p.state === 'flee' && sp < 0.6, mug: p.state === 'walk' && !answering && ((REAL_T + p.phoneT) % 20) < 6, flip: answering });
  }
}
