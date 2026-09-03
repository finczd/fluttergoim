import { requireAdmin } from '../../utils/auth'
import { getDb } from '../../utils/db'
import { maskApiKey } from '../../utils/cron-utils'

function safeJsonParse(s: string) {
  try {
    const v = JSON.parse(s)
    if (Array.isArray(v)) return v
  } catch {}
  if (typeof s === 'string' && s.includes(',')) {
    return s.split(/[,，]/).map(x => x.trim()).filter(Boolean)
  }
  return []
}

export default defineEventHandler(async (event) => {
  const sess = requireAdmin(event)
  const q = getQuery(event)
  const raw = String(q.raw || '') === '1'
  if (raw && sess.role !== 'admin') {
    throw createError({ statusCode: 403, message: '仅管理员可查看原始 API Key' })
  }
  const db = getDb()
  const row = db.prepare(
    `SELECT a.*, c.name AS default_category_name
     FROM ai_configs a LEFT JOIN categories c ON c.id = a.default_category_id
     WHERE a.id = 1`
  ).get() as any
  const categories = db.prepare('SELECT id, name FROM categories ORDER BY id ASC').all() as any[]
  const masked = row
    ? {
        ...row,
        api_key: maskApiKey(row.api_key || '', raw),
        default_tags: row.default_tags ? safeJsonParse(row.default_tags) : [],
      }
    : null
  return { code: 0, message: 'ok', data: { config: masked, categories } }
})
