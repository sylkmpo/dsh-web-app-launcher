$ErrorActionPreference = 'Stop'

$root = Join-Path ([IO.Path]::GetTempPath()) ("dsh-plugin-runtime-test-" + [guid]::NewGuid().ToString('N'))
$profile = Join-Path $root 'browser-profile-stale'
$unrelated = Join-Path $root 'keep-user-data'

try {
    New-Item -ItemType Directory -Force -Path $profile, $unrelated | Out-Null
    Set-Content -LiteralPath (Join-Path $profile 'Cache') -Value 'stale'
    Set-Content -LiteralPath (Join-Path $unrelated 'data.txt') -Value 'keep'

    $moduleUri = ([uri](Join-Path $PSScriptRoot '..\index.js')).AbsoluteUri
    $script = "import('$moduleUri').then(({ internals }) => internals.cleanupRuntimeProfiles(process.argv[1]))"
    & node --input-type=module -e $script $root
    if ($LASTEXITCODE -ne 0) { throw "Node cleanup probe exited with $LASTEXITCODE" }

    if (Test-Path -LiteralPath $profile) { throw 'plugin left a stale browser profile behind' }
    if (-not (Test-Path -LiteralPath (Join-Path $unrelated 'data.txt'))) {
        throw 'plugin removed unrelated runtime data'
    }

    Remove-Item -LiteralPath $unrelated -Recurse -Force
    New-Item -ItemType Directory -Force -Path $profile | Out-Null
    Set-Content -LiteralPath (Join-Path $profile 'Cache') -Value 'stale again'
    & node --input-type=module -e $script $root
    if ($LASTEXITCODE -ne 0) { throw "Node empty-root cleanup probe exited with $LASTEXITCODE" }
    if (Test-Path -LiteralPath $root) { throw 'plugin left an empty runtime root behind' }
} finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host 'plugin runtime cleanup test passed'
