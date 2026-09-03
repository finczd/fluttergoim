import { requireAdmin, publicUser } from '../../utils/auth'
import { getDb } from '../../utils/db'
import { forceReconfigure } from '../../utils/cron-manager'
import { maskApiKey } from '../../utils/cron-utils'

function toTagJson(v: any): string {
  if (Array.isArray(v)) return JSON.stringify(v)
  const s = String(v || '')
  // 尝试 JSON
  try {
    const parsed = JSON.parse(s)
    if (Array.isArray(parsed)) return JSON.stringify(parsed)
  } catch {}
  const arr = s.split(/[,，]/).map(x => x.trim()).filter(Boolean)
  return JSON.stringify(arr)
}

export default defineEventHandler(async (event) => {
  const sess = requireAdmin(event)
  // editor 也允许保存 AI 配置？需求未写死，就 requireAdmin 通用即可。若 role 限制可再加。
  const body = await readBody(event)
  const db = getDb()
  const oldRow = db.prepare('SELECT * FROM ai_configs WHERE id = 1').get() as any
  if (!oldRow) {
    throw createError({ statusCode: 404, message: 'ai_configs 不存在' })
  }

  const provider = body.provider !== undefined ? String(body.provider) : oldRow.provider
  const api_base = body.api_base !== undefined ? String(body.api_base).replace(/\/+$/, '') : oldRow.api_base
  const model = body.model !== undefined ? String(body.model) : oldRow.model
  const temperature = body.temperature !== undefined ? Number(body.temperature) : Number(oldRow.temperature)
  const max_tokens = body.max_tokens !== undefined ? Number(body.max_tokens) : Number(oldRow.max_tokens)
  const system_prompt = body.system_prompt !== undefined ? String(body.system_prompt) : oldRow.system_prompt
  const default_topic_hint = body.default_topic_hint !== undefined ? String(body.default_topic_hint) : oldRow.default_topic_hint
  const default_category_id =
    body.default_category_id === null || body.default_category_id === ''
      ? null
      : body.default_category_id !== undefined
        ? Number(body.default_category_id) || null
        : oldRow.default_category_id
  const default_tags =
    body.default_tags !== undefined ? toTagJson(body.default_tags) : oldRow.default_tags
  const default_status = body.default_status !== undefined ? (body.default_status ? 1 : 0) : Number(oldRow.default_status)
  const enabled = body.enabled !== undefined ? (body.enabled ? 1 : 0) : Number(oldRow.enabled)

  // API Key 逻辑：如果值以 *** 开头则保持旧值
  let api_key = oldRow.api_key
  if (body.api_key !== undefined) {
    const v = String(body.api_key)
    if (!v.startsWith('***')) {
      api_key = v
    }
  }

  db.prepare(
    `UPDATE ai_configs SET
       provider = ?, api_base = ?, api_key = ?, model = ?, temperature = ?, max_tokens = ?,
       system_prompt = ?, default_topic_hint = ?, default_category_id = ?, default_tags = ?,
       default_status = ?, enabled = ?
     WHERE id = 1`
  ).run(
    provider,
    api_base,
    api_key,
    model,
    temperature,
    max_tokens,
    system_prompt,
    default_topic_hint,
    default_category_id,
    default_tags,
    default_status,
    enabled,
  )

  forceReconfigure()

  const row = db.prepare(
    `SELECT a.*, c.name AS default_category_name
     FROM ai_configs a LEFT JOIN categories c ON c.id = a.default_category_id WHERE a.id = 1`
  ).get() as any
  const data = row
    ? {
        ...row,
        api_key: maskApiKey(row.api_key || '', false),
        default_tags: (() => {
          try { return JSON.parse(row.default_tags) } catch { return [] }
        })(),
      }
    : null
  return { code: 0, message: 'ok', data }
})
