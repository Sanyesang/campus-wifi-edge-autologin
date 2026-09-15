[CmdletBinding()]
param()

$Uninstaller = Join-Path $PSScriptRoot 'Uninstall-CampusAutoLoginTask.ps1'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Uninstaller -TaskName 'JXNU Wi-Fi Auto Login'
exit $LASTEXITCODE

