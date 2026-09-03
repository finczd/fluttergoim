export default defineEventHandler(async (event) => {
  const id = Number(getRouterParam(event, 'id'))
  const d = getDb()
  const exists = d.prepare('SELECT id FROM articles WHERE id = ?').get(id)
  if (!exists) { setResponseStatus(event, 404); return { code: 404, message: '不存在' } }
  if (event.method === 'DELETE') {
    d.prepare('DELETE FROM articles WHERE id = ?').run(id)
    return { code: 0, message: '删除成功' }
  }
  if (event.method === 'PUT') {
    const body = await readBody(event)
    const patch: any = {}
    if (body.title !== undefined) patch.title = body.title
    if (body.slug !== undefined) patch.slug = body.slug
    if (body.summary !== undefined) patch.summary = body.summary
    if (body.content !== undefined) patch.content = body.content
    if (body.cover !== undefined) patch.cover = body.cover
    if (body.tags !== undefined) patch.tags = JSON.stringify(body.tags || [])
    if (body.published !== undefined) patch.status = body.published ? 1 : 0
    if (body.status !== undefined) patch.status = Number(body.status)
    patch.updated_at = new Date().toISOString()
    if (body.category !== undefined) {
      if (!body.category) patch.category_id = null
      else {
        const cat = d.prepare('SELECT id FROM categories WHERE name = ?').get(body.category) as any
        if (cat) patch.category_id = cat.id
        else patch.category_id = Number(d.prepare('INSERT INTO categories (name) VALUES (?)').run(body.category).lastInsertRowid)
      }
    }
    const sets = Object.keys(patch).map(k => `${k} = ?`).join(', ')
    d.prepare(`UPDATE articles SET ${sets} WHERE id = ?`).run(...Object.values(patch), id)
    const ar = d.prepare(`SELECT a.id, a.slug, a.title, a.summary, a.content, a.cover, a.tags, a.status, a.created_at, a.updated_at, c.name as category_name FROM articles a LEFT JOIN categories c ON c.id = a.category_id WHERE a.id = ?`).get(id) as any
    return { code: 0, message: '更新成功', data: { id: ar.id, slug: ar.slug, title: ar.title, summary: ar.summary, content: ar.content, cover: ar.cover, category: ar.category_name || null, tags: JSON.parse(ar.tags || '[]'), status: ar.status, published: ar.status === 1, createdAt: ar.created_at, updatedAt: ar.updated_at } }
  }
})
