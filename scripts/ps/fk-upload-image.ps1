# Twin of skills/fk-upload-image.md
param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [string]$ProjectId,
    [string]$EntityId,
    [string]$FileName
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'FkCommon.psm1') -Force

Invoke-FkHealth -RequireExtension | Out-Null
if (-not (Test-Path -LiteralPath $FilePath)) { throw "File not found: $FilePath" }
$abs = (Resolve-Path -LiteralPath $FilePath).Path
$fn = Split-Path $abs -Leaf
if ($FileName) { $fn = $FileName }
$body = @{
    file_path = $abs
    file_name = $fn
}
if ($ProjectId) { $body['project_id'] = $ProjectId }
$r = Invoke-FkApi -Method POST -Path '/api/flow/upload-image' -Body $body
Write-Host (ConvertTo-FkJson $r)
$mid = Get-FkProp $r 'media_id'
if (-not (Test-FkUuid ([string]$mid))) {
    throw 'Upload did not return a UUID media_id. Check flow_key / extension.'
}
Write-Host ("media_id={0}" -f $mid)
if ($EntityId) {
    Invoke-FkApi -Method PATCH -Path ('/api/characters/' + $EntityId) -Body @{ media_id = $mid } | Out-Null
    Write-Host ("Patched entity {0}" -f $EntityId)
}
Write-Host 'Policy A: do not use this as a shortcut for /fk-gen-refs unless the user asked to inject a local/logo file.'
