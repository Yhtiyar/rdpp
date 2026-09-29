/* Run against a Flutter web build served at APP_URL. */
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || '/tmp/littlewins-browser/node_modules/playwright');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const output = path.resolve(__dirname, '../docs/verification/parent-age');
const url = process.env.APP_URL || 'http://127.0.0.1:7361';
const stateKey = 'littlewins.state.v1';
const salt = 'parent-age-web-check';
let pinHash = Buffer.from(`${salt}:123456`);
for (let i = 0; i < 10000; i++) pinHash = crypto.createHash('sha256').update(pinHash).digest();
const initial = {
  version: 1, onboarded: true, locale: 'en', age: 7, sound: false, dailyLimit: 60,
  auth: { salt, pinHash: pinHash.toString('base64'), recoveryHash: '', attempts: 0, lockedUntil: null },
  reading: { completed: { 'frog:0': '2026-09-27' }, spentCoins: 0, positions: { frog: 1 } },
  wallet: { minutesByDay: {}, endsAt: null },
  batchProgress: {}, lastOpenedBookId: 'frog', textSize: 20, pendingPurchase: null,
};
const errors = [], checks = [];
let browser, page;

async function enableSemantics() {
  await page.waitForFunction(() => document.querySelector('flutter-view'));
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
}

async function saved() {
  return page.evaluate(key => JSON.parse(JSON.parse(localStorage.getItem(key))), stateKey);
}

async function enterParents(locale = 'en') {
  await page.getByRole('button', { name: locale === 'ru' ? 'Родителям' : 'Parents', exact: true }).click();
  for (const digit of '123456') await page.getByText(digit, { exact: true }).click();
  await page.getByText(locale === 'ru' ? 'Ваши настройки' : 'Your settings', { exact: true }).waitFor();
}

async function alignText(text) {
  const label = page.getByText(text, { exact: true });
  await label.waitFor();
  const size = page.viewportSize();
  await page.mouse.move(size.width / 2, Math.min(size.height - 100, 450));
  for (let i = 0; i < 5; i++) {
    const box = await label.boundingBox();
    if (Math.abs(box.y - 160) < 10) break;
    await page.mouse.wheel(0, box.y - 160);
    await page.waitForTimeout(300);
  }
}

async function select(label, age, locale = 'en') {
  await alignText(locale === 'ru' ? 'Возраст ребёнка' : 'Child’s age');
  const option = page.getByRole('button', { name: locale === 'ru' ? `${label} лет` : `Ages ${label}`, exact: true });
  await option.click();
  await page.waitForFunction(({ key, age }) => JSON.parse(JSON.parse(localStorage.getItem(key))).age === age, { key: stateKey, age });
  await page.waitForTimeout(300);
  assert.equal(await option.getAttribute('aria-current'), 'true');
  const state = await saved();
  assert.deepEqual(state.reading, initial.reading);
  assert.deepEqual(state.auth, initial.auth);
  assert.deepEqual(state.wallet, initial.wallet);
  assert.equal(state.onboarded, true);
  assert.equal(state.sound, false);
}

async function screenshot(name) {
  await page.mouse.move(3, 3);
  await page.waitForTimeout(150);
  await page.screenshot({ path: path.join(output, `${name}.png`) });
}

(async () => {
  fs.mkdirSync(output, { recursive: true });
  browser = await chromium.launch({ headless: true, args: ['--no-sandbox'] });
  const context = await browser.newContext({ viewport: { width: 430, height: 932 }, deviceScaleFactor: 1 });
  page = await context.newPage();
  page.on('pageerror', e => errors.push(e.message));
  page.on('console', message => {
    if (message.type() === 'error' && /Exception|RenderFlex|overflow|Error/.test(message.text())) errors.push(message.text());
  });
  await page.addInitScript(({ key, initial }) => {
    if (!localStorage.getItem(key)) localStorage.setItem(key, JSON.stringify(JSON.stringify(initial)));
  }, { key: stateKey, initial });
  await page.goto(url);
  await enableSemantics();
  assert.equal(await page.getByText('Child’s age', { exact: true }).count(), 0);
  await enterParents();
  await alignText('Child’s age');
  await screenshot('01-current-430');
  for (const [label, age] of [['4–6', 4], ['10–12', 10], ['7–9', 7]]) {
    await select(label, age);
    await screenshot(`02-age-${age}-430`);
  }
  checks.push('All three age categories can be switched inside the PIN-protected parent area');
  checks.push('Every change preserves reading progress, coins, parent PIN, wallet and other settings');

  await select('10–12', 10);
  await page.reload();
  await enableSemantics();
  await enterParents();
  await alignText('Child’s age');
  assert.equal(await page.getByRole('button', { name: 'Ages 10–12', exact: true }).getAttribute('aria-current'), 'true');
  assert.equal((await saved()).age, 10);
  checks.push('Saved category survives reload and another parent PIN entry');

  await page.setViewportSize({ width: 320, height: 640 });
  await select('4–6', 4);
  await screenshot('03-age-320');
  await alignText('Interface language');
  await page.getByText('Русский', { exact: true }).click();
  await select('10–12', 10, 'ru');
  await screenshot('04-age-russian-320');
  checks.push('Age switching works in English and Russian at 320px width');

  await page.setViewportSize({ width: 1365, height: 900 });
  await alignText('Возраст ребёнка');
  await screenshot('05-age-russian-desktop');
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await select('7–9', 7, 'ru');
  const first = await page.screenshot();
  await page.waitForTimeout(400);
  assert(first.equals(await page.screenshot()), 'Reduced-motion age setting should remain still');
  await screenshot('06-reduced-motion');
  checks.push('Desktop layout and reduced-motion selection verified');
  assert.deepEqual(errors, []);
  fs.writeFileSync(path.join(output, 'checks.json'), JSON.stringify({ passed: true, checks, errors }, null, 2) + '\n');
  console.log(JSON.stringify({ passed: true, checks, errors }, null, 2));
})().catch(async error => {
  console.error(error);
  if (page) {
    await screenshot('failure');
    console.error(await page.locator('body').ariaSnapshot());
  }
  process.exitCode = 1;
}).finally(async () => { if (browser) await browser.close(); });
