# Flow Kit — Windows PowerShell setup (Windows 10 / 11, PowerShell 5.1+)
# Usage (from repo root):
#   Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
#   .\setup.ps1

Set-StrictMode -Version 1
$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModulePath = Join-Path $Root 'scripts\ps\FkCommon.psm1'
if (-not (Test-Path -LiteralPath $ModulePath)) {
    Write-Host "ERROR: missing $ModulePath" -ForegroundColor Red
    exit 1
}
Import-Module $ModulePath -Force

Write-Host '========================================='
Write-Host '  Flow Kit — Setup (Windows PowerShell)'
Write-Host '========================================='
Write-Host ''

$Errors = 0

# ─── Python ──────────────────────────────────────────────────
Write-Host 'Checking Python...'
$Python = $null
try {
    $Python = Get-FkPython
    $VerLine = & $Python --version 2>&1
    $Ver = (& $Python -c "import sys; print('%d.%d' % (sys.version_info[0], sys.version_info[1]))").Trim()
    $parts = $Ver.Split('.')
    $major = [int]$parts[0]
    $minor = [int]$parts[1]
    if ($major -gt 3 -or ($major -eq 3 -and $minor -ge 10)) {
        Write-Host "  OK: $VerLine  ($Python)"
    }
    else {
        Write-Host "  WARNING: Python $Ver found, 3.10+ recommended ($Python)"
    }
}
catch {
    Write-Host "  MISSING: $($_.Exception.Message)"
    Write-Host '  Install: https://www.python.org/downloads/  (enable "Add python.exe to PATH")'
    Write-Host '  Do not use the Microsoft Store python stub (WindowsApps).'
    $Errors++
}

# ─── pip ─────────────────────────────────────────────────────
if ($Python) {
    Write-Host 'Checking pip...'
    try {
        $pipOut = & $Python -m pip --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  OK: $pipOut"
        }
        else {
            throw 'pip --version failed'
        }
    }
    catch {
        Write-Host '  MISSING: pip not found'
        Write-Host "  Install: $Python -m ensurepip --upgrade"
        $Errors++
    }
}

# ─── ffmpeg / ffprobe ────────────────────────────────────────
Write-Host 'Checking ffmpeg...'
$ffmpeg = Get-FkToolPath 'ffmpeg'
if ($ffmpeg) {
    $ffVer = & $ffmpeg -version 2>&1 | Select-Object -First 1
    Write-Host "  OK: $ffVer"
}
else {
    Write-Host '  MISSING: ffmpeg not found (needed for video concat/trim/music)'
    Write-Host '  Install: winget install Gyan.FFmpeg'
    Write-Host '  Then open a NEW PowerShell window so PATH updates.'
    $Errors++
}

Write-Host 'Checking ffprobe...'
$ffprobe = Get-FkToolPath 'ffprobe'
if ($ffprobe) {
    Write-Host "  OK: ffprobe available ($ffprobe)"
}
else {
    Write-Host '  MISSING: ffprobe not found (usually bundled with ffmpeg)'
    $Errors++
}

# ─── Chrome ──────────────────────────────────────────────────
Write-Host 'Checking Chrome...'
$chrome = $null
$chromeReg = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe'
try {
    if (Test-Path $chromeReg) {
        $chrome = (Get-ItemProperty $chromeReg).'(default)'
    }
}
catch { }
if (-not $chrome) {
    $guesses = @(
        "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
    )
    foreach ($g in $guesses) {
        if (Test-Path -LiteralPath $g) { $chrome = $g; break }
    }
}
if ($chrome) {
    Write-Host "  OK: Chrome found ($chrome)"
}
else {
    Write-Host '  WARNING: Chrome not detected (needed for the Flow Kit extension)'
    Write-Host '  Download: https://www.google.com/chrome/'
}

Write-Host ''
Write-Host 'Note: the extension connects to ws://127.0.0.1:9222'
Write-Host '  If you launch Chrome with --remote-debugging-port=9222, the agent WebSocket will conflict.'
Write-Host '  Leave WS_PORT at 9222 unless you change both the agent and extension.'
Write-Host ''

if ($Errors -gt 0) {
    Write-Host "Found $Errors missing dependency(ies). Install them and re-run." -ForegroundColor Yellow
    exit 1
}

# ─── Virtual environment ────────────────────────────────────
Write-Host 'Setting up Python virtual environment...'
$VenvDir = Join-Path $Root 'venv'
$VenvPython = Join-Path $VenvDir 'Scripts\python.exe'
if (-not (Test-Path -LiteralPath $VenvPython)) {
    & $Python -m venv $VenvDir
    Write-Host '  Created: venv'
}
else {
    Write-Host '  Exists: venv'
}

Write-Host 'Installing Python dependencies...'
& $VenvPython -m pip install -q --upgrade pip
& $VenvPython -m pip install -q -r (Join-Path $Root 'requirements.txt')
Write-Host '  Installed requirements.txt'

Write-Host 'Verifying agent can import...'
Push-Location $Root
try {
    & $VenvPython -c "from agent.main import app; print('  OK: agent.main imports successfully')"
    if ($LASTEXITCODE -ne 0) {
        throw 'import failed'
    }
}
catch {
    Write-Host '  FAILED: agent cannot import — check error above'
    Pop-Location
    exit 1
}
finally {
    Pop-Location
}

Write-Host ''
Write-Host '========================================='
Write-Host '  Setup complete!'
Write-Host '========================================='
Write-Host @'

Next steps:

  1. Load Chrome extension:
     chrome://extensions  then  Developer mode  then  Load unpacked  then  the extension folder

  2. Open Google Flow and sign in:
     https://labs.google/fx/tools/flow

  3. Start the agent (this window):
     .\venv\Scripts\Activate.ps1
     python -m agent.main

  4. Verify (new window):
     Invoke-RestMethod http://127.0.0.1:8100/health
     Expect extension_connected true

  Optional AI tool configs:
     python setup.py

  PowerShell skill twins: scripts\ps\  (see scripts\ps\README.md)
  Claude statusline (Windows): .\scripts\ps\fk-dashboard.ps1

'@

