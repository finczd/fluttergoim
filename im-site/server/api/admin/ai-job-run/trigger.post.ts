import { requireAdmin } from '../../../utils/auth'
import { runAiArticleJob } from '../../../utils/ai-runner'

export default defineEventHandler(async (event) => {
  requireAdmin(event)
  const body = await readBody(event)
  const count = body?.count !== undefined ? Number(body.count) : undefined
  const runId = await runAiArticleJob('manual', count !== undefined ? { count } : undefined)
  return { code: 0, message: 'ok', data: { runId } }
})
