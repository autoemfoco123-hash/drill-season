import * as THREE from 'three';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { ShaderPass } from 'three/addons/postprocessing/ShaderPass.js';
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';
import { Sky } from 'three/addons/objects/Sky.js';

/* =========================================================
   DRILL SEASON - core utilities, state, save
   ========================================================= */
const $ = id => document.getElementById(id);
const clamp = (v, a, b) => v < a ? a : v > b ? b : v;
const lerp = (a, b, t) => a + (b - a) * t;
const rand = (a, b) => a + Math.random() * (b - a);
const randi = (a, b) => Math.floor(a + Math.random() * (b - a + 1));
const pick = a => a[Math.floor(Math.random() * a.length)];
const TAU = Math.PI * 2;
const angDiff = (a, b) => { let d = (b - a) % TAU; if (d > Math.PI) d -= TAU; if (d < -Math.PI) d += TAU; return d; };
function rng(seed) { let a = seed >>> 0; return () => { a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }
const fmtMoney = n => (n < 0 ? '-$' : '$') + Math.abs(Math.round(n)).toLocaleString('en-US');
const esc = s => String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const IS_TOUCH = (window.matchMedia && matchMedia('(pointer: coarse)').matches) || (('ontouchstart' in window) && navigator.maxTouchPoints > 0);
const SAVE_KEY = 'drillseason.save.v1';
// one shared clock for every player: 1 real second = 1 game minute, a full day every 24 minutes
let TIME_OFFSET = 0;
const worldSeconds = () => Date.now() / 1000 + TIME_OFFSET;
const worldMinutes = () => ((worldSeconds() % 1440) + 1440) % 1440;

const CAST = {
  benny: { name: '@basement808', role: 'Producer · runs the basement studio', color: '#ff9a3c', init: '8' },
  kiara: { name: '@lilsis.calder', role: 'Your little sister', color: '#c79bff', init: 'LS' },
  coach: { name: '@calderrec', role: 'Runs the Calder Park rec center', color: '#86e3b0', init: 'CR' },
  vance: { name: '@northline.exec', role: 'Label exec · Northline Records', color: '#f4c64e', init: 'NL' },
  saint: { name: '@saint.halo', role: 'Runs the Halo crew', color: '#ff4b3a', init: 'SH' },
  reyes: { name: '@unit7.det', role: 'Area detective', color: '#71c6ff', init: 'U7' },
};

const DEF_CFG = () => ({ optic: 'iron', barrel: 'standard', mag: 'std', muzzle: 'none', finish: 'gunmetal', charm: 'none' });
const DEF_PARTS = () => ['optic:iron', 'barrel:standard', 'mag:std', 'muzzle:none'];

function newState(name) {
  return {
    v: 1, name: name || 'Unknown', cash: 150, buzz: 4, heat: 0, health: 100, warmth: 100, bandages: 1,
    night: 1, clock: 21 * 60 + 30, playTime: 0, pos: null,
    cur: 'k9',
    guns: {
      k9: { owned: true, mag: 12, res: 36, cfg: DEF_CFG() },
      draft: { owned: false, mag: 30, res: 60, cfg: DEF_CFG() },
      plow: { owned: false, mag: 6, res: 12, cfg: DEF_CFG() },
    },
    parts: { k9: DEF_PARTS(), draft: DEF_PARTS(), plow: DEF_PARTS() },
    cos: ['finish:gunmetal', 'charm:none'],
    threads: { benny: [], kiara: [], coach: [], vance: [], saint: [], reyes: [] },
    unread: { benny: 0, kiara: 0, coach: 0, vance: 0, saint: 0, reyes: 0 },
    feed: [], tracks: [], flags: {}, cd: {}, endings: {}, tracked: null, buffs: { coffee: 0, warmers: 0 }, job: null,
    stats: { tracks: 0, best: null, buzzPeak: 4, heatPeak: 0, walkAways: 0, fights: 0, downs: 0, cashEarned: 0, rides: 0, shots: 0, coldTime: 0, dist: 0, disses: 0, timesDowned: 0, merch: 0, videos: 0, layLows: 0, pvpDowns: 0, busted: 0, carsTaken: 0, drive: 0, photos: 0 },
    skin: defaultSkin(),
    settings: { sens: 1, vol: 0.8, music: 0.85, invertY: false, quality: IS_TOUCH ? 'low' : 'high', radio: 1, score: true, voices: true, fp: false, fov: 70 },
    garage: [{ model: 'hatch', color: 0x2a6a8a }],
    social: { followers: 214, following: 96, bio: 'drill · Calder Park · Chicago', posts: [] },
    day: 1,
  };
}
function deepMerge(base, o) {
  for (const k in o) {
    const v = o[k];
    if (v && typeof v === 'object' && !Array.isArray(v) && base[k] && typeof base[k] === 'object' && !Array.isArray(base[k])) deepMerge(base[k], v);
    else base[k] = v;
  }
  return base;
}
let S = newState('');
let MODE = 'title';
let GAME_T = 0;          // world sim time (s)
let REAL_T = 0;          // always ticking

function loadSave() {
  try {
    const t = localStorage.getItem(SAVE_KEY);
    if (!t) return null;
    const o = JSON.parse(t);
    if (!o || o.v !== 1 || !o.name) return null;
    return deepMerge(newState(o.name), o);
  } catch (e) { return null; }
}
function saveGame() {
  if (!S || !S.name || MODE === 'title') return;
  try {
    if (typeof P !== 'undefined' && P.pos) S.pos = { x: P.pos.x, y: P.pos.y, z: P.pos.z, yaw: camYaw };
    localStorage.setItem(SAVE_KEY, JSON.stringify(S));
  } catch (e) { /* storage unavailable */ }
}
function wipeSave() { try { localStorage.removeItem(SAVE_KEY); } catch (e) { } }

/* ---------- map constants ---------- */
const MAP_HALF = 250;                // the district is 500 m across
const XL = [-190, -95, 0, 70, 160], ZL = [-180, -90, 0, 90, 180];
const XN = ['Kessler Ave', 'Harlan Ave', 'Bishop St', 'Marrow St', 'Shore Dr'], ZN = ['Ironside Rd', 'Low End Rd', 'Calder Ave', 'Garnet St', 'Sable St'];
const XB = [-MAP_HALF, ...XL, MAP_HALF], ZB = [-MAP_HALF, ...ZL, MAP_HALF];
const BOUND = MAP_HALF - 3;
const SHORE_X = XL[XL.length - 1];    // Shore Dr runs along the lake
const ROAD_X_END = SHORE_X + 10;      // east-west streets end at Shore Dr
const LAKE_X = SHORE_X + 46;          // frozen lake from here east
const ROAD_HW = 6, WALK_EDGE = 10;
const LX = 70;                      // L line runs above Marrow St
const DECK_Y0 = 6.8, DECK_Y = 7.2, PLAT_Y = 7.6;
const DECK_X0 = 60.5, DECK_X1 = 79.5;
const TRACKS = [67, 73];
const STEP_UP = 0.7;
const GRAV = 22;

const LOC = {
  home: { x: -8.4, z: -42, name: 'Home', addr: '6127 S Bishop St' },
  store: { x: 16, z: -8.4, name: 'Calder Mini Mart', addr: 'Calder Ave & Bishop St' },
  studio: { x: 41, z: -8.4, name: 'Basement 808', addr: '2242 W Calder Ave · downstairs' },
  rec: { x: -10.2, z: 63, name: 'Calder Park Rec Center', addr: '6400 S Bishop St' },
  platform: { x: 63, z: -6, y: PLAT_Y, name: 'Calder L platform' },
  reyes: { x: 66.5, z: -98, name: 'Under the L, Low End Rd' },
  station: { x: 110, z: 82, name: 'Area 7 police station' },
  hospital: { x: -103.5, z: -45, name: 'Calder General' },
  dealer: { x: 104, z: 9, name: 'Marrow Motors' },
  park: { x: -48, z: 18, name: 'Calder Park pond' },
  pavilion: { x: -66, z: 56, name: 'Park pavilion' },
  stairs: { x: 62, z: 45, name: 'L stairs, Marrow St' },
  storeFront: { x: 20, z: -7.5, name: 'Mini Mart window' },
  court: { x: -47.5, z: 121, name: 'Garnet Courts hoops' },
  gas: { x: -40, z: -197, name: 'Ironside Fuel' },
  lakefront: { x: 190, z: 0, name: 'Shore Dr lakefront' },
  yard: { x: -224, z: -40, name: 'Kessler rail yard' },
};
const COACH_POS = { x: -7.6, z: 69 };
const BENNY_POS = { x: 37.6, z: -7.6 };
