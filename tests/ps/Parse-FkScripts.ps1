$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$psdir = Join-Path (Resolve-Path (Join-Path $here '..\..')) 'scripts\ps'
$script:bad = 0
Get-ChildItem -Path $psdir -Filter *.ps* | Where-Object { $_.Extension -match '\.psm?1$' } | ForEach-Object {
    $tok = $null
    $err = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tok, [ref]$err)
    if ($err -and $err.Count -gt 0) {
        $script:bad++
        Write-Host $_.Name
        foreach ($e in $err) { Write-Host ('  ' + $e.ToString()) }
    }
}
if ($bad -gt 0) { exit 1 }
Write-Host 'parse-ok'
exit 0
