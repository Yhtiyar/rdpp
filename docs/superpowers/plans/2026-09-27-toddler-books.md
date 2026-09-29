# Toddler books implementation

Goal: Ship prepared, offline listening editions of The Frog Prince and Колобок, with Qwen Plus narration and picture questions every three pages.
Spec: toddlerbooks.md; existing-book scope supersedes the proposed MiMi pilot.
Architecture: immutable bundled manifests, one testable listening state machine, route-local audio adapter, independent preferences namespace, Flutter player using existing visual language.
Stack: Flutter, audioplayers, SharedPreferences; Python developer-only OpenRouter generation.

Global constraints: Preserve reading mode and coin accounting. No secrets in assets or client. Keep existing work intact. Test in Flutter web, never MobAI. Preserve original attributions and endings. All child interactions work without reading. No live generation in app.
Visual thesis: original painted illustration occupies most of the reader; rounded purple controls and MiMi reactions frame it with quiet, warm whitespace. Picture answers are large, wordless, visibly tappable. Motion communicates speaking, selection and encouragement; honor reduced motion.

## Task 1: Content and generation
- [x] Write failing manifest contract tests.
- [x] Prepare 12 English and 9 Russian short pages linked to source pages, two questions per three pages, prompt/hint/guidance/feedback narration.
- [x] Reuse original Russian character pictures and create matching English answer art.
- [x] Implement a content-hashed generator with dry run, budget bound, atomic writes, caching, bounded retries and no key logging.
- [x] Generate all assets with the selected Qwen Plus female voice. Decode all; transcribe representative samples in both languages.
Expected: no missing assets, balanced correct positions, grounded questions, complete endings.

## Task 2: Listening engine
- [x] Write failing tests for completion gating, quiz recovery, persistence, independent progress and audio cancellation.
- [x] Implement injected audio interface, durable resume state, pause/background/exit handling, replay and auto/manual page turns.
Expected: stale audio cannot advance pages; answers unlock only after prompt; paused/reopened sessions remain paused; listening never earns reading coins.
Interfaces: manifest -> engine -> screen; preferences key littlewins.listening.v1 independent of AppController saves.

## Task 3: Player and entry points
- [x] Add illustrated player, large controls, captions/options, picture questions with MiMi feedback, completion sticker and replay.
- [x] Add listen actions to Home and both Library books; keep all read actions available.
- [x] Widget checks for controls, answer gating and compact layouts.
Expected: child flow never requires text answers; audio errors expose a retry; no reading regressions.

## Task 4: Verify and document
- [x] Run analyze and Flutter tests, build web, complete both books in browser with actual accelerated audio, revisit/resume/background and guided-answer checks.
- [x] Inspect screenshots at 320px, 430px and desktop plus reduced motion. Decode every MP3, check offline network behavior and secret exclusion.
- [x] Fresh final review per executing-plans skill; fix important issues with regression coverage.
- [x] Update toddlerbooks.md with implementation status and reproducible generation/testing commands.
Review focus: late player events, storage failures, browser autoplay/visibility, stale cached audio, resumed questions, small-screen image recognition, unchanged wallet and original story text.
