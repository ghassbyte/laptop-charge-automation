@echo off
:: ---- Self-elevate to admin if not already running elevated ----
net session >nul 2>&1
if not %errorlevel%==0 (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

REM Stops the hidden background broker + daemon.
REM The daemon is stopped via its tracked PID (batt_monitor.pid), so unrelated
REM python.exe processes (VS Code extensions, etc.) are left alone. Falls back
REM to killing all python.exe only if no PID file is found.

echo Stopping Mosquitto broker...
taskkill /IM mosquitto.exe /F >NUL 2>&1

echo Stopping battery monitor daemon...
set PID_PATH=%~dp0batt_monitor.pid
if exist "%PID_PATH%" (
    set /p DAEMON_PID=<"%PID_PATH%"
    if defined DAEMON_PID taskkill /PID %DAEMON_PID% /T /F >NUL 2>&1
    del "%PID_PATH%" >NUL 2>&1
) else (
    echo No PID file found - falling back to killing all python.exe...
    taskkill /IM python.exe /F >NUL 2>&1
)

echo Done.
timeout /t 2 >NUL