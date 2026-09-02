# Twin of skills/fk-review-video.md
param(
    [Parameter(Mandatory = $true)][string]$VideoId,
    [string]$ProjectId,
    [ValidateSet('light', 'deep')][string]$Mode = 'light'
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'FkCommon.psm1') -Force

Invoke-FkHealth -RequireExtension | Out-Null
$video = Invoke-FkApi -Method GET -Path ('/api/videos/' + $VideoId)
$projectId = $ProjectId
if ([string]::IsNullOrWhiteSpace($projectId)) { $projectId = [string](Get-FkProp $video 'project_id') }
$ori = Get-FkOrientation -Video $video
$path = '/api/videos/' + $VideoId + '/review?project_id=' + [uri]::EscapeDataString($projectId) + '&mode=' + $Mode + '&orientation=' + $ori
Write-Host ("POST {0}" -f $path)
$r = Invoke-FkApi -Method POST -Path $path -TimeoutSec 600
Write-Host (ConvertTo-FkJson $r)
Write-Host 'Interpret scores using skills/fk-review-video.md. Prefer provider agy on Antigravity.'
