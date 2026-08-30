<template>
  <a-config-provider :locale="arcoLocale">
    <a-layout class="admin-layout">
      <a-layout-sider :width="208" collapsible>
        <div class="logo">IM Admin</div>
        <a-menu :selected-keys="[activeKey]" @menu-item-click="onMenuClick">
          <a-menu-item key="/admin/users">
            <template #icon><icon-user-group /></template>
            用户管理
          </a-menu-item>
          <a-menu-item key="/admin/groups">
            <template #icon><icon-team /></template>
            群组管理
          </a-menu-item>
          <a-menu-item key="/admin/messages">
            <template #icon><icon-message /></template>
            消息记录
          </a-menu-item>
          <a-menu-item key="/admin/stats">
            <template #icon><icon-bar-chart /></template>
            数据统计
          </a-menu-item>
          <a-menu-item key="/admin/configs">
            <template #icon><icon-settings /></template>
            系统配置
          </a-menu-item>
          <a-menu-item key="/admin/apps">
            <template #icon><icon-apps /></template>
            小程序管理
          </a-menu-item>
          <a-menu-item key="/admin/nodes">
            <template #icon><icon-location /></template>
            节点管理
          </a-menu-item>
          <a-menu-item key="/admin/assistant">
            <template #icon><icon-robot /></template>
            智能助手
          </a-menu-item>
          <a-menu-item key="/admin/logs">
            <template #icon><icon-file /></template>
            日志
          </a-menu-item>
        </a-menu>
      </a-layout-sider>

      <a-layout>
        <a-layout-header class="admin-header">
          <a-button @click="toggleLang">{{ currentLang === 'zh-CN' ? 'EN' : '中文' }}</a-button>
          <a-button status="danger" @click="logout">退出登录</a-button>
        </a-layout-header>
        <a-layout-content class="admin-content">
          <router-view />
        </a-layout-content>
      </a-layout>
    </a-layout>
  </a-config-provider>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import zhCN from '@arco-design/web-vue/es/locale/lang/zh-cn'
import enUS from '@arco-design/web-vue/es/locale/lang/en-us'
import { setLocale } from '@/i18n'

const route = useRoute()
const router = useRouter()
const { locale: i18nLocale } = useI18n()

const currentLang = computed(() => i18nLocale.value as string)
const arcoLocale = computed(() => (currentLang.value === 'zh-CN' ? zhCN : enUS))

const activeKey = computed(() => {
  const m = route.path.match(/^\/admin\/[a-z-]*/)
  return m ? m[0] : '/admin/users'
})

function onMenuClick(key: string) {
  router.push(key)
}

function toggleLang() {
  const next = currentLang.value === 'zh-CN' ? 'en-US' : 'zh-CN'
  setLocale(next)
}

function logout() {
  localStorage.removeItem('im-token')
  localStorage.removeItem('im-refresh')
  router.push('/login')
}
</script>

<style scoped>
.admin-layout { height: 100vh; }
.logo { color: #fff; font-weight: 700; font-size: 16px; padding: 16px 20px; }
.admin-header { display: flex; align-items: center; justify-content: flex-end; gap: 12px; background: #fff; border-bottom: 1px solid var(--color-border-2); padding: 0 24px; }
.admin-content { background: #f5f7fa; padding: 24px; overflow-y: auto; }
</style>
