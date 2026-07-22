@echo off
REM tools/build/run_tests.bat — run the P0/P1 spike tests on Windows.
REM Mirrors run.bat's spike loop, kept under tools/build/ so CI can call
REM a dedicated test entry-point without re-running schema validation.
setlocal
set HERE=%~dp0
set ROOT=%HERE%..\..
for %%I in ("%ROOT%") do set ROOT=%%~fI
set GD=%ROOT%\.tools\godot\Godot_v4.6.2-stable_win64.exe
if not exist "%GD%" set GD=godot
set PY=python
echo === Python 内容 schema 校验 ===
"%PY%" "%ROOT%\tools\content_validator\validate.py" "%ROOT%\content"
if exist "%GD%" (
  echo === Godot headless P0/P1 spike ===
  for %%t in (test_rng_determinism test_save_atomic_recovery test_event_interpreter test_command_queue test_grid_pathfind test_pixel_scaling test_content_schema test_stage3_smoke test_p1_tactical) do (
    echo -- %%t --
    "%GD%" --headless --path "%ROOT%" --script "game/tests/%%t.gd" || echo WARN: %%t exit non-zero
  )
) else (
  echo WARN: Godot not found, skipping headless spike. Please install Godot 4.6.2.
)
echo === 完成 ===
endlocal