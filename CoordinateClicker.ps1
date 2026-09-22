[CmdletBinding()]
param(
    [int]$InitialDelaySeconds = 8,
    [int]$ClickDelaySeconds = 2,
    [int]$AfterThirdClickDelaySeconds = 8
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

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

$points = @(
    [pscustomobject]@{ X = 1793; Y = 1049 },
    [pscustomobject]@{ X = 1633; Y = 737 },
    [pscustomobject]@{ X = 1655; Y = 737 },
    [pscustomobject]@{ X = 1341; Y = 356 },
    [pscustomobject]@{ X = 1334; Y = 424 },
    [pscustomobject]@{ X = 1037; Y = 619 },
    [pscustomobject]@{ X = 1107; Y = 681 },
    [pscustomobject]@{ X = 1894; Y = 14 }
)

$form = New-Object System.Windows.Forms.Form
$form.Text = '江西师范大学 校园网坐标点击器'
$form.StartPosition = 'CenterScreen'
$form.ClientSize = New-Object System.Drawing.Size(500, 315)
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.MinimizeBox = $true
$form.BackColor = [System.Drawing.Color]::FromArgb(247, 249, 252)

$title = New-Object System.Windows.Forms.Label
$title.Text = '校园网坐标点击器'
$title.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 17, [System.Drawing.FontStyle]::Bold)
$title.ForeColor = [System.Drawing.Color]::FromArgb(29, 53, 87)
$title.AutoSize = $true
$title.Location = New-Object System.Drawing.Point(155, 28)
$form.Controls.Add($title)

$hint = New-Object System.Windows.Forms.Label
$hint.Text = "请先点击开始$([Environment]::NewLine)启动后等待 $InitialDelaySeconds 秒；普通间隔 $ClickDelaySeconds 秒，第三次点击后等待 $AfterThirdClickDelaySeconds 秒"
$hint.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9)
$hint.ForeColor = [System.Drawing.Color]::FromArgb(90, 105, 120)
$hint.AutoSize = $false
$hint.TextAlign = 'MiddleCenter'
$hint.Size = New-Object System.Drawing.Size(430, 45)
$hint.Location = New-Object System.Drawing.Point(35, 72)
$form.Controls.Add($hint)

$startButton = New-Object System.Windows.Forms.Button
$startButton.Text = '开始按坐标点击'
$startButton.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 14, [System.Drawing.FontStyle]::Bold)
$startButton.ForeColor = [System.Drawing.Color]::White
$startButton.BackColor = [System.Drawing.Color]::FromArgb(22, 119, 153)
$startButton.FlatStyle = 'Flat'
$startButton.FlatAppearance.BorderSize = 0
$startButton.Size = New-Object System.Drawing.Size(280, 62)
$startButton.Location = New-Object System.Drawing.Point(110, 130)
$startButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($startButton)

$stopButton = New-Object System.Windows.Forms.Button
$stopButton.Text = '停止'
$stopButton.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9)
$stopButton.Size = New-Object System.Drawing.Size(80, 30)
$stopButton.Location = New-Object System.Drawing.Point(210, 202)
$stopButton.Enabled = $false
$form.Controls.Add($stopButton)

$status = New-Object System.Windows.Forms.Label
$status.Text = '准备就绪。'
$status.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9)
$status.ForeColor = [System.Drawing.Color]::FromArgb(90, 105, 120)
$status.AutoSize = $false
$status.TextAlign = 'MiddleCenter'
$status.Size = New-Object System.Drawing.Size(430, 42)
$status.Location = New-Object System.Drawing.Point(35, 245)
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

$startButton.Add_Click({
    if ($script:phase -ne 'idle') { return }

    $script:phase = 'initial'
    $script:index = 0
    $script:nextActionAt = (Get-Date).AddSeconds([Math]::Max(0, $InitialDelaySeconds))
    $startButton.Enabled = $false
    $stopButton.Enabled = $true
    $status.Text = "准备开始，剩余 $InitialDelaySeconds 秒..."
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
            if ($script:index -ge $points.Count) {
                $timer.Stop()
                $script:phase = 'idle'
                $startButton.Enabled = $true
                $stopButton.Enabled = $false
                $status.Text = "已完成 $($points.Count) 次坐标点击。"
                return
            }

            $point = $points[$script:index]
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
                $status.Text = "已点击 $current/$($points.Count)：X=$($point.X), Y=$($point.Y)"
            }
            $script:nextActionAt = (Get-Date).AddSeconds([Math]::Max(0, $waitSeconds))
        }
    } catch {
        $timer.Stop()
        Close-WaitOverlay
        $script:phase = 'idle'
        $startButton.Enabled = $true
        $stopButton.Enabled = $false
        $status.Text = "点击失败：$($_.Exception.Message)"
    }
})

$form.Add_FormClosing({
    $timer.Stop()
    Close-WaitOverlay
})

[void]$form.ShowDialog()
