import { requireAdmin } from '../../utils/auth'
import { getDb } from '../../utils/db'

export default defineEventHandler(async (event) => {
  const sess = requireAdmin(event)
  if (sess.role !== 'admin') {
    throw createError({ statusCode: 403, message: '仅管理员可删除账号' })
  }
  const body = await readBody(event)
  const id = Number(body?.id)
  if (!id || id <= 0) {
    throw createError({ statusCode: 400, message: '缺少 id' })
  }
  if (id === sess.userId) {
    throw createError({ statusCode: 400, message: '不能删除当前登录账号' })
  }
  const db = getDb()
  const info = db.prepare('DELETE FROM admin_users WHERE id = ?').run(id)
  if (info.changes === 0) {
    throw createError({ statusCode: 404, message: '用户不存在' })
  }
  return { code: 0, message: 'ok' }
})
