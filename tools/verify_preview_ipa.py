#!/usr/bin/env python3
"""Reject an IPA when the no-Screen-Time configuration was not applied."""

import argparse
from pathlib import Path, PurePosixPath
import plistlib
import zipfile


def verify_preview_ipa(path):
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        extensions = [name for name in names
                      if any(part.endswith('.appex') for part in PurePosixPath(name).parts)]
        if extensions:
            raise ValueError(f'{path}: preview still contains an app extension: {extensions[0]}')
        info_paths = [name for name in names
                      if len(PurePosixPath(name).parts) == 3
                      and name.startswith('Payload/')
                      and PurePosixPath(name).parts[1].endswith('.app')
                      and name.endswith('/Info.plist')]
        if len(info_paths) != 1:
            raise ValueError(f'{path}: expected exactly one app Info.plist')
        info = plistlib.loads(archive.read(info_paths[0]))
        if info.get('LittlewinsScreenTimePreview') is not True:
            raise ValueError(f'{path}: missing preview marker; preview configuration did not run')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('ipa', type=Path, nargs='+')
    args = parser.parse_args()
    for path in args.ipa:
        try:
            verify_preview_ipa(path)
        except (ValueError, OSError, zipfile.BadZipFile) as error:
            parser.exit(1, f'ERROR: {error}\nPublish the updated iOS workflow to the GitHub default branch, then rebuild. Do not install this IPA.\n')
        print(f'PASS: {path}: preview marker present; no app extensions.')


if __name__ == '__main__':
    main()
