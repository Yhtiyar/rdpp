/* Run against a built Flutter web app: APP_URL=http://127.0.0.1:7357 node tools/home_animation_web_check.cjs */
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || '/tmp/littlewins-browser/node_modules/playwright');
const fs = require('fs');
const path = require('path');
const assert = require('assert');
const { execFileSync } = require('child_process');
const output = path.resolve(__dirname, '../docs/verification/home-page-turn');
const frames = path.resolve(__dirname, '../.implementation/emotional/reading-final-frames');

(async () => {
  fs.mkdirSync(output, { recursive: true });
  fs.mkdirSync(frames, { recursive: true });
  const browser = await chromium.launch({ headless: true, args: ['--no-sandbox'] });
  const errors = [], audio = [];
  let context;
  try {
    context = await browser.newContext({
      viewport: { width: 430, height: 932 }, deviceScaleFactor: 1,
    });
    await context.addInitScript(() => localStorage.setItem('littlewins.state.v1', JSON.stringify(JSON.stringify({
      version: 1, onboarded: true, locale: 'en', sound: true,
      reading: { completed: {}, positions: {}, spentCoins: 0 }, wallet: {}, batchProgress: {},
    }))));
    const page = await context.newPage();
    page.on('pageerror', e => errors.push(e.message));
    page.on('console', m => {
      if (m.type() === 'error' && /Exception|RenderFlex|overflow|Assertion failed/.test(m.text())) errors.push(m.text());
    });
    page.on('request', r => { if (r.url().includes('/sounds/')) audio.push(r.url()); });
    await page.goto(process.env.APP_URL || 'http://127.0.0.1:7357');
    await page.waitForFunction(() => document.querySelector('flt-semantics-placeholder'));
    await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
    await page.getByText('The Frog Prince', { exact: true }).waitFor();
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await page.waitForTimeout(500);
    const beforeState = await page.evaluate(() => localStorage.getItem('littlewins.state.v1'));
    const title = await page.getByText('The Frog Prince', { exact: true }).boundingBox();
    const hero = { x: 22, y: title.y - 16 - 386 * 327 / 381, scale: 386 / 381 };
    await page.screenshot({ path: path.join(frames, 'baseline.png') });
    await page.screenshot({ path: path.join(output, 'home-430.png') });
    await page.emulateMedia({ reducedMotion: 'no-preference' });
    const started = Date.now(), samples = [];
    while (Date.now() - started < 11000) {
      const filename = `frame-${String(samples.length).padStart(3, '0')}.png`;
      await page.screenshot({ path: path.join(frames, filename) });
      samples.push({ filename, ms: Date.now() - started });
      await page.waitForTimeout(150);
    }
    // Inspect pixels in the head and foreleg separately: moving only the page
    // must never pass this regression check again. Pillow only reads evidence.
    const metrics = JSON.parse(execFileSync('python3', ['-c', `
import json, sys
from pathlib import Path
from PIL import Image, ImageChops, ImageStat
folder=Path(sys.argv[1]); hero=json.loads(sys.argv[2]); samples=json.loads(sys.argv[3])
base=Image.open(folder/'baseline.png').convert('RGB')
def box(coords):
 return tuple(round((hero['x'] if i%2==0 else hero['y'])+v*hero['scale']) for i,v in enumerate(coords))
regions={'head':box((85,45,315,179)), 'paw':box((200,169,270,286)), 'eyes':box((108,99,254,171)), 'ui':(0,710,430,932)}
rows=[]
for sample in samples:
 frame=Image.open(folder/sample['filename']).convert('RGB')
 row=dict(sample)
 for name,rect in regions.items():
  row[name]=sum(ImageStat.Stat(ImageChops.difference(base.crop(rect),frame.crop(rect))).mean)/3
 row['pagePixels']=sum(r>210 and g>190 and b<225 and r-b>20 for r,g,b in frame.crop(box((65,145,232,206))).getdata())
 row['eyeDarkPixels']=sum(r<90 and g<85 and b<145 for r,g,b in frame.crop(regions['eyes']).getdata())
 rows.append(row)
print(json.dumps({'samples':rows,'maximumMeanPixelDifference':{name:max(r[name] for r in rows) for name in regions}}))
`, frames, JSON.stringify(hero), JSON.stringify(samples)], { encoding: 'utf8' }));
    const max = metrics.maximumMeanPixelDifference;
    assert(max.head > 2, `Head is static: ${max.head}`);
    assert(max.paw > 3, `Paw is static: ${max.paw}`);
    assert(max.ui < .1, `Animation moved the surrounding UI: ${max.ui}`);
    const turn = metrics.samples.reduce((a, b) => a.pagePixels > b.pagePixels ? a : b);
    const blink = metrics.samples.reduce((a, b) => a.eyeDarkPixels < b.eyeDarkPixels ? a : b);
    fs.copyFileSync(path.join(frames, turn.filename), path.join(output, 'page-turning.png'));
    fs.copyFileSync(path.join(frames, blink.filename), path.join(output, 'blink.png'));
    assert.equal(await page.evaluate(() => localStorage.getItem('littlewins.state.v1')), beforeState);
    await context.close();
    context = null;

    // Keep accessibility and viewport changes out of the preview recording.
    context = await browser.newContext({ viewport: { width: 430, height: 932 }, reducedMotion: 'reduce' });
    await context.addInitScript(state => localStorage.setItem('littlewins.state.v1', state), beforeState);
    const still = await context.newPage();
    still.on('pageerror', e => errors.push(e.message));
    await still.goto(process.env.APP_URL || 'http://127.0.0.1:7357');
    await still.waitForFunction(() => document.querySelector('flt-semantics-placeholder'));
    await still.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
    await still.getByText('The Frog Prince', { exact: true }).waitFor();
    await still.waitForTimeout(500);
    const reduced = await still.screenshot({ path: path.join(output, 'reduced-motion.png') });
    await still.waitForTimeout(5300);
    assert(reduced.equals(await still.screenshot()), 'Reduced motion animated');
    for (const size of [{ width: 320, height: 640 }, { width: 1365, height: 900 }]) {
      await still.setViewportSize(size); await still.waitForTimeout(300);
      await still.screenshot({ path: path.join(output, `home-${size.width}.png`) });
    }
    await context.close();
    // Record two uninterrupted cycles; screenshot reads would stall software
    // WebGL and misrepresent the animation's normal playback.
    context = await browser.newContext({
      viewport: { width: 430, height: 932 }, deviceScaleFactor: 1,
      recordVideo: { dir: path.join(frames, 'video'), size: { width: 430, height: 932 } },
    });
    await context.addInitScript(state => localStorage.setItem('littlewins.state.v1', state), beforeState);
    const preview = await context.newPage();
    preview.on('pageerror', e => errors.push(e.message));
    await preview.goto(process.env.APP_URL || 'http://127.0.0.1:7357');
    await preview.waitForFunction(() => document.querySelector('flutter-view'));
    await preview.waitForTimeout(12000);
    await context.close();
    context = null;
    fs.copyFileSync(await preview.video().path(), path.join(output, 'home-page-turn.webm'));
    assert.equal(audio.length, 0, 'Reading loop played unsolicited audio');
    assert.deepEqual(errors, [], 'Browser errors');
    const report = {
      passed: true,
      checks: ['head visibly moves', 'paw visibly moves', 'surrounding UI stays still',
        'no reading-state changes', 'reduced motion stays still for a complete cycle',
        '320px and desktop layouts captured', 'silent loop', 'no browser errors'],
      ...metrics, errors,
    };
    fs.writeFileSync(path.join(output, 'checks.json'), JSON.stringify(report, null, 2));
    console.log(JSON.stringify({ ...report, samples: `${samples.length} frames over 11 seconds` }, null, 2));
  } finally {
    if (context) await context.close();
    await browser.close();
  }
})().catch(error => { console.error(error); process.exit(1); });
