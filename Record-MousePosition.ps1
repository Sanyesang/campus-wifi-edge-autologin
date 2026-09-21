[CmdletBinding()]
param(
    [string]$HistoryPath = '',
    [int]$PollMilliseconds = 30,
    [int]$RunSeconds = 0
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($HistoryPath)) {
    $HistoryPath = Join-Path -Path $PSScriptRoot -ChildPath 'mouse-positions.txt'
}

if ($PollMilliseconds -lt 10) {
    $PollMilliseconds = 10
}

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class CampusMouseRecorderNative
{
    [StructLayout(LayoutKind.Sequential)]
    public struct POINT
    {
        public int X;
        public int Y;
    }

    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int virtualKey);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool GetCursorPos(out POINT point);
}
'@

Add-Type -AssemblyName System.Windows.Forms

function Test-KeyDown {
    param([int]$VirtualKey)

    return (([CampusMouseRecorderNative]::GetAsyncKeyState($VirtualKey) -band 0x8000) -ne 0)
}

function Set-ClipboardText {
    param([Parameter(Mandatory = $true)][string]$Text)

    try {
        [System.Windows.Forms.Clipboard]::SetText($Text)
        return
    } catch {
        # clip.exe is a fallback when the PowerShell host cannot access the
        # Windows clipboard through System.Windows.Forms.
        $Text | & "$env:SystemRoot\System32\clip.exe"
    }
}

$HistoryPath = [System.IO.Path]::GetFullPath($HistoryPath)
$historyDirectory = Split-Path -Parent $HistoryPath
if ($historyDirectory) {
    New-Item -ItemType Directory -Path $historyDirectory -Force | Out-Null
}

Write-Host 'Mouse coordinate recorder started.' -ForegroundColor Cyan
Write-Host 'Press F1 to copy the current cursor position and append it to mouse-positions.txt.' -ForegroundColor White
Write-Host 'Press Esc to exit.' -ForegroundColor Yellow
Write-Host ("History file: {0}" -f $HistoryPath) -ForegroundColor DarkGray

$lastF1Down = $false
$lastEscapeDown = $false
$f1Key = 0x70
$escapeKey = 0x1B
$deadline = if ($RunSeconds -gt 0) { (Get-Date).AddSeconds($RunSeconds) } else { $null }

try {
    while ($true) {
        $f1Down = Test-KeyDown -VirtualKey $f1Key
        $escapeDown = Test-KeyDown -VirtualKey $escapeKey

        if ($f1Down -and -not $lastF1Down) {
            $point = New-Object CampusMouseRecorderNative+POINT
            if ([CampusMouseRecorderNative]::GetCursorPos([ref]$point)) {
                $clipboardValue = 'X={0}, Y={1}' -f $point.X, $point.Y
                $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff zzz')
                Set-ClipboardText -Text $clipboardValue
                Add-Content -LiteralPath $HistoryPath -Value ("{0}`t{1}" -f $timestamp, $clipboardValue) -Encoding UTF8
                Write-Host ("[{0}] Copied: {1}" -f $timestamp, $clipboardValue) -ForegroundColor Green
            } else {
                Write-Warning 'Failed to read the cursor position.'
            }
        }

        if ($escapeDown -and -not $lastEscapeDown) {
            break
        }

        if ($deadline -and (Get-Date) -ge $deadline) {
            break
        }

        $lastF1Down = $f1Down
        $lastEscapeDown = $escapeDown
        Start-Sleep -Milliseconds $PollMilliseconds
    }
} finally {
    Write-Host 'Mouse coordinate recorder exited.' -ForegroundColor Cyan
}
