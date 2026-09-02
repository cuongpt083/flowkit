# Twin of skills/fk-create-project.md (execution only).
# Agent writes prompts in the skill markdown, then posts JSON here.
#
# JSON shape:
# {
#   "project": { "name", "story", "material", "render_mode", "characters": [...] },
#   "video": { "title" },
#   "scenes": [ { "display_order", "prompt", "video_prompt", "transition_prompt",
#                 "character_names": [], "chain_type", "parent_display_order" } ]
# }
# parent_display_order is resolved to parent_scene_id after scenes are created in order.
param(
    [string]$JsonPath,
    [switch]$ListMaterials
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'FkCommon.psm1') -Force

if ($ListMaterials) {
    $mats = Invoke-FkApi -Method GET -Path '/api/materials'
    Write-Host (ConvertTo-FkJson $mats)
    return
}

if ([string]::IsNullOrWhiteSpace($JsonPath)) {
    throw 'Pass -JsonPath to a UTF-8 JSON file (see script header), or -ListMaterials.'
}
if (-not (Test-Path -LiteralPath $JsonPath)) {
    throw "JSON not found: $JsonPath"
}

$spec = Read-FkJson -LiteralPath $JsonPath
$projectSpec = Get-FkProp $spec 'project'
if (-not $projectSpec) { throw 'JSON missing .project' }
$material = Get-FkProp $projectSpec 'material'
if ([string]::IsNullOrWhiteSpace([string]$material)) {
    throw 'project.material is required. GET /api/materials or -ListMaterials.'
}

Invoke-FkHealth -RequireExtension | Out-Null
$created = Invoke-FkApi -Method POST -Path '/api/projects' -Body $projectSpec
$projectId = [string](Get-FkProp $created 'id')
if (-not $projectId) { $projectId = [string](Get-FkProp $created 'project_id') }
Write-Host ("Project: {0}" -f $projectId)

$videoSpec = Get-FkProp $spec 'video'
if (-not $videoSpec) { $videoSpec = @{ title = (Get-FkProp $projectSpec 'name') } }
if ($videoSpec -is [hashtable]) {
    $videoSpec['project_id'] = $projectId
}
else {
    $ht = @{
        project_id = $projectId
        title      = (Get-FkProp $videoSpec 'title' (Get-FkProp $projectSpec 'name'))
    }
    $videoSpec = $ht
}
$video = Invoke-FkApi -Method POST -Path '/api/videos' -Body $videoSpec
$vid = [string](Get-FkProp $video 'id')
Write-Host ("Video:   {0}" -f $vid)

$orderToId = @{}
$scenesSpec = ConvertTo-FkArray (Get-FkProp $spec 'scenes')
$scenesSpec = @($scenesSpec | Sort-Object { Get-FkProp $_ 'display_order' })
foreach ($sc in $scenesSpec) {
    $order = [int](Get-FkProp $sc 'display_order' 0)
    $chain = [string](Get-FkProp $sc 'chain_type' 'ROOT')
    $parentOrder = Get-FkProp $sc 'parent_display_order'
    $parentId = Get-FkProp $sc 'parent_scene_id'
    if (-not $parentId -and $null -ne $parentOrder -and $orderToId.ContainsKey([int]$parentOrder)) {
        $parentId = $orderToId[[int]$parentOrder]
    }
    $body = @{
        video_id        = $vid
        display_order   = $order
        prompt          = [string](Get-FkProp $sc 'prompt')
        character_names = ConvertTo-FkArray (Get-FkProp $sc 'character_names')
        chain_type      = $chain
    }
    $vp = Get-FkProp $sc 'video_prompt'
    if ($vp) { $body['video_prompt'] = [string]$vp }
    $tp = Get-FkProp $sc 'transition_prompt'
    if ($tp) { $body['transition_prompt'] = [string]$tp }
    $nt = Get-FkProp $sc 'narrator_text'
    if ($nt) { $body['narrator_text'] = [string]$nt }
    if ($parentId) { $body['parent_scene_id'] = [string]$parentId }
    $row = Invoke-FkApi -Method POST -Path '/api/scenes' -Body $body
    $sid = [string](Get-FkProp $row 'id')
    $orderToId[$order] = $sid
    Write-Host ("  scene {0} {1} {2}" -f $order, $chain, $sid)
}

Invoke-FkApi -Method PUT -Path '/api/active-project' -Body @{ project_id = $projectId } | Out-Null
$ap = Invoke-FkApi -Method GET -Path '/api/active-project'
Write-Host ''
Write-Host ('Active project switched to: {0} ({1})' -f (Get-FkProp $ap 'project_name'), $projectId)
Write-Host ("Video:        {0}" -f $vid)
Write-Host ("Material:     {0}" -f $material)
Write-Host 'Next: /fk-gen-refs'
