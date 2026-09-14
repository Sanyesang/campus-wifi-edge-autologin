[CmdletBinding()]
param(
    [string]$TaskName = 'Campus Wi-Fi Auto Login - jxnu-stu'
)

$ErrorActionPreference = 'Stop'
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
Write-Host "已移除任务：$TaskName"

