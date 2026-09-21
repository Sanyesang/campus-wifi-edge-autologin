[CmdletBinding()]
param()

$Uninstaller = Join-Path $PSScriptRoot 'Uninstall-CampusAutoLoginTask.ps1'
& pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $Uninstaller -TaskName 'JXNU Wi-Fi Auto Login'
exit $LASTEXITCODE
