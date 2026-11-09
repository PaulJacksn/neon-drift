const { chromium } = require('/home/hatch/workspace/goals/showcasemy-resume-to-portfolio-product/files/launch-post/node_modules/playwright-core');

const URL = 'http://127.0.0.1:8931/index.html';
const EXE = '/home/hatch/.cache/ms-playwright/chromium-1181/chrome-linux/chrome';
const PROXY = { server: 'http://127.0.0.1:8888', bypass: '127.0.0.1,localhost' };

(async () => {
  const browser = await chromium.launch({ executablePath: EXE, args: ['--no-sandbox', '--disable-gpu'] });
  const ctx = await browser.newContext({ viewport: { width: 480, height: 320 }, proxy: PROXY });
  const page = await ctx.newPage();
  page.on('pageerror', (e) => console.log('pageerror:', e.message));
  await page.goto(URL, { waitUntil: 'domcontentloaded', timeout: 60000 });
  // wait for menu, then let the music-gen thread settle
  for (let i = 0; i < 90; i++) {
    await page.waitForTimeout(1000);
    const s = await page.evaluate(() => window.__ND || null);
    if (s && s.state === 'menu') break;
  }
  console.log('menu reached, settling 20s for music thread...');
  await page.waitForTimeout(20000);
  await page.mouse.click(240, 160);
  await page.waitForTimeout(2000);
  const fps = [];
  for (let i = 0; i < 8; i++) {
    await page.waitForTimeout(1000);
    const s = await page.evaluate(() => window.__ND || null);
    if (s) fps.push(s.fps);
  }
  console.log('SMALL VIEWPORT 480x320 fps samples:', JSON.stringify(fps));
  console.log('state:', JSON.stringify(await page.evaluate(() => window.__ND || null)));
  await browser.close();
  console.log('FPS PROBE DONE');
})().catch((e) => { console.error('FAIL', e.message); process.exit(1); });
