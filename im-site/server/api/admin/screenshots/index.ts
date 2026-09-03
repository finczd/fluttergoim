export default defineEventHandler(async (event) => {
  const d = getDb()
  if (event.method === 'GET') {
    const rows = d.prepare('SELECT id, url, title, sort_order FROM screenshots ORDER BY sort_order ASC, id ASC').all() as any[]
    return {
      code: 0,
      data: rows.map(r => ({
        id: r.id,
        url: r.url,
        title: r.title,
        order: r.sort_order,
        sort_order: r.sort_order,
      })),
    }
  }
  if (event.method === 'POST') {
    const body = await readBody(event)
    const maxOrder = (d.prepare('SELECT COALESCE(MAX(sort_order), -1) as m FROM screenshots').get() as any).m
    const info = d.prepare('INSERT INTO screenshots (url, title, sort_order) VALUES (?, ?, ?)').run(
      body.url,
      body.title || '',
      body.sort_order ?? body.order ?? (maxOrder + 1),
    )
    const r = d.prepare('SELECT id, url, title, sort_order FROM screenshots WHERE id = ?').get(info.lastInsertRowid) as any
    return {
      code: 0,
      data: { id: r.id, url: r.url, title: r.title, order: r.sort_order, sort_order: r.sort_order },
      message: '添加成功',
    }
  }
})
