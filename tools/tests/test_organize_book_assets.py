import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).parents[1]))
from organize_book_assets import organize


class OrganizeBookAssetsTest(unittest.TestCase):
    def test_migration_preserves_manifest_hashes_and_is_idempotent(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder) / 'repo'
            archive = Path(folder) / 'archive'
            def write(name, data):
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(json.dumps(data) if isinstance(data, (list, dict)) else data)
            book = {'id': 'frog-princess', 'cover': 'assets/books/frog-princess_01.webp',
                    'pages': [{'image': 'assets/books/frog-princess_01.webp',
                               'audio': 'assets/toddler/audio/frog-princess-part-001.mp3'}]}
            write('assets/books/catalog.json', [book])
            write('assets/toddler/catalog.json', [book])
            write('content/verbatim-books/frog-princess.json', book)
            write('content/verbatim-books/frog.json', {'id': 'frog', 'pages': []})
            write('assets/books/frog-princess_01.webp', 'picture')
            write('assets/toddler/audio/frog-princess-part-001.mp3', 'sound')
            write('assets/toddler/audio/frog-princess-page-01.mp3', 'obsolete')
            metadata = {'requestHash': 'unchanged', 'sha256': hashlib.sha256(b'sound').hexdigest()}
            write('assets/toddler/audio_manifest.json', {
                'assets/toddler/audio/frog-princess-part-001.mp3': metadata,
                'assets/toddler/audio/frog-princess-page-01.mp3': {'requestHash': 'old'},
            })
            write('pubspec.yaml', 'flutter:\n  assets:\n    - assets/books/\n    - assets/toddler/\n    - assets/toddler/audio/\n    - assets/toddler/art/\n')
            before = (root / 'assets/books/catalog.json').read_bytes()
            preview = organize(root, archive, apply=False)
            self.assertEqual((root / 'assets/books/catalog.json').read_bytes(), before)
            self.assertGreater(preview['moves'], 0)
            organize(root, archive, apply=True)
            self.assertEqual((root / 'assets/books/frog-princess/audio/frog-princess-part-001.mp3').read_text(), 'sound')
            manifest = json.loads((root / 'assets/toddler/audio_manifest.json').read_text())
            self.assertEqual(manifest, {'assets/books/frog-princess/audio/frog-princess-part-001.mp3': metadata})
            self.assertTrue((archive / 'assets/toddler/audio/frog-princess-page-01.mp3').is_file())
            self.assertEqual(sorted(p.name for p in (root / 'assets/toddler').iterdir()), ['audio_manifest.json', 'catalog.json'])
            self.assertIn('assets/books/frog-princess/art/', (root / 'pubspec.yaml').read_text())
            second = organize(root, archive, apply=True)
            self.assertEqual(second['moves'], 0)
            self.assertEqual(second['rewrites'], 0)

    def test_conflicting_destination_stops_before_catalog_or_source_mutation(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for path in ['assets/books', 'assets/toddler', 'content/verbatim-books', 'assets/books/frog/art']:
                (root / path).mkdir(parents=True, exist_ok=True)
            book = {'id': 'frog', 'cover': 'assets/books/frog_01.webp', 'pages': []}
            for path, data in [('assets/books/catalog.json', [book]), ('assets/toddler/catalog.json', [book]),
                               ('content/verbatim-books/frog.json', book), ('assets/toddler/audio_manifest.json', {})]:
                (root / path).write_text(json.dumps(data))
            (root / 'assets/books/frog_01.webp').write_text('original')
            (root / 'assets/books/frog/art/frog_01.webp').write_text('different')
            before = (root / 'assets/books/catalog.json').read_bytes()
            with self.assertRaisesRegex(ValueError, 'Conflicting destination'):
                organize(root, root / 'archive', apply=True)
            self.assertEqual((root / 'assets/books/catalog.json').read_bytes(), before)
            self.assertEqual((root / 'assets/books/frog_01.webp').read_text(), 'original')


if __name__ == '__main__':
    unittest.main()
