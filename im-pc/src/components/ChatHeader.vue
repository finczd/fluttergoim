<script setup>
import { computed } from 'vue';
import { useMessagesStore } from '../stores/messages';
import { useUiStore } from '../stores/ui';
import { useInspector } from '../composables/useInspector';
import Avatar from './Avatar.vue';

const messages = useMessagesStore();
const ui = useUiStore();
const inspector = useInspector();

const current = computed(() => messages.current || {});
const isGroup = computed(() => current.value.type === 'group');
const title = computed(() => current.value.title || '会话');

// 在线/离线文案
const statusText = computed(() => {
  const c = current.value;
  if (!c.id) return '';
  if (isGroup.value) {
    const n = c.members?.length || c.member_count_cache || 0;
    return n > 0 ? `${n} 位成员` : '群聊';
  }
  const peer = c.peer || {};
  if (peer.is_online) return '在线';
  return peer.online_text || '离线';
});
const isOnline = computed(() => !isGroup.value && !!current.value.peer?.is_online);

// 同步状态文案
const syncText = computed(() => {
  const s = ui.syncStatus;
  if (s === 'online') return '已同步';
  if (s === 'connecting') return '连接中…';
  if (s === 'offline' || s === 'error') return '同步失败';
  return '同步中';
});

function openInfo() {
  if (!current.value?.id) {
    ui.toast('请先选择一个会话');
    return;
  }
  inspector.openConversation(current.value);
}
function openSearch() {
  ui.toast('查找聊天记录', '暂未实现，敬请期待', 'info');
}
// 需求11：语音/视频通话（TRTC，单聊）
function startCall(type) {
  if (!current.value?.id) { ui.toast('请先选择一个会话'); return; }
  if (isGroup.value) { ui.toast('暂仅支持单聊通话'); return; }
  ui.openCall(current.value.id, type, title.value);
}
</script>

<template>
  <header class="chat-header">
    <div class="chat-identity">
      <Avatar :user="current" size="large" />
      <div class="chat-identity-text">
        <div class="chat-title-row">
          <h2>{{ title }}</h2>
          <span v-if="isGroup" class="type-badge">群聊</span>
        </div>
        <div class="chat-status-row">
          <p class="chat-status" :class="{ online: isOnline }">
            <span v-if="!isGroup" class="status-dot" :class="{ online: isOnline }"></span>
            {{ statusText }}
          </p>
          <span class="chat-divider">·</span>
          <p class="chat-sync" :data-state="ui.syncStatus">
            <span class="sync-mini-dot" :data-state="ui.syncStatus"></span>
            {{ syncText }}
          </p>
        </div>
      </div>
    </div>
    <div class="chat-actions">
      <button v-if="!isGroup" class="icon-button" type="button" title="语音通话" @click="startCall('voice')"><svg><use href="#i-phone" /></svg></button>
      <button v-if="!isGroup" class="icon-button" type="button" title="视频通话" @click="startCall('video')"><svg><use href="#i-video" /></svg></button>
      <button class="icon-button" type="button" title="查找聊天记录" @click="openSearch"><svg><use href="#i-search" /></svg></button>
      <button class="icon-button" type="button" :title="isGroup ? '群聊详情' : '联系人资料'" @click="openInfo"><svg><use href="#i-info" /></svg></button>
      <button class="icon-button" type="button" title="更多" @click="openInfo"><svg><use href="#i-more" /></svg></button>
    </div>
  </header>
</template>
