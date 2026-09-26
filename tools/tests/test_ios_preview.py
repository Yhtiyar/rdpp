"""Checks the actual Xcode project transformation, using a small project fixture."""
import copy
import unittest
from tools.configure_ios_preview import configure_preview


class PreviewProjectTest(unittest.TestCase):
    def project(self):
        return {'rootObject': 'project', 'objects': {
            'project': {'isa': 'PBXProject', 'targets': ['app', 'extension', 'tests'],
                        'attributes': {'TargetAttributes': {'app': {'SystemCapabilities': {
                            'com.apple.FamilyControls': {'enabled': 1},
                            'com.apple.ApplicationGroups.iOS': {'enabled': 1}}}}}},
            'app': {'isa': 'PBXNativeTarget', 'name': 'Runner', 'buildPhases': ['embed', 'resources'],
                    'dependencies': ['monitorDependency'], 'buildConfigurationList': 'configs'},
            'extension': {'isa': 'PBXNativeTarget', 'name': 'ScreenTimeMonitor', 'productReference': 'appex'},
            'tests': {'isa': 'PBXNativeTarget', 'name': 'RunnerTests'},
            'monitorDependency': {'isa': 'PBXTargetDependency', 'target': 'extension'},
            'embed': {'isa': 'PBXCopyFilesBuildPhase', 'files': ['monitorFile', 'otherFile']},
            'resources': {'isa': 'PBXResourcesBuildPhase', 'files': ['bookFile']},
            'monitorFile': {'isa': 'PBXBuildFile', 'fileRef': 'appex'},
            'otherFile': {'isa': 'PBXBuildFile', 'fileRef': 'otherProduct'},
            'configs': {'buildConfigurations': ['debug', 'release']},
            'debug': {'buildSettings': {'CODE_SIGN_ENTITLEMENTS': 'Runner/Runner.entitlements',
                                      'SWIFT_ACTIVE_COMPILATION_CONDITIONS': 'DEBUG $(inherited)'}},
            'release': {'buildSettings': {'CODE_SIGN_ENTITLEMENTS': 'Runner/Runner.entitlements'}},
        }}

    def test_preview_has_no_monitor_target_dependency_or_embedded_extension(self):
        project = self.project()
        configure_preview(project)
        objects = project['objects']
        self.assertEqual(objects['project']['targets'], ['app', 'tests'])
        self.assertEqual(objects['app']['dependencies'], [])
        self.assertEqual(objects['embed']['files'], ['otherFile'])
        self.assertEqual(objects['resources']['files'], ['bookFile'])

    def test_preview_removes_restricted_entitlements_and_selects_stub_in_all_configs(self):
        project = self.project()
        configure_preview(project)
        objects = project['objects']
        for config in ['debug', 'release']:
            settings = objects[config]['buildSettings']
            self.assertEqual(settings['CODE_SIGN_ENTITLEMENTS'], '')
            self.assertIn('WITHOUT_SCREEN_TIME', settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'].split())
        self.assertIn('DEBUG', objects['debug']['buildSettings']['SWIFT_ACTIVE_COMPILATION_CONDITIONS'])
        self.assertEqual(objects['project']['attributes']['TargetAttributes']['app']['SystemCapabilities'], {})
        once = copy.deepcopy(project)
        configure_preview(project)
        self.assertEqual(project, once)


if __name__ == '__main__':
    unittest.main()
