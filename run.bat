@echo off
cd /d "%~dp0backend"

set VENV="%~dp0.venv"
set PYTHON="C:\Users\veluz\AppData\Local\Python\pythoncore-3.14-64\python.exe"

:: Try py 3.11 first (recommended), fallback to detected python
where py >nul 2>&1
if %errorlevel%==0 (
    py -3.11 --version >nul 2>&1
    if %errorlevel%==0 set PYTHON=py -3.11
)

echo [1/3] Checking virtual environment...
%VENV%\Scripts\python.exe -c "import flask" >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] venv missing or broken. Recreating...
    rmdir /s /q %VENV% >nul 2>&1
    %PYTHON% -m venv %VENV%
    echo [2/3] Installing dependencies...
    %VENV%\Scripts\python.exe -m pip install -r requirements.txt
) else (
    echo [2/3] venv OK, skipping install.
)

echo [3/3] Starting Flask app...
%VENV%\Scripts\python.exe app.py
pause
