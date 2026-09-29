# Batch quiz verification

Date: 2026-09-26. Flutter web in headless Chromium; no MobAI or device operations.

- `flutter analyze`: no issues.
- `flutter test`: 30 tests passed, including persisted attempts, third-error reset,
  preservation of earlier rewards, old page-credit migration, final partial batch,
  duplicate submissions, and rollback after delayed/failed storage writes.
- `flutter build web --no-web-resources-cdn`: passed.
- `tools/web_smoke.cjs`: all 20 browser checks passed. The run reread a reset
  batch, completed all 13 English pages, purchased a timer, reloaded, and checked
  English book questions under the Russian interface. No browser errors or
  external runtime requests occurred.
- Reviewed all 32 prepared questions against their source batches. Each batch
  contains four questions with four distinct options and one correct answer.

The independent review identified a save race. A regression demonstrated the
failure before the fix: an answer could be accepted while the final read marker
was still saving, and queued saves could preserve rolled-back progress. The
controller now blocks answers until the read marker commits and flushes a
corrective snapshot after failure. Reader navigation is disabled while saving.

Visual checks covered the four-option quiz, reset explanation, 320px scrolling
layout, and Russian interface. See [browser results](web-smoke.json),
[quiz](08-quiz.png), [reset](21-batch-reset.png),
[small quiz](22-small-quiz.png), and
[English questions with Russian UI](20-english-quiz-russian.png).

Native iOS/Android rendering was not tested for this change. Earlier MVP results
remain in the parent verification directory.

## Manual quiz launch follow-up

Per the updated requirement, reaching a batch boundary or reopening a book never
launches a quiz. The child presses **Start test** (or **Continue test** for saved
attempts). Four new widget regressions failed before the fix and now pass: short
pages 3 and 6, scrolling to the end of a longer page, and reopening an unfinished
quiz. The full 20-check browser run passed again, including button-only launch,
manual resume with persisted attempts, resets, rewards and Russian labels.
See [the reader waiting for Start test](23-start-test.png).
