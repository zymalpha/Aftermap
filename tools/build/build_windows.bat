@echo off
REM tools/build/build_windows.bat — Windows wrapper for build_windows.sh.
REM Locates Godot and runs the headless Windows Desktop release export.
REM Never aborts the session: a missing GUI Godot / export template prints a
REM clear message and exits 0.

setlocal enabledelayedexpansion

set "HERE=%~dp0"
set "ROOT=%HERE%..\.."
set "OUT_DIR=%ROOT%\build\windows"
set "OUT_EXE=%OUT_DIR%\Aftermap.exe"

set "GD=%ROOT%\.tools\godot\Godot_v4.6.2-stable_win64.exe"
if not exist "%GD%" (
    where godot >nul 2>nul
    if !errorlevel! equ 0 (
        for /f "delims=" %%G in ('where godot') do set "GD=%%G"
    ) else (
        echo WARN: Godot not found in .tools\godot\ or PATH - export skipped.
        echo EXPORT_STATUS=no_godot
        exit /b 0
    )
)

if not exist "%ROOT%\export_presets.cfg" (
    echo WARN: export_presets.cfg missing at repo root - export skipped.
    echo EXPORT_STATUS=no_preset
    exit /b 0
)

if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"

echo === Exporting Aftermap to %OUT_EXE% ===
echo     Godot: %GD%
echo     Preset: "Windows Desktop"

"%GD%" --headless --path "%ROOT%" --export-release "Windows Desktop" "%OUT_EXE%"
set RC=%errorlevel%

if not "%RC%"=="0" (
    echo WARN: Godot export exited non-zero ^(rc=%RC%^).
    echo       This usually means the 'Windows Desktop' export template is not
    echo       installed locally. Open Godot once in GUI mode and install the
    echo       export templates ^(Editor menu - Editor - Manage Export Templates^).
    echo       The release session continues.
    echo EXPORT_STATUS=needs_gui_godot
    exit /b 0
)

if exist "%OUT_EXE%" (
    echo EXPORT_STATUS=ok
    echo OUTPUT=%OUT_EXE%
) else (
    echo EXPORT_STATUS=missing_output
)

endlocal
