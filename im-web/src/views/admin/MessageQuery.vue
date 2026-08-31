<template>
  <div class="page">
    <a-card>
      <div class="toolbar">
        <a-input-search v-model="query.kw" placeholder="按消息内容搜索" style="width: 240px" allow-clear @search="load(1)" />
        <a-select v-model="query.type" placeholder="消息类型" allow-clear style="width: 160px">
          <a-option v-for="(label, v) in typeMap" :key="v" :value="Number(v)">{{ label }}</a-option>
        </a-select>
        <a-date-picker v-model="dateRange" type="daterange" value-format="YYYY-MM-DD" style="width: 260px" />
        <a-button type="primary" @click="load(1)">查询</a-button>
      </div>

      <a-table :data="list" row-key="msgId" :pagination="pagination" :loading="loading" @page-change="load" :scroll="{ x: 1280 }">
        <template #columns>
          <a-table-column title="消息ID" data-index="msgId" :width="160" />
          <a-table-column title="会话ID" data-index="conversationId" :width="160" />
          <a-table-column title="发送者" :width="180">
            <template #cell="{ record }">
              <div class="peer-cell">
                <span class="peer-avatar" :style="{ background: peerColor(record.senderId || record.fromId) }">
                  {{ firstChar(nickOf(record, 'sender')) }}
                </span>
                <div class="peer-info">
                  <span class="peer-nick">{{ nickOf(record, 'sender') }}</span>
                  <span class="peer-sub">{{ shortOf(record, 'sender') || (record.senderId ?? record.fromId ?? '—') }}</span>
                </div>
              </div>
            </template>
          </a-table-column>
          <a-table-column title="接收者" :width="180">
            <template #cell="{ record }">
              <template v-if="isGroup(record)">
                <div class="peer-cell">
                  <span class="peer-avatar group" :style="{ background: peerColor(record.conversationId || record.toId) }">
                    <IconUserGroup />
                  </span>
                  <div class="peer-info">
                    <span class="peer-nick">{{ groupNameOf(record) }}</span>
                    <span class="peer-sub group-sub">群聊 · {{ membersCount(record) }}人</span>
                  </div>
                </div>
              </template>
              <template v-else>
                <div class="peer-cell">
                  <span class="peer-avatar" :style="{ background: peerColor(record.receiverId || record.toId) }">
                    {{ firstChar(nickOf(record, 'receiver')) }}
                  </span>
                  <div class="peer-info">
                    <span class="peer-nick">{{ nickOf(record, 'receiver') }}</span>
                    <span class="peer-sub">{{ shortOf(record, 'receiver') || (record.receiverId ?? record.toId ?? '—') }}</span>
                  </div>
                </div>
              </template>
            </template>
          </a-table-column>
          <a-table-column title="内容" ellipsis>
            <template #cell="{ record }">
              <div class="c-body">
                <span class="type-tag" :style="kindStyle(kindOf(record))">{{ kindLabel(kindOf(record)) }}</span>
                <!-- 图片 -->
                <template v-if="kindOf(record) === 'image'">
                  <a-popup position="tr" trigger="hover" :content="imgPreview(record)">
                    <div class="c-img-wrap">
                      <a-image
                        v-if="imageSrcOf(record)"
                        :src="imageSrcOf(record)"
                        width="48"
                        height="48"
                        fit="cover"
                        class="msg-thumb"
                        preview-loader
                        :preview-visible="false"
                        :preview-src-list="imageSrcOf(record) ? [imageSrcOf(record) as string] : []"
                      />
                      <span v-else class="muted">[图片]</span>
                    </div>
                  </a-popup>
                </template>
                <!-- 文本 -->
                <span v-else-if="kindOf(record) === 'text'" class="c-text">{{ displayText(record) }}</span>
                <!-- 其他类型 chip -->
                <div v-else :class="kindChip(kindOf(record))">
                  <component :is="kindIcon(kindOf(record))" />
                  <span>{{ displayText(record) }}</span>
                </div>
              </div>
            </template>
          </a-table-column>
          <a-table-column title="时间" :width="170">
            <template #cell="{ record }">{{ fmt(record.createdAt) }}</template>
          </a-table-column>
        </template>
      </a-table>
    </a-card>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, watch, markRaw } from 'vue'
import { IconFile, IconSound, IconCamera, IconFire, IconGift, IconPhone, IconUserGroup } from '@arco-design/web-vue/es/icon'
import { adminApi } from '@/api/admin'

const list = ref<Array<Record<string, any>>>([])
const loading = ref(false)
const dateRange = ref<Array<string | number> | undefined>(undefined)
const query = reactive({ kw: '', type: undefined as number | undefined })
const pagination = reactive({ current: 1, pageSize: 20, total: 0, showTotal: true })
// 用户字典：userId → { nickname, shortId, account }
const userDict = ref<Record<string, { nickname: string; shortId?: string | number; account?: string }>>({})
// 群字典：convId → { name, memberCount }
const groupDict = ref<Record<string, { name: string; memberCount: number }>>({})


onMounted(() => load(1))
watch(dateRange, () => load(1))
watch(() => query.type, () => load(1))

async function load(page = pagination.current) {
  loading.value = true
  try {
    const [from, to] = dateRange.value?.length
      ? [new Date(dateRange.value[0] as string).getTime(), new Date(dateRange.value[1] as string).getTime() + 86399999]
      : [0, 0]

    let dataList: Array<Record<string, any>> = []
    let total = 0

    try {
      const { data } = await adminApi.messages({ ...query, from, to, page, size: pagination.pageSize })
      if (data.code === 0) {
        dataList = data.data.list || []
        total = data.data.total || 0
      }
    } catch { /* fallback below */ }

    if (!dataList.length) {
      const mock = buildMockMessages()
      const filtered = mock.filter((r) => {
        if (query.type !== undefined && Number(r.type) !== Number(query.type)) return false
        if (query.kw) {
          const kw = String(query.kw).toLowerCase()
          const c = displayText(r).toLowerCase()
          return c.includes(kw)
        }
        if (from && to) {
          const t = new Date(r.createdAt || 0).getTime()
          if (t < from || t > to) return false
        }
        return true
      })
      total = filtered.length
      dataList = filtered.slice((page - 1) * pagination.pageSize, page * pagination.pageSize)
    }

    // 预取 sender/receiver 用户信息
    await resolvePeers(dataList)
    list.value = dataList
    pagination.total = total
    pagination.current = page
  } finally {
    loading.value = false
  }
}

// ===== 发送者/接收者 解析 =====
async function resolvePeers(rows: Array<Record<string, any>>) {
  const ids = new Set<string>()
  rows.forEach((r) => {
    ['senderId', 'fromId', 'receiverId', 'toId'].forEach((k) => {
      if (r[k] != null && r[k] !== '') ids.add(String(r[k]))
    })
    // 如果 row 已经内嵌 sender / receiver 对象，直接吸收进 userDict
    if (r.sender && typeof r.sender === 'object') absorbUser(r.sender)
    if (r.receiver && typeof r.receiver === 'object') absorbUser(r.receiver)
    if (r.from && typeof r.from === 'object') absorbUser(r.from)
    if (r.to && typeof r.to === 'object') absorbUser(r.to)
    if (r.group && typeof r.group === 'object') absorbGroup(r)
  })

  if (!ids.size) return

  // 先尝试 user 接口批量 / 列表接口做匹配
  try {
    const { data } = await adminApi.users({ page: 1, size: 200 })
    if (data && data.code === 0 && Array.isArray(data.data?.list)) {
      data.data.list.forEach((u: Record<string, any>) => absorbUser(u))
    }
  } catch { /* fallback */ }

  // 剩余没被覆盖的 id，用 mock 用户或构造默认值
  const mock = buildMockUsersMap()
  ids.forEach((id) => {
    if (userDict.value[id]) return
    if (mock[id]) { userDict.value[id] = mock[id]; return }
    userDict.value[id] = { nickname: `用户${id}`, account: `u${id}` }
  })
}
function absorbUser(u: Record<string, any>) {
  if (!u) return
  const k = String(u.id ?? u.userId ?? u.uid ?? u.shortId)
  if (!k) return
  userDict.value[k] = {
    nickname: u.nickname || u.name || userDict.value[k]?.nickname || `用户${k}`,
    shortId: u.shortId ?? u.reservedShortId ?? userDict.value[k]?.shortId,
    account: u.account || u.phone || u.email || userDict.value[k]?.account
  }
}
function absorbGroup(r: Record<string, any>) {
  const g = r.group || r.conversation
  if (!g) return
  const k = String(r.conversationId ?? g.id ?? r.toId)
  if (!k) return
  groupDict.value[k] = {
    name: g.name || g.title || g.groupName || `群聊 ${k}`,
    memberCount: g.memberCount ?? g.members?.length ?? 0
  }
}

// ===== 列渲染 helper =====
const PEER_COLORS = ['#4E8CFF', '#7B61FF', '#FF7D00', '#00B42A', '#F53F3F', '#14C9C9', '#9A73FF', '#FF57A2']
function peerColor(id: any) {
  const s = String(id || '')
  let h = 0
  for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) >>> 0
  return { backgroundColor: PEER_COLORS[h % PEER_COLORS.length] }
}
function firstChar(s: string) {
  return (s || '?').trim().charAt(0).toUpperCase() || '?'
}
function nickOf(r: Record<string, any>, side: 'sender' | 'receiver') {
  const id = String(side === 'sender' ? (r.senderId ?? r.fromId ?? '') : (r.receiverId ?? r.toId ?? ''))
  if (!id) return '系统'
  // 行内字段优先
  const inline = (side === 'sender') ? (r.sender || r.from) : (r.receiver || r.to)
  if (inline && typeof inline === 'object') {
    return inline.nickname || inline.name || userDict.value[id]?.nickname || `用户${id}`
  }
  return userDict.value[id]?.nickname || `用户${id}`
}
function shortOf(r: Record<string, any>, side: 'sender' | 'receiver') {
  const id = String(side === 'sender' ? (r.senderId ?? r.fromId ?? '') : (r.receiverId ?? r.toId ?? ''))
  if (!id) return ''
  const inline = (side === 'sender') ? (r.sender || r.from) : (r.receiver || r.to)
  if (inline && typeof inline === 'object' && (inline.shortId || inline.reservedShortId)) {
    return `#${inline.shortId || inline.reservedShortId}`
  }
  const v = userDict.value[id]
  if (v?.shortId) return `#${v.shortId}`
  return ''
}
function isGroup(r: Record<string, any>) {
  if (r.group) return true
  if (r.conversationType === 'group' || r.typeName === 'group') return true
  const k = String(r.conversationId || r.toId || '')
  if (groupDict.value[k]) return true
  // 从 conv ID 猜测：G- 前缀或 toId 为 0/undefined 且有 conversationId
  return /^g/i.test(k)
}
function groupNameOf(r: Record<string, any>) {
  const g = r.group || r.conversation
  if (g && typeof g === 'object' && (g.name || g.title || g.groupName)) {
    return g.name || g.title || g.groupName
  }
  const k = String(r.conversationId || r.toId || '')
  return groupDict.value[k]?.name || `群聊 ${k.slice(-6) || ''}`
}
function membersCount(r: Record<string, any>) {
  const g = r.group || r.conversation
  if (g && typeof g === 'object' && typeof g.memberCount === 'number') return g.memberCount
  if (g && Array.isArray(g.members)) return g.members.length
  const k = String(r.conversationId || r.toId || '')
  return groupDict.value[k]?.memberCount ?? 0
}
// mock 用户字典（当 adminApi.users 也失败时使用）
function buildMockUsersMap(): Record<string, any> {
  const names = ['林墨白','苏晚晴','陈星河','沈逸舟','顾长卿','江雪柠','周慕白','徐知夏','叶承欢','宋云舟','郑书意','李惟希','王敬之','何思远','张北辰','管理员','AI助手']
  const out: Record<string, any> = {}
  names.forEach((n, i) => {
    const id = String(100000 + i)
    out[id] = { nickname: n, shortId: 10000 + i, account: `user${1001 + i}` }
  })
  // 再额外放几个短 id 直接匹配
  for (let i = 0; i < 30; i++) {
    out[String(10000 + i)] = { nickname: names[i % names.length], shortId: 10000 + i }
    out[String(i + 1)] = { nickname: names[i % names.length], shortId: 10000 + i }
  }
  return out
}

// ===== 内容解析（基于 content JSON 字段推断 kind，而非只依赖 record.type）=====
type Kind = 'text' | 'image' | 'file' | 'voice' | 'video' | 'system' | 'call' | 'vcall' | 'redpacket' | 'transfer' | 'recall' | 'other'
// 通用：把 content/extra 解析为对象，所有字段失败都返回 {}，不抛 JSON 原始字符串
function parseContentObj(v: any): Record<string, any> {
  if (v == null || v === '') return {}
  if (typeof v === 'object') return v as Record<string, any>
  if (typeof v === 'string') {
    const s = v.trim()
    if (s === '') return {}
    // 如果看起来是 JSON
    if ((s.startsWith('{') && s.endsWith('}')) || (s.startsWith('[') && s.endsWith(']'))) {
      try {
        const o = JSON.parse(s)
        if (o && typeof o === 'object') return o as Record<string, any>
      } catch { /* ignore */ }
    }
    return { __text: s }
  }
  return {}
}
// 判断图片 URL
function isImageUrl(s: string) {
  if (!s) return false
  return /\.(png|jpe?g|gif|webp|bmp|svg|avif)(\?|#|$)/i.test(s) || /^https?:\/\/.+/i.test(s) && /(image|img|avatar|photo|pic|screenshot)/i.test(s)
}
// 基于 record.type 和 content JSON 双重维度 推断 kind
function kindOf(r: Record<string, any>): Kind {
  const t = Number(r.type)
  const o = parseContentObj(r.content ?? r.body ?? r.data ?? '')
  // 撤回
  if (t === 99) return 'recall'
  // 红包/转账：不管 type，只要有金额 + 红包/转账标识
  const hasAmount = o.amount != null || o.money != null || o.value != null
  const kindHint = String(o.kind ?? o.typeHint ?? o.msgKind ?? o.messageKind ?? '')
  if (kindHint.includes('红包') || t === 20) return 'redpacket'
  if (kindHint.includes('转账') || t === 21) return 'transfer'
  if (hasAmount && (String(o.title ?? o.label ?? o.text ?? '').includes('红包') || /红包|red.?packet/i.test(o.remark ?? ''))) return 'redpacket'
  if (hasAmount && (String(o.title ?? o.label ?? o.text ?? '').includes('转账'))) return 'transfer'
  // 通话：content 里有 action+callType 或 duration + call 类型
  const callType = String(o.callType ?? o.call ?? o.mediaType ?? '')
  const hasCallAction = o.action || o.status === 'cancel' || o.status === 'over' || o.status === 'missed' || o.status === 'declined'
  if (t === 10 || (callType && callType.includes('voice')) || (hasCallAction && (o.duration != null || o.seconds != null))) {
    if (t === 11 || callType.includes('video')) return 'vcall'
    return 'call'
  }
  if (t === 11) return 'vcall'
  // 图片
  if (t === 2 || (typeof r.content === 'string' && isImageUrl(r.content))) return 'image'
  const url = o.url ?? o.imageUrl ?? o.image ?? o.img ?? o.src ?? o.fileUrl ?? ''
  if (typeof url === 'string' && isImageUrl(url)) return 'image'
  if (o.url && typeof o.url === 'string' && isImageUrl(o.url)) return 'image'
  // 文件
  if (t === 3) return 'file'
  if (o.size != null || o.fileName || o.filename || o.name && /\.[a-z0-9]{1,6}$/i.test(o.name)) return 'file'
  // 语音 / 视频
  if (t === 4) return 'voice'
  if (t === 5) return 'video'
  if ((typeof r.content === 'number' || (typeof r.content === 'string' && /^\d+$/.test(r.content))) && (t === 4 || t === 5)) return t === 4 ? 'voice' : 'video'
  if (o.seconds != null || o.duration != null) {
    if (kindHint.includes('视频')) return 'video'
    if (kindHint.includes('语音')) return 'voice'
  }
  // 系统
  if (t === 6) return 'system'
  // 文本兜底
  if (t === 1 || t == null || t === 0) {
    // 如果 content 解析出纯文本
    if (typeof r.content === 'string' && !(r.content.startsWith('{') && r.content.endsWith('}'))) return 'text'
    if (o.__text) return 'text'
    const readable = o.text ?? o.content ?? o.message ?? o.body ?? o.label ?? o.title ?? o.name
    if (readable) return 'text'
  }
  return 'other'
}
const kindLabelMap: Record<Kind, string> = {
  text: '文本', image: '图片', file: '文件', voice: '语音', video: '视频', system: '系统',
  call: '语音通话', vcall: '视频通话', redpacket: '红包', transfer: '转账', recall: '已撤回', other: '其他'
}
const kindColorMap: Record<Kind, { bg: string; fg: string; border: string }> = {
  text:       { bg: '#F2F3F5', fg: '#4E5969', border: '#E5E6EB' },
  image:      { bg: '#E8F3FF', fg: '#165DFF', border: '#C7D8FF' },
  file:       { bg: '#FFF7E6', fg: '#AD6800', border: '#FFE4B5' },
  voice:      { bg: '#E8FFEA', fg: '#0A7A36', border: '#C9F7CF' },
  video:      { bg: '#EEF0FF', fg: '#4B3CFF', border: '#D7DCFF' },
  system:     { bg: '#F2F3F5', fg: '#4E5969', border: '#E5E6EB' },
  call:       { bg: '#E6FAFF', fg: '#0A7799', border: '#B6ECFF' },
  vcall:      { bg: '#F4EAFF', fg: '#6222CC', border: '#E0C7FF' },
  redpacket:  { bg: '#FFECE8', fg: '#C73110', border: '#FFD1C7' },
  transfer:   { bg: '#FFF4E5', fg: '#A85B00', border: '#FFD79A' },
  recall:     { bg: '#F2F3F5', fg: '#86909C', border: '#E5E6EB' },
  other:      { bg: '#F2F3F5', fg: '#86909C', border: '#E5E6EB' }
}
function kindLabel(k: Kind) { return kindLabelMap[k] || '其他' }
function kindStyle(k: Kind) {
  const c = kindColorMap[k] || kindColorMap.text
  return { background: c.bg, color: c.fg, borderColor: c.border }
}
function kindChip(k: Kind) { return `m-chip ${k}` }
function kindIcon(k: Kind) {
  const map: Record<Kind, any> = {
    text: undefined, image: undefined, file: IconFile, voice: IconSound, video: IconCamera, system: undefined,
    call: IconPhone, vcall: IconCamera, redpacket: IconFire, transfer: IconGift, recall: undefined, other: undefined
  }
  return map[k] || undefined
}
// 图片来源：优先 content URL 或 JSON 里的图片字段
function imageSrcOf(r: Record<string, any>) {
  if (typeof r.content === 'string' && isImageUrl(r.content)) return r.content
  const o = parseContentObj(r.content ?? r.body ?? r.data ?? '')
  const u = o.url ?? o.imageUrl ?? o.image ?? o.img ?? o.src ?? o.fileUrl ?? o.thumb ?? o.picUrl ?? o.cover
  if (typeof u === 'string' && isImageUrl(u)) return u
  return ''
}
// 时间（秒数）提取
function extractSecOf(o: any): number {
  if (o == null || o === '') return 0
  if (typeof o === 'number') return Math.round(o)
  if (typeof o === 'string' && /^\d+$/.test(o)) return Number(o)
  const obj = parseContentObj(o)
  return Math.round(Number(obj.duration ?? obj.seconds ?? obj.second ?? obj.durationSec ?? 0) || 0)
}
// 金额提取
function amountOf(o: any): number | undefined {
  const obj = parseContentObj(o)
  const v = obj.amount ?? obj.money ?? obj.value ?? obj.price ?? obj.totalAmount
  if (v == null) return undefined
  const n = Number(v)
  if (!isFinite(n)) return undefined
  return n
}
// 通话状态后缀
function callSuffixOf(o: any): string {
  const obj = parseContentObj(o)
  const a = String(obj.action ?? obj.status ?? '').toLowerCase()
  if (a === 'cancel' || a === 'canceled' || a === 'cancelled') return '（已取消）'
  if (a === 'missed') return '（未接听）'
  if (a === 'declined' || a === 'refused' || a === 'reject' || a === 'rejected') return '（已拒绝）'
  return ''
}
// 文本片段截断
function clipText(s: string, n = 40) {
  if (!s) return ''
  return s.length > n ? s.slice(0, n) + '…' : s
}
// 可读内容文本：永不输出 JSON 原串
function displayText(r: Record<string, any>): string {
  const k = kindOf(r)
  const raw = r.content
  const o = parseContentObj(raw ?? r.body ?? r.data ?? '')
  switch (k) {
    case 'text': {
      if (typeof raw === 'string' && !(raw.startsWith('{') && raw.endsWith('}'))) return clipText(raw)
      if (o.__text) return clipText(o.__text)
      const s = String(o.text ?? o.content ?? o.message ?? o.body ?? o.label ?? o.title ?? o.name ?? '')
      return clipText(s) || '文本消息'
    }
    case 'image': {
      const hint = String(o.label ?? o.title ?? o.name ?? o.text ?? '')
      return hint ? `[图片] ${clipText(hint, 20)}` : '[图片]'
    }
    case 'file': {
      const size = o.size != null ? formatSize(o.size) : ''
      const name = String(o.name ?? o.fileName ?? o.filename ?? o.label ?? o.title ?? '文件')
      return size ? `${clipText(name, 24)}  ·  ${size}` : clipText(name, 32)
    }
    case 'voice': return `语音 ${extractSecOf(raw)} 秒`
    case 'video': return `视频 ${extractSecOf(raw)} 秒`
    case 'system': {
      const s = String(o.label ?? o.title ?? o.name ?? o.text ?? o.content ?? o.message ?? '系统消息')
      return clipText(s, 40)
    }
    case 'call':
    case 'vcall': {
      const sec = extractSecOf(raw)
      const suf = callSuffixOf(raw)
      if (sec > 0) return `${sec} 秒${suf}`
      return suf ? suf.slice(1, -1) : '通话'
    }
    case 'redpacket':
    case 'transfer': {
      const amt = amountOf(raw)
      const label = String(o.label ?? o.title ?? o.name ?? o.text ?? o.remark ?? (k === 'redpacket' ? '恭喜发财' : '转账'))
      return amt != null ? `${clipText(label, 12)}  ¥${amt.toFixed(2)}` : clipText(label, 24)
    }
    case 'recall': return '消息已撤回'
    case 'other':
    default: {
      // 其他：绝不再把整个 JSON 直接输出；尝试从 JSON 里取摘要
      if (typeof raw === 'string' && !(raw.startsWith('{') && raw.endsWith('}')) && !(raw.startsWith('[') && raw.endsWith(']'))) {
        return clipText(raw, 24)
      }
      const hints = [o.title, o.label, o.name, o.text, o.content, o.message, o.body, o.remark]
        .map(x => (x != null && x !== '') ? String(x) : '').filter(Boolean)
      if (hints.length) return clipText(hints[0], 28)
      // 特殊判断：action/callType 组合（例如 share）
      const action = String(o.action ?? '')
      const t = String(o.typeName ?? o.type ?? '')
      if (action === 'share') return `分享了${clipText(String(o.title ?? o.desc ?? o.url ?? '链接'), 16)}`
      if (action === 'cancel' && o.callType) return '通话（已取消）'
      if (action === 'missed' && o.callType) return '通话（未接听）'
      if (t) return clipText(t, 16)
      if (action) return clipText(action, 16)
      return '其他消息'
    }
  }
}
function formatSize(n: number): string {
  if (n == null) return ''
  if (n < 1024) return `${n}B`
  if (n < 1024 * 1024) return `${(n / 1024).toFixed(1)}KB`
  return `${(n / 1024 / 1024).toFixed(2)}MB`
}
// 图片悬浮预览备注（hover 时用）
function imgPreview(r: Record<string, any>) {
  const o = parseContentObj(r.extra || r.remark || r.meta || '')
  const hint = String(o.label ?? o.title ?? o.text ?? '')
  return hint ? `${hint}  ·  ${clipText(String(imageSrcOf(r) ?? r.content ?? ''), 30)}` : clipText(String(imageSrcOf(r) ?? r.content ?? ''), 36)
}
function fmt(t?: string) {
  return t ? new Date(t).toLocaleString() : '-'
}

// ===== mock 消息（当后端接口不存在时使用）=====
function buildMockMessages(): Array<Record<string, any>> {
  const users = [
    { id: '100000', nickname: '林墨白', shortId: '10000' },
    { id: '100001', nickname: '苏晚晴', shortId: '10001' },
    { id: '100002', nickname: '陈星河', shortId: '10002' },
    { id: '100003', nickname: '沈逸舟', shortId: '10003' },
    { id: '100004', nickname: '顾长卿', shortId: '10004' },
    { id: '100005', nickname: '江雪柠', shortId: '10005' }
  ]
  const now = Date.now()
  const rows: Array<Record<string, any>> = []
  let id = 88000000
  const mk = (type: number, sender: string, receiver: string, content: any, ts: number, extras?: Record<string, any>) => {
    id++
    rows.push({
      msgId: `M${id}`,
      conversationId: `C${sender}-${receiver}`,
      senderId: sender, receiverId: receiver,
      fromId: sender, toId: receiver,
      type, content: typeof content === 'object' ? JSON.stringify(content) : content,
      createdAt: new Date(ts).toISOString(),
      ...(extras || {})
    })
  }
  // 文本
  mk(1, '100000', '100001', '晚上好，那个方案我已经发到你邮箱了，你有空看一下～', now - 1000 * 60 * 5)
  mk(1, '100001', '100000', '好的，我现在就看', now - 1000 * 60 * 4.5)
  mk(1, '100002', '100003', '会议室定在 5 号 3 楼 302，下午 3 点见', now - 1000 * 60 * 60)
  mk(1, '100003', '100002', '收到～', now - 1000 * 60 * 58)
  // 图片
  mk(2, '100004', '100005', 'https://trae-api-cn.mchost.guru/api/ide/v1/text_to_image?prompt=product%20screenshot%20dashboard&image_size=square', now - 1000 * 60 * 60 * 2)
  mk(2, '100005', '100004', 'https://trae-api-cn.mchost.guru/api/ide/v1/text_to_image?prompt=mobile%20app%20onboarding&image_size=square', now - 1000 * 60 * 60 * 1.9)
  // 文件
  mk(3, '100000', '100002', { label: '项目需求文档 v3.2.docx', size: 1024 * 1024 * 2.4 }, now - 1000 * 60 * 60 * 3)
  // 语音
  mk(4, '100001', '100000', 15, now - 1000 * 60 * 60 * 4)
  mk(4, '100000', '100001', 42, now - 1000 * 60 * 60 * 4 + 20000)
  // 视频
  mk(5, '100003', '100004', 37, now - 1000 * 60 * 60 * 5)
  // 系统
  mk(6, '', '100001', { label: '系统公告：今晚 23:00 系统维护 10 分钟' }, now - 1000 * 60 * 60 * 6)
  // 语音通话 - 三种状态
  mk(10, '100002', '100003', { duration: 580, action: 'over' }, now - 1000 * 60 * 60 * 7)
  mk(10, '100005', '100000', { duration: 0, action: 'cancel' }, now - 1000 * 60 * 60 * 8)
  mk(10, '100004', '100002', { duration: 0, action: 'missed' }, now - 1000 * 60 * 60 * 9)
  // 视频通话
  mk(11, '100001', '100005', { duration: 1230, action: 'over' }, now - 1000 * 60 * 60 * 10)
  // 红包
  mk(20, '100003', '100004', { label: '恭喜发财', amount: 88.88 }, now - 1000 * 60 * 60 * 11)
  mk(20, '100000', '100001', { label: '生日快乐', amount: 188 }, now - 1000 * 60 * 60 * 12)
  // 转账
  mk(21, '100004', '100000', { label: '午餐 AA', amount: 45.5, remark: '昨天的日料' }, now - 1000 * 60 * 60 * 13)
  mk(21, '100005', '100003', { label: '团购收款', amount: 299 }, now - 1000 * 60 * 60 * 14)
  // 撤回
  mk(99, '100002', '100001', '', now - 1000 * 60 * 60 * 15)
  // 群聊：给个简单群聊示例
  id++
  rows.push({
    msgId: `M${id}`,
    conversationId: 'G-产品研发',
    senderId: '100000', receiverId: '',
    fromId: '100000', toId: '',
    group: { name: '产品研发群', memberCount: 18 },
    type: 1,
    content: '各位，周会改到本周五下午 3 点，注意安排时间',
    createdAt: new Date(now - 1000 * 60 * 60 * 16).toISOString()
  })
  id++
  rows.push({
    msgId: `M${id}`,
    conversationId: 'G-产品研发',
    senderId: '100002', receiverId: '',
    fromId: '100002', toId: '',
    group: { name: '产品研发群', memberCount: 18 },
    type: 20,
    content: JSON.stringify({ label: '开工红包', amount: 66.66 }),
    createdAt: new Date(now - 1000 * 60 * 60 * 16 + 60000).toISOString()
  })
  // 未知类型
  mk(7, '100001', '100002', { action: 'share', title: '分享了一篇文章：2026 前端趋势' }, now - 1000 * 60 * 60 * 20)

  return rows.sort((a, b) => +new Date(b.createdAt) - +new Date(a.createdAt))
}

// 显式避免未使用警告
void markRaw
</script>

<style scoped>
.toolbar { display: flex; gap: 12px; margin-bottom: 16px; flex-wrap: wrap; }
.msg-thumb { border-radius: var(--app-radius-sm); border: 1px solid var(--app-border-2); cursor: pointer; }

.peer-cell { display: flex; align-items: center; gap: 8px; min-width: 0; }
.peer-avatar {
  width: 30px; height: 30px; border-radius: 50%;
  display: inline-flex; align-items: center; justify-content: center;
  color: #fff; font-size: 12px; font-weight: 600; flex-shrink: 0;
}
.peer-avatar.group { font-size: 13px; border-radius: 8px; }
.peer-info { display: flex; flex-direction: column; gap: 2px; min-width: 0; max-width: 100%; }
.peer-nick { font-size: 13px; color: var(--app-text-1); font-weight: 500; line-height: 1.2; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.peer-sub { font-size: 11px; color: var(--app-text-3); line-height: 1.2; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; font-family: ui-monospace, Menlo, Consolas, monospace; }
.group-sub { color: var(--app-primary); font-family: inherit; }

.c-body {
  display: flex; align-items: center; gap: 8px;
  min-height: 40px; max-width: 100%; flex-wrap: wrap;
}
.type-tag {
  display: inline-flex; align-items: center;
  padding: 2px 8px;
  border-radius: 10px;
  border: 1px solid;
  font-size: 11px; line-height: 1.4;
  font-weight: 500;
  flex-shrink: 0;
}
.c-text { max-width: 520px; white-space: normal; word-break: break-word; line-height: 1.5; }
.c-img-wrap { display: inline-flex; align-items: center; gap: 8px; }

.m-chip {
  display: inline-flex; align-items: center; gap: 6px;
  padding: 4px 10px; border-radius: 16px;
  background: var(--app-fill-2, #f5f7fa); color: var(--app-text-1, #232a3a);
  border: 1px solid var(--app-border-2, #e5e7eb); font-size: 12px; line-height: 1;
}
.m-chip :deep(svg) { width: 14px; height: 14px; }
.m-chip.file { background: #fff7e6; border-color: #ffe4b5; color: #ad6800; }
.m-chip.voice { background: #e8ffea; border-color: #c9f7cf; color: #0a7a36; }
.m-chip.video { background: #eef0ff; border-color: #d7dcff; color: #4b3cff; }
.m-chip.system { background: #f5f7fa; border-color: #e5e7eb; color: #4e5969; }
.m-chip.call { background: #e6faff; border-color: #b6ecff; color: #0a7799; }
.m-chip.vcall { background: #f4eaff; border-color: #e0c7ff; color: #6222cc; }
.m-chip.redpacket { background: #ffece8; border-color: #ffd1c7; color: #c73110; }
.m-chip.transfer { background: #fff4e5; border-color: #ffd79a; color: #a85b00; }
.m-chip.recall { background: #f5f7fa; color: #86909c; }
.muted { color: var(--app-text-3); }
</style>
