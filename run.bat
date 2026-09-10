@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"
if defined GODOT_BIN goto launch
if exist ".tools\godot\Godot_v4.6.2-stable_win64.exe" (
  set "GODOT_BIN=%~dp0.tools\godot\Godot_v4.6.2-stable_win64.exe"
  goto launch
)
where godot >nul 2>nul
if not errorlevel 1 (
  set "GODOT_BIN=godot"
  goto launch
)
echo 请安装 Godot 4.6.2，并设置 GODOT_BIN 为程序路径。
echo 或将 Godot 放到 .tools\godot\Godot_v4.6.2-stable_win64.exe
pause
exit /b 1
:launch
"%GODOT_BIN%" --path "%~dp0." %*
exit /b %errorlevel%
