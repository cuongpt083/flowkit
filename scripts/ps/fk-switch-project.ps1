# Twin of skills/fk-switch-project.md
param(
    [string]$ProjectId,
    [switch]$Clear,
    [switch]$List
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'FkCommon.psm1') -Force

if ($Clear) {
    Invoke-FkApi -Method DELETE -Path '/api/active-project' | Out-Null
    Write-Host 'Active project cleared (fallback = most recently created).'
    return
}

$projects = ConvertTo-FkArray (Invoke-FkApi -Method GET -Path '/api/projects')
$ap = Invoke-FkApi -Method GET -Path '/api/active-project'
Write-Host ('Current active: {0} ({1}) source={2}' -f (Get-FkProp $ap 'project_name' '(none)'), (Get-FkProp $ap 'project_id' ''), (Get-FkProp $ap 'source' ''))
Write-Host ''
Write-Host ('{0,3}  {1,-40} {2,-36} {3}' -f '#', 'Name', 'ID', 'Material')
$i = 0
foreach ($p in $projects) {
    $i++
    Write-Host ('{0,3}  {1,-40} {2,-36} {3}' -f $i, (Get-FkProp $p 'name'), (Get-FkProp $p 'id'), (Get-FkProp $p 'material'))
}

if ($List -or [string]::IsNullOrWhiteSpace($ProjectId)) {
    Write-Host ''
    Write-Host 'Pass -ProjectId <id> to switch.'
    return
}

$sw = Invoke-FkApi -Method PUT -Path '/api/active-project' -Body @{ project_id = $ProjectId }
Write-Host ''
Write-Host ('Switched to: {0}' -f (Get-FkProp $sw 'project_name'))
Write-Host ('Project ID:  {0}' -f (Get-FkProp $sw 'project_id'))
Write-Host ('Video ID:    {0}' -f (Get-FkProp $sw 'video_id' 'none'))
