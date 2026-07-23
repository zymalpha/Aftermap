@echo off
setlocal
set HERE=%~dp0
set GD=%HERE%.tools\godot\Godot_v4.6.2-stable_win64.exe
if not exist "%GD%" set GD=godot
set PY=python
echo === Python 内容 schema 校验 ===
"%PY%" "%HERE%tools\content_validator\validate.py" "%HERE%content"
if exist "%GD%" (
  echo === Godot headless 全量回归 (Stage 18 / v1.0) ===
  for %%t in (test_command_queue test_grid_pathfind test_pixel_scaling test_stage3_smoke test_p1_tactical test_p2_characters test_p2_content test_p2_inventory_base test_p2_seven_days test_p2_state_machine test_p2_world test_p4_thirty_days test_p5_content_count test_p5_ui_layout test_p5_localization test_p5_scene_controllers test_p6_thousand_seeds test_p6_perf_benchmark) do (
    echo -- %%t --
    "%GD%" --headless --path "%HERE%" --script "game/tests/%%t.gd" || echo WARN: %%t exit non-zero
  )
) else (
  echo WARN: Godot not found, skipping headless spike. Please install Godot 4.6.2.
)
echo === Python pytest: map_pipeline ===
"%PY%" -m pytest "%HERE%tools\map_pipeline\tests\" || echo WARN: pytest exit non-zero
echo === 完成 ===
endlocal
