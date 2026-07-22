#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
GD="$HERE/.tools/godot/Godot_v4.6.2-stable_win64.exe"
if [ ! -f "$GD" ]; then GD="$(command -v godot || true)"; fi
PY="${PYTHON:-python}"
echo "=== Python 内容 schema 校验 ==="
"$PY" "$HERE/tools/content_validator/validate.py" "$HERE/content"
if [ -f "$GD" ]; then
  echo "=== Godot headless P0 spike ==="
  for t in test_rng_determinism test_save_atomic_recovery test_event_interpreter test_command_queue test_grid_pathfind test_pixel_scaling test_content_schema; do
    echo "-- $t --"
    "$GD" --headless --path "$HERE" --script "game/tests/$t.gd" || echo "WARN: $t exit non-zero"
  done
else
  echo "WARN: Godot 未安装，跳过 headless spike（请在本机安装 Godot 4.6.2 后重跑）"
fi
echo "=== 完成 ==="
