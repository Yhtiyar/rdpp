# September 2026 book expansion

The new source files add sixteen independent titles to the original two-book
catalogue. The ten stories in `books/fables-list.pdf` are separate shelf entries;
they share the bundled original PDF and retain the collection's attribution,
illustrator credits and CC BY-NC-SA notices. Six Russian PDFs retain their source
files, authors and deti-online.com notices.

Each `*-reading.json` fragment contains the complete extracted story, source PDF
page numbers and authored quizzes. The accepted listening scripts live in
`content/verbatim-books/{id}.json` for all eighteen books, including `frog` and
`kolobok`. Version 2 preserves every source word in order, normalizing only layout
whitespace. Structural labels such as “Chapter 1” and “1 часть” are excluded
from the cleaned source before segmentation; story sentences remain intact.
Parts prefer 15–25 seconds at the reviewed playback speed (Russian 1.0×; English 0.85×), with
clean sentence boundaries taking precedence. Source offsets and page references
allow the complete text to be checked automatically. Questions are grounded in
the current group of three parts, including a final partial group.

The `*-listening.json` files in this directory are historical shortened drafts.
They are superseded and are never published by the merger. Extraction scripts
may rebuild those historical drafts, but cannot replace the accepted verbatim
editions. Reading progress and wallet balances retain their existing identities;
the listening version change resets incompatible old narration positions.

Russian speech uses Gemini Flash-Lite TTS (`google/gemini-3.8-flash-lite-tts`),
voice `Sulafat`, for narration and every question/recovery/completion clip.
English retains Qwen Plus, voice `longanlingxin`. Gemini PCM is encoded to MP3
locally. Request fingerprints include the model, voice and delivery style;
existing filenames never bypass validation. See `toddlerbooks.md` for the
current authoring and voice policy.

The three text-only PDFs (The Ugly Duckling, Teremok and The Frog Princess) use
newly generated painted story illustrations. Other stories reuse their supplied
artwork, with individually reviewed answer crops. Credits describe these origins;
the importer does not assert new redistribution permissions for source material.

## Rebuild

Install developer dependencies with `pip install -r tools/requirements-books.txt`.
Preparation scripts require Pillow, PyMuPDF, and
Poppler's `pdftotext` and `pdfimages` commands.
The source extraction scripts are deliberately separate from the merger and
audio service, so artwork preparation does not regenerate narration or call APIs.

```sh
python3 tools/prepare_fables_first.py
python3 tools/prepare_fables_last.py
python3 tools/prepare_russian_books.py
python3 tools/segment_verbatim_books.py

# Author/review questions and illustrations before publishing. Generate from
# an exact authoring file (or an array of them), dry-run first. Never run two
# generators concurrently because they share the audio manifest.
python3 tools/generate_toddler_audio.py --catalog content/verbatim-books/frog.json --max-cost 3
python3 tools/generate_toddler_audio.py --catalog content/verbatim-books/frog.json --generate --max-cost 3
python3 tools/merge_book_catalogs.py
```

The segmenter refuses to replace existing authored parts when boundaries change;
review resegmentation explicitly. The merger rejects missing questions, evidence
outside its checkpoint, shortened narration, missing artwork, and missing or stale
audio. It validates both complete catalogues before writing either. It also
measures artwork to preserve its proportions in the listening screen.
`tools/prepare_books.py` invokes the same merger, so rebuilding the first
two books keeps the expanded shelf. Generation tools read the developer's ignored
environment file; only local illustrations, catalogues and completed audio are
bundled into Flutter.

Verification commands and results are recorded in
`docs/verification/new-books/README.md`. Transcription is a diagnostic for spoken
wording; it does not replace a fluent listener's assessment of pronunciation and
warmth.

## Book media folders

Each book owns its media under `assets/books/{id}/`: illustrations and answer
pictures in `art/`, narration and question clips in `audio/`, and its original
PDF directly in the book folder. The English collection shares
`assets/books/shared/fables_original.pdf`. `assets/toddler/` contains only the
listening catalogue and audio manifest. Flutter lists every book's media
directories explicitly in `pubspec.yaml`.

Run `python3 tools/organize_book_assets.py` to preview the migration and add
`--apply` to perform it. Stop media generators first. The tool updates catalogue,
authoring and verification paths, preserves audio request/content hashes, and
refuses to overwrite differing destination files. Rerunning it is safe.

Unreferenced media moves to `/tmp/readapp-obsolete-toddler-assets`, outside the
Flutter bundle. The archive retains obsolete audio manifest entries, while
`content/book-asset-migration.json` records file destinations and checksums.
Published catalogue references remain protected until their replacement is
published; rerun the organizer after the final catalogue merge to archive those
retired clips too. Historical shortened drafts may refer to archived media and
are not executable listening catalogues.
