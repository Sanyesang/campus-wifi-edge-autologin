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

Write-Status "started profile=$ProfileId mode=$Mode"
$deadline = (Get-Date).AddSeconds($WaitSeconds)
do {
    $wlan = Get-WlanState
    if ($wlan.SSID -eq $TargetSsid -and $wlan.State -eq 'connected') { break }
    Start-Sleep -Seconds 2
} while ((Get-Date) -lt $deadline)

$wlan = Get-WlanState
if ($wlan.SSID -ne $TargetSsid -or $wlan.State -ne 'connected') {
    Write-Status ("skip: WLAN not connected (SSID={0}, State={1})" -f $wlan.SSID, $wlan.State)
    exit 0
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

# 浏览器用户脚本负责选择运营商和提交；本脚本不读取账号密码。
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
