import { requireAdmin, changePassword } from '../../utils/auth'

export default defineEventHandler(async (event) => {
  const sess = requireAdmin(event)
  const body = await readBody(event)
  changePassword(sess.userId, String(body?.oldPassword || ''), String(body?.newPassword || ''))
  return { code: 0, message: 'ok' }
})
