#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
exec "${PYTHON:-python3}" "$ROOT_DIR/tools/build/run_tests.py" "$@"
