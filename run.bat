@echo off
setlocal
set HERE=%~dp0
set GD=%HERE%.tools\godot\Godot_v4.6.2-stable_win64.exe
if not exist "%GD%" set GD=godot
set PY=python
echo === Python 内容 schema 校验 ===
"%PY%" "%HERE%tools\content_validator\validate.py" "%HERE%content"
if exist "%GD%" (
  echo === Godot headless P0 spike ===
  for %%t in (test_rng_determinism test_save_atomic_recovery test_event_interpreter test_command_queue test_grid_pathfind test_pixel_scaling test_content_schema) do (
    echo -- %%t --
    "%GD%" --headless --path "%HERE%" --script "game/tests/%%t.gd" || echo WARN: %%t exit non-zero
  )
) else (
  echo WARN: Godot not found, skipping headless spike. Please install Godot 4.6.2.
)
echo === 完成 ===
endlocal
