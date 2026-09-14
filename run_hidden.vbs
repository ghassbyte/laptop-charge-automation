' Generic hidden launcher - runs the given command line with no visible
' window and no taskbar entry. Usage: wscript.exe run_hidden.vbs "path\to\file.bat"
Set objShell = CreateObject("WScript.Shell")
objShell.Run """" & WScript.Arguments(0) & """", 0, False
