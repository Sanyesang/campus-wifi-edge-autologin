[CmdletBinding()]
param(
    [ValidateSet('one-click', 'automatic')]
    [string]$Mode = 'one-click'
)

$Setup = Join-Path $PSScriptRoot 'Setup-CampusAutoLogin.ps1'
$Config = Join-Path $PSScriptRoot 'schools\jxnu.json'
& pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $Setup -ConfigPath $Config -TaskName 'JXNU Wi-Fi Auto Login' -Mode $Mode
exit $LASTEXITCODE
