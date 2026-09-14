# Launches the battery daemon fully detached and hidden, and records the
# PID of the launcher process so batt_monitor.bat / stop_batt_monitor.bat can
# check/kill exactly this process instead of matching on "any python.exe"
# (which false-positives against unrelated python.exe processes, e.g. VS
# Code's Python extension language servers).
param(
    [Parameter(Mandatory)][string]$ScriptPath,
    [Parameter(Mandatory)][string]$LogPath,
    [Parameter(Mandatory)][string]$PidPath
)

$cmdArgs = '/c python "' + $ScriptPath + '" >> "' + $LogPath + '" 2>&1'
$proc = Start-Process -FilePath cmd.exe -ArgumentList $cmdArgs -WindowStyle Hidden -PassThru
$proc.Id | Out-File -FilePath $PidPath -Encoding ascii -NoNewline
