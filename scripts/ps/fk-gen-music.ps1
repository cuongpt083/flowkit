# Twin of skills/fk-gen-music.md
param(
    [switch]$ListTemplates,
    [string]$TemplateId,
    [string]$JsonPath,
    [string]$TaskId,
    [switch]$Download,
    [switch]$Credits
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'FkCommon.psm1') -Force

if ($Credits) {
    Write-Host (ConvertTo-FkJson (Invoke-FkApi -Method GET -Path '/api/music/credits'))
    return
}
if ($ListTemplates) {
    Write-Host (ConvertTo-FkJson (Invoke-FkApi -Method GET -Path '/api/music/templates'))
    return
}
if ($TemplateId -and -not $JsonPath) {
    Write-Host (ConvertTo-FkJson (Invoke-FkApi -Method GET -Path ('/api/music/templates/' + $TemplateId)))
    return
}
if ($JsonPath) {
    $spec = Read-FkJson -LiteralPath $JsonPath
    $r = Invoke-FkApi -Method POST -Path '/api/music/generate' -Body $spec -TimeoutSec 180
    Write-Host (ConvertTo-FkJson $r)
    $tid = Get-FkProp $r 'task_id'
    if (-not $tid) { $tid = Get-FkProp $r 'taskId' }
    if ($tid) { Write-Host ("task_id={0}" -f $tid) }
    return
}
if ($TaskId) {
    if ($Download) {
        Write-Host (ConvertTo-FkJson (Invoke-FkApi -Method POST -Path ('/api/music/tasks/' + $TaskId + '/download') -TimeoutSec 180))
    }
    else {
        Write-Host (ConvertTo-FkJson (Invoke-FkApi -Method POST -Path ('/api/music/tasks/' + $TaskId + '/poll') -TimeoutSec 180))
    }
    return
}
Write-Host 'Usage: -ListTemplates | -TemplateId x | -JsonPath generate.json | -TaskId id [-Download] | -Credits'
