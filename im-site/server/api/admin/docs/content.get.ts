// 后台文档管理：读取单个文档 RAW markdown 内容
export default defineEventHandler(async (event) => {
  requireAdmin(event)
  const q = getQuery(event)
  const slug = String(q.slug || '').trim()
  if (!slug) {
    setResponseStatus(event, 400)
    return { code: 400, message: '缺少 slug 参数' }
  }
  const safeSlug = slug.replace(/[\\/]/g, '').replace(/\.{2,}/g, '')
  const db = getDb()
  const row = db.prepare('SELECT * FROM docs WHERE slug = ?').get(safeSlug) as any
  if (!row) {
    setResponseStatus(event, 404)
    return { code: 404, message: '文档不存在' }
  }
  return {
    code: 0,
    data: {
      id: row.id,
      slug: row.slug,
      title: row.title,
      category: row.category,
      category_label: row.category_label,
      order: row.order_num,
      content: row.content,
    },
  }
})
