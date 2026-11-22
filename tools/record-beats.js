// Records the studio beats (the rhythm game's music) from the web build's music engine into
// godot/assets/studio/<style>_<n>.ogg, plus beats.json with the note charts for each verse type.
// Usage: node tools/record-beats.js   (needs Playwright with Chromium, ffmpeg, npm install)
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const ROOT = path.resolve(__dirname, '..'), OUT = path.join(ROOT, 'godot', 'assets', 'studio');
const STYLES = ['chi', 'uk', 'ny'], PER_STYLE = 3, MARK = 0.5;
(async () => {
  const s = fs.readFileSync(path.join(ROOT, 'dist', 'artifact.html'), 'utf8'), i = s.lastIndexOf('</script>');
  const f = path.join(ROOT, 'build', 'beats-page.html'); fs.mkdirSync(path.dirname(f), { recursive: true });
  fs.writeFileSync(f, '<meta charset="utf-8">\n' + s.slice(0, i) + '\nwindow.__DS = { ev: src => eval(src) };\n' + s.slice(i));
  const browser = await chromium.launch({ args: ['--autoplay-policy=no-user-gesture-required', '--disable-webgl'] });
  const page = await browser.newPage();
  await page.route(/https:\/\/cdn\.jsdelivr\.net\/npm\/three@0\.160\.0\/(.*)/, r => r.fulfill({ path: path.join(ROOT, 'node_modules', 'three', r.request().url().split('three@0.160.0/')[1]), contentType: 'text/javascript' }));
  await page.route(/fonts\.(googleapis|gstatic)\.com/, r => r.abort());
  await page.goto('file://' + f);
  await page.waitForFunction(() => window.__DS && window.__DS.ev, null, { timeout: 120000 });
  const ev = src => page.evaluate(x => window.__DS.ev(x), src);
  await ev('initAudio(); 0');
  await page.waitForFunction(() => window.__DS.ev('AU.bankReady === true'), null, { timeout: 180000 });
  const list = [];
  STYLES.forEach((st, si) => { for (let k = 0; k < PER_STYLE; k++) list.push({ style: st, seed: 1000 + si * 97 + k * 7919, file: `${st}_${k}` }); });
  // three at a time: more than that and the audio engine falls behind real time
  const res = [];
  for (let k = 0; k < list.length; k += 3) res.push(...await ev(`Promise.all(${JSON.stringify(list.slice(k, k + 3))}.map(L => new Promise(res => {
    const md = AU.ctx.createMediaStreamDestination(), g = AU.ctx.createGain(); g.connect(md);
    const beat = buildBeat(L.seed, 'tribute', L.style);
    const charts = {}; for (const ty of ['tribute', 'wayout', 'diss']) charts[ty] = buildBeat(L.seed, ty, L.style).notes.map(n => [+n.t.toFixed(4), n.lane]);
    const r = new MediaRecorder(md.stream, { mimeType: 'audio/webm;codecs=opus', audioBitsPerSecond: 160000 }), chunks = [];
    r.ondataavailable = e => chunks.push(e.data);
    r.start(500);
    setTimeout(() => {
      const t0 = AU.ctx.currentTime + 0.8;
      // a short click ${MARK}s before the beat marks where the beat starts in the recording
      const o = AU.ctx.createOscillator(), og = AU.ctx.createGain(); o.frequency.value = 1000; og.gain.value = 0.9; o.connect(og).connect(g); o.start(t0 - ${MARK}); o.stop(t0 - ${MARK} + 0.012);
      const B = makeBus(g, { gain: 0.2 }); scheduleBeat(B, beat, t0);
      // stop on the audio clock, not the wall clock: under load the engine renders slower than real time
      const iv = setInterval(() => { if (AU.ctx.currentTime > t0 + beat.dur + 2) { clearInterval(iv); r.stop(); } }, 100);
    }, 400);
    r.onstop = async () => { const b = new Uint8Array(await new Blob(chunks).arrayBuffer()); let s = ''; for (let i = 0; i < b.length; i += 0x8000) s += String.fromCharCode.apply(null, b.subarray(i, i + 0x8000)); res({ L, b64: btoa(s), dur: beat.dur, bpm: beat.bpm, step: beat.step, bar: beat.bar, charts }); };
  })))`));
  fs.mkdirSync(OUT, { recursive: true });
  const meta = [];
  for (const it of res) {
    const webm = path.join(ROOT, 'build', 'beat_' + it.L.file + '.webm'); fs.writeFileSync(webm, Buffer.from(it.b64, 'base64'));
    // find the marker click, then cut the recording so it starts exactly at the first beat
    const raw = execFileSync('ffmpeg', ['-loglevel', 'error', '-i', webm, '-ac', '1', '-ar', '48000', '-f', 'f32le', '-'], { maxBuffer: 1 << 30 });
    const pcm = new Float32Array(raw.buffer, raw.byteOffset, raw.length / 4);
    let at = -1; for (let k = 0; k < pcm.length; k++) if (Math.abs(pcm[k]) > 0.25) { at = k; break; }
    if (at < 0) throw new Error('no marker in ' + it.L.file);
    const start = at / 48000 + MARK;
    const ogg = path.join(OUT, it.L.file + '.ogg');
    execFileSync('ffmpeg', ['-y', '-loglevel', 'error', '-ss', start.toFixed(4), '-i', webm, '-t', (it.dur + 1.5).toFixed(2), '-af', 'afade=t=out:st=' + (it.dur + 0.5).toFixed(2) + ':d=1,loudnorm=I=-16:TP=-1.5:LRA=11', '-ar', '44100', '-c:a', 'libvorbis', '-q:a', '4', ogg]);
    meta.push({ file: it.L.file, style: it.L.style, seed: it.L.seed, dur: it.dur, bpm: it.bpm, step: it.step, bar: it.bar, charts: it.charts });
    console.log(path.basename(ogg), (fs.statSync(ogg).size / 1024).toFixed(0) + ' KB', 'notes', Object.values(it.charts).map(c => c.length).join('/'));
  }
  fs.writeFileSync(path.join(OUT, 'beats.json'), JSON.stringify(meta));
  await browser.close();
})();
