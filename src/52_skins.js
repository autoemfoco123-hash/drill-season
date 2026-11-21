
/* =========================================================
   SKINS - every player builds a look; it is saved with the
   profile and streamed to other players with their presence.
   ========================================================= */
const SKIN_TONES = [0xf3cfae, 0xdcae88, 0xb98458, 0x8f5d3b, 0x6b4630, 0x4a2e1e];
const SWATCHES = [0x15171a, 0x262b33, 0x3a3f46, 0x8a9098, 0xe8e8ea, 0x7a1418, 0xc8202a, 0xff8a2a, 0xffc832, 0x2a5a2a, 0x4f8a3a, 0x1e2f4a, 0x2a5aa8, 0x6ab0ff, 0x5a2a6a, 0xff6ab0, 0x6b4a30, 0xc8a878];
const HAIR_COLS = [0x0f0d0c, 0x2a1a10, 0x4a2e1a, 0x8a6a3a, 0xc8a060, 0xb8b8b8, 0xb03020, 0x3a6aff];
const SKIN_OPTS = {
  hair: ['none', 'buzz', 'short', 'afro', 'locs', 'braids', 'twists'],
  head: ['none', 'beanie', 'cap', 'capback', 'durag', 'bucket', 'hood', 'skimask', 'headphones'],
  top: ['puffer', 'hoodie', 'parka', 'track', 'varsity', 'leather'],
  pants: ['jeans', 'cargo', 'joggers', 'ski'],
  shoes: ['sneaker', 'high', 'boot'],
  bag: ['none', 'back', 'cross'],
};
const SKIN_LABELS = {
  none: 'None', buzz: 'Buzz cut', short: 'Short', afro: 'Afro', locs: 'Locs', braids: 'Braids', twists: 'Twists',
  beanie: 'Beanie', cap: 'Cap', capback: 'Cap back', durag: 'Durag', bucket: 'Bucket hat', hood: 'Hood up', skimask: 'Ski mask', headphones: 'Headphones',
  puffer: 'Puffer', hoodie: 'Hoodie', parka: 'Parka', track: 'Tracksuit', varsity: 'Varsity', leather: 'Leather',
  jeans: 'Jeans', cargo: 'Cargos', joggers: 'Joggers', ski: 'Ski pants', sneaker: 'Sneakers', high: 'High-tops', boot: 'Boots', back: 'Backpack', cross: 'Crossbody',
};
const SKIN_FIELDS = [
  ['tone', 'n', 0, 5], ['hair', 'e', 'hair'], ['hairCol', 'c'], ['beard', 'b'], ['head', 'e', 'head'], ['headCol', 'c'], ['pom', 'b'],
  ['top', 'e', 'top'], ['topCol', 'c'], ['top2', 'c'], ['pants', 'e', 'pants'], ['pantsCol', 'c'], ['pants2', 'c'], ['shoes', 'e', 'shoes'], ['shoesCol', 'c'],
  ['chain', 'b'], ['watch', 'b'], ['glasses', 'b'], ['bag', 'e', 'bag'], ['bagCol', 'c'], ['build', 'n', 0, 2],
];
function defaultSkin() {
  return { tone: 4, hair: 'short', hairCol: 0x0f0d0c, beard: 0, head: 'beanie', headCol: 0xff8a2a, pom: 1, top: 'puffer', topCol: 0x262b33, top2: 0x343a44, pants: 'jeans', pantsCol: 0x1b2533, pants2: 0xe8e8ea, shoes: 'sneaker', shoesCol: 0xdedede, chain: 0, watch: 0, glasses: 0, bag: 'none', bagCol: 0x15171a, build: 1 };
}
const PRESETS = [
  ['Calder Classic', {}],
  ['Blackout', { head: 'skimask', headCol: 0x15171a, top: 'puffer', topCol: 0x15171a, top2: 0x262b33, pants: 'cargo', pantsCol: 0x15171a, shoes: 'boot', shoesCol: 0x15171a, glasses: 0 }],
  ['Studio Rat', { hair: 'twists', head: 'headphones', headCol: 0xe8e8ea, top: 'hoodie', topCol: 0x3a3f46, top2: 0x262b33, pants: 'joggers', pantsCol: 0x262b33, pants2: 0xe8e8ea, shoes: 'sneaker', shoesCol: 0xe8e8ea, bag: 'cross', bagCol: 0x15171a }],
  ['Varsity Drip', { hair: 'buzz', head: 'capback', headCol: 0x7a1418, top: 'varsity', topCol: 0x7a1418, top2: 0xe8e8ea, pants: 'jeans', pantsCol: 0x1e2f4a, shoes: 'high', shoesCol: 0xe8e8ea, chain: 1, watch: 1, glasses: 1 }],
  ['Track Star', { hair: 'braids', head: 'durag', headCol: 0xc8202a, top: 'track', topCol: 0xc8202a, top2: 0xe8e8ea, pants: 'joggers', pantsCol: 0xc8202a, pants2: 0xe8e8ea, shoes: 'sneaker', shoesCol: 0xe8e8ea, chain: 1 }],
  ['Snow Day', { hair: 'afro', head: 'bucket', headCol: 0xe8e8ea, top: 'puffer', topCol: 0xe8e8ea, top2: 0xc8a878, pants: 'ski', pantsCol: 0x8a9098, shoes: 'boot', shoesCol: 0x6b4a30 }],
  ['Bishop St', { hair: 'locs', head: 'none', top: 'leather', topCol: 0x15171a, top2: 0x3a3f46, pants: 'jeans', pantsCol: 0x262b33, shoes: 'boot', shoesCol: 0x15171a, chain: 1, glasses: 1, beard: 1 }],
  ['Garnet Courts', { hair: 'short', head: 'hood', top: 'hoodie', topCol: 0x7a1418, top2: 0x5a1010, pants: 'joggers', pantsCol: 0x15171a, pants2: 0x7a1418, shoes: 'high', shoesCol: 0x7a1418, bag: 'back', bagCol: 0x15171a }],
  ['Lakefront', { hair: 'short', head: 'beanie', headCol: 0x1e2f4a, pom: 0, top: 'parka', topCol: 0x4f8a3a, top2: 0xc8a878, pants: 'cargo', pantsCol: 0x6b4a30, shoes: 'boot', shoesCol: 0x6b4a30, beard: 1 }],
  ['Ironside', { hair: 'buzz', head: 'cap', headCol: 0xffc832, top: 'parka', topCol: 0xffc832, top2: 0x3a3f46, pants: 'cargo', pantsCol: 0x3a3f46, shoes: 'boot', shoesCol: 0x6b4a30, glasses: 1 }],
];
const presetSkin = i => Object.assign(defaultSkin(), PRESETS[i][1]);
function cleanSkin(s) {
  const d = defaultSkin(), o = {};
  s = s && typeof s === 'object' ? s : {};
  for (const [k, t, a, b] of SKIN_FIELDS) {
    const v = s[k];
    if (t === 'e') o[k] = SKIN_OPTS[a].includes(v) ? v : d[k];
    else if (t === 'c') o[k] = Number.isInteger(v) && v >= 0 && v <= 0xffffff ? v : d[k];
    else if (t === 'b') o[k] = v ? 1 : 0;
    else o[k] = Number.isInteger(v) && v >= a && v <= b ? v : d[k];
  }
  return o;
}
// compact form for the 12 Hz presence stream
function encodeSkin(s) { return SKIN_FIELDS.map(([k, t, a]) => t === 'e' ? SKIN_OPTS[a].indexOf(s[k]) : s[k] | 0); }
function decodeSkin(arr) {
  if (!Array.isArray(arr) || arr.length !== SKIN_FIELDS.length) return null;
  const o = {};
  SKIN_FIELDS.forEach(([k, t, a], i) => { const v = arr[i]; o[k] = t === 'e' ? SKIN_OPTS[a][v | 0] : v; });
  return cleanSkin(o);
}
function skinHumanOpts(s) {
  s = cleanSkin(s);
  return {
    skin: SKIN_TONES[s.tone], hair: s.hair, hairCol: s.hairCol, beard: s.beard, head: s.head, hat: s.headCol, pom: s.pom,
    top: s.top, jacket: s.topCol, jacket2: s.top2, pantsStyle: s.pants, pants: s.pantsCol, pants2: s.pants2, shoe: s.shoes, shoes: s.shoesCol,
    chain: !!s.chain, watch: !!s.watch, glasses: !!s.glasses, bag: s.bag === 'none' ? null : s.bag, bagCol: s.bagCol, build: s.build,
  };
}
// believable everyday outfits for pedestrians
function randomSkin(R) {
  R = R || Math.random;
  const p = a => a[Math.floor(R() * a.length)];
  const muted = [0x15171a, 0x262b33, 0x3a3f46, 0x8a9098, 0x1e2f4a, 0x2a3a2a, 0x4a3a2a, 0x5a1a1a, 0x6b4a30, 0xc8a878, 0xe8e8ea];
  const pop = [0xc8202a, 0xff8a2a, 0xffc832, 0x2a5aa8, 0x6ab0ff, 0x4f8a3a, 0xff6ab0, 0x5a2a6a];
  const col = () => R() < 0.75 ? p(muted) : p(pop);
  return cleanSkin({
    tone: Math.floor(R() * 6), hair: p(SKIN_OPTS.hair), hairCol: R() < 0.8 ? p(HAIR_COLS.slice(0, 4)) : p(HAIR_COLS), beard: R() < 0.25 ? 1 : 0,
    head: p(['none', 'beanie', 'beanie', 'cap', 'hood', 'bucket', 'durag', 'headphones', 'beanie']), headCol: col(), pom: R() < 0.4 ? 1 : 0,
    top: p(['puffer', 'puffer', 'parka', 'parka', 'hoodie', 'track', 'leather', 'varsity']), topCol: col(), top2: col(),
    pants: p(['jeans', 'jeans', 'cargo', 'joggers', 'ski']), pantsCol: p(muted), pants2: 0xe8e8ea,
    shoes: p(SKIN_OPTS.shoes), shoesCol: p([0xe8e8ea, 0x15171a, 0x6b4a30, 0x3a3f46]), chain: R() < 0.1 ? 1 : 0, watch: R() < 0.15 ? 1 : 0,
    glasses: R() < 0.08 ? 1 : 0, bag: p(['none', 'none', 'none', 'back', 'cross']), bagCol: p(muted), build: Math.floor(R() * 3),
  });
}
const skinKey = s => encodeSkin(s).join('.');
