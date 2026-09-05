// 后台文档管理：删除 docs 表中的文档（Nuxt 按文件名 .delete.ts 匹配 DELETE method）
import { getDb } from '../../../utils/db'

function normSlug(s: string): string {
  return String(s || '')
    .trim()
    .toLowerCase()
    .replace(/[\\/]/g, '')
    .replace(/\.{2,}/g, '')
    .replace(/[^a-z0-9\u4e00-\u9fa5_-]+/g, '-')
    .replace(/^-+|-+$/g, '')
}

export default defineEventHandler(async (event) => {
  requireAdmin(event)
  const q = getQuery(event)
  const slug = normSlug(String(q.slug || ''))
  if (!slug) {
    setResponseStatus(event, 400)
    return { code: 400, message: '缺少 slug' }
  }
  const db = getDb()
  const r = db.prepare('DELETE FROM docs WHERE slug = ?').run(slug)
  if (r.changes === 0) {
    setResponseStatus(event, 404)
    return { code: 404, message: '文档不存在' }
  }
  return { code: 0, message: '删除成功' }
})
