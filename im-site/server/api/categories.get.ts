export default defineEventHandler(async () => {
  const d = getDb()
  const rows = d.prepare('SELECT id, name FROM categories ORDER BY id ASC').all() as any[]
  return { code: 0, data: rows }
})
