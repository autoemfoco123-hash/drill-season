
/* =========================================================
   CUTSCENES - in-engine camera moves, letterboxed, skippable
   ========================================================= */
const CUT = { on: false, shots: [], i: -1, t: 0, end: null, a: new THREE.Vector3(), b: new THREE.Vector3(), la: new THREE.Vector3(), lb: new THREE.Vector3() };
const _look = new THREE.Vector3();
const V3 = (x, y, z) => new THREE.Vector3(x, y, z);
const easeIO = t => t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2;
function resolveV(v) { if (!v) return null; const r = typeof v === 'function' ? v() : v; return r.isVector3 ? r.clone() : V3(r[0], r[1], r[2]); }
function playCutscene(shots, end) {
  if (CUT.on) { if (end) end(); return; }
  CUT.on = true; CUT.shots = shots; CUT.i = -1; CUT.end = end || null;
  MODE = 'cutscene'; unlockPointer(); mouse.left = mouse.right = false; for (const k in keys) keys[k] = false;
  $('phone').hidden = true;
  document.body.classList.add('cine');
  sfx.stinger('cut');
  fpHide(); if (P.human) P.human.group.visible = !P.car;
  nextCutShot();
}
function nextCutShot() {
  CUT.i++;
  if (CUT.i >= CUT.shots.length) { endCutscene(); return; }
  const s = CUT.shots[CUT.i]; CUT.t = 0;
  if (s.start) s.start();
  CUT.a.copy(resolveV(s.from)); CUT.b.copy(resolveV(s.to) || CUT.a);
  CUT.la.copy(resolveV(s.look)); CUT.lb.copy(resolveV(s.lookTo) || CUT.la);
  camera.fov = s.fov || 50; camera.updateProjectionMatrix(); setParticleScale();
  if (s.say) say(s.say[0], s.say[1], s.say[2]);
  cutTitle(s.title || null, s.sub || '');
}
function updateCutscene(dt) {
  const s = CUT.shots[CUT.i]; if (!s) return;
  CUT.t += dt;
  const k = (s.ease || easeIO)(clamp(CUT.t / s.dur, 0, 1));
  camera.position.lerpVectors(CUT.a, CUT.b, k);
  _look.lerpVectors(CUT.la, CUT.lb, k);
  camera.lookAt(_look);
  if (s.tick) s.tick(dt, k);
  camera.updateMatrixWorld();
  if (CUT.t >= s.dur) nextCutShot();
}
function endCutscene() {
  if (!CUT.on) return;
  CUT.on = false;
  document.body.classList.remove('cine');
  cutTitle(null);
  MODE = 'play';
  camera.fov = 62; camera.updateProjectionMatrix(); setParticleScale();
  camYaw = P.car ? P.car.yaw + Math.PI : camYaw;
  const e = CUT.end; CUT.end = null;
  if (e) e();
  if (MODE === 'play') lockPointer();
}
function skipCutscene() { if (CUT.on) endCutscene(); }
let cutTitleT = null;
function cutTitle(t, sub) {
  const el = $('cut-title');
  if (!t) { el.classList.remove('on'); return; }
  el.querySelector('b').textContent = t; el.querySelector('span').textContent = sub || '';
  el.classList.remove('on'); void el.offsetWidth; el.classList.add('on');
}
// ---- the scenes ----
const headOf = () => V3(P.pos.x, P.pos.y + 1.5, P.pos.z);
const besidePlayer = (side, back, up) => () => { const f = { x: Math.sin(P.bodyYaw), z: Math.cos(P.bodyYaw) }, l = { x: Math.cos(P.bodyYaw), z: -Math.sin(P.bodyYaw) }; return V3(P.pos.x + l.x * side + f.x * back, P.pos.y + up, P.pos.z + l.z * side + f.z * back); };
function cutIntro() {
  return [
    { dur: 6, from: [-78, 52, 112], to: [-30, 36, 74], look: [30, 2, -30], lookTo: [48, 6, -40], fov: 46, title: 'Calder Park', sub: 'Chicago · ' + clockStr() },
    { dur: 5, from: [6, 1.4, 6.5], to: [30, 2.0, 5.2], look: [70, 8, -6], lookTo: [70, 8.6, -9], fov: 42 },
    { dur: 4.5, from: besidePlayer(1.8, 3.2, 1.9), to: besidePlayer(0.9, 2.2, 1.7), look: headOf, fov: 40, title: '@' + S.name, sub: 'Day ' + S.day, start: () => { P.human.group.visible = true; } },
  ];
}
function cutStudio() {
  return [
    { dur: 3.4, from: [35.5, 1.1, -1.5], to: [38.2, 1.5, -4.2], look: [41, 1.9, -10.4], fov: 40, say: [CAST.benny.name, "Booth's warm. Come down.", CAST.benny.color], start: () => { NPCS.benny.waveT = 3; } },
    { dur: 2.6, from: [44.5, 2.8, -4.5], to: [42.4, 1.5, -6.6], look: [41, 0, -9.8], fov: 44 },
  ];
}
function cutVideo() {
  return [
    { dur: 3.6, from: [62.0, 8.6, 18], to: [63.2, 8.2, 5], look: headOf, fov: 38, title: 'Rolling', sub: 'Hit your marks', start: () => { P.pose = 2.5; } },
  ];
}
function cutBusted() {
  return [
    { dur: 2.8, from: besidePlayer(3.2, 1.5, 0.6), to: besidePlayer(2.4, 2.4, 0.9), look: headOf, fov: 42, say: ['POLICE', 'Hands where I can see them!', '#71c6ff'], start: () => { P.handsUp = 3.6; } },
    { dur: 2.6, from: () => V3(P.pos.x + 4, P.pos.y + 9, P.pos.z + 5), to: () => V3(P.pos.x + 5, P.pos.y + 13, P.pos.z + 7), look: () => V3(P.pos.x, P.pos.y, P.pos.z), fov: 46, title: 'Busted', sub: S.heat >= 90 ? 'Heat maxed out' : 'Area 7 police' },
  ];
}
function cutDowned() {
  return [
    { dur: 3.4, from: () => V3(P.pos.x + 1.6, P.pos.y + 1.4, P.pos.z + 1.6), to: () => V3(P.pos.x + 2.4, P.pos.y + 7, P.pos.z + 2.4), look: () => V3(P.pos.x, P.pos.y + 0.2, P.pos.z), fov: 44, title: 'Down', sub: 'Calder General', tick: (dt, k) => { GRADE.uniforms.uDesat.value = k * 0.85; } },
  ];
}
function cutSaint(c) {
  const s = c.members.find(e => e.type === 'saint') || c.members[0];
  return [
    { dur: 3.6, from: () => V3(s.pos.x + (P.pos.x - s.pos.x) * 0.35, 1.3, s.pos.z + (P.pos.z - s.pos.z) * 0.35), to: () => V3(s.pos.x + (P.pos.x - s.pos.x) * 0.25, 1.5, s.pos.z + (P.pos.z - s.pos.z) * 0.25), look: () => V3(s.pos.x, 1.6, s.pos.z), fov: 38, say: [CAST.saint.name, 'You keep saying my name. Say it now.', CAST.saint.color] },
    { dur: 2.4, from: besidePlayer(0.7, -1.6, 1.8), to: besidePlayer(0.6, -1.2, 1.7), look: () => V3(s.pos.x, 1.5, s.pos.z), fov: 44 },
  ];
}
function cutEnding(id) {
  if (id === 'wayout') return [
    { dur: 3.5, from: [-2, 1.6, 66], to: [-4, 2.2, 63], look: [-12, 2.4, 63], fov: 40, start: () => { sfx.cheer(); P.pose = 7; } },
    { dur: 3.5, from: besidePlayer(0, 4, 1.8), to: besidePlayer(0, 9, 6), look: headOf, fov: 44 },
  ];
  if (id === 'witness') return [
    { dur: 3.5, from: [60, 1.2, -94], to: [63, 1.6, -99], look: [67.1, 1.1, -104], fov: 38, say: [CAST.reyes.name, 'Start from the beginning.', CAST.reyes.color] },
    { dur: 3, from: [66, 8.4, -86], to: [70, 9.5, -80], look: [67, 1, -104], fov: 46 },
  ];
  if (id === 'crown') return [
    { dur: 6, from: [0, 0, 0], look: headOf, fov: 40, tick: (dt, k) => { const a = k * 1.6; camera.position.set(P.pos.x + Math.cos(a) * 4.2, P.pos.y + 1.4 + k * 1.5, P.pos.z + Math.sin(a) * 4.2); camera.lookAt(P.pos.x, P.pos.y + 1.4, P.pos.z); } },
  ];
  return [
    { dur: 3.2, from: besidePlayer(2.5, 2.5, 0.8), to: besidePlayer(2, 3, 1.2), look: headOf, fov: 42, say: [CAST.reyes.name, 'Hands where I can see them.', CAST.reyes.color], start: () => { P.handsUp = 6; sfx.siren(); } },
    { dur: 3, from: () => V3(P.pos.x + 3, 1.2, P.pos.z + 3), to: () => V3(P.pos.x + 3, 1.0, P.pos.z + 3), look: () => V3(P.pos.x + 3, 16, P.pos.z - 30), fov: 50 },
  ];
}
