<template>
  <div class="contacts-page">
    <div class="list-head">
      <h2>联系记录</h2>
    </div>

    <table class="data-table">
      <thead>
        <tr>
          <th>姓名</th>
          <th>联系方式</th>
          <th>留言</th>
          <th>提交时间</th>
          <th>状态</th>
          <th>操作</th>
        </tr>
      </thead>
      <tbody>
        <tr v-if="loading">
          <td colspan="6" class="empty-row">加载中...</td>
        </tr>
        <tr v-else-if="!list.length">
          <td colspan="6" class="empty-row">暂无联系记录</td>
        </tr>
        <tr v-for="c in list" :key="c.id" :class="{ unread: !c.read }">
          <td class="td-name">{{ c.name }}</td>
          <td>{{ c.contact }}</td>
          <td class="td-msg">{{ c.message }}</td>
          <td class="td-time">{{ formatDate(c.createdAt) }}</td>
          <td>
            <span v-if="c.read" class="tag tag-grey">已读</span>
            <span v-else class="status-unread">
              <span class="blue-dot"></span>
              未读
            </span>
          </td>
          <td class="td-actions">
            <button v-if="!c.read" @click="markRead(c)" class="act-btn">标记已读</button>
            <button @click="remove(c)" class="act-btn danger">删除</button>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: 'admin' })

interface Contact {
  id: string
  name: string
  contact: string
  message: string
  createdAt: string
  read: boolean
}

const list = ref<Contact[]>([])
const loading = ref(false)

async function load() {
  loading.value = true
  try {
    const res = await $fetch<{ code: number; data: Contact[] }>('/api/admin/contacts')
    if (res.code === 0) list.value = res.data || []
  } catch { /* ignore */ }
  loading.value = false
}

async function markRead(c: Contact) {
  try {
    await $fetch(`/api/admin/contacts/${c.id}`, { method: 'PUT' })
    c.read = true
  } catch (err: any) {
    alert('操作失败: ' + (err?.data?.message || err?.message || ''))
  }
}

async function remove(c: Contact) {
  if (!confirm(`确认删除「${c.name || '匿名'}」的留言？此操作不可恢复。`)) return
  try {
    await $fetch(`/api/admin/contacts/${c.id}`, { method: 'DELETE' })
    await load()
  } catch (err: any) {
    alert('删除失败: ' + (err?.data?.message || err?.message || ''))
  }
}

function formatDate(s: string) {
  if (!s) return ''
  const d = new Date(s)
  const p = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}`
}

onMounted(async () => {
  // 验证登录状态，未登录则跳转登录页
  try {
    await $fetch('/api/admin/articles?pageSize=1')
  } catch {
    await navigateTo('/admin/login')
    return
  }
  await load()
})
</script>

<style scoped>
.list-head {
  display: flex; align-items: center; justify-content: space-between;
  margin-bottom: 20px;
}
.list-head h2 { font-size: 20px; font-weight: 700; color: #1d2129; }

.data-table {
  width: 100%; border-collapse: collapse; background: #fff;
  border-radius: 8px; overflow: hidden; box-shadow: 0 1px 4px rgba(0,0,0,.04);
}
.data-table th {
  padding: 12px 16px; text-align: left; font-size: 13px; font-weight: 600;
  color: #86909c; background: #f7f8fa; border-bottom: 1px solid #e5e6eb;
}
.data-table td {
  padding: 12px 16px; font-size: 14px; color: #1d2129;
  border-bottom: 1px solid #f2f3f5; vertical-align: middle;
}
.empty-row { text-align: center; color: #86909c; padding: 32px 0; }
.td-name { font-weight: 600; white-space: nowrap; }
.td-msg {
  max-width: 320px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
}
.td-time { white-space: nowrap; color: #4e5969; }
.td-actions { white-space: nowrap; }

tr.unread { background: #f7faff; }
tr.unread td.td-name { color: #165dff; }

.status-unread {
  display: inline-flex; align-items: center; gap: 6px;
  font-size: 13px; color: #165dff; font-weight: 600;
}
.blue-dot {
  display: inline-block; width: 8px; height: 8px; border-radius: 50%;
  background: #165dff; box-shadow: 0 0 0 3px rgba(22, 93, 255, .15);
}

.tag {
  display: inline-block; padding: 2px 8px; border-radius: 4px;
  font-size: 12px; font-weight: 500;
}
.tag-grey { background: #f2f3f5; color: #86909c; }

.act-btn {
  padding: 4px 10px; border: none; border-radius: 4px; background: #f2f3f5;
  color: #4e5969; font-size: 13px; cursor: pointer; margin-right: 4px; transition: all .2s;
}
.act-btn:hover { background: #e5e6eb; }
.act-btn.danger { color: #f53f3f; }
.act-btn.danger:hover { background: #ffece8; }
</style>
