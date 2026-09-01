# Twin of skills/fk-gen-chain-videos.md — patch child image as endImage, then GENERATE_VIDEO
param(
    [Parameter(Mandatory = $true)][string]$ProjectId,
    [string]$VideoId,
    [int]$PollSeconds = 180
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'FkCommon.psm1') -Force

Invoke-FkHealth -RequireExtension | Out-Null
$pid = $ProjectId
$video = Resolve-FkVideo -ProjectId $pid -VideoId $VideoId
$vid = [string](Get-FkProp $video 'id')
$ori = Get-FkOrientation -Video $video
$prefix = Get-FkFieldPrefix $ori
$endField = $prefix + '_end_scene_media_id'
$imgField = $prefix + '_image_media_id'

$scenes = ConvertTo-FkArray (Invoke-FkApi -Method GET -Path ('/api/scenes?video_id=' + [uri]::EscapeDataString($vid)))
foreach ($s in $scenes) {
    $mid = [string](Get-FkProp $s $imgField '')
    if (-not (Test-FkUuid $mid)) {
        throw ("ABORT: scene {0} missing UUID image media_id. Run /fk-gen-images first." -f (Get-FkProp $s 'id'))
    }
}

$childOf = @{}
foreach ($s in $scenes) {
    $parent = Get-FkProp $s 'parent_scene_id'
    if ($parent) {
        $childOf[[string]$parent] = $s
    }
}

Write-Host 'Patching end_scene_media_id (child image, not parent)...'
foreach ($s in $scenes) {
    $sid = [string](Get-FkProp $s 'id')
    if ($childOf.ContainsKey($sid)) {
        $child = $childOf[$sid]
        $childImg = [string](Get-FkProp $child $imgField)
        $body = @{}
        $body[$endField] = $childImg
        Invoke-FkApi -Method PATCH -Path ('/api/scenes/' + $sid) -Body $body | Out-Null
        Write-Host ("  {0} endImage <- child {1}" -f $sid, (Get-FkProp $child 'id'))
    }
}

& (Join-Path $PSScriptRoot 'fk-gen-videos.ps1') -ProjectId $pid -VideoId $vid -PollSeconds $PollSeconds
Write-Host 'Chained videos ready. Check concat gaps — trim 0.4-0.7s overlap at chain boundaries if needed.'
