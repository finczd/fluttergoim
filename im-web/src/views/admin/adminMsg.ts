/**
 * 后台消息渲染共享工具：消息记录（MessageQuery）与群组消息（GroupManage）共用，
 * 保证两处对同一 type 的渲染（图标样式 + 文本解析）完全一致。
 *
 * 服务端 type 约定（不含历史遗留旧类型 10/11/20/21，App 未上线不考虑兼容旧数据）：
 * 1 文本 2 图片 3 文件 4 语音 5 视频 6 系统(JSON {actor,kind,target})
 * 7 语音通话 8 红包 9 转账 99 撤回
 */

export type Kind =
  | 'text' | 'image' | 'file' | 'voice' | 'video' | 'system'
  | 'call' | 'redpacket' | 'transfer' | 'recall' | 'other'

export const kindMap: Record<number, Kind> = {
  1: 'text', 2: 'image', 3: 'file', 4: 'voice', 5: 'video', 6: 'system',
  7: 'call', 8: 'redpacket', 9: 'transfer', 99: 'recall'
}

export function kindOf(r: Record<string, any>): Kind {
  return kindMap[Number(r?.type)] || 'other'
}

const kindLabelMap: Record<Kind, string> = {
  text: '文本', image: '图片', file: '文件', voice: '语音', video: '视频', system: '系统',
  call: '语音通话', redpacket: '红包', transfer: '转账', recall: '已撤回', other: '其他'
}
export function kindLabel(k: Kind): string {
  return kindLabelMap[k] || '其他'
}

const kindColorMap: Record<Kind, { bg: string; fg: string; border: string }> = {
  text:       { bg: '#F2F3F5', fg: '#4E5969', border: '#E5E6EB' },
  image:      { bg: '#E8F3FF', fg: '#165DFF', border: '#C7D8FF' },
  file:       { bg: '#FFF7E6', fg: '#AD6800', border: '#FFE4B5' },
  voice:      { bg: '#E8FFEA', fg: '#0A7A36', border: '#C9F7CF' },
  video:      { bg: '#EEF0FF', fg: '#4B3CFF', border: '#D7DCFF' },
  system:     { bg: '#F2F3F5', fg: '#4E5969', border: '#E5E6EB' },
  call:       { bg: '#E6FAFF', fg: '#0A7799', border: '#B6ECFF' },
  redpacket:  { bg: '#FFECE8', fg: '#C73110', border: '#FFD1C7' },
  transfer:   { bg: '#FFF4E5', fg: '#A85B00', border: '#FFD79A' },
  recall:     { bg: '#F2F3F5', fg: '#86909C', border: '#E5E6EB' },
  other:      { bg: '#F2F3F5', fg: '#86909C', border: '#E5E6EB' }
}
export function kindStyle(k: Kind) {
  const c = kindColorMap[k] || kindColorMap.text
  return { background: c.bg, color: c.fg, borderColor: c.border }
}

export function parseContentObj(v: any): Record<string, any> {
  if (v == null || v === '') return {}
  if (typeof v === 'object') return v as Record<string, any>
  if (typeof v === 'string') {
    const s = v.trim()
    if (s === '') return {}
    if (s.startsWith('{') && s.endsWith('}')) {
      try {
        const o = JSON.parse(s)
        if (o && typeof o === 'object') return o as Record<string, any>
      } catch { /* ignore */ }
    }
    return { __text: s }
  }
  return {}
}

function isImageUrl(s: string) {
  if (!s) return false
  return /\.(png|jpe?g|gif|webp|bmp|svg|avif)(\?|#|$)/i.test(s)
}

export function imageSrcOf(r: Record<string, any>): string {
  if (typeof r?.content === 'string' && isImageUrl(r.content)) return r.content
  // 图片消息：file 字段 { url, ... }
  const f = r?.file || {}
  const fu = f.url ?? f.fileUrl ?? ''
  if (typeof fu === 'string' && fu) return fu
  const o = parseContentObj(r?.content)
  const u = o.url ?? o.imageUrl ?? o.image ?? o.img ?? o.src
  if (typeof u === 'string' && isImageUrl(u)) return u
  return ''
}

function clipText(s: string, n = 60) {
  if (!s) return ''
  return s.length > n ? s.slice(0, n) + '…' : s
}

function extractSecOf(o: any): number {
  const obj = parseContentObj(o)
  const raw = (o == null || typeof o === 'object') ? 0 : Number(o)
  return Math.round(Number(obj.duration ?? obj.seconds ?? (isFinite(raw) ? raw : 0)) || 0)
}

// 系统消息（type 6）：content JSON {actor, kind, target} 解析成中文句子，不显示原始 JSON
function systemText(o: Record<string, any>): string {
  const actor = String(o.actor ?? '').trim()
  const kind = String(o.kind ?? '').trim()
  const target = String(o.target ?? o.nickname ?? o.user ?? '').trim()
  const verbs: Record<string, string> = {
    invite: '邀请', join: '加入', kick: '移出', remove: '移除', leave: '退出',
    add: '添加', create: '创建', dissolve: '解散', dismiss: '解散',
    update: '更新', mute: '禁言', unmute: '解除禁言', transfer: '转让',
    promote: '设为管理员', demote: '取消管理员', recall: '撤回'
  }
  const verb = verbs[kind] || kind
  const parts: string[] = []
  if (actor) parts.push(actor)
  if (verb) parts.push(verb + '了')
  if (target) parts.push(target)
  if (parts.length) return parts.join(' ')
  return String(o.__text ?? o.text ?? o.label ?? o.content ?? '系统消息')
}

export function displayText(r: Record<string, any>): string {
  const k = kindOf(r)
  const raw = r?.content
  const o = parseContentObj(raw)
  switch (k) {
    case 'text': {
      if (typeof raw === 'string' && !(raw.startsWith('{') && raw.endsWith('}'))) return raw
      return clipText(String(o.__text ?? o.text ?? o.content ?? ''))
    }
    case 'image': return '[图片]'
    case 'file': {
      const f = r?.file || {}
      const name = String(f.name ?? o.name ?? o.fileName ?? '文件')
      const size = f.size ?? o.size
      return size ? `${clipText(name, 24)} · ${formatSize(Number(size))}` : clipText(name, 32)
    }
    case 'voice': return `语音 ${extractSecOf(raw)} 秒`
    case 'video': return `视频 ${extractSecOf(raw)} 秒`
    case 'system': return clipText(systemText(o), 60)
    case 'call': {
      const sec = extractSecOf(raw)
      const a = String(o.action ?? '').toLowerCase()
      const suf = a === 'cancel' ? '（已取消）' : a === 'missed' ? '（未接听）' : a === 'reject' || a === 'declined' ? '（已拒绝）' : ''
      return sec > 0 ? `${sec} 秒${suf}` : (suf || '通话')
    }
    case 'redpacket':
    case 'transfer': {
      const amt = Number(o.amount ?? 0)
      const label = String(o.note ?? o.label ?? (k === 'redpacket' ? '红包' : '转账'))
      return amt ? `${label} ¥${amt.toFixed(2)}` : label
    }
    case 'recall': return '消息已撤回'
    default: {
      if (typeof raw === 'string' && !(raw.startsWith('{') && raw.endsWith('}'))) return clipText(raw, 40)
      const hint = [o.title, o.label, o.name, o.text, o.content].map(x => (x != null) ? String(x) : '').filter(Boolean)[0]
      return hint ? clipText(hint, 40) : '其他消息'
    }
  }
}

function formatSize(n: number): string {
  if (!isFinite(n)) return ''
  if (n < 1024) return `${n}B`
  if (n < 1024 * 1024) return `${(n / 1024).toFixed(1)}KB`
  return `${(n / 1024 / 1024).toFixed(2)}MB`
}
