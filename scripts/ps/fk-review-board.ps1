# Twin of skills/fk-review-board.md
param(
    [string]$VideoId,
    [int]$Port = 8200
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'FkCommon.psm1') -Force

$vid = $VideoId
if ([string]::IsNullOrWhiteSpace($vid)) {
    $ap = Invoke-FkApi -Method GET -Path '/api/active-project'
    $vid = [string](Get-FkProp $ap 'video_id' '')
}
if ([string]::IsNullOrWhiteSpace($vid)) { throw 'Pass -VideoId or /fk-switch-project first.' }

$py = Get-FkPython
$root = Get-FkRoot
$server = Join-Path $root 'tools\review_server.py'
if (-not (Test-Path -LiteralPath $server)) { throw "missing $server" }

try {
    Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue | ForEach-Object {
        try { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue } catch { }
    }
}
catch { }

Start-Process -FilePath $py -ArgumentList @($server) -WorkingDirectory $root -WindowStyle Minimized
Start-Sleep -Seconds 2
$url = "http://127.0.0.1:$Port/?video_id=$vid"
Start-Process $url
Write-Host ("Review Board: {0}" -f $url)
