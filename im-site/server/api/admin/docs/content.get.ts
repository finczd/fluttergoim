// 后台文档管理：读取单个 markdown 源文件的 RAW 内容（非 HTML）
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { resolveDocsDir } from '../../../utils/db'

export default defineEventHandler(async (event) => {
  requireAdmin(event)
  const q = getQuery(event)
  const slug = String(q.slug || '').trim()
  if (!slug) {
    setResponseStatus(event, 400)
    return { code: 400, message: '缺少 slug 参数' }
  }
  const docsDir = resolveDocsDir()
  // 安全：避免路径穿越
  const safeSlug = slug.replace(/[\\/]/g, '').replace(/\.{2,}/g, '')
  const fp = join(docsDir, `${safeSlug}.md`)
  let raw = ''
  try {
    raw = readFileSync(fp, 'utf-8')
  } catch {
    setResponseStatus(event, 404)
    return { code: 404, message: '文档不存在' }
  }
  return {
    code: 0,
    data: {
      slug: safeSlug,
      fileName: `${safeSlug}.md`,
      content: raw,
    },
  }
})
