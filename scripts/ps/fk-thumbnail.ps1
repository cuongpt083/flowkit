# Twin of skills/fk-thumbnail.md (generation + 1280x720 resize)
# Prompts JSON: ["prompt v1", "prompt v2", "prompt v3", "prompt v4"]
param(
    [Parameter(Mandatory = $true)][string]$ProjectId,
    [string]$PromptsJson,
    [string[]]$CharacterNames,
    [int]$CooldownSeconds = 8
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'FkCommon.psm1') -Force

$outMeta = Resolve-FkOutputDir -ProjectId $ProjectId
$thumbDir = Join-Path $outMeta.Path 'thumbnails'
New-FkDirectory $thumbDir | Out-Null
$ff = Get-FkToolPath 'ffmpeg'

if (-not [string]::IsNullOrWhiteSpace($PromptsJson)) {
    Invoke-FkHealth -RequireExtension | Out-Null
    $prompts = ConvertTo-FkArray (Read-FkJson -LiteralPath $PromptsJson)
    if ($prompts.Count -lt 1) { throw 'Prompts JSON must be a non-empty array of strings' }
    $i = 0
    foreach ($p in $prompts) {
        $i++
        $body = @{
            prompt          = [string]$p
            aspect_ratio    = 'LANDSCAPE'
            output_filename = ('thumbnail_v{0}.png' -f $i)
        }
        if ($CharacterNames -and $CharacterNames.Count -gt 0) {
            $body['character_names'] = @($CharacterNames)
        }
        Write-Host ("Generating thumbnail v{0}..." -f $i)
        try {
            Invoke-FkApi -Method POST -Path ('/api/projects/' + $ProjectId + '/generate-thumbnail') -Body $body -TimeoutSec 120 | Out-Null
        }
        catch {
            Write-Host ("  retry without character_names: {0}" -f $_.Exception.Message)
            $body.Remove('character_names')
            Invoke-FkApi -Method POST -Path ('/api/projects/' + $ProjectId + '/generate-thumbnail') -Body $body -TimeoutSec 120 | Out-Null
        }
        if ($i -lt $prompts.Count) { Start-Sleep -Seconds $CooldownSeconds }
    }
}

$pngs = @(Get-ChildItem -LiteralPath $thumbDir -Filter 'thumbnail_v*.png' -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch '_yt|_final' })
if ($pngs.Count -eq 0) {
    throw "No thumbnail_v*.png in $thumbDir. Pass -PromptsJson or generate stills first."
}
foreach ($png in $pngs) {
    $yt = Join-Path $thumbDir ($png.BaseName + '_yt.png')
    & $ff -y -i $png.FullName -vf 'scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2:color=black' $yt
    if ($LASTEXITCODE -ne 0) { throw "resize failed $($png.Name)" }
    Write-Host ("  {0} -> {1}" -f $png.Name, (Split-Path $yt -Leaf))
}
Write-Host ("Thumbnails: {0}" -f $thumbDir)
