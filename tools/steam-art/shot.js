// renders an HTML page (or one element of it) to PNG with Chromium; transparent where the page is
const { chromium } = require('playwright');
(async () => {
  const [, , page_path, out, w, h, sel, query] = process.argv;
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: +w, height: +h }, deviceScaleFactor: 1 });
  await p.goto('file://' + page_path + (query ? '?' + query : ''));
  await p.waitForFunction(() => document.title === 'ready', null, { timeout: 30000 });
  await p.waitForTimeout(300);
  const target = sel ? await p.$(sel) : p;
  await target.screenshot({ path: out, omitBackground: true });
  await b.close();
})();
