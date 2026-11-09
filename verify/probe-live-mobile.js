const { chromium } = require('/home/hatch/workspace/goals/showcasemy-resume-to-portfolio-product/files/launch-post/node_modules/playwright-core');

const URL = 'https://pauljacksn.github.io/neon-drift/';
const OUT = '/home/hatch/workspace/neon-drift/verify/';
const EXE = '/home/hatch/.cache/ms-playwright/chromium-1181/chrome-linux/chrome';
const PROXY = { server: 'http://127.0.0.1:8888', bypass: '127.0.0.1,localhost' };

async function ndState(page) {
  return await page.evaluate(() => window.__ND || null);
}

(async () => {
  const browser = await chromium.launch({ executablePath: EXE, args: ['--no-sandbox', '--disable-gpu'] });
  const errors = [];
  const mctx = await browser.newContext({ viewport: { width: 390, height: 844 }, hasTouch: true, isMobile: true, proxy: PROXY, ignoreHTTPSErrors: true });
  const mpage = await mctx.newPage();
  mpage.on('console', (m) => { if (m.type() === 'error') errors.push('console: ' + m.text()); });
  mpage.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
  await mpage.goto(URL, { waitUntil: 'commit', timeout: 120000 });
  let st = null;
  for (let i = 0; i < 120; i++) {
    await mpage.waitForTimeout(1000);
    st = await ndState(mpage);
    if (st && st.state === 'menu') break;
  }
  console.log('MOBILE LIVE menu:', JSON.stringify(st));
  await mpage.waitForTimeout(2000);
  await mpage.screenshot({ path: OUT + 'live-menu-mobile.png' });
  await mpage.touchscreen.tap(195, 500);
  for (let i = 0; i < 10; i++) {
    await mpage.waitForTimeout(1000);
    st = await ndState(mpage);
    if (st && st.state === 'playing') break;
  }
  console.log('MOBILE LIVE after tap:', JSON.stringify(st));
  await mpage.waitForTimeout(1500);
  await mpage.screenshot({ path: OUT + 'live-play-early-mobile.png' });
  const cdp = await mctx.newCDPSession(mpage);
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: 195, y: 600, id: 1 }] });
  for (let i = 1; i <= 30; i++) {
    const a = (i / 30) * Math.PI * 2;
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: 195 + Math.cos(a) * 50, y: 600 + Math.sin(a) * 40, id: 1 }] });
    await mpage.waitForTimeout(250);
    if (i === 15) await mpage.screenshot({ path: OUT + 'live-play-mid-mobile.png' });
  }
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  st = await ndState(mpage);
  console.log('MOBILE LIVE after steering:', JSON.stringify(st));
  await mctx.close();
  console.log('MOBILE LIVE errors:', JSON.stringify(errors));
  await browser.close();
  console.log('MOBILE LIVE PROBE DONE');
})().catch((e) => { console.error('FAIL', e.message); process.exit(1); });
