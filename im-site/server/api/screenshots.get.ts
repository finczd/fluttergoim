import { getHeader } from 'h3'
import { getDb } from '~/server/utils/db'

/**
 * 读取站点基础 URL：优先 SITE_URL 环境变量，其次根据当前请求自动推导。
 * 用于把 /uploads/1.jpg 这种相对 URL 在服务端拼成"当前访问域名下"的绝对 URL，
 * 这样同一份 DB 在 www.x123.wang / localhost:3000 / 任意部署域名下都能正确加载图。
 */
function resolveSiteBase(event: any): string {
  const fromEnv = process.env.SITE_URL
  if (fromEnv) return fromEnv.replace(/\/$/, '')
  try {
    const proto = String(getHeader(event, 'x-forwarded-proto') || getHeader(event, 'x-scheme') || 'http').split(',')[0].trim()
    const host = String(getHeader(event, 'x-forwarded-host') || getHeader(event, 'host') || 'localhost:3000').split(',')[0].trim()
    return `${proto}://${host}`
  } catch {
    return 'http://localhost:3000'
  }
}

function normalizeUrl(rawUrl: string, base: string): string {
  if (!rawUrl) return rawUrl
  if (/^https?:\/\//i.test(rawUrl)) return rawUrl
  if (rawUrl.startsWith('//')) return rawUrl
  const joined = rawUrl.startsWith('/') ? rawUrl : `/${rawUrl}`
  return `${base}${joined}`
}

export default defineEventHandler(async (event) => {
  const d = getDb()
  const rows = d.prepare(
    `SELECT id, url, title, sort_order FROM screenshots ORDER BY sort_order ASC, id ASC`
  ).all() as any[]

  const base = resolveSiteBase(event)
  return {
    code: 0,
    data: rows.map((r) => ({
      id: r.id,
      url: normalizeUrl(r.url, base),
      rawUrl: r.url,
      title: r.title,
      order: r.sort_order,
    })),
  }
})
