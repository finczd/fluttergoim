import { mkdir, readFile, writeFile, readdir, unlink } from 'node:fs/promises'
import { join } from 'node:path'
import { randomUUID } from 'node:crypto'

const DATA_DIR = join(process.cwd(), 'data')

export interface Screenshot {
  id: string
  url: string
  title: string
  order: number
}

async function ensureDir() {
  await mkdir(DATA_DIR, { recursive: true })
}

async function readAll(): Promise<Screenshot[]> {
  await ensureDir()
  try {
    const raw = await readFile(join(DATA_DIR, 'screenshots.json'), 'utf-8')
    return JSON.parse(raw)
  } catch {
    return []
  }
}

async function writeAll(list: Screenshot[]) {
  await ensureDir()
  await writeFile(join(DATA_DIR, 'screenshots.json'), JSON.stringify(list, null, 2), 'utf-8')
}

export async function listScreenshots(): Promise<Screenshot[]> {
  const list = await readAll()
  return list.sort((a, b) => a.order - b.order)
}

export async function addScreenshot(url: string, title: string): Promise<Screenshot> {
  const list = await readAll()
  const shot: Screenshot = {
    id: randomUUID(),
    url,
    title: title || 'APP截图',
    order: list.length,
  }
  list.push(shot)
  await writeAll(list)
  return shot
}

export async function deleteScreenshot(id: string): Promise<boolean> {
  const list = await readAll()
  const idx = list.findIndex(s => s.id === id)
  if (idx < 0) return false
  list.splice(idx, 1)
  // 重新排序
  list.forEach((s, i) => s.order = i)
  await writeAll(list)
  return true
}

export async function updateScreenshot(id: string, data: Partial<Screenshot>): Promise<Screenshot | null> {
  const list = await readAll()
  const idx = list.findIndex(s => s.id === id)
  if (idx < 0) return null
  list[idx] = { ...list[idx], ...data, id }
  await writeAll(list)
  return list[idx]
}
