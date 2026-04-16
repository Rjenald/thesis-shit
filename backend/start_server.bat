@echo off
setlocal enabledelayedexpansion

echo ============================================================
echo   Huni CREPE Pitch Detection Server
echo ============================================================
echo.

REM ── Move to the directory containing this script ──────────────────────────
cd /d "%~dp0"

REM ── Activate virtual environment if it exists ─────────────────────────────
if exist "venv\Scripts\activate.bat" (
    echo [INFO] Activating virtual environment...
    call venv\Scripts\activate.bat
    echo [INFO] venv active.
) else (
    echo [WARN] No venv found at .\venv — using system Python.
    echo [HINT] To create one: python -m venv venv
    echo [HINT]                venv\Scripts\activate
    echo [HINT]                pip install -r requirements.txt
    echo.
)

REM ── Check Python is available ─────────────────────────────────────────────
where python >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Python not found on PATH. Please install Python 3.9+ and try again.
    pause
    exit /b 1
)

REM ── Verify the server file exists ─────────────────────────────────────────
if not exist "crepe_server.py" (
    echo [ERROR] crepe_server.py not found in %~dp0
    pause
    exit /b 1
)

REM ── Print connection info ─────────────────────────────────────────────────
echo [INFO] WebSocket : ws://0.0.0.0:8000/ws/pitch
echo [INFO] Health    : http://0.0.0.0:8000/health
echo [INFO] Press Ctrl+C to stop the server.
echo.

REM ── Start the server ─────────────────────────────────────────────────────
python crepe_server.py

REM ── Handle exit ──────────────────────────────────────────────────────────
echo.
echo [INFO] Server stopped.
pause
endlocal
