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
          <a-table-column title="群主" :width="180">
            <template #cell="{ record }">
              <div class="group-cell">
                <span class="group-avatar owner-avatar" :style="{ background: memberColor(record.ownerId || record.id) }">
                  <img v-if="record.ownerAvatar" :src="record.ownerAvatar" alt="" />
                  <template v-else>{{ (record.ownerNickname || '群').slice(0, 1).toUpperCase() }}</template>
                </span>
                <div class="group-info">
                  <span class="name">{{ record.ownerNickname || '—' }}</span>
                  <span class="sub">{{ record.ownerShortId ? '#' + record.ownerShortId : (record.ownerId ? 'ID ' + record.ownerId : '—') }}</span>
                </div>
              </div>
            </template>
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
                <span class="muid">ID {{ m.userId }}<template v-if="m.shortId"> · 短ID #{{ m.shortId }}</template></span>
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

    <!-- 群聊天记录弹窗（居中模态，复用 ConvViewer 共享组件） -->
    <a-modal
      v-model:visible="showMsgs"
      :title="'群聊天记录 · ' + (currentGroup?.nameZh || currentGroup?.id || '')"
      :footer="false"
      :mask-closable="true"
      :mask="true"
      width="720"
      :body-style="{ padding: '16px 20px 20px', height: '600px', display: 'flex', flexDirection: 'column' }"
      unmount-on-close
    >
      <div class="msg-toolbar">
        <a-input-search v-model="msgKw" placeholder="搜索内容" allow-clear style="width: 260px" @search="reloadViewer" />
        <a-button type="primary" size="small" @click="reloadViewer">刷新</a-button>
      </div>
      <div class="conv-viewer-wrap">
        <ConvViewer v-if="currentGroup?.id" :key="currentGroup.id" ref="viewerRef" :conv-id="String(currentGroup.id)" :kw="msgKw" />
      </div>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { Message } from '@arco-design/web-vue'
import { IconUserGroup, IconMessage } from '@arco-design/web-vue/es/icon'
import { adminApi } from '@/api/admin'
// 会话查看器（消息渲染解析 + 数据源 /admin/messages，与消息记录「查看会话」共用同一组件）
import ConvViewer from './ConvViewer.vue'

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

// 内容解析（extractSec/shortText/parseLabel 已废弃，统一走 adminMsg.ts 共享解析）

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
    else Message.error(data.message || '读取群成员失败')
  } catch (e: any) {
    Message.error(e?.message || '读取群成员失败（网络错误）')
  } finally {
    membersLoading.value = false
  }
}

// ============= 群聊天记录（复用 ConvViewer，数据源 /admin/messages，含昵称/短ID/头像） =============
const showMsgs = ref(false)
const msgKw = ref('')
const viewerRef = ref<InstanceType<typeof ConvViewer> | null>(null)

async function openMessages(r: Record<string, any>) {
  currentGroup.value = r
  msgKw.value = ''
  showMsgs.value = true
}

function reloadViewer() {
  viewerRef.value?.reload()
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

/* 消息弹窗 */
.msg-toolbar {
  display: flex; gap: 10px; margin-bottom: 12px; align-items: center;
  flex-shrink: 0;
}
.conv-viewer-wrap { flex: 1; min-height: 0; }
.conv-viewer-wrap :deep(.conv-window) { height: 100%; }
</style>
