import { mkdir, readFile, writeFile } from 'node:fs/promises'
import { join } from 'node:path'

const DATA_DIR = join(process.cwd(), 'data')

export interface SiteConfig {
  siteTitle: string
  siteDescription: string
  siteKeywords: string
  logo: string
  contactEmail: string
  contactPhone: string
  contactWechat: string
  contactQQ: string
}

const DEFAULT: SiteConfig = {
  siteTitle: 'ChatPulse - 企业级即时通讯系统 | 源码出售+定制开发',
  siteDescription: 'ChatPulse 企业级即时通讯系统，Go + Vue + Flutter 全栈技术，支持单聊群聊、音视频通话、红包转账、朋友圈、靓号系统。源码出售、私有化部署、定制开发、终身授权。',
  siteKeywords: '即时通讯系统,IM系统源码,企业通讯,聊天APP源码,Go IM,Flutter聊天,私有化部署IM,定制开发,ChatPulse',
  logo: '/favicon.svg',
  contactEmail: 'contact@chatpulse.cn',
  contactPhone: '400-000-0000',
  contactWechat: 'ChatPulse_BD',
  contactQQ: '12345678',
}

async function ensureDir() {
  await mkdir(DATA_DIR, { recursive: true })
}

export async function getSiteConfig(): Promise<SiteConfig> {
  await ensureDir()
  try {
    const raw = await readFile(join(DATA_DIR, 'site-config.json'), 'utf-8')
    return { ...DEFAULT, ...JSON.parse(raw) }
  } catch {
    return DEFAULT
  }
}

export async function saveSiteConfig(data: Partial<SiteConfig>): Promise<SiteConfig> {
  await ensureDir()
  const current = await getSiteConfig()
  const updated = { ...current, ...data }
  await writeFile(join(DATA_DIR, 'site-config.json'), JSON.stringify(updated, null, 2), 'utf-8')
  return updated
}
