@echo off
:: ---- Self-elevate to admin if not already running elevated ----
net session >nul 2>&1
if not %errorlevel%==0 (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

setlocal EnableDelayedExpansion

REM ================= EDIT THESE TO MATCH YOUR SETUP =================
set MOSQUITTO_DIR=C:\Program Files\mosquitto
set MQTT_USER=palzilla
set MQTT_PASS=palzilla
REM =====================================================================

echo Opening Mobile Hotspot settings - turn it ON if it isn't already.
start ms-settings:network-mobilehotspot
echo Press any key once the hotspot is ON...
pause >NUL

REM ---- Start Mosquitto broker hidden (skip if already running) ----
tasklist /FI "IMAGENAME eq mosquitto.exe" 2>NUL | find /I "mosquitto.exe" >NUL
if errorlevel 1 (
    echo Starting Mosquitto broker in background...
    wscript.exe "%~dp0run_hidden.vbs" "%~dp0start_mosquitto.bat"
    timeout /t 3 >NUL
) else (
    echo Mosquitto already running - skipping.
)

REM ---- Start the battery daemon hidden (skip if already running) ----
REM Checked via the tracked PID (batt_monitor.pid), not "is any python.exe
REM running" - other tools (e.g. VS Code's Python extension) spawn their own
REM unrelated python.exe processes, which used to make that check false-
REM positive and silently skip starting the daemon.
set PID_PATH=%~dp0batt_monitor.pid
set DAEMON_RUNNING=0
if exist "%PID_PATH%" (
    set /p DAEMON_PID=<"%PID_PATH%"
    if defined DAEMON_PID (
        tasklist /FI "PID eq !DAEMON_PID!" 2>NUL | find /I "!DAEMON_PID!" >NUL
        if not errorlevel 1 set DAEMON_RUNNING=1
    )
)
if "!DAEMON_RUNNING!"=="1" (
    echo Battery monitor already running - skipping.
) else (
    echo Starting battery monitor in background...
    wscript.exe "%~dp0run_hidden.vbs" "%~dp0start_batt_daemon.bat"
    timeout /t 2 >NUL
)

echo Setting mode to AUTO (20%%/80%% battery logic)...
"%MOSQUITTO_DIR%\mosquitto_pub.exe" -h 127.0.0.1 -p 1883 -u %MQTT_USER% -P %MQTT_PASS% -t home/laptop_charger/mode -m auto -r

echo Done - running silently in the background. This window closes shortly.
timeout /t 3 >NUL