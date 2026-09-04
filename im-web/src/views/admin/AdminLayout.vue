<template>
  <a-config-provider :locale="arcoLocale">
    <div class="layout">
      <!-- 侧边栏 -->
      <aside class="sider" :class="{ collapsed }">
        <div class="brand">
          <span class="brand-mark" v-html="brandIcon"></span>
          <span v-show="!collapsed" class="brand-name">IM Admin</span>
        </div>

        <nav class="menu">
          <template v-for="g in menuGroups" :key="g.title">
            <div v-show="!collapsed" class="menu-group-title">{{ g.title }}</div>
            <router-link
              v-for="m in g.items"
              :key="m.path"
              :to="m.path"
              class="menu-item"
              :class="{ active: activeKey === m.path }"
              :title="collapsed ? m.label : undefined"
            >
              <span class="menu-icon"><component :is="m.icon" /></span>
              <span v-show="!collapsed" class="menu-label">{{ m.label }}</span>
            </router-link>
          </template>
        </nav>

        <div class="sider-footer">
          <button class="collapse-btn" @click="collapsed = !collapsed" :title="collapsed ? '展开' : '收起'">
            <IconMenuUnfold v-if="collapsed" />
            <IconMenuFold v-else />
          </button>
        </div>
      </aside>

      <!-- 主区 -->
      <div class="main">
        <header class="header">
          <div class="header-left">
            <span class="page-title">{{ currentTitle }}</span>
          </div>
          <div class="header-right">
            <button class="icon-btn" @click="toggleLang" :title="currentLang === 'zh-CN' ? '切换为英文' : 'Switch to Chinese'">
              <IconLanguage />
            </button>
            <span class="header-divider"></span>
            <div class="user">
              <span class="avatar">A</span>
            </div>
            <button class="icon-btn" @click="logout" title="退出登录">
              <IconExport />
            </button>
          </div>
        </header>
        <main class="content">
          <router-view />
        </main>
      </div>
    </div>
  </a-config-provider>
</template>

<script setup lang="ts">
import { computed, ref, markRaw } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import zhCN from '@arco-design/web-vue/es/locale/lang/zh-cn'
import enUS from '@arco-design/web-vue/es/locale/lang/en-us'
import {
  IconDashboard, IconUserGroup, IconRelation, IconMessage, IconBarChart, IconSettings,
  IconApps, IconLocation, IconRobot, IconFile, IconGift,
  IconLanguage, IconExport, IconMenuFold, IconMenuUnfold, IconTrophy, IconExperiment,
  IconQrcode, IconCloudDownload, IconWechatpay, IconDelete, IconFire
} from '@arco-design/web-vue/es/icon'
import { setLocale } from '@/i18n'

const route = useRoute()
const router = useRouter()
const { locale: i18nLocale } = useI18n()

const collapsed = ref(false)

const currentLang = computed(() => i18nLocale.value as string)
const arcoLocale = computed(() => (currentLang.value === 'zh-CN' ? zhCN : enUS))

const menuGroups = [
  {
    title: '总览',
    items: [
      { path: '/admin/dashboard', label: '仪表台', icon: markRaw(IconDashboard) }
    ]
  },
  {
    title: '业务管理',
    items: [
      { path: '/admin/users', label: '用户管理', icon: markRaw(IconUserGroup) },
      { path: '/admin/groups', label: '群组管理', icon: markRaw(IconRelation) },
      { path: '/admin/messages', label: '消息记录', icon: markRaw(IconMessage) },
      { path: '/admin/apps', label: '小程序管理', icon: markRaw(IconApps) },
      { path: '/admin/vip-ids', label: '靓号管理', icon: markRaw(IconTrophy) },
      { path: '/admin/invite-codes', label: '邀请码管理', icon: markRaw(IconGift) },
      { path: '/admin/finance', label: '财务管理', icon: markRaw(IconGift) },
      { path: '/admin/recharge-orders', label: '充值订单', icon: markRaw(IconWechatpay) },
      { path: '/admin/withdraw-orders', label: '提现订单', icon: markRaw(IconExport) },
      { path: '/admin/moments', label: '朋友圈', icon: markRaw(IconFire) }
    ]
  },
  {
    title: '审计',
    items: [
      { path: '/admin/stats', label: '数据统计', icon: markRaw(IconBarChart) },
      { path: '/admin/health', label: '系统检测', icon: markRaw(IconExperiment) },
      { path: '/admin/logs', label: '日志', icon: markRaw(IconFile) }
    ]
  },
  {
    title: '系统',
    items: [
      { path: '/admin/configs', label: '系统配置', icon: markRaw(IconSettings) },
      { path: '/admin/nodes', label: '节点管理', icon: markRaw(IconLocation) },
      { path: '/admin/assistant', label: '智能助手', icon: markRaw(IconRobot) },
      { path: '/admin/data-clear', label: '清空数据', icon: markRaw(IconDelete) }
    ]
  }
]

const allMenus = computed(() => menuGroups.flatMap((g) => g.items))

const activeKey = computed(() => {
  const m = route.path.match(/^\/admin\/[a-z-]*/)
  return m ? m[0] : '/admin/dashboard'
})

const currentTitle = computed(() => {
  return allMenus.value.find((m) => m.path === activeKey.value)?.label || ''
})

const brandIcon = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 5h16a1 1 0 0 1 1 1v9a1 1 0 0 1-1 1H9l-5 4V6a1 1 0 0 1 1-1z"/><circle cx="9" cy="10.5" r="0.6" fill="currentColor"/><circle cx="12.5" cy="10.5" r="0.6" fill="currentColor"/><circle cx="16" cy="10.5" r="0.6" fill="currentColor"/></svg>`

function toggleLang() {
  setLocale(currentLang.value === 'zh-CN' ? 'en-US' : 'zh-CN')
}

function logout() {
  localStorage.removeItem('im-token')
  localStorage.removeItem('im-refresh')
  router.push('/login')
}
</script>

<style scoped>
.layout { display: flex; height: 100vh; overflow: hidden; }

/* ===== 侧边栏 ===== */
.sider {
  width: var(--app-sider-width);
  background: var(--app-bg-sider);
  display: flex;
  flex-direction: column;
  transition: width var(--app-transition-smooth);
  box-shadow: var(--app-shadow-sider);
  z-index: 10;
  flex-shrink: 0;
}
.sider.collapsed { width: var(--app-sider-collapsed-width); }

.brand {
  height: var(--app-header-height);
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 0 20px;
  border-bottom: 1px solid var(--app-border-sider);
  flex-shrink: 0;
}
.sider.collapsed .brand { justify-content: center; padding: 0; }
.brand-mark {
  width: 30px; height: 30px;
  border-radius: var(--app-radius-md);
  background: linear-gradient(135deg, #165dff, #4080ff);
  display: flex; align-items: center; justify-content: center;
  flex-shrink: 0;
  color: #fff;
  box-shadow: 0 2px 8px rgba(22, 93, 255, 0.4);
}
.brand-mark :deep(svg) { width: 17px; height: 17px; }
.brand-name {
  color: var(--app-text-white);
  font-size: var(--app-font-size-lg);
  font-weight: var(--app-font-weight-semibold);
  letter-spacing: 0.5px;
  white-space: nowrap;
}

/* 菜单 */
.menu { flex: 1; padding: 8px 10px; overflow-y: auto; overflow-x: hidden; }
.menu-group-title {
  padding: 14px 14px 6px;
  font-size: var(--app-font-size-xs);
  color: var(--app-sider-text);
  opacity: 0.55;
  letter-spacing: 0.5px;
  text-transform: uppercase;
}
.menu-group-title:first-child { padding-top: 4px; }
.menu-item {
  display: flex; align-items: center; gap: 12px;
  height: 42px;
  padding: 0 14px;
  margin-bottom: 4px;
  border-radius: var(--app-radius-md);
  color: var(--app-sider-text);
  text-decoration: none;
  font-size: var(--app-font-size-base);
  cursor: pointer;
  transition: background var(--app-transition-base), color var(--app-transition-base);
}
.menu-item:hover { background: var(--app-bg-sider-hover); color: var(--app-sider-text-hover); }
.menu-item.active {
  background: var(--app-bg-sider-active);
  color: var(--app-sider-text-active);
  box-shadow: 0 2px 8px rgba(22, 93, 255, 0.35);
}
.menu-icon { display: flex; align-items: center; justify-content: center; width: 20px; height: 20px; flex-shrink: 0; }
.menu-icon :deep(svg) { width: 20px; height: 20px; }
.menu-label { white-space: nowrap; }
.sider.collapsed .menu-item { justify-content: center; padding: 0; }
.sider.collapsed .menu-label { display: none; }

/* 侧栏底部 */
.sider-footer { padding: 12px; border-top: 1px solid var(--app-border-sider); flex-shrink: 0; }
.collapse-btn {
  width: 100%; height: 36px;
  display: flex; align-items: center; justify-content: center;
  background: transparent; border: none; color: var(--app-sider-text);
  border-radius: var(--app-radius-md); cursor: pointer;
  transition: background var(--app-transition-base), color var(--app-transition-base);
}
.collapse-btn:hover { background: var(--app-bg-sider-hover); color: var(--app-sider-text-hover); }
.collapse-btn :deep(svg) { width: 18px; height: 18px; }

/* ===== 主区 ===== */
.main { flex: 1; display: flex; flex-direction: column; min-width: 0; }
.header {
  height: var(--app-header-height);
  background: var(--app-bg-header);
  border-bottom: 1px solid var(--app-border-2);
  display: flex; align-items: center; justify-content: space-between;
  padding: 0 var(--app-content-padding);
  flex-shrink: 0;
  z-index: 5;
}
.page-title { font-size: var(--app-font-size-lg); font-weight: var(--app-font-weight-semibold); color: var(--app-text-1); }
.header-right { display: flex; align-items: center; gap: 4px; }
.icon-btn {
  width: 36px; height: 36px;
  display: flex; align-items: center; justify-content: center;
  background: transparent; border: none; color: var(--app-text-2);
  border-radius: var(--app-radius-md); cursor: pointer;
  transition: background var(--app-transition-base), color var(--app-transition-base);
}
.icon-btn:hover { background: var(--app-border-2); color: var(--app-text-1); }
.icon-btn :deep(svg) { width: 20px; height: 20px; }
.header-divider { width: 1px; height: 20px; background: var(--app-border-1); margin: 0 6px; }
.user { display: flex; align-items: center; gap: 8px; padding: 0 6px; }
.avatar {
  width: 30px; height: 30px;
  border-radius: var(--app-radius-pill);
  background: linear-gradient(135deg, #165dff, #4080ff);
  color: #fff; display: flex; align-items: center; justify-content: center;
  font-size: 13px; font-weight: 600;
  box-shadow: 0 2px 6px rgba(22, 93, 255, 0.3);
}

.content { flex: 1; overflow-y: auto; padding: var(--app-content-padding); background: var(--app-bg-page); }
</style>
