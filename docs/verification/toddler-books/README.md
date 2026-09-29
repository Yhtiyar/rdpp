# Toddler listening editions · 27 September 2026

Historical verification of the initial two-book, shortened editions. Those
editions and their media have been superseded. See the [current eighteen-book
verification](../new-books/README.md) and [production guide](../../../toddlerbooks.md).

The Frog Prince and Колобок now have separate listening editions, entered through **Listen & play** on Home or in the Library. The original reading mode, quizzes and coin ledger remain intact.

- English: 12 illustrated scenes, 8 picture questions, 45 narrated clips.
- Russian: 9 illustrated scenes, 6 picture questions, 34 narrated clips.
- Narrator: OpenRouter `qwen/qwen-audio-3.0-tts-plus`, female `longanlingxin`, played at 0.85× for a gentler pace.
- Audio: roughly 8.5 MiB, bundled with the app. No cloud requests during playback.
- English answer art: a six-cell painted atlas, revised to remove edge bleeding. Russian answers reuse the supplied character illustrations. Original credits and watermarks are retained.

## Evidence

`web-check.json` records both complete stories using actual MP3 playback at 8× in Chromium. The test waits for real end events; it does not call application completion callbacks. It covers every page and question, pause/reopen, wrong-answer hints, the guided answer, a saved completion star and unchanged reading/coin state. `audio-decode.json` records full decoding, duration, RMS, peak and clipping for all 79 bundled clips. External domains are blocked during the walkthrough.

`recovery-check.json` covers intentional browser autoplay rejection and retry, narration with effects disabled, document hiding, paused return, manual page turns, captions, reduced-motion stability during playback, rapid replay and closing without overlapping audio. Hiding is simulated through the document visibility event consumed by Flutter; this is not a physical-device backgrounding test.

`transcriptions.json` compares first/last story pages and first questions for both languages with Qwen ASR. The final six samples match the scripts aside from punctuation/case and Russian ё/е normalization. The Russian ending was regenerated after an earlier transcription flagged the character's name. This is automated intelligibility evidence, not a human judgment of accent or vocal warmth.

[English page](01-frog-page-430.png) · [Small-screen picture question](06-frog-question-320.png) · [Russian page](07-kolobok-page.png) · [Russian question](08-kolobok-question.png) · [Completion](10-kolobok-complete.png)

Screenshots cover 320×568, 430×932 and 1365×900 viewports, plus both books, picture-choice recovery, completion and listening settings. All were inspected; the English atlas was revised after the first inspection.

## Code verification

- `flutter analyze`: no issues.
- `flutter test`: 88 passing tests, including the existing reading/reward suite.
- Python audio-generation tests: 4 passing.
- `flutter build web --no-web-resources-cdn --no-wasm-dry-run`: release build.
- Secret check: the `.env` OpenRouter key is absent from the built web directory.
- Generation dry run: zero missing or stale clips; request and file hashes match.

The original `tools/web_smoke.cjs` also passed against this build; its screenshots, recording and checks are in `reading-regression/`. This includes both original reading books, quizzes, rewards, language persistence, small-screen layouts and no external requests/browser errors.

A fresh read-only code review found four important issues. The fix pass added reproducing tests and fixed: writes before successful state loading, cancellation during audio preparation, duplicate listening routes, and uncaught errors from derived audio streams. An additional regression verifies that a delayed load finishing behind another route stays silent. These tests passed in the full suite.

## Decisions and limitations

Implementation stayed in the existing feature branch without committing or moving the user's unrelated work. The English listening edition has 12 scenes rather than the original 13 pages so every checkpoint follows a complete three-scene group; source mappings and both original endings are retained. Listening uses a separate preferences namespace to isolate it from reading rewards. Any future parent-data reset must clear both namespaces.

The developer generator's header/hash validation is deliberately followed by a separate complete audio decode audit. Integrating a decoder into that Python tool is deferred. Its queued concurrent requests are bounded by a cost estimate and retry limit; stopping the entire queue on authentication/credit errors is also deferred.

Native bundles contain the media for offline use. The browser tests use a local server and forbid external requests; they do not establish PWA offline caching after losing the hosting server. A parent/child trial and fluent human voice review have not been conducted. Existing source notices do not grant additional redistribution rights.

## Reproduce

```sh
flutter analyze
flutter test
python3 -m unittest discover -s tools/tests -p test_toddler_audio.py
python3 tools/generate_toddler_audio.py
flutter build web --no-web-resources-cdn --no-wasm-dry-run
python3 -m http.server 7358 --directory build/web
```

In another terminal (Playwright installed; override `PLAYWRIGHT_MODULE` if needed):

```sh
node tools/toddler_web_check.cjs
node tools/toddler_recovery_web_check.cjs
```
