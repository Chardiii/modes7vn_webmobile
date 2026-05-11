@echo off
echo Fixing JWT package conflict...
cd /d "%~dp0"
call .venv\Scripts\activate.bat
pip uninstall -y jwt PyJWT python-jwt
pip install PyJWT==2.8.0
pip install Flask-JWT-Extended==4.6.0
echo Done! Try running the app again.
pause
