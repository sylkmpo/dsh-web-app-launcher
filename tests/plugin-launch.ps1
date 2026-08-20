$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$source = Get-Content -Raw -LiteralPath (Join-Path $root 'plugin-launch.vbs')
$probeDir = Join-Path ([IO.Path]::GetTempPath()) ("dsh-plugin-vbs-test-" + [guid]::NewGuid().ToString('N'))
$probe = Join-Path $probeDir 'plugin-launch-probe.vbs'

try {
    New-Item -ItemType Directory -Force -Path $probeDir | Out-Null
    $probeSource = $source.Replace('sh.Run ', 'WScript.Echo ')
    Set-Content -LiteralPath $probe -Value $probeSource -Encoding ASCII

    $output = & cscript.exe //nologo $probe 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "plugin-launch.vbs does not compile: $($output -join ' ')"
    }
    $expected = 'cmd /c "' + $probeDir + '\plugin-run.bat" 0 0'
    if (($output -join "`n").Trim() -ne $expected) {
        throw "unexpected hidden launch command: $($output -join ' ')"
    }
} finally {
    Remove-Item -LiteralPath $probeDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host 'plugin launch test passed'
