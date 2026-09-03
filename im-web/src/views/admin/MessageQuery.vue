<template>
  <div class="page">
    <a-card>
      <div class="toolbar">
        <a-input-search v-model="query.kw" placeholder="按消息内容搜索" style="width: 240px" allow-clear @search="load(1)" />
        <a-select v-model="query.type" placeholder="消息类型" allow-clear style="width: 150px">
          <a-option v-for="(label, v) in typeMap" :key="v" :value="Number(v)">{{ label }}</a-option>
        </a-select>
        <a-date-picker v-model="dateRange" type="daterange" value-format="YYYY-MM-DD" style="width: 260px" />
        <a-button type="primary" @click="load(1)">查询</a-button>
      </div>

      <a-table :data="list" row-key="msgId" :pagination="pagination" :loading="loading" @page-change="load" :scroll="{ x: 1280 }">
        <template #columns>
          <a-table-column title="消息ID" :width="180">
            <template #cell="{ record }">
              <span class="msg-id">{{ record.msgId }}</span>
            </template>
          </a-table-column>
          <a-table-column title="发送者" :width="190">
            <template #cell="{ record }">
              <div class="peer-cell">
                <a-avatar :size="30" :image-url="record.senderAvatar || undefined" class="peer-avatar-fallback" :style="!record.senderAvatar ? { background: peerColor(record.senderId) } : {}">
                  {{ firstChar(record.senderName) }}
                </a-avatar>
                <div class="peer-info">
                  <span class="peer-nick">
                    {{ record.senderName || '未知' }}
                    <a-tag v-if="String(record.senderId) === '-1'" color="orangered" size="small" class="official-tag">官方</a-tag>
                  </span>
                  <span class="peer-sub">{{ record.senderShortId ? '#' + record.senderShortId : (record.senderId ?? '—') }}</span>
                </div>
              </div>
            </template>
          </a-table-column>
          <a-table-column title="接收者" :width="190">
            <template #cell="{ record }">
              <div class="peer-cell">
                <a-avatar :size="30" :image-url="record.receiverAvatar || undefined" :style="!record.receiverAvatar ? { background: peerColor(record.receiverId) } : {}">
                  <template v-if="isGroupMsg(record)"><IconUserGroup /></template>
                  <template v-else>{{ firstChar(record.receiverName) }}</template>
                </a-avatar>
                <div class="peer-info">
                  <span class="peer-nick">{{ record.receiverName || '未知' }}</span>
                  <span class="peer-sub" :class="{ 'group-sub': isGroupMsg(record) }">
                    {{ isGroupMsg(record) ? '群聊' : (record.receiverShortId ? '#' + record.receiverShortId : (record.receiverId || '—')) }}
                  </span>
                </div>
              </div>
            </template>
          </a-table-column>
          <a-table-column title="内容" ellipsis>
            <template #cell="{ record }">
              <div class="c-body">
                <span class="type-tag" :style="kindStyle(kindOf(record))">{{ kindLabel(kindOf(record)) }}</span>
                <a-image
                  v-if="kindOf(record) === 'image' && imageSrcOf(record)"
                  :src="imageSrcOf(record)"
                  width="42" height="42" fit="cover"
                  class="msg-thumb"
                  :preview-src-list="[imageSrcOf(record)]"
                />
                <span v-else-if="kindOf(record) === 'image'" class="muted">[图片]</span>
                <span v-else-if="kindOf(record) === 'text'" class="c-text">{{ displayText(record) }}</span>
                <div v-else class="m-chip">
                  <span>{{ displayText(record) }}</span>
                </div>
                <a-tag v-if="record.blocked" color="red" size="small">已屏蔽</a-tag>
              </div>
            </template>
          </a-table-column>
          <a-table-column title="时间" :width="165">
            <template #cell="{ record }">{{ fmt(record.createdAt) }}</template>
          </a-table-column>
          <a-table-column title="操作" :width="170" align="center" :fixed="'right'">
            <template #cell="{ record }">
              <a-space size="mini">
                <a-button size="mini" type="text" @click="openConv(record)">查看会话</a-button>
                <a-popconfirm
                  :content="record.blocked ? '确定恢复显示该消息？' : '确定屏蔽该消息？屏蔽后用户端将不再显示'"
                  type="warning"
                  @ok="toggleBlock(record)"
                >
                  <a-button size="mini" type="text" :status="record.blocked ? 'normal' : 'danger'">
                    {{ record.blocked ? '恢复' : '屏蔽' }}
                  </a-button>
                </a-popconfirm>
              </a-space>
            </template>
          </a-table-column>
        </template>
        <template #empty>
          <a-empty description="暂无消息记录" />
        </template>
      </a-table>
    </a-card>

    <!-- 查看会话弹窗（聊天窗口样式） -->
    <a-modal v-model:visible="convVisible" :title="convTitle" :width="640" :footer="false" unmount-on-close>
      <div ref="convScroll" class="conv-window" @scroll="onConvScroll">
        <a-spin v-if="convLoading" class="conv-spin" />
        <template v-for="m in convList" :key="m.msgId">
          <div class="conv-day" v-if="m.__day">{{ m.__day }}</div>
          <div class="conv-row" :class="{ mine: isMine(m) }">
            <a-avatar :size="34" :image-url="m.senderAvatar || undefined" :style="!m.senderAvatar ? { background: peerColor(m.senderId) } : {}">
              {{ firstChar(m.senderName) }}
            </a-avatar>
            <div class="conv-bubble-wrap">
              <div class="conv-sender">{{ m.senderName || '未知' }}<a-tag v-if="String(m.senderId) === '-1'" color="orangered" size="small" class="official-tag">官方</a-tag></div>
              <div class="conv-bubble">
                <a-image v-if="kindOf(m) === 'image' && imageSrcOf(m)" :src="imageSrcOf(m)" width="180" fit="cover" :preview-src-list="[imageSrcOf(m)]" />
                <template v-else>{{ displayText(m) }}</template>
              </div>
              <div class="conv-time">{{ fmt(m.createdAt) }}<a-tag v-if="m.blocked" color="red" size="small" class="blocked-tag">已屏蔽</a-tag></div>
            </div>
          </div>
        </template>
        <a-empty v-if="!convLoading && !convList.length" description="该会话暂无消息" />
      </div>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, watch, nextTick } from 'vue'
import { Message } from '@arco-design/web-vue'
import { IconUserGroup } from '@arco-design/web-vue/es/icon'
import { adminApi } from '@/api/admin'

const list = ref<Array<Record<string, any>>>([])
const loading = ref(false)
const dateRange = ref<Array<string | number> | undefined>(undefined)
const query = reactive({ kw: '', type: undefined as number | undefined })
const pagination = reactive({ current: 1, pageSize: 20, total: 0, showTotal: true })

// 消息类型（服务端 type 字段；含历史遗留值）
const typeMap: Record<number, string> = {
  1: '文本', 2: '图片', 3: '文件', 4: '语音', 5: '视频',
  6: '系统', 7: '语音通话', 8: '红包', 9: '转账',
  10: '语音通话(旧)', 11: '视频通话(旧)', 20: '红包(旧)', 21: '转账(旧)', 99: '撤回'
}

onMounted(() => load(1))
watch(dateRange, () => load(1))
watch(() => query.type, () => load(1))

async function load(page = pagination.current) {
  loading.value = true
  try {
    const [from, to] = dateRange.value?.length
      ? [new Date(dateRange.value[0] as string).getTime(), new Date(dateRange.value[1] as string).getTime() + 86399999]
      : [0, 0]
    const { data } = await adminApi.messages({ ...query, from, to, page, size: pagination.pageSize })
    if (data?.code !== 0) { Message.error(data?.message || '查询失败'); return }
    list.value = data.data?.list || []
    pagination.total = data.data?.total || 0
    pagination.current = page
  } catch (e: any) {
    Message.error('查询失败：' + (e?.message || ''))
  } finally {
    loading.value = false
  }
}

// ===== 屏蔽 / 恢复 =====
async function toggleBlock(row: Record<string, any>) {
  try {
    const { data } = await adminApi.messageBlock(String(row.msgId), !row.blocked)
    if (data?.code !== 0) { Message.error(data?.message || '操作失败'); return }
    row.blocked = !row.blocked
    Message.success(row.blocked ? '已屏蔽，用户端不再显示该消息' : '已恢复显示')
  } catch (e: any) {
    Message.error('操作失败：' + (e?.message || ''))
  }
}

// ===== 查看会话 =====
const convVisible = ref(false)
const convLoading = ref(false)
const convList = ref<Array<Record<string, any>>>([])
const convTitle = ref('会话消息')
// 打开会话时来源行的接收者（单聊）：作为聊天窗口右侧「我方」视角
const convMineId = ref('')
const convScroll = ref<HTMLElement>()
const convTotal = ref(0)
const convPage = ref(1)
let convConvId = ''

function openConv(row: Record<string, any>) {
  convConvId = String(row.conversationId || '')
  if (!convConvId) { Message.warning('缺少会话 ID'); return }
  convTitle.value = `会话消息 · ${row.convName || row.conversationId}`
  // 单聊以该条消息的接收者为右侧视角；群聊 convMineId 置空（全部左侧显示）
  convMineId.value = isGroupMsg(row) ? '' : String(row.receiverId || '')
  convList.value = []
  convTotal.value = 0
  convPage.value = 1
  convVisible.value = true
  loadConv()
}

async function loadConv() {
  if (!convConvId) return
  convLoading.value = true
  try {
    const { data } = await adminApi.messages({ convId: convConvId, page: convPage.value, size: 50 })
    if (data?.code !== 0) { Message.error(data?.message || '读取会话消息失败'); return }
    const rows = (data.data?.list || []) as Array<Record<string, any>>
    convTotal.value = data.data?.total || 0
    // 接口按 msgId 倒序返回，正序展示；标记日期分组
    rows.forEach((m) => {
      const d = m.createdAt ? new Date(m.createdAt) : null
      m.__day = d ? `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}` : ''
    })
    rows.reverse()
    convList.value = [...rows, ...convList.value]
    await nextTick()
    scrollToBottom()
  } finally {
    convLoading.value = false
  }
}

function onConvScroll() {
  const el = convScroll.value
  if (!el || convLoading.value) return
  // 顶部滚动加载更早消息
  if (el.scrollTop < 60 && convList.value.length < convTotal.value) {
    convPage.value++
    loadConv().then(() => { if (el.scrollTop < 10) el.scrollTop = 10 })
  }
}

function scrollToBottom() {
  const el = convScroll.value
  if (el) el.scrollTop = el.scrollHeight
}

function isMine(m: Record<string, any>) {
  return convMineId.value !== '' && String(m.senderId) === convMineId.value
}

// ===== 通用渲染 helper =====
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
function isGroupMsg(r: Record<string, any>) {
  return Number(r.convType) === 2
}
function fmt(t?: string) {
  return t ? new Date(t).toLocaleString() : '-'
}

// ===== 内容解析（服务端真实 type 字段优先）=====
type Kind = 'text' | 'image' | 'file' | 'voice' | 'video' | 'system' | 'call' | 'vcall' | 'redpacket' | 'transfer' | 'recall' | 'other'
const kindMap: Record<number, Kind> = {
  1: 'text', 2: 'image', 3: 'file', 4: 'voice', 5: 'video', 6: 'system',
  7: 'call', 10: 'call', 11: 'vcall', 8: 'redpacket', 20: 'redpacket',
  9: 'transfer', 21: 'transfer', 99: 'recall'
}
function kindOf(r: Record<string, any>): Kind {
  return kindMap[Number(r.type)] || 'other'
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

function parseContentObj(v: any): Record<string, any> {
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
function imageSrcOf(r: Record<string, any>) {
  if (typeof r.content === 'string' && isImageUrl(r.content)) return r.content
  // 图片消息：file 字段 { url, ... }
  const f = r.file || {}
  const fu = f.url ?? f.fileUrl ?? ''
  if (typeof fu === 'string' && fu) return fu
  const o = parseContentObj(r.content)
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
function displayText(r: Record<string, any>): string {
  const k = kindOf(r)
  const raw = r.content
  const o = parseContentObj(raw)
  switch (k) {
    case 'text': {
      if (typeof raw === 'string' && !(raw.startsWith('{') && raw.endsWith('}'))) return raw
      return clipText(String(o.__text ?? o.text ?? o.content ?? ''))
    }
    case 'image': return '[图片]'
    case 'file': {
      const f = r.file || {}
      const name = String(f.name ?? o.name ?? o.fileName ?? '文件')
      const size = f.size ?? o.size
      return size ? `${clipText(name, 24)} · ${formatSize(Number(size))}` : clipText(name, 32)
    }
    case 'voice': return `语音 ${extractSecOf(raw)} 秒`
    case 'video': return `视频 ${extractSecOf(raw)} 秒`
    case 'system': return clipText(String(o.__text ?? o.text ?? o.label ?? '系统消息'), 50)
    case 'call':
    case 'vcall': {
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
</script>

<style scoped>
.toolbar { display: flex; gap: 12px; margin-bottom: 16px; flex-wrap: wrap; }
.msg-thumb { border-radius: var(--app-radius-sm); border: 1px solid var(--app-border-2); cursor: pointer; }
.msg-id { font-family: ui-monospace, Menlo, Consolas, monospace; font-size: 12px; color: var(--app-text-2); }

.peer-cell { display: flex; align-items: center; gap: 8px; min-width: 0; }
.peer-avatar-fallback { flex-shrink: 0; }
.peer-info { display: flex; flex-direction: column; gap: 2px; min-width: 0; max-width: 100%; }
.peer-nick { font-size: 13px; color: var(--app-text-1); font-weight: 500; line-height: 1.2; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; display: flex; align-items: center; gap: 4px; }
.official-tag { flex-shrink: 0; transform: scale(0.85); margin-left: 2px; }
.peer-sub { font-size: 11px; color: var(--app-text-3); line-height: 1.2; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; font-family: ui-monospace, Menlo, Consolas, monospace; }
.group-sub { color: var(--app-primary); font-family: inherit; }

.c-body { display: flex; align-items: center; gap: 8px; min-height: 40px; max-width: 100%; flex-wrap: wrap; }
.type-tag { display: inline-flex; align-items: center; padding: 2px 8px; border-radius: 10px; border: 1px solid; font-size: 11px; line-height: 1.4; font-weight: 500; flex-shrink: 0; }
.c-text { max-width: 420px; white-space: normal; word-break: break-word; line-height: 1.5; }
.m-chip { display: inline-flex; align-items: center; gap: 6px; padding: 4px 10px; border-radius: 16px; background: var(--app-fill-2, #f5f7fa); color: var(--app-text-1, #232a3a); border: 1px solid var(--app-border-2, #e5e7eb); font-size: 12px; line-height: 1.4; }
.muted { color: var(--app-text-3); }

/* ===== 查看会话弹窗 ===== */
.conv-window {
  height: 460px; overflow-y: auto;
  background: var(--app-fill-1, #f7f8fa);
  border-radius: 8px; padding: 16px;
  display: flex; flex-direction: column; gap: 14px;
}
.conv-spin { margin: 0 auto; }
.conv-day { text-align: center; font-size: 11px; color: var(--app-text-3); }
.conv-row { display: flex; gap: 10px; align-items: flex-start; }
.conv-row.mine { flex-direction: row-reverse; }
.conv-bubble-wrap { display: flex; flex-direction: column; gap: 4px; max-width: 70%; }
.conv-row.mine .conv-bubble-wrap { align-items: flex-end; }
.conv-sender { font-size: 11px; color: var(--app-text-3); display: flex; align-items: center; gap: 4px; }
.blocked-tag { margin-left: 4px; }
.conv-bubble {
  background: #fff; border: 1px solid var(--app-border-2, #e5e7eb);
  border-radius: 4px 12px 12px 12px; padding: 8px 12px;
  font-size: 13px; line-height: 1.55; color: var(--app-text-1);
  word-break: break-word; white-space: pre-wrap;
}
.conv-row.mine .conv-bubble { background: var(--app-primary-bg, #e8f3ff); border-color: transparent; border-radius: 12px 4px 12px 12px; }
.conv-time { font-size: 10.5px; color: var(--app-text-4, #c9cdd4); }
</style>
