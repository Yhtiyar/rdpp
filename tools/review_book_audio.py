#!/usr/bin/env python3
"""Transcribe prepared book audio for editorial review (developer-only).

Dry-run by default. --review sends existing audio to Qwen ASR via OpenRouter.
Transcripts diagnose missing/mispronounced words; they do not assess warmth.
"""
import argparse
import base64
from concurrent.futures import ThreadPoolExecutor, as_completed
from difflib import SequenceMatcher
import hashlib
import json
from pathlib import Path
import re

import requests
from generate_toddler_audio import ROOT, clips, read_key


def normalize(text):
    return ' '.join(re.findall(r'\w+', text.lower().replace('ё', 'е')))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--review', action='store_true')
    parser.add_argument('--all-clips', action='store_true')
    parser.add_argument('--narration-only', action='store_true')
    parser.add_argument('--catalog', type=Path, default=ROOT / 'assets/toddler/catalog.json')
    parser.add_argument('--model', default='qwen/qwen3-asr-1.7b')
    parser.add_argument('--output', type=Path, default=ROOT / 'docs/verification/new-books/transcriptions.json')
    parser.add_argument('--workers', type=int, choices=range(1, 9), default=4)
    args = parser.parse_args()
    books = json.loads(args.catalog.read_text())
    if isinstance(books, dict):
        books = [books]
    items = []
    for book in books:
        selected = [(p['audio'], p['text']) for p in book['pages']] if args.narration_only else list(clips([book])) if args.all_clips else [
            (book['pages'][0]['audio'], book['pages'][0]['text']),
            (book['pages'][-1]['audio'], book['pages'][-1]['text']),
            (book['questions'][0]['audio']['prompt'], book['questions'][0]['prompt']),
        ]
        items.extend((path, script, book['language']) for path, script in selected)
    target = args.output
    results = json.loads(target.read_text()) if target.exists() else []
    current = {path for path, _, _ in items}
    cache = {item['file']: item for item in results if item['file'] in current}
    pending = [(p, s, lang) for p, s, lang in items if not (
        cache.get(p, {}).get('sha256') == hashlib.sha256((ROOT / p).read_bytes()).hexdigest()
        and cache[p].get('status') == 200 and cache[p].get('script') == s
        and cache[p].get('model', 'qwen/qwen3-asr-1.7b') == args.model
    )]
    print(f'{len(pending)} clips need transcription; {len(items) - len(pending)} cached.')
    if not args.review or not pending:
        return
    key = read_key()

    def transcribe(item):
        path, script, language = item
        data = (ROOT / path).read_bytes()
        result = {'file': path, 'script': script, 'sha256': hashlib.sha256(data).hexdigest(), 'model': args.model}
        try:
            response = requests.post(
                'https://openrouter.ai/api/v1/audio/transcriptions',
                headers={'Authorization': 'Bearer ' + key},
                json={'model': args.model, 'language': language,
                      'input_audio': {'data': base64.b64encode(data).decode(), 'format': Path(path).suffix.lstrip('.')}},
                timeout=(15, 90),
            )
            result['status'] = response.status_code
            if response.ok:
                result['transcript'] = response.json().get('text', '')
                result['similarity'] = round(SequenceMatcher(None, normalize(script), normalize(result['transcript']), autojunk=False).ratio(), 4)
        except (requests.RequestException, ValueError):
            result['status'] = 'request-failed'
        return result

    target.parent.mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        for job in as_completed([pool.submit(transcribe, item) for item in pending]):
            result = job.result()
            cache[result['file']] = result
            target.write_text(json.dumps(list(cache.values()), ensure_ascii=False, indent=2) + '\n')
            print(f"{Path(result['file']).name}: {result.get('similarity', result['status'])}", flush=True)
    flagged = [result['file'] for result in cache.values() if result.get('similarity', 0) < .97]
    print(f'{len(flagged)} clips need closer review: {flagged}')


if __name__ == '__main__':
    main()
