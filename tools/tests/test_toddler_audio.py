import importlib.util
from pathlib import Path
import unittest
import tempfile
from unittest.mock import patch, Mock

spec = importlib.util.spec_from_file_location('audio', Path(__file__).parents[1] / 'generate_toddler_audio.py')
audio = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audio)

class AudioGenerationTest(unittest.TestCase):
    def test_hash_changes_when_voice_or_text_changes(self):
        a = audio.request_body('Hello')
        b = {**a, 'voice': 'another-voice'}
        self.assertNotEqual(audio.fingerprint(a), audio.fingerprint(b))
        self.assertNotEqual(audio.fingerprint(a), audio.fingerprint(audio.request_body('Goodbye')))

    def test_rejects_error_document_disguised_as_audio(self):
        with self.assertRaises(ValueError):
            audio.validate_mp3(b'{"error":"failed"}' * 30, 'audio/mpeg')
        with self.assertRaises(ValueError):
            audio.validate_mp3(b'ID3' + b'x' * 400, 'application/json')

    def test_cache_checks_bytes_not_just_request(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / 'clip.mp3'
            body = audio.request_body('Hello')
            p.write_bytes(b'ID3' + b'x' * 400)
            entry = {'requestHash': audio.fingerprint(body), 'sha256': audio.bytes_hash(p.read_bytes())}
            self.assertTrue(audio.cached(p, body, entry))
            p.write_bytes(b'broken')
            self.assertFalse(audio.cached(p, body, entry))

    def test_budget_includes_all_retry_attempts(self):
        with self.assertRaises(ValueError):
            audio.check_budget([audio.request_body('x' * 1000)], .05, 3)
        self.assertAlmostEqual(audio.check_budget([audio.request_body('x' * 1000)], .1, 3), .06)

    def test_language_profile_changes_model_voice_and_cache_identity(self):
        text = 'Жили-были старик со старухой.'
        english = audio.request_body(text)
        russian = audio.request_body(text, {
            'model': audio.GEMINI_MODEL, 'voice': audio.GEMINI_VOICE,
        })
        self.assertEqual(russian['input'], text)
        self.assertEqual(russian['response_format'], 'pcm')
        options = russian['provider']['options']['google-ai-studio']
        self.assertEqual(options['speech_metadata']['style'], audio.GEMINI_STYLE)
        self.assertGreaterEqual(options['maxOutputTokens'], 256)
        self.assertNotEqual(audio.fingerprint(english), audio.fingerprint(russian))
        cost = audio.check_budget([russian], 1, 3)
        self.assertGreater(cost, options['maxOutputTokens'] * .000006 * 3)
        with self.assertRaisesRegex(ValueError, 'exceeds cap'):
            audio.check_budget([russian], cost / 2, 3)

    def test_pcm_rejects_json_and_incomplete_samples(self):
        body = audio.request_body('Привет', {'model': audio.GEMINI_MODEL})
        with self.assertRaises(ValueError):
            audio.mp3_payload(b'{"error":"failed"}' * 300, 'application/json', body)
        with self.assertRaises(ValueError):
            audio.mp3_payload(b'x' * 2401, 'audio/pcm', body)

    def test_unknown_model_cannot_bypass_cost_limit(self):
        body = audio.request_body('hello', {'model': 'unpriced-model'})
        with self.assertRaisesRegex(ValueError, 'Verify pricing'):
            audio.check_budget([body], 1)

    def test_speech_segments_preserve_repetition_and_budget_every_request(self):
        text = 'Повтор. Повтор.'
        book = {'model': audio.GEMINI_MODEL, 'voice': audio.GEMINI_VOICE}
        body = audio.request_body(text, book, {'segments': ['Повтор.', 'Повтор.']})
        parts = audio.segment_requests(body)
        self.assertEqual([part['input'] for part in parts], ['Повтор.', 'Повтор.'])
        self.assertTrue(all('_segments' not in part for part in parts))
        self.assertAlmostEqual(audio.check_budget([body], 1), audio.check_budget(parts, 1))
        self.assertNotEqual(audio.fingerprint(body), audio.fingerprint(audio.request_body(text, book)))
        with self.assertRaisesRegex(ValueError, 'exact complete script'):
            audio.request_body(text, book, {'segments': ['Повтор.', 'Другое.']})

    def test_budget_rejects_nonfinite_caps(self):
        for cap in (float('nan'), float('inf'), -1):
            with self.assertRaisesRegex(ValueError, 'finite'):
                audio.check_budget([audio.request_body('hello')], cap)

    def test_missing_encoder_stops_before_paid_request(self):
        with tempfile.TemporaryDirectory() as directory:
            catalog = Path(directory) / 'catalog.json'
            catalog.write_text('[]')
            body = audio.request_body('Привет', {'model': audio.GEMINI_MODEL})
            with (patch('sys.argv', ['audio', '--catalog', str(catalog), '--generate']),
                  patch.object(audio, 'ROOT', Path(directory)),
                  patch.object(audio, 'requests_for', return_value=[('new.mp3', body)]),
                  patch.object(audio, 'read_key', return_value='test-key'),
                  patch.object(audio, 'encoder_binary', side_effect=ValueError('missing encoder')),
                  patch.object(audio.requests, 'post') as post):
                with self.assertRaisesRegex(ValueError, 'missing encoder'):
                    audio.main()
                post.assert_not_called()

    def test_account_rejection_is_not_retried_and_has_safe_status(self):
        response = Mock(status_code=402)
        with patch.object(audio.requests, 'post', return_value=response) as post:
            with self.assertRaisesRegex(audio.FatalAudioError, 'HTTP 402'):
                audio.generate_one('new.mp3', audio.request_body('Hello'), 'test-key')
            self.assertEqual(post.call_count, 1)

    def test_account_rejection_stops_queued_catalogue_requests(self):
        with tempfile.TemporaryDirectory() as directory:
            catalog = Path(directory) / 'catalog.json'
            catalog.write_text('[]')
            pending = [(f'{n}.mp3', audio.request_body('Hello')) for n in range(5)]
            with (patch('sys.argv', ['audio', '--catalog', str(catalog), '--generate', '--workers', '1']),
                  patch.object(audio, 'ROOT', Path(directory)),
                  patch.object(audio, 'requests_for', return_value=pending),
                  patch.object(audio, 'read_key', return_value='test-key'),
                  patch.object(audio.requests, 'post', return_value=Mock(status_code=401)) as post):
                with self.assertRaises(SystemExit):
                    audio.main()
                self.assertEqual(post.call_count, 1)

if __name__ == '__main__': unittest.main()
