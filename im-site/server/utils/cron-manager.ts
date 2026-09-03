import cron from 'node-cron'
import { getDb } from './db'
import { runAiArticleJob } from './ai-runner'
import { isValidCron, nextRunFrom } from './cron-utils'

interface JobConfigRow {
  id: number
  enabled: number
  cron_expr: string
  max_articles_per_run: number
  auto_publish: number
  last_run_at: string | null
  next_run_at: string | null
}

let _started = false
let _task: cron.ScheduledTask | null = null
let _currentExpr = ''
let _currentEnabled = 0
let _pollTimer: ReturnType<typeof setInterval> | null = null

function computeNextRun(expr: string, _from?: Date): string | null {
  return nextRunFrom(expr)
}

function applyConfig(db: any, cfg: JobConfigRow) {
  const wantEnabled = cfg.enabled === 1
  const wantExpr = (cfg.cron_expr || '').trim()
  const valid = isValidCron(wantExpr)

  // 相同则不重排
  if (wantEnabled === !!_currentEnabled && wantExpr === _currentExpr) {
    // 仍然确保 next_run_at 写入（首次场景）
    if (wantEnabled && valid) {
      const next = computeNextRun(wantExpr)
      if (next) {
        try { db.prepare(`UPDATE ai_job_configs SET next_run_at = ? WHERE id = 1`).run(next) } catch {}
      }
    }
    return
  }

  // 停掉旧任务
  if (_task) {
    try { _task.stop() } catch {}
    _task = null
  }
  _currentExpr = ''
  _currentEnabled = 0

  if (wantEnabled && valid) {
    try {
      const task = cron.schedule(
        wantExpr,
        async () => {
          try {
            await runAiArticleJob('cron')
          } catch { /* runner 已自行写 error_message */ }
        },
        {
          scheduled: true,
          timezone: 'Asia/Shanghai',
          name: 'ai_articles',
        } as any
      )
      _task = task
      _currentExpr = wantExpr
      _currentEnabled = 1
      const next = computeNextRun(wantExpr)
      try {
        if (next) {
          db.prepare(`UPDATE ai_job_configs SET next_run_at = ? WHERE id = 1`).run(next)
        }
      } catch {}
    } catch (e) {
      console.warn('[cron-manager] schedule failed:', e)
      try {
        db.prepare(`UPDATE ai_job_configs SET next_run_at = NULL WHERE id = 1`).run()
      } catch {}
    }
  } else {
    // 关闭或无效：清空 next_run_at
    try {
      db.prepare(`UPDATE ai_job_configs SET next_run_at = NULL WHERE id = 1`).run()
    } catch {}
  }
}

function pollDbCheck() {
  try {
    const db = getDb()
    const cfg = db.prepare('SELECT * FROM ai_job_configs WHERE id = 1').get() as JobConfigRow | undefined
    if (cfg) applyConfig(db, cfg)
  } catch (e) {
    console.warn('[cron-manager] poll error:', e)
  }
}

export function startCronScheduler(): void {
  if (_started) return
  _started = true
  try {
    const db = getDb()
    const cfg = db.prepare('SELECT * FROM ai_job_configs WHERE id = 1').get() as JobConfigRow | undefined
    if (cfg) applyConfig(db, cfg)

    // 每 5 分钟重新读取 DB，支持配置变更后自动重排
    _pollTimer = setInterval(() => {
      pollDbCheck()
    }, 5 * 60 * 1000)
    if (typeof (_pollTimer as any).unref === 'function') {
      (_pollTimer as any).unref()
    }
  } catch (e) {
    console.warn('[cron-manager] start failed:', e)
  }
}

/**
 * 供保存配置接口调用：立即重新加载配置并重新 schedule
 */
export function forceReconfigure(): void {
  pollDbCheck()
}
