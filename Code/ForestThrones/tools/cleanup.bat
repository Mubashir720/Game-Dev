@echo off
REM ─── Forest Thrones — double-click me ────────────────────────────────────────
REM Retires the 18 files the v5 rebuild superseded by MOVING them into
REM _superseded_backup\ . Nothing is deleted. See cleanup_superseded.ps1.

cd /d "%~dp0.."

if not exist "project.godot" (
    echo.
    echo   ERROR: project.godot not found next to this script.
    echo   Expected layout:  ForestThrones\tools\cleanup.bat
    echo.
    pause
    exit /b 1
)

echo.
echo   Forest Thrones — retiring superseded files
echo   Project: %CD%
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "tools\cleanup_superseded.ps1"

echo.
pause
