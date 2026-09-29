/* Revisit answered games, restart mid-question, and inspect the language selector. */
const {chromium} = require(process.env.PLAYWRIGHT_MODULE || '/tmp/littlewins-browser/node_modules/playwright');
const fs = require('fs'), path = require('path'), assert = require('assert');
const root = path.resolve(__dirname, '..');
const output = path.join(root, 'docs/verification/listening-replay');
const catalog = JSON.parse(fs.readFileSync(path.join(root, 'assets/toddler/catalog.json')));
const books = JSON.parse(fs.readFileSync(path.join(root, 'assets/books/catalog.json')));
const url = process.env.APP_URL || 'http://127.0.0.1:7359';

(async () => {
  fs.mkdirSync(output, {recursive: true});
  const browser = await chromium.launch({headless: true, args: ['--no-sandbox']});
  const results = [];
  try {
    for (const id of ['kolobok', 'frog']) {
      const book = catalog.find(b => b.id === id), ru = book.language === 'ru';
      const context = await browser.newContext({viewport: {width: 320, height: 568}, hasTouch: true});
      await context.addInitScript(({book}) => {
        localStorage.setItem('littlewins.state.v1', JSON.stringify(JSON.stringify({
          onboarded: true, locale: book.language, age: 3, sound: false, lastOpenedBookId: book.id,
          reading: {completed: {}, positions: {}, spentCoins: 0}, wallet: {},
        })));
        localStorage.setItem('littlewins.listening.v1', JSON.stringify(JSON.stringify({
          'other-book': {page: 4, completedEver: true},
          [book.id]: {
            version: book.version, phase: 'page', page: 3, question: 1, heard: [0, 1, 2, 3],
            answers: Object.fromEntries(book.questions.slice(0, 2).map(q => [q.id, true])),
            attempts: 0, clipKind: 'prompt', promptHeard: false, positionMs: 0,
            completedEver: true, autoAdvance: false, captions: false,
          },
        })));
        window.__speech = [];
        const play = HTMLMediaElement.prototype.play;
        HTMLMediaElement.prototype.play = function () {
          if (this.src.includes('/audio/')) {
            this.playbackRate = 4;
            const record = {file: this.src, ended: false, element: this};
            window.__speech.push(record);
            this.addEventListener('ended', () => record.ended = true, {once: true});
          }
          return play.call(this);
        };
      }, {book});
      const page = await context.newPage(), errors = [];
      page.on('pageerror', e => errors.push(e.message));
      page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
      const all = () => page.evaluate(() => JSON.parse(JSON.parse(localStorage.getItem('littlewins.listening.v1'))));
      const state = async () => (await all())[id];
      const wait = async predicate => {
        for (let i = 0; i < 240; i++) {
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
        const homeLabel = ru ? 'Читаем с МиМи' : 'Read with MiMi';
        await page.getByText(homeLabel, {exact: true}).waitFor();
        assert.equal(await page.getByText(ru ? 'Почитаем чуть-чуть, а потом — вопросы!' : 'A few pages, then a little quiz!', {exact: true}).count(), 1);
        for (const width of [320, 430, 1024]) {
          await page.setViewportSize({width, height: width === 320 ? 700 : 932});
          await page.getByText(homeLabel, {exact: true}).scrollIntoViewIfNeeded();
          await page.waitForTimeout(300);
          await page.screenshot({path: path.join(output, `home-${book.language}-${width}.png`)});
        }
        await page.setViewportSize({width: 320, height: 568});
        const mainBefore = await page.evaluate(() => localStorage.getItem('littlewins.state.v1'));
        await page.getByText(ru ? 'Слушать и играть' : 'Listen & play', {exact: true}).click();
        await page.getByRole('button', {name: ru ? 'Предыдущая страница' : 'Previous page', exact: true}).click();
        await wait(s => s.page === 2);
        await page.getByRole('button', {name: ru ? 'Следующая страница' : 'Next page', exact: true}).click();
        await wait(s => s.phase === 'question' && s.question === 0 && s.promptHeard);
        assert.deepEqual((await state()).answers, {});
        for (let index = 0; index < 2; index++) {
          const question = book.questions[index];
          await wait(s => s.question === index && s.promptHeard);
          await page.getByRole('button', {name: question.choices[question.answer].label, exact: true}).click();
          await wait(s => index === 0 ? s.question === 1 : s.phase === 'page' && s.page === 3);
        }
        assert.equal(Object.keys((await state()).answers).length, 2);
        await page.getByRole('button', {name: ru ? 'Предыдущая страница' : 'Previous page', exact: true}).click();
        await page.getByRole('button', {name: ru ? 'Следующая страница' : 'Next page', exact: true}).click();
        await wait(s => s.phase === 'question' && s.question === 0);
        await page.getByRole('button', {name: ru ? 'Настройки сказки' : 'Listening options', exact: true}).click();
        const restart = page.getByText(ru ? 'Начать сначала' : 'Start from beginning', {exact: true});
        await restart.waitFor();
        await page.screenshot({path: path.join(output, `${id}-options-320.png`)});
        await restart.click();
        await wait(s => s.phase === 'page' && s.page === 0);
        await page.waitForFunction(first => window.__speech.at(-1)?.file.endsWith('/' + first), book.pages[0].audio);
        await page.waitForTimeout(500);
        assert.equal(await restart.count(), 0);
        assert.deepEqual((await state()).answers, {});
        assert.deepEqual((await state()).heard, []);
        assert.equal((await state()).completedEver, true);
        assert.equal((await state()).autoAdvance, false);
        assert.deepEqual((await all())['other-book'], {page: 4, completedEver: true});
        assert.equal(await page.evaluate(() => localStorage.getItem('littlewins.state.v1')), mainBefore);
        assert(await page.evaluate(() => !window.__speech.at(-1).element.paused));
        assert(await page.evaluate(() => window.__speech.slice(0, -1).every(s => s.element.paused)));
        await page.screenshot({path: path.join(output, `${id}-restarted-320.png`)});
        await page.getByRole('button', {name: ru ? 'Закрыть сказку' : 'Close story', exact: true}).click();

        // Both interface languages, both shelves, phone and tablet widths.
        await page.getByText(ru ? 'Все мои книги' : 'Explore my books', {exact: true}).click();
        for (const language of ['en', 'ru']) {
          const name = language === 'en'
            ? (ru ? 'Книги на английском' : 'English books')
            : (ru ? 'Книги на русском' : 'Russian books');
          await page.getByRole('button', {name, exact: true}).click();
          for (const candidate of books.filter(b => b.language === language)) {
            assert.equal(await page.getByText(candidate.title, {exact: true}).count(), 1);
          }
          for (const width of [320, 430, 1024]) {
            await page.setViewportSize({width, height: width === 320 ? 700 : 932});
            await page.waitForTimeout(300);
            await page.screenshot({path: path.join(output, `library-${book.language}-${language}-${width}.png`)});
          }
        }
        assert.deepEqual(errors, []);
        results.push({id, passed: true, repeatedBothQuestions: true, restartedDuringQuestion: true,
          preservedStarAndOtherProgress: true, libraryLanguages: ['en', 'ru'], widths: [320, 430, 1024], errors});
      } catch (error) {
        await page.screenshot({path: path.join(output, `${id}-failure.png`)});
        results.push({id, passed: false, error: error.message, state: await state(), errors});
      } finally { await context.close(); }
    }
  } finally { await browser.close(); }
  fs.writeFileSync(path.join(output, 'checks.json'), JSON.stringify(results, null, 2));
  console.log(JSON.stringify(results, null, 2));
  assert(results.every(r => r.passed), 'Listening replay or library check failed');
})().catch(error => {console.error(error); process.exitCode = 1;});
