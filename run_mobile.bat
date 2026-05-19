@echo off
title Mode S7vn — Mobile
echo.
echo  ==========================================
echo   MODE S7VN — Flutter Mobile App
echo  ==========================================
echo.

set "MOBILE=%~dp0mobile"

REM ── Check Flutter is installed ──
where flutter >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Flutter not found on PATH.
    echo         Install Flutter from https://flutter.dev/docs/get-started/install
    echo.
    pause
    exit /b 1
)

REM ── Check mobile folder exists ──
if not exist "%MOBILE%\pubspec.yaml" (
    echo [ERROR] Mobile project not found at: %MOBILE%
    pause
    exit /b 1
)

cd /d "%MOBILE%"

REM ── Get dependencies ──
echo [1/2] Getting Flutter dependencies...
flutter pub get

REM ── Run app ──
echo.
echo [2/2] Launching app...
echo  (Connect a device or start an emulator first)
echo  Press Ctrl+C to stop.
echo.
flutter run

echo.
echo  App stopped.
pause
