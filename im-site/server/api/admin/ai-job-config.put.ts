import { requireAdmin } from '../../utils/auth'
import { getDb } from '../../utils/db'
import { forceReconfigure } from '../../utils/cron-manager'
import { isValidCron, nextRunFrom } from '../../utils/cron-utils'

export default defineEventHandler(async (event) => {
  requireAdmin(event)
  const body = await readBody(event)
  const db = getDb()
  const old = db.prepare('SELECT * FROM ai_job_configs WHERE id = 1').get() as any
  if (!old) throw createError({ statusCode: 404, message: 'ai_job_configs 不存在' })

  const enabled = body.enabled !== undefined ? (body.enabled ? 1 : 0) : Number(old.enabled)
  const cron_expr = body.cron_expr !== undefined ? String(body.cron_expr).trim() : old.cron_expr
  const max_articles_per_run =
    body.max_articles_per_run !== undefined
      ? Math.max(1, Math.min(50, Number(body.max_articles_per_run) || 1))
      : Number(old.max_articles_per_run)
  const auto_publish = body.auto_publish !== undefined ? (body.auto_publish ? 1 : 0) : Number(old.auto_publish)

  if (cron_expr === '') {
    throw createError({ statusCode: 400, message: 'Cron 表达式不能为空' })
  }
  if (!isValidCron(cron_expr)) {
    throw createError({ statusCode: 400, message: 'Cron 表达式格式无效' })
  }

  db.prepare(
    `UPDATE ai_job_configs SET enabled = ?, cron_expr = ?, max_articles_per_run = ?, auto_publish = ? WHERE id = 1`
  ).run(enabled, cron_expr, max_articles_per_run, auto_publish)

  forceReconfigure()

  const row = db.prepare('SELECT * FROM ai_job_configs WHERE id = 1').get() as any
  let nextRunAt: string | null = null
  if (row && row.enabled === 1) {
    nextRunAt = nextRunFrom((row.cron_expr || '').trim())
    if (nextRunAt) {
      try { db.prepare(`UPDATE ai_job_configs SET next_run_at = ? WHERE id = 1`).run(nextRunAt) } catch {}
      row.next_run_at = nextRunAt
    }
  } else {
    try { db.prepare(`UPDATE ai_job_configs SET next_run_at = NULL WHERE id = 1`).run() } catch {}
  }
  return {
    code: 0,
    message: 'ok',
    data: row ? { ...row, nextRunAt } : null,
  }
})
