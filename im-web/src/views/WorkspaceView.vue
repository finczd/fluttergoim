<template>
  <div class="workspace">
    <!-- 左侧导航 -->
    <aside class="sidebar">
      <div class="logo">{{ t('app.name') }}</div>
      <nav class="nav">
        <router-link to="/chat" class="nav-item">{{ t('nav.messages') }}</router-link>
        <router-link to="/contacts" class="nav-item">{{ t('nav.contacts') }}</router-link>
        <router-link to="/calls" class="nav-item">{{ t('nav.calls') }}</router-link>
      </nav>
      <div class="footer">
        <button class="lang-btn" @click="toggleLang">{{ currentLang === 'zh-CN' ? 'EN' : '中文' }}</button>
        <router-link to="/admin" class="admin-link">{{ t('nav.admin') }}</router-link>
      </div>
    </aside>

    <!-- 中间会话列表 + 右侧聊天窗口：阶段 3 实现 -->
    <main class="content">
      <router-view />
    </main>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { setLocale } from '@/i18n'

const { t, locale } = useI18n()
const currentLang = computed(() => locale.value as string)

function toggleLang() {
  setLocale(currentLang.value === 'zh-CN' ? 'en-US' : 'zh-CN')
}
</script>

<style scoped>
.workspace { display: flex; height: 100vh; }
.sidebar { width: 220px; background: #1f2329; color: #fff; display: flex; flex-direction: column; padding: 16px 0; }
.logo { font-size: 18px; font-weight: 700; padding: 0 20px 24px; }
.nav { flex: 1; display: flex; flex-direction: column; gap: 4px; }
.nav-item { padding: 10px 20px; color: #c0c6cf; text-decoration: none; }
.nav-item.router-link-active { color: #fff; background: #2e333b; }
.footer { padding: 12px 20px; display: flex; gap: 12px; align-items: center; }
.lang-btn { background: #2e333b; color: #fff; border: none; padding: 6px 12px; border-radius: 6px; cursor: pointer; }
.admin-link { color: #7ea6ff; text-decoration: none; font-size: 13px; }
.content { flex: 1; background: #f5f7fa; }
</style>
