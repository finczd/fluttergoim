import { requireAdmin, publicUser } from '../../utils/auth'
import { getDb } from '../../utils/db'

export default defineEventHandler(async (event) => {
  const sess = requireAdmin(event)
  if (sess.role !== 'admin') {
    throw createError({ statusCode: 403, message: '仅管理员可查看账号列表' })
  }
  const db = getDb()
  const rows = db.prepare('SELECT * FROM admin_users ORDER BY id ASC').all() as any[]
  return { code: 0, message: 'ok', data: rows.map(u => publicUser(u)) }
})
