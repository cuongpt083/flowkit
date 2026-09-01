# Twin of skills/fk-concat-fit-narrator.md
param(
    [Parameter(Mandatory = $true)][string]$VideoId,
    [double]$Buffer = 0.5,
    [switch]$FourK,
    [double]$TrimHead = 0.4,
    [double]$Xfade = 0.4
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'FkCommon.psm1') -Force

$video = Invoke-FkApi -Method GET -Path ('/api/videos/' + $VideoId)
$pid = [string](Get-FkProp $video 'project_id')
$proj = Invoke-FkApi -Method GET -Path ('/api/projects/' + $pid)
$ori = Get-FkOrientation -Video $video -Project $proj
$prefix = Get-FkFieldPrefix $ori
$outMeta = Resolve-FkOutputDir -ProjectId $pid
$outdir = $outMeta.Path
$slug = $outMeta.Slug
$trimDir = Join-Path $outdir 'trimmed'
New-FkDirectory $trimDir | Out-Null
New-FkDirectory (Join-Path $outdir '4k') | Out-Null

$scenes = @(ConvertTo-FkArray (Invoke-FkApi -Method GET -Path ('/api/scenes?video_id=' + [uri]::EscapeDataString($VideoId))) | Sort-Object { Get-FkProp $_ 'display_order' })
$ff = Get-FkToolPath 'ffmpeg'
$rows = New-Object System.Collections.Generic.List[object]

foreach ($s in $scenes) {
    $order = [int](Get-FkProp $s 'display_order')
    $sid = [string](Get-FkProp $s 'id')
    $idx = '{0:D3}' -f $order
    $candidates = @(
        (Join-Path (Join-Path $outdir '4k') ("scene_{0}_{1}.mp4" -f $idx, $sid)),
        (Join-Path (Join-Path $outdir '4k') ($sid + '.mp4')),
        (Join-Path (Join-Path $outdir 'motion') ("scene_{0}_{1}.mp4" -f $idx, $sid))
    )
    $src = $null
    foreach ($c in $candidates) { if (Test-FkMediaFile $c) { $src = $c; break } }
    if (-not $src) {
        $up = [string](Get-FkProp $s ($prefix + '_upscale_url') '')
        $vu = [string](Get-FkProp $s ($prefix + '_video_url') '')
        $url = $null
        if (Test-FkSignedUrl $up) { $url = $up } elseif (Test-FkSignedUrl $vu) { $url = $vu }
        if (-not $url) { throw ("ABORT: no video source for scene {0}" -f $sid) }
        $dest = $candidates[0]
        Save-FkUrlToFile -Url $url -LiteralPath $dest
        if (-not (Test-FkMediaFile $dest)) { throw ("download failed scene {0}" -f $sid) }
        $src = $dest
    }
    $tts = Join-Path (Join-Path $outdir 'tts') ("scene_{0}_{1}.wav" -f $idx, $sid)
    $vDur = Get-FkDurationSec -LiteralPath $src
    $cut = $vDur
    $ttsDur = $null
    if (Test-Path -LiteralPath $tts) {
        $ttsDur = Get-FkDurationSec -LiteralPath $tts
        $cut = [Math]::Min($vDur, [Math]::Round($ttsDur + $Buffer, 2))
    }
    $rows.Add(@{ Scene = $s; Path = $src; Tts = $tts; Idx = $idx; Sid = $sid; Cut = $cut; TtsDur = $ttsDur; HasTts = (Test-Path -LiteralPath $tts) })
}

Write-Host ('{0,4} {1,10} {2,10} {3}' -f '#', 'TTS', 'Cut', 'Source')
foreach ($r in $rows) {
    $td = '-'
    if ($null -ne $r.TtsDur) { $td = ('{0:N2}s' -f $r.TtsDur) }
    Write-Host ('{0,4} {1,10} {2,10} {3}' -f $r.Idx, $td, ('{0:N2}s' -f $r.Cut), $r.Path)
}

$firstSize = Get-FkVideoWidth -LiteralPath $rows[0].Path
$W = $firstSize.Width; $H = $firstSize.Height
if ($FourK) {
    if ($ori -eq 'VERTICAL') { $W = 2160; $H = 3840 } else { $W = 3840; $H = 2160 }
}
$vf = "scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2"

$trimmed = New-Object System.Collections.Generic.List[object]
foreach ($r in $rows) {
    $outClip = Join-Path $trimDir ("scene_{0}_{1}.mp4" -f $r.Idx, $r.Sid)
    if ($r.HasTts) {
        & $ff -y -ss "$TrimHead" -i $r.Path -i $r.Tts -t "$($r.Cut)" `
            -filter_complex '[0:a]volume=0.3[bg];[1:a]volume=1.5[fg];[bg][fg]amix=inputs=2:duration=first[aout]' `
            -map '0:v' -map '[aout]' -c:v libx264 -preset fast -crf 18 -vf $vf -r 24 -pix_fmt yuv420p `
            -c:a aac -b:a 192k -ar 48000 -ac 2 -movflags +faststart $outClip
    }
    else {
        & $ff -y -i $r.Path -ss "$TrimHead" -c:v libx264 -preset fast -crf 18 -vf $vf -r 24 -pix_fmt yuv420p `
            -c:a aac -b:a 192k -ar 48000 -ac 2 -movflags +faststart $outClip
    }
    if ($LASTEXITCODE -ne 0) { throw "ffmpeg trim failed $($r.Sid)" }
    $trimmed.Add(@{ Scene = $r.Scene; Path = $outClip })
}

$overlayPath = Join-Path $outdir 'text_overlays.json'
if (Test-Path -LiteralPath $overlayPath) {
    $font = $null
    try { $font = Get-FkArialBold } catch { Write-Host 'No Arial Bold; skip drawtext overlays.' }
    if ($font) {
        $overlays = Read-FkJson -LiteralPath $overlayPath
        Write-Host "text_overlays.json present; burn skipped unless entries are simple (see skill for drawtext). Font=$font"
    }
}

$segments = New-Object System.Collections.Generic.List[object]
$current = New-Object System.Collections.Generic.List[string]
foreach ($row in $trimmed) {
    $chain = [string](Get-FkProp $row.Scene 'chain_type')
    if ($chain -eq 'CONTINUATION' -and $current.Count -gt 0) { [void]$current.Add($row.Path) }
    else {
        if ($current.Count -gt 0) { [void]$segments.Add(@($current.ToArray())) }
        $current = New-Object System.Collections.Generic.List[string]
        [void]$current.Add($row.Path)
    }
}
if ($current.Count -gt 0) { [void]$segments.Add(@($current.ToArray())) }

$finalParts = New-Object System.Collections.Generic.List[string]
$segIdx = 0
foreach ($seg in $segments) {
    $segIdx++
    if ($seg.Count -eq 1) { [void]$finalParts.Add($seg[0]); continue }
    $chainOut = Join-Path $trimDir ('chain_{0:D3}.mp4' -f $segIdx)
    Invoke-FkXfadeChain -Inputs @($seg) -Output $chainOut -Xfade $Xfade
    [void]$finalParts.Add($chainOut)
}

$listPath = Join-Path $outdir 'concat_trimmed.txt'
Write-FkConcatList -Paths @($finalParts) -LiteralPath $listPath
$final = Join-Path $outdir ($slug + '_narrator_cut.mp4')
& $ff -y -f concat -safe 0 -i $listPath -c copy -movflags +faststart $final
if ($LASTEXITCODE -ne 0) { throw "concat failed $final" }

$dur = Get-FkDurationSec -LiteralPath $final
$size = Get-FkVideoWidth -LiteralPath $final
Write-Host ''
Write-Host ('Narrator-fit concat complete: {0}' -f (Get-FkProp $proj 'name'))
Write-Host ('  Output: {0}' -f $final)
Write-Host ('  Duration: {0:N1}s' -f $dur)
Write-Host ('  Resolution: {0}x{1}' -f $size.Width, $size.Height)
Write-Host ('  Buffer: {0}s' -f $Buffer)
