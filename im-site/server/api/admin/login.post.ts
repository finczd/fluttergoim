import { login } from '../../utils/auth'

// POST /api/admin/login  body: { username, password }
export default defineEventHandler(async (event) => {
  const body = await readBody(event)
  const { username, password } = body || {}

  const fwd = getRequestHeader(event, 'x-forwarded-for')
  const socket = (event.node?.req as any)?.socket
  const socketIp = socket?.remoteAddress
  const ip = (typeof fwd === 'string' && fwd) ? fwd.split(',')[0].trim() : (socketIp || undefined)

  const result = login(event, String(username || ''), String(password || ''), ip)
  return { code: 0, message: 'ok', data: { user: result.user } }
})
