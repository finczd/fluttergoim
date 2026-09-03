import { requireAdmin, publicUser } from '../../utils/auth'
import { getDb } from '../../utils/db'

export default defineEventHandler(async (event) => {
  const sess = requireAdmin(event)
  const db = getDb()
  const u = db.prepare('SELECT * FROM admin_users WHERE id = ?').get(sess.userId) as any
  if (!u) {
    throw createError({ statusCode: 401, message: '账号不存在' })
  }
  return { code: 0, message: 'ok', data: publicUser(u) }
})
