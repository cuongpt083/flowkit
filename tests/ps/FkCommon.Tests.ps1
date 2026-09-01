# Flow Kit — FkCommon tests (Windows PowerShell 5.1)
# Run from repo root:
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\ps\FkCommon.Tests.ps1
# Optional Pester:
#   Invoke-Pester -Path .\tests\ps\FkCommon.Tests.ps1

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo = Resolve-Path (Join-Path $here '..\..')
$module = Join-Path $repo.Path 'scripts\ps\FkCommon.psm1'
Import-Module $module -Force

$script:FailCount = 0
$script:PassCount = 0

function Assert-True {
    param([string]$Name, [bool]$Condition, [string]$Detail = '')
    if ($Condition) {
        $script:PassCount++
        Write-Host "  PASS  $Name"
    }
    else {
        $script:FailCount++
        Write-Host "  FAIL  $Name  $Detail" -ForegroundColor Red
    }
}

Write-Host 'FkCommon.Tests'
Write-Host '=============='

# ConvertTo-FkJson depth
$nested = @{
    requests = @(
        @{
            type     = 'GENERATE_VIDEO'
            scene_id = 's-1'
            nested   = @{ a = 1; b = @{ c = 2 } }
        }
    )
}
$json = ConvertTo-FkJson $nested
$parsed = $json | ConvertFrom-Json
Assert-True 'json contains GENERATE_VIDEO' ($json -match 'GENERATE_VIDEO')
Assert-True 'json depth keeps nested.c' ([int]$parsed.requests[0].nested.b.c -eq 2)

# Concat list Windows paths + apostrophe
$tmp = Join-Path (Get-FkTempDir) ('concat_test_{0}.txt' -f [guid]::NewGuid().ToString('N'))
$p1 = "C:\Users\Admin\clip.mp4"
$p2 = "C:\Users\Admin\a'b.mp4"
Write-FkConcatList -Paths @($p1, $p2) -LiteralPath $tmp
$lines = [System.IO.File]::ReadAllLines($tmp)
Assert-True 'concat line 0 uses forward slashes' ($lines[0] -eq "file 'C:/Users/Admin/clip.mp4'")
Assert-True 'concat line 1 escapes apostrophe' ($lines[1] -eq "file 'C:/Users/Admin/a'\''b.mp4'")
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue

$entry = ConvertTo-FkConcatEntry -Path "D:\flow kit\scene.mp4"
Assert-True 'concat entry spaces kept' ($entry -eq "file 'D:/flow kit/scene.mp4'")

# UUID
$fromUrl = Get-FkUuidFromUrl 'https://lh3.googleusercontent.com/image/a1b2c3d4-e5f6-7890-abcd-ef1234567890?foo=1'
Assert-True 'uuid from /image/ URL' ($fromUrl -eq 'a1b2c3d4-e5f6-7890-abcd-ef1234567890')
$one = ConvertTo-FkArray ([pscustomobject]@{ id = 1 })
Assert-True 'ConvertTo-FkArray wraps scalar' ($one.Count -eq 1)
Assert-True 'Get-FkProp missing default' ((Get-FkProp ([pscustomobject]@{ a = 1 }) 'b' 'x') -eq 'x')
Assert-True 'uuid valid' (Test-FkUuid 'a1b2c3d4-e5f6-7890-abcd-ef1234567890')
Assert-True 'uuid rejects CAMS' (-not (Test-FkUuid 'CAMSabc'))
Assert-True 'uuid rejects empty' (-not (Test-FkUuid ''))
Assert-True 'uuid rejects null-like' (-not (Test-FkUuid $null))

# Python stub detection
Assert-True 'WindowsApps is stub' (Test-FkPythonStubPath 'C:\Users\Me\AppData\Local\Microsoft\WindowsApps\python.exe')
Assert-True 'real python is not stub' (-not (Test-FkPythonStubPath 'C:\Python312\python.exe'))

# Null sink
Assert-True 'null sink is NUL on Windows' ((Get-FkNullSink) -eq 'NUL')

# Temp dir
$td = Get-FkTempDir
Assert-True 'temp dir under %TEMP%\flowkit' ($td -match 'flowkit$')
Assert-True 'temp dir exists' (Test-Path -LiteralPath $td)

# Base URL
$old = $env:FK_BASE_URL
$env:FK_BASE_URL = 'http://127.0.0.1:8100/'
Assert-True 'base url strips slash' ((Get-FkBaseUrl) -eq 'http://127.0.0.1:8100')
if ($null -eq $old) { Remove-Item Env:FK_BASE_URL } else { $env:FK_BASE_URL = $old }

# Orientation
$vid = [pscustomobject]@{ orientation = 'vertical' }
Assert-True 'orientation uppercases' ((Get-FkOrientation -Video $vid) -eq 'VERTICAL')
Assert-True 'orientation default HORIZONTAL' ((Get-FkOrientation) -eq 'HORIZONTAL')

# Root
$root = Get-FkRoot
Assert-True 'repo root has setup.ps1' (Test-Path -LiteralPath (Join-Path $root 'setup.ps1'))
Assert-True 'repo root has agent' (Test-Path -LiteralPath (Join-Path $root 'agent\main.py'))

Write-Host ''
Write-Host ("Passed: {0}  Failed: {1}" -f $script:PassCount, $script:FailCount)
if ($script:FailCount -gt 0) { exit 1 }
exit 0
