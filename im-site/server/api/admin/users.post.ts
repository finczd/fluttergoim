import { requireAdmin, hashPassword, publicUser } from '../../utils/auth'
import { getDb } from '../../utils/db'

export default defineEventHandler(async (event) => {
  const sess = requireAdmin(event)
  if (sess.role !== 'admin') {
    throw createError({ statusCode: 403, message: '仅管理员可新增账号' })
  }
  const body = await readBody(event)
  const username = String(body?.username || '').trim()
  const password = String(body?.password || '')
  const nickname = String(body?.nickname || '').trim()
  const role = body?.role === 'editor' ? 'editor' : 'admin'
  const status = body?.status === 0 ? 0 : 1

  if (!/^[A-Za-z0-9_]{3,20}$/.test(username)) {
    throw createError({ statusCode: 400, message: '账号需 3-20 位字母/数字/下划线' })
  }
  if (password.length < 6) {
    throw createError({ statusCode: 400, message: '密码长度至少 6 位' })
  }

  const db = getDb()
  const exist = db.prepare('SELECT id FROM admin_users WHERE username = ?').get(username)
  if (exist) {
    throw createError({ statusCode: 400, message: '账号已存在' })
  }
  const hash = hashPassword(password)
  const now = new Date().toISOString()
  const info = db.prepare(
    `INSERT INTO admin_users (username, password_hash, nickname, role, status, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?)`
  ).run(username, hash, nickname, role, status, now, now)
  const u = db.prepare('SELECT * FROM admin_users WHERE id = ?').get(info.lastInsertRowid) as any
  return { code: 0, message: 'ok', data: publicUser(u) }
})
