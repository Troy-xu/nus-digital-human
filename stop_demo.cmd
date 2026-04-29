@echo off
setlocal
set SCRIPT_DIR=%~dp0
set STOP_SH=%SCRIPT_DIR%scripts\stop_all.sh

echo Stopping NUS Digital Human demo...

if not exist "%STOP_SH%" (
    echo ERROR: %STOP_SH% not found.
    pause
    exit /b 1
)

type "%STOP_SH%" | wsl -d Ubuntu-22.04 -u root -- bash

echo.
echo Done. Window closes in 3 seconds...
timeout /t 3 >nul
endlocal
