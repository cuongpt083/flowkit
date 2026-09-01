# Twin of skills/fk-gen-videos.md
param(
    [Parameter(Mandatory = $true)][string]$ProjectId,
    [string]$VideoId,
    [int]$PollSeconds = 180
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'FkCommon.psm1') -Force

Invoke-FkHealth -RequireExtension | Out-Null
$pid = $ProjectId
$proj = Invoke-FkApi -Method GET -Path ('/api/projects/' + $pid)
$video = Resolve-FkVideo -ProjectId $pid -VideoId $VideoId
$vid = [string](Get-FkProp $video 'id')
$ori = Get-FkOrientation -Video $video
$prefix = Get-FkFieldPrefix $ori
$motion = ([string](Get-FkProp $proj 'render_mode')) -eq 'motion'

$scenes = ConvertTo-FkArray (Invoke-FkApi -Method GET -Path ('/api/scenes?video_id=' + [uri]::EscapeDataString($vid)))
foreach ($s in $scenes) {
    if ($motion) {
        $url = [string](Get-FkProp $s ($prefix + '_image_url') '')
        if ([string]::IsNullOrWhiteSpace($url)) {
            throw ("ABORT: motion scene {0} missing image URL. Run /fk-gen-images first." -f (Get-FkProp $s 'id'))
        }
        continue
    }
    $st = [string](Get-FkProp $s ($prefix + '_image_status') '')
    $mid = [string](Get-FkProp $s ($prefix + '_image_media_id') '')
    if ($st -ne 'COMPLETED' -or -not (Test-FkUuid $mid)) {
        throw ("ABORT: scene images not ready (scene {0}). Run /fk-gen-images {1} {2} first." -f (Get-FkProp $s 'id'), $pid, $vid)
    }
}

$inFlight = Get-FkInFlightSceneIds -VideoId $vid -Types @('GENERATE_VIDEO', 'REGENERATE_VIDEO', 'GENERATE_VIDEO_REFS')
$reqs = New-Object System.Collections.Generic.List[object]
foreach ($s in $scenes) {
    $sid = [string](Get-FkProp $s 'id')
    $vst = [string](Get-FkProp $s ($prefix + '_video_status') '')
    if ($vst -eq 'COMPLETED') { continue }
    if ($inFlight.ContainsKey($sid)) {
        Write-Host ("Skip in-flight GENERATE_VIDEO scene {0}" -f $sid)
        continue
    }
    $reqs.Add(@{
            type        = 'GENERATE_VIDEO'
            scene_id    = $sid
            project_id  = $pid
            video_id    = $vid
            orientation = $ori
        })
}

if ($reqs.Count -eq 0) {
    Write-Host 'No GENERATE_VIDEO to submit (all COMPLETED or already in-flight).'
}
else {
    Write-Host ("Submitting {0} GENERATE_VIDEO request(s). Poll every {1}s..." -f $reqs.Count, $PollSeconds)
    Submit-FkBatch -Requests $reqs.ToArray() | Out-Null
    $st = Wait-FkBatchStatus -VideoId $vid -Type 'GENERATE_VIDEO' -IntervalSeconds $PollSeconds
    Write-Host ('batch-status: ' + (ConvertTo-FkJson $st))
}

$scenes = ConvertTo-FkArray (Invoke-FkApi -Method GET -Path ('/api/scenes?video_id=' + [uri]::EscapeDataString($vid)))
$scenes = @($scenes | Sort-Object { Get-FkProp $_ 'display_order' })
Write-Host ('{0,4} {1,-16} {2,-40}' -f '#', 'video_status', 'video_media_id')
$bad = 0
foreach ($s in $scenes) {
    $st = [string](Get-FkProp $s ($prefix + '_video_status') '')
    $mid = [string](Get-FkProp $s ($prefix + '_video_media_id') '')
    if (-not $mid) { $mid = '' }
    Write-Host ('{0,4} {1,-16} {2,-40}' -f (Get-FkProp $s 'display_order'), $st, $mid.Substring(0, [Math]::Min(16, $mid.Length)))
    if ($st -ne 'COMPLETED') { $bad++ }
}
if ($bad -gt 0) {
    Write-Host ("WARNING: {0} scene(s) not COMPLETED. Do not re-submit while PENDING/PROCESSING." -f $bad)
    exit 1
}
Write-Host ("All videos ready. Run /fk-concat {0} to download and merge (trim + xfade + loudnorm)." -f $vid)
