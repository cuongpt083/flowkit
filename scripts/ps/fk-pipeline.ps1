# Twin of skills/fk-pipeline.md — orchestrates existing HTTP/ffmpeg twins.
# Review regen loops stay with the host agent (API POST review); this script
# submits Flow batches and optional download/concat.
param(
    [string]$ProjectId,
    [string]$VideoId,
    [switch]$Upscale,
    [switch]$Tts,
    [string]$TtsTemplate,
    [switch]$Download,
    [switch]$Concat,
    [switch]$FourK,
    [switch]$WithTts,
    [switch]$SkipReview,
    [int]$ImagePollSeconds = 15,
    [int]$VideoPollSeconds = 180
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'FkCommon.psm1') -Force

Invoke-FkHealth -RequireExtension | Out-Null
$projectId = Resolve-FkProjectId -ProjectId $ProjectId
$proj = Invoke-FkApi -Method GET -Path ('/api/projects/' + $projectId)
$video = Resolve-FkVideo -ProjectId $projectId -VideoId $VideoId
$vid = [string](Get-FkProp $video 'id')
$ori = Get-FkOrientation -Video $video -Project $proj
$prefix = Get-FkFieldPrefix $ori
$outMeta = Resolve-FkOutputDir -ProjectId $projectId
$outdir = $outMeta.Path
$name = [string](Get-FkProp $proj 'name')

function Get-FkPipelineState {
    $chars = ConvertTo-FkArray (Invoke-FkApi -Method GET -Path ('/api/projects/' + $projectId + '/characters'))
    $scenes = ConvertTo-FkArray (Invoke-FkApi -Method GET -Path ('/api/scenes?video_id=' + [uri]::EscapeDataString($vid)))
    $n = $scenes.Count
    $refsDone = @($chars | Where-Object { Test-FkUuid ([string](Get-FkProp $_ 'media_id' '')) }).Count
    $imgDone = @($scenes | Where-Object { (Get-FkProp $_ ($prefix + '_image_status')) -eq 'COMPLETED' }).Count
    $vidDone = @($scenes | Where-Object { (Get-FkProp $_ ($prefix + '_video_status')) -eq 'COMPLETED' }).Count
    $upDone = @($scenes | Where-Object { (Get-FkProp $_ ($prefix + '_upscale_status')) -eq 'COMPLETED' }).Count
    $ttsDir = Join-Path $outdir 'tts'
    $ttsDone = 0
    if (Test-Path -LiteralPath $ttsDir) {
        $ttsDone = @(Get-ChildItem -LiteralPath $ttsDir -Filter 'scene_*.wav' -ErrorAction SilentlyContinue).Count
    }
    $kDir = Join-Path $outdir '4k'
    $dlDone = 0
    if (Test-Path -LiteralPath $kDir) {
        $dlDone = @(Get-ChildItem -LiteralPath $kDir -Filter 'scene_*.mp4' -ErrorAction SilentlyContinue | Where-Object { $_.Length -gt 10000 }).Count
    }
    $hasNar = $false
    foreach ($s in $scenes) {
        if (Get-FkProp $s 'narrator_text') { $hasNar = $true; break }
    }
    return @{
        Chars = $chars; Scenes = $scenes; N = $n
        RefsDone = $refsDone; RefsTotal = $chars.Count
        ImgDone = $imgDone; VidDone = $vidDone; UpDone = $upDone
        TtsDone = $ttsDone; DlDone = $dlDone; HasNarrator = $hasNar
    }
}

function Write-FkNotify([string]$Msg) {
    Write-Host ("[NOTIFY] {0}" -f $Msg)
}

$st = Get-FkPipelineState
Write-Host ("[fk-pipeline] {0} [{1}]" -f $name, $ori)
Write-Host ("  Refs {0}/{1}  Images {2}/{3}  Videos {4}/{3}  4K {5}/{3}  TTS {6}  DL {7}" -f $st.RefsDone, $st.RefsTotal, $st.ImgDone, $st.N, $st.VidDone, $st.UpDone, $st.TtsDone, $st.DlDone)

$twins = $PSScriptRoot
if ($st.RefsDone -lt $st.RefsTotal) {
    Write-Host 'Stage REFS'
    & (Join-Path $twins 'fk-gen-refs.ps1') -ProjectId $projectId -PollSeconds $ImagePollSeconds
    if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) { throw 'fk-gen-refs failed' }
    Write-FkNotify "REFS complete for $name"
}

$st = Get-FkPipelineState
if ($st.ImgDone -lt $st.N) {
    Write-Host 'Stage IMAGES'
    & (Join-Path $twins 'fk-gen-images.ps1') -ProjectId $projectId -VideoId $vid -PollSeconds $ImagePollSeconds
    Write-FkNotify "IMAGES complete for $name"
}

$st = Get-FkPipelineState
if ($st.VidDone -lt $st.N) {
    Write-Host 'Stage VIDEOS'
    $lite = $false
    try {
        $models = Invoke-FkApi -Method GET -Path '/api/models'
        $blob = ConvertTo-FkJson $models
        if ($blob -match 'i2v_lite') { $lite = $true }
    }
    catch { }
    if ($lite) {
        & (Join-Path $twins 'fk-gen-chain-videos.ps1') -ProjectId $projectId -VideoId $vid -PollSeconds $VideoPollSeconds
    }
    else {
        & (Join-Path $twins 'fk-gen-videos.ps1') -ProjectId $projectId -VideoId $vid -PollSeconds $VideoPollSeconds
    }
    Write-FkNotify "VIDEOS complete for $name"
}

if (-not $SkipReview) {
    Write-Host 'Stage REVIEW (API light). Host agent should interpret scores / regen; pipeline continues.'
    try {
        $revPath = '/api/videos/' + $vid + '/review?project_id=' + [uri]::EscapeDataString($projectId) + '&mode=light&orientation=' + $ori
        Invoke-FkApi -Method POST -Path $revPath -TimeoutSec 30 | Out-Null
    }
    catch {
        Write-Host ("  review POST: {0}" -f $_.Exception.Message)
    }
}

if ($Tts) {
    $templates = ConvertTo-FkArray (Invoke-FkApi -Method GET -Path '/api/tts/templates')
    if ($templates.Count -eq 0) {
        throw 'TTS requested but no voice template. Run /fk-gen-tts-template first.'
    }
    $tpl = $TtsTemplate
    if ([string]::IsNullOrWhiteSpace($tpl)) {
        $tpl = [string](Get-FkProp $templates[0] 'name')
        if (-not $tpl) { $tpl = [string](Get-FkProp $templates[0] 'id') }
    }
    Write-Host ("Stage TTS template={0}" -f $tpl)
    $body = @{ template = $tpl }
    Invoke-FkApi -Method POST -Path ('/api/videos/' + $vid + '/narrate') -Body $body -TimeoutSec 120 | Out-Null
}

if ($Upscale) {
    $st = Get-FkPipelineState
    $reqs = New-Object System.Collections.Generic.List[object]
    foreach ($s in $st.Scenes) {
        $upst = [string](Get-FkProp $s ($prefix + '_upscale_status') '')
        if ($upst -eq 'COMPLETED') { continue }
        $reqs.Add(@{
                type        = 'UPSCALE_VIDEO'
                scene_id    = [string](Get-FkProp $s 'id')
                project_id  = $projectId
                video_id    = $vid
                orientation = $ori
            })
    }
    if ($reqs.Count -gt 0) {
        Write-Host ("Stage UPSCALE {0} request(s)" -f $reqs.Count)
        Submit-FkBatch -Requests $reqs.ToArray() | Out-Null
        Wait-FkBatchStatus -VideoId $vid -Type 'UPSCALE_VIDEO' -IntervalSeconds $VideoPollSeconds | Out-Null
        Write-FkNotify "UPSCALE complete for $name"
    }
}

if ($Download) {
    $st = Get-FkPipelineState
    New-FkDirectory (Join-Path $outdir '4k') | Out-Null
    foreach ($s in $st.Scenes) {
        $order = [int](Get-FkProp $s 'display_order')
        $sid = [string](Get-FkProp $s 'id')
        $idx = '{0:D3}' -f $order
        $dest = Join-Path (Join-Path $outdir '4k') ("scene_{0}_{1}.mp4" -f $idx, $sid)
        if (Test-FkMediaFile $dest) { continue }
        $up = [string](Get-FkProp $s ($prefix + '_upscale_url') '')
        $vu = [string](Get-FkProp $s ($prefix + '_video_url') '')
        $url = $null
        if (Test-FkSignedUrl $up) { $url = $up }
        elseif (Test-FkSignedUrl $vu) { $url = $vu }
        if (-not $url) { continue }
        Write-Host ("Download {0}" -f $idx)
        Save-FkUrlToFile -Url $url -LiteralPath $dest
        if (-not (Test-FkMediaFile $dest)) {
            if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Force }
            Write-Host ("  skip bad download {0}" -f $idx)
        }
    }
}

if ($Concat) {
    Write-Host 'Stage CONCAT'
    $cargs = New-Object System.Collections.Generic.List[string]
    [void]$cargs.Add('-VideoId'); [void]$cargs.Add($vid)
    if ($FourK) { [void]$cargs.Add('-FourK') }
    if ($WithTts -or $Tts) { [void]$cargs.Add('-WithTts') }
    & (Join-Path $twins 'fk-concat.ps1') @($cargs.ToArray())
}

$st = Get-FkPipelineState
Write-Host ''
Write-Host ("Pipeline complete for {0}" -f $name)
Write-Host ("  Refs: {0}/{1}  Images: {2}/{3}  Videos: {4}/{3}  Upscale: {5}/{3}  DL: {6}  TTS wavs: {7}" -f $st.RefsDone, $st.RefsTotal, $st.ImgDone, $st.N, $st.VidDone, $st.UpDone, $st.DlDone, $st.TtsDone)
Write-FkNotify "Pipeline finished $name"
