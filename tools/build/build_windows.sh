#!/usr/bin/env bash
# tools/build/build_windows.sh — export Aftermap as a Windows Desktop release
# build using the bundled Godot 4.6.2 binary.
#
# Flow:
#   1. Locate Godot (prefer .tools/godot/, fall back to PATH).
#   2. Run `godot --headless --export-release "Windows Desktop" build/windows/Aftermap.exe`.
#
# Export requires the export presets (res://export_presets.cfg) AND the
# "Windows Desktop" export template installed locally. On a headless CI box
# without the export templates, the step will print a clear message and exit 0
# so it never breaks the release session — a maintainer with a GUI Godot +
# templates can produce the final .exe.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
OUT_DIR="$ROOT/build/windows"
OUT_EXE="$OUT_DIR/Aftermap.exe"

GD="$ROOT/.tools/godot/Godot_v4.6.2-stable_win64.exe"
if [ ! -f "$GD" ]; then
	GD="$(command -v godot || true)"
fi

if [ -z "$GD" ] || [ ! -f "$GD" ]; then
	echo "WARN: Godot not found in .tools/godot/ or PATH — export skipped."
	echo "      Install Godot 4.6.2 and re-run, or place the binary at .tools/godot/."
	echo "EXPORT_STATUS=no_godot"
	exit 0
fi

if [ ! -f "$ROOT/export_presets.cfg" ]; then
	echo "WARN: export_presets.cfg missing at repo root — export skipped."
	echo "EXPORT_STATUS=no_preset"
	exit 0
fi

mkdir -p "$OUT_DIR"
echo "=== Exporting Aftermap → $OUT_EXE ==="
echo "    Godot: $GD"
echo "    Preset: \"Windows Desktop\""

# Run the release export. We capture the exit code because a missing export
# template is reported as a non-zero exit, which we deliberately do NOT treat
# as fatal to the session.
set +e
"$GD" --headless --path "$ROOT" --export-release "Windows Desktop" "$OUT_EXE"
RC=$?
set -e 2>/dev/null || true

if [ "$RC" -ne 0 ]; then
	echo "WARN: Godot export exited non-zero (rc=$RC)."
	echo "      This usually means the 'Windows Desktop' export template is not"
	echo "      installed locally. Open Godot once in GUI mode and install the"
	echo "      export templates (Editor menu → Editor → Manage Export Templates)."
	echo "      The release session continues; build_windows will be re-run by a"
	echo "      maintainer with templates to produce the final binary."
	echo "EXPORT_STATUS=needs_gui_godot"
	# Deliberately exit 0 so CI/release scripts don't abort.
	exit 0
fi

if [ -f "$OUT_EXE" ]; then
	SIZE=$(stat -c %s "$OUT_EXE" 2>/dev/null || stat -f %z "$OUT_EXE" 2>/dev/null || echo "?")
	echo "EXPORT_STATUS=ok"
	echo "OUTPUT=$OUT_EXE"
	echo "SIZE_BYTES=$SIZE"
else
	echo "EXPORT_STATUS=missing_output"
fi
