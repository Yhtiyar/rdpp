import copy
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).parents[1]))
from merge_book_catalogs import validate_verbatim
from prepare_russian_books import clean_page
from segment_verbatim_books import canonical_text, segment


class VerbatimBooksTest(unittest.TestCase):
    def setUp(self):
        self.reading = {
            'id': 'example', 'language': 'ru',
            'pages': [
                {'text': '«Где же дом?»\n\n— спросила мышка. ' * 10,
                 'sourcePage': 1, 'image': 'one.webp'},
                {'text': 'За рекой стоял дом.\nОни вернулись домой!',
                 'sourcePage': 2, 'image': 'two.webp'},
            ],
        }
        pages = segment(self.reading)
        questions = []
        for start in range(0, len(pages), 3):
            group = pages[start:start + 3]
            for _ in range(1 if len(group) == 1 else 2):
                questions.append({
                    'id': f'question-{len(questions)}',
                    'afterPage': start + len(group) - 1,
                    'evidence': {'quote': group[-1]['text'],
                                 'pageIds': [group[-1]['id']]},
                    'choices': [{'image': 'mouse.webp'}, {'image': 'house.webp'}],
                    'answer': len(questions) % 2,
                })
        self.edition = {'id': 'example', 'version': 2, 'textPolicy': 'verbatim',
                        'pages': pages, 'questions': questions}

    def test_segmentation_preserves_unicode_dialogue_and_all_source_words(self):
        source, _ = canonical_text(self.reading)
        self.assertEqual(' '.join(p['text'] for p in self.edition['pages']), source)
        for part in self.edition['pages']:
            self.assertEqual(source[part['sourceTextStart']:part['sourceTextEnd']], part['text'])
        self.assertEqual(self.edition['pages'][-1]['sourcePages'][-1], 2)
        validate_verbatim(self.edition, self.reading)

    def test_long_sentence_is_never_truncated_to_fit_duration(self):
        self.reading['pages'][0]['text'] = 'Очень ' * 110 + 'длинное предложение.'
        self.reading['pages'] = self.reading['pages'][:1]
        parts = segment(self.reading)
        self.assertEqual(len(parts), 1)
        self.assertGreater(parts[0]['estimatedPlaybackSeconds'], 25)
        self.assertEqual(parts[0]['text'], self.reading['pages'][0]['text'])

    def test_checkpoint_keeps_dialogue_with_its_speaker_attribution(self):
        text = ('Утка сидела в гнезде. ' * 27
                + '— Да вот, ещё одно яйцо остаётся! — сказала молодая утка. '
                + 'Наступил солнечный день. ' * 7)
        self.reading['pages'] = [{'text': text, 'sourcePage': 1, 'image': 'one.webp'}]
        parts = segment(self.reading)
        self.assertTrue(any('яйцо остаётся! — сказала молодая утка.' in p['text'] for p in parts))
        self.assertFalse(any(p['text'].startswith('— сказала') for p in parts))
        self.assertEqual(' '.join(p['text'] for p in parts), ' '.join(text.split()))

    def test_checkpoint_never_interrupts_a_repeated_quoted_sound(self):
        text = ('Утка сидела в гнезде. ' * 27
                + 'Наконец затрещала скорлупка и самого большого яйца. '
                + '«Пи! пи-и!» — и оттуда вывалился огромный некрасивый птенец. '
                + 'Наступил солнечный день. ' * 6)
        self.reading['pages'] = [{'text': text, 'sourcePage': 1, 'image': 'one.webp'}]
        parts = segment(self.reading)
        self.assertTrue(any('«Пи! пи-и!» — и оттуда' in p['text'] for p in parts))
        self.assertFalse(any(p['text'].endswith('«Пи!') for p in parts))
        self.assertEqual(' '.join(p['text'] for p in parts), ' '.join(text.split()))

    def test_reading_cleaner_omits_numbered_section_headings_but_keeps_verse(self):
        source = 'Айболит\n1 часть\nДобрый доктор Айболит!\n2 часть\nИ пришла к Айболиту лиса.\n3\n'
        self.assertEqual(
            clean_page(source, 'Айболит', 'Корней Иванович Чуковский', poem=True),
            'Добрый доктор Айболит!\nИ пришла к Айболиту лиса.')

    def test_publisher_rejects_shortened_text(self):
        self.edition['pages'][0]['text'] = 'Жила мышка.'
        with self.assertRaisesRegex(ValueError, 'complete source text'):
            validate_verbatim(self.edition, self.reading)

    def test_publisher_rejects_lost_partial_checkpoint(self):
        self.edition['questions'].pop()
        with self.assertRaisesRegex(ValueError, 'incomplete listening checkpoints'):
            validate_verbatim(self.edition, self.reading)

    def test_publisher_rejects_evidence_from_a_different_passage(self):
        self.edition['questions'][0]['evidence']['quote'] = 'Волк съел пирожки.'
        with self.assertRaisesRegex(ValueError, 'current passage'):
            validate_verbatim(self.edition, self.reading)

    def test_publisher_rejects_stale_offsets_even_with_complete_words(self):
        changed = copy.deepcopy(self.edition)
        changed['pages'][0]['sourceTextStart'] += 1
        with self.assertRaisesRegex(ValueError, 'source offsets'):
            validate_verbatim(changed, self.reading)


if __name__ == '__main__':
    unittest.main()
