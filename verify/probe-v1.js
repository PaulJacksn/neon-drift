const { chromium } = require('/home/hatch/workspace/goals/showcasemy-resume-to-portfolio-product/files/launch-post/node_modules/playwright-core');

const URL = 'http://127.0.0.1:8931/index.html';
const OUT = '/home/hatch/workspace/neon-drift/verify/';
const EXE = '/home/hatch/.cache/ms-playwright/chromium-1181/chrome-linux/chrome';
const PROXY = { server: 'http://127.0.0.1:8888', bypass: '127.0.0.1,localhost' };

async function ndState(page) {
  return await page.evaluate(() => window.__ND || null);
}

async function waitForState(page, want, secs) {
  let st = null;
  for (let i = 0; i < secs; i++) {
    await page.waitForTimeout(1000);
    st = await ndState(page);
    if (st && st.state === want) return st;
  }
  return st;
}

(async () => {
  const browser = await chromium.launch({ executablePath: EXE, args: ['--no-sandbox', '--disable-gpu'] });

  // ---------------- desktop 1280x800 ----------------
  const errors = [];
  const ctx = await browser.newContext({ viewport: { width: 1280, height: 800 }, proxy: PROXY });
  const page = await ctx.newPage();
  page.on('console', (m) => { if (m.type() === 'error') errors.push('console: ' + m.text()); });
  page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
  await page.goto(URL, { waitUntil: 'domcontentloaded', timeout: 60000 });
  let st = await waitForState(page, 'menu', 90);
  console.log('DESKTOP menu:', JSON.stringify(st));
  await page.waitForTimeout(1500);
  await page.screenshot({ path: OUT + 'v1-menu-desktop.png' });

  await page.mouse.click(640, 400);
  st = await waitForState(page, 'playing', 10);
  console.log('DESKTOP after click:', JSON.stringify(st));

  // drag left then right
  await page.mouse.move(640, 400);
  await page.mouse.down();
  for (let i = 0; i < 20; i++) { await page.mouse.move(640 - i * 8, 400); await page.waitForTimeout(50); }
  for (let i = 0; i < 20; i++) { await page.mouse.move(480 + i * 12, 400); await page.waitForTimeout(50); }
  await page.mouse.up();
  await page.waitForTimeout(3000);
  st = await ndState(page);
  console.log('DESKTOP mid-run:', JSON.stringify(st));
  await page.screenshot({ path: OUT + 'v1-play-desktop.png' });

  // no steering until crash (cap ~60s)
  let crashed = false;
  for (let i = 0; i < 40; i++) {
    await page.waitForTimeout(1500);
    st = await ndState(page);
    if (st && st.state === 'gameover') { crashed = true; break; }
  }
  console.log('DESKTOP crashed:', crashed, JSON.stringify(st));
  await page.waitForTimeout(1500);
  await page.screenshot({ path: OUT + 'v1-gameover-desktop.png' });

  // restart and sample fps (SwiftShader software rendering: indicative only)
  await page.mouse.click(640, 400);
  await page.waitForTimeout(1000);
  const fps = [];
  for (let i = 0; i < 5; i++) { await page.waitForTimeout(1000); const s = await ndState(page); if (s) fps.push(s.fps); }
  console.log('DESKTOP fps samples:', JSON.stringify(fps));
  await page.screenshot({ path: OUT + 'v1-play2-desktop.png' });
  await ctx.close();
  console.log('DESKTOP errors:', JSON.stringify(errors));

  // ---------------- mobile 390x844 touch ----------------
  const merrors = [];
  const mctx = await browser.newContext({ viewport: { width: 390, height: 844 }, hasTouch: true, isMobile: true, proxy: PROXY });
  const mpage = await mctx.newPage();
  mpage.on('console', (m) => { if (m.type() === 'error') merrors.push('console: ' + m.text()); });
  mpage.on('pageerror', (e) => merrors.push('pageerror: ' + e.message));
  await mpage.goto(URL, { waitUntil: 'domcontentloaded', timeout: 60000 });
  st = await waitForState(mpage, 'menu', 90);
  console.log('MOBILE menu:', JSON.stringify(st));
  await mpage.waitForTimeout(1500);
  await mpage.screenshot({ path: OUT + 'v1-menu-mobile.png' });

  await mpage.touchscreen.tap(195, 500);
  st = await waitForState(mpage, 'playing', 10);
  console.log('MOBILE after tap:', JSON.stringify(st));

  const cdp = await mctx.newCDPSession(mpage);
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: 195, y: 600, id: 1 }] });
  for (let i = 1; i <= 15; i++) {
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: 195 - i * 5, y: 600, id: 1 }] });
    await mpage.waitForTimeout(50);
  }
  for (let i = 1; i <= 15; i++) {
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: 120 + i * 7, y: 600, id: 1 }] });
    await mpage.waitForTimeout(50);
  }
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  await mpage.waitForTimeout(3000);
  st = await ndState(mpage);
  console.log('MOBILE mid-run:', JSON.stringify(st));
  await mpage.screenshot({ path: OUT + 'v1-play-mobile.png' });
  const mfps = [];
  for (let i = 0; i < 3; i++) { await mpage.waitForTimeout(1000); const s = await ndState(mpage); if (s) mfps.push(s.fps); }
  console.log('MOBILE fps samples:', JSON.stringify(mfps));
  await mctx.close();
  console.log('MOBILE errors:', JSON.stringify(merrors));

  await browser.close();
  console.log('PROBE DONE');
})().catch((e) => { console.error('FAIL', e.message); process.exit(1); });
