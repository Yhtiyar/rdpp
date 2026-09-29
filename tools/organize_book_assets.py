#!/usr/bin/env python3
"""Group book media and reversibly quarantine obsolete bundled files.

Dry run by default; pass --apply after generators have finished writing. Active
media includes both the published catalogues and authored exact editions, so a
second run after publishing can retire the previous listening edition safely.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil

ROOT = Path(__file__).resolve().parents[1]
EXCLUDED = {
    'tools/generate_toddler_audio.py', 'tools/merge_book_catalogs.py',
    'tools/review_book_audio.py', 'tools/organize_book_assets.py',
    'tools/tests/test_organize_book_assets.py', 'toddlerbooks.md',
    'content/book-asset-migration.json',
}
PATH_PATTERN = re.compile(r'assets/(?:books|toddler)/[A-Za-z0-9_./-]+')


def strings(value):
    if isinstance(value, dict):
        for key, item in value.items():
            yield str(key)
            yield from strings(item)
    elif isinstance(value, list):
        for item in value:
            yield from strings(item)
    elif isinstance(value, str):
        yield value


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def json_text(value):
    return json.dumps(value, ensure_ascii=False, indent=2) + '\n'


def organize(root=ROOT, archive=Path('/tmp/readapp-obsolete-toddler-assets'), *, apply=False):
    root, archive = Path(root).resolve(), Path(archive).resolve()
    if archive.is_relative_to(root / 'assets'):
        raise ValueError('The obsolete-media archive must be outside bundled assets')
    live_files = [root / 'assets/books/catalog.json', root / 'assets/toddler/catalog.json']
    live_files += sorted((root / 'content/verbatim-books').glob('*.json'))
    live_files += sorted((root / 'content/new-books').glob('*-reading.json'))
    documents = [json.loads(path.read_text()) for path in live_files if path.is_file()]
    books = [book for document in documents for book in (document if isinstance(document, list) else [document])]
    book_ids = sorted({book['id'] for book in books}, key=lambda value: (-len(value), value))

    def canonical(path):
        pure = Path(path)
        parts = pure.parts
        if path == 'assets/books/fables_original.pdf':
            return 'assets/books/shared/fables_original.pdf'
        flat_book = len(parts) == 3 and parts[:2] == ('assets', 'books')
        flat_toddler = len(parts) == 4 and parts[:2] == ('assets', 'toddler') and parts[2] in ('audio', 'art')
        if not (flat_book or flat_toddler):
            return path
        name = pure.name
        owner = next((bid for bid in book_ids if name.startswith((bid + '-', bid + '_'))), None)
        if owner is None:
            return path
        kind = '' if pure.suffix == '.pdf' else ('audio/' if pure.suffix == '.mp3' else 'art/')
        return f'assets/books/{owner}/{kind}{name}'

    def rewrite(text):
        def replace(match):
            # A sentence-ending full stop is not part of the filename.
            path = match.group().rstrip('.')
            return canonical(path) + match.group()[len(path):]
        return PATH_PATTERN.sub(replace, text)

    active = {canonical(match.group()) for document in documents for value in strings(document)
              for match in PATH_PATTERN.finditer(value)}
    manifest_path = root / 'assets/toddler/audio_manifest.json'
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    audit_path = root / 'content/book-asset-migration.json'
    audit = json.loads(audit_path.read_text()) if audit_path.exists() else {'version': 1, 'archive': str(archive), 'files': {}}
    archived_manifest_path = archive / 'audio_manifest.json'
    archived_manifest = json.loads(archived_manifest_path.read_text()) if archived_manifest_path.exists() else {}
    moves = []
    keep_audio = set()
    for folder in (root / 'assets/books', root / 'assets/toddler'):
        for source in sorted(folder.rglob('*')):
            if not source.is_file() or source.suffix not in ('.webp', '.png', '.jpg', '.jpeg', '.mp3', '.pdf'):
                continue
            old = source.relative_to(root).as_posix()
            grouped = canonical(old)
            if grouped == old and not (len(source.relative_to(root).parts) >= 4 and old.startswith('assets/books/')):
                raise ValueError(f'Cannot determine a book for {old}')
            obsolete = grouped not in active
            target = archive / old if obsolete else root / grouped
            if source == target:
                if source.suffix == '.mp3':
                    keep_audio.add(grouped)
                continue
            checksum = digest(source)
            if target.exists() and digest(target) != checksum:
                raise ValueError(f'Conflicting destination: {target}')
            moves.append((source, target, old, grouped, obsolete, checksum))
            if source.suffix == '.mp3' and not obsolete:
                keep_audio.add(grouped)

    new_manifest = {}
    for path, metadata in manifest.items():
        grouped = canonical(path)
        destination = new_manifest if grouped in keep_audio else archived_manifest
        key = grouped if destination is new_manifest else path
        if key in destination and destination[key] != metadata:
            raise ValueError(f'Conflicting manifest entry: {key}')
        destination[key] = metadata

    rewrites = {}
    text_files = [root / 'README.md']
    for directory in ('content', 'lib', 'test', 'tools', 'docs'):
        text_files.extend(path for path in (root / directory).rglob('*') if path.suffix in ('.json', '.md', '.dart', '.py', '.cjs', '.js', '.yaml', '.yml'))
    text_files += [root / 'assets/books/catalog.json', root / 'assets/toddler/catalog.json']
    for path in text_files:
        if not path.is_file() or path.relative_to(root).as_posix() in EXCLUDED:
            continue
        text = path.read_text()
        updated = rewrite(text)
        if text != updated:
            rewrites[path] = updated
    manifest_text = json_text(new_manifest)
    if not manifest_path.exists() or manifest_path.read_text() != manifest_text:
        rewrites[manifest_path] = manifest_text
    pubspec = root / 'pubspec.yaml'
    if pubspec.is_file():
        text = pubspec.read_text()
        lines = text.splitlines()
        prefix = '    - assets/books/'
        positions = [i for i, line in enumerate(lines) if line.startswith(prefix)]
        insert = positions[0] if positions else next((i for i, line in enumerate(lines) if line.strip() == 'assets:'), 0) + 1
        lines = [line for line in lines if not line.startswith(prefix) and line not in ('    - assets/toddler/audio/', '    - assets/toddler/art/')]
        grouped_lines = [prefix, prefix + 'shared/']
        for book_id in sorted(book_ids):
            grouped_lines += [prefix + book_id + '/', prefix + book_id + '/art/', prefix + book_id + '/audio/']
        lines[insert:insert] = grouped_lines
        updated = '\n'.join(lines) + '\n'
        if text != updated:
            rewrites[pubspec] = updated
    summary = {'moves': len(moves), 'quarantined': sum(move[4] for move in moves), 'rewrites': len(rewrites), 'books': len(book_ids)}
    if not apply:
        return summary
    # All destination conflicts are checked before modifying media or metadata.
    for source, target, old, grouped, obsolete, checksum in moves:
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.exists():
            source.unlink()  # Identical bytes already exist at the destination.
        else:
            shutil.move(str(source), str(target))
        audit['files'][old] = {'path': str(target) if obsolete else grouped, 'canonicalPath': grouped,
                               'archived': obsolete, 'sha256': checksum, 'bytes': target.stat().st_size}
    for book_id in book_ids:
        for kind in ('art', 'audio'):
            (root / 'assets/books' / book_id / kind).mkdir(parents=True, exist_ok=True)
    (root / 'assets/books/shared').mkdir(parents=True, exist_ok=True)
    for path, text in rewrites.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        temp = path.with_name(path.name + '.organize-tmp')
        temp.write_text(text)
        temp.replace(path)
    for directory in (root / 'assets/toddler/audio', root / 'assets/toddler/art'):
        if directory.exists() and not any(directory.iterdir()):
            directory.rmdir()
    if moves:
        audit_path.parent.mkdir(parents=True, exist_ok=True)
        audit_path.write_text(json_text(audit))
        archive.mkdir(parents=True, exist_ok=True)
        archived_manifest_path.write_text(json_text(archived_manifest))
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true', help='Apply the reviewed move plan')
    parser.add_argument('--archive', type=Path, default=Path('/tmp/readapp-obsolete-toddler-assets'))
    args = parser.parse_args()
    print(json_text(organize(archive=args.archive, apply=args.apply)), end='')


if __name__ == '__main__':
    main()
