import plistlib
import tempfile
import unittest
import zipfile
from pathlib import Path
from tools.verify_preview_ipa import verify_preview_ipa


class PreviewIpaTest(unittest.TestCase):
    def make_ipa(self, directory, extension=False, marker=True):
        path = Path(directory) / 'preview.ipa'
        with zipfile.ZipFile(path, 'w') as archive:
            info = {'CFBundleIdentifier': 'com.example.readapp'}
            if marker:
                info['LittlewinsScreenTimePreview'] = True
            archive.writestr('Payload/Runner.app/Info.plist', plistlib.dumps(info))
            if extension:
                archive.writestr('Payload/Runner.app/PlugIns/ScreenTimeMonitor.appex/Info.plist', b'extension')
        return path

    def test_rejects_embedded_extension_even_when_preview_marked(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(ValueError, 'extension'):
                verify_preview_ipa(self.make_ipa(directory, extension=True))

    def test_rejects_build_where_preview_configuration_never_ran(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(ValueError, 'marker'):
                verify_preview_ipa(self.make_ipa(directory, marker=False))

    def test_accepts_configured_preview_without_extensions(self):
        with tempfile.TemporaryDirectory() as directory:
            verify_preview_ipa(self.make_ipa(directory))
