@echo off
REM NUS Digital Human demo launcher (Windows side).
REM Pipes start_all.sh into WSL bash via stdin to avoid path-with-spaces parsing issues.

setlocal
set SCRIPT_DIR=%~dp0
set START_SH=%SCRIPT_DIR%scripts\start_all.sh

echo Starting NUS Digital Human demo...
echo Using script: %START_SH%
echo.

if not exist "%START_SH%" (
    echo ERROR: %START_SH% not found.
    pause
    exit /b 1
)

REM Pipe the bash script into WSL via stdin so we never need to pass a Windows path
REM (with spaces) as a WSL argument. Robust across cmd's quoting quirks.
type "%START_SH%" | wsl -d Ubuntu-22.04 -u root -- bash

if errorlevel 1 (
    echo.
    echo ERROR: start_all.sh exited with code %errorlevel%.
    pause
    exit /b %errorlevel%
)

echo.
echo Opening browser...
start "" http://localhost:3000/sentio

echo.
echo Demo launched. Window closes in 5 seconds (or press any key)...
timeout /t 5 >nul
endlocal
