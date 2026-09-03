import { getDb } from './db'
import { aiChatCompletion } from './ai-client'

function formatDateCN(d: Date) {
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
}

function quickSlug() {
  return (
    'ai-' +
    Date.now().toString(36) +
    Math.floor(Math.random() * 0xfff).toString(36).padStart(3, '0')
  )
}

interface AiConfigRow {
  id: number
  provider: string
  api_base: string
  api_key: string
  model: string
  temperature: number
  max_tokens: number
  system_prompt: string
  default_topic_hint: string
  default_category_id: number | null
  default_tags: string
  default_status: number
  enabled: number
}

interface JobConfigRow {
  id: number
  enabled: number
  cron_expr: string
  max_articles_per_run: number
  auto_publish: number
  last_run_at: string | null
  next_run_at: string | null
}

function parseAiOutput(raw: string) {
  const text = String(raw || '').replace(/\r\n/g, '\n')
  const lines = text.split('\n')
  // 标题：找第一行【】包裹
  let title = ''
  let summary = ''
  let bodyStartIdx = 0
  const titleMatch = lines[0]?.match(/【([^】]+)】/)
  if (titleMatch) {
    title = titleMatch[1].trim()
    bodyStartIdx = 1
    // 第二行是摘要（2句话纯文本）
    if (lines.length > 1 && lines[1].trim()) {
      summary = lines[1].trim()
      bodyStartIdx = 2
    }
  } else {
    // 退而求其次：按要求生成默认标题
    const now = new Date()
    const pad = (n: number) => String(n).padStart(2, '0')
    title = `AI 资讯 ${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())} ${pad(now.getHours())}:${pad(now.getMinutes())}`
    // 没有解析到【】时，把第一行可能包含【...】混在一起也算上；再尝试抓摘要
    if (lines.length > 1) {
      summary = lines[0].trim().slice(0, 200)
      bodyStartIdx = 1
    }
  }
  // 从 bodyStartIdx 开始拼接所有行作为正文
  const body = lines.slice(bodyStartIdx).join('\n').trim()
  // 如果正文被 ```html ... ``` 包裹就剥掉
  const m = body.match(/^\s*```[\w]*\s*\n([\s\S]*?)\n```\s*$/i)
  const content = m ? m[1].trim() : body
  return { title, summary, content }
}

function insertArticle(db: any, payload: {
  slug: string
  title: string
  summary: string
  content: string
  category_id: number | null
  tags: string
  status: number
  ai_run_id: number
  created_at: string
  updated_at: string
}) {
  return db.prepare(
    `INSERT INTO articles (slug, title, summary, content, cover, category_id, tags, status, source, ai_run_id, created_at, updated_at)
     VALUES (@slug, @title, @summary, @content, '', @category_id, @tags, @status, 'ai', @ai_run_id, @created_at, @updated_at)`
  ).run(payload)
}

/**
 * 根据 ai_configs.id=1 + ai_job_configs 生成指定条数文章。
 * 返回 run id。
 */
export async function runAiArticleJob(
  triggerType: 'cron' | 'manual',
  overrides?: { count?: number }
): Promise<number> {
  const db = getDb()

  const aiCfg = db.prepare('SELECT * FROM ai_configs WHERE id = 1').get() as AiConfigRow | undefined
  if (!aiCfg || aiCfg.enabled !== 1 || !aiCfg.api_key) {
    throw new Error('AI 未开启或未配置 API Key')
  }
  const jobCfg = db.prepare('SELECT * FROM ai_job_configs WHERE id = 1').get() as JobConfigRow | undefined
  const maxPer = jobCfg?.max_articles_per_run ?? 1
  const count = Math.max(1, Math.min(50, overrides?.count ?? maxPer))

  const now = new Date()
  const insertRun = db.prepare(
    `INSERT INTO ai_job_runs (started_at, finished_at, status, articles_count, error_message, trigger_type)
     VALUES (?, NULL, 0, 0, '', ?)`
  )
  const info = insertRun.run(now.toISOString(), triggerType)
  const runId = Number(info.lastInsertRowid)

  let successCount = 0
  try {
    const dateStr = formatDateCN(now)
    const topicHint = aiCfg.default_topic_hint || ''

    for (let i = 0; i < count; i++) {
      const userPromptLines = [
        topicHint ? `话题倾向：${topicHint}。` : '',
        `今日日期：${dateStr}。`,
        '请生成一个原创标题（必须用【】包裹标题首行）+ 100字左右摘要 + 正文 HTML。严格格式：',
        '第 1 行 【xxx】=标题，第 2 行是摘要（2句话，纯文本），第 3 行开始是正文 HTML。',
        '正文使用简单 HTML 标签（<p>、<h3>、<ul>、<li>、<strong> 等）即可，不要 Markdown 代码块，不要用 ```html ``` 包裹。',
      ].filter(Boolean).join('\n')

      const raw = await aiChatCompletion({
        apiBase: aiCfg.api_base,
        apiKey: aiCfg.api_key,
        model: aiCfg.model,
        temperature: aiCfg.temperature,
        maxTokens: aiCfg.max_tokens,
        systemPrompt: aiCfg.system_prompt,
        userPrompt: userPromptLines,
      })
      const parsed = parseAiOutput(raw)
      const createdISO = new Date().toISOString()
      // 计算 status: ai_configs.default_status OR ai_job_configs.auto_publish
      const statusVal = (aiCfg.default_status || (jobCfg?.auto_publish ?? 0)) ? 1 : 0

      let slug = quickSlug()
      let attempts = 0
      while (attempts < 4) {
        try {
          const ins = insertArticle(db, {
            slug,
            title: parsed.title,
            summary: parsed.summary,
            content: parsed.content,
            category_id: aiCfg.default_category_id ?? null,
            tags: aiCfg.default_tags || '[]',
            status: statusVal,
            ai_run_id: runId,
            created_at: createdISO,
            updated_at: createdISO,
          })
          if (ins && ins.changes) {
            successCount += 1
            break
          }
        } catch (e: any) {
          const msg = String(e?.message || '')
          if (msg.includes('UNIQUE') && msg.includes('slug') && attempts < 3) {
            slug = slug + String.fromCharCode(97 + Math.floor(Math.random() * 26))
            attempts++
            continue
          }
          throw e
        }
      }
    }

    db.prepare(
      `UPDATE ai_job_runs SET status = 1, articles_count = ?, finished_at = ?, error_message = '' WHERE id = ?`
    ).run(successCount, new Date().toISOString(), runId)

    // 顺带更新 job config 的 last_run_at
    try {
      db.prepare(`UPDATE ai_job_configs SET last_run_at = ? WHERE id = 1`).run(new Date().toISOString())
    } catch {}
  } catch (err: any) {
    const msg = String(err?.message || String(err)).slice(0, 2000)
    try {
      db.prepare(
        `UPDATE ai_job_runs SET status = 2, articles_count = ?, finished_at = ?, error_message = ? WHERE id = ?`
      ).run(successCount, new Date().toISOString(), msg, runId)
    } catch {}
  }

  return runId
}

/**
 * 单独生成 1 篇（可被"立即生成单篇"按钮调用）
 */
export async function generateSingleAiArticle(opts?: {
  customTopic?: string
}): Promise<{ id: number; title: string; slug: string }> {
  const db = getDb()
  const aiCfg = db.prepare('SELECT * FROM ai_configs WHERE id = 1').get() as AiConfigRow | undefined
  if (!aiCfg || aiCfg.enabled !== 1 || !aiCfg.api_key) {
    throw new Error('AI 未开启或未配置 API Key')
  }
  const jobCfg = db.prepare('SELECT * FROM ai_job_configs WHERE id = 1').get() as JobConfigRow | undefined

  const now = new Date()
  const dateStr = formatDateCN(now)

  // 创建一个单独的 manual 行作为 single 生成的 run
  const runInfo = db.prepare(
    `INSERT INTO ai_job_runs (started_at, finished_at, status, articles_count, error_message, trigger_type)
     VALUES (?, NULL, 0, 0, '', 'manual')`
  ).run(now.toISOString())
  const runId = Number(runInfo.lastInsertRowid)

  try {
    const topicHint = opts?.customTopic || aiCfg.default_topic_hint || ''
    const userPromptLines = [
      opts?.customTopic ? `自定义话题：${opts.customTopic}。` : (topicHint ? `话题倾向：${topicHint}。` : ''),
      `今日日期：${dateStr}。`,
      '请生成一个原创标题（必须用【】包裹标题首行）+ 100字左右摘要 + 正文 HTML。严格格式：',
      '第 1 行 【xxx】=标题，第 2 行是摘要（2句话，纯文本），第 3 行开始是正文 HTML。',
      '正文使用简单 HTML 标签（<p>、<h3>、<ul>、<li>、<strong> 等）即可，不要 Markdown 代码块，不要用 ```html ``` 包裹。',
    ].filter(Boolean).join('\n')

    const raw = await aiChatCompletion({
      apiBase: aiCfg.api_base,
      apiKey: aiCfg.api_key,
      model: aiCfg.model,
      temperature: aiCfg.temperature,
      maxTokens: aiCfg.max_tokens,
      systemPrompt: aiCfg.system_prompt,
      userPrompt: userPromptLines,
    })
    const parsed = parseAiOutput(raw)
    const createdISO = new Date().toISOString()
    const statusVal = (aiCfg.default_status || (jobCfg?.auto_publish ?? 0)) ? 1 : 0

    let slug = quickSlug()
    let articleId = 0
    let attempts = 0
    while (attempts < 4) {
      try {
        const ins = insertArticle(db, {
          slug,
          title: parsed.title,
          summary: parsed.summary,
          content: parsed.content,
          category_id: aiCfg.default_category_id ?? null,
          tags: aiCfg.default_tags || '[]',
          status: statusVal,
          ai_run_id: runId,
          created_at: createdISO,
          updated_at: createdISO,
        })
        if (ins && ins.changes) {
          articleId = Number(ins.lastInsertRowid)
          break
        }
      } catch (e: any) {
        const msg = String(e?.message || '')
        if (msg.includes('UNIQUE') && msg.includes('slug') && attempts < 3) {
          slug = slug + String.fromCharCode(97 + Math.floor(Math.random() * 26))
          attempts++
          continue
        }
        throw e
      }
    }

    db.prepare(
      `UPDATE ai_job_runs SET status = 1, articles_count = 1, finished_at = ?, error_message = '' WHERE id = ?`
    ).run(new Date().toISOString(), runId)
    return { id: articleId, title: parsed.title, slug }
  } catch (err: any) {
    const msg = String(err?.message || String(err)).slice(0, 2000)
    try {
      db.prepare(
        `UPDATE ai_job_runs SET status = 2, articles_count = 0, finished_at = ?, error_message = ? WHERE id = ?`
      ).run(new Date().toISOString(), msg, runId)
    } catch {}
    throw err
  }
}
