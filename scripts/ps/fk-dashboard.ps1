# Twin of skills/fk-dashboard.md — wire Claude Code statusline to scripts/statusline.ps1
param(
    [switch]$PrintOnly
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'FkCommon.psm1') -Force

$root = Get-FkRoot
$script = Join-Path $root 'scripts\statusline.ps1'
$cmd = 'powershell -NoProfile -ExecutionPolicy Bypass -File "' + $script + '"'
Write-Host 'Claude Code statusLine command:'
Write-Host $cmd

if ($PrintOnly) { return }

$settingsDir = Join-Path $root '.claude'
$settings = Join-Path $settingsDir 'settings.local.json'
New-FkDirectory $settingsDir | Out-Null
$data = @{ statusLine = @{ type = 'command'; command = $cmd } }
if (Test-Path -LiteralPath $settings) {
    try {
        $existing = Read-FkJson -LiteralPath $settings
        $ht = @{}
        foreach ($p in $existing.PSObject.Properties) { $ht[$p.Name] = $p.Value }
        $ht['statusLine'] = @{ type = 'command'; command = $cmd }
        $data = $ht
    }
    catch { }
}
Save-FkJson -InputObject $data -LiteralPath $settings
Write-Host ("Wrote {0}" -f $settings)
Write-Host 'Restart Claude Code to see GLA in the statusline. Unix hosts keep scripts/statusline.sh.'
