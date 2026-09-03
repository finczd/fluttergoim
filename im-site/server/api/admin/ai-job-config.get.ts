import { requireAdmin } from '../../utils/auth'
import { getDb } from '../../utils/db'
import { nextRunFrom } from '../../utils/cron-utils'

export default defineEventHandler(async (event) => {
  requireAdmin(event)
  const db = getDb()
  const row = db.prepare('SELECT * FROM ai_job_configs WHERE id = 1').get() as any
  let nextRunAt: string | null = null
  if (row && row.enabled === 1) {
    nextRunAt = row.next_run_at || nextRunFrom((row.cron_expr || '').trim())
  }
  return {
    code: 0,
    message: 'ok',
    data: row
      ? {
          ...row,
          nextRunAt,
        }
      : null,
  }
})
