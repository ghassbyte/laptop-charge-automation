@echo off
REM Worker script - actually launches Mosquitto. Not meant to be double-clicked
REM directly; batt_monitor.bat runs this hidden via run_hidden.vbs.
REM Edit MOSQUITTO_DIR if your install path differs.

set MOSQUITTO_DIR=C:\Program Files\mosquitto
cd /d "%MOSQUITTO_DIR%"
mosquitto.exe -c mosquitto.conf >> "%MOSQUITTO_DIR%\mosquitto_log.txt" 2>&1
