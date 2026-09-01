# Twin of skills/fk-fix-uuids.md
param(
    [Parameter(Mandatory = $true)][string]$ProjectId,
    [string]$VideoId
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'FkCommon.psm1') -Force

function Repair-FkId {
    param([string]$Current, [string]$Url)
    if (Test-FkUuid $Current) { return $null }
    if ([string]::IsNullOrWhiteSpace($Current) -and [string]::IsNullOrWhiteSpace($Url)) { return $null }
    $extracted = Get-FkUuidFromUrl $Url
    if (Test-FkUuid $extracted) { return $extracted }
    return $null
}

$fixes = New-Object System.Collections.Generic.List[string]
$chars = ConvertTo-FkArray (Invoke-FkApi -Method GET -Path ('/api/projects/' + $ProjectId + '/characters'))
foreach ($c in $chars) {
    $mid = [string](Get-FkProp $c 'media_id' '')
    $url = [string](Get-FkProp $c 'reference_image_url' '')
    $fresh = Repair-FkId -Current $mid -Url $url
    if ($fresh) {
        Invoke-FkApi -Method PATCH -Path ('/api/characters/' + (Get-FkProp $c 'id')) -Body @{ media_id = $fresh } | Out-Null
        $fixes.Add(('entity {0} media_id {1} -> {2}' -f (Get-FkProp $c 'name'), $mid, $fresh))
    }
}

$video = Resolve-FkVideo -ProjectId $ProjectId -VideoId $VideoId
$vid = [string](Get-FkProp $video 'id')
$ori = Get-FkOrientation -Video $video
$prefix = Get-FkFieldPrefix $ori
$fields = @(
    @(($prefix + '_image_media_id'), ($prefix + '_image_url')),
    @(($prefix + '_video_media_id'), ($prefix + '_video_url')),
    @(($prefix + '_upscale_media_id'), ($prefix + '_upscale_url'))
)
$scenes = ConvertTo-FkArray (Invoke-FkApi -Method GET -Path ('/api/scenes?video_id=' + [uri]::EscapeDataString($vid)))
foreach ($s in $scenes) {
    $patch = @{}
    foreach ($pair in $fields) {
        $fid = $pair[0]; $furl = $pair[1]
        $cur = [string](Get-FkProp $s $fid '')
        $url = [string](Get-FkProp $s $furl '')
        $fresh = Repair-FkId -Current $cur -Url $url
        if ($fresh) {
            $patch[$fid] = $fresh
            $fixes.Add(('scene {0} {1} {2} -> {3}' -f (Get-FkProp $s 'display_order'), $fid, $cur, $fresh))
        }
    }
    if ($patch.Count -gt 0) {
        Invoke-FkApi -Method PATCH -Path ('/api/scenes/' + (Get-FkProp $s 'id')) -Body $patch | Out-Null
    }
}

if ($fixes.Count -eq 0) {
    Write-Host 'All media_ids are already UUID format.'
}
else {
    Write-Host 'Fixes applied:'
    foreach ($f in $fixes) { Write-Host ('  ' + $f) }
}
