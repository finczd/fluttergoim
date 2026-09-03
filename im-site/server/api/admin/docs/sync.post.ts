// 后台文档管理：手动同步仓库 docs/ 目录到 im-site/content/docs/
import { syncDocsDirToContent } from '../../../utils/db'

export default defineEventHandler(async (event) => {
  requireAdmin(event)
  try {
    syncDocsDirToContent()
  } catch (e: any) {
    return { code: 1, message: e?.message || '同步失败' }
  }
  return { code: 0, message: '同步成功' }
})
