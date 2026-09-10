#!/usr/bin/env python3
"""Run the real Godot tests; missing tools and script errors are failures."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]


def find_godot():
    candidates = [os.environ.get('GODOT_BIN', ''), shutil.which('godot'), shutil.which('godot4'),
                  ROOT / '.tools/godot/Godot_v4.6.2-stable_win64.exe',
                  ROOT / '.tools/godot/Godot_v4.6.2-stable_linux.x86_64']
    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            return str(Path(candidate).resolve())
    raise SystemExit('Godot 4.6.2 is required. Set GODOT_BIN or install godot on PATH.')


def run(command, timeout=240):
    result = subprocess.run(command, cwd=ROOT, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=timeout)
    print(result.stdout, flush=True)
    if result.returncode or 'SCRIPT ERROR:' in result.stdout or '\nERROR:' in result.stdout:
        raise SystemExit(result.returncode or 1)
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--full', action='store_true', help='Include stress and performance tests')
    args = parser.parse_args()
    godot = find_godot()
    version = run([godot, '--version']).stdout.strip()
    if not version.startswith('4.6.2.'):
        raise SystemExit(f'Expected Godot 4.6.2, got {version}')
    run([sys.executable, 'tools/content_validator/validate.py', 'content'])
    run([godot, '--headless', '--path', str(ROOT), '--editor', '--import', '--quit'])
    skipped = {'test_p6_thousand_seeds', 'test_p6_perf_benchmark'} if not args.full else set()
    tests = sorted((ROOT / 'game/tests').glob('test_*.gd'))
    for test in tests:
        if test.stem in skipped or test.stem == 'test_playable_ui':
            continue
        print(f'Running {test.name}', flush=True)
        run([godot, '--headless', '--path', str(ROOT), '--script', str(test)], timeout=420)
    run([sys.executable, '-m', 'pytest', '-q', 'tools/map_pipeline/tests'])
    print('All selected tests passed. UI integration runs separately with a display.')


if __name__ == '__main__':
    main()
