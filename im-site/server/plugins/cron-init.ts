import { getDb } from '../utils/db'
import { startCronScheduler } from '../utils/cron-manager'

export default () => {
  try {
    getDb()
  } catch (e) {
    console.error('[cron-init] DB init failed:', e)
    return
  }
  try {
    startCronScheduler()
  } catch (e) {
    console.warn('[cron-init] startCronScheduler failed:', e)
  }
}
