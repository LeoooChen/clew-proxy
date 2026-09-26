#!/usr/bin/env python3
"""Push a version tag to origin; CI tests, builds and publishes the EXE installer.

Usage: python scripts/release.py [vMAJOR.MINOR.PATCH] [--dry-run]
Requires git and gh on PATH. No local binaries or ZIP archives are published.
"""
from __future__ import annotations

import argparse
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def run(*args: str) -> str:
    command = [shutil.which(args[0]) or args[0], *args[1:]]
    # gh emits UTF-8 even when Windows' default Python encoding is GBK.
    return subprocess.check_output(command, cwd=ROOT, text=True, encoding='utf-8').strip()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('version', nargs='?')
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    if run('git', 'status', '--porcelain'):
        raise SystemExit('Commit all changes before releasing.')
    origin = run('git', 'remote', 'get-url', 'origin')
    match = re.fullmatch(r'(?:https://github\.com/|git@github\.com:)([^/]+/[^/]+?)(?:\.git)?', origin)
    if not match:
        raise SystemExit('origin must point to the intended GitHub repository.')
    repo = match[1]
    previous = run('git', 'describe', '--tags', '--abbrev=0')
    if args.version:
        tag = 'v' + args.version.removeprefix('v')
    else:
        version = re.fullmatch(r'v(\d+)\.(\d+)\.(\d+)', previous)
        if not version:
            raise SystemExit('Specify a version: vMAJOR.MINOR.PATCH')
        tag = f'v{version[1]}.{version[2]}.{int(version[3]) + 1}'
    if not re.fullmatch(r'v\d+\.\d+\.\d+', tag):
        raise SystemExit('Version must be vMAJOR.MINOR.PATCH')
    if run('git', 'tag', '--list', tag) or run('git', 'ls-remote', '--tags', 'origin', f'refs/tags/{tag}'):
        raise SystemExit(f'{tag} already exists.')
    print(f'Repository: {repo}\nCommit: {run("git", "rev-parse", "HEAD")}\nTag: {tag}')
    print('CI will publish the Windows EXE only after build, UI and installer tests pass.')
    if args.dry_run:
        return
    run('gh', 'auth', 'status')
    run('git', 'push', 'origin', 'HEAD')
    run('git', 'tag', '-a', tag, '-m', f'Clew {tag}')
    run('git', 'push', 'origin', tag)
    print(f'Follow build status: https://github.com/{repo}/actions')
    print(f'Release after CI passes: https://github.com/{repo}/releases/tag/{tag}')


if __name__ == '__main__':
    main()
