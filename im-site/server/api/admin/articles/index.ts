export default defineEventHandler(async (event) => {
  const d = getDb()
  if (event.method === 'GET') {
    const q = getQuery(event)
    const page = Math.max(1, Number(q.page) || 1)
    const pageSize = Math.max(1, Number(q.pageSize) || 50)
    const offset = (page - 1) * pageSize
    const params: any[] = []
    let where = 'WHERE 1=1'
    if (q.keyword) { where += ` AND (a.title LIKE ? OR a.summary LIKE ?)`; params.push(`%${q.keyword}%`, `%${q.keyword}%`) }
    if (q.status !== undefined && q.status !== '') { where += ' AND a.status = ?'; params.push(Number(q.status)) }
    if (q.category) {
      const cat = d.prepare('SELECT id FROM categories WHERE name = ?').get(q.category as string) as any
      if (cat) { where += ' AND a.category_id = ?'; params.push(cat.id) }
    }
    const total = (d.prepare(`SELECT COUNT(*) as c FROM articles a ${where}`).get(...params) as any).c
    const rows = d.prepare(`SELECT a.id, a.slug, a.title, a.summary, a.content, a.cover, a.tags, a.status, a.created_at, a.updated_at, c.name as category_name FROM articles a LEFT JOIN categories c ON c.id = a.category_id ${where} ORDER BY a.created_at DESC LIMIT ? OFFSET ?`).all(...params, pageSize, offset) as any[]
    return { code: 0, data: { total, page, pageSize, list: rows.map(r => ({ id: r.id, slug: r.slug, title: r.title, summary: r.summary, content: r.content, cover: r.cover, category: r.category_name || null, tags: JSON.parse(r.tags || '[]'), status: r.status, published: r.status === 1, createdAt: r.created_at, updatedAt: r.updated_at })) } }
  }
  if (event.method === 'POST') {
    const body = await readBody(event)
    if (!body.slug || !body.title) { setResponseStatus(event, 400); return { code: 400, message: 'slug 和 title 不能为空' } }
    let catId: number | null = null
    if (body.category) {
      const cat = d.prepare('SELECT id FROM categories WHERE name = ?').get(body.category) as any
      if (cat) catId = cat.id
      else catId = Number(d.prepare('INSERT INTO categories (name) VALUES (?)').run(body.category).lastInsertRowid)
    }
    const now = new Date().toISOString()
    const res = d.prepare(`INSERT INTO articles (slug, title, summary, content, cover, category_id, tags, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`).run(body.slug, body.title, body.summary || '', body.content || '', body.cover || '', catId, JSON.stringify(body.tags || []), body.published ? 1 : 0, now, now)
    const ar = d.prepare(`SELECT a.id, a.slug, a.title, a.summary, a.content, a.cover, a.tags, a.status, a.created_at, a.updated_at, c.name as category_name FROM articles a LEFT JOIN categories c ON c.id = a.category_id WHERE a.id = ?`).get(res.lastInsertRowid) as any
    return { code: 0, message: '创建成功', data: { id: ar.id, slug: ar.slug, title: ar.title, summary: ar.summary, content: ar.content, cover: ar.cover, category: ar.category_name || null, tags: JSON.parse(ar.tags || '[]'), status: ar.status, published: ar.status === 1, createdAt: ar.created_at, updatedAt: ar.updated_at } }
  }
})
