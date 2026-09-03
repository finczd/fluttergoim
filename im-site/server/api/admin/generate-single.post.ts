import { requireAdmin } from '../../utils/auth'
import { generateSingleAiArticle } from '../../utils/ai-runner'

export default defineEventHandler(async (event) => {
  requireAdmin(event)
  const body = await readBody(event)
  const customTopic = body?.customTopic !== undefined ? String(body.customTopic) : undefined
  const result = await generateSingleAiArticle(customTopic ? { customTopic } : undefined)
  return { code: 0, message: 'ok', data: result }
})
