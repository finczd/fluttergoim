// 后台文档管理：列出 docs 表所有文档
export default defineEventHandler(async (event) => {
  requireAdmin(event)
  const db = getDb()
  const list = db.prepare(
    `SELECT id, slug, title, category, category_label, order_num AS "order",
            length(content) AS size, updated_at AS mtime
     FROM docs
     ORDER BY category ASC, order_num ASC`
  ).all()
  return { code: 0, data: { list } }
})
