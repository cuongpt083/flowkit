# Twin of skills/fk-refresh-urls.md
param(
    [Parameter(Mandatory = $true)][string]$VideoId,
    [string]$ProjectId
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'FkCommon.psm1') -Force

$flow = Invoke-FkApi -Method GET -Path '/api/flow/status'
$connected = [bool](Get-FkProp $flow 'connected')
$key = Get-FkProp $flow 'flow_key_present'
if (-not $connected -or -not $key) {
    throw 'Extension not connected or flow_key_present is false. Open/refresh a Google Flow tab in Chrome.'
}

$video = Invoke-FkApi -Method GET -Path ('/api/videos/' + $VideoId)
$projectId = $ProjectId
if ([string]::IsNullOrWhiteSpace($projectId)) {
    $projectId = [string](Get-FkProp $video 'project_id')
}
Write-Host ("Project: {0}  Video: {1}" -f $projectId, $VideoId)

$result = Invoke-FkApi -Method POST -Path ('/api/flow/refresh-urls/' + $projectId)
Write-Host ("Refreshed: {0} URLs (found {1} total)" -f (Get-FkProp $result 'refreshed' 0), (Get-FkProp $result 'found' 0))
$err = Get-FkProp $result 'error'
if ($err) { Write-Host ("ERROR: {0}" -f $err) }

$scenes = ConvertTo-FkArray (Invoke-FkApi -Method GET -Path ('/api/scenes?video_id=' + [uri]::EscapeDataString($VideoId)))
$ori = 'horizontal'
foreach ($s in $scenes) {
    if ((Get-FkProp $s 'vertical_video_status') -eq 'COMPLETED' -and (Get-FkProp $s 'vertical_video_url')) {
        $ori = 'vertical'
        break
    }
    if ((Get-FkProp $s 'horizontal_video_status') -eq 'COMPLETED' -and (Get-FkProp $s 'horizontal_video_url')) {
        $ori = 'horizontal'
        break
    }
}
$ok = 0
$expired = 0
$now = [int64](((Get-Date).ToUniversalTime() - [datetime]'1970-01-01').TotalSeconds)
foreach ($s in $scenes) {
    $url = [string](Get-FkProp $s ($ori + '_video_url') '')
    if ([string]::IsNullOrWhiteSpace($url)) { $expired++; continue }
    if ($url -match 'Expires=(\d+)') {
        $exp = [int64]$Matches[1]
        if ($exp -gt $now) { $ok++ } else { $expired++ }
    }
    else { $ok++ }
}
Write-Host ("Orientation: {0}" -f $ori.ToUpperInvariant())
Write-Host ("Valid URLs: {0}/{1}" -f $ok, $scenes.Count)
if ($expired -gt 0) {
    Write-Host ("Still expired/missing: {0} - open the Flow project tab, then retry." -f $expired)
}
else {
    Write-Host 'All URLs refreshed successfully!'
}
