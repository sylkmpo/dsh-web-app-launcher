$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$manifest = Get-Content -Raw -LiteralPath (Join-Path $root 'package.json') | ConvertFrom-Json
if ($manifest.name -ne 'dsh-web-app-launcher') { throw "unexpected plugin name: $($manifest.name)" }
if (-not $manifest.dsh.bundle.patch) { throw 'package.json must declare dsh.bundle.patch' }
if ($manifest.dependencies) { throw 'bundle must use Harness profile fallback instead of duplicating runtime dependencies' }
if (-not (Test-Path -LiteralPath (Join-Path $root 'cordis.patch.yml'))) { throw 'cordis.patch.yml is missing' }
if (-not (Test-Path -LiteralPath (Join-Path $root 'index.js'))) { throw 'index.js is missing' }
if (-not (Test-Path -LiteralPath (Join-Path $root 'startup.js'))) { throw 'startup.js is missing' }

$patch = Get-Content -Raw -LiteralPath (Join-Path $root 'cordis.patch.yml')
if ($patch -notmatch 'dsh-web-app-launcher') { throw 'bundle patch does not mount the launcher plugin' }
if ($patch -notmatch 'desktop-launcher') { throw 'bundle patch does not define a stable launcher row id' }
if ($patch -notmatch '(?ms)^- id:\s*web-startup\s+disabled:\s*true') {
    throw 'bundle patch does not disable the built-in Web argument provider'
}
if ($patch -notmatch "(?ms)- id:\s*desktop-launcher-startup\s+name:\s*'dsh-web-app-launcher/startup'") {
    throw 'bundle patch does not insert the combined argument provider'
}

$index = Get-Content -Raw -LiteralPath (Join-Path $root 'index.js')
if ($index -notmatch 'appExit') { throw 'launcher plugin does not stop dsh through appExit' }
if ($index -notmatch 'user-data-dir') { throw 'launcher plugin does not isolate browser data' }
if ($index -notmatch 'CreateShortcut') { throw 'launcher plugin does not create a desktop shortcut' }
if ($index -notmatch 'DeepSeek Harness') { throw 'launcher plugin shortcut name is missing' }
if ($index -notmatch 'plugin-launch\.vbs') { throw 'launcher plugin shortcut does not target the plugin-only hidden entry point' }
if ($index -notmatch "GetFolderPath\('Desktop'\)") { throw 'launcher plugin does not resolve the redirected Windows desktop path' }

$startup = Get-Content -Raw -LiteralPath (Join-Path $root 'startup.js')
foreach ($flag in @('--host', '--no-open', '--port', '--trusted-host', '--app-mode', '--launcher-data-dir')) {
    if ($startup -notmatch [regex]::Escape($flag)) { throw "combined startup provider is missing $flag" }
}
if ($startup -notmatch "provide\('webStartup'") { throw 'combined startup provider does not provide webStartup' }

Write-Host 'plugin manifest test passed'
