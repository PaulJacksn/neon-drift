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
  await page.waitForTimeout(2000);
  await page.screenshot({ path: OUT + 'v3-menu-desktop.png' });

  await page.mouse.click(640, 400);
  st = await waitForState(page, 'playing', 10);
  console.log('DESKTOP after click:', JSON.stringify(st));
  await page.waitForTimeout(1500);
  await page.screenshot({ path: OUT + 'v3-play-early-desktop.png' });

  // steer in a slow circle to stay alive ~10s, screenshot mid-run
  await page.mouse.move(640, 400);
  await page.mouse.down();
  for (let i = 0; i < 40; i++) {
    const a = (i / 40) * Math.PI * 2;
    await page.mouse.move(640 + Math.cos(a) * 120, 400 + Math.sin(a) * 60);
    await page.waitForTimeout(250);
    if (i === 20) await page.screenshot({ path: OUT + 'v3-play-mid-desktop.png' });
  }
  await page.mouse.up();
  st = await ndState(page);
  console.log('DESKTOP after steering:', JSON.stringify(st));

  // stop steering, wait for crash
  let crashed = false;
  for (let i = 0; i < 40; i++) {
    await page.waitForTimeout(1500);
    st = await ndState(page);
    if (st && st.state === 'gameover') { crashed = true; break; }
  }
  console.log('DESKTOP crashed:', crashed, JSON.stringify(st));
  await page.waitForTimeout(1500);
  await page.screenshot({ path: OUT + 'v3-gameover-desktop.png' });
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
  await mpage.waitForTimeout(2000);
  await mpage.screenshot({ path: OUT + 'v3-menu-mobile.png' });

  await mpage.touchscreen.tap(195, 500);
  st = await waitForState(mpage, 'playing', 10);
  console.log('MOBILE after tap:', JSON.stringify(st));
  await mpage.waitForTimeout(1500);
  await mpage.screenshot({ path: OUT + 'v3-play-early-mobile.png' });

  const cdp = await mctx.newCDPSession(mpage);
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: 195, y: 600, id: 1 }] });
  for (let i = 1; i <= 30; i++) {
    const a = (i / 30) * Math.PI * 2;
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: 195 + Math.cos(a) * 50, y: 600 + Math.sin(a) * 40, id: 1 }] });
    await mpage.waitForTimeout(250);
    if (i === 15) await mpage.screenshot({ path: OUT + 'v3-play-mid-mobile.png' });
  }
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  st = await ndState(mpage);
  console.log('MOBILE after steering:', JSON.stringify(st));
  await mctx.close();
  console.log('MOBILE errors:', JSON.stringify(merrors));

  await browser.close();
  console.log('PROBE DONE');
})().catch((e) => { console.error('FAIL', e.message); process.exit(1); });
