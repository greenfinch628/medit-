#!/usr/bin/env python3
"""Build from this checkout and install a local, ad-hoc-signed macOS app."""
import argparse
from datetime import datetime, timezone
from pathlib import Path
import platform
import plistlib
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
APP_NAME = 'nex-editm'
BUNDLE_ID = 'com.greenfinch628.medit.review'


def run(*command):
    subprocess.run([str(part) for part in command], cwd=ROOT, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--test', action='store_true', help='Run the existing app tests before installation')
    parser.add_argument('--build-only', action='store_true', help='Build without installing')
    parser.add_argument('--install-dir', type=Path, default=Path.home() / 'Applications')

    args = parser.parse_args()
    if platform.system() != 'Darwin':
        parser.error('Run this script on macOS with full Xcode installed.')
    for tool in ['xcodebuild', 'xcrun', 'ditto', 'codesign']:
        if not shutil.which(tool):
            parser.error(f'Missing {tool}; install and select full Xcode first.')
    run('xcodebuild', '-version')
    destination = args.install_dir.expanduser().resolve() / (APP_NAME + '.app')
    if not args.build_only:
        if destination.is_symlink():
            parser.error(f'Refusing to replace a symbolic link: {destination}')
        if destination.exists():
            try:
                identity = plistlib.loads((destination / 'Contents/Info.plist').read_bytes()).get('CFBundleIdentifier')
            except (OSError, plistlib.InvalidFileException):
                parser.error(f'Cannot identify the existing app: {destination}')
            if identity != BUNDLE_ID:
                parser.error(f'The app at {destination} has a different identity; choose another --install-dir.')
            processes = subprocess.check_output(['ps', '-axo', 'command='], text=True)
            if any(line.lstrip().startswith(str(destination / 'Contents/MacOS') + '/') for line in processes.splitlines()):
                parser.error(f'Quit {APP_NAME} before replacing it.')
    app = ROOT / 'build/source-install/Build/Products/Release/nex-editm.app'
    run('xcodebuild', '-project', ROOT / 'medit-.xcodeproj', '-scheme', 'medit-',
        '-configuration', 'Release', '-derivedDataPath', ROOT / 'build/source-install',
        'CODE_SIGNING_ALLOWED=NO', 'PRODUCT_NAME=nex-editm',
        f'PRODUCT_BUNDLE_IDENTIFIER={BUNDLE_ID}', 'build')
    run('codesign', '--force', '--sign', '-', '--timestamp=none', app)
    if args.test:
        run(app / 'Contents/MacOS/nex-editm', '--self-test')
    run('codesign', '--verify', '--deep', '--strict', app)
    print(f'Built: {app}', flush=True)
    if args.build_only:
        return
    destination.parent.mkdir(parents=True, exist_ok=True)
    # Stage on the destination filesystem, then keep the old app as a backup.
    with tempfile.TemporaryDirectory(prefix=f'.{APP_NAME}-install-', dir=destination.parent) as staging:
        candidate = Path(staging) / destination.name
        run('ditto', app, candidate)
        run('codesign', '--verify', '--deep', '--strict', candidate)
        backup = None
        if destination.exists():
            stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
            backup = destination.with_name(f'{APP_NAME}-{stamp}.app.backup')
            destination.rename(backup)
        try:
            candidate.rename(destination)
        except OSError:
            if backup is not None:
                backup.rename(destination)
            raise
    print(f'Installed: {destination}')
    if backup is not None:
        print(f'Previous app retained at: {backup}')
    print('Open the app from Finder. Existing settings and recovery are retained.')


if __name__ == '__main__':
    main()
