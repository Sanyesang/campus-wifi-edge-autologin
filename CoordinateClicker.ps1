[CmdletBinding()]
param(
    [int]$InitialDelaySeconds = 8,
    [int]$ClickDelaySeconds = 2,
    [int]$AfterThirdClickDelaySeconds = 8,
    [switch]$AutoStart
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$script:validOperators = @('移动', '电信', '联通')
$script:scriptPath = [System.IO.Path]::GetFullPath($PSCommandPath)
$script:settingsDirectory = Join-Path $env:LOCALAPPDATA 'JXNUCampusClicker'
$script:settingsPath = Join-Path $script:settingsDirectory 'settings.json'
$script:startupShortcutPath = Join-Path (
    [Environment]::GetFolderPath([Environment+SpecialFolder]::Startup)
) '江西师范大学校园网一键连接.lnk'
$script:selectedOperator = ''
$script:settingsLoadError = ''
$script:autoStartConfigured = $false

function Get-SavedOperator {
    if (-not (Test-Path -LiteralPath $script:settingsPath)) {
        return ''
    }

    $settings = Get-Content -LiteralPath $script:settingsPath -Raw | ConvertFrom-Json -ErrorAction Stop
    $operator = [string]$settings.selectedOperator
    if ($operator -notin $script:validOperators) {
        throw '已保存的运营商设置无效，请重新打开工具并选择运营商。'
    }

    return $operator
}

function Save-SelectedOperator {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('移动', '电信', '联通')]
        [string]$Operator
    )

    if (-not (Test-Path -LiteralPath $script:settingsDirectory)) {
        New-Item -ItemType Directory -Path $script:settingsDirectory -Force | Out-Null
    }

    $settings = [ordered]@{ selectedOperator = $Operator } | ConvertTo-Json
    [System.IO.File]::WriteAllText(
        $script:settingsPath,
        $settings,
        [System.Text.UTF8Encoding]::new($false))
    $script:selectedOperator = $Operator
}

function Get-StartupShortcutInfo {
    if (-not (Test-Path -LiteralPath $script:startupShortcutPath)) {
        return $null
    }

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($script:startupShortcutPath)
    return [pscustomobject]@{
        TargetPath = [string]$shortcut.TargetPath
        Arguments  = [string]$shortcut.Arguments
    }
}

function Test-OwnedStartupShortcut {
    $shortcut = Get-StartupShortcutInfo
    if ($null -eq $shortcut) {
        return $false
    }

    $isPowerShell7 = [System.IO.Path]::GetFileName($shortcut.TargetPath) -ieq 'pwsh.exe'
    $isClickerScript = $shortcut.Arguments.IndexOf(
        $script:scriptPath,
        [System.StringComparison]::OrdinalIgnoreCase) -ge 0
    $startsAutomatically = $shortcut.Arguments -match '(?i)(?:^|\s)-AutoStart(?:\s|$)'
    return $isPowerShell7 -and $isClickerScript -and $startsAutomatically
}

function Test-CurrentAutoStartShortcut {
    return Test-OwnedStartupShortcut
}

function Install-AutoStartShortcut {
    if ($script:selectedOperator -notin $script:validOperators) {
        throw '请先选择移动、电信或联通，再开启开机自启。'
    }

    if ((Test-Path -LiteralPath $script:startupShortcutPath) -and -not (Test-OwnedStartupShortcut)) {
        throw '启动文件夹中已有同名的非本工具快捷方式；为避免覆盖它，未开启开机自启。'
    }

    $powerShellPath = (Get-Command pwsh.exe -ErrorAction Stop).Source
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($script:startupShortcutPath)
    $quotedScriptPath = [char]34 + $script:scriptPath + [char]34
    $shortcut.TargetPath = $powerShellPath
    $shortcut.Arguments = "-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File $quotedScriptPath -AutoStart"
    $shortcut.WorkingDirectory = Split-Path -Parent $script:scriptPath
    $shortcut.Description = '登录 Windows 后按已保存的运营商自动连接江西师范大学校园网'
    $shortcut.Save()
}

function Remove-AutoStartShortcut {
    if (-not (Test-Path -LiteralPath $script:startupShortcutPath)) {
        return
    }

    if (-not (Test-OwnedStartupShortcut)) {
        throw '启动文件夹中的同名文件不是本工具创建的快捷方式；为避免误删，未移除。'
    }

    Remove-Item -LiteralPath $script:startupShortcutPath
}

try {
    $script:selectedOperator = Get-SavedOperator
    $script:autoStartConfigured = Test-CurrentAutoStartShortcut
} catch {
    $script:settingsLoadError = $_.Exception.Message
}

if ($AutoStart -and ($script:selectedOperator -notin $script:validOperators)) {
    $message = "自动连接未启动：无法读取已保存的运营商设置。请手动打开工具，重新选择运营商并检查开机自启。"
    if ($script:settingsLoadError) {
        $message += [Environment]::NewLine + [Environment]::NewLine + $script:settingsLoadError
    }
    [System.Windows.Forms.MessageBox]::Show(
        $message,
        '校园网自动连接',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
    exit 1
}

if (-not ('CoordinateClicker.NativeMethods' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace CoordinateClicker {
    public static class NativeMethods {
        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool SetCursorPos(int x, int y);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extraInfo);

        [DllImport("user32.dll")]
        public static extern bool SetProcessDPIAware();

        [DllImport("user32.dll")]
        public static extern IntPtr GetForegroundWindow();

        [DllImport("user32.dll")]
        public static extern bool SetForegroundWindow(IntPtr hWnd);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool SetWindowPos(
            IntPtr hWnd,
            IntPtr hWndInsertAfter,
            int x,
            int y,
            int cx,
            int cy,
            uint flags);

        [DllImport("user32.dll", EntryPoint = "GetWindowLongPtr", SetLastError = true)]
        public static extern IntPtr GetWindowLongPtr(IntPtr hWnd, int nIndex);

        [DllImport("user32.dll", EntryPoint = "SetWindowLongPtr", SetLastError = true)]
        public static extern IntPtr SetWindowLongPtr(IntPtr hWnd, int nIndex, IntPtr newStyle);

        public static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
        public const int GWL_EXSTYLE = -20;
        public const long WS_EX_NOACTIVATE = 0x08000000L;
        public const long WS_EX_TOOLWINDOW = 0x00000080L;
        public const uint SWP_NOACTIVATE = 0x0010;
        public const uint SWP_SHOWWINDOW = 0x0040;
    }
}
'@
}

[void][CoordinateClicker.NativeMethods]::SetProcessDPIAware()

$script:networkStartClicks = @(
    [pscustomobject]@{ X = 1793; Y = 1049 },
    [pscustomobject]@{ X = 1633; Y = 737 },
    [pscustomobject]@{ X = 1655; Y = 737 }
)

$script:operatorMenuClick = [pscustomobject]@{ X = 1341; Y = 356 }
$script:operatorClicks = @{
    '移动' = [pscustomobject]@{ X = 1336; Y = 400 }
    '电信' = [pscustomobject]@{ X = 1334; Y = 424 }
}
$script:portalActionClicks = @(
    [pscustomobject]@{ X = 1037; Y = 619 },
    [pscustomobject]@{ X = 1107; Y = 681 },
    [pscustomobject]@{ X = 1894; Y = 14 }
)
$script:activePoints = @()

$form = New-Object System.Windows.Forms.Form
$form.Text = '江西师范大学 校园网坐标点击器'
$form.StartPosition = 'CenterScreen'
$form.ClientSize = New-Object System.Drawing.Size(500, 390)
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.MinimizeBox = $true
$form.BackColor = [System.Drawing.Color]::FromArgb(247, 249, 252)

$title = New-Object System.Windows.Forms.Label
$title.Text = '校园网坐标点击器'
$title.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 17, [System.Drawing.FontStyle]::Bold)
$title.ForeColor = [System.Drawing.Color]::FromArgb(29, 53, 87)
$title.AutoSize = $true
$title.Location = New-Object System.Drawing.Point(155, 22)
$form.Controls.Add($title)

$hint = New-Object System.Windows.Forms.Label
$hint.Text = "请先点击开始$([Environment]::NewLine)启动后等待 $InitialDelaySeconds 秒；普通间隔 $ClickDelaySeconds 秒，第三次点击后等待 $AfterThirdClickDelaySeconds 秒"
$hint.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9)
$hint.ForeColor = [System.Drawing.Color]::FromArgb(90, 105, 120)
$hint.AutoSize = $false
$hint.TextAlign = 'MiddleCenter'
$hint.Size = New-Object System.Drawing.Size(430, 48)
$hint.Location = New-Object System.Drawing.Point(35, 62)
$form.Controls.Add($hint)

$operatorGroup = New-Object System.Windows.Forms.GroupBox
$operatorGroup.Text = '选择校园卡运营商'
$operatorGroup.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9)
$operatorGroup.Size = New-Object System.Drawing.Size(430, 58)
$operatorGroup.Location = New-Object System.Drawing.Point(35, 118)
$form.Controls.Add($operatorGroup)

$mobileRadio = New-Object System.Windows.Forms.RadioButton
$mobileRadio.Text = '移动'
$mobileRadio.AutoSize = $true
$mobileRadio.Location = New-Object System.Drawing.Point(38, 25)
$operatorGroup.Controls.Add($mobileRadio)

$telecomRadio = New-Object System.Windows.Forms.RadioButton
$telecomRadio.Text = '电信'
$telecomRadio.AutoSize = $true
$telecomRadio.Location = New-Object System.Drawing.Point(180, 25)
$operatorGroup.Controls.Add($telecomRadio)

$unicomRadio = New-Object System.Windows.Forms.RadioButton
$unicomRadio.Text = '联通'
$unicomRadio.AutoSize = $true
$unicomRadio.Location = New-Object System.Drawing.Point(322, 25)
$operatorGroup.Controls.Add($unicomRadio)

$script:operatorOptions = @($mobileRadio, $telecomRadio, $unicomRadio)

$autoStartCheckBox = New-Object System.Windows.Forms.CheckBox
$autoStartCheckBox.Text = '开机自启（登录 Windows 后按所选运营商自动连接）'
$autoStartCheckBox.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9)
$autoStartCheckBox.AutoSize = $true
$autoStartCheckBox.Location = New-Object System.Drawing.Point(35, 184)
$autoStartCheckBox.Checked = $script:autoStartConfigured
$autoStartCheckBox.Enabled = $script:selectedOperator -in $script:validOperators
$form.Controls.Add($autoStartCheckBox)

switch ($script:selectedOperator) {
    '移动' { $mobileRadio.Checked = $true }
    '电信' { $telecomRadio.Checked = $true }
    '联通' { $unicomRadio.Checked = $true }
}

$startButton = New-Object System.Windows.Forms.Button
$startButton.Text = '一键连接校园网'
$startButton.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 14, [System.Drawing.FontStyle]::Bold)
$startButton.ForeColor = [System.Drawing.Color]::White
$startButton.BackColor = [System.Drawing.Color]::FromArgb(22, 119, 153)
$startButton.FlatStyle = 'Flat'
$startButton.FlatAppearance.BorderSize = 0
$startButton.Size = New-Object System.Drawing.Size(280, 62)
$startButton.Location = New-Object System.Drawing.Point(110, 215)
$startButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$startButton.Enabled = $script:selectedOperator -in $script:validOperators
$form.Controls.Add($startButton)

$stopButton = New-Object System.Windows.Forms.Button
$stopButton.Text = '停止'
$stopButton.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9)
$stopButton.Size = New-Object System.Drawing.Size(80, 30)
$stopButton.Location = New-Object System.Drawing.Point(210, 286)
$stopButton.Enabled = $false
$form.Controls.Add($stopButton)

$status = New-Object System.Windows.Forms.Label
$status.Text = if ($script:settingsLoadError) {
    "配置读取异常：$($script:settingsLoadError)"
} elseif ($script:selectedOperator) {
    "已记住运营商：$($script:selectedOperator)。"
} else {
    '请先选择运营商；选择会自动保存。'
}
$status.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9)
$status.ForeColor = [System.Drawing.Color]::FromArgb(90, 105, 120)
$status.AutoSize = $false
$status.TextAlign = 'MiddleCenter'
$status.Size = New-Object System.Drawing.Size(430, 42)
$status.Location = New-Object System.Drawing.Point(35, 328)
$form.Controls.Add($status)

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 100
$script:phase = 'idle'
$script:index = 0
$script:nextActionAt = $null
$script:waitOverlay = $null
$script:waitOverlayLabel = $null

function Close-WaitOverlay {
    if ($null -ne $script:waitOverlay) {
        $script:waitOverlay.Close()
        $script:waitOverlay.Dispose()
        $script:waitOverlay = $null
        $script:waitOverlayLabel = $null
    }
}

function Show-WaitOverlay {
    param([Parameter(Mandatory = $true)][int]$Seconds)

    Close-WaitOverlay

    $previousForeground = [CoordinateClicker.NativeMethods]::GetForegroundWindow()
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $overlay = New-Object System.Windows.Forms.Form
    $overlay.FormBorderStyle = 'None'
    $overlay.StartPosition = 'Manual'
    $overlay.Bounds = $screen
    $overlay.BackColor = [System.Drawing.Color]::FromArgb(24, 31, 42)
    $overlay.Opacity = 0.8
    $overlay.ShowInTaskbar = $false
    $overlay.TopMost = $true
    $overlay.ControlBox = $false

    $label = New-Object System.Windows.Forms.Label
    $label.Dock = 'Fill'
    $label.TextAlign = 'MiddleCenter'
    $label.ForeColor = [System.Drawing.Color]::White
    $label.BackColor = [System.Drawing.Color]::Transparent
    $label.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 38, [System.Drawing.FontStyle]::Bold)
    $label.Text = "等待页面响应`r`n$Seconds"
    $overlay.Controls.Add($label)

    $script:waitOverlay = $overlay
    $script:waitOverlayLabel = $label
    $overlayStyle = [CoordinateClicker.NativeMethods]::GetWindowLongPtr($overlay.Handle, [CoordinateClicker.NativeMethods]::GWL_EXSTYLE).ToInt64()
    $overlayStyle = $overlayStyle -bor [CoordinateClicker.NativeMethods]::WS_EX_NOACTIVATE -bor [CoordinateClicker.NativeMethods]::WS_EX_TOOLWINDOW
    [void][CoordinateClicker.NativeMethods]::SetWindowLongPtr(
        $overlay.Handle,
        [CoordinateClicker.NativeMethods]::GWL_EXSTYLE,
        [IntPtr]$overlayStyle)
    $overlay.Show()
    [void][CoordinateClicker.NativeMethods]::SetWindowPos(
        $overlay.Handle,
        [CoordinateClicker.NativeMethods]::HWND_TOPMOST,
        $screen.X,
        $screen.Y,
        $screen.Width,
        $screen.Height,
        [CoordinateClicker.NativeMethods]::SWP_NOACTIVATE -bor [CoordinateClicker.NativeMethods]::SWP_SHOWWINDOW)
    if ($previousForeground -ne [IntPtr]::Zero) {
        [void][CoordinateClicker.NativeMethods]::SetForegroundWindow($previousForeground)
    }
}

function Update-WaitOverlay {
    param([Parameter(Mandatory = $true)][int]$RemainingSeconds)

    if ($null -ne $script:waitOverlayLabel) {
        $script:waitOverlayLabel.Text = "等待页面响应`r`n$RemainingSeconds"
    }
}

function Stop-Sequence {
    $timer.Stop()
    Close-WaitOverlay
    $script:phase = 'idle'
    $script:index = 0
    $startButton.Enabled = $true
    $stopButton.Enabled = $false
    foreach ($option in $script:operatorOptions) { $option.Enabled = $true }
    $status.Text = '已停止，准备就绪。'
}

function Invoke-PointClick {
    param([Parameter(Mandatory = $true)]$Point)

    if (-not [CoordinateClicker.NativeMethods]::SetCursorPos([int]$Point.X, [int]$Point.Y)) {
        throw "无法移动鼠标到 X=$($Point.X), Y=$($Point.Y)"
    }

    Start-Sleep -Milliseconds 120
    [CoordinateClicker.NativeMethods]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
    [CoordinateClicker.NativeMethods]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
}

$mobileRadio.Add_CheckedChanged({
    if ($mobileRadio.Checked) {
        try {
            Save-SelectedOperator -Operator '移动'
            $startButton.Enabled = $true
            $autoStartCheckBox.Enabled = $true
            $status.Text = '已保存运营商：移动。'
        } catch {
            $startButton.Enabled = $false
            $autoStartCheckBox.Enabled = $false
            [System.Windows.Forms.MessageBox]::Show(
                "无法保存运营商设置：$($_.Exception.Message)",
                '校园网坐标点击器',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        }
    }
})

$telecomRadio.Add_CheckedChanged({
    if ($telecomRadio.Checked) {
        try {
            Save-SelectedOperator -Operator '电信'
            $startButton.Enabled = $true
            $autoStartCheckBox.Enabled = $true
            $status.Text = '已保存运营商：电信。'
        } catch {
            $startButton.Enabled = $false
            $autoStartCheckBox.Enabled = $false
            [System.Windows.Forms.MessageBox]::Show(
                "无法保存运营商设置：$($_.Exception.Message)",
                '校园网坐标点击器',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        }
    }
})

$unicomRadio.Add_CheckedChanged({
    if ($unicomRadio.Checked) {
        try {
            Save-SelectedOperator -Operator '联通'
            $startButton.Enabled = $true
            $autoStartCheckBox.Enabled = $true
            $status.Text = '已保存运营商：联通。'
        } catch {
            $startButton.Enabled = $false
            $autoStartCheckBox.Enabled = $false
            [System.Windows.Forms.MessageBox]::Show(
                "无法保存运营商设置：$($_.Exception.Message)",
                '校园网坐标点击器',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        }
    }
})

$script:suppressAutoStartChange = $false
$autoStartCheckBox.Add_CheckedChanged({
    if ($script:suppressAutoStartChange) {
        return
    }

    try {
        if ($autoStartCheckBox.Checked) {
            Install-AutoStartShortcut
            $status.Text = "开机自启已启用：登录 Windows 后自动连接$($script:selectedOperator)校园宽带。"
        } else {
            Remove-AutoStartShortcut
            $status.Text = '开机自启已关闭。'
        }
    } catch {
        $script:suppressAutoStartChange = $true
        $autoStartCheckBox.Checked = -not $autoStartCheckBox.Checked
        $script:suppressAutoStartChange = $false
        [System.Windows.Forms.MessageBox]::Show(
            $_.Exception.Message,
            '开机自启设置失败',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
    }
})

$startButton.Add_Click({
    if ($script:phase -ne 'idle') { return }

    if ($script:selectedOperator -notin $script:validOperators) {
        [System.Windows.Forms.MessageBox]::Show(
            '请先选择移动、电信或联通。',
            '校园网坐标点击器',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        return
    }

    $activePoints = [System.Collections.Generic.List[object]]::new()
    foreach ($point in $script:networkStartClicks) { $activePoints.Add($point) }
    if ($script:selectedOperator -ne '联通') {
        $activePoints.Add($script:operatorMenuClick)
        $activePoints.Add($script:operatorClicks[$script:selectedOperator])
    }
    foreach ($point in $script:portalActionClicks) { $activePoints.Add($point) }
    $script:activePoints = $activePoints
    foreach ($option in $script:operatorOptions) { $option.Enabled = $false }

    $script:phase = 'initial'
    $script:index = 0
    $script:nextActionAt = (Get-Date).AddSeconds([Math]::Max(0, $InitialDelaySeconds))
    $startButton.Enabled = $false
    $stopButton.Enabled = $true
    $status.Text = "准备连接：$($script:selectedOperator)校园宽带；共 $($script:activePoints.Count) 次点击。"
    $timer.Start()
})

$stopButton.Add_Click({ Stop-Sequence })

$timer.Add_Tick({
    try {
        $now = Get-Date

        if ($script:phase -eq 'initial') {
            $remaining = [Math]::Ceiling(($script:nextActionAt - $now).TotalSeconds)
            if ($remaining -gt 0) {
                $status.Text = "准备开始，剩余 $remaining 秒..."
                return
            }
            $script:phase = 'clicking'
            $script:nextActionAt = $now
        }

        if ($script:phase -eq 'third-wait') {
            $remaining = [Math]::Ceiling(($script:nextActionAt - $now).TotalSeconds)
            if ($remaining -gt 0) {
                Update-WaitOverlay -RemainingSeconds $remaining
                $status.Text = "等待页面响应：$remaining 秒"
                return
            }

            Close-WaitOverlay
            $script:phase = 'clicking'
            $script:nextActionAt = $now
        }

        if ($script:phase -eq 'clicking' -and $now -ge $script:nextActionAt) {
            if ($script:index -ge $script:activePoints.Count) {
                $timer.Stop()
                Close-WaitOverlay
                $script:phase = 'idle'
                $startButton.Enabled = $true
                $stopButton.Enabled = $false
                $status.Text = "已完成 $($script:activePoints.Count) 次坐标点击（$($script:selectedOperator)）。"
                $form.Close()
                return
            }

            $point = $script:activePoints[$script:index]
            $current = $script:index + 1
            Invoke-PointClick -Point $point
            $script:index++
            $waitSeconds = $ClickDelaySeconds
            if ($current -eq 3) {
                $waitSeconds = $AfterThirdClickDelaySeconds
                Show-WaitOverlay -Seconds $waitSeconds
                $script:phase = 'third-wait'
                $status.Text = "等待页面响应：$waitSeconds 秒"
            } else {
                $status.Text = "已点击 $current/$($script:activePoints.Count)：X=$($point.X), Y=$($point.Y)"
            }
            $script:nextActionAt = (Get-Date).AddSeconds([Math]::Max(0, $waitSeconds))
        }
    } catch {
        $timer.Stop()
        Close-WaitOverlay
        $script:phase = 'idle'
        $startButton.Enabled = $true
        $stopButton.Enabled = $false
        foreach ($option in $script:operatorOptions) { $option.Enabled = $true }
        $status.Text = "点击失败：$($_.Exception.Message)"
    }
})

$form.Add_FormClosing({
    $timer.Stop()
    Close-WaitOverlay
})

if ($AutoStart) {
    $form.StartPosition = 'Manual'
    $form.Location = New-Object System.Drawing.Point(20, 20)
    $form.Add_Shown({
        $status.Text = "开机自启：即将自动连接$($script:selectedOperator)校园宽带。"
        $startButton.PerformClick()
    })
}

[void]$form.ShowDialog()
exit 0
