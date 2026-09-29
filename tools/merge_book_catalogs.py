#!/usr/bin/env python3
"""Merge the authored source groups into the bundled catalogues.

Reading editions retain their IDs. Listening editions must preserve their entire
source text. Validate every package before publishing either catalogue.
"""
import json
import re
from pathlib import Path
import shutil

from PIL import Image
from generate_toddler_audio import cached, requests_for
from segment_verbatim_books import canonical_text

ROOT = Path(__file__).resolve().parents[1]
GROUPS = ('fables-first', 'fables-last', 'russian')


def validate_verbatim(book, reading):
    for page in reading['pages']:
        if re.search(r'(?im)^\s*(?:chapter\s+[\divxlcdm]+|\d+\s+часть|глава\s+[\divxlcdm]+)\s*$', page['text']):
            raise ValueError(f"{book['id']}: exclude structural section headings before narration")
    source, _ = canonical_text(reading)
    pages, questions = book['pages'], book['questions']
    if book.get('version', 0) < 2 or book.get('textPolicy') != 'verbatim':
        raise ValueError(f"{book['id']}: a versioned verbatim edition is required")
    if not pages or ' '.join(page['text'] for page in pages) != source:
        raise ValueError(f"{book['id']}: narration must equal the complete source text")
    cursor = 0
    for page in pages:
        while source[cursor:cursor + 1].isspace():
            cursor += 1
        end = cursor + len(page['text'])
        if (page['sourceTextStart'], page['sourceTextEnd']) != (cursor, end):
            raise ValueError(f"{page['id']}: invalid source offsets")
        cursor = end
    expected = [min(start + 3, len(pages)) - 1
                for start in range(0, len(pages), 3)
                for _ in range(1 if len(pages) - start == 1 else 2)]
    if [q['afterPage'] for q in questions] != expected:
        raise ValueError(f"{book['id']}: incomplete listening checkpoints")
    for index, q in enumerate(questions):
        group = pages[q['afterPage'] // 3 * 3:q['afterPage'] + 1]
        passage = ' '.join(page['text'] for page in group)
        evidence = q.get('evidence', {})
        if (not evidence.get('quote') or evidence['quote'] not in passage
                or not evidence.get('pageIds')
                or not set(evidence['pageIds']) <= {page['id'] for page in group}):
            raise ValueError(f"{q['id']}: evidence must belong to its current passage")
        choices = q['choices']
        if (len(choices) != 2 or q['answer'] != index % 2
                or len({(c['image'], c.get('cell')) for c in choices}) != 2):
            raise ValueError(f"{q['id']}: invalid or unbalanced picture choices")


def merge_catalogs(reading_editions=()):
    source = ROOT / 'content/new-books'
    reading_target = ROOT / 'assets/books/catalog.json'
    by_id = {book['id']: book for book in json.loads(reading_target.read_text())}
    by_id.update((book['id'], book) for book in reading_editions)
    for group in GROUPS:
        for book in json.loads((source / f'{group}-reading.json').read_text()):
            if book['id'] in ('frog', 'kolobok'):
                raise ValueError('New source groups cannot replace original reading editions')
            by_id[book['id']] = book
    listening = []
    manifest = json.loads((ROOT / 'assets/toddler/audio_manifest.json').read_text())
    for reading in by_id.values():
        path = ROOT / 'content/verbatim-books' / f"{reading['id']}.json"
        book = json.loads(path.read_text())
        validate_verbatim(book, reading)
        for page in book['pages']:
            with Image.open(ROOT / page['image']) as image:
                page['imageAspectRatio'] = round(image.width / image.height, 5)
        for audio_path, body in requests_for([book]):
            if not cached(ROOT / audio_path, body, manifest.get(audio_path, {})):
                raise ValueError(f'Missing or stale audio: {audio_path}')
        listening.append(book)
    prepared = [(reading_target, list(by_id.values())),
                (ROOT / 'assets/toddler/catalog.json', listening)]
    for target, books in prepared:
        for book in books:
            images = [book['cover'], *[page['image'] for page in book['pages'] if page.get('image')]]
            if target.parent.name == 'toddler':
                images.extend(choice['image'] for question in book['questions'] for choice in question['choices'])
            for image_path in images:
                if not (ROOT / image_path).is_file():
                    raise ValueError(f"Missing artwork for {book['id']}: {image_path}")
    # Validate both catalogues before replacing either; an unfinished art job must
    # not publish reading entries whose listening editions cannot open yet.
    for target, books in prepared:
        temp = target.with_suffix('.tmp')
        temp.write_text(json.dumps(books, ensure_ascii=False, indent=2) + '\n')
        temp.replace(target)
        print(f'{target.parent.name}: {len(books)} books')
    if (source / 'fables-first-reading.json').exists():
        shared = ROOT / 'assets/books/shared'
        shared.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / 'books/fables-list.pdf', shared / 'fables_original.pdf')


if __name__ == '__main__':
    merge_catalogs()
