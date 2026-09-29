/* Tap the highlighted answer before its spoken guidance has finished. */
const {chromium} = require(process.env.PLAYWRIGHT_MODULE || '/tmp/littlewins-browser/node_modules/playwright');
const fs = require('fs'), path = require('path'), assert = require('assert');
const root = path.resolve(__dirname, '..');
const output = path.join(root, 'docs/verification/listening-guided-answer');
const catalog = JSON.parse(fs.readFileSync(path.join(root, 'assets/toddler/catalog.json')));
const ids = (process.env.BOOK_IDS || 'kolobok,frog').split(',');
const url = process.env.APP_URL || 'http://127.0.0.1:7359';

(async () => {
  fs.mkdirSync(output, {recursive: true});
  const browser = await chromium.launch({headless: true, args: ['--no-sandbox']});
  const results = [];
  try {
    for (const id of ids) {
      const book = catalog.find(b => b.id === id), question = book.questions[0];
      const context = await browser.newContext({viewport: {width: 320, height: 568}, hasTouch: true});
      await context.addInitScript(({id, version, afterPage}) => {
        localStorage.setItem('littlewins.state.v1', JSON.stringify(JSON.stringify({
          onboarded: true, locale: 'en', age: 3, sound: false, lastOpenedBookId: id,
          reading: {completed: {}, positions: {}, spentCoins: 0}, wallet: {},
        })));
        localStorage.setItem('littlewins.listening.v1', JSON.stringify(JSON.stringify({[id]: {
          version, phase: 'question', page: afterPage, question: 0, heard: [0, 1, 2],
          answers: {}, attempts: 0, clipKind: 'prompt', promptHeard: true, positionMs: 0,
        }})));
        window.__speech = [];
        const play = HTMLMediaElement.prototype.play;
        HTMLMediaElement.prototype.play = function () {
          if (this.src.includes('/audio/')) {
            this.playbackRate = this.src.includes('-guided.mp3') ? 1 : 4;
            window.__speech.push({element: this, file: this.src, ended: false});
            const record = window.__speech.at(-1);
            this.addEventListener('ended', () => record.ended = true, {once: true});
          }
          return play.call(this);
        };
      }, {id, version: book.version, afterPage: question.afterPage});
      const page = await context.newPage(), errors = [];
      page.on('pageerror', e => errors.push(e.message));
      const state = () => page.evaluate(id => JSON.parse(JSON.parse(localStorage.getItem('littlewins.listening.v1')))[id], id);
      const wait = async predicate => {
        for (let i = 0; i < 120; i++) {
          const value = await state();
          if (predicate(value)) return value;
          await page.waitForTimeout(50);
        }
        throw new Error(`State did not advance: ${JSON.stringify(await state())}`);
      };
      try {
        await page.goto(url);
        await page.waitForFunction(() => document.querySelector('flutter-view'));
        await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
        await page.getByText('Listen & play', {exact: true}).click();
        const wrong = page.getByRole('button', {name: question.choices[1 - question.answer].label, exact: true});
        await wrong.click();
        await wait(s => s.attempts === 1 && s.promptHeard);
        await wrong.click();
        await page.waitForFunction(() => {
          const current = window.__speech.at(-1);
          return current?.file.includes('-guided.mp3') && !current.ended
            && current.element.currentTime > current.element.duration * .4;
        });
        await page.screenshot({path: path.join(output, `${id}-guidance.png`)});
        const green = page.getByRole('button', {name: question.choices[question.answer].label, exact: true});
        const box = await green.boundingBox();
        assert(box);
        // Physical tap: do not let Playwright wait for a disabled answer to unlock.
        await page.touchscreen.tap(box.x + box.width / 2, box.y + box.height / 2);
        const accepted = await wait(s => s.clipKind === 'feedback' && s.answers[question.id] === true);
        assert.equal(accepted.question, 0);
        await page.screenshot({path: path.join(output, `${id}-accepted.png`)});
        // Extra taps must not replay feedback or skip the next question.
        await page.touchscreen.tap(box.x + box.width / 2, box.y + box.height / 2);
        await wait(s => s.question === 1 && s.clipKind === 'prompt');
        const speech = await page.evaluate(() => window.__speech.map(({file, ended, element}) => ({file, ended, paused: element.paused})));
        const feedback = speech.filter(s => s.file.endsWith('/' + question.audio.feedback));
        assert.equal(feedback.length, 1);
        assert(feedback[0].ended);
        assert(speech.filter(s => s.file.includes('-guided.mp3')).every(s => s.paused));
        assert.deepEqual(errors, []);
        results.push({id, passed: true, earlyGuidedTap: true, feedbackPlays: 1, advancedToQuestion: 1, errors});
      } catch (error) {
        await page.screenshot({path: path.join(output, `${id}-failure.png`)});
        results.push({id, passed: false, error: error.message, state: await state(), errors});
      } finally { await context.close(); }
    }
  } finally { await browser.close(); }
  fs.writeFileSync(path.join(output, 'checks.json'), JSON.stringify(results, null, 2));
  console.log(JSON.stringify(results, null, 2));
  assert(results.every(r => r.passed), 'Guided-answer regression failed');
})().catch(error => {console.error(error); process.exitCode = 1;});
