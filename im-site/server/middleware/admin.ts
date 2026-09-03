import { getSession } from '../utils/auth'
import { getDb } from '../utils/db'

/**
 * 保护 /api/admin/* (除 login/logout 外) 以及 /admin 前端页面路由。
 * 未登录：
 *   - API 路由返回 JSON { code:401, message }
 *   - 浏览器页面 302 到 /admin/login
 *
 * 注：middleware 执行早于 Nitro 插件，因此在此显式触发 getDb() 确保
 * admin_users / ai_configs 等新表在首次访问 admin 路由前就被创建。
 * 避免 "no such table: admin_users" 报错。
 */
try { getDb() } catch (e) { console.error('[admin-middleware] init db failed:', e) }

export default defineEventHandler(async (event) => {
  const url = event.path || ''
  const isApiAdmin = url.startsWith('/api/admin/')
  const isPageAdmin = url === '/admin' || url.startsWith('/admin/')

  if (!isApiAdmin && !isPageAdmin) return

  // 放行登录 / 登出
  if (url.startsWith('/api/admin/login') || url.startsWith('/api/admin/logout')) return
  if (url.startsWith('/admin/login')) return

  const session = getSession(event)
  if (!session) {
    if (isApiAdmin) {
      setResponseStatus(event, 401)
      return { code: 401, message: '未登录或登录已过期' }
    }
    // 浏览器页面：重定向
    await sendRedirect(event, '/admin/login', 302)
    return
  }
})
