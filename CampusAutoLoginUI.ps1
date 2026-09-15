[CmdletBinding()]
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot 'schools\jxnu.json'),
    [switch]$Startup
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$ConfigPath = [System.IO.Path]::GetFullPath($ConfigPath)
if (-not (Test-Path -LiteralPath $ConfigPath)) {
    [System.Windows.Forms.MessageBox]::Show("找不到学校配置：$ConfigPath", '校园网助手', 'OK', 'Error') | Out-Null
    exit 2
}

$Config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
$UiScriptPath = [System.IO.Path]::GetFullPath($PSCommandPath)
$EngineScript = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'engine\Start-CampusAutoLogin.ps1'))
$PowerShell = (Get-Command powershell.exe).Source
$StartupDir = [Environment]::GetFolderPath('Startup')
$StartupShortcutPath = Join-Path $StartupDir "$($Config.schoolName)校园网助手.lnk"
$LogPath = Join-Path (Join-Path $env:LOCALAPPDATA 'CampusAutoLogin') "$($Config.id).log"
$script:ConnectionProcess = $null

function New-Shortcut {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$TargetPath,
        [Parameter(Mandatory = $true)][string]$Arguments,
        [Parameter(Mandatory = $true)][string]$WorkingDirectory,
        [string]$Description = '',
        [string]$IconLocation = ''
    )

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($Path)
    $shortcut.TargetPath = $TargetPath
    $shortcut.Arguments = $Arguments
    $shortcut.WorkingDirectory = $WorkingDirectory
    $shortcut.Description = $Description
    if ($IconLocation) { $shortcut.IconLocation = $IconLocation }
    $shortcut.Save()
}

function Set-StartupEnabled {
    param([bool]$Enabled)

    if ($Enabled) {
        $args = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -ConfigPath "{1}" -Startup' -f $UiScriptPath, $ConfigPath
        New-Shortcut -Path $StartupShortcutPath -TargetPath $PowerShell -Arguments $args `
            -WorkingDirectory $PSScriptRoot -Description "启动 $($Config.schoolName) 校园网助手" `
            -IconLocation "${env:SystemRoot}\System32\netshell.dll,0"
    } elseif (Test-Path -LiteralPath $StartupShortcutPath) {
        Remove-Item -LiteralPath $StartupShortcutPath -Force
    }
}

function Get-LastStatus {
    if (Test-Path -LiteralPath $LogPath) {
        $line = Get-Content -LiteralPath $LogPath -Tail 1 -ErrorAction SilentlyContinue
        if ($line) { return ([string]$line -replace '^\S+\s+\S+\s+', '') }
    }
    return ''
}

function Start-Connection {
    if ($script:ConnectionProcess -and -not $script:ConnectionProcess.HasExited) {
        return
    }

    $button.Enabled = $false
    $statusLabel.Text = '正在等待 Wi-Fi 并连接校园网…'
    $argLine = '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}" -ConfigPath "{1}" -Mode one-click' -f $EngineScript, $ConfigPath
    $script:ConnectionProcess = Start-Process -FilePath $PowerShell -ArgumentList $argLine -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -PassThru
    $statusTimer.Start()
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "$($Config.schoolName) 校园网助手"
$form.StartPosition = 'CenterScreen'
$form.ClientSize = New-Object System.Drawing.Size(520, 315)
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.MinimizeBox = $true
$form.BackColor = [System.Drawing.Color]::FromArgb(247, 249, 252)

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "$($Config.schoolName) 校园网助手"
$titleLabel.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 17, [System.Drawing.FontStyle]::Bold)
$titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(29, 53, 87)
$titleLabel.AutoSize = $true
$titleLabel.Location = New-Object System.Drawing.Point(145, 30)
$form.Controls.Add($titleLabel)

$hintLabel = New-Object System.Windows.Forms.Label
$hintLabel.Text = "连接 Wi-Fi：$($Config.ssid)"
$hintLabel.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9)
$hintLabel.ForeColor = [System.Drawing.Color]::FromArgb(90, 105, 120)
$hintLabel.AutoSize = $true
$hintLabel.Location = New-Object System.Drawing.Point(190, 70)
$form.Controls.Add($hintLabel)

$button = New-Object System.Windows.Forms.Button
$button.Text = '一键连接校园网'
$button.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 15, [System.Drawing.FontStyle]::Bold)
$button.ForeColor = [System.Drawing.Color]::White
$button.BackColor = [System.Drawing.Color]::FromArgb(22, 119, 153)
$button.FlatStyle = 'Flat'
$button.FlatAppearance.BorderSize = 0
$button.Size = New-Object System.Drawing.Size(330, 76)
$button.Location = New-Object System.Drawing.Point(95, 105)
$button.Cursor = [System.Windows.Forms.Cursors]::Hand
$button.Add_Click({ Start-Connection })
$form.Controls.Add($button)

$startupCheckBox = New-Object System.Windows.Forms.CheckBox
$startupCheckBox.Text = '开机自启'
$startupCheckBox.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9)
$startupCheckBox.AutoSize = $true
$startupCheckBox.Location = New-Object System.Drawing.Point(95, 205)
$startupCheckBox.Checked = $false
$startupCheckBox.Add_CheckedChanged({
    try {
        Set-StartupEnabled -Enabled $startupCheckBox.Checked
        if ($startupCheckBox.Checked) {
            $statusLabel.Text = '已开启开机自启：下次登录 Windows 会自动打开本窗口。'
        } else {
            $statusLabel.Text = '已关闭开机自启。'
        }
    } catch {
        $startupCheckBox.Checked = -not $startupCheckBox.Checked
        $statusLabel.Text = "设置开机自启失败：$($_.Exception.Message)"
    }
})
$form.Controls.Add($startupCheckBox)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = if ($Startup) { '开机自启已启动，请点击按钮连接校园网。' } else { '准备就绪。' }
$statusLabel.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9)
$statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(90, 105, 120)
$statusLabel.AutoSize = $false
$statusLabel.TextAlign = 'MiddleLeft'
$statusLabel.Size = New-Object System.Drawing.Size(330, 42)
$statusLabel.Location = New-Object System.Drawing.Point(95, 238)
$form.Controls.Add($statusLabel)
$startupCheckBox.Checked = Test-Path -LiteralPath $StartupShortcutPath

$statusTimer = New-Object System.Windows.Forms.Timer
$statusTimer.Interval = 700
$statusTimer.Add_Tick({
    $last = Get-LastStatus
    if ($last -match 'internet already available|internet became available') {
        $statusLabel.Text = '连接成功，可以上网了。'
    } elseif ($last -match 'timeout waiting|WLAN not connected') {
        $statusLabel.Text = '连接未完成，请确认 Wi-Fi 已连接到目标校园网。'
    } elseif ($last) {
        $statusLabel.Text = "正在处理：$last"
    }

    if ($script:ConnectionProcess -and $script:ConnectionProcess.HasExited) {
        $statusTimer.Stop()
        $button.Enabled = $true
        if ($script:ConnectionProcess.ExitCode -eq 0) {
            $statusLabel.Text = '连接流程已完成，请查看 Edge 或尝试打开网页。'
        } elseif ($script:ConnectionProcess.ExitCode -ne 1) {
            $statusLabel.Text = "连接失败，退出码：$($script:ConnectionProcess.ExitCode)"
        }
    }
})

$form.Add_FormClosed({
    $statusTimer.Stop()
})

[void]$form.ShowDialog()
