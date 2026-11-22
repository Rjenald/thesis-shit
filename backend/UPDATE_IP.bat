@echo off
REM Points the app at this PC's current LAN address.
REM
REM Run this whenever you change Wi-Fi networks, then RESTART the app -
REM the server address is applied at build time, so hot reload won't
REM pick it up.
REM
REM Double-click; no admin needed. The real work is in update_ip.ps1.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0update_ip.ps1"

echo.
echo Next: restart the app in VS Code (F5 - "Huni (debug)").
echo.
pause
