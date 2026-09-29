# Complete book editions · 28 September 2026

The app contains 18 reading and listening editions: 11 English and 7 Russian.
The ten fables are separate books. There are 164 reading pages, 258 narration
parts, 179 picture questions and 992 bundled speech clips.

Listening version 2 reproduces the complete cleaned source story, including
repetitions and endings. Layout whitespace is normalized. Structural labels
such as Айболит’s numbered parts are excluded before segmentation. Source
PDFs, credits, page references and text offsets are retained. Reading progress
and the coin ledger keep their existing identities.

## Narration and media

All 635 Russian clips use Gemini Flash-Lite TTS / Sulafat, including questions,
hints, guided answers, feedback and completion. English retains Qwen Plus /
longanlingxin. Actual browser playback rates were observed as Russian 1.0× and
English 0.85× (`playback-rates.json`). Gemini’s naturally gentle pace is not
slowed again.

`narration-durations.json` measures every part at its configured speed:
237 of 258 fall within 15–25 seconds; the remaining complete passages range
from 12.696 to 31.056 seconds. No story is shortened to meet a duration target.
Four clips use exact smaller synthesis segments joined into their original
page: two provider empty-stream failures and two repeated phrases that needed
separate generation. The manifest records their component generations.

Every book owns `assets/books/<id>/art/` and `audio/`, plus its source PDF.
The collection PDF is under `assets/books/shared/`. `assets/toddler/` contains
only `catalog.json` and `audio_manifest.json`. The set of 992 MP3 files exactly
equals both the current catalogue references and manifest keys. No old
`*-page-*` or two-digit `*-question-*` recordings remain. Колобок contains
44 current Gemini clips; its 33 superseded clips were removed.

Obsolete media is outside the project bundle at
`/tmp/readapp-obsolete-toddler-assets`; checksums and destinations are recorded
in `content/book-asset-migration.json`. A final organizer dry run reports zero
moves, zero quarantines and zero rewrites. Current source and web-bundle bytes
match for all 1,262 book files. The developer API key is absent from the build.

## Wording and artwork review

`independent-transcriptions.json` contains a successful Whisper transcription
for each of the 992 final audio hashes and scripts. 981 meet the 0.97 similarity
threshold. Every remaining low-score clip has a second ASR result for the same
bytes in `flagged-second-transcriptions.json`; `transcript-flags.json` records
the comparisons. Some apparent inserted sign-offs occur only in Whisper’s
transcript and are absent from the independent result. Orthography and
inflection also produce disagreements. These automated diagnostics do not
certify pronunciation, stress or vocal warmth; no fluent human review of the
entire catalogue is claimed.

The generated Frog Princess, Ugly Duckling and Teremok scenes and answer art
were visually reviewed in contact sheets and in Flutter. Additional scenes
match the longer exact passages, including the Frog Princess’s blue starry
ball gown. Existing source art is retained where suitable. Provenance is under
`content/new-books/*-art.json`.

## Checks

- Flutter: 86 tests pass; the final content checks also pass after question retakes.
- Python: 23 tests pass for exact-source coverage, evidence/checkpoints,
  asset migration, audio identity, bounded spending, encoder preflight,
  segmented requests and fatal-request cancellation.
- `flutter analyze --no-pub`: no issues.
- `flutter build web --no-web-resources-cdn --no-pub`: succeeds.
- `library-reading.json`: all 18 shelf entries; each of the 16 new reading
  editions completes its first batch, all four quiz questions, and exact coin credit.
- `recovery-check.json`: blocked autoplay/retry, reduced motion, hidden-tab
  pause, paused return, captions/manual turns, rapid replay and close.

Browser journeys use the release Flutter web build at 320 px and 430 px;
library captures also cover 1365 px. Real MP3 playback is accelerated to 8×
for complete journeys, and the test waits for native audio-end events.
External network requests are blocked. These are browser tests, not native
Android/iOS testing or a claim of PWA availability without its hosting server.

All 18 full listening journeys passed: 258 parts, 179 questions and 652 real
audio-end events, with zero browser errors or external requests. Results are
recorded in `journeys.json`; `audio-decode.json` records complete audio decoding.
Each journey covers every narration part and question,
wrong-answer hints and guided recovery, completion, a saved star and unchanged
reading balances. All 992 MP3 files decode completely and pass the non-silence and clipping
checks. The decoder records actual playback durations for every file.

## Reproduce

```sh
pip install -r tools/requirements-books.txt
python3 -m unittest tools.tests.test_toddler_audio tools.tests.test_verbatim_books tools.tests.test_organize_book_assets
python3 tools/generate_toddler_audio.py
python3 tools/organize_book_assets.py
flutter analyze --no-pub
flutter test --no-pub
flutter build web --no-web-resources-cdn --no-pub
python3 -m http.server 7359 --bind 127.0.0.1 --directory build/web
```

With Playwright installed, in another terminal:

```sh
APP_URL=http://127.0.0.1:7359 node tools/new_books_web_check.cjs
APP_URL=http://127.0.0.1:7359 node tools/new_library_web_check.cjs
APP_URL=http://127.0.0.1:7359 RECOVERY_OUTPUT_DIR=docs/verification/new-books node tools/toddler_recovery_web_check.cjs
```

Generation and paid transcription are explicit developer-only operations;
see `toddlerbooks.md`. The original two-book reports under `toddler-books/`
are historical and do not describe the current narration.
