/* APP_URL=http://127.0.0.1:7373 node tools/icon_web_check.cjs */
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || '/tmp/littlewins-browser/node_modules/playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const output = path.resolve(__dirname, '../docs/verification/illustrated-icons', process.env.CAPTURE_PHASE || 'after');
const stateKey = 'littlewins.state.v1';
const today = new Date().toISOString().slice(0, 10);
const state = {
  version: 1, onboarded: true, locale: 'en', age: 7, sound: false,
  reading: { completed: Object.fromEntries(Array.from({ length: 12 }, (_, i) => [`frog:${i}`, today])), positions: { frog: 12 }, spentCoins: 0 },
  wallet: {}, batchProgress: {},
};

(async () => {
  fs.mkdirSync(output, { recursive: true });
  const browser = await chromium.launch({ headless: true, args: ['--no-sandbox'] });
  const errors = [], checks = [], assets = new Set();
  try {
    const context = await browser.newContext({ viewport: { width: 430, height: 932 }, reducedMotion: 'reduce' });
    const page = await context.newPage();
    page.on('pageerror', e => errors.push(e.message));
    page.on('console', message => {
      if (message.type() === 'error' && /Exception|RenderFlex|overflow|Error/.test(message.text())) errors.push(message.text());
    });
    page.on('response', response => {
      if (response.url().includes('/art/icons/')) {
        assets.add(response.url().split('/').pop());
        if (!response.ok()) errors.push(`Missing icon: ${response.url()}`);
      }
    });
    await page.addInitScript(({ stateKey, state }) => {
      if (!localStorage.getItem(stateKey)) localStorage.setItem(stateKey, JSON.stringify(JSON.stringify(state)));
    }, { stateKey, state });
    const open = async () => {
      await page.goto(process.env.APP_URL || 'http://127.0.0.1:7373');
      await page.waitForFunction(() => document.querySelector('flt-semantics-placeholder'));
      await page.evaluate(() => document.querySelector('flt-semantics-placeholder').click());
      await page.getByText('littlewins', { exact: true }).waitFor();
      await page.waitForTimeout(700);
    };
    const shot = async name => {
      await page.mouse.move(1, 1);
      await page.waitForTimeout(350);
      await page.screenshot({ path: path.join(output, `${name}.png`) });
    };
    const tab = async name => {
      await page.getByRole('tab', { name: new RegExp(name) }).click();
      await page.waitForTimeout(350);
    };
    await open();
    await shot('home-430');
    for (const size of [{ width: 320, height: 640 }, { width: 1365, height: 900 }]) {
      await page.setViewportSize(size);
      await shot(`home-${size.width}`);
    }
    await page.setViewportSize({ width: 430, height: 932 });
    await tab('Books');
    await shot('books-430');
    await tab('My wins');
    await shot('wins-430');
    const still = await page.screenshot();
    await page.waitForTimeout(650);
    assert(still.equals(await page.screenshot()), 'Reduced-motion progress must remain still');
    checks.push('Navigation works; reduced-motion icons remain still');
    await page.setViewportSize({ width: 320, height: 640 });
    await shot('wins-320');
    await page.setViewportSize({ width: 430, height: 932 });
    await page.getByRole('button', { name: '120', exact: true }).click();
    await shot('wallet-430');
    await page.getByRole('button', { name: 'Back', exact: true }).click();
    await page.getByRole('button', { name: 'Parents', exact: true }).click();
    await shot('parent-lock-430');
    await page.evaluate(stateKey => localStorage.removeItem(stateKey), stateKey);
    await page.evaluate(({ stateKey, state }) => localStorage.setItem(stateKey, JSON.stringify(JSON.stringify({ ...state, onboarded: false }))), { stateKey, state });
    await open();
    await shot('welcome-430');
    await page.setViewportSize({ width: 320, height: 640 });
    await shot('welcome-320');
    checks.push('Home, books, wins, wallet, parent lock and welcome captured; 320px, 430px and desktop checked');

    await page.evaluate(({ stateKey, state }) => localStorage.setItem(stateKey, JSON.stringify(JSON.stringify({ ...state, locale: 'ru' }))), { stateKey, state });
    await open();
    await shot('home-ru-320');
    await tab('Победы');
    await shot('wins-ru-320');
    await page.mouse.move(160, 380);
    await page.mouse.wheel(0, 800);
    await shot('milestones-ru-320');
    checks.push('Russian home and milestone layouts checked at 320px');

    await page.evaluate(({ stateKey, state }) => localStorage.setItem(stateKey, JSON.stringify(JSON.stringify(state))), { stateKey, state });
    await page.setViewportSize({ width: 430, height: 932 });
    await open();
    await tab('Books');
    await page.emulateMedia({ reducedMotion: 'no-preference' });
    await page.waitForTimeout(350);
    // Playwright's screenshot synchronization took >550ms in this software
    // renderer and missed the spring. Capture frames directly through CDP.
    const cdp = await context.newCDPSession(page);
    const navFrame = async name => {
      const { data } = await cdp.send('Page.captureScreenshot', {
        format: 'png', clip: { x: 0, y: 852, width: 430, height: 80, scale: 1 },
      });
      const frame = Buffer.from(data, 'base64');
      fs.writeFileSync(path.join(output, `${name}.png`), frame);
      return frame;
    };
    const before = await navFrame('navigation-before');
    const wins = page.getByRole('tab', { name: /My wins/ });
    await wins.evaluate(element => element.click());
    const frames = [];
    for (let i = 0; i < 4; i++) frames.push(await navFrame(`navigation-frame-${i}`));
    await page.waitForTimeout(650);
    const settled = await navFrame('navigation-settled');
    assert(frames.some(frame => !frame.equals(before) && !frame.equals(settled)), 'Navigation should have an intermediate animated frame');
    await page.waitForTimeout(650);
    assert(settled.equals(await navFrame('navigation-resting')), 'Navigation motion must stop after selection');
    assert.equal(await wins.getAttribute('aria-selected'), 'true');
    const saved = await page.evaluate(stateKey => JSON.parse(JSON.parse(localStorage.getItem(stateKey))), stateKey);
    assert.deepEqual(saved.reading, state.reading, 'Icon interactions must preserve reading progress');
    checks.push('Selection visibly animates, settles, exposes selected state and preserves reading progress');
    if (process.env.CAPTURE_PHASE !== 'before') {
      assert.deepEqual([...assets].sort(), ['book.webp', 'coin.webp', 'home.webp', 'lock.webp', 'trophy.webp']);
      checks.push('All five production icons loaded successfully');
    }
    assert.deepEqual(errors, []);
    fs.writeFileSync(path.join(output, 'checks.json'), JSON.stringify({ passed: true, checks, assets: [...assets], errors }, null, 2));
    console.log(JSON.stringify({ passed: true, checks, assets: [...assets], errors }, null, 2));
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exit(1); });
