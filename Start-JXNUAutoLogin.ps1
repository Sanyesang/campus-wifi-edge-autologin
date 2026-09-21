[CmdletBinding()]
param(
    [switch]$ForceOpen,
    [int]$WaitSeconds = 180
)

$Launcher = Join-Path $PSScriptRoot 'engine\Start-CampusAutoLogin.ps1'
$Config = Join-Path $PSScriptRoot 'schools\jxnu.json'
& pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $Launcher -ConfigPath $Config -ForceOpen:$ForceOpen -WaitSeconds $WaitSeconds
exit $LASTEXITCODE
