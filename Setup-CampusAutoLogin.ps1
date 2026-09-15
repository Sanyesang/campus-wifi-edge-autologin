[CmdletBinding()]
param(
    [ValidateSet('one-click', 'automatic')]
    [string]$Mode = 'one-click',
    [string]$ConfigPath = (Join-Path $PSScriptRoot 'schools\jxnu.json'),
    [string]$TaskName = ''
)

$ErrorActionPreference = 'Stop'
$ConfigPath = [System.IO.Path]::GetFullPath($ConfigPath)
if (-not (Test-Path -LiteralPath $ConfigPath)) { throw "找不到学校配置：$ConfigPath" }

$Config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $TaskName) { $TaskName = "Campus Wi-Fi Auto Login - $($Config.id)" }

$Installer = Join-Path $PSScriptRoot 'Install-CampusAutoLoginTask.ps1'
$UiScript = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'CampusAutoLoginUI.ps1'))
$PowerShell = (Get-Command powershell.exe).Source

if ($Mode -eq 'automatic') {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Installer -ConfigPath $ConfigPath -TaskName $TaskName
    exit $LASTEXITCODE
}

# 一键模式只创建桌面快捷方式，不注册开机任务。
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
$desktop = [Environment]::GetFolderPath('Desktop')
$shortcutPath = Join-Path $desktop "$($Config.schoolName)校园网一键连接.lnk"
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $PowerShell
$shortcut.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -ConfigPath "{1}"' -f $UiScript, $ConfigPath
$shortcut.WorkingDirectory = $PSScriptRoot
$shortcut.Description = '打开 {0} 校园网助手' -f $Config.schoolName
$shortcut.IconLocation = (Join-Path ${env:SystemRoot} 'System32\netshell.dll') + ',0'
$shortcut.Save()

Write-Host "已创建一键联网快捷方式：$shortcutPath"
Write-Host "未注册开机自动联网任务。"
