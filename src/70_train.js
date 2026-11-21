
/* =========================================================
   THE L TRAIN - scheduled, stops at Calder, knocks you down
   ========================================================= */
const CAR_L = 14.6, TRAIN_CARS = 4, TRAIN_HALF = CAR_L * TRAIN_CARS / 2;
const TRAIN_CYCLE = 96;
function buildTrainMesh(dir) {
  const g = new THREE.Group();
  const body = new Batch(), em = new Batch();
  for (let c = 0; c < TRAIN_CARS; c++) {
    const zc = (c - (TRAIN_CARS - 1) / 2) * CAR_L;
    vbox(body, 0, 0.05, zc, 2.3, 0.55, 13.2, 0x15171a);
    vbox(body, 0, 0.55, zc, 2.9, 2.75, 14.2, 0x9aa4ae);
    vbox(body, 0, 3.3, zc, 2.6, 0.22, 13.9, 0x707884);
    vbox(body, 0, 3.52, zc, 2.3, 0.1, 13.4, 0xe8f0f8);
    for (const s of [-1, 1]) {
      vbox(body, s * 1.456, 1.02, zc, 0.02, 0.14, 14.2, 0x2a5fa0);
      for (let w = 0; w < 5; w++) vbox(em, s * 1.458, 1.62, zc - 5.6 + w * 2.8, 0.02, 0.92, 1.9, 0xffe3b8);
      for (const dz of [-3.5, 3.5]) vbox(body, s * 1.459, 0.62, zc + dz, 0.02, 2.36, 1.3, 0x7a838d);
    }
    for (const s of [-1, 1]) for (const zz of [-5, 5]) vbox(body, s * 0.9, -0.15, zc + zz, 0.3, 0.5, 1.8, 0x0b0c0e);
  }
  for (const end of [-1, 1]) {
    const ez = end * (TRAIN_HALF - 0.3);
    for (const s of [-0.85, 0.85]) vbox(em, s, 1.0, ez + end * 0.32, 0.32, 0.22, 0.03, end === dir ? 0xfff6e0 : 0xff2a14);
    vbox(em, 0, 2.75, ez + end * 0.32, 1.1, 0.32, 0.03, 0xffb030);
    vbox(em, 0, 1.75, ez + end * 0.32, 1.6, 0.8, 0.02, 0x40506a);
  }
  const m1 = new THREE.Mesh(body.build(), MAT.props), m2 = new THREE.Mesh(em.build(), MAT.emis);
  g.add(m1, m2);
  const glow = new THREE.Sprite(new THREE.SpriteMaterial({ map: TEX.glow, color: 0xfff0d0, transparent: true, opacity: 0.9, blending: THREE.AdditiveBlending, depthWrite: false }));
  glow.scale.set(5, 3, 1); glow.position.set(0, 1.0, dir * (TRAIN_HALF + 0.4)); g.add(glow);
  const spill = new THREE.Mesh(new THREE.PlaneGeometry(9, CAR_L * TRAIN_CARS), new THREE.MeshBasicMaterial({ map: TEX.glow, color: 0x6a5030, transparent: true, opacity: 0.0, blending: THREE.AdditiveBlending, depthWrite: false }));
  spill.rotation.x = -Math.PI / 2; spill.position.y = 0.3; g.add(spill);
  g.userData.spill = spill;
  return g;
}
const TRAINS = [
  { x: TRACKS[1], dir: 1, off: 0, mesh: null, z: -999, v: 0, state: 'gone', box: null, clack: 0, sx: 0 },
  { x: TRACKS[0], dir: -1, off: 48, mesh: null, z: 999, v: 0, state: 'gone', box: null, clack: 0, sx: 0 },
];
for (const T of TRAINS) {
  T.mesh = buildTrainMesh(T.dir);
  T.mesh.position.set(T.x, DECK_Y + 0.12, T.z); T.mesh.visible = false; scene.add(T.mesh);
  T.box = { x0: T.x - 1.5, x1: T.x + 1.5, y0: DECK_Y + 0.1, y1: DECK_Y + 3.7, z0: 0, z1: 0, on: false, tag: 'train' };
  DYN_BOXES.push(T.box);
}
const T1 = 17, T2 = 9, T3 = 15, RUN = 270;
function trainAt(T, t) {
  const ph = ((t + T.off) % TRAIN_CYCLE + TRAIN_CYCLE) % TRAIN_CYCLE;
  const z0 = -T.dir * RUN;
  if (ph < T1) { const u = ph / T1; return { z: z0 * (1 - (1 - (1 - u) * (1 - u))), v: -z0 * 2 * (1 - u) / T1, state: 'arrive', u }; }
  if (ph < T1 + T2) return { z: 0, v: 0, state: 'dwell', u: (ph - T1) / T2 };
  if (ph < T1 + T2 + T3) { const u = (ph - T1 - T2) / T3; return { z: T.dir * RUN * u * u, v: T.dir * RUN * 2 * u / T3, state: 'depart', u }; }
  return { z: T.dir * 999, v: 0, state: 'gone', u: 0 };
}
// seconds until the next arrival at Calder, for the phone / hud
function nextTrainIn() {
  let best = 999;
  for (const T of TRAINS) { const ph = ((worldSeconds() + T.off) % TRAIN_CYCLE + TRAIN_CYCLE) % TRAIN_CYCLE; const until = ph < T1 ? T1 - ph : TRAIN_CYCLE - ph + T1; best = Math.min(best, until); }
  return best;
}
function updateTrains(dt) {
  for (const T of TRAINS) {
    const prev = T.state;
    const s = trainAt(T, worldSeconds());
    T.z = s.z; T.v = s.v; T.state = s.state;
    const vis = s.state !== 'gone' && Math.abs(s.z) < 330;
    T.mesh.visible = vis;
    T.mesh.position.z = s.z;
    T.box.on = vis && Math.abs(s.z) < BOUND + TRAIN_HALF;
    T.box.z0 = s.z - TRAIN_HALF; T.box.z1 = s.z + TRAIN_HALF;
    T.mesh.userData.spill.material.opacity = vis ? 0.5 : 0;
    if (!vis) continue;
    const dx = T.x - camera.position.x, dz = s.z - camera.position.z, d = Math.hypot(dx, Math.max(0, Math.abs(dz) - TRAIN_HALF));
    if (s.state === 'arrive' && s.u > 0.62 && !T.screeched && d < 140) { T.screeched = true; sfx.screech(T.x, s.z); }
    if (s.state !== 'arrive') T.screeched = false;
    if (prev === 'arrive' && s.state === 'dwell' && d < 120) { sfx.chime(T.x, 0); trainStopFX(T, 'open'); }
    if (s.state === 'dwell' && s.u > 0.8 && !T.closing) { T.closing = true; if (d < 120) { sfx.chime(T.x, 0); trainStopFX(T, 'close'); } }
    if (s.state !== 'dwell') T.closing = false;
  }
  trainAudio(dt);
  // knockdown + warning when you are on the tracks
  const py = P.pos.y;
  if (py > DECK_Y - 0.2 && py < DECK_Y + 2) {
    for (const T of TRAINS) {
      if (T.state === 'gone' || Math.abs(P.pos.x - T.x) > 1.9) continue;
      const rel = P.pos.z - T.z, ahead = rel * Math.sign(T.v || T.dir);
      if (Math.abs(T.v) > 0.6 && ahead > 0 && ahead < TRAIN_HALF + 90 && !P.trainWarned) { P.trainWarned = true; sfx.horn(T.x, T.z); banner('Train coming', 'Get off the tracks'); setTimeout(() => P.trainWarned = false, 4000); }
      if (Math.abs(rel) < TRAIN_HALF + P.radius && Math.abs(T.v) > 0.6 && P.downT <= 0) {
        const side = P.pos.x < T.x ? -1 : 1;
        P.vel.set(side * 7.5, 6.5, Math.sign(T.v) * 6);
        P.onGround = false; P.airY = P.pos.y; P.downT = 1.8;
        hurtPlayer(26 + Math.abs(T.v) * 0.7, null, true); sfx.thud(); P.shake = 1;
        banner('Knocked down by the L', 'Stay off the tracks');
        S.flags.trainHits = (S.flags.trainHits || 0) + 1;
        postFeed('@L_platform_lurker', `somebody really got clipped by the L at Calder 💀 ${S.flags.trainHits > 1 ? 'AGAIN' : ''}`);
      }
    }
  }
}
