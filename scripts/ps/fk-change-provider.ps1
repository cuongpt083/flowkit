# Twin of skills/fk-change-provider.md
param(
    [string]$Set,
    [switch]$List
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'FkCommon.psm1') -Force

$cur = Invoke-FkApi -Method GET -Path '/api/providers?live=true'
Write-Host ('Active: {0}' -f (Get-FkProp $cur 'active'))
Write-Host (ConvertTo-FkJson $cur)

if ($Set) {
    $r = Invoke-FkApi -Method PATCH -Path '/api/providers' -Body @{ active = $Set }
    Write-Host ('Updated: {0}' -f (ConvertTo-FkJson $r))
}
