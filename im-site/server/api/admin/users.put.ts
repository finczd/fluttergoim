import { requireAdmin, hashPassword, resetPassword, publicUser } from '../../utils/auth'
import { getDb } from '../../utils/db'

export default defineEventHandler(async (event) => {
  const sess = requireAdmin(event)
  if (sess.role !== 'admin') {
    throw createError({ statusCode: 403, message: '仅管理员可编辑账号' })
  }
  const body = await readBody(event)
  const id = Number(body?.id)
  if (!id || id <= 0) {
    throw createError({ statusCode: 400, message: '缺少 id' })
  }
  const db = getDb()
  const target = db.prepare('SELECT * FROM admin_users WHERE id = ?').get(id) as any
  if (!target) {
    throw createError({ statusCode: 404, message: '用户不存在' })
  }

  const fields: string[] = []
  const params: any[] = []
  if (body.nickname !== undefined) {
    fields.push('nickname = ?')
    params.push(String(body.nickname))
  }
  if (body.role !== undefined) {
    const r = body.role === 'editor' ? 'editor' : 'admin'
    fields.push('role = ?')
    params.push(r)
  }
  if (body.status !== undefined) {
    fields.push('status = ?')
    params.push(body.status ? 1 : 0)
  }
  if (body.newPassword !== undefined && body.newPassword !== null && String(body.newPassword) !== '') {
    // 复用 resetPassword 逻辑（它会校验 role 与密码长度）
    resetPassword(sess.role, id, String(body.newPassword))
  }
  if (fields.length) {
    fields.push('updated_at = ?')
    params.push(new Date().toISOString())
    params.push(id)
    db.prepare(`UPDATE admin_users SET ${fields.join(', ')} WHERE id = ?`).run(...params)
  }
  const u = db.prepare('SELECT * FROM admin_users WHERE id = ?').get(id) as any
  return { code: 0, message: 'ok', data: publicUser(u) }
})
