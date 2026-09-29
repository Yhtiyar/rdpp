#!/usr/bin/env python3
"""Prepare exact-text listening parts for editorial question authoring.

Whitespace is normalized once; source words, punctuation and order are retained.
Durations are estimates from reviewed Qwen clips at the app's 0.85x speed. Final
audio is measured separately, and clean-boundary duration exceptions reviewed.
"""
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
CHARACTERS_PER_SECOND = {'en': 12.63, 'ru': 11.21}


def canonical_text(book):
    text, spans = '', []
    for index, page in enumerate(book['pages']):
        if text:
            text += ' '
        start = len(text)
        text += ' '.join(page['text'].split())
        spans.append((start, len(text), index, page))
    return text, spans


def sentence_boundaries(text):
    """Keep quoted speech, sound effects and their attributions together.

    Match complete quotation pairs rather than carrying an open-quote state:
    a missing closing mark in a supplied book must not swallow later passages.
    """
    quotes = [(match.start(), match.end()) for match in re.finditer(
        r'«[^«»]*»|“[^“”]*”|"[^"\n]*"', text)]
    ends = {0, len(text)}
    for match in re.finditer(r'[.!?…][»”"\']*(?=\s|$)', text):
        end = match.end()
        if any(start < end < stop for start, stop in quotes):
            continue
        # A lowercase continuation includes both "asked the king" and
        # Russian "— сказала утка", as well as repeated "swack! swack!".
        following = text[end:].lstrip()
        if re.match(r'(?:[—–-]\s*)?[a-zа-яё]', following):
            continue
        if re.search(r'\b(?:Mr|Mrs|Ms|Dr|St)\.$', text[:end]):
            continue
        if following.startswith('.'):
            continue
        ends.add(end)
    return sorted(ends)


def segment(book):
    text, spans = canonical_text(book)
    ends = sentence_boundaries(text)
    rate = CHARACTERS_PER_SECOND[book['language']]
    target = 20 * rate
    cost, previous = [float('inf')] * len(ends), [0] * len(ends)
    cost[0] = 0
    for right in range(1, len(ends)):
        for left in range(right - 1, -1, -1):
            length = len(text[ends[left]:ends[right]].strip())
            seconds = length / rate
            penalty = ((length - target) / target) ** 2 + .1
            if seconds < 15:
                penalty += ((15 - seconds) / 10) ** 2
            if seconds > 25:
                penalty += ((seconds - 25) / 8) ** 2
            candidate = cost[left] + penalty
            if candidate < cost[right]:
                cost[right], previous[right] = candidate, left
            if length > 50 * rate and left < right - 1:
                break
    boundaries, cursor = [], len(ends) - 1
    while cursor:
        left = previous[cursor]
        boundaries.append((ends[left], ends[cursor]))
        cursor = left
    pages = []
    for number, (start, end) in enumerate(reversed(boundaries), 1):
        while text[start:start + 1].isspace():
            start += 1
        covered = [span for span in spans if span[0] < end and span[1] > start]
        dominant = max(covered, key=lambda span: min(end, span[1]) - max(start, span[0]))
        identifier = f"{book['id']}-part-{number:03d}"
        pages.append(dict(id=identifier, text=text[start:end], image=dominant[3]['image'],
                          sourcePages=list(dict.fromkeys(span[3]['sourcePage'] for span in covered)),
                          sourceReadingPages=[span[2] for span in covered],
                          sourceTextStart=start, sourceTextEnd=end,
                          estimatedPlaybackSeconds=round((end - start) / rate, 2),
                          audio=f"assets/books/{book['id']}/audio/{identifier}.mp3"))
    assert ' '.join(page['text'] for page in pages) == text
    return pages


def main():
    reading = {book['id']: book for book in json.loads((ROOT / 'assets/books/catalog.json').read_text())}
    for path in sorted((ROOT / 'content/new-books').glob('*-reading.json')):
        reading.update((book['id'], book) for book in json.loads(path.read_text()))
    old = {book['id']: book for book in json.loads((ROOT / 'assets/toddler/catalog.json').read_text())}
    for path in sorted((ROOT / 'content/new-books').glob('*-listening.json')):
        old.update((book['id'], book) for book in json.loads(path.read_text()))
    output = ROOT / 'content/verbatim-books'
    output.mkdir(parents=True, exist_ok=True)
    for book in reading.values():
        edition = dict(old[book['id']])
        edition.update(version=2, pages=segment(book), questions=[],
                       model=('google/gemini-3.8-flash-lite-tts' if book['language'] == 'ru'
                              else 'qwen/qwen-audio-3.0-tts-plus'),
                       voice='Sulafat' if book['language'] == 'ru' else 'longanlingxin',
                       adaptationNote=('Complete original book text, split into listening parts without rewriting.'
                                       if book['language'] == 'en' else
                                       'Полный оригинальный текст книги, разделённый на части для прослушивания без пересказа.'),
                       textPolicy='verbatim', playbackRate=1.0 if book['language'] == 'ru' else .85)
        path = output / (book['id'] + '.json')
        # A fresh segmentation must never silently overwrite authored questions.
        if path.exists():
            existing = json.loads(path.read_text())
            if existing['pages'] != edition['pages']:
                raise ValueError(f'Segmentation changed for authored edition {book["id"]}; review before replacing it')
            continue
        path.write_text(json.dumps(edition, ensure_ascii=False, indent=2) + '\n')
        durations = [page['estimatedPlaybackSeconds'] for page in edition['pages']]
        print(book['id'], len(edition['pages']), 'parts;', sum(15 <= seconds <= 25 for seconds in durations),
              'within target; estimated range', min(durations), max(durations))


if __name__ == '__main__':
    main()
