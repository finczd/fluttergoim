export default defineEventHandler(async (event) => {
  const slug = getRouterParam(event, 'slug') as string
  const d = getDb()
  const r = d.prepare(`SELECT a.id, a.slug, a.title, a.summary, a.content, a.cover, a.tags, a.status, a.created_at, a.updated_at, c.name as category_name FROM articles a LEFT JOIN categories c ON c.id = a.category_id WHERE a.slug = ?`).get(slug) as any
  if (!r) { setResponseStatus(event, 404); return { code: 404, message: '不存在' } }
  return { code: 0, data: { id: r.id, slug: r.slug, title: r.title, summary: r.summary, content: r.content, cover: r.cover, category: r.category_name || null, tags: JSON.parse(r.tags || '[]'), status: r.status, createdAt: r.created_at, updatedAt: r.updated_at } }
})
