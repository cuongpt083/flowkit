# Twin of skills/fk-youtube-upload.md
param(
    [Parameter(Mandatory = $true)][string]$ChannelName,
    [switch]$Auth
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'FkCommon.psm1') -Force

$py = Get-FkPython
$root = Get-FkRoot
$auth = Join-Path $root 'youtube\auth.py'
if ($Auth -or -not (Test-Path -LiteralPath (Join-Path $root "youtube\channels\$ChannelName\token.json"))) {
    Write-Host "Running youtube/auth.py $ChannelName"
    & $py $auth $ChannelName
    if ($LASTEXITCODE -ne 0) { throw 'youtube/auth.py failed' }
}

Write-Host 'Auth ready. Host fills title/description/tags from /fk-youtube-seo, then calls youtube.upload.upload_video() as in skills/fk-youtube-upload.md (Python API, not bash).'
Write-Host ("Channel dir: {0}" -f (Join-Path $root "youtube\channels\$ChannelName"))
