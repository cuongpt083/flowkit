# Twin of skills/fk-import-voice.md — register WAV after host confirms transcript.
param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$WavPath,
    [Parameter(Mandatory = $true)][string]$Text,
    [string]$Instruct = 'imported voice',
    [string]$TestSentence
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'FkCommon.psm1') -Force

if (-not (Test-Path -LiteralPath $WavPath)) { throw "WAV not found: $WavPath" }
$abs = (Resolve-Path -LiteralPath $WavPath).Path
$root = Get-FkRoot
$dir = Join-Path $root 'output\_shared\tts_templates'
New-FkDirectory $dir | Out-Null
$dest = Join-Path $dir ($Name + '.wav')
if ($abs -ne $dest) { Copy-Item -LiteralPath $abs -Destination $dest -Force }

$dur = $null
try { $dur = Get-FkDurationSec -LiteralPath $dest } catch { }

$metaPath = Join-Path $dir 'templates.json'
$meta = @{}
if (Test-Path -LiteralPath $metaPath) {
    $loaded = Read-FkJson -LiteralPath $metaPath
    if ($loaded -is [hashtable]) { $meta = $loaded }
    else {
        foreach ($p in $loaded.PSObject.Properties) { $meta[$p.Name] = $p.Value }
    }
}
$meta[$Name] = @{
    name       = $Name
    audio_path = $dest
    text       = $Text
    instruct   = $Instruct
    duration   = $dur
}
Save-FkJson -InputObject $meta -LiteralPath $metaPath
Write-Host ("Registered {0} -> {1}" -f $Name, $dest)
Write-Host (ConvertTo-FkJson (Invoke-FkApi -Method GET -Path '/api/tts/templates'))

if ($TestSentence) {
    $body = @{
        text      = $TestSentence
        instruct  = $Instruct
        ref_audio = $dest
        ref_text  = $Text
    }
    Write-Host (ConvertTo-FkJson (Invoke-FkApi -Method POST -Path '/api/tts/generate' -Body $body -TimeoutSec 180))
}
Write-Host 'Transcribe with Get-FkPython + faster-whisper if needed (not Homebrew python3.10).'
