# Twin of skills/fk-gen-images.md — wave ROOT GENERATE_IMAGE then CONTINUATION EDIT_IMAGE
param(
    [Parameter(Mandatory = $true)][string]$ProjectId,
    [string]$VideoId,
    [int]$PollSeconds = 15
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'FkCommon.psm1') -Force

Invoke-FkHealth -RequireExtension | Out-Null
$pid = $ProjectId
$video = Resolve-FkVideo -ProjectId $pid -VideoId $VideoId
$vid = [string](Get-FkProp $video 'id')
$ori = Get-FkOrientation -Video $video
$prefix = Get-FkFieldPrefix $ori

$chars = ConvertTo-FkArray (Invoke-FkApi -Method GET -Path ('/api/projects/' + $pid + '/characters'))
$missingRefs = @($chars | Where-Object { -not (Test-FkUuid ([string](Get-FkProp $_ 'media_id' ''))) })
if ($missingRefs.Count -gt 0) {
    throw ("ABORT: {0} entit(y/ies) missing media_id. Run /fk-gen-refs {1} first." -f $missingRefs.Count, $pid)
}

function Get-FkImageNeed {
    param($Scenes, [string]$Prefix)
    $need = New-Object System.Collections.Generic.List[object]
    foreach ($s in $Scenes) {
        $st = [string](Get-FkProp $s ($Prefix + '_image_status') '')
        $mid = [string](Get-FkProp $s ($Prefix + '_image_media_id') '')
        if ($st -eq 'COMPLETED' -and (Test-FkUuid $mid)) { continue }
        $need.Add($s)
    }
    return $need
}

function Get-FkChainDepth {
    param($Scene, $ById)
    $d = 0
    $cur = $Scene
    $guard = 0
    while ($cur -and (([string](Get-FkProp $cur 'chain_type')) -eq 'CONTINUATION') -and (Get-FkProp $cur 'parent_scene_id')) {
        $guard++
        if ($guard -gt 200) { break }
        $parentId = [string](Get-FkProp $cur 'parent_scene_id')
        if (-not $ById.ContainsKey($parentId)) { break }
        $cur = $ById[$parentId]
        $d++
    }
    return $d
}

$maxWaves = 40
for ($wave = 1; $wave -le $maxWaves; $wave++) {
    $scenes = ConvertTo-FkArray (Invoke-FkApi -Method GET -Path ('/api/scenes?video_id=' + [uri]::EscapeDataString($vid)))
    $byId = @{}
    foreach ($s in $scenes) { $byId[[string](Get-FkProp $s 'id')] = $s }
    $need = @(Get-FkImageNeed -Scenes $scenes -Prefix $prefix)
    if ($need.Count -eq 0) { break }

    $minDepth = 9999
    $depths = @{}
    foreach ($s in $need) {
        $d = Get-FkChainDepth -Scene $s -ById $byId
        $depths[[string](Get-FkProp $s 'id')] = $d
        if ($d -lt $minDepth) { $minDepth = $d }
    }

    $reqs = New-Object System.Collections.Generic.List[object]
    foreach ($s in $need) {
        $sid = [string](Get-FkProp $s 'id')
        if ($depths[$sid] -ne $minDepth) { continue }
        $chain = [string](Get-FkProp $s 'chain_type')
        $rtype = 'GENERATE_IMAGE'
        if ($chain -eq 'CONTINUATION' -and (Get-FkProp $s 'parent_scene_id')) {
            $rtype = 'EDIT_IMAGE'
        }
        $reqs.Add(@{
                type        = $rtype
                scene_id    = $sid
                project_id  = $pid
                video_id    = $vid
                orientation = $ori
            })
    }
    if ($reqs.Count -eq 0) { break }

    Write-Host ("Wave {0}: submitting {1} request(s) (depth {2})..." -f $wave, $reqs.Count, $minDepth)
    Submit-FkBatch -Requests $reqs.ToArray() | Out-Null
    $pollType = 'GENERATE_IMAGE'
    if ($minDepth -gt 0) { $pollType = 'EDIT_IMAGE' }
    $st = Wait-FkBatchStatus -VideoId $vid -Type $pollType -IntervalSeconds $PollSeconds
    Write-Host ('  done={0} all_succeeded={1}' -f (Get-FkProp $st 'done'), (Get-FkProp $st 'all_succeeded'))
}

$scenes = ConvertTo-FkArray (Invoke-FkApi -Method GET -Path ('/api/scenes?video_id=' + [uri]::EscapeDataString($vid)))
$scenes = @($scenes | Sort-Object { Get-FkProp $_ 'display_order' })
Write-Host ''
Write-Host ('{0,4} {1,-14} {2,-16} {3,-40}' -f '#', 'chain_type', 'image_status', 'media_id')
$bad = 0
foreach ($s in $scenes) {
    $sid = [string](Get-FkProp $s 'id')
    $st = [string](Get-FkProp $s ($prefix + '_image_status') '')
    $mid = [string](Get-FkProp $s ($prefix + '_image_media_id') '')
    if ($mid.StartsWith('CAMS') -or (-not (Test-FkUuid $mid))) {
        $url = [string](Get-FkProp $s ($prefix + '_image_url') '')
        $extracted = Get-FkUuidFromUrl $url
        if (Test-FkUuid $extracted) {
            $patch = @{}
            $patch[($prefix + '_image_media_id')] = $extracted
            Invoke-FkApi -Method PATCH -Path ('/api/scenes/' + $sid) -Body $patch | Out-Null
            $mid = $extracted
            Write-Host ("  patched CAMS -> {0} on scene {1}" -f $mid, $sid)
        }
    }
    if (-not (Test-FkUuid $mid) -or $st -ne 'COMPLETED') { $bad++ }
    Write-Host ('{0,4} {1,-14} {2,-16} {3,-40}' -f (Get-FkProp $s 'display_order'), (Get-FkProp $s 'chain_type'), $st, $mid)
}
if ($bad -gt 0) {
    Write-Host ("WARNING: {0} scene(s) without completed UUID image." -f $bad)
    exit 1
}
Write-Host ("All scene images ready. Run /fk-gen-videos {0} {1} to generate videos." -f $pid, $vid)
