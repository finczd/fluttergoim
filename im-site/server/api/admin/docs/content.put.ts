// 后台文档管理：写入 markdown 源文件到 content/docs/<slug>.md
import { writeFileSync, mkdirSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { resolveDocsDir } from '../../../utils/db'

export default defineEventHandler(async (event) => {
  requireAdmin(event)
  const body = await readBody(event)
  const slug = String(body?.slug || '').trim()
  const content = body?.content
  if (!slug) {
    setResponseStatus(event, 400)
    return { code: 400, message: '缺少 slug' }
  }
  if (typeof content !== 'string') {
    setResponseStatus(event, 400)
    return { code: 400, message: '缺少 content' }
  }
  // 写入到 resolveDocsDir() 返回的路径（优先 content/docs）
  const safeSlug = slug.replace(/[\\/]/g, '').replace(/\.{2,}/g, '')
  const docsDir = resolveDocsDir()
  try {
    mkdirSync(docsDir, { recursive: true })
  } catch {}
  const fp = join(docsDir, `${safeSlug}.md`)
  try {
    writeFileSync(fp, content, 'utf-8')
  } catch (e: any) {
    setResponseStatus(event, 500)
    return { code: 500, message: e?.message || '写入失败' }
  }
  return { code: 0, message: '保存成功', data: { slug: safeSlug, fileName: `${safeSlug}.md` } }
})
