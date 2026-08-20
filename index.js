import { existsSync, mkdirSync, readdirSync, rmdirSync, rmSync } from 'node:fs'
import { homedir, tmpdir } from 'node:os'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { spawn } from 'node:child_process'

export const name = 'desktop-launcher'
export const inject = ['desktopLauncherStartup', 'webServer']

const browserSpawnOptions = Object.freeze({ stdio: 'ignore', windowsHide: false })

function browserCandidates() {
  if (process.platform !== 'win32') return []
  const local = process.env.LOCALAPPDATA ?? join(homedir(), 'AppData', 'Local')
  return [
    join(local, 'Microsoft', 'Edge', 'Application', 'msedge.exe'),
    join(local, 'Google', 'Chrome', 'Application', 'chrome.exe'),
    join(local, 'BraveSoftware', 'Brave-Browser', 'Application', 'brave.exe'),
    join(local, 'Vivaldi', 'Application', 'vivaldi.exe'),
    'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
    'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
    'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
    'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
    'C:\\Program Files\\BraveSoftware\\Brave-Browser\\Application\\brave.exe',
    'C:\\Program Files\\Vivaldi\\Application\\vivaldi.exe',
  ]
}

function findBrowser() {
  return browserCandidates().find(path => {
    return existsSync(path)
  })
}

function psLiteral(value) {
  return `'${String(value).replaceAll("'", "''")}'`
}

function ensureDesktopShortcut(ctx, spawnProcess = spawn) {
  if (process.platform !== 'win32') return
  const packageRoot = fileURLToPath(new URL('.', import.meta.url))
  const launcher = join(packageRoot, 'plugin-launch.vbs')
  const icon = join(packageRoot, 'assets', 'dsh.ico')
  const wscript = join(process.env.SystemRoot || 'C:\\Windows', 'System32', 'wscript.exe')
  const command = [
    `$desktop = [Environment]::GetFolderPath('Desktop')`,
    `$shortcut = Join-Path $desktop 'DeepSeek Harness.lnk'`,
    `$ws = New-Object -ComObject WScript.Shell`,
    `$lnk = $ws.CreateShortcut($shortcut)`,
    `$lnk.TargetPath = ${psLiteral(wscript)}`,
    `$lnk.Arguments = ${psLiteral(`"${launcher}"`)}`,
    `$lnk.WorkingDirectory = ${psLiteral(packageRoot)}`,
    `$lnk.IconLocation = ${psLiteral(`${icon}, 0`)}`,
    `$lnk.Description = 'DeepSeek Harness Web app'`,
    `$lnk.Save()`,
  ].join('; ')
  const child = spawnProcess('powershell.exe', [
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-Command', command,
  ], { stdio: 'ignore', windowsHide: true })
  child.once('error', error => ctx.logger.warn(new Error(`desktop-launcher: could not create shortcut: ${error.message}`)))
}

function removeProfile(profileDir) {
  try {
    rmSync(profileDir, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 })
  } catch {
    // The next launch's prefix sweep is the final fallback for locked files.
  }
}

function cleanupRuntimeProfiles(runtimeRoot) {
  try {
    for (const entry of readdirSync(runtimeRoot, { withFileTypes: true })) {
      if (entry.isDirectory() && entry.name.startsWith('browser-profile-')) {
        removeProfile(join(runtimeRoot, entry.name))
      }
    }
    rmdirSync(runtimeRoot)
  } catch {
    // A missing or unreadable runtime root has nothing this plugin can clean.
  }
}

function launchApp(ctx, startup, spawnProcess = spawn) {
  if (!startup.appMode) return
  if (process.platform !== 'win32') {
    ctx.logger.warn(new Error('desktop-launcher: --app-mode is only supported on Windows'))
    return
  }
  const browser = findBrowser()
  if (!browser) {
    ctx.logger.warn(new Error('desktop-launcher: no Edge/Chrome/Brave/Vivaldi installation was found'))
    return
  }

  const runtimeRoot = startup.dataDir || process.env.DSH_LAUNCHER_RUNTIME_DIR || join(tmpdir(), 'dsh-web-app-launcher')
  cleanupRuntimeProfiles(runtimeRoot)
  mkdirSync(runtimeRoot, { recursive: true })
  const profileDir = join(runtimeRoot, `browser-profile-${process.pid}-${Date.now()}`)
  const url = `http://127.0.0.1:${ctx.webServer.port}`
  const child = spawnProcess(browser, [
    `--app=${url}`,
    `--user-data-dir=${profileDir}`,
    '--no-first-run',
    '--no-default-browser-check',
    '--disable-component-update',
    '--disable-sync',
    '--disable-extensions',
    '--disable-default-apps',
    '--disable-background-networking',
    '--window-size=1280,800',
  ], browserSpawnOptions)

  let closed = false
  const close = (code = 0) => {
    if (closed) return
    closed = true
    removeProfile(profileDir)
    cleanupRuntimeProfiles(runtimeRoot)
    const exit = ctx.get('appExit')
    if (typeof exit === 'function') exit(code)
  }
  child.once('error', () => close(1))
  child.once('exit', () => close(0))
  ctx.effect(() => async () => {
    if (!closed) child.kill()
    removeProfile(profileDir)
    cleanupRuntimeProfiles(runtimeRoot)
  }, 'desktop-launcher.app')
}

export const internals = { cleanupRuntimeProfiles, ensureDesktopShortcut, launchApp }

export function apply(ctx) {
  ensureDesktopShortcut(ctx)
  launchApp(ctx, ctx.get('desktopLauncherStartup'))
}
