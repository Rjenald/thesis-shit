@echo off
REM Starts both backend servers, each in its own window:
REM   port 8001  auth_api.py     - login and registration against huni_db
REM   port 8000  crepe_server.py - pitch detection + song catalog
REM
REM Just double-click (no admin needed). Closing a window stops that server.
REM XAMPP's MySQL must be running, or login fails with a 503.

cd /d "%~dp0"

if not exist "venv\Scripts\python.exe" (
    echo.
    echo  No virtual environment at backend\venv
    echo  Create it with:  python -m venv venv
    echo.
    pause
    exit /b 1
)

echo ===============================================
echo  Checking MySQL...
tasklist /FI "IMAGENAME eq mysqld.exe" 2>nul | find /I "mysqld.exe" >nul
if %errorlevel%==0 (
    echo    [OK] MySQL is running
) else (
    echo    [!!] MySQL is NOT running
    echo         Open the XAMPP Control Panel and press Start next to MySQL,
    echo         otherwise login will fail with a 503 error.
)

echo.
echo  Starting servers...
start "Huni auth (8001)"  cmd /k "venv\Scripts\python.exe auth_api.py"
start "Huni pitch (8000)" cmd /k "venv\Scripts\python.exe crepe_server.py"
echo    [OK] Two windows opened. Give them ~30 seconds to load the model.

echo.
echo ===============================================
echo  This PC's address on this network:
echo.
ipconfig | findstr /C:"IPv4"
echo.
echo  If that differs from the address in .vscode\launch.json,
echo  update the PITCH_SERVER_IP lines there and RESTART the app.
echo  (--dart-define is applied at build time; hot reload won't pick it up.)
echo ===============================================
echo.
pause
