import cron from 'node-cron'

export function isValidCron(expr: string): boolean {
  if (!expr || typeof expr !== 'string') return false
  const s = expr.trim()
  if (!s) return false
  try {
    if (typeof cron.validate === 'function') return Boolean(cron.validate(s))
  } catch {}
  const parts = s.split(/\s+/)
  return parts.length === 5 || parts.length === 6
}

export function nextRunFrom(expr: string): string | null {
  try {
    const tmp = cron.schedule(expr, () => {}, {
      scheduled: false,
      timezone: 'Asia/Shanghai',
    })
    if (tmp && typeof (tmp as any).nextDates === 'function') {
      const arr = (tmp as any).nextDates(1)
      const d = Array.isArray(arr) ? arr[0] : arr
      try { (tmp as any).stop?.() } catch {}
      if (d instanceof Date) return d.toISOString()
      if (d && typeof d.toISOString === 'function') return d.toISOString()
    }
  } catch {}
  return null
}

export function maskApiKey(k: string, showRaw: boolean): string {
  if (showRaw) return k
  if (!k) return ''
  if (k.length <= 12) return '********'
  return k.slice(0, 8) + '***' + k.slice(-4)
}
