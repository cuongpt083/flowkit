# Twin of skills/fk-monitor.md — poll + optional download.
# Telegram stays with the host agent: this script prints [NOTIFY] lines.
param(
    [string]$ProjectId,
    [string]$VideoId,
    [switch]$Download,
    [int]$IntervalSeconds = 180,
    [int]$MaxCycles = 0
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

function Get-Snap {
    $chars = ConvertTo-FkArray (Invoke-FkApi -Method GET -Path ('/api/projects/' + $projectId + '/characters'))
    $scenes = ConvertTo-FkArray (Invoke-FkApi -Method GET -Path ('/api/scenes?video_id=' + [uri]::EscapeDataString($vid)))
    $pending = Invoke-FkApi -Method GET -Path '/api/requests/pending'
    $failed = Invoke-FkApi -Method GET -Path '/api/requests?status=FAILED'
    $n = $scenes.Count
    $kDir = Join-Path $outdir '4k'
    $ttsDir = Join-Path $outdir 'tts'
    $dl = 0
    if (Test-Path $kDir) { $dl = @(Get-ChildItem $kDir -Filter 'scene_*.mp4' | Where-Object { $_.Length -gt 10000 }).Count }
    $tts = 0
    if (Test-Path $ttsDir) { $tts = @(Get-ChildItem $ttsDir -Filter 'scene_*.wav').Count }
    $pendN = 0
    if ($pending -is [System.Array]) { $pendN = $pending.Count }
    elseif (Get-FkProp $pending 'total') { $pendN = [int](Get-FkProp $pending 'total') }
    $failN = 0
    if ($failed -is [System.Array]) { $failN = $failed.Count }
    elseif (Get-FkProp $failed 'total') { $failN = [int](Get-FkProp $failed 'total') }
    return @{
        Refs     = @($chars | Where-Object { Test-FkUuid ([string](Get-FkProp $_ 'media_id' '')) }).Count
        RefsT    = $chars.Count
        Images   = @($scenes | Where-Object { (Get-FkProp $_ ($prefix + '_image_status')) -eq 'COMPLETED' }).Count
        Videos   = @($scenes | Where-Object { (Get-FkProp $_ ($prefix + '_video_status')) -eq 'COMPLETED' }).Count
        Upscales = @($scenes | Where-Object { (Get-FkProp $_ ($prefix + '_upscale_status')) -eq 'COMPLETED' }).Count
        N        = $n
        Dl       = $dl
        Tts      = $tts
        Pending  = $pendN
        Failed   = $failN
        Scenes   = $scenes
    }
}

Write-Host ("[NOTIFY] Monitor started: {0} interval={1}s" -f $name, $IntervalSeconds)
$prev = $null
$cycle = 0
while ($true) {
    $cycle++
    $cur = Get-Snap
    Write-Host ("[cycle {0}] {1}" -f $cycle, $name)
    Write-Host ("  Refs {0}/{1} | Images {2}/{5} | Videos {3}/{5} | 4K {4}/{5} | DL {6} | TTS {7}" -f $cur.Refs, $cur.RefsT, $cur.Images, $cur.Videos, $cur.Upscales, $cur.N, $cur.Dl, $cur.Tts)
    Write-Host ("  Queue pending={0} failed={1}" -f $cur.Pending, $cur.Failed)

    if ($prev) {
        if ($cur.Refs -eq $cur.RefsT -and $prev.Refs -lt $cur.RefsT) { Write-Host '[NOTIFY] Ref images complete' }
        if ($cur.Images -eq $cur.N -and $prev.Images -lt $cur.N) { Write-Host '[NOTIFY] Scene images complete' }
        if ($cur.Videos -eq $cur.N -and $prev.Videos -lt $cur.N) { Write-Host '[NOTIFY] Scene videos complete' }
        if ($cur.Upscales -eq $cur.N -and $cur.N -gt 0 -and $prev.Upscales -lt $cur.N) { Write-Host '[NOTIFY] 4K upscale complete' }
        if ($cur.Failed -gt $prev.Failed) { Write-Host ('[NOTIFY] New failures: {0}' -f ($cur.Failed - $prev.Failed)) }
    }

    if ($Download) {
        New-FkDirectory (Join-Path $outdir '4k') | Out-Null
        foreach ($s in $cur.Scenes) {
            if ((Get-FkProp $s ($prefix + '_upscale_status')) -ne 'COMPLETED') { continue }
            $order = [int](Get-FkProp $s 'display_order')
            $sid = [string](Get-FkProp $s 'id')
            $dest = Join-Path (Join-Path $outdir '4k') ('scene_{0:D3}_{1}.mp4' -f $order, $sid)
            if (Test-FkMediaFile $dest) { continue }
            $url = [string](Get-FkProp $s ($prefix + '_upscale_url') '')
            if (-not (Test-FkSignedUrl $url)) { continue }
            Write-Host ("  download {0}" -f $order)
            Save-FkUrlToFile -Url $url -LiteralPath $dest
        }
    }

    $allVid = ($cur.N -gt 0 -and $cur.Videos -ge $cur.N)
    $allUp = ($cur.N -gt 0 -and $cur.Upscales -ge $cur.N -and $cur.Dl -ge $cur.Upscales)
    if ($Download -and $allUp) {
        Write-Host '[NOTIFY] Monitor stopped: upscales downloaded'
        break
    }
    if (-not $Download -and $allVid) {
        Write-Host '[NOTIFY] Monitor stopped: all videos done'
        break
    }
    if ($MaxCycles -gt 0 -and $cycle -ge $MaxCycles) {
        Write-Host '[NOTIFY] Monitor stopped: max cycles'
        break
    }
    $prev = $cur
    Start-Sleep -Seconds $IntervalSeconds
}
