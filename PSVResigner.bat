@ECHO OFF
START "" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0PSVResignerMain.ps1" %*
EXIT