import { mkdir, readFile, writeFile, readdir, unlink, stat } from 'node:fs/promises'
import { join } from 'node:path'
import { randomUUID } from 'node:crypto'

// 文章存储在项目根目录 data/articles/ 下（宝塔友好，可视化）
const DATA_DIR = join(process.cwd(), 'data', 'articles')

async function ensureDir() {
  await mkdir(DATA_DIR, { recursive: true })
}

export interface Article {
  id: string
  slug: string
  title: string
  summary: string
  content: string
  coverImage: string
  category: string
  tags: string[]
  published: boolean
  views: number
  createdAt: string
  updatedAt: string
}

async function readOne(id: string): Promise<Article | null> {
  try {
    const raw = await readFile(join(DATA_DIR, `${id}.json`), 'utf-8')
    return JSON.parse(raw)
  } catch {
    return null
  }
}

export async function getArticleBySlug(slug: string): Promise<Article | null> {
  await ensureDir()
  const files = await readdir(DATA_DIR)
  for (const f of files) {
    if (!f.endsWith('.json')) continue
    const raw = await readFile(join(DATA_DIR, f), 'utf-8')
    const a: Article = JSON.parse(raw)
    if (a.slug === slug && a.published) {
      // 增加浏览量
      a.views = (a.views || 0) + 1
      await writeFile(join(DATA_DIR, f), JSON.stringify(a, null, 2), 'utf-8')
      return a
    }
  }
  return null
}

export async function getArticleById(id: string): Promise<Article | null> {
  await ensureDir()
  return readOne(id)
}

export async function listArticles(opts?: {
  page?: number
  pageSize?: number
  category?: string
  tag?: string
  publishedOnly?: boolean
}): Promise<{ list: Article[]; total: number; page: number; pageSize: number }> {
  await ensureDir()
  const page = opts?.page ?? 1
  const pageSize = opts?.pageSize ?? 10
  const files = await readdir(DATA_DIR)
  let items: Article[] = []

  for (const f of files) {
    if (!f.endsWith('.json')) continue
    try {
      const raw = await readFile(join(DATA_DIR, f), 'utf-8')
      const a: Article = JSON.parse(raw)
      if (opts?.publishedOnly && !a.published) continue
      if (opts?.category && a.category !== opts.category) continue
      if (opts?.tag && !a.tags?.includes(opts.tag)) continue
      items.push(a)
    } catch { /* skip broken files */ }
  }

  // 按时间倒序
  items.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())

  const total = items.length
  const start = (page - 1) * pageSize
  const list = items.slice(start, start + pageSize)

  return { list, total, page, pageSize }
}

export async function getAllCategories(): Promise<{ name: string; count: number }[]> {
  await ensureDir()
  const files = await readdir(DATA_DIR)
  const map = new Map<string, number>()

  for (const f of files) {
    if (!f.endsWith('.json')) continue
    try {
      const raw = await readFile(join(DATA_DIR, f), 'utf-8')
      const a: Article = JSON.parse(raw)
      if (!a.published) continue
      const c = a.category || '未分类'
      map.set(c, (map.get(c) || 0) + 1)
    } catch { /* skip */ }
  }

  return [...map.entries()].map(([name, count]) => ({ name, count }))
}

export async function createArticle(data: Partial<Article>): Promise<Article> {
  await ensureDir()
  const now = new Date().toISOString()
  const article: Article = {
    id: randomUUID(),
    slug: data.slug || slugify(data.title || 'untitled'),
    title: data.title || '',
    summary: data.summary || '',
    content: data.content || '',
    coverImage: data.coverImage || '',
    category: data.category || '技术分享',
    tags: data.tags || [],
    published: data.published ?? false,
    views: 0,
    createdAt: now,
    updatedAt: now,
  }
  await writeFile(join(DATA_DIR, `${article.id}.json`), JSON.stringify(article, null, 2), 'utf-8')
  return article
}

export async function updateArticle(id: string, data: Partial<Article>): Promise<Article | null> {
  const existing = await readOne(id)
  if (!existing) return null

  const updated: Article = {
    ...existing,
    ...data,
    id: existing.id, // 不可变
    updatedAt: new Date().toISOString(),
  }
  await writeFile(join(DATA_DIR, `${id}.json`), JSON.stringify(updated, null, 2), 'utf-8')
  return updated
}

export async function deleteArticle(id: string): Promise<boolean> {
  try {
    await unlink(join(DATA_DIR, `${id}.json`))
    return true
  } catch {
    return false
  }
}

function slugify(s: string): string {
  return s
    .toLowerCase()
    .replace(/[^a-z0-9\u4e00-\u9fa5]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 80)
}
