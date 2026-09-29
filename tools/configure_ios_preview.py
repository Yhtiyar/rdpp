#!/usr/bin/env python3
"""Configure the disposable macOS CI checkout for a Screen-Time-free preview.

The source project stays fully enabled locally. plutil is supplied by macOS;
the transformation itself uses only Python's standard library.
"""

import argparse
import json
from pathlib import Path
import plistlib
import subprocess


def configure_preview(project):
    objects = project['objects']
    root = objects[project['rootObject']]
    runners = [key for key in root['targets']
               if objects[key].get('name') == 'Runner']
    if len(runners) != 1:
        raise ValueError('Expected exactly one Runner target')
    runner_id = runners[0]
    runner = objects[runner_id]
    monitors = {key for key, obj in objects.items()
                if obj.get('isa') == 'PBXNativeTarget'
                and obj.get('name') == 'ScreenTimeMonitor'}
    if len(monitors) != 1:
        raise ValueError('Expected exactly one ScreenTimeMonitor target')
    products = {objects[key]['productReference'] for key in monitors}
    monitor_files = {key for key, obj in objects.items()
                     if obj.get('isa') == 'PBXBuildFile'
                     and obj.get('fileRef') in products}

    # Remove both explicit and implicit build paths to the monitor. Keep the
    # unused objects so repeated application is safe and other targets survive.
    root['targets'] = [key for key in root['targets'] if key not in monitors]
    runner['dependencies'] = [key for key in runner.get('dependencies', [])
                              if objects[key].get('target') not in monitors]
    for phase_id in runner['buildPhases']:
        phase = objects[phase_id]
        if phase.get('isa') == 'PBXCopyFilesBuildPhase':
            phase['files'] = [key for key in phase['files'] if key not in monitor_files]

    configurations = objects[runner['buildConfigurationList']]['buildConfigurations']
    for config_id in configurations:
        settings = objects[config_id]['buildSettings']
        settings['CODE_SIGN_ENTITLEMENTS'] = ''
        conditions = settings.get('SWIFT_ACTIVE_COMPILATION_CONDITIONS', '$(inherited)')
        if isinstance(conditions, list):
            conditions = ' '.join(conditions)
        flags = conditions.split()
        if 'WITHOUT_SCREEN_TIME' not in flags:
            flags.append('WITHOUT_SCREEN_TIME')
        settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = ' '.join(flags)

    attributes = root.get('attributes', {}).get('TargetAttributes', {})
    capabilities = attributes.get(runner_id, {}).get('SystemCapabilities', {})
    capabilities.pop('com.apple.FamilyControls', None)
    capabilities.pop('com.apple.ApplicationGroups.iOS', None)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path,
                        default=Path('ios/Runner.xcodeproj/project.pbxproj'))
    args = parser.parse_args()
    # Read first and only replace the project after every validation passes.
    result = subprocess.run(['plutil', '-convert', 'json', '-o', '-', str(args.project)],
                            check=True, capture_output=True, text=True)
    project = json.loads(result.stdout)
    configure_preview(project)
    info_path = args.project.parent.parent / 'Runner' / 'Info.plist'
    info = plistlib.loads(info_path.read_bytes())
    info['LittlewinsScreenTimePreview'] = True
    args.project.write_bytes(plistlib.dumps(project, sort_keys=False))
    info_path.write_bytes(plistlib.dumps(info, sort_keys=False))
    print('Preview configured: ScreenTimeMonitor omitted, restricted entitlements removed, blocking disabled.')


if __name__ == '__main__':
    main()
