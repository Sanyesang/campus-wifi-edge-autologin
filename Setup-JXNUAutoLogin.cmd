@echo off
echo 1. 一键联网（需要你点击桌面快捷方式）
echo 2. 全自动联网（Windows登录后自动执行）
choice /C 12 /N /M "请选择模式 [1/2]: "
if errorlevel 2 goto automatic
if errorlevel 1 goto oneclick

:oneclick
pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup-JXNUAutoLogin.ps1" -Mode one-click
goto end

:automatic
pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup-JXNUAutoLogin.ps1" -Mode automatic
goto end

:end
if errorlevel 1 pause
