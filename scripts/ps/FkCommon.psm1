# Flow Kit — shared PowerShell helpers (Windows PowerShell 5.1+).
# Do not use the `curl` alias (it is Invoke-WebRequest on Windows).
# Do not use PowerShell 7-only syntax (&&, ??, $IsWindows, ternary).

Set-StrictMode -Version 1
$ErrorActionPreference = 'Stop'

function Get-FkRoot {
    # scripts/ps/ -> repo root
    return (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}

function Get-FkBaseUrl {
    $url = $env:FK_BASE_URL
    if ([string]::IsNullOrWhiteSpace($url)) {
        $url = 'http://127.0.0.1:8100'
    }
    return $url.TrimEnd('/')
}

function ConvertTo-FkJson {
    param(
        [Parameter(Mandatory = $true, Position = 0)]$InputObject
    )
    return (ConvertTo-Json -InputObject $InputObject -Depth 20 -Compress)
}

function Get-FkTempDir {
    $dir = Join-Path $env:TEMP 'flowkit'
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    return $dir
}

function New-FkDirectory {
    param(
        [Parameter(Mandatory = $true)][string]$LiteralPath
    )
    if (-not (Test-Path -LiteralPath $LiteralPath)) {
        New-Item -ItemType Directory -Path $LiteralPath -Force | Out-Null
    }
    return $LiteralPath
}

function Save-FkJson {
    param(
        [Parameter(Mandatory = $true)]$InputObject,
        [Parameter(Mandatory = $true)][string]$LiteralPath
    )
    $dir = Split-Path -Parent $LiteralPath
    if ($dir) { New-FkDirectory -LiteralPath $dir | Out-Null }
    $json = ConvertTo-FkJson $InputObject
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($LiteralPath, $json, $utf8)
}

function Read-FkJson {
    param(
        [Parameter(Mandatory = $true)][string]$LiteralPath
    )
    $raw = [System.IO.File]::ReadAllText($LiteralPath)
    return ($raw | ConvertFrom-Json)
}

function Invoke-FkApi {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('GET', 'POST', 'PATCH', 'PUT', 'DELETE')][string]$Method,
        [Parameter(Mandatory = $true)][string]$Path,
        $Body = $null,
        [int]$TimeoutSec = 120
    )
    $url = (Get-FkBaseUrl) + '/' + $Path.TrimStart('/')
    if ($null -ne $Body) {
        if ($Body -is [string]) {
            $json = $Body
        }
        else {
            $json = ConvertTo-FkJson $Body
        }
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
        return Invoke-RestMethod -Uri $url -Method $Method -Body $bytes `
            -ContentType 'application/json; charset=utf-8' -TimeoutSec $TimeoutSec
    }
    return Invoke-RestMethod -Uri $url -Method $Method -TimeoutSec $TimeoutSec
}

function Invoke-FkHealth {
    param(
        [switch]$RequireExtension
    )
    $health = Invoke-FkApi -Method GET -Path '/health'
    if (-not $health) {
        throw 'GET /health returned empty. Is the agent running? python -m agent.main'
    }
    if ($RequireExtension) {
        $connected = $false
        if ($health.PSObject.Properties.Name -contains 'extension_connected') {
            $connected = [bool]$health.extension_connected
        }
        if (-not $connected) {
            throw 'extension_connected is false. Open Google Flow in Chrome and reload the Flow Kit extension.'
        }
    }
    return $health
}

function Wait-FkBatchStatus {
    param(
        [string]$VideoId,
        [string]$ProjectId,
        [string]$Type,
        [int]$IntervalSeconds = 15,
        [int]$MaxWaitSeconds = 0
    )
    if ($IntervalSeconds -lt 1) { $IntervalSeconds = 1 }
    $elapsed = 0
    while ($true) {
        $q = @()
        if ($VideoId) { $q += ('video_id=' + [uri]::EscapeDataString($VideoId)) }
        if ($ProjectId) { $q += ('project_id=' + [uri]::EscapeDataString($ProjectId)) }
        if ($Type) { $q += ('type=' + [uri]::EscapeDataString($Type)) }
        $path = '/api/requests/batch-status'
        if ($q.Count -gt 0) { $path = $path + '?' + ($q -join '&') }
        $status = Invoke-FkApi -Method GET -Path $path
        $done = $false
        if ($status.PSObject.Properties.Name -contains 'done') {
            $done = [bool]$status.done
        }
        if ($done) { return $status }
        if ($MaxWaitSeconds -gt 0 -and $elapsed -ge $MaxWaitSeconds) {
            throw ("batch-status timed out after {0}s: {1}" -f $elapsed, (ConvertTo-FkJson $status))
        }
        Start-Sleep -Seconds $IntervalSeconds
        $elapsed += $IntervalSeconds
    }
}

function Wait-FkSeconds {
    param(
        [Parameter(Mandatory = $true)][int]$Seconds
    )
    Start-Sleep -Seconds $Seconds
}

function Test-FkPythonStubPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $true }
    return ($Path -match 'WindowsApps')
}

function Get-FkPython {
    if (-not [string]::IsNullOrWhiteSpace($env:FK_PYTHON)) {
        if (Test-FkPythonStubPath $env:FK_PYTHON) {
            throw "FK_PYTHON points at the WindowsApps stub: $($env:FK_PYTHON)"
        }
        if (-not (Test-Path -LiteralPath $env:FK_PYTHON)) {
            throw "FK_PYTHON not found: $($env:FK_PYTHON)"
        }
        return $env:FK_PYTHON
    }

    $pyLauncher = Get-Command py -ErrorAction SilentlyContinue
    if ($pyLauncher -and -not (Test-FkPythonStubPath $pyLauncher.Source)) {
        try {
            $exe = & $pyLauncher.Source -3 -c "import sys; print(sys.executable)" 2>$null
            if ($LASTEXITCODE -eq 0 -and $exe -and -not (Test-FkPythonStubPath $exe)) {
                return $exe.ToString().Trim()
            }
        }
        catch { }
    }

    foreach ($name in @('python', 'python3')) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if (-not $cmd) { continue }
        if (Test-FkPythonStubPath $cmd.Source) { continue }
        try {
            $exe = & $cmd.Source -c "import sys; print(sys.executable)" 2>$null
            if ($LASTEXITCODE -eq 0 -and $exe -and -not (Test-FkPythonStubPath $exe)) {
                return $exe.ToString().Trim()
            }
        }
        catch { }
    }

    throw 'Python 3.10+ not found. Install from https://www.python.org/downloads/ and enable "Add python.exe to PATH". Avoid the Microsoft Store stub.'
}

function Get-FkToolPath {
    param(
        [Parameter(Mandatory = $true)][string]$Name
    )
    $cmd = Get-Command ($Name + '.exe') -ErrorAction SilentlyContinue
    if (-not $cmd) {
        $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    }
    if (-not $cmd) { return $null }
    return $cmd.Source
}

function Invoke-FkFfmpeg {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]$ArgumentList
    )
    $exe = Get-FkToolPath 'ffmpeg'
    if (-not $exe) {
        throw 'ffmpeg not found on PATH. Install: winget install Gyan.FFmpeg'
    }
    & $exe @ArgumentList
    if ($LASTEXITCODE -ne 0) {
        throw "ffmpeg exited with code $LASTEXITCODE"
    }
}

function Invoke-FkFfprobe {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]$ArgumentList
    )
    $exe = Get-FkToolPath 'ffprobe'
    if (-not $exe) {
        throw 'ffprobe not found on PATH (usually bundled with ffmpeg). Install: winget install Gyan.FFmpeg'
    }
    $out = & $exe @ArgumentList
    if ($LASTEXITCODE -ne 0) {
        throw "ffprobe exited with code $LASTEXITCODE"
    }
    return $out
}

function ConvertTo-FkConcatEntry {
    param(
        [Parameter(Mandatory = $true)][string]$Path
    )
    $posix = $Path -replace '\\', '/'
    $escaped = $posix.Replace("'", "'\''")
    return "file '$escaped'"
}

function Write-FkConcatList {
    param(
        [Parameter(Mandatory = $true)][string[]]$Paths,
        [Parameter(Mandatory = $true)][string]$LiteralPath
    )
    $dir = Split-Path -Parent $LiteralPath
    if ($dir) { New-FkDirectory -LiteralPath $dir | Out-Null }
    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($p in $Paths) {
        [void]$lines.Add((ConvertTo-FkConcatEntry -Path $p))
    }
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllLines($LiteralPath, $lines.ToArray(), $utf8)
}

function Get-FkArialBold {
    $windir = $env:WINDIR
    if ([string]::IsNullOrWhiteSpace($windir)) {
        $windir = 'C:\Windows'
    }
    $candidates = @(
        (Join-Path $windir 'Fonts\arialbd.ttf'),
        (Join-Path $windir 'Fonts\Arial Bold.ttf')
    )
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c) { return $c }
    }
    throw "Arial Bold not found. Expected one of: $($candidates -join ', ')"
}

function Get-FkNullSink {
    if ($env:OS -eq 'Windows_NT') { return 'NUL' }
    return '/dev/null'
}

function Test-FkUuid {
    param(
        [string]$Value
    )
    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    return [bool]($Value -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
}

function Get-FkOrientation {
    param(
        $Video,
        $Project
    )
    $ori = $null
    if ($Video -and ($Video.PSObject.Properties.Name -contains 'orientation')) {
        $ori = $Video.orientation
    }
    if ([string]::IsNullOrWhiteSpace($ori) -and $Project -and ($Project.PSObject.Properties.Name -contains 'orientation')) {
        $ori = $Project.orientation
    }
    if ([string]::IsNullOrWhiteSpace($ori)) {
        $ori = 'HORIZONTAL'
    }
    return $ori.ToString().ToUpperInvariant()
}

function Save-FkUrlToFile {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$LiteralPath
    )
    $dir = Split-Path -Parent $LiteralPath
    if ($dir) { New-FkDirectory -LiteralPath $dir | Out-Null }
    $wc = New-Object System.Net.WebClient
    try {
        $wc.DownloadFile($Url, $LiteralPath)
    }
    finally {
        $wc.Dispose()
    }
}

function ConvertTo-FkArray {
    param($Value)
    if ($null -eq $Value) { return , @() }
    if ($Value -is [System.Array]) { return , @($Value) }
    # Unary comma: PowerShell unwraps single-element arrays on return.
    return , @($Value)
}

function Get-FkProp {
    param(
        $Object,
        [Parameter(Mandatory = $true)][string]$Name,
        $Default = $null
    )
    if ($null -eq $Object) { return $Default }
    if ($Object -is [hashtable]) {
        if ($Object.ContainsKey($Name)) { return $Object[$Name] }
        return $Default
    }
    $prop = $Object.PSObject.Properties[$Name]
    if ($prop) { return $prop.Value }
    return $Default
}

function Get-FkUuidFromUrl {
    param([string]$Url)
    if ([string]::IsNullOrWhiteSpace($Url)) { return $null }
    $m = [regex]::Match($Url, '/(?:image|video)/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})')
    if ($m.Success) { return $m.Groups[1].Value }
    $m2 = [regex]::Match($Url, '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})')
    if ($m2.Success) { return $m2.Groups[1].Value }
    return $null
}

function Get-FkFieldPrefix {
    param(
        [string]$Orientation
    )
    if ([string]::IsNullOrWhiteSpace($Orientation)) {
        $Orientation = 'HORIZONTAL'
    }
    return $Orientation.ToString().ToLowerInvariant()
}

function Resolve-FkProjectId {
    param([string]$ProjectId)
    if (-not [string]::IsNullOrWhiteSpace($ProjectId)) {
        return $ProjectId
    }
    $ap = Invoke-FkApi -Method GET -Path '/api/active-project'
    $id = Get-FkProp $ap 'project_id'
    if ([string]::IsNullOrWhiteSpace($id)) {
        throw 'No -ProjectId and no active project. Run fk-switch-project.ps1 or pass -ProjectId.'
    }
    return [string]$id
}

function Resolve-FkVideo {
    param(
        [string]$ProjectId,
        [string]$VideoId
    )
    if (-not [string]::IsNullOrWhiteSpace($VideoId)) {
        return Invoke-FkApi -Method GET -Path ('/api/videos/' + $VideoId)
    }
    $list = ConvertTo-FkArray (Invoke-FkApi -Method GET -Path ('/api/videos?project_id=' + [uri]::EscapeDataString($ProjectId)))
    if ($list.Count -eq 0) {
        throw "No videos for project $ProjectId"
    }
    return $list[0]
}

function Submit-FkBatch {
    param(
        [Parameter(Mandatory = $true)][array]$Requests
    )
    if ($Requests.Count -eq 0) {
        return @{ submitted = 0; skipped = $true }
    }
    $body = @{ requests = @($Requests) }
    return Invoke-FkApi -Method POST -Path '/api/requests/batch' -Body $body
}

function Get-FkInFlightSceneIds {
    param(
        [string]$VideoId,
        [string[]]$Types
    )
    $reqs = ConvertTo-FkArray (Invoke-FkApi -Method GET -Path ('/api/requests?video_id=' + [uri]::EscapeDataString($VideoId)))
    $set = @{}
    foreach ($r in $reqs) {
        $st = [string](Get-FkProp $r 'status')
        $ty = [string](Get-FkProp $r 'type')
        if ($Types -notcontains $ty) { continue }
        if ($st -ne 'PENDING' -and $st -ne 'PROCESSING') { continue }
        $sid = Get-FkProp $r 'scene_id'
        if ($sid) { $set[[string]$sid] = $true }
    }
    # Unary comma: prevent PowerShell from enumerating hashtable keys.
    return , $set
}

function Resolve-FkOutputDir {
    param([Parameter(Mandatory = $true)][string]$ProjectId)
    $meta = Invoke-FkApi -Method GET -Path ('/api/projects/' + $ProjectId + '/output-dir')
    $rel = [string](Get-FkProp $meta 'path')
    $slug = [string](Get-FkProp $meta 'slug')
    if ([string]::IsNullOrWhiteSpace($rel)) { throw "output-dir missing path for $ProjectId" }
    $path = $rel -replace '/', '\'
    if (-not [IO.Path]::IsPathRooted($path)) {
        $path = Join-Path (Get-FkRoot) $path
    }
    New-FkDirectory -LiteralPath $path | Out-Null
    return @{ Path = $path; Slug = $slug; Meta = $meta }
}

function Get-FkDurationSec {
    param([Parameter(Mandatory = $true)][string]$LiteralPath)
    $exe = Get-FkToolPath 'ffprobe'
    if (-not $exe) { throw 'ffprobe not found on PATH' }
    $out = & $exe -v quiet -show_entries format=duration -of csv=p=0 $LiteralPath
    if ($LASTEXITCODE -ne 0) { throw "ffprobe duration failed: $LiteralPath" }
    $s = ("$out").Trim()
    if ([string]::IsNullOrWhiteSpace($s)) { throw "ffprobe empty duration: $LiteralPath" }
    return [double]$s
}

function Get-FkVideoWidth {
    param([Parameter(Mandatory = $true)][string]$LiteralPath)
    $exe = Get-FkToolPath 'ffprobe'
    if (-not $exe) { throw 'ffprobe not found on PATH' }
    $out = & $exe -v quiet -select_streams v:0 -show_entries stream=width,height -of csv=p=0 $LiteralPath
    if ($LASTEXITCODE -ne 0) { throw "ffprobe size failed: $LiteralPath" }
    $parts = ("$out").Trim().Split(',')
    $w = [int]$parts[0]
    $h = 0
    if ($parts.Count -gt 1) { $h = [int]$parts[1] }
    return @{ Width = $w; Height = $h }
}

function Test-FkMediaFile {
    param(
        [string]$LiteralPath,
        [int]$MinBytes = 10000
    )
    if ([string]::IsNullOrWhiteSpace($LiteralPath)) { return $false }
    if (-not (Test-Path -LiteralPath $LiteralPath)) { return $false }
    $len = (Get-Item -LiteralPath $LiteralPath).Length
    if ($len -lt $MinBytes) { return $false }
    $exe = Get-FkToolPath 'ffprobe'
    if (-not $exe) { return $false }
    & $exe -v quiet -select_streams v:0 -show_entries stream=codec_type -of csv=p=0 $LiteralPath | Out-Null
    return ($LASTEXITCODE -eq 0)
}

function Test-FkSignedUrl {
    param([string]$Url)
    if ([string]::IsNullOrWhiteSpace($Url)) { return $false }
    if ($Url -notmatch 'Expires=(\d+)') { return $false }
    $exp = [int64]$Matches[1]
    $now = [int64](((Get-Date).ToUniversalTime() - [datetime]'1970-01-01').TotalSeconds)
    return ($exp -gt $now)
}

function Invoke-FkXfadeChain {
    param(
        [Parameter(Mandatory = $true)][string[]]$Inputs,
        [Parameter(Mandatory = $true)][string]$Output,
        [double]$Xfade = 0.4
    )
    if ($Inputs.Count -eq 1) {
        Copy-Item -LiteralPath $Inputs[0] -Destination $Output -Force
        return
    }
    $exe = Get-FkToolPath 'ffmpeg'
    if (-not $exe) { throw 'ffmpeg not found on PATH' }
    $ffArgs = New-Object System.Collections.Generic.List[string]
    [void]$ffArgs.Add('-y')
    foreach ($inp in $Inputs) {
        [void]$ffArgs.Add('-i')
        [void]$ffArgs.Add($inp)
    }
    $durs = New-Object System.Collections.Generic.List[double]
    foreach ($inp in $Inputs) { [void]$durs.Add((Get-FkDurationSec -LiteralPath $inp)) }
    $vfilters = New-Object System.Collections.Generic.List[string]
    $afilters = New-Object System.Collections.Generic.List[string]
    $cum = [double]$durs[0]
    $n = $Inputs.Count
    for ($i = 0; $i -lt ($n - 1); $i++) {
        $offset = $cum - $Xfade
        if ($offset -lt 0) { $offset = 0 }
        if ($i -eq 0) { $vin = '[0:v][1:v]'; $ain = '[0:a][1:a]' }
        else { $vin = "[v$i][$($i+1):v]"; $ain = "[a$i][$($i+1):a]" }
        if ($i -eq ($n - 2)) { $vout = '[vout]'; $aout = '[aout]' }
        else { $vout = "[v$($i+1)]"; $aout = "[a$($i+1)]" }
        [void]$vfilters.Add(('{0}xfade=transition=fade:duration={1}:offset={2}{3}' -f $vin, $Xfade, $offset, $vout))
        [void]$afilters.Add(('{0}acrossfade=d={1}{2}' -f $ain, $Xfade, $aout))
        $cum = $offset + [double]$durs[$i + 1]
    }
    $fc = (@($vfilters) + @($afilters)) -join ';'
    [void]$ffArgs.Add('-filter_complex')
    [void]$ffArgs.Add($fc)
    [void]$ffArgs.Add('-map'); [void]$ffArgs.Add('[vout]')
    [void]$ffArgs.Add('-map'); [void]$ffArgs.Add('[aout]')
    foreach ($x in @('-c:v', 'libx264', '-preset', 'fast', '-crf', '18', '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-ar', '48000', '-ac', '2', '-movflags', '+faststart', $Output)) {
        [void]$ffArgs.Add($x)
    }
    & $exe @($ffArgs.ToArray())
    if ($LASTEXITCODE -ne 0) { throw "ffmpeg xfade failed for $Output" }
}

Export-ModuleMember -Function @(
    'Get-FkRoot',
    'Get-FkBaseUrl',
    'ConvertTo-FkJson',
    'Get-FkTempDir',
    'New-FkDirectory',
    'Save-FkJson',
    'Read-FkJson',
    'Invoke-FkApi',
    'Invoke-FkHealth',
    'Wait-FkBatchStatus',
    'Wait-FkSeconds',
    'Test-FkPythonStubPath',
    'Get-FkPython',
    'Get-FkToolPath',
    'Invoke-FkFfmpeg',
    'Invoke-FkFfprobe',
    'ConvertTo-FkConcatEntry',
    'Write-FkConcatList',
    'Get-FkArialBold',
    'Get-FkNullSink',
    'Test-FkUuid',
    'Get-FkOrientation',
    'Save-FkUrlToFile',
    'ConvertTo-FkArray',
    'Get-FkProp',
    'Get-FkUuidFromUrl',
    'Get-FkFieldPrefix',
    'Resolve-FkProjectId',
    'Resolve-FkVideo',
    'Submit-FkBatch',
    'Get-FkInFlightSceneIds',
    'Resolve-FkOutputDir',
    'Get-FkDurationSec',
    'Get-FkVideoWidth',
    'Test-FkMediaFile',
    'Test-FkSignedUrl',
    'Invoke-FkXfadeChain'
)
