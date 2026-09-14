@echo off
setlocal

REM ================= EDIT THESE TO MATCH YOUR SETUP =================
set MOSQUITTO_DIR=C:\Program Files\Mosquitto
set MQTT_USER=palzilla
set MQTT_PASS=palzilla
REM =====================================================================

echo Setting mode to FORCE_ON (gaming - charger stays ON regardless of battery)...
"%MOSQUITTO_DIR%\mosquitto_pub.exe" -h 127.0.0.1 -p 1883 -u %MQTT_USER% -P %MQTT_PASS% -t home/laptop_charger/mode -m force_on -r

echo.
echo Done - charger will stay ON. Run batt_monitor.bat again to go back to auto logic.
pause
