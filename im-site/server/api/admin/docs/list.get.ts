// 后台文档管理：列出 docs 目录所有 *.md 文件（含 EXCLUDE，不隐藏）
import { readdirSync, statSync } from 'node:fs'
import { join, basename, extname } from 'node:path'
import { resolveDocsDir } from '../../../utils/db'

// FILE_META / EXCLUDE_FILES / CATEGORY_LABEL 与 server/api/docs.get.ts 保持同步（静态拷贝）
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

export default defineEventHandler(async (event) => {
  // 仅管理员可访问
  requireAdmin(event)
  const docsDir = resolveDocsDir()
  let files: string[] = []
  try {
    files = readdirSync(docsDir).filter(f => f.toLowerCase().endsWith('.md'))
  } catch {
    files = []
  }
  const list = files.map(fn => {
    const meta = FILE_META[fn] || { title: fn.replace(/\.md$/i, ''), category: 'other', order: 99 }
    const categoryLabel = CATEGORY_LABEL[meta.category] || meta.category
    const fp = join(docsDir, fn)
    let size = 0
    let mtime = ''
    try {
      const st = statSync(fp)
      size = st.size
      mtime = st.mtime.toISOString()
    } catch {}
    return {
      fileName: fn,
      slug: basename(fn, extname(fn)),
      title: meta.title,
      size,
      mtime,
      categoryLabel,
      categoryKey: meta.category,
      order: meta.order,
      excluded: EXCLUDE_FILES.has(fn),
    }
  })
  list.sort((a, b) => {
    if (a.categoryKey !== b.categoryKey) return a.categoryKey.localeCompare(b.categoryKey)
    return a.order - b.order
  })
  return {
    code: 0,
    data: { list },
  }
})
