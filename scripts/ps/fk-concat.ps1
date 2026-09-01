# Twin of skills/fk-concat.md
param(
    [Parameter(Mandatory = $true)][string]$VideoId,
    [switch]$WithTts,
    [switch]$FourK,
    [switch]$HardCut,
    [double]$TrimHead = 0.4,
    [double]$TrimTail = 0.4,
    [double]$Xfade = 0.4
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'FkCommon.psm1') -Force

if ($HardCut) { $TrimHead = 0; $TrimTail = 0 }

$video = Invoke-FkApi -Method GET -Path ('/api/videos/' + $VideoId)
$pid = [string](Get-FkProp $video 'project_id')
$proj = Invoke-FkApi -Method GET -Path ('/api/projects/' + $pid)
$ori = Get-FkOrientation -Video $video -Project $proj
$prefix = Get-FkFieldPrefix $ori
$outMeta = Resolve-FkOutputDir -ProjectId $pid
$outdir = $outMeta.Path
$slug = $outMeta.Slug
New-FkDirectory (Join-Path $outdir '4k') | Out-Null
New-FkDirectory (Join-Path $outdir 'norm') | Out-Null
New-FkDirectory (Join-Path $outdir 'narrated') | Out-Null

$scenes = @(ConvertTo-FkArray (Invoke-FkApi -Method GET -Path ('/api/scenes?video_id=' + [uri]::EscapeDataString($VideoId))) | Sort-Object { Get-FkProp $_ 'display_order' })
if ($scenes.Count -eq 0) { throw "No scenes for video $VideoId" }

function Get-FkSceneClipPath {
    param($Scene, [string]$OutDir)
    $order = [int](Get-FkProp $Scene 'display_order')
    $sid = [string](Get-FkProp $Scene 'id')
    $idx = '{0:D3}' -f $order
    $canon = Join-Path (Join-Path $OutDir '4k') ("scene_{0}_{1}.mp4" -f $idx, $sid)
    $legacy = Join-Path (Join-Path $OutDir '4k') ($sid + '.mp4')
    $motion = Join-Path (Join-Path $OutDir 'motion') ("scene_{0}_{1}.mp4" -f $idx, $sid)
    return @{ Canon = $canon; Legacy = $legacy; Motion = $motion; Idx = $idx; Sid = $sid }
}

$needRefresh = $false
foreach ($s in $scenes) {
    $p = Get-FkSceneClipPath -Scene $s -OutDir $outdir
    if (Test-Path -LiteralPath $p.Canon) {
        $len = (Get-Item -LiteralPath $p.Canon).Length
        if ($len -lt 10000) { Remove-Item -LiteralPath $p.Canon -Force }
    }
    if (Test-FkMediaFile $p.Canon) { continue }
    if (Test-FkMediaFile $p.Legacy) { continue }
    if (Test-FkMediaFile $p.Motion) { continue }
    $up = [string](Get-FkProp $s ($prefix + '_upscale_url') '')
    $vu = [string](Get-FkProp $s ($prefix + '_video_url') '')
    if (-not (Test-FkSignedUrl $up) -and -not (Test-FkSignedUrl $vu)) { $needRefresh = $true }
}

if ($needRefresh) {
    Write-Host 'Refreshing signed URLs (Flow tab must be open)...'
    Invoke-FkApi -Method POST -Path ('/api/flow/refresh-urls/' + $pid) | Out-Null
    $scenes = @(ConvertTo-FkArray (Invoke-FkApi -Method GET -Path ('/api/scenes?video_id=' + [uri]::EscapeDataString($VideoId))) | Sort-Object { Get-FkProp $_ 'display_order' })
}

$sources = New-Object System.Collections.Generic.List[object]
foreach ($s in $scenes) {
    $p = Get-FkSceneClipPath -Scene $s -OutDir $outdir
    if ((Test-Path -LiteralPath $p.Canon) -and ((Get-Item -LiteralPath $p.Canon).Length -lt 10000)) {
        Remove-Item -LiteralPath $p.Canon -Force
    }
    $src = $null
    if (Test-FkMediaFile $p.Canon) { $src = $p.Canon }
    elseif (Test-FkMediaFile $p.Legacy) {
        Copy-Item -LiteralPath $p.Legacy -Destination $p.Canon -Force
        $src = $p.Canon
    }
    elseif (Test-FkMediaFile $p.Motion) { $src = $p.Motion }
    else {
        $up = [string](Get-FkProp $s ($prefix + '_upscale_url') '')
        $vu = [string](Get-FkProp $s ($prefix + '_video_url') '')
        $url = $null
        if (Test-FkSignedUrl $up) { $url = $up }
        elseif (Test-FkSignedUrl $vu) { $url = $vu }
        if (-not $url) {
            throw ("ABORT: scene {0} has no local clip and no signed URL. Run /fk-gen-videos first (do not GENERATE_VIDEO from concat)." -f $p.Sid)
        }
        Write-Host ("Downloading scene {0}..." -f $p.Idx)
        Save-FkUrlToFile -Url $url -LiteralPath $p.Canon
        if (-not (Test-FkMediaFile $p.Canon)) {
            if (Test-Path -LiteralPath $p.Canon) { Remove-Item -LiteralPath $p.Canon -Force }
            throw ("Download failed or 403 body for scene {0}. Refresh URLs and retry." -f $p.Sid)
        }
        $src = $p.Canon
    }
    $tts = Join-Path (Join-Path $outdir 'tts') ("scene_{0}_{1}.wav" -f $p.Idx, $p.Sid)
    $sources.Add(@{ Scene = $s; Path = $src; Tts = $tts; Idx = $p.Idx; Sid = $p.Sid })
}

if ($WithTts) {
    $missing = @($sources | Where-Object { -not (Test-Path -LiteralPath $_.Tts) })
    if ($missing.Count -gt 0) {
        throw ("ABORT: -WithTts but missing WAV for {0} scene(s). Run /fk-gen-narrator first." -f $missing.Count)
    }
}

$firstSize = Get-FkVideoWidth -LiteralPath $sources[0].Path
$W = $firstSize.Width
$H = $firstSize.Height
if ($FourK) {
    if ($ori -eq 'VERTICAL') { $W = 2160; $H = 3840 } else { $W = 3840; $H = 2160 }
}
if ($firstSize.Width -ge 3840 -and $W -lt $firstSize.Width) {
    $W = $firstSize.Width; $H = $firstSize.Height
}
Write-Host ("Output scale {0}x{1}" -f $W, $H)

$srcDirName = 'norm'
if ($WithTts) { $srcDirName = 'narrated' }
$srcDir = Join-Path $outdir $srcDirName
$normed = New-Object System.Collections.Generic.List[object]

foreach ($row in $sources) {
    $s = $row.Scene
    $th = $TrimHead
    $tt = $TrimTail
    $ovh = Get-FkProp $s 'trim_start'
    $ovt = Get-FkProp $s 'trim_end'
    if ($null -ne $ovh) { $th = [double]$ovh }
    if ($null -ne $ovt) { $tt = [double]$ovt }
    $dur = Get-FkDurationSec -LiteralPath $row.Path
    $keep = [Math]::Max(0.5, $dur - $th - $tt)
    if ($dur -le ($th + $tt + 0.5)) { $th = 0; $keep = $dur }
    $outClip = Join-Path $srcDir ("scene_{0}_{1}.mp4" -f $row.Idx, $row.Sid)
    $vf = "scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2"
    $ff = Get-FkToolPath 'ffmpeg'
    if ($WithTts) {
        & $ff -y -ss "$th" -i $row.Path -i $row.Tts -t "$keep" `
            -filter_complex '[0:a]volume=0.3[bg];[1:a]volume=1.5[fg];[bg][fg]amix=inputs=2:duration=first[aout]' `
            -map '0:v' -map '[aout]' `
            -c:v libx264 -preset fast -crf 18 -vf $vf -r 24 -pix_fmt yuv420p `
            -c:a aac -b:a 192k -ar 48000 -ac 2 -movflags +faststart $outClip
    }
    else {
        & $ff -y -ss "$th" -i $row.Path -t "$keep" `
            -c:v libx264 -preset fast -crf 18 -vf $vf -r 24 -pix_fmt yuv420p `
            -c:a aac -b:a 192k -ar 48000 -ac 2 -movflags +faststart $outClip
    }
    if ($LASTEXITCODE -ne 0) { throw "ffmpeg normalize failed: $($row.Sid)" }
    $normed.Add(@{ Scene = $s; Path = $outClip })
}

$segments = New-Object System.Collections.Generic.List[object]
$current = New-Object System.Collections.Generic.List[string]
foreach ($row in $normed) {
    $chain = [string](Get-FkProp $row.Scene 'chain_type')
    if ($chain -eq 'CONTINUATION' -and $current.Count -gt 0) {
        [void]$current.Add($row.Path)
    }
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
    $chainOut = $seg[0]
    if (-not $HardCut -and $seg.Count -gt 1) {
        $chainOut = Join-Path $srcDir ('chain_{0:D3}.mp4' -f $segIdx)
        Invoke-FkXfadeChain -Inputs @($seg) -Output $chainOut -Xfade $Xfade
    }
    $ln = $chainOut
    if ($ln.ToLower().EndsWith('.mp4')) { $ln = $ln.Substring(0, $ln.Length - 4) }
    $ln = $ln + '_ln.mp4'
    $ff = Get-FkToolPath 'ffmpeg'
    & $ff -y -i $chainOut -af 'loudnorm=I=-16:TP=-1.5:LRA=11' `
        -c:v copy -c:a aac -b:a 192k -ar 48000 -ac 2 $ln
    if ($LASTEXITCODE -ne 0) { throw "ffmpeg loudnorm failed: $chainOut" }
    [void]$finalParts.Add($ln)
}

$listPath = Join-Path $outdir 'concat.txt'
Write-FkConcatList -Paths @($finalParts) -LiteralPath $listPath
$final = Join-Path $outdir ($slug + '_final.mp4')
$ff = Get-FkToolPath 'ffmpeg'
& $ff -y -f concat -safe 0 -i $listPath -c copy -movflags +faststart $final
if ($LASTEXITCODE -ne 0) { throw "ffmpeg concat failed: $final" }

$music = Join-Path $outdir 'music.wav'
if (Test-Path -LiteralPath $music) {
    $mixed = Join-Path $outdir ($slug + '_final_music.mp4')
    & $ff -y -i $final -i $music -filter_complex '[1:a]volume=0.18[bed];[0:a][bed]amix=inputs=2:duration=first[aout]' `
        -map '0:v' -map '[aout]' -c:v copy -c:a aac -b:a 192k -ar 48000 -ac 2 -movflags +faststart $mixed
    if ($LASTEXITCODE -ne 0) { throw 'ffmpeg music mix failed' }
    $final = $mixed
}

$dur = Get-FkDurationSec -LiteralPath $final
$size = Get-FkVideoWidth -LiteralPath $final
$mb = [Math]::Round((Get-Item -LiteralPath $final).Length / 1MB, 1)
Write-Host ''
Write-Host ('Concat complete: {0}' -f (Get-FkProp $proj 'name'))
Write-Host ('  Output: {0}' -f $final)
Write-Host ('  Duration: {0:N1}s' -f $dur)
Write-Host ('  Resolution: {0}x{1}' -f $size.Width, $size.Height)
Write-Host ('  Size: {0} MB' -f $mb)
Write-Host ('  Scenes: {0}' -f $scenes.Count)
$cont = 'trim 0.4/0.4, xfade 0.4 in-chain'
if ($HardCut) { $cont = '--hard-cut' }
Write-Host ('  Continuity: {0}' -f $cont)
