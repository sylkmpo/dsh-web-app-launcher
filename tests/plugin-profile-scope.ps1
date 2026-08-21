$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$patch = Get-Content -Raw -LiteralPath (Join-Path $root 'cordis.patch.yml')
$webProfileGuard = 'disabled:\s*!!js\s*>-\s*\r?\n\s*!Array\.from\(ctx\.loader\.entries\(\)\)\.some\(entry => entry\.options\.id === ''web-startup''\)'

foreach ($id in @('desktop-launcher-startup', 'desktop-launcher')) {
    $entry = "(?ms)- id:\s*$([regex]::Escape($id))\s+.*?(?=\r?\n\s*- id:|\z)"
    if ($patch -notmatch $entry) { throw "bundle patch is missing $id" }
    if ($Matches[0] -notmatch $webProfileGuard) {
        throw "$id must stay disabled outside profiles that contain web-startup"
    }
}

Write-Host 'plugin profile scope test passed'
