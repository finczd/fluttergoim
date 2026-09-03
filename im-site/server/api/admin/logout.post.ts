import { logout } from '../../utils/auth'

export default defineEventHandler(async (event) => {
  logout(event)
  return { code: 0, message: 'ok' }
})
