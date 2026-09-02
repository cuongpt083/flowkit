# Twin of skills/fk-gen-narrator.md (TTS generate after host writes narrator_text).
# Optional -TextsJson: { "<scene_id>": "narrator text", ... } then PATCH + generate.
param(
    [Parameter(Mandatory = $true)][string]$VideoId,
    [string]$ProjectId,
    [string]$Template,
    [string]$TextsJson,
    [double]$Speed = 1.1
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'FkCommon.psm1') -Force

$video = Invoke-FkApi -Method GET -Path ('/api/videos/' + $VideoId)
$projectId = $ProjectId
if ([string]::IsNullOrWhiteSpace($projectId)) { $projectId = [string](Get-FkProp $video 'project_id') }
$out = Resolve-FkOutputDir -ProjectId $projectId
$ttsDir = Join-Path $out.Path 'tts'
New-FkDirectory $ttsDir | Out-Null

if ($TextsJson) {
    $map = Read-FkJson -LiteralPath $TextsJson
    foreach ($p in $map.PSObject.Properties) {
        Invoke-FkApi -Method PATCH -Path ('/api/scenes/' + $p.Name) -Body @{ narrator_text = [string]$p.Value } | Out-Null
        Write-Host ("PATCH narrator_text scene {0}" -f $p.Name)
    }
}

$tplName = $Template
$refAudio = $null
$refText = $null
if ($tplName) {
    $t = Invoke-FkApi -Method GET -Path ('/api/tts/templates/' + $tplName)
    $refAudio = Get-FkProp $t 'audio_path'
    $refText = Get-FkProp $t 'text'
}

$scenes = @(ConvertTo-FkArray (Invoke-FkApi -Method GET -Path ('/api/scenes?video_id=' + [uri]::EscapeDataString($VideoId))) | Sort-Object { Get-FkProp $_ 'display_order' })
foreach ($s in $scenes) {
    $nt = [string](Get-FkProp $s 'narrator_text' '')
    if ([string]::IsNullOrWhiteSpace($nt)) { continue }
    $order = [int](Get-FkProp $s 'display_order')
    $sid = [string](Get-FkProp $s 'id')
    $wav = Join-Path $ttsDir ('scene_{0:D3}_{1}.wav' -f $order, $sid)
    $body = @{
        text        = $nt
        speed       = $Speed
        output_path = $wav
    }
    if ($refAudio) { $body['ref_audio'] = $refAudio }
    if ($refText) { $body['ref_text'] = $refText }
    Write-Host ("TTS scene {0}" -f $order)
    Invoke-FkApi -Method POST -Path '/api/tts/generate' -Body $body -TimeoutSec 180 | Out-Null
}
Write-Host ("WAV dir: {0}" -f $ttsDir)
Write-Host 'Host writes narrator_text (interview skip). Next: /fk-concat-fit-narrator'
