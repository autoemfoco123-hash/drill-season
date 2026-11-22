// Records the four radio stations from the web build's music engine into godot/assets/music/*.ogg.
// Usage: node tools/record-radio.js [seconds]   (needs Playwright with Chromium, ffmpeg, npm install)
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const ROOT = path.resolve(__dirname, '..'), OUT = path.join(ROOT, 'godot', 'assets', 'music');
const SECS = +process.argv[2] || 150;
(async () => {
  const s = fs.readFileSync(path.join(ROOT, 'dist', 'artifact.html'), 'utf8'), i = s.lastIndexOf('</script>');
  const f = path.join(ROOT, 'build', 'radio-page.html'); fs.mkdirSync(path.dirname(f), { recursive: true });
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
  const n = await ev('STATIONS.length');
  const stations = []; for (let st = 1; st < n; st++) if (await ev(`!!STATIONS[${st}].style`)) stations.push(st);
  const res = await ev(`Promise.all(${JSON.stringify(stations)}.map(st => new Promise(res => {
    const md = AU.ctx.createMediaStreamDestination(), g = AU.ctx.createGain(); g.connect(md);
    const sp = new StationPlayer(st, g, 0.3, () => { });
    const r = new MediaRecorder(md.stream, { mimeType: 'audio/webm;codecs=opus', audioBitsPerSecond: 160000 }), chunks = [];
    r.ondataavailable = e => chunks.push(e.data);
    r.onstop = async () => { sp.stop(); const b = new Uint8Array(await new Blob(chunks).arrayBuffer()); let s = ''; for (let i = 0; i < b.length; i += 0x8000) s += String.fromCharCode.apply(null, b.subarray(i, i + 0x8000)); res([st, btoa(s)]); };
    r.start(1000); setTimeout(() => r.stop(), ${SECS} * 1000);
  })))`);
  fs.mkdirSync(OUT, { recursive: true });
  const names = ['', 'wcld', 'hawk', 'northline', 'lowend'];
  for (const [st, b64] of res) {
    const webm = path.join(ROOT, 'build', 'radio_' + st + '.webm'); fs.writeFileSync(webm, Buffer.from(b64, 'base64'));
    const ogg = path.join(OUT, (names[st] || 'station' + st) + '.ogg');
    execFileSync('ffmpeg', ['-y', '-loglevel', 'error', '-i', webm, '-af', 'afade=t=in:d=0.6,areverse,afade=t=in:d=1.5,areverse,loudnorm=I=-16:TP=-1.5:LRA=11', '-c:a', 'libvorbis', '-q:a', '4', ogg]);
    console.log(path.basename(ogg), (fs.statSync(ogg).size / 1024).toFixed(0) + ' KB');
  }
  await browser.close();
})();
