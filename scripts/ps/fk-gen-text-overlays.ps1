# Twin of skills/fk-gen-text-overlays.md — host writes JSON; this copies to OUTDIR.
param(
    [Parameter(Mandatory = $true)][string]$VideoId,
    [Parameter(Mandatory = $true)][string]$JsonPath
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'FkCommon.psm1') -Force

$video = Invoke-FkApi -Method GET -Path ('/api/videos/' + $VideoId)
$projectId = [string](Get-FkProp $video 'project_id')
$out = Resolve-FkOutputDir -ProjectId $projectId
$dest = Join-Path $out.Path 'text_overlays.json'
Copy-Item -LiteralPath $JsonPath -Destination $dest -Force
Write-Host ("Saved {0}" -f $dest)
Write-Host 'Overlay copy only. Host extracts dates/stats per skills/fk-gen-text-overlays.md'
