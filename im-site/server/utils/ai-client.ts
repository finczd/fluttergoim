export interface AiChatMessage {
  role: 'system' | 'user' | 'assistant'
  content: string
}

export interface AiGenerateOptions {
  apiBase: string
  apiKey: string
  model: string
  temperature: number
  maxTokens: number
  systemPrompt: string
  userPrompt: string
  timeoutMs?: number
}

/**
 * 调用 /chat/completions，返回 assistant message 的纯文本。
 * 失败 throw Error（带可读 message）。
 */
export async function aiChatCompletion(opts: AiGenerateOptions): Promise<string> {
  if (!opts.apiKey) {
    throw new Error('缺少 API Key')
  }
  const timeout = opts.timeoutMs ?? 90000
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), timeout)
  try {
    const base = (opts.apiBase || '').replace(/\/+$/, '')
    if (!base) throw new Error('缺少 API Base 地址')
    const url = `${base}/chat/completions`
    const body = {
      model: opts.model,
      temperature: Number(opts.temperature) ?? 0.7,
      max_tokens: Number(opts.maxTokens) ?? 2000,
      stream: false,
      messages: [
        { role: 'system', content: opts.systemPrompt || '' },
        { role: 'user', content: opts.userPrompt || '' },
      ],
    }
    const resp = await fetch(url, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${opts.apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
      signal: controller.signal,
    })
    const text = await resp.text()
    let data: any = null
    try { data = text ? JSON.parse(text) : null } catch { /* ignore */ }
    if (!resp.ok) {
      const errMsg =
        (data && (data.error?.message || data.message)) ||
        resp.statusText ||
        `HTTP ${resp.status}`
      throw new Error(`AI 接口错误 (${resp.status}): ${errMsg}`)
    }
    if (!data || !data.choices || !data.choices[0] || !data.choices[0].message) {
      throw new Error('AI 返回体缺少 choices/message 字段')
    }
    const content = data.choices[0].message.content || ''
    return String(content).trim()
  } catch (e: any) {
    if (e?.name === 'AbortError' || e?.code === 20 || String(e?.message).includes('aborted')) {
      throw new Error(`AI 请求超时（${timeout}ms）`)
    }
    if (e instanceof Error) throw e
    throw new Error(String(e || '未知 AI 错误'))
  } finally {
    clearTimeout(timer)
  }
}
