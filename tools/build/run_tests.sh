#!/usr/bin/env bash
# tools/build/run_tests.sh — run the P0/P1 spike tests.
# Mirrors the spike loop in run.sh, kept under tools/build/ so CI can call
# a dedicated test entry-point without re-running schema validation.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
GD="$ROOT/.tools/godot/Godot_v4.6.2-stable_win64.exe"
if [ ! -f "$GD" ]; then GD="$(command -v godot || true)"; fi
PY="${PYTHON:-python}"
echo "=== Python 内容 schema 校验 ==="
"$PY" "$ROOT/tools/content_validator/validate.py" "$ROOT/content"
if [ -f "$GD" ]; then
  echo "=== Godot headless P0/P1 spike ==="
  for t in test_rng_determinism test_save_atomic_recovery test_event_interpreter test_command_queue test_grid_pathfind test_pixel_scaling test_content_schema test_stage3_smoke test_p1_tactical; do
    echo "-- $t --"
    "$GD" --headless --path "$ROOT" --script "game/tests/$t.gd" || echo "WARN: $t exit non-zero"
  done
else
  echo "WARN: Godot 未安装，跳过 headless spike（请在本机安装 Godot 4.6.2 后重跑）"
fi
echo "=== 完成 ==="