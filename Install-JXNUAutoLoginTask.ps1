[CmdletBinding()]
param()

$Installer = Join-Path $PSScriptRoot 'Install-CampusAutoLoginTask.ps1'
$Config = Join-Path $PSScriptRoot 'schools\jxnu.json'
& pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $Installer -ConfigPath $Config -TaskName 'JXNU Wi-Fi Auto Login'
exit $LASTEXITCODE
