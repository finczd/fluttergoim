<template>
  <div class="admin-layout">
    <header class="topbar">
      <div class="topbar-left">
        <svg viewBox="0 0 64 64" width="32" height="32"><defs><linearGradient id="ag" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#165dff"/><stop offset="100%" stop-color="#4080ff"/></linearGradient></defs><rect width="64" height="64" rx="14" fill="url(#ag)"/><path d="M20 22h24a4 4 0 0 1 4 4v12a4 4 0 0 1-4 4H30l-8 6v-6h-2a4 4 0 0 1-4-4V26a4 4 0 0 1 4-4z" fill="#fff"/></svg>
        <span class="title">ChatPulse 后台</span>
      </div>
      <div class="topbar-right">
        <div v-if="me" class="user-chip">
          <span class="hello">欢迎，</span>
          <strong>{{ me.nickname || me.username }}</strong>
          <span class="uname">（{{ me.username }}）</span>
          <span :class="['role-badge', me.role === 'admin' ? 'admin' : 'editor']">
            {{ me.role === 'admin' ? '管理员' : '编辑' }}
          </span>
          <button class="link-btn pwd-btn" @click="$emit('openChangePassword')">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
            修改密码
          </button>
        </div>
        <a href="/" target="_blank" class="link-btn">访问官网</a>
        <button @click="logout" class="link-btn">退出登录</button>
      </div>
    </header>
    <div class="admin-body">
      <aside class="sidebar">
        <button v-for="m in menus" :key="m.tab" class="side-btn" :class="{ active: activeTab === m.tab }" @click="$emit('changeTab', m.tab)">
          <span v-html="m.icon"></span>
          <span>{{ m.label }}</span>
        </button>
      </aside>
      <main class="content"><slot /></main>
    </div>
  </div>
</template>

<script setup lang="ts">
interface MenuDef { tab: string; label: string; icon: string }
defineProps<{
  activeTab: string
  me?: { username: string; nickname?: string; role: string } | null
}>()
defineEmits<{
  (e: 'changeTab', tab: string): void
  (e: 'openChangePassword'): void
}>()

const menus: MenuDef[] = [
  {
    tab: 'articles',
    label: '文章管理',
    icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/></svg>',
  },
  {
    tab: 'settings',
    label: '基本设置',
    icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 1 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 1 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 1 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 1 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>',
  },
  {
    tab: 'screenshots',
    label: '截图管理',
    icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="2" ry="2"/><circle cx="8.5" cy="8.5" r="1.5"/><polyline points="21 15 16 10 5 21"/></svg>',
  },
  {
    tab: 'docs',
    label: '文档管理',
    icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/><line x1="10" y1="9" x2="8" y2="9"/></svg>',
  },
  {
    tab: 'contacts',
    label: '联系记录',
    icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/><polyline points="22,6 12,13 2,6"/></svg>',
  },
  {
    tab: 'users',
    label: '账号管理',
    icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>',
  },
  {
    tab: 'ai',
    label: 'AI 管理',
    icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="4"/><path d="M8 12h2M14 12h2M12 8v8"/></svg>',
  },
  {
    tab: 'change-password',
    label: '修改密码',
    icon: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>',
  },
]

async function logout() {
  try { await $fetch('/api/admin/logout', { method: 'POST' }) } catch {}
  await navigateTo('/admin/login')
}
</script>

<style scoped>
.admin-layout {
  min-height: 100vh;
  background: #f0f2f5;
}
.topbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  height: 56px;
  padding: 0 24px;
  background: #fff;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.08);
}
.topbar-left { display: flex; align-items: center; gap: 10px; }
.topbar-left .title { font-size: 16px; font-weight: 700; color: #1d2129; }
.topbar-right { display: flex; align-items: center; gap: 8px; }
.user-chip {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 13px;
  color: #4e5969;
  padding: 4px 10px;
  border-radius: 999px;
  background: #f7f8fa;
  margin-right: 8px;
}
.user-chip .hello { color: #86909c; }
.user-chip strong { color: #1d2129; font-weight: 600; }
.user-chip .uname { color: #86909c; }
.role-badge {
  display: inline-block;
  padding: 1px 8px;
  border-radius: 10px;
  font-size: 11px;
  font-weight: 600;
  line-height: 1.6;
}
.role-badge.admin { background: #e8f3ff; color: #165dff; }
.role-badge.editor { background: #e8ffea; color: #00b42a; }
.pwd-btn {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  margin-left: 4px;
  color: #165dff;
}
.link-btn {
  padding: 6px 14px;
  border: none;
  border-radius: 6px;
  background: transparent;
  color: #4e5969;
  cursor: pointer;
  font-size: 14px;
  text-decoration: none;
  transition: background 0.2s;
}
.link-btn:hover { background: #f2f3f5; }

.admin-body { display: flex; min-height: calc(100vh - 56px); }
.sidebar {
  width: 200px;
  flex-shrink: 0;
  padding: 12px;
  background: #fff;
  border-right: 1px solid #e5e6eb;
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.side-btn {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px 14px;
  border: none;
  border-radius: 8px;
  background: transparent;
  color: #4e5969;
  cursor: pointer;
  font-size: 14px;
  text-align: left;
  transition: all 0.2s;
}
.side-btn:hover { background: #f2f3f5; }
.side-btn.active {
  background: #e8f3ff;
  color: #165dff;
  font-weight: 600;
}
.content {
  flex: 1;
  padding: 24px;
  overflow-x: auto;
}
</style>
