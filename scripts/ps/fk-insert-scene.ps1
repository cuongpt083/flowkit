# Twin of skills/fk-insert-scene.md
# API auto-shifts display_order on INSERT — do not patch subsequent scenes.
param(
    [Parameter(Mandatory = $true)][string]$VideoId,
    [Parameter(Mandatory = $true)][int]$AfterOrder,
    [Parameter(Mandatory = $true)][string]$Prompt,
    [string]$VideoPrompt,
    [string[]]$CharacterNames
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'FkCommon.psm1') -Force

Invoke-FkHealth -RequireExtension | Out-Null
$scenes = ConvertTo-FkArray (Invoke-FkApi -Method GET -Path ('/api/scenes?video_id=' + [uri]::EscapeDataString($VideoId)))
$parent = $null
foreach ($s in $scenes) {
    if ([int](Get-FkProp $s 'display_order') -eq $AfterOrder) { $parent = $s; break }
}
if (-not $parent) { throw "No scene with display_order=$AfterOrder on video $VideoId" }

$names = $CharacterNames
if (-not $names -or $names.Count -eq 0) {
    $names = @(ConvertTo-FkArray (Get-FkProp $parent 'character_names'))
}

$body = @{
    video_id         = $VideoId
    display_order    = ($AfterOrder + 1)
    prompt           = $Prompt
    character_names  = @($names)
    chain_type       = 'INSERT'
    parent_scene_id  = [string](Get-FkProp $parent 'id')
    source           = 'user'
}
if (-not [string]::IsNullOrWhiteSpace($VideoPrompt)) {
    $body['video_prompt'] = $VideoPrompt
}

$created = Invoke-FkApi -Method POST -Path '/api/scenes' -Body $body
Write-Host ("Inserted scene {0} after order {1} (API shifts later scenes)." -f (Get-FkProp $created 'id'), $AfterOrder)

$scenes = ConvertTo-FkArray (Invoke-FkApi -Method GET -Path ('/api/scenes?video_id=' + [uri]::EscapeDataString($VideoId)))
$scenes = @($scenes | Sort-Object { Get-FkProp $_ 'display_order' })
Write-Host ('{0,4} {1,-14} {2}' -f '#', 'chain', 'prompt')
foreach ($s in $scenes) {
    $p = [string](Get-FkProp $s 'prompt' '')
    if ($p.Length -gt 60) { $p = $p.Substring(0, 60) }
    $mark = ''
    if ((Get-FkProp $s 'id') -eq (Get-FkProp $created 'id')) { $mark = '  <- INSERT' }
    Write-Host ('{0,4} {1,-14} {2}{3}' -f (Get-FkProp $s 'display_order'), (Get-FkProp $s 'chain_type'), $p, $mark)
}
Write-Host 'New scene inserted. Run /fk-gen-images then /fk-gen-chain-videos.'
