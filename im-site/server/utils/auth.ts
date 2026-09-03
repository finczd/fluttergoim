import type { H3Event } from 'h3'
import bcrypt from 'bcryptjs'
import { randomBytes } from 'node:crypto'
import { getDb } from './db'

const SESSION_COOKIE = 'cp_admin_session'
const SESSION_TTL = 1000 * 60 * 60 * 24 // 24h

/**
 * requireDb(): 每次访问前显式调用确保 admin_users / ai_configs 等新表已创建。
 * 原因：dev 服务器重启时 middleware 与 plugin 的执行顺序不稳定，
 * 旧版 data/chatpulse.db 文件已存在时容易出现 "no such table"。
 */
function requireDb() { return getDb() }

interface Session {
  sid: string
  userId: number
  username: string
  role: string
  createdAt: number
  expireAt: number
}

// 进程内 session store（开发友好；生产 SQLite 重启不丢）
const _sessions = new Map<string, Session>()

function cleanExpired() {
  const now = Date.now()
  for (const [sid, s] of _sessions.entries()) {
    if (s.expireAt < now) _sessions.delete(sid)
  }
}

export function hashPassword(pwd: string) {
  return bcrypt.hashSync(pwd, 10)
}
export function verifyPassword(pwd: string, hash: string) {
  return bcrypt.compareSync(pwd, hash)
}

/**
 * 登录：校验用户名密码，返回 session
 * 失败抛错（H3Error）
 */
export function login(event: H3Event, username: string, password: string, ip?: string) {
  requireDb()
  if (!username || typeof username !== 'string' || !password || typeof password !== 'string') {
    throw createError({ statusCode: 400, message: '请输入用户名和密码' })
  }
  const db = getDb()
  const user = db.prepare('SELECT * FROM admin_users WHERE username = ?').get(username.trim()) as any
  if (!user || user.status !== 1) {
    throw createError({ statusCode: 401, message: '账号不存在或已禁用' })
  }
  if (!verifyPassword(password, user.password_hash)) {
    throw createError({ statusCode: 401, message: '用户名或密码错误' })
  }
  cleanExpired()
  const now = Date.now()
  const sid = randomBytes(32).toString('hex')
  const sess: Session = {
    sid,
    userId: user.id,
    username: user.username,
    role: user.role,
    createdAt: now,
    expireAt: now + SESSION_TTL,
  }
  _sessions.set(sid, sess)

  // DB 记录最后登录时间 IP
  try {
    db.prepare('UPDATE admin_users SET last_login_at = ?, last_login_ip = ?, updated_at = ? WHERE id = ?')
      .run(new Date().toISOString(), ip || null, new Date().toISOString(), user.id)
  } catch {}

  // 写 Cookie：HttpOnly + SameSite=Lax + Secure(HTTPS)
  const protocol = getRequestProtocol(event)
  const secure = protocol === 'https'
  setCookie(event, SESSION_COOKIE, sid, {
    httpOnly: true,
    path: '/',
    secure,
    sameSite: secure ? 'none' : 'lax',
    maxAge: SESSION_TTL / 1000,
  })
  return { sid, user: publicUser(user) }
}

export function logout(event: H3Event) {
  const sid = getCookie(event, SESSION_COOKIE)
  if (sid) _sessions.delete(sid)
  deleteCookie(event, SESSION_COOKIE, { path: '/' })
  return true
}

export function getSession(event: H3Event): Session | null {
  requireDb()
  const sid = getCookie(event, SESSION_COOKIE)
  if (!sid) return null
  const s = _sessions.get(sid)
  if (!s) return null
  if (s.expireAt < Date.now()) {
    _sessions.delete(sid)
    return null
  }
  return s
}

/** 需要管理员登录态的接口调用，未登录直接 401 */
export function requireAdmin(event: H3Event): Session {
  requireDb()
  const s = getSession(event)
  if (!s) {
    throw createError({ statusCode: 401, message: '未登录或登录已过期' })
  }
  return s
}

export function publicUser(u: any) {
  return {
    id: u.id,
    username: u.username,
    nickname: u.nickname || '',
    role: u.role,
    status: u.status,
    lastLoginAt: u.last_login_at,
    lastLoginIp: u.last_login_ip,
    createdAt: u.created_at,
    updatedAt: u.updated_at,
  }
}

/** 改密码：必须提供旧密码验证 */
export function changePassword(userId: number, oldPwd: string, newPwd: string) {
  requireDb()
  if (!oldPwd || !newPwd) throw createError({ statusCode: 400, message: '请输入旧密码和新密码' })
  if (newPwd.length < 6) throw createError({ statusCode: 400, message: '新密码长度至少 6 位' })
  const db = getDb()
  const user = db.prepare('SELECT * FROM admin_users WHERE id = ?').get(userId) as any
  if (!user) throw createError({ statusCode: 404, message: '用户不存在' })
  if (!verifyPassword(oldPwd, user.password_hash)) {
    throw createError({ statusCode: 400, message: '旧密码错误' })
  }
  const hash = hashPassword(newPwd)
  db.prepare('UPDATE admin_users SET password_hash = ?, updated_at = ? WHERE id = ?')
    .run(hash, new Date().toISOString(), userId)
  return true
}

/** 管理员重置其它用户密码（不需要旧密码） */
export function resetPassword(adminRole: string, targetUserId: number, newPwd: string) {
  requireDb()
  if (adminRole !== 'admin') throw createError({ statusCode: 403, message: '无权操作' })
  if (!newPwd || newPwd.length < 6) throw createError({ statusCode: 400, message: '新密码长度至少 6 位' })
  const db = getDb()
  const hash = hashPassword(newPwd)
  const info = db.prepare('UPDATE admin_users SET password_hash = ?, updated_at = ? WHERE id = ?')
    .run(hash, new Date().toISOString(), targetUserId)
  if (info.changes === 0) throw createError({ statusCode: 404, message: '用户不存在' })
  return true
}

function getRequestProtocol(event: H3Event): string {
  try {
    const header = getRequestHeader(event, 'x-forwarded-proto')
    if (header) return header.split(',')[0].trim()
    const nodeEvent = (event.node || event as any).req
    return nodeEvent?.connection?.encrypted ? 'https' : 'http'
  } catch { return 'http' }
}
