# Twin of skills/fk-brand-logo.md
param(
    [Parameter(Mandatory = $true)][string]$ChannelName,
    [Parameter(Mandatory = $true)][string]$VideoPath,
    [int]$Size = 0,
    [switch]$Thumbnails,
    [string]$ProjectId,
    [switch]$NoIntro,
    [switch]$NoOutro
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'FkCommon.psm1') -Force

if (-not (Test-Path -LiteralPath $VideoPath)) { throw "Video not found: $VideoPath" }
$root = Get-FkRoot
$channelDir = Join-Path (Join-Path $root 'youtube\channels') $ChannelName
$icon = Join-Path $channelDir ($ChannelName + '_icon.png')
if (-not (Test-Path -LiteralPath $icon)) {
    throw "Icon not found: $icon`nPlease place your channel icon PNG there first."
}
$icon4k = Join-Path $channelDir '4k_icon.png'
$tmp = Get-FkTempDir
$ff = Get-FkToolPath 'ffmpeg'

$wh = Get-FkVideoWidth -LiteralPath $VideoPath
$W = $wh.Width; $H = $wh.Height
$logo = 110; $pad = 16
$introPri = @('intro_1080.mp4')
$outroPri = @('outro_1080.mp4')
if ($W -ge 3840) {
    $logo = 220; $pad = 40
    $introPri = @('intro_4k_2x.mp4', 'intro_4k.mp4', 'intro_1080.mp4')
    $outroPri = @('outro_4k.mp4', 'outro_1080.mp4')
}
elseif ($W -ge 1920) {
    $logo = 130; $pad = 24
    $introPri = @('intro_1080.mp4', 'intro_4k.mp4')
    $outroPri = @('outro_1080.mp4', 'outro_4k.mp4')
}
if ($Size -gt 0) { $logo = $Size }

function Find-FkAsset([string[]]$Names) {
    foreach ($n in $Names) {
        $p = Join-Path $channelDir $n
        if (Test-Path -LiteralPath $p) { return $p }
    }
    return $null
}

$intro = $null
$outro = $null
if (-not $NoIntro) { $intro = Find-FkAsset $introPri }
if (-not $NoOutro) { $outro = Find-FkAsset $outroPri }

$vfScale = "scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2"
$introN = Join-Path $tmp 'fk_intro_norm.mp4'
$outroN = Join-Path $tmp 'fk_outro_norm.mp4'
$mainN = Join-Path $tmp 'fk_main_norm.mp4'

if ($intro) {
    & $ff -y -i $intro -vf $vfScale -c:v libx264 -preset fast -crf 18 -r 24 -pix_fmt yuv420p -c:a aac -b:a 192k -ar 48000 -ac 2 -movflags +faststart $introN
    if ($LASTEXITCODE -ne 0) { throw 'intro normalize failed' }
}
if ($outro) {
    & $ff -y -i $outro -vf $vfScale -c:v libx264 -preset fast -crf 18 -r 24 -pix_fmt yuv420p -c:a aac -b:a 192k -ar 48000 -ac 2 -movflags +faststart $outroN
    if ($LASTEXITCODE -ne 0) { throw 'outro normalize failed' }
}

$probe = Get-FkToolPath 'ffprobe'
$ac = & $probe -v quiet -show_entries stream=sample_rate,channels -select_streams a -of csv=p=0 $VideoPath
$needA = $true
if (("$ac").Trim() -match '^48000,2') { $needA = $false }
if ($needA) {
    & $ff -y -i $VideoPath -c:v copy -c:a aac -b:a 192k -ar 48000 -ac 2 -movflags +faststart $mainN
    if ($LASTEXITCODE -ne 0) { throw 'main audio normalize failed' }
}
else {
    Copy-Item -LiteralPath $VideoPath -Destination $mainN -Force
}

$parts = New-Object System.Collections.Generic.List[string]
if ($intro) { [void]$parts.Add($introN) }
[void]$parts.Add($mainN)
if ($outro) { [void]$parts.Add($outroN) }
$list = Join-Path $tmp 'fk_brand_concat.txt'
Write-FkConcatList -Paths @($parts) -LiteralPath $list
$joined = Join-Path $tmp 'fk_with_intro_outro.mp4'
& $ff -y -f concat -safe 0 -i $list -c copy -movflags +faststart $joined
if ($LASTEXITCODE -ne 0) { throw 'brand concat failed' }

$outBase = $VideoPath
if ($outBase.ToLower().EndsWith('.mp4')) { $outBase = $outBase.Substring(0, $outBase.Length - 4) }
$branded = $outBase + '_branded.mp4'
$fc = "[1:v]scale=${logo}:${logo},format=rgba[icon];[0:v][icon]overlay=W-w-${pad}:H-h-${pad}"
& $ff -y -i $joined -i $icon -filter_complex $fc -c:v libx264 -preset fast -crf 18 -r 24 -pix_fmt yuv420p -c:a copy -movflags +faststart $branded
if ($LASTEXITCODE -ne 0) { throw 'logo overlay failed' }

if ((Test-Path -LiteralPath $icon4k) -and $W -ge 3840) {
    $tmpB = $outBase + '_branded_tmp.mp4'
    & $ff -y -i $branded -i $icon4k -filter_complex '[1:v]scale=-1:180,format=rgba[icon4k];[0:v][icon4k]overlay=W-w-40:40' `
        -c:v libx264 -preset fast -crf 18 -r 24 -pix_fmt yuv420p -c:a copy -movflags +faststart $tmpB
    if ($LASTEXITCODE -ne 0) { throw '4K badge failed' }
    Move-Item -LiteralPath $tmpB -Destination $branded -Force
}

if ($Thumbnails) {
    $pidUse = $ProjectId
    if ([string]::IsNullOrWhiteSpace($pidUse)) {
        throw '-Thumbnails requires -ProjectId to locate thumbnail_v*_yt.png'
    }
    $od = Resolve-FkOutputDir -ProjectId $pidUse
    $thumbDir = Join-Path $od.Path 'thumbnails'
    if (Test-Path -LiteralPath $thumbDir) {
        Get-ChildItem -LiteralPath $thumbDir -Filter 'thumbnail_v*_yt.png' | ForEach-Object {
            $dest = $_.FullName -replace '_yt\.png$', '_final.png'
            & $ff -y -i $_.FullName -i $icon -filter_complex '[1:v]scale=72:72[icon];[0:v][icon]overlay=W-w-16:H-h-16' $dest
        }
    }
}

foreach ($f in @($introN, $outroN, $mainN, $joined, $list)) {
    if (Test-Path -LiteralPath $f) { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
}

$dur = Get-FkDurationSec -LiteralPath $branded
$sz = Get-FkVideoWidth -LiteralPath $branded
Write-Host ("Channel branding applied: {0}" -f $ChannelName)
Write-Host ("  Output: {0}" -f $branded)
Write-Host ("  Duration: {0:N1}s" -f $dur)
Write-Host ("  Resolution: {0}x{1}" -f $sz.Width, $sz.Height)
Write-Host ("  Intro: {0}" -f $(if ($intro) { $intro } else { '(none)' }))
Write-Host ("  Outro: {0}" -f $(if ($outro) { $outro } else { '(none)' }))
Write-Host ("  Brand logo: {0}x{0} bottom-right" -f $logo)
