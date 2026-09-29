const {chromium} = require(process.env.PLAYWRIGHT_MODULE || '/tmp/littlewins-browser/node_modules/playwright');
const fs = require('fs'), path = require('path'), assert = require('assert');
const root = path.resolve(__dirname, '..'), out = path.join(root, 'docs/verification/new-books');
const url = process.env.APP_URL || 'http://127.0.0.1:7359';
const books = JSON.parse(fs.readFileSync(path.join(root, 'assets/books/catalog.json')));
(async () => {
  fs.mkdirSync(out, {recursive: true});
  const browser = await chromium.launch({headless: true, args: ['--no-sandbox']});
  const errors = [], checks = [];
  const context = await browser.newContext({viewport: {width: 430, height: 932}});
  const page = await context.newPage();
  page.on('pageerror', e => errors.push(e.message));
  page.on('console', m => {if (m.type() === 'error' && /Exception|overflow|Error/.test(m.text())) errors.push(m.text());});
  async function open(id) {
    await page.goto(url);
    await page.evaluate(id => {
      localStorage.setItem('littlewins.state.v1', JSON.stringify(JSON.stringify({
        onboarded: true, locale: 'en', age: 5, sound: false, lastOpenedBookId: id,
        reading: {completed: {}, positions: {}, spentCoins: 0}, wallet: {},
      })));
    }, id);
    await page.reload();
    await page.waitForFunction(() => document.querySelector('flutter-view'));
    await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  }
  await open('frog');
  await page.getByText('Explore my books', {exact: true}).click();
  for (const language of ['en', 'ru']) {
    await page.getByRole('button', {name: language === 'en' ? 'English books' : 'Russian books', exact: true}).click();
    for (const book of books.filter(b => b.language === language)) {
      assert.equal(await page.getByText(book.title, {exact: true}).count(), 1, book.id);
    }
    for (const width of [430, 320, 1365]) {
      await page.setViewportSize({width, height: width === 320 ? 568 : 932});
      await page.waitForTimeout(300);
      await page.screenshot({path: path.join(out, `library-${language}-${width}.png`)});
    }
    checks.push(`${language}: every title has its own library entry`);
  }
  for (const book of books.slice(2)) {
    await page.setViewportSize({width: 430, height: 932});
    await open(book.id);
    await page.getByText('Continue my story', {exact: true}).click();
    await page.getByText(`Page 1 of ${book.pages.length}`, {exact: true}).waitFor();
    await page.screenshot({path: path.join(out, `${book.id}-reading.png`)});
    const batch = book.batches[0];
    for (let i = 0; i < batch.endPage; i++) {
      await page.getByText(`Page ${i + 1} of ${book.pages.length}`, {exact: true}).waitFor();
      await page.mouse.move(200, 450); await page.mouse.wheel(0, 20000); await page.waitForTimeout(400);
      // Reader offers both an arrow and a labelled footer for the next page.
      await page.getByText(i === batch.endPage - 1 ? 'Start test' : 'Next page', {exact: true}).last().click();
    }
    for (let i = 0; i < batch.questions.length; i++) {
      const q = batch.questions[i];
      await page.getByRole('button', {name: `${'ABCD'[q.answer]} ${q.options[q.answer]}`, exact: true}).click();
      await page.getByText('Check answer', {exact: true}).click();
      if (i < batch.questions.length - 1) await page.getByText('Next question', {exact: true}).click();
    }
    await page.getByText(`Saved balance: ${batch.endPage * 10} coins`, {exact: true}).waitFor();
    const state = await page.evaluate(() => JSON.parse(JSON.parse(localStorage.getItem('littlewins.state.v1'))));
    assert.equal(Object.keys(state.reading.completed).length, batch.endPage);
    checks.push(`${book.id}: first reading batch and all four answers earn exactly ${batch.endPage * 10} coins`);
    console.log(checks.at(-1));
  }
  assert.deepEqual(errors, []);
  fs.writeFileSync(path.join(out, 'library-reading.json'), JSON.stringify({passed: true, checks, errors}, null, 2));
  await browser.close();
})().catch(error => {console.error(error); process.exit(1);});
