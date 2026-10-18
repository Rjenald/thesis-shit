@echo off
REM Opens ports 8000 (pitch server) and 8001 (auth/login) so a phone on the
REM same Wi-Fi can reach them. Windows blocks inbound connections by default,
REM which is why the app reports "could not reach the Huni server".
REM
REM RIGHT-CLICK THIS FILE AND CHOOSE "Run as administrator".
REM Run once per machine - the rule persists.

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo  NOT RUNNING AS ADMINISTRATOR
    echo.
    echo  Close this window, right-click ALLOW_FIREWALL.bat
    echo  and choose "Run as administrator".
    echo.
    pause
    exit /b 1
)

echo Adding firewall rule for ports 8000 and 8001...
powershell -NoProfile -Command ^
  "Remove-NetFirewallRule -DisplayName 'Huni servers (8000-8001)' -ErrorAction SilentlyContinue; ^
   New-NetFirewallRule -DisplayName 'Huni servers (8000-8001)' -Direction Inbound ^
     -LocalPort 8000,8001 -Protocol TCP -Action Allow -Profile Private,Domain | Out-Null; ^
   Write-Host 'Rule added.'"

echo.
echo Your PC's address on this network:
powershell -NoProfile -Command ^
  "(Get-NetIPAddress -AddressFamily IPv4 ^| Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } ^| Select-Object -ExpandProperty IPAddress) -join ', '"

echo.
echo Next: on your PHONE's browser open
echo    http://THAT_ADDRESS:8001/auth/health
echo You should see:  {"status":"ok","database":"huni_db","users":13}
echo.
pause
