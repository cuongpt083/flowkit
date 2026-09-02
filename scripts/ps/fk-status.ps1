# Twin of skills/fk-status.md — Windows PowerShell 5.1
param(
    [string]$ProjectId
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'FkCommon.psm1') -Force

$health = Invoke-FkHealth
Write-Host ("Health: {0}  extension_connected={1}" -f (Get-FkProp $health 'status'), (Get-FkProp $health 'extension_connected'))

if ([string]::IsNullOrWhiteSpace($ProjectId)) {
    $projects = ConvertTo-FkArray (Invoke-FkApi -Method GET -Path '/api/projects')
    Write-Host ''
    Write-Host ('{0,-36} {1,-32} {2,-10} {3}' -f 'ID', 'Name', 'Tier', 'Status')
    Write-Host ('-' * 100)
    foreach ($p in $projects) {
        Write-Host ('{0,-36} {1,-32} {2,-10} {3}' -f (Get-FkProp $p 'id'), (Get-FkProp $p 'name'), (Get-FkProp $p 'tier' '?'), (Get-FkProp $p 'status' '?'))
    }
    if ($projects.Count -eq 0) { Write-Host '(no projects)' }
    return
}

$projectId = $ProjectId
$proj = Invoke-FkApi -Method GET -Path ('/api/projects/' + $projectId)
Write-Host ''
Write-Host ("Project: {0} ({1})" -f (Get-FkProp $proj 'name'), $projectId)
Write-Host ("Material: {0}  render_mode={1}" -f (Get-FkProp $proj 'material'), (Get-FkProp $proj 'render_mode'))

$chars = ConvertTo-FkArray (Invoke-FkApi -Method GET -Path ('/api/projects/' + $projectId + '/characters'))
$refsReady = 0
Write-Host ''
Write-Host 'Entities'
Write-Host ('{0,-24} {1,-16} {2,-40} {3}' -f 'Name', 'Type', 'media_id', 'Ready')
foreach ($c in $chars) {
    $mid = [string](Get-FkProp $c 'media_id' '')
    $ok = Test-FkUuid $mid
    if ($ok) { $refsReady++ }
    $ready = 'NO'
    if ($ok) { $ready = 'YES' }
    Write-Host ('{0,-24} {1,-16} {2,-40} {3}' -f (Get-FkProp $c 'name'), (Get-FkProp $c 'entity_type'), $mid, $ready)
}

$videos = ConvertTo-FkArray (Invoke-FkApi -Method GET -Path ('/api/videos?project_id=' + [uri]::EscapeDataString($projectId)))
foreach ($v in $videos) {
    $vid = [string](Get-FkProp $v 'id')
    $ori = Get-FkOrientation -Video $v -Project $proj
    $prefix = Get-FkFieldPrefix $ori
    $scenes = ConvertTo-FkArray (Invoke-FkApi -Method GET -Path ('/api/scenes?video_id=' + [uri]::EscapeDataString($vid)))
    $scenes = @($scenes | Sort-Object { Get-FkProp $_ 'display_order' })
    $imgOk = 0; $vidOk = 0; $upOk = 0
    Write-Host ''
    Write-Host ("Video {0}  title={1}  Orientation: {2}" -f $vid, (Get-FkProp $v 'title'), $ori)
    Write-Host ('{0,4} {1,-12} {2,-14} {3,-14} {4,-14} {5}' -f '#', 'chain', 'image', 'video', 'upscale', 'prompt')
    foreach ($s in $scenes) {
        $img = [string](Get-FkProp $s ($prefix + '_image_status') '')
        $vo = [string](Get-FkProp $s ($prefix + '_video_status') '')
        $up = [string](Get-FkProp $s ($prefix + '_upscale_status') '')
        if ($img -eq 'COMPLETED') { $imgOk++ }
        if ($vo -eq 'COMPLETED') { $vidOk++ }
        if ($up -eq 'COMPLETED') { $upOk++ }
        $prompt = [string](Get-FkProp $s 'prompt' '')
        if ($prompt.Length -gt 50) { $prompt = $prompt.Substring(0, 50) }
        Write-Host ('{0,4} {1,-12} {2,-14} {3,-14} {4,-14} {5}' -f (Get-FkProp $s 'display_order'), (Get-FkProp $s 'chain_type'), $img, $vo, $up, $prompt)
    }
    $n = $scenes.Count
    Write-Host ''
    Write-Host ("Orientation: {0}" -f $ori)
    Write-Host ("Refs: {0}/{1}  Images: {2}/{3}  Videos: {4}/{3}  Upscale: {5}/{3}" -f $refsReady, $chars.Count, $imgOk, $n, $vidOk, $upOk)
    if ($refsReady -lt $chars.Count) {
        Write-Host ("Next: /fk-gen-refs {0}" -f $projectId)
    }
    elseif ($imgOk -lt $n) {
        Write-Host ("Next: /fk-gen-images {0} {1}" -f $projectId, $vid)
    }
    elseif ($vidOk -lt $n) {
        Write-Host ("Next: /fk-gen-videos {0} {1}" -f $projectId, $vid)
    }
    else {
        Write-Host ("Next: /fk-concat {0}" -f $vid)
    }
}

$pending = Invoke-FkApi -Method GET -Path '/api/requests/pending'
Write-Host ''
Write-Host ('Pending/processing: {0}' -f (ConvertTo-FkJson $pending))
