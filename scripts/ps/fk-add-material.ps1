# Twin of skills/fk-add-material.md
param(
    [string]$JsonPath,
    [string]$DeleteId
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'FkCommon.psm1') -Force

if ($DeleteId) {
    Invoke-FkApi -Method DELETE -Path ('/api/materials/' + $DeleteId) | Out-Null
    Write-Host ("Deleted material {0}" -f $DeleteId)
}

if ($JsonPath) {
    $spec = Read-FkJson -LiteralPath $JsonPath
    $r = Invoke-FkApi -Method POST -Path '/api/materials' -Body $spec
    Write-Host ('Created: {0}' -f (ConvertTo-FkJson $r))
}

Write-Host (ConvertTo-FkJson (Invoke-FkApi -Method GET -Path '/api/materials'))
