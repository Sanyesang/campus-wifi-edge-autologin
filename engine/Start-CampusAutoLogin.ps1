[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = (Join-Path $PSScriptRoot '..\schools\jxnu.json'),
    [ValidateSet('one-click', 'automatic')]
    [string]$Mode = 'one-click',
    [switch]$ForceOpen,
    [int]$WaitSeconds = 180
)

$ErrorActionPreference = 'SilentlyContinue'

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "找不到学校配置：$ConfigPath"
}

$Config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
$PortalUrl = [string]$Config.portalUrl
$TargetSsid = [string]$Config.ssid
$BypassList = (@($Config.bypassHosts) -join ';')
$CheckUrl = [string]$Config.internetCheck.url
$ExpectedStatus = [string]$Config.internetCheck.expectedStatus
$ProfileId = [string]$Config.id
$CoordinateAutomation = $Config.coordinateAutomation
$CoordinateClicksEnabled = $CoordinateAutomation -and $CoordinateAutomation.enabled -eq $true

$LogDir = Join-Path $env:LOCALAPPDATA 'CampusAutoLogin'
$LogPath = Join-Path $LogDir "$ProfileId.log"
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

function Write-Status([string]$Message) {
    Add-Content -LiteralPath $LogPath -Value ("{0:u} {1}" -f (Get-Date), $Message) -Encoding UTF8
}

function Get-WlanState {
    $text = netsh wlan show interfaces 2>$null | Out-String
    $ssid = [regex]::Match($text, '(?m)^\s*SSID\s*:\s*(.+?)\s*$').Groups[1].Value.Trim()
    $state = [regex]::Match($text, '(?m)^\s*State\s*:\s*(.+?)\s*$').Groups[1].Value.Trim()
    [pscustomobject]@{ SSID = $ssid; State = $state }
}

function Test-Internet {
    # 绕过系统 HTTP 代理；不会关闭 Clash TUN。
    $code = & curl.exe --noproxy '*' --silent --show-error --max-time 5 `
        --output NUL --write-out '%{http_code}' $CheckUrl 2>$null
    return ($code -eq $ExpectedStatus)
}

function Get-EdgePath {
    $candidates = @(
        (Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'),
        (Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\Application\msedge.exe')
    )
    return $candidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
}

function Invoke-CoordinateClickSequence {
    param(
        [Parameter(Mandatory = $true)]$Automation
    )

    if (-not ('CampusAutoLogin.NativeMethods' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace CampusAutoLogin {
    public static class NativeMethods {
        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool SetCursorPos(int x, int y);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extraInfo);
    }
}
'@
    }

    $initialDelay = [int]$Automation.initialDelaySeconds
    $clickDelay = [int]$Automation.delaySeconds
    $postThirdClickDelay = [int]$Automation.postThirdClickDelaySeconds
    if ($initialDelay -gt 0) { Start-Sleep -Seconds $initialDelay }

    $index = 0
    foreach ($point in @($Automation.clicks)) {
        $index++
        $x = [int]$point.x
        $y = [int]$point.y
        Write-Status ("coordinate click {0}: X={1}, Y={2}" -f $index, $x, $y)
        if (-not [CampusAutoLogin.NativeMethods]::SetCursorPos($x, $y)) {
            throw "无法移动鼠标到坐标 X=$x, Y=$y"
        }
        Start-Sleep -Milliseconds 120
        [CampusAutoLogin.NativeMethods]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
        [CampusAutoLogin.NativeMethods]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
        if ($index -lt @($Automation.clicks).Count) {
            $waitSeconds = $clickDelay
            if ($index -eq 3 -and $postThirdClickDelay -gt 0) {
                $waitSeconds = $postThirdClickDelay
                Write-Status ("after third click: waiting {0}s for browser page" -f $waitSeconds)
            }
            if ($waitSeconds -gt 0) {
                Start-Sleep -Seconds $waitSeconds
            }
        }
    }
    Write-Status ("coordinate click sequence finished: count={0}, delay={1}s, afterThirdClickDelay={2}s" -f $index, $clickDelay, $postThirdClickDelay)
}

Write-Status ("started profile={0} mode={1} portal={2} coordinateEnabled={3} initialDelay={4}s clickDelay={5}s afterThirdClickDelay={6}s" -f `
        $ProfileId, $Mode, $PortalUrl, $CoordinateClicksEnabled, $CoordinateAutomation.initialDelaySeconds, $CoordinateAutomation.delaySeconds, $CoordinateAutomation.postThirdClickDelaySeconds)
$deadline = (Get-Date).AddSeconds($WaitSeconds)
do {
    $wlan = Get-WlanState
    if ($wlan.SSID -eq $TargetSsid -and $wlan.State -eq 'connected') { break }
    Start-Sleep -Seconds 2
} while ((Get-Date) -lt $deadline)

$wlan = Get-WlanState
if ($wlan.SSID -ne $TargetSsid -or $wlan.State -ne 'connected') {
    Write-Status ("skip: WLAN not connected (SSID={0}, State={1})" -f $wlan.SSID, $wlan.State)
    exit 2
}

if (-not $ForceOpen -and (Test-Internet)) {
    Write-Status 'skip: internet already available'
    exit 0
}

$edge = Get-EdgePath
if (-not $edge) {
    Write-Status 'error: Microsoft Edge executable not found'
    exit 2
}

$args = @('--new-tab')
if ($BypassList) { $args += "--proxy-bypass-list=$BypassList" }
$args += $PortalUrl
Start-Process -FilePath $edge -ArgumentList $args | Out-Null
Write-Status 'opened portal in Edge'

# 坐标模式由本地鼠标点击完成；本脚本不读取、保存或输出账号密码。
if ($CoordinateClicksEnabled -and -not $ForceOpen) {
    try {
        Invoke-CoordinateClickSequence -Automation $CoordinateAutomation
    } catch {
        Write-Status ("coordinate click sequence failed: {0}" -f $_.Exception.Message)
        exit 2
    }
} elseif ($CoordinateClicksEnabled -and $ForceOpen) {
    Write-Status 'force-open mode: skipped coordinate click sequence'
} else {
    # 非坐标模式由浏览器用户脚本负责选择运营商和提交。
    Write-Status 'waiting for browser userscript to submit'
}

$checkDeadline = (Get-Date).AddSeconds(90)
do {
    Start-Sleep -Seconds 3
    if (Test-Internet) {
        Write-Status 'internet became available'
        exit 0
    }
} while ((Get-Date) -lt $checkDeadline)

Write-Status 'timeout waiting for authenticated internet'
exit 1
