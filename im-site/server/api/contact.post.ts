export default defineEventHandler(async (event) => {
  const body = await readBody(event)
  const { name, contact, message } = body || {}
  if (!name || !contact) { setResponseStatus(event, 400); return { code: 400, message: '请填写姓名和联系方式' } }
  const validPattern = /^[a-zA-Z0-9@._\-+()#&\s]+$/
  if (!validPattern.test(contact)) { setResponseStatus(event, 400); return { code: 400, message: '联系方式只允许数字、字母和符号' } }
  const id = (await import('node:crypto')).randomUUID()
  const createdAt = new Date().toISOString()
  const d = getDb()
  d.prepare('INSERT INTO contacts (id, name, contact, message, created_at, is_read) VALUES (?, ?, ?, ?, ?, 0)').run(id, String(name), String(contact), String(message || ''), createdAt)
  return { code: 0, message: '提交成功，我们会尽快联系您' }
})
