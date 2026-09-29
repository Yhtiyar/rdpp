# Listening replay, language selector and home copy

Verified on 28 September 2026 using Flutter web and Chromium. No mobile-device tooling was used.

## Changes

- Replaying a listening section repeats every picture question at its checkpoint. Old answers and assistance for that checkpoint are cleared; interrupted questions still resume paused in place.
- Listening options include **Start from beginning / Начать сначала**. Restart dismisses the sheet, resets the current run and starts the first narration. Story stars, preferences, other listening books, reading progress and wallet state remain intact.
- Opening options no longer redundantly notifies an already paused session during route rebuilding; the new widget regression exposed that assertion.
- The library uses a larger English / Русский selector with a purple sliding selection, check mark, native language names and localized accessibility labels. Animation follows the existing reduced-motion policy.
- Home introduces the title with **Read with MiMi / Читаем с МиМи**, followed by **A few pages, then a little quiz! / Почитаем чуть-чуть, а потом — вопросы!**. Completed books receive an invitation to read again.

## Evidence

- New session regression failed before the fix: revisiting an answered checkpoint skipped directly to the next page. It now passes, including restoring the second question of a repeated checkpoint.
- New widget regression failed before the restart option existed. It now verifies reset, preserved progress and uninterrupted playback after the sheet closes at 320 × 568.
- `flutter test --no-pub --reporter expanded`: **90 tests passed**.
- `flutter analyze --no-pub`: **No issues found**.
- `flutter build web --no-web-resources-cdn --no-pub`: **passed**.
- `node tools/listening_replay_web_check.cjs`: **passed** for Колобок and The Frog Prince using bundled audio and native media completion events at accelerated test playback. Both completed checkpoint questions were required again; restarting during a question played the first narration without overlapping audio. Stars and unrelated stored progress were preserved.
- Both library shelves contain all expected titles under both interface languages. Home and library screenshots cover widths 320, 430 and 1024. Listening options and restart screenshots cover 320 × 568. No browser errors were recorded.

Machine-readable results are in `checks.json`. Screenshots were visually reviewed for selector contrast, clear selection, text wrapping and reachable restart controls.
