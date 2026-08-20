import { Command } from 'commander'
import { parseCmdline } from '@deepseek-ai/dsh-cmdline'

export const name = 'desktop-launcher-startup'
export const inject = ['cmdlineArgs']

function normalizeMode(value) {
  const normalized = String(value ?? '0').trim().toLowerCase()
  if (normalized === '0' || normalized === 'false') return false
  if (normalized === '1' || normalized === 'true') return true
  throw new Error(`--app-mode must be 0 or 1, got ${JSON.stringify(value)}`)
}

export function apply(ctx) {
  const program = new Command()
    .name('dsh --profile web')
    .description('Serve DeepSeek Harness in a browser or desktop app window.')
    .helpOption('-h, --help', '显示帮助')
    .option('--host <host>', '监听地址')
    .option('--no-open', '不使用默认浏览器打开 Web UI')
    .option('--port <port>', '监听端口；使用 0 可由系统分配空闲端口')
    .option('--trusted-host <authority...>', '额外允许的访问地址')
    .option('--app-mode <0|1>', 'open the Web UI in a disposable Chromium app window', '0')
    .option('--launcher-data-dir <path>', 'store temporary launcher data below this directory')

  program.action(() => {
    const options = program.opts()
    if (options.host === '0.0.0.0') {
      program.error('error: --host 0.0.0.0 is intentionally disabled for safety; use 127.0.0.1')
    }
    if (options.port !== undefined && !/^\d+$/.test(options.port)) {
      program.error(`error: --port must be a number, got ${JSON.stringify(options.port)}`)
    }
    let appMode
    try {
      appMode = normalizeMode(options.appMode)
    } catch (error) {
      program.error(error instanceof Error ? error.message : String(error))
    }
    ctx.provide('webStartup', {
      openBrowser: options.open && !appMode,
      ...(options.host !== undefined && { host: options.host }),
      ...(options.port !== undefined && { port: Number(options.port) }),
      trustedHosts: options.trustedHost ?? [],
    })
    ctx.provide('desktopLauncherStartup', {
      appMode,
      dataDir: options.launcherDataDir,
    })
  })
  parseCmdline(ctx, program)
}
