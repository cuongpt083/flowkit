# Twin of skills/fk-gen-refs.md
param(
    [string]$ProjectId,
    [switch]$Regenerate,
    [int]$PollSeconds = 15
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'FkCommon.psm1') -Force

Invoke-FkHealth -RequireExtension | Out-Null
$projectId = Resolve-FkProjectId -ProjectId $ProjectId
$chars = ConvertTo-FkArray (Invoke-FkApi -Method GET -Path ('/api/projects/' + $projectId + '/characters'))
if ($chars.Count -eq 0) { throw "No entities on project $projectId" }

$type = 'GENERATE_CHARACTER_IMAGE'
if ($Regenerate) { $type = 'REGENERATE_CHARACTER_IMAGE' }

$reqs = New-Object System.Collections.Generic.List[object]
foreach ($c in $chars) {
    $mid = [string](Get-FkProp $c 'media_id' '')
    if (-not $Regenerate -and (Test-FkUuid $mid)) { continue }
    $reqs.Add(@{
            type         = $type
            character_id = [string](Get-FkProp $c 'id')
            project_id   = $projectId
        })
}

if ($reqs.Count -eq 0) {
    Write-Host 'All entities already have UUID media_id. Nothing to submit.'
}
else {
    Write-Host ("Submitting {0} {1} request(s)..." -f $reqs.Count, $type)
    Submit-FkBatch -Requests $reqs.ToArray() | Out-Null
    $st = Wait-FkBatchStatus -ProjectId $projectId -Type $type -IntervalSeconds $PollSeconds
    Write-Host ('batch-status: ' + (ConvertTo-FkJson $st))
}

$chars = ConvertTo-FkArray (Invoke-FkApi -Method GET -Path ('/api/projects/' + $projectId + '/characters'))
Write-Host ''
Write-Host ('{0,-24} {1,-16} {2,-40} {3}' -f 'Entity', 'Type', 'media_id', 'Status')
$bad = 0
foreach ($c in $chars) {
    $mid = [string](Get-FkProp $c 'media_id' '')
    $ok = Test-FkUuid $mid
    $status = 'OK'
    if (-not $ok) { $status = 'MISSING'; $bad++ }
    Write-Host ('{0,-24} {1,-16} {2,-40} {3}' -f (Get-FkProp $c 'name'), (Get-FkProp $c 'entity_type'), $mid, $status)
}
if ($bad -gt 0) {
    Write-Host ("WARNING: {0} entit(y/ies) still missing UUID media_id. If UNSAFE_GENERATION, follow skill troubleshooting (profile/back view) then re-run with -Regenerate." -f $bad)
    exit 1
}
Write-Host ("All references ready. Run /fk-gen-images {0} <VID> to generate scene images." -f $projectId)
