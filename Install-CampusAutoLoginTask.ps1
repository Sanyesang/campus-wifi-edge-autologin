[CmdletBinding()]
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot 'schools\jxnu.json'),
    [string]$TaskName = ''
)

$ErrorActionPreference = 'Stop'
$ConfigPath = [System.IO.Path]::GetFullPath($ConfigPath)
if (-not (Test-Path -LiteralPath $ConfigPath)) { throw "找不到学校配置：$ConfigPath" }

$Config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $TaskName) { $TaskName = "Campus Wi-Fi Auto Login - $($Config.id)" }

$Launcher = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'engine\Start-CampusAutoLogin.ps1'))
$PowerShell = (Get-Command pwsh.exe -ErrorAction Stop).Source
$Action = New-ScheduledTaskAction -Execute $PowerShell -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$Launcher`" -ConfigPath `"$ConfigPath`" -Mode automatic"
$Trigger = New-ScheduledTaskTrigger -AtLogOn -RandomDelay (New-TimeSpan -Seconds 30)
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
$Principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Principal $Principal -Description "连接 $($Config.ssid) 后自动打开并提交校园网 Edge 认证页" -Force | Out-Null
Write-Host "已注册任务：$TaskName"
Write-Host '不会读取、保存或输出账号密码。'
