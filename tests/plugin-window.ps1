$ErrorActionPreference = 'Stop'

$root = Join-Path ([IO.Path]::GetTempPath()) ("dsh-plugin-window-test-" + [guid]::NewGuid().ToString('N'))
$moduleUri = ([uri](Join-Path $PSScriptRoot '..\index.js')).AbsoluteUri
$script = @'
import { EventEmitter } from 'node:events'

import(process.argv[1]).then(({ internals }) => {
  const calls = []
  const cleanups = []
  const fakeSpawn = (file, args, options) => {
    calls.push({ file, args, options })
    const child = new EventEmitter()
    child.kill = () => {}
    return child
  }

  const ctx = {
    webServer: { port: 3080 },
    logger: { warn(error) { throw error } },
    get() { return () => {} },
    effect(register) { cleanups.push(register()) },
  }

  internals.ensureDesktopShortcut(ctx, fakeSpawn)
  internals.launchApp(ctx, { appMode: true, dataDir: process.argv[2] }, fakeSpawn)

  if (calls.length !== 2) throw new Error(`expected 2 spawn calls, got ${calls.length}`)
  if (calls[0].options.windowsHide !== true) {
    throw new Error('shortcut helper window must stay hidden')
  }
  if (calls[1].options.windowsHide !== false) {
    throw new Error('browser app window must not be hidden')
  }

  return Promise.all(cleanups.map(cleanup => cleanup()))
})
'@

try {
    & node --input-type=module -e $script $moduleUri $root
    if ($LASTEXITCODE -ne 0) { throw "Node window visibility probe exited with $LASTEXITCODE" }
} finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host 'plugin window visibility test passed'
