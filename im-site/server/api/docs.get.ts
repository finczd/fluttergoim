// 公开接口：读取 docs 表，返回文档列表或单篇内容（供 /api-docs 页面渲染）
import { marked } from 'marked'

const CATEGORY_LABEL: Record<string, string> = {
  arch: '架构与设计',
  api: 'APP API 文档',
  recharge: '充值提现',
  deploy: '部署运维',
  custom: '定制开发',
  other: '其他',
}

function groupByCategory(list: any[]) {
  const group: Record<string, any[]> = {}
  for (const d of list) {
    if (!group[d.category]) group[d.category] = []
    group[d.category].push(d)
  }
  return group
}

function listAll() {
  const db = getDb()
  const rows = db.prepare(
    'SELECT id, slug, title, category, category_label, order_num AS "order", updated_at FROM docs ORDER BY category ASC, order_num ASC'
  ).all() as any[]
  return rows
}

function readBySlug(slug: string) {
  const db = getDb()
  const row = db.prepare('SELECT * FROM docs WHERE slug = ?').get(slug) as any
  if (!row) return null
  marked.setOptions({ breaks: true, gfm: true })
  const html = marked.parse(row.content || '', { async: false }) as string
  return { doc: row, html, raw: row.content || '' }
}

export default defineEventHandler(async (event) => {
  const q = getQuery(event)
  const slug = q.slug as string | undefined

  // 列表
  if (!slug) {
    const list = listAll()
    return {
      code: 0,
      data: {
        categories: Object.keys(CATEGORY_LABEL).map(k => ({ key: k, label: CATEGORY_LABEL[k] })),
        list,
        grouped: groupByCategory(list),
      },
    }
  }

  // 单个
  const safeSlug = String(slug).replace(/[\\/]/g, '').replace(/\.{2,}/g, '')
  const result = readBySlug(safeSlug)
  if (!result) {
    setResponseStatus(event, 404)
    return { code: 404, message: '文档不存在' }
  }
  return { code: 0, data: result }
})
