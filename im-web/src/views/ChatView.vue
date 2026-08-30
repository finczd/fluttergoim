<template>
  <div class="chat-page">
    <div class="conv-list">
      <div class="conv-header">
        <h2>{{ t('chat.title') }}</h2>
        <button class="search-btn">{{ t('chat.searchPlaceholder') }}</button>
      </div>
      <!-- 快捷通话入口 -->
      <div class="quick-calls">
        <div class="call-item video">{{ t('chat.videoCall') }}</div>
        <div class="call-item voice">{{ t('chat.voiceCall') }}</div>
      </div>
      <!-- 会话列表：阶段 3 接入接口 -->
      <div class="empty">{{ t('common.empty') }}</div>
    </div>
    <div class="chat-window">
      <div class="placeholder">{{ t('chat.title') }}</div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { useI18n } from 'vue-i18n'
const { t } = useI18n()
</script>

<style scoped>
.chat-page { display: flex; height: 100%; }
.conv-list { width: 300px; border-right: 1px solid #edeff2; padding: 16px; overflow-y: auto; }
.conv-header { display: flex; flex-direction: column; gap: 12px; }
.conv-header h2 { margin: 0; font-size: 22px; }
.search-btn { text-align: left; padding: 8px 12px; border-radius: 16px; border: none; background: #fff; color: #9aa3ae; cursor: pointer; }
.quick-calls { display: flex; gap: 8px; margin-top: 12px; }
.call-item { flex: 1; text-align: center; padding: 12px 0; border-radius: 12px; font-size: 13px; }
.call-item.video { background: #eaf1ff; color: #1f6feb; }
.call-item.voice { background: #e8f7ee; color: #00b42a; }
.empty { margin-top: 40px; text-align: center; color: #9aa3ae; }
.chat-window { flex: 1; display: flex; align-items: center; justify-content: center; color: #9aa3ae; }
</style>
