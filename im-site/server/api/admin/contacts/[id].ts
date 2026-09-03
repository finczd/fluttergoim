export default defineEventHandler(async (event) => {
  const id = getRouterParam(event, 'id') as string
  const d = getDb()
  const exists = d.prepare('SELECT id FROM contacts WHERE id = ?').get(id)
  if (!exists) { setResponseStatus(event, 404); return { code: 404, message: '不存在' } }
  if (event.method === 'PUT') {
    d.prepare('UPDATE contacts SET is_read = 1 WHERE id = ?').run(id)
    return { code: 0, message: '已标记为已读' }
  }
  if (event.method === 'DELETE') {
    d.prepare('DELETE FROM contacts WHERE id = ?').run(id)
    return { code: 0, message: '删除成功' }
  }
})
