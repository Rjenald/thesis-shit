@echo off
REM Starts both backend servers, each in its own window:
REM   port 8001  auth_api.py     - login and registration against huni_db
REM   port 8000  crepe_server.py - pitch detection + song catalog
REM
REM Just double-click. Closing a window stops that server.
REM
REM XAMPP's MySQL must be running first, or login returns a 503.

cd /d "%~dp0"

if not exist "venv\Scripts\python.exe" (
    echo.
    echo  No virtual environment found at backend\venv
    echo  Create it with:  python -m venv venv
    echo.
    pause
    exit /b 1
)

echo Checking MySQL...
powershell -NoProfile -Command ^
  "if (Get-Process mysqld -ErrorAction SilentlyContinue) { Write-Host '  MySQL is running' } ^
   else { Write-Host '  WARNING: MySQL is NOT running - start it in the XAMPP Control Panel,' ; Write-Host '           or login will fail with a 503 error.' }"

echo.
echo Starting servers...
start "Huni auth (8001)"  cmd /k "venv\Scripts\python.exe auth_api.py"
start "Huni pitch (8000)" cmd /k "venv\Scripts\python.exe crepe_server.py"

echo.
echo Your PC's address on this network:
powershell -NoProfile -Command ^
  "(Get-NetIPAddress -AddressFamily IPv4 ^| Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } ^| Select-Object -ExpandProperty IPAddress) -join ', '"

echo.
echo IMPORTANT: if that address differs from the one in .vscode\launch.json,
echo update the two PITCH_SERVER_IP lines there and restart the app.
echo A --dart-define is baked in at build time; hot reload will not pick it up.
echo.
pause
