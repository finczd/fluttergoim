// 后台文档管理：保存 / 新建 docs 表中的文档（PUT upsert）
// 删除逻辑请见 content.delete.ts
const CATEGORY_LABEL: Record<string, string> = {
  arch: '架构与设计',
  api: 'APP API 文档',
  recharge: '充值提现',
  deploy: '部署运维',
  custom: '定制开发',
  other: '其他',
}

function normSlug(s: string): string {
  return String(s || '')
    .trim()
    .toLowerCase()
    .replace(/[\\/]/g, '')
    .replace(/\.{2,}/g, '')
    .replace(/[^a-z0-9\u4e00-\u9fa5_-]+/g, '-')
    .replace(/^-+|-+$/g, '')
}

export default defineEventHandler(async (event) => {
  requireAdmin(event)

  // PUT /api/admin/docs/content —— upsert（保存或新建）
  const body = await readBody(event)
  const id = Number(body?.id || 0)
  let slug = normSlug(String(body?.slug || ''))
  const title = String(body?.title || body?.display_title || slug || '').trim()
  let category = String(body?.category || 'arch').trim() || 'arch'
  const content = typeof body?.content === 'string' ? body.content : ''
  const order = Number(body?.order ?? 99)
  if (!CATEGORY_LABEL[category]) category = 'other'
  const category_label = CATEGORY_LABEL[category] || category

  if (!slug) {
    setResponseStatus(event, 400)
    return { code: 400, message: '请填写 slug（英文唯一标识）' }
  }
  if (!title) {
    setResponseStatus(event, 400)
    return { code: 400, message: '请填写文档标题' }
  }

  const db = getDb()

  // slug 唯一检查（排除自己）
  const conflict = db.prepare('SELECT id FROM docs WHERE slug = ? AND id != ?').get(slug, id)
  if (conflict) {
    setResponseStatus(event, 409)
    return { code: 409, message: 'slug 已被占用，请换一个' }
  }

  if (id > 0) {
    // 更新
    db.prepare(`
      UPDATE docs SET slug=?, title=?, category=?, category_label=?, content=?, order_num=?, updated_at=datetime('now','localtime')
      WHERE id=?
    `).run(slug, title, category, category_label, content, order, id)
    return { code: 0, message: '保存成功', data: { id, slug, title } }
  } else {
    // 新建
    const info = db.prepare(`
      INSERT INTO docs (slug, title, category, category_label, content, order_num)
      VALUES (?, ?, ?, ?, ?, ?)
    `).run(slug, title, category, category_label, content, order)
    return { code: 0, message: '创建成功', data: { id: info.lastInsertRowid, slug, title } }
  }
})
