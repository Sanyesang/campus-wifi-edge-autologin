@echo off
set "SCRIPT=%~dp0Install-JXNUAutoLoginTask.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
if errorlevel 1 pause

