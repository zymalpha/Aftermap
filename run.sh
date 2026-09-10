#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
GODOT_EXE="${GODOT_BIN:-}"
if [ -z "$GODOT_EXE" ]; then
  GODOT_EXE="$(command -v godot || command -v godot4 || true)"
fi
if [ -z "$GODOT_EXE" ] && [ -x "$ROOT_DIR/.tools/godot/Godot_v4.6.2-stable_linux.x86_64" ]; then
  GODOT_EXE="$ROOT_DIR/.tools/godot/Godot_v4.6.2-stable_linux.x86_64"
fi
if [ -z "$GODOT_EXE" ]; then
  echo "Godot 4.6.2 is required. Set GODOT_BIN or add godot to PATH."
  exit 1
fi
exec "$GODOT_EXE" --path "$ROOT_DIR" "$@"
