import { requireAdmin } from '../../utils/auth'
import { getDb } from '../../utils/db'

export default defineEventHandler(async (event) => {
  requireAdmin(event)
  const q = getQuery(event)
  const page = Math.max(1, Number(q.page) || 1)
  const pageSize = Math.min(100, Math.max(1, Number(q.pageSize) || 20))
  const offset = (page - 1) * pageSize
  const db = getDb()
  const totalRow = db.prepare('SELECT COUNT(*) AS c FROM ai_job_runs').get() as any
  const list = db.prepare(
    `SELECT * FROM ai_job_runs ORDER BY started_at DESC LIMIT ? OFFSET ?`
  ).all(pageSize, offset) as any[]
  return {
    code: 0,
    message: 'ok',
    data: {
      total: Number(totalRow?.c || 0),
      page,
      pageSize,
      list,
    },
  }
})
