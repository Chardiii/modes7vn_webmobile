@echo off
title Mode S7vn — Backend
echo.
echo  ==========================================
echo   MODE S7VN — Flask Backend
echo  ==========================================
echo.

REM ── Locate project root (one level above this script) ──
set "ROOT=%~dp0.."
set "VENV=%ROOT%\.venv\Scripts\activate.bat"
set "APP=%~dp0app.py"

REM ── Check venv exists ──
if not exist "%VENV%" (
    echo [ERROR] Virtual environment not found at:
    echo         %VENV%
    echo.
    echo  Run this from the project root to create it:
    echo    python -m venv .venv
    echo    .venv\Scripts\pip install -r backend\requirements.txt
    echo.
    pause
    exit /b 1
)

REM ── Check .env exists ──
if not exist "%~dp0.env" (
    echo [WARNING] .env file not found in backend folder.
    echo           Copy .env.example to .env and fill in your values.
    echo.
)

REM ── Activate venv ──
echo [1/2] Activating virtual environment...
call "%VENV%"

REM ── Start server ──
echo [2/2] Starting Flask server...
echo.
echo  Access at: http://localhost:5000
echo  Press Ctrl+C to stop.
echo.

cd /d "%~dp0"
python app.py

echo.
echo  Server stopped.
pause
