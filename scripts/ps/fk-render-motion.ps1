# Twin of skills/fk-render-motion.md
param(
    [Parameter(Mandatory = $true)][string]$ProjectId,
    [string]$VideoId
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'FkCommon.psm1') -Force

Invoke-FkApi -Method PATCH -Path ('/api/projects/' + $ProjectId) -Body @{ render_mode = 'motion'; material = 'vox_collage' } | Out-Null
Write-Host 'Set render_mode=motion material=vox_collage (override material in the skill if user refused).'
& (Join-Path $PSScriptRoot 'fk-gen-videos.ps1') -ProjectId $ProjectId -VideoId $VideoId
Write-Host 'Next: /fk-gen-narrator then /fk-concat-fit-narrator. Do not gen-chain-videos or upscale.'
