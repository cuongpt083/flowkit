# Flow Kit statusline for Claude Code on Windows (no jq).
# Claude settings.local.json:
#   "statusLine": { "type": "command", "command": "powershell -NoProfile -ExecutionPolicy Bypass -File <repo>\\scripts\\statusline.ps1" }
$ErrorActionPreference = 'SilentlyContinue'
$esc = [char]27
$G = "$esc[32m"
$V = "$esc[35m"
$R = "$esc[0m"

function Get-FkJson([string]$Url) {
    try {
        $resp = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 1
        return ($resp.Content | ConvertFrom-Json)
    }
    catch { return $null }
}

$claude = ''
if ([Console]::IsInputRedirected) {
    $stdinJson = [Console]::In.ReadToEnd()
    if ($stdinJson) {
        try {
            $s = $stdinJson | ConvertFrom-Json
            $model = [string]$s.model.display_name
            $ctx = 0; $rl5 = 0; $rl7 = 0
            if ($s.context_window.used_percentage) { $ctx = [int]$s.context_window.used_percentage }
            if ($s.rate_limits.five_hour.used_percentage) { $rl5 = [int]$s.rate_limits.five_hour.used_percentage }
            if ($s.rate_limits.seven_day.used_percentage) { $rl7 = [int]$s.rate_limits.seven_day.used_percentage }
            if ($model) {
                $claude = "$model ctx:${G}${ctx}%${R} rl:${G}${rl5}%${R}/5h ${G}${rl7}%${R}/7d"
            }
        }
        catch { }
    }
}

$base = 'http://127.0.0.1:8100'
$health = Get-FkJson "$base/health"
$prefix = ''
if ($claude) { $prefix = "$claude | " }
if (-not $health) {
    Write-Output "${prefix}GLA: ! DOWN"
    exit 0
}

$ext = [bool]$health.extension_connected
if ($ext) { $extIcon = "WS:${G}Ok${R}" } else { $extIcon = "WS:${V}x${R}" }

$flow = Get-FkJson "$base/api/flow/status"
$auth = 'Auth:x'
if ($flow -and $flow.flow_key_present) { $auth = 'Auth:Ok' }

$credits = Get-FkJson "$base/api/flow/credits"
$tier = ''
try {
    $rawTier = $credits.data.userPaygateTier
    if (-not $rawTier) { $rawTier = $credits.userPaygateTier }
    if ($rawTier -eq 'PAYGATE_TIER_ONE') { $tier = 'T1' }
    elseif ($rawTier -eq 'PAYGATE_TIER_TWO') { $tier = 'T2' }
}
catch { }

$ap = Get-FkJson "$base/api/active-project"
$projName = ''
$vid = ''
$projId = ''
if ($ap) {
    $projName = [string]$ap.project_name
    $vid = [string]$ap.video_id
    $projId = [string]$ap.project_id
}
$short = $projName
if ($short.Length -gt 15) { $short = $short.Substring(0, 15) }

if (-not $vid) {
    Write-Output "${prefix}GLA: $extIcon $short"
    exit 0
}

$video = Get-FkJson "$base/api/videos/$vid"
$scenes = Get-FkJson "$base/api/scenes?video_id=$vid"
$total = 0; $img = 0; $vo = 0; $up = 0
$ori = 'H'
if ($video -and $video.orientation -eq 'VERTICAL') { $ori = 'V' }
if ($scenes) {
    $arr = @($scenes)
    $total = $arr.Count
    foreach ($s in $arr) {
        if ($ori -eq 'V') {
            if ($s.vertical_image_status -eq 'COMPLETED') { $img++ }
            if ($s.vertical_video_status -eq 'COMPLETED') { $vo++ }
            if ($s.vertical_upscale_status -eq 'COMPLETED') { $up++ }
        }
        else {
            if ($s.horizontal_image_status -eq 'COMPLETED') { $img++ }
            if ($s.horizontal_video_status -eq 'COMPLETED') { $vo++ }
            if ($s.horizontal_upscale_status -eq 'COMPLETED') { $up++ }
        }
    }
}

$pending = Get-FkJson "$base/api/requests/pending"
$processing = Get-FkJson "$base/api/requests?status=PROCESSING"
$pN = 0; $prN = 0
if ($pending -is [System.Array]) { $pN = $pending.Count }
if ($processing -is [System.Array]) { $prN = $processing.Count }

$dl = 0; $tts = 0
if ($projId) {
    $od = Get-FkJson "$base/api/projects/$projId/output-dir"
    $slug = ''
    if ($od) { $slug = [string]$od.slug }
    $root = Split-Path -Parent $PSScriptRoot
    if ($slug) {
        $k = Join-Path $root "output\$slug\4k"
        $t = Join-Path $root "output\$slug\tts"
        if (Test-Path $k) { $dl = @(Get-ChildItem $k -Filter 'scene_*.mp4' -ErrorAction SilentlyContinue).Count }
        if (Test-Path $t) { $tts = @(Get-ChildItem $t -Filter 'scene_*.wav' -ErrorAction SilentlyContinue).Count }
    }
}

$tierBit = ''
if ($tier) { $tierBit = " ${V}${tier}${R}" }
Write-Output "${prefix}GLA: ${extIcon}${tierBit} ${V}${auth}${R} ${short} ${ori} ${total}sc img:${V}${img}${R} vid:${V}${vo}${R} 4K:${V}${up}${R} dl:${V}${dl}${R} TTS:${V}${tts}${R} Q:${V}${pN}${R}->${V}${prN}${R}/5"
exit 0
