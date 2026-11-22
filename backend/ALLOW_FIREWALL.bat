@echo off
REM Opens ports 8000 (pitch) and 8001 (login) so a phone on the same Wi-Fi
REM can reach this PC. Windows blocks inbound connections by default, which
REM is why the app says "could not reach the Huni server".
REM
REM RIGHT-CLICK this file -> "Run as administrator".  Double-clicking will
REM not work: adding a firewall rule requires elevation.

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo  ============================================
    echo   NOT RUNNING AS ADMINISTRATOR - nothing done
    echo  ============================================
    echo.
    echo  Close this window.
    echo  RIGHT-CLICK ALLOW_FIREWALL.bat
    echo  Choose "Run as administrator"
    echo.
    pause
    exit /b 1
)

echo Removing any previous rule...
netsh advfirewall firewall delete rule name="Huni servers" >nul 2>&1

echo Adding rule for TCP 8000-8001...
netsh advfirewall firewall add rule name="Huni servers" dir=in action=allow protocol=TCP localport=8000-8001

echo.
echo Verifying...
netsh advfirewall firewall show rule name="Huni servers" | findstr /C:"Rule Name" /C:"Enabled" /C:"LocalPort" /C:"Action"

echo.
echo Your PC's address on this network:
ipconfig | findstr /C:"IPv4"

echo.
echo NEXT: on your PHONE'S BROWSER open  http://THAT-ADDRESS:8001/auth/health
echo Expect:  {"status":"ok","database":"huni_db","users":13}
echo.
pause
