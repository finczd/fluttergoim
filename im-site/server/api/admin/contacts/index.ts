export default defineEventHandler(async () => {
  const d = getDb()
  const rows = d.prepare('SELECT id, name, contact, message, created_at, is_read FROM contacts ORDER BY created_at DESC').all() as any[]
  return { code: 0, data: rows.map(r => ({ id: r.id, name: r.name, contact: r.contact, message: r.message, createdAt: r.created_at, read: r.is_read === 1 })) }
})
