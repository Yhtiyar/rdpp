/* Full listening journeys on release Flutter web with real bundled audio. */
const {chromium} = require(process.env.PLAYWRIGHT_MODULE || '/tmp/littlewins-browser/node_modules/playwright');
const fs = require('fs'), path = require('path'), assert = require('assert');
const root = path.resolve(__dirname, '..');
const out = path.join(root, 'docs/verification/new-books');
const url = process.env.APP_URL || 'http://127.0.0.1:7359';
const catalog = JSON.parse(fs.readFileSync(path.join(root, 'assets/toddler/catalog.json')));
const selected = process.env.BOOK_IDS?.split(',');
const books = catalog.filter(b => !selected || selected.includes(b.id)).sort((a, b) => b.pages.length - a.pages.length);
const reports = [];
let browser;

async function enable(page) {
  await page.waitForFunction(() => document.querySelector('flutter-view'));
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
}
async function saved(page, id) {
  return page.evaluate(id => {
    const raw = localStorage.getItem('littlewins.listening.v1');
    return raw ? JSON.parse(JSON.parse(raw))[id] : null;
  }, id);
}
async function waitState(page, id, predicate) {
  for (let i = 0; i < 600; i++) {
    const state = await saved(page, id);
    if (state && predicate(state)) return state;
    await page.waitForTimeout(100);
  }
  throw new Error(`Timed out: ${id} ${JSON.stringify(await saved(page, id))}`);
}
async function runBook(book) {
  const errors = [], external = [];
  const context = await browser.newContext({viewport: {width: 430, height: 932}, deviceScaleFactor: 1});
  await context.route('**/*', route => {
    const requestUrl = new URL(route.request().url());
    if (!['127.0.0.1', 'localhost'].includes(requestUrl.hostname)) {
      external.push(requestUrl.href); return route.abort();
    }
    return route.continue();
  });
  await context.addInitScript(id => {
    if (!localStorage.getItem('littlewins.state.v1')) {
      localStorage.setItem('littlewins.state.v1', JSON.stringify(JSON.stringify({
        version: 1, onboarded: true, locale: 'en', age: 3, sound: false,
        lastOpenedBookId: id, reading: {completed: {}, positions: {}, spentCoins: 0}, wallet: {},
      })));
    }
    window.__ended = 0;
    const original = HTMLMediaElement.prototype.play;
    HTMLMediaElement.prototype.play = function () {
      this.playbackRate = 8;
      this.addEventListener('ended', () => window.__ended++, {once: true});
      return original.call(this);
    };
  }, book.id);
  const page = await context.newPage();
  page.on('pageerror', e => errors.push(e.message));
  page.on('console', m => { if (m.type() === 'error' && /Exception|RenderFlex|overflow|Error/.test(m.text())) errors.push(m.text()); });
  page.on('response', response => { if (response.status() >= 400) errors.push(`${response.status()} ${response.url()}`); });
  const shot = async suffix => {
    await page.mouse.move(1, 1);
    await page.waitForTimeout(180);
    return page.screenshot({path: path.join(out, `${book.id}-${suffix}.png`)});
  };
  try {
    await page.goto(url); await enable(page);
    await page.getByText('Listen & play', {exact: true}).click();
    const pauseName = book.language === 'ru' ? 'Пауза' : 'Pause story';
    const playName = book.language === 'ru' ? 'Играть' : 'Play story';
    await page.getByRole('button', {name: pauseName, exact: false}).click();
    await page.getByRole('button', {name: playName, exact: false}).waitFor();
    await shot('page-430');
    await page.setViewportSize({width: 320, height: 568}); await page.waitForTimeout(250); await shot('page-320');
    await page.setViewportSize({width: 430, height: 932});
    await page.getByRole('button', {name: playName, exact: false}).click();
    for (let i = 0; i < book.questions.length; i++) {
      const q = book.questions[i];
      await waitState(page, book.id, s => s.phase === 'question' && s.question === i && s.promptHeard);
      if (i === 0) {
        await shot('question-430');
        const wrong = page.getByRole('button', {name: q.choices[1 - q.answer].label, exact: true});
        await wrong.click();
        await waitState(page, book.id, s => s.attempts === 1 && s.promptHeard);
        await wrong.click();
        await waitState(page, book.id, s => s.attempts === 2 && s.promptHeard);
        await page.setViewportSize({width: 320, height: 568}); await page.waitForTimeout(250); await shot('guided-320');
        await page.setViewportSize({width: 430, height: 932});
      }
      await page.getByRole('button', {name: q.choices[q.answer].label, exact: true}).click();
    }
    await page.getByText(book.language === 'ru' ? 'Звёздочка за сказку получена' : 'Story star collected', {exact: true}).waitFor({timeout: 30000});
    const final = await waitState(page, book.id, s => s.phase === 'complete');
    assert.equal(final.heard.length, book.pages.length);
    assert.equal(Object.keys(final.answers).length, book.questions.length);
    assert(final.completedEver);
    const main = await page.evaluate(() => JSON.parse(JSON.parse(localStorage.getItem('littlewins.state.v1'))));
    assert.deepEqual(main.reading.completed, {}); assert.equal(main.reading.spentCoins, 0);
    await shot('complete');
    const ended = await page.evaluate(() => window.__ended);
    assert(ended >= book.pages.length + book.questions.length * 2);
    assert.equal(errors.length, 0, errors.join('\n')); assert.equal(external.length, 0, external.join('\n'));
    const report = {id: book.id, version: book.version, passed: true, pages: book.pages.length, questions: book.questions.length, actualAudioEndEvents: ended, guidedRecovery: true, errors, external};
    reports.push(report); console.log(JSON.stringify(report));
  } catch (error) {
    await shot('failure');
    reports.push({id: book.id, passed: false, error: error.message, state: await saved(page, book.id), errors});
    console.error(book.id, error.message);
  } finally { await context.close(); }
}

(async () => {
  fs.mkdirSync(out, {recursive: true});
  browser = await chromium.launch({headless: true, args: ['--no-sandbox']});
  let index = 0;
  await Promise.all(Array.from({length: 3}, async () => {
    while (index < books.length) await runBook(books[index++]);
  }));
  const reportPath = path.join(out, 'journeys.json');
  const previous = fs.existsSync(reportPath) ? JSON.parse(fs.readFileSync(reportPath)) : [];
  const combined = [...previous.filter(r => r.version === 2 && !books.some(b => b.id === r.id)), ...reports];
  fs.writeFileSync(reportPath, JSON.stringify(combined, null, 2));
  assert(reports.every(r => r.passed), 'Some listening journeys failed');
  const page = await browser.newPage();
  await page.goto(url); await enable(page);
  const clips = catalog.flatMap(b => [...b.pages.map(p => p.audio), ...b.questions.flatMap(q => Object.values(q.audio)), b.completion.audio]);
  const rates = Object.fromEntries(catalog.map(b => [b.id, b.playbackRate]));
  const decoded = await page.evaluate(async ({paths, rates}) => {
    const audio = new AudioContext(), results = [];
    for (const file of paths) {
      const response = await fetch(`assets/${file}`);
      if (!response.ok) throw new Error(`${file}: HTTP ${response.status}`);
      const buffer = await audio.decodeAudioData(await response.arrayBuffer());
      const samples = buffer.getChannelData(0); let sum = 0, peak = 0, clipped = 0;
      for (const sample of samples) { sum += sample * sample; peak = Math.max(peak, Math.abs(sample)); if (Math.abs(sample) >= .999) clipped++; }
      results.push({file, seconds: buffer.duration, playbackSeconds: buffer.duration / rates[file.split('/')[2]], sampleRate: buffer.sampleRate, rms: Math.sqrt(sum / samples.length), peak, clippedFraction: clipped / samples.length});
    }
    await audio.close(); return results;
  }, {paths: clips, rates});
  fs.writeFileSync(path.join(out, 'audio-decode.json'), JSON.stringify(decoded, null, 2));
  assert(decoded.every(c => c.seconds > .5 && c.rms > .001 && c.clippedFraction < .01));
  console.log(`Decoded ${decoded.length} complete, non-silent MP3 clips.`);
  await browser.close();
})().catch(async error => { console.error(error); if (browser) await browser.close(); process.exitCode = 1; });
