@echo off
REM Worker script - actually launches the battery monitor daemon. Not meant to
REM be double-clicked directly; batt_monitor.bat runs this hidden.
REM Edit SCRIPT_PATH to match where you saved laptop-charge-automation.py.

set SCRIPT_PATH=E:\03_project\mix\laptop-charge-automation\laptop-charge-automation.py
set LOG_PATH=E:\03_project\mix\laptop-charge-automation\batt_monitor_log.txt
set PID_PATH=%~dp0batt_monitor.pid

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start_daemon.ps1" -ScriptPath "%SCRIPT_PATH%" -LogPath "%LOG_PATH%" -PidPath "%PID_PATH%"
