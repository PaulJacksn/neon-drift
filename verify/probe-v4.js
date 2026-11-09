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
  const errors = [];
  const ctx = await browser.newContext({ viewport: { width: 1280, height: 800 }, proxy: PROXY });
  const page = await ctx.newPage();
  page.on('console', (m) => { if (m.type() === 'error') errors.push('console: ' + m.text()); });
  page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
  await page.goto(URL, { waitUntil: 'domcontentloaded', timeout: 60000 });
  let st = await waitForState(page, 'menu', 90);
  console.log('V4 menu:', JSON.stringify(st));
  await page.waitForTimeout(2000);
  await page.screenshot({ path: OUT + 'v4-menu-desktop.png' });

  await page.mouse.click(640, 400);
  st = await waitForState(page, 'playing', 10);
  console.log('V4 after click:', JSON.stringify(st));
  await page.waitForTimeout(1500);
  await page.screenshot({ path: OUT + 'v4-play-early-desktop.png' });

  // SOAK: steer gently for 45s, sample state every 5s
  await page.mouse.move(640, 400);
  await page.mouse.down();
  const samples = [];
  for (let i = 0; i < 45; i++) {
    const a = (i / 45) * Math.PI * 4;
    await page.mouse.move(640 + Math.cos(a) * 90, 400 + Math.sin(a) * 45);
    await page.waitForTimeout(1000);
    if (i % 5 === 0) {
      const s = await ndState(page);
      samples.push(s ? { t: i, score: s.score, speed: s.speed, fps: s.fps, state: s.state, combo: s.combo } : null);
    }
    if (i === 22) await page.screenshot({ path: OUT + 'v4-play-mid-desktop.png' });
  }
  await page.mouse.up();
  console.log('V4 soak samples:', JSON.stringify(samples));
  st = await ndState(page);
  console.log('V4 after soak:', JSON.stringify(st));
  await page.screenshot({ path: OUT + 'v4-play-late-desktop.png' });

  // stop steering, wait for crash
  let crashed = false;
  for (let i = 0; i < 40; i++) {
    await page.waitForTimeout(1500);
    st = await ndState(page);
    if (st && st.state === 'gameover') { crashed = true; break; }
  }
  console.log('V4 crashed:', crashed, JSON.stringify(st));
  await page.waitForTimeout(1500);
  await page.screenshot({ path: OUT + 'v4-gameover-desktop.png' });
  await ctx.close();
  console.log('V4 errors:', JSON.stringify(errors));

  // mobile quick pass
  const merrors = [];
  const mctx = await browser.newContext({ viewport: { width: 390, height: 844 }, hasTouch: true, isMobile: true, proxy: PROXY });
  const mpage = await mctx.newPage();
  mpage.on('console', (m) => { if (m.type() === 'error') merrors.push('console: ' + m.text()); });
  mpage.on('pageerror', (e) => merrors.push('pageerror: ' + e.message));
  await mpage.goto(URL, { waitUntil: 'commit', timeout: 120000 });
  st = await waitForState(mpage, 'menu', 120);
  console.log('V4 MOBILE menu:', JSON.stringify(st));
  await mpage.waitForTimeout(2000);
  await mpage.screenshot({ path: OUT + 'v4-menu-mobile.png' });
  await mpage.touchscreen.tap(195, 500);
  st = await waitForState(mpage, 'playing', 10);
  console.log('V4 MOBILE after tap:', JSON.stringify(st));
  await mpage.waitForTimeout(1500);
  await mpage.screenshot({ path: OUT + 'v4-play-early-mobile.png' });
  const cdp = await mctx.newCDPSession(mpage);
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: 195, y: 600, id: 1 }] });
  for (let i = 1; i <= 20; i++) {
    const a = (i / 20) * Math.PI * 2;
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: 195 + Math.cos(a) * 50, y: 600 + Math.sin(a) * 40, id: 1 }] });
    await mpage.waitForTimeout(250);
  }
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  st = await ndState(mpage);
  console.log('V4 MOBILE after steering:', JSON.stringify(st));
  await mpage.screenshot({ path: OUT + 'v4-play-mid-mobile.png' });
  await mctx.close();
  console.log('V4 MOBILE errors:', JSON.stringify(merrors));
  await browser.close();
  console.log('V4 PROBE DONE');
})().catch((e) => { console.error('FAIL', e.message); process.exit(1); });
