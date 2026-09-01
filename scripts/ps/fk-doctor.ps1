# Twin of skills/fk-doctor.md (triage + single request). Taxonomy stays in the skill markdown.
param(
    [string]$RequestId
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'FkCommon.psm1') -Force

Write-Host '=== HEALTH ==='
try {
    $h = Invoke-FkApi -Method GET -Path '/health'
    Write-Host (ConvertTo-FkJson $h)
}
catch { Write-Host ("health FAILED: {0}" -f $_.Exception.Message) }

try {
    Write-Host (ConvertTo-FkJson (Invoke-FkApi -Method GET -Path '/api/flow/status'))
}
catch { Write-Host ("flow/status: {0}" -f $_.Exception.Message) }

if ($RequestId) {
    Write-Host ("=== REQUEST {0} ===" -f $RequestId)
    Write-Host (ConvertTo-FkJson (Invoke-FkApi -Method GET -Path ('/api/requests/' + $RequestId)))
    Write-Host 'Match error_message against skills/fk-doctor.md taxonomy.'
    return
}

Write-Host '=== FAILED (limit 20) ==='
Write-Host (ConvertTo-FkJson (Invoke-FkApi -Method GET -Path '/api/requests?status=FAILED&limit=20'))
Write-Host '=== PROCESSING ==='
Write-Host (ConvertTo-FkJson (Invoke-FkApi -Method GET -Path '/api/requests?status=PROCESSING'))
Write-Host 'Windows: if health fails, run python -m agent.main (not WSL). curl alias is Invoke-WebRequest. Port 9222 is the extension WS.'
Write-Host 'Read skills/fk-doctor.md for diagnosis / fix / prevent.'
