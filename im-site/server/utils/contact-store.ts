import { mkdir, readFile, writeFile, readdir, unlink } from 'node:fs/promises'
import { join } from 'node:path'
import { randomUUID } from 'node:crypto'

const DATA_DIR = join(process.cwd(), 'data', 'contacts')

export interface ContactSubmission {
  id: string
  name: string
  contact: string
  message: string
  createdAt: string
  read: boolean
}

async function ensureDir() {
  await mkdir(DATA_DIR, { recursive: true })
}

export async function createContact(name: string, contact: string, message: string): Promise<ContactSubmission> {
  await ensureDir()
  const sub: ContactSubmission = {
    id: randomUUID(),
    name,
    contact,
    message: message || '',
    createdAt: new Date().toISOString(),
    read: false,
  }
  await writeFile(join(DATA_DIR, `${sub.id}.json`), JSON.stringify(sub, null, 2), 'utf-8')
  return sub
}

export async function listContacts(): Promise<ContactSubmission[]> {
  await ensureDir()
  const files = await readdir(DATA_DIR)
  const items: ContactSubmission[] = []
  for (const f of files) {
    if (!f.endsWith('.json')) continue
    try {
      const raw = await readFile(join(DATA_DIR, f), 'utf-8')
      items.push(JSON.parse(raw))
    } catch { /* skip */ }
  }
  return items.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())
}

export async function markRead(id: string): Promise<boolean> {
  await ensureDir()
  try {
    const raw = await readFile(join(DATA_DIR, `${id}.json`), 'utf-8')
    const sub: ContactSubmission = JSON.parse(raw)
    sub.read = true
    await writeFile(join(DATA_DIR, `${id}.json`), JSON.stringify(sub, null, 2), 'utf-8')
    return true
  } catch {
    return false
  }
}

export async function deleteContact(id: string): Promise<boolean> {
  try {
    await unlink(join(DATA_DIR, `${id}.json`))
    return true
  } catch {
    return false
  }
}
