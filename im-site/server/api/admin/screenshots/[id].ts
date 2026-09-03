export default defineEventHandler(async (event) => {
  const id = Number(getRouterParam(event, 'id'))
  const d = getDb()
  const exists = d.prepare('SELECT id FROM screenshots WHERE id = ?').get(id)
  if (!exists) { setResponseStatus(event, 404); return { code: 404, message: '不存在' } }
  if (event.method === 'DELETE') {
    d.prepare('DELETE FROM screenshots WHERE id = ?').run(id)
    return { code: 0, message: '删除成功' }
  }
  if (event.method === 'PUT') {
    const body = await readBody(event)
    const patch: any = {}
    if (body.title !== undefined) patch.title = body.title
    // 兼容前端两种命名：body.order 或 body.sort_order，都落到 DB 的 sort_order 列
    if (body.order !== undefined || body.sort_order !== undefined) {
      patch.sort_order = body.order ?? body.sort_order
    }
    if (Object.keys(patch).length) {
      const sets = Object.keys(patch).map(k => `${k} = ?`).join(', ')
      d.prepare(`UPDATE screenshots SET ${sets} WHERE id = ?`).run(...Object.values(patch), id)
    }
    const r = d.prepare('SELECT id, url, title, sort_order FROM screenshots WHERE id = ?').get(id) as any
    return { code: 0, data: { id: r.id, url: r.url, title: r.title, order: r.sort_order, sort_order: r.sort_order }, message: '更新成功' }
  }
})
