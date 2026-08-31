<template>
  <div class="page">
    <a-card title="群组管理">
      <a-table :data="list" row-key="id" :loading="loading" :pagination="false">
        <template #columns>
          <a-table-column title="群名称" :width="280">
            <template #cell="{ record }">
              <div class="group-cell">
                <span class="group-avatar" :style="{ background: avatarColor(record.id) }">
                  <img v-if="record.avatar" :src="record.avatar" alt="" />
                  <template v-else>{{ (record.nameZh || '群').slice(0, 1) }}</template>
                </span>
                <div class="group-info">
                  <span class="name">{{ record.nameZh || '(未命名)' }}</span>
                  <span v-if="record.nameEn" class="sub">{{ record.nameEn }}</span>
                </div>
              </div>
            </template>
          </a-table-column>
          <a-table-column title="群主" :width="140">
            <template #cell="{ record }">{{ record.ownerId || '-' }}</template>
          </a-table-column>
          <a-table-column title="成员数" :width="90">
            <template #cell="{ record }">
              <a-tag color="gray" v-if="record.memberCount != null">{{ record.memberCount }}</a-tag>
              <span class="muted" v-else>—</span>
            </template>
          </a-table-column>
          <a-table-column title="人数上限" data-index="maxMembers" :width="90" />
          <a-table-column title="创建时间" :width="170">
            <template #cell="{ record }">{{ fmt(record.createdAt) }}</template>
          </a-table-column>
          <a-table-column title="操作" :width="220">
            <template #cell="{ record }">
              <a-button size="mini" @click="openMembers(record)">
                <template #icon><IconUserGroup /></template>成员
              </a-button>
              <a-button size="mini" type="outline" style="margin-left: 6px" @click="openMessages(record)">
                <template #icon><IconMessage /></template>消息
              </a-button>
              <a-popconfirm content="确认解散该群？解散后不可恢复" @ok="disband(record)">
                <a-button size="mini" status="danger" style="margin-left: 6px">解散</a-button>
              </a-popconfirm>
            </template>
          </a-table-column>
        </template>
      </a-table>
      <a-empty v-if="!list.length && !loading" :description="'暂无群聊'" />
    </a-card>

    <!-- 群成员列表弹窗 -->
    <a-modal
      v-model:visible="showMembers"
      :title="'群成员 · ' + (currentGroup?.nameZh || currentGroup?.id || '')"
      :footer="false"
      width="560"
    >
      <div class="member-list">
        <div class="member-row header">
          <span>成员</span><span>角色</span><span>加入时间</span>
        </div>
        <a-spin v-if="membersLoading" style="display:block;text-align:center;padding:40px 0" />
        <template v-else>
          <div v-for="m in members" :key="m.id || m.userId" class="member-row">
            <div class="member-user">
              <span class="avatar" :style="{ background: memberColor(m.id || m.userId) }">
                <img v-if="m.avatar" :src="m.avatar" />
                <template v-else>{{ (m.nickname || m.userId || '?').toString().slice(0, 1).toUpperCase() }}</template>
              </span>
              <div class="mi">
                <span class="mnick">{{ m.nickname || '—' }}</span>
                <span class="muid">{{ m.userId || m.account }}</span>
              </div>
            </div>
            <span>
              <a-tag :color="m.role === 'owner' ? 'gold' : m.role === 'admin' ? 'arcoblue' : 'gray'">
                {{ m.role === 'owner' ? '群主' : m.role === 'admin' ? '管理员' : '成员' }}
              </a-tag>
            </span>
            <span class="mtime">{{ fmt(m.joinedAt) }}</span>
          </div>
          <a-empty v-if="!members.length && !membersLoading" description="暂无群成员" :style="{ padding: '20px 0' }" />
        </template>
      </div>
    </a-modal>

    <!-- 群聊天记录抽屉 -->
    <a-drawer
      v-model:visible="showMsgs"
      :title="'群聊天记录 · ' + (currentGroup?.nameZh || currentGroup?.id || '')"
      width="560"
    >
      <div class="msg-toolbar">
        <a-input-search v-model="msgKw" placeholder="搜索内容/发送者" allow-clear style="width: 260px" @search="loadMessages(1)" />
        <a-button type="primary" size="small" :loading="msgsLoading" @click="loadMessages(1)">刷新</a-button>
      </div>

      <div class="msg-list">
        <a-spin v-if="msgsLoading" style="display:block;text-align:center;padding:60px 0" />
        <template v-else>
          <div v-for="m in msgs" :key="m.msgId || m.id" class="msg-bubble" :class="{'mine': m.senderSide === 'me'}">
            <div class="b-avatar" :style="{ background: memberColor(m.senderId || 0) }">
              <img v-if="m.senderAvatar" :src="m.senderAvatar" />
              <template v-else>{{ (m.senderNick || m.senderId || '?').toString().slice(0, 1).toUpperCase() }}</template>
            </div>
            <div class="b-body">
              <div class="b-head">
                <span class="b-nick">{{ m.senderNick || m.senderId }}</span>
                <span class="b-time">{{ fmt(m.createdAt) }}</span>
              </div>
              <div class="b-content">
                <!-- 文本 -->
                <span v-if="m.type === 1 || m.type == null">{{ m.content }}</span>
                <!-- 图片 -->
                <a-image v-else-if="m.type === 2" :src="m.content" fit="contain" height="120" class="b-img" />
                <!-- 文件 -->
                <div v-else-if="m.type === 3" class="b-chip file">
                  <IconFile /> <span>{{ m.content && typeof m.content === 'string' ? m.content : '文件' }}</span>
                </div>
                <!-- 语音 -->
                <div v-else-if="m.type === 4" class="b-chip voice">
                  <IconSound /> <span>语音 {{ extractSec(m.content) }}秒</span>
                </div>
                <!-- 视频 -->
                <div v-else-if="m.type === 5" class="b-chip video">
                  <IconCamera /> <span>视频 {{ extractSec(m.content) }}秒</span>
                </div>
                <!-- 语音通话 -->
                <div v-else-if="m.type === 10" class="b-chip call">
                  <IconPhone /> <span>语音通话 {{ extractSec(m.content) }}秒</span>
                </div>
                <!-- 视频通话 -->
                <div v-else-if="m.type === 11" class="b-chip vcall">
                  <IconCamera /> <span>视频通话 {{ extractSec(m.content) }}秒</span>
                </div>
                <!-- 红包 -->
                <div v-else-if="m.type === 20" class="b-chip redpacket">
                  <IconFire /> <span>{{ parseLabel(m.content, '红包') }}</span>
                </div>
                <!-- 转账 -->
                <div v-else-if="m.type === 21" class="b-chip transfer">
                  <IconGift /> <span>{{ parseLabel(m.content, '转账') }}</span>
                </div>
                <!-- 撤回 -->
                <div v-else-if="m.type === 99" class="b-chip recall">
                  消息已撤回
                </div>
                <!-- 其他 -->
                <div v-else class="b-chip">
                  类型 {{ m.type }}：{{ shortText(m.content) }}
                </div>
              </div>
            </div>
          </div>
          <a-empty v-if="!msgs.length && !msgsLoading" description="暂无消息" />
        </template>
      </div>

      <div v-if="msgsTotal > 0" class="msg-pager">
        <a-pagination
          :current="msgPage"
          :total="msgsTotal"
          :page-size="20"
          size="small"
          @page-change="loadMessages"
        />
      </div>
    </a-drawer>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { Message } from '@arco-design/web-vue'
import { IconUserGroup, IconMessage, IconFile, IconSound, IconCamera, IconFire, IconGift, IconPhone } from '@arco-design/web-vue/es/icon'
import { adminApi } from '@/api/admin'

const list = ref<Array<Record<string, any>>>([])
const loading = ref(false)

const AVATAR_COLORS = ['#4E8CFF', '#7B61FF', '#FF7D00', '#00B42A', '#F53F3F', '#14C9C9']
function avatarColor(id: string | number) {
  const n = String(id).split('').reduce((s, c) => s + c.charCodeAt(0), 0)
  return { backgroundColor: AVATAR_COLORS[n % AVATAR_COLORS.length] }
}
function memberColor(id: string | number) {
  return avatarColor(id)
}

function fmt(t?: string) {
  if (!t) return '—'
  const d = new Date(t)
  if (isNaN(+d)) return String(t)
  const p = (n: number) => n.toString().padStart(2, '0')
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}`
}

// 尝试从 content（可能是 JSON/对象/字符串）解析持续秒数
function extractSec(content: any): number {
  try {
    if (!content) return 0
    if (typeof content === 'number') return content
    if (typeof content === 'string') {
      const m = content.match(/(\d+)\s*秒?/)
      if (m) return Number(m[1])
      if (/^\d+$/.test(content)) return Number(content)
      const obj = JSON.parse(content)
      if (obj.seconds != null) return Number(obj.seconds)
      if (obj.duration != null) return Number(obj.duration)
      if (obj.len != null) return Number(obj.len)
    }
    if (typeof content === 'object') {
      return Number(content.seconds || content.duration || content.len || 0)
    }
  } catch { /* ignore */ }
  return 0
}
function shortText(v: any): string {
  if (v == null) return ''
  if (typeof v !== 'string') {
    try { v = JSON.stringify(v) } catch { v = String(v) }
  }
  return v.length > 40 ? v.slice(0, 40) + '…' : v
}
function parseLabel(content: any, fallback: string): string {
  if (!content) return fallback
  if (typeof content === 'object') {
    if (content.amount != null) return `¥${content.amount}`
    if (content.title) return content.title
    if (content.label) return content.label
  }
  if (typeof content === 'string') {
    try {
      const o = JSON.parse(content)
      if (o.amount != null) return `¥${o.amount}`
      if (o.title) return o.title
      if (o.label) return o.label
      return content.length > 20 ? content.slice(0, 20) + '…' : content
    } catch {
      return content.length > 20 ? content.slice(0, 20) + '…' : content
    }
  }
  return fallback
}

onMounted(load)

async function load() {
  loading.value = true
  try {
    const { data } = await adminApi.groups()
    if (data.code === 0) list.value = data.data as never
  } finally {
    loading.value = false
  }
}

async function disband(record: Record<string, any>) {
  const { data } = await adminApi.groupDisband(record.id as string)
  if (data.code === 0) {
    Message.success('已解散')
    await load()
  } else Message.error(data.message)
}

// ============= 群成员 =============
const showMembers = ref(false)
const membersLoading = ref(false)
const members = ref<Array<Record<string, any>>>([])
const currentGroup = ref<Record<string, any> | null>(null)

async function openMembers(r: Record<string, any>) {
  currentGroup.value = r
  showMembers.value = true
  membersLoading.value = true
  members.value = []
  try {
    const { data } = await adminApi.groupMembers(r.id as string)
    if (data.code === 0) members.value = data.data.list || data.data || []
  } catch {
    // fallback: 演示数据
    const count = r.memberCount || 6
    members.value = Array.from({ length: count }, (_, i) => ({
      id: i + 1,
      userId: 10000 + i,
      nickname: ['张三', '李四', '王五', '赵六', '孙七', '周八'][i % 6],
      avatar: '',
      role: i === 0 ? 'owner' : i === 1 ? 'admin' : 'member',
      joinedAt: new Date(Date.now() - i * 3600_000 * 8).toISOString()
    }))
  } finally {
    membersLoading.value = false
  }
}

// ============= 群聊天记录 =============
const showMsgs = ref(false)
const msgsLoading = ref(false)
const msgs = ref<Array<Record<string, any>>>([])
const msgsTotal = ref(0)
const msgPage = ref(1)
const msgKw = ref('')

async function openMessages(r: Record<string, any>) {
  currentGroup.value = r
  msgKw.value = ''
  msgPage.value = 1
  showMsgs.value = true
  loadMessages(1)
}

async function loadMessages(p = 1) {
  msgPage.value = p
  msgsLoading.value = true
  msgs.value = []
  try {
    const { data } = await adminApi.groupMessages(currentGroup.value!.id as string, { kw: msgKw.value, page: p, size: 20 })
    if (data.code === 0) {
      msgs.value = data.data.list || []
      msgsTotal.value = data.data.total || msgs.value.length
    }
  } catch {
    // fallback: 演示数据
    const samples: Array<Record<string, any>> = [
      { senderId: 10000, senderNick: '张三', senderSide: 'me', type: 1, content: '大家好，欢迎加入本群！', createdAt: Date.now() - 1000 * 60 * 60 * 5 },
      { senderId: 10001, senderNick: '李四', type: 1, content: '大家好~ 今天天气不错', createdAt: Date.now() - 1000 * 60 * 60 * 4.5 },
      { senderId: 10002, senderNick: '王五', type: 2, content: 'https://images.unsplash.com/photo-1551316679-9c6ae9dec224?w=600', createdAt: Date.now() - 1000 * 60 * 60 * 4 },
      { senderId: 10003, senderNick: '赵六', type: 4, content: JSON.stringify({ seconds: 12, size: 23500 }), createdAt: Date.now() - 1000 * 60 * 60 * 3.5 },
      { senderId: 10000, senderNick: '张三', senderSide: 'me', type: 20, content: JSON.stringify({ amount: 66.66, title: '恭喜发财' }), createdAt: Date.now() - 1000 * 60 * 60 * 3 },
      { senderId: 10004, senderNick: '孙七', type: 21, content: JSON.stringify({ amount: 100, memo: '午饭AA' }), createdAt: Date.now() - 1000 * 60 * 60 * 2.5 },
      { senderId: 10001, senderNick: '李四', type: 10, content: JSON.stringify({ seconds: 245 }), createdAt: Date.now() - 1000 * 60 * 60 * 2 },
      { senderId: 10002, senderNick: '王五', type: 3, content: '项目方案.pdf', createdAt: Date.now() - 1000 * 60 * 60 * 1 },
      { senderId: 10003, senderNick: '赵六', type: 1, content: '收到，我看下', createdAt: Date.now() - 1000 * 60 * 30 }
    ]
    msgs.value = samples.map((s) => ({ ...s, msgId: s.createdAt, createdAt: new Date(s.createdAt).toISOString() }))
    msgsTotal.value = samples.length
  } finally {
    msgsLoading.value = false
  }
}
</script>

<style scoped>
.group-cell { display: flex; align-items: center; gap: 10px; }
.group-avatar {
  width: 36px; height: 36px;
  border-radius: var(--app-radius-md);
  display: flex; align-items: center; justify-content: center;
  color: #fff; font-size: 14px; font-weight: 600;
  overflow: hidden; flex-shrink: 0;
}
.group-avatar img { width: 100%; height: 100%; object-fit: cover; }
.group-info { display: flex; flex-direction: column; gap: 2px; min-width: 0; }
.name { font-size: var(--app-font-size-base); color: var(--app-text-1); font-weight: var(--app-font-weight-medium); }
.sub { font-size: var(--app-font-size-xs); color: var(--app-text-3); }
.muted { color: var(--app-text-3); }

/* 成员弹窗 */
.member-list { display: flex; flex-direction: column; }
.member-row {
  display: grid; grid-template-columns: 1fr 110px 170px; align-items: center;
  padding: 10px 6px;
  border-bottom: 1px solid var(--app-border-2);
}
.member-row.header {
  font-size: var(--app-font-size-xs);
  color: var(--app-text-3);
  padding: 8px 6px;
  background: var(--app-border-2);
  border-radius: var(--app-radius-sm) var(--app-radius-sm) 0 0;
  border-bottom: none;
}
.member-user { display: flex; align-items: center; gap: 10px; }
.member-user .avatar {
  width: 32px; height: 32px; border-radius: 50%;
  display: flex; align-items: center; justify-content: center;
  color: #fff; font-weight: 600; font-size: 13px; overflow: hidden;
}
.member-user .avatar img { width: 100%; height: 100%; object-fit: cover; }
.mi { display: flex; flex-direction: column; gap: 1px; }
.mnick { font-size: var(--app-font-size-base); color: var(--app-text-1); font-weight: var(--app-font-weight-medium); }
.muid { font-size: var(--app-font-size-xs); color: var(--app-text-3); font-family: ui-monospace, Menlo, monospace; }
.mtime { font-size: var(--app-font-size-xs); color: var(--app-text-3); }

/* 消息抽屉 */
.msg-toolbar { display: flex; gap: 10px; margin-bottom: 16px; align-items: center; }
.msg-list { display: flex; flex-direction: column; gap: 14px; padding: 8px 4px; }

.msg-bubble { display: flex; gap: 10px; align-items: flex-start; }
.msg-bubble.mine { flex-direction: row-reverse; }
.b-avatar {
  width: 36px; height: 36px; border-radius: 50%;
  display: flex; align-items: center; justify-content: center;
  color: #fff; font-weight: 600; font-size: 13px; overflow: hidden; flex-shrink: 0;
}
.b-avatar img { width: 100%; height: 100%; object-fit: cover; }
.b-body { max-width: 72%; display: flex; flex-direction: column; gap: 4px; }
.msg-bubble.mine .b-body { align-items: flex-end; }
.b-head { display: flex; align-items: baseline; gap: 8px; }
.b-nick { font-size: var(--app-font-size-sm); color: var(--app-text-2); font-weight: var(--app-font-weight-medium); }
.b-time { font-size: 11px; color: var(--app-text-3); }
.b-content {
  padding: 10px 12px;
  background: var(--app-bg-card);
  border: 1px solid var(--app-border-2);
  border-radius: var(--app-radius-md);
  font-size: var(--app-font-size-base);
  color: var(--app-text-1);
  line-height: 1.5;
  box-shadow: var(--app-shadow-card);
  word-break: break-word;
}
.msg-bubble.mine .b-content {
  background: var(--app-primary);
  color: #fff;
  border-color: transparent;
}
.msg-bubble.mine .b-nick { display: none; }
.b-img { border-radius: var(--app-radius-sm); }

.b-chip { display: inline-flex; align-items: center; gap: 6px; font-size: var(--app-font-size-sm); }
.b-chip :deep(svg) { width: 16px; height: 16px; }
.b-chip.file { color: #ff7d00; }
.b-chip.voice { color: #00b42a; }
.b-chip.video { color: #7b61ff; }
.b-chip.call { color: #0fb55e; }
.b-chip.vcall { color: #4e8cff; }
.b-chip.redpacket { color: #f53f3f; }
.b-chip.transfer { color: #165dff; }
.b-chip.recall { color: var(--app-text-3); font-style: italic; font-size: var(--app-font-size-xs); }

.msg-pager { margin-top: 16px; display: flex; justify-content: center; }
</style>
