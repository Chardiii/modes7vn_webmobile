@echo off
echo Starting Flask backend...
call "%~dp0.venv\Scripts\activate.bat"
cd /d "%~dp0backend"
python app.py
