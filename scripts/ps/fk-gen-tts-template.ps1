# Twin of skills/fk-gen-tts-template.md (API only; install OmniVoice separately)
param(
    [string]$Name,
    [string]$Text,
    [string]$Instruct = 'male, moderate pitch, young adult',
    [double]$Speed = 1.0,
    [switch]$List
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'FkCommon.psm1') -Force

if ($List -or [string]::IsNullOrWhiteSpace($Name)) {
    Write-Host (ConvertTo-FkJson (Invoke-FkApi -Method GET -Path '/api/tts/templates'))
    if ([string]::IsNullOrWhiteSpace($Name)) { return }
}

if ([string]::IsNullOrWhiteSpace($Text)) {
    throw 'Pass -Text (standard base transcript in the target language). See skills/fk-gen-tts-template.md'
}

$body = @{
    name     = $Name
    text     = $Text
    instruct = $Instruct
    speed    = $Speed
}
$r = Invoke-FkApi -Method POST -Path '/api/tts/templates' -Body $body -TimeoutSec 180
Write-Host (ConvertTo-FkJson $r)
Write-Host 'On Windows set TTS_PYTHON_BIN to the venv python.exe that has omnivoice+torch.'
