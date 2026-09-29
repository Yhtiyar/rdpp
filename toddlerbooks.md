# Toddler listening books

Current production guide · updated 28 September 2026

## Story text and page boundaries

Narrate the **exact, complete story text** supplied in `books/`. The books are already written for toddlers. Preserve vocabulary, dialogue, repetitions, verses and endings. Do not simplify, paraphrase, shorten, soften or add explanatory story sentences.

Exclude material that is not part of the spoken story: **“Chapter 1”, “1 часть”, “2 часть”, section numbers, page numbers, running headers, contents lists, credits, URLs and watermarks**. Identify these from the source layout; do not remove the same words when they occur inside a story sentence. Record exclusions in source preparation and retain the original PDF. Correct extraction errors only by checking that PDF.

The cleaned reading text is the narration source of truth. Joining listening parts must reproduce that text exactly, allowing layout-whitespace normalization. Captions use the identical script. Each part records source-page references and exact text offsets. Questions, hints and celebration lines are separate authored speech.

A listening **page is an audio part**, not a PDF page. Prefer **15–25 seconds at the actual playback speed (1.0× for Gemini Russian; 0.85× for Qwen English)**. Split or combine consecutive passages at natural sentence, dialogue or verse boundaries. Keep quotation marks, speech attributions, repeated sounds and complete verses together. Do not stop a checkpoint halfway through an utterance. A shorter passage or longer complete sentence is acceptable when necessary; do not pad or rewrite the story to meet a duration target. Measure generated audio instead of relying only on word counts. There is no fixed page-count cap.

Split collections such as `fables-list.pdf` into individual books. Keep each title’s source references, author/illustrator credits and license notices.

## Narration models

| Language | Model through OpenRouter | Voice | Delivery |
| --- | --- | --- | --- |
| English | `qwen/qwen-audio-3.0-tts-plus` | `longanlingxin` | Warm adult storyteller, 0.85× playback |
| Russian | `google/gemini-3.8-flash-lite-tts` | `Sulafat` | Warm, gentle storytelling, natural 1.0× playback |

**Use Gemini for all Russian speech:** narration, questions, hints, guided answers, feedback and completion. Rebuild the whole Russian edition with one consistent voice. Do not mix older Qwen clips into it. English retains Qwen.

Respect each edition's `playbackRate`. Gemini already supplies a gentle pace; slowing it again stretches the parts unnecessarily. Review timing and intonation at the actual configured speed.

Gemini supports Russian. Keep performance directions in `provider.options.google-ai-studio.speech_metadata.style`; never insert them into the spoken text. The chosen direction is `warm, gentle storytelling, clear natural pacing`. Avoid baby talk, whispering, shouting, sudden volume changes and invented vocalizations. [Google language and voice documentation](https://ai.google.dev/gemini-api/docs/speech-generation), [OpenRouter speech options](https://openrouter.ai/docs/guides/overview/multimodal/tts).

OpenRouter’s Gemini endpoint returns PCM; request `response_format: "pcm"` and encode the accepted 24 kHz, 16-bit mono output to MP3 locally. Do not rename raw PCM as MP3. Qwen can return MP3 directly. The app bundles MP3 files and makes no generation requests.

Prices checked on 28 September 2026: Qwen Plus is **$20 per million input characters**; Gemini Flash-Lite TTS is **$0.50 per million input tokens and $6 per million output audio tokens** at the current rate. These units differ. Our three Gemini narration auditions cost approximately $0.0031–$0.0045 each, close to Qwen for those same passages. Recheck provider pricing before a later production run. [Qwen pricing](https://openrouter.ai/qwen/qwen-audio-3.0-tts-plus), [Gemini pricing](https://ai.google.dev/gemini-api/docs/pricing#gemini-3.8-flash-lite-tts).

Generate a small audition before a new voice or delivery setting: dialogue, verse, a question, and a passage with challenging names. Check the **whole clip, especially its ending**, for pronunciation, word stress, unnatural intonation, repeated or missing words, spoken punctuation (“точка”), stray letters and unwanted sounds. Thirteen seconds alone is not evidence of the cause of a bad take. Regenerate or adjust delivery; preserve story wording.

Transcription comparison helps detect wording errors but does not certify pronunciation or warmth. Inspect flagged differences against the audio and source. Keep actual human listening feedback separate from automated review results.

## Book assets and authoring

Keep each book’s current media together:

```text
assets/books/
  catalog.json
  shared/fables_original.pdf
  <book-id>/
    art/                 # covers, story scenes, picture answers
    audio/               # current narration and question MP3s
    <original>.pdf
assets/toddler/
  catalog.json
  audio_manifest.json
content/verbatim-books/
  <book-id>.json          # exact scripts, evidence, voice profile, references
```

Reuse source illustrations where suitable and generate missing artwork in the same style. Do not duplicate identical art just because reading and listening both use it. Shared source PDFs live under `shared/`.

Remove superseded narration, unused art, auditions, temporary files and historical editions from the bundled asset directories after reference validation. Keep useful review/provenance records under `content/` or `docs/verification/`, outside Flutter assets. Do not delete a file referenced by a current edition. Declare every media subdirectory in `pubspec.yaml`.

The audio manifest records the request fingerprint, file hash, byte size, model, voice and format. Cache identity must change when the exact text, model, voice or delivery settings change. Never accept an old clip just because its filename exists. Use a new listening content version when scripts or part boundaries change; preserve reading progress and wallet balances.

For a repeatedly empty provider response or a lost repeated phrase, a clip may use reviewed `speechOverrides` with smaller synthesis `segments`. Joining those strings must equal the original script exactly. The generator joins their MP3 audio into the same app page, records each segment's generation metadata, and budgets every request. This does not change captions, part boundaries or checkpoint placement.

## Picture questions

Ask two questions after every three listening parts. A final single part gets one question; a final two-part group gets two. Questions must be answered by the passage just heard. Record a literal evidence quote and its part IDs.

Each question has exactly two clear pictures with semantic labels, one correct answer, and separate prompt, hint, guided-answer and feedback clips. Prefer recognizable characters, objects, simple actions and locations. Avoid abstract morals, negatives and facts outside the passage. Balance correct positions across the book and keep both choices stable during a question.

Use the story’s character designs at comparable scale and framing. A source crop is acceptable only when the subject remains unmistakable at phone size. Do not substitute emoji or generic icons for finished picture answers.

## Listening behavior

Open **Listen & play** from Home or the Library. The tap starts narration; a blocked or failed playback exposes a large retry control and must never silently advance. Resume saved sessions paused. Speech stays in the book’s language, even when the parent interface uses another language.

Show the illustration prominently with stable back, play/pause and replay controls, plus three progress marks for the current group. Optional captions are off by default. Previously heard parts can be revisited freely; unheard parts cannot be skipped on the first pass.

Every visit to a section's checkpoint must ask its picture questions again, even if answered on an earlier visit. Clear that checkpoint's earlier answers and assistance when starting it again. An interrupted question resumes in place, paused. Keep **Start from beginning / Начать сначала** in listening options throughout the story and games; it closes options, clears the current listening run, and starts the first part. Preserve earned story stars, listening preferences, other books, reading progress and wallet balances.

At narration end, hold the image briefly (about 1.2 seconds), then turn automatically. Pause cancels the pending turn. Manual-turn mode exposes Next only after narration finishes. Backgrounding or leaving the story stops audio; returning stays paused. Never overlap narration and question speech.

A question plays automatically and enables both choices only after its prompt finishes. First wrong answer: give a passage-based hint. Second wrong answer: explain and highlight the correct picture. The green picture must accept a tap immediately, even while guidance is speaking; stop that guidance, play the correct feedback once, then advance when it ends. Other choices wait until guidance finishes. Record assistance without punishment or lost rewards. Lock duplicate taps during feedback.

Finishing all required parts and checkpoints earns one durable story star. Offer replay or return to the shelf; do not automatically start another book. Listening does not award reading coins or modify wallet balances. Reading and listening progress remain separate.

## Visual quality and accessibility

Follow `emotional-design.md`. Use Duolingo’s care over illustration, animation and feedback as the quality reference while retaining littlewins’ MiMi character and palette. Keep one coherent art direction within each book, with stable faces, proportions, clothing and important props.

Review the complete illustration sequence and answer contact sheets. Reject broken anatomy, inconsistent characters, stray text, muddy details, cut-off subjects or ambiguous answers. Review the actual Flutter layouts at 320 px, 430 px and tablet widths. Use large touch targets, semantic labels and controls that remain reachable without scrolling.

Motion should direct attention without distracting from speech. Use existing motion timings and reduced-motion behavior. Pause decorative motion with narration; animation completion must never determine correctness or saved progress. Keep sound effects quieter than speech.

## Production and verification

1. Extract complete story text, exclude structural labels, and retain source credits/PDFs.
2. Segment exact passages, verify complete coverage and source offsets, and review natural checkpoint boundaries.
3. Author grounded picture questions and review all page/answer artwork.
4. Generate audio with the language-specific model. Decode every clip, measure duration, compare transcripts and review pronunciation/intonation, including endings.
5. Group media by book, verify all references and hashes, and remove superseded bundled assets.
6. Publish both catalogues only when every edition is complete. The merger rejects shortened scripts, invalid evidence, missing pictures and stale audio.
7. Run relevant Python/Dart checks, `flutter analyze`, and Flutter web journeys covering every book, all checkpoints, recovery, completion, narrow layouts and offline media. **Do not use MobAI.** Record what was actually verified.

Tooling lives in `tools/`: `segment_verbatim_books.py`, question-authoring scripts, `generate_toddler_audio.py`, `organize_book_assets.py`, `merge_book_catalogs.py` and `review_book_audio.py`. Source preparation must preserve accepted verbatim editions.

Generation reads the ignored root `.env` only in a developer process. Never copy credentials into Flutter assets, client code, logs or screenshots. Run a dry-run cost estimate first, enforce a spend ceiling and bounded retries, and write completed clips atomically. Gemini requests carry an output-token limit for cost control. Run only one generator at a time because the audio manifest is shared.
