@echo off
setlocal enabledelayedexpansion

echo ============================================================
<<<<<<< HEAD
<<<<<<< HEAD
echo   Huni CREPE Pitch Detection Server  [FULL MODEL]
=======
echo   Huni CREPE Pitch Detection Server
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
=======
echo   Huni CREPE Pitch Detection Server
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
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

<<<<<<< HEAD
<<<<<<< HEAD
REM ── Check for exported Colab model ──────────────────────────────────────
if exist "crepe_full_best.keras" (
    echo [INFO] Found crepe_full_best.keras — using your exported Colab model!
) else (
    echo [INFO] crepe_full_best.keras not found — will download built-in full model.
    echo [HINT] To use your Colab model: download crepe_full_best.keras from
    echo [HINT] Google Drive and place it in this folder.
)
echo.

REM ── Print connection info ─────────────────────────────────────────────────
echo [INFO] Model     : CREPE Full
echo [INFO] WebSocket : ws://0.0.0.0:8000/pitch
=======
REM ── Print connection info ─────────────────────────────────────────────────
echo [INFO] WebSocket : ws://0.0.0.0:8000/ws/pitch
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
=======
REM ── Print connection info ─────────────────────────────────────────────────
echo [INFO] WebSocket : ws://0.0.0.0:8000/ws/pitch
>>>>>>> 3b3d57a9c30cc8f2bff286b136b9d9fdb0c5c49f
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
