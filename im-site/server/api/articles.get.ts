export default defineEventHandler(async (event) => {
  const q = getQuery(event)
  const page = Math.max(1, Number(q.page) || 1)
  const pageSize = Math.max(1, Number(q.pageSize) || 10)
  const offset = (page - 1) * pageSize
  const d = getDb()
  let where = 'WHERE a.status = 1'
  const params: any[] = []
  if (q.category) {
    const cat = d.prepare('SELECT id FROM categories WHERE name = ?').get(q.category as string) as any
    if (cat) { where += ' AND a.category_id = ?'; params.push(cat.id) }
  }
  const total = (d.prepare(`SELECT COUNT(*) as c FROM articles a ${where}`).get(...params) as any).c
  const rows = d.prepare(`SELECT a.id, a.slug, a.title, a.summary, a.content, a.cover, a.tags, a.status, a.created_at, a.updated_at, c.name as category_name FROM articles a LEFT JOIN categories c ON c.id = a.category_id ${where} ORDER BY a.created_at DESC LIMIT ? OFFSET ?`).all(...params, pageSize, offset) as any[]
  return { code: 0, data: { total, page, pageSize, list: rows.map(r => ({ id: r.id, slug: r.slug, title: r.title, summary: r.summary, content: r.content, cover: r.cover, category: r.category_name || null, tags: JSON.parse(r.tags || '[]'), status: r.status, createdAt: r.created_at, updatedAt: r.updated_at })) } }
})
