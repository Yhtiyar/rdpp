#!/usr/bin/env python3
"""Build prepared narration: Qwen for English, Gemini for Russian.

python3 tools/generate_toddler_audio.py --generate --max-cost 1
Requires requests. Reads OPENROUTERAPIKEY or OPENROUTER_API_KEY from env/.env.
Dry-run by default. Gemini returns PCM and is encoded locally to bundled MP3.
The spend ceiling includes bounded retries and a Gemini output-token limit.
"""
import argparse
from concurrent.futures import CancelledError, ThreadPoolExecutor, as_completed
import hashlib
import json
import math
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from threading import Event
import time
import requests

ROOT = Path(__file__).resolve().parents[1]
MODEL = 'qwen/qwen-audio-3.0-tts-plus'
VOICE = 'longanlingxin'
RATE = 20 / 1_000_000
MODEL_RATES = {MODEL: RATE}
GEMINI_MODEL = 'google/gemini-3.8-flash-lite-tts'
GEMINI_VOICE = 'Sulafat'
GEMINI_STYLE = 'warm, gentle storytelling, clear natural pacing'
ATTEMPTS = 3


class FatalAudioError(ValueError):
    """A safe local diagnostic for an account/configuration rejection."""


def request_body(text, book=None, overrides=None):
    profile = book or {}
    body = {'model': profile.get('model', MODEL), 'voice': profile.get('voice', VOICE),
            'input': text, 'response_format': 'mp3'}
    if profile.get('providerOptions'):
        body['provider'] = {'options': profile['providerOptions']}
    if body['model'] == GEMINI_MODEL:
        body['response_format'] = 'pcm'
        # Google generationConfig options are passed through separately from
        # the exact transcript. A generous limit bounds cost without clipping
        # normal 15–25 second narration (25 output tokens per audio second).
        limit = (overrides or {}).get('maxOutputTokens', min(7372, max(256, len(text) * 5 + 128)))
        if not isinstance(limit, int) or not 256 <= limit <= 7372:
            raise ValueError('Gemini output limit must be between 256 and 7372')
        body['provider'] = {'options': {'google-ai-studio': {
            'speech_metadata': {'style': GEMINI_STYLE},
            'maxOutputTokens': limit,
        }}}
    segments = (overrides or {}).get('segments')
    if segments is not None:
        if (not isinstance(segments, list) or not 2 <= len(segments) <= 8
                or any(not isinstance(s, str) or not s.strip() for s in segments)
                or ' '.join(segments) != text):
            raise ValueError('Speech segments must reproduce the exact complete script')
        body['_segments'] = segments
    return body


def segment_requests(body):
    return [{**{k: v for k, v in body.items() if k != '_segments'}, 'input': segment}
            for segment in body.get('_segments', [body['input']])]


def bytes_hash(data):
    return hashlib.sha256(data).hexdigest()


def fingerprint(body):
    return bytes_hash(json.dumps(body, sort_keys=True, ensure_ascii=False).encode())


def validate_mp3(data, content_type):
    if 'audio/' not in content_type or len(data) < 256 or not (data.startswith(b'ID3') or (data[0] == 255 and data[1] & 224 == 224)):
        raise ValueError('Response is not a complete MP3 audio payload')


def cached(path, body, entry):
    return path.is_file() and entry.get('requestHash') == fingerprint(body) and entry.get('sha256') == bytes_hash(path.read_bytes())


def check_budget(bodies, cap, attempts=ATTEMPTS):
    if not math.isfinite(cap) or cap < 0:
        raise ValueError('Spend ceiling must be a finite, nonnegative amount')
    cost = 0
    for body in [part for body in bodies for part in segment_requests(body)]:
        if body['model'] == GEMINI_MODEL:
            limit = body['provider']['options']['google-ai-studio']['maxOutputTokens']
            # Conservative UTF-8 byte bound for input tokens plus metadata.
            cost += (len(body['input'].encode()) + len(GEMINI_STYLE) + 256) * .0000005
            cost += limit * .000006
        elif body['model'] in MODEL_RATES:
            cost += len(body['input']) * MODEL_RATES[body['model']]
        else:
            raise ValueError('Verify pricing before generating with a new speech model')
    cost *= attempts
    if cost > cap:
        raise ValueError(f'Estimated maximum ${cost:.4f} including retries exceeds cap ${cap:.2f}')
    return cost


def clips(books):
    for book in books:
        for page in book['pages']:
            yield page['audio'], page['text']
        for q in book['questions']:
            for kind, path in q['audio'].items():
                yield path, q[kind]
        yield book['completion']['audio'], book['completion']['text']


def requests_for(books):
    for book in books:
        for path, text in clips([book]):
            yield path, request_body(text, book, book.get('speechOverrides', {}).get(path))


def read_key():
    env = dict(os.environ)
    path = ROOT / '.env'
    if path.exists():
        for line in path.read_text().splitlines():
            if '=' in line and not line.lstrip().startswith('#'):
                k, v = line.split('=', 1)
                env.setdefault(k.strip(), v.strip().strip('\"\''))
    key = env.get('OPENROUTERAPIKEY') or env.get('OPENROUTER_API_KEY')
    if not key:
        raise ValueError('Set OPENROUTERAPIKEY in .env; it is never printed or bundled')
    return key


def encoder_binary():
    binary = shutil.which('ffmpeg')
    if not binary:
        try:
            import imageio_ffmpeg
            binary = imageio_ffmpeg.get_ffmpeg_exe()
        except ImportError as error:
            raise ValueError('Install ffmpeg or imageio-ffmpeg to encode Gemini audio') from error
    subprocess.run([binary, '-version'], capture_output=True, check=True)
    return binary


def mp3_payload(data, content_type, body):
    if body['response_format'] == 'mp3':
        validate_mp3(data, content_type)
        return data
    if 'audio/' not in content_type or len(data) < 2400 or len(data) % 2:
        raise ValueError('Response is not complete PCM audio')
    binary = encoder_binary()
    source = ['-f', 'wav'] if data.startswith(b'RIFF') else ['-f', 's16le', '-ar', '24000', '-ac', '1']
    result = subprocess.run([binary, '-hide_banner', '-loglevel', 'error',
                             *source, '-i', 'pipe:0', '-codec:a', 'libmp3lame',
                             '-b:a', '96k', '-f', 'mp3', 'pipe:1'],
                            input=data, capture_output=True, check=True)
    validate_mp3(result.stdout, 'audio/mpeg')
    return result.stdout


def generate_one(path, body, key):
    if '_segments' in body:
        # Preserve exact repeated phrases or recover an empty provider response
        # without changing the app's page boundary or the story wording.
        with tempfile.TemporaryDirectory(prefix='readapp-speech-') as directory:
            folder = Path(directory)
            metadata = [generate_one(folder / f'{n}.mp3', part, key)
                        for n, part in enumerate(segment_requests(body))]
            listing = folder / 'clips.txt'
            listing.write_text(''.join(f"file '{n}.mp3'\n" for n in range(len(metadata))))
            result = subprocess.run([encoder_binary(), '-hide_banner', '-loglevel', 'error',
                                     '-f', 'concat', '-safe', '0', '-i', str(listing),
                                     '-c', 'copy', '-f', 'mp3', 'pipe:1'],
                                    capture_output=True, check=True)
            data = result.stdout
            validate_mp3(data, 'audio/mpeg')
            target = ROOT / path
            target.parent.mkdir(parents=True, exist_ok=True)
            temp = target.with_suffix('.tmp')
            temp.write_bytes(data)
            temp.replace(target)
            return {'requestHash': fingerprint(body), 'sha256': bytes_hash(data),
                    'bytes': len(data), 'characters': len(body['input']),
                    'model': body['model'], 'voice': body['voice'], 'format': 'mp3',
                    'sourceFormat': body['response_format'], 'segments': metadata}
    for attempt in range(ATTEMPTS):
        try:
            r = requests.post('https://openrouter.ai/api/v1/audio/speech', headers={'Authorization': 'Bearer ' + key}, json=body, timeout=(15, 90))
            if r.status_code in (401, 402, 403, 400):
                raise FatalAudioError(f'Audio request rejected: HTTP {r.status_code}')
            if not r.ok:
                raise requests.RequestException(f'HTTP {r.status_code}')
            data = mp3_payload(r.content, r.headers.get('Content-Type', ''), body)
            target = ROOT / path
            target.parent.mkdir(parents=True, exist_ok=True)
            temp = target.with_suffix('.tmp')
            temp.write_bytes(data)
            temp.replace(target)
            return {'requestHash': fingerprint(body), 'sha256': bytes_hash(data), 'bytes': len(data), 'characters': len(body['input']), 'model': body['model'], 'voice': body['voice'], 'format': 'mp3', 'sourceFormat': body['response_format'], 'generationId': r.headers.get('X-Generation-Id')}
        except requests.RequestException:
            if attempt == ATTEMPTS - 1:
                raise ValueError('Audio request failed after bounded retries') from None
            time.sleep(2 ** attempt)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--generate', action='store_true')
    parser.add_argument('--max-cost', type=float, default=1.0)
    parser.add_argument('--catalog', type=Path, default=ROOT / 'assets/toddler/catalog.json',
                        help='Bundled catalogue or an authored listening fragment')
    parser.add_argument('--book', help='Generate one book ID from the selected catalogue')
    parser.add_argument('--workers', type=int, choices=range(1, 7), default=3)
    args = parser.parse_args()
    books = json.loads(args.catalog.read_text())
    if isinstance(books, dict):
        books = [books]
    if args.book:
        if args.book not in [book['id'] for book in books]:
            parser.error(f'Unknown book ID: {args.book}')
        books = [b for b in books if b['id'] == args.book]
    manifest_path = ROOT / 'assets/toddler/audio_manifest.json'
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    pending = [(path, body) for path, body in requests_for(books)
               if not cached(ROOT / path, body, manifest.get(path, {}))]
    cost = check_budget([body for _, body in pending], args.max_cost)
    print(f'{len(pending)} clips to generate; estimated base ${cost / ATTEMPTS:.4f}; maximum with retries ${cost:.4f}', flush=True)
    if not args.generate or not pending:
        return
    key = read_key()
    if any(body['response_format'] == 'pcm' or '_segments' in body for _, body in pending):
        encoder_binary()  # Fail before any paid request if encoding is unavailable.
    failures = []
    aborted = Event()

    def generate_pending(path, body):
        if aborted.is_set():
            raise CancelledError()
        try:
            return generate_one(path, body, key)
        except FatalAudioError:
            aborted.set()
            raise

    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        jobs = {pool.submit(generate_pending, path, body): path for path, body in pending}
        for job in as_completed(jobs):
            path = jobs[job]
            if job.cancelled():
                failures.append(path)
                continue
            try:
                manifest[path] = job.result()
                temp = manifest_path.with_suffix('.tmp')
                temp.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
                temp.replace(manifest_path)
                print(f'Ready: {Path(path).name}', flush=True)
            except CancelledError:
                failures.append(path)
            except Exception as error:
                # Never echo upstream bodies, request objects or authentication.
                failures.append(path)
                diagnostic = str(error) if isinstance(error, FatalAudioError) else type(error).__name__
                print(f'Failed: {Path(path).name} ({diagnostic})', flush=True)
                if isinstance(error, FatalAudioError):
                    for queued in jobs:
                        queued.cancel()
    if failures:
        raise SystemExit(f'{len(failures)} clips failed. Rerun to retry only missing/stale files.')

if __name__ == '__main__':
    main()
