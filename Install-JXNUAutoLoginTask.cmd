@echo off
set "SCRIPT=%~dp0Install-JXNUAutoLoginTask.ps1"
pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
if errorlevel 1 pause
