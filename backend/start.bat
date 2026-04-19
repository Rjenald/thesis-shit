@echo off
echo Starting Huni Pitch Detection Server...
echo.

REM Check if venv exists
if not exist "venv\" (
    echo Creating virtual environment...
    python -m venv venv
    call venv\Scripts\activate
    echo Installing packages...
    pip install -r requirements.txt
) else (
    call venv\Scripts\activate
)

echo.
echo Server starting at ws://0.0.0.0:8000/pitch
echo Press Ctrl+C to stop
echo.

python app.py
