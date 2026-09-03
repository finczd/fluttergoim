// 读取仓库根 d:\im-project\docs 目录下的 *.md 文件
// 返回文档列表和内容（供前端 api-docs 页面渲染）
import { readdirSync, readFileSync, statSync } from 'node:fs'
import { join, basename, extname } from 'node:path'
import { marked } from 'marked'

/**
 * 通过当前工作目录向上定位 im-site 的上一级（即 d:\im-project）下的 docs 目录。
 */
function resolveDocsDir(): string {
  // process.cwd() 通常是 d:\im-project\im-site；docs 在同级目录 d:\im-project\docs
  const candidates = [
    join(process.cwd(), '..', 'docs'),
    join(process.cwd(), 'docs'),
    join(process.cwd(), 'im-server', 'doc'),
  ]
  for (const p of candidates) {
    try {
      const s = statSync(p)
      if (s.isDirectory()) return p
    } catch { /* ignore */ }
  }
  // 兜底创建空目录
  try {
    const fallback = join(process.cwd(), '..', 'docs')
    const { mkdirSync } = require('node:fs')
    mkdirSync(fallback, { recursive: true })
    return fallback
  } catch { return join(process.cwd(), 'docs') }
}

const DOCS_DIR = resolveDocsDir()

/**
 * 文件名 → 展示标题 & 分类
 * 不在映射内但仍然允许展示的文件：标题取文件名、归到 arch / order=99
 * EXCLUDE 列表中的文件直接不展示（物理文件仍然保留在仓库中）
 */
const FILE_META: Record<string, { title: string; category: string; order: number }> = {
  '企业IM-架构方案.md':     { title: '架构方案',     category: 'arch',     order: 1 },
  '企业IM-数据库设计.md':   { title: '数据库设计',   category: 'arch',     order: 2 },
  '企业IM-API文档.md':      { title: 'APP API 文档', category: 'api',      order: 1 },
  '企业IM-API接口清单.md':  { title: 'API 接口清单', category: 'api',      order: 2 },
  'recharge-withdraw-api.md': { title: '充值提现接口', category: 'recharge', order: 1 },
  '宝塔部署指南.md':        { title: '宝塔部署指南',  category: 'deploy',   order: 1 },
}

const EXCLUDE_FILES = new Set([
  '企业IM-需求文档.md',
  '企业IM-MVP开发任务清单.md',
  '需求完成度检查清单.md',
])

const CATEGORY_LABEL: Record<string, string> = {
  arch: '架构与设计',
  api: 'APP API 文档',
  recharge: '充值提现',
  deploy: '部署运维',
}

interface Doc {
  slug: string        // 文件名无扩展名
  fileName: string
  title: string
  category: string
  categoryLabel: string
  order: number
  updatedAt: string
}

function listAll(): Doc[] {
  let fileNames: string[] = []
  try { fileNames = readdirSync(DOCS_DIR).filter(f => f.toLowerCase().endsWith('.md')) }
  catch { fileNames = [] }
  const docs: Doc[] = fileNames
    .filter(fn => !EXCLUDE_FILES.has(fn))
    .map(fn => {
      const meta = FILE_META[fn] || { title: fn.replace(/\.md$/i, ''), category: 'arch', order: 99 }
      const fp = join(DOCS_DIR, fn)
      let updatedAt = ''
      try { updatedAt = new Date(statSync(fp).mtime).toISOString() } catch {}
      return {
        slug: basename(fn, extname(fn)),
        fileName: fn,
        title: meta.title,
        category: meta.category,
        categoryLabel: CATEGORY_LABEL[meta.category] || meta.category,
        order: meta.order,
        updatedAt,
      }
    })
  docs.sort((a, b) => {
    if (a.category !== b.category) return a.category.localeCompare(b.category)
    return a.order - b.order
  })
  return docs
}

function groupByCategory(list: Doc[]) {
  const group: Record<string, Doc[]> = {}
  for (const d of list) {
    if (!group[d.category]) group[d.category] = []
    group[d.category].push(d)
  }
  return group
}

/**
 * 按 slug 读取并渲染 markdown 为 HTML
 */
function readBySlug(slug: string): { doc: Doc; html: string; raw: string } | null {
  const all = listAll()
  const meta = all.find(d => d.slug === slug)
  // 排除 EXCLUDE 中的文件（即使有人通过 slug 猜测到）
  if (!meta) return null
  if (EXCLUDE_FILES.has(meta.fileName)) return null
  const fp = join(DOCS_DIR, meta.fileName)
  let raw = ''
  try { raw = readFileSync(fp, 'utf-8') } catch { return null }
  marked.setOptions({ breaks: true, gfm: true })
  const html = marked.parse(raw, { async: false }) as string
  return { doc: meta, html, raw }
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
  const result = readBySlug(slug)
  if (!result) {
    setResponseStatus(event, 404)
    return { code: 404, message: '文档不存在' }
  }
  return {
    code: 0,
    data: result,
  }
})
