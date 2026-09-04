<script setup>
import { ref, watch, nextTick, computed, onMounted, onBeforeUnmount } from 'vue';
import { useMessagesStore } from '../stores/messages';
import { useUiStore } from '../stores/ui';
import { useInspector } from '../composables/useInspector';
import { useAuthStore } from '../stores/auth';
import MessageRow from './MessageRow.vue';
import { dayText } from '../utils/format';

const messages = useMessagesStore();
const ui = useUiStore();
const auth = useAuthStore();
const inspector = useInspector();
const emit = defineEmits(['money']);
const listEl = ref(null);

const rendered = computed(() => {
  const out = [];
  let prevDay = '';
  for (const m of messages.messages) {
    const day = dayText(m.created_at);
    if (day !== prevDay) {
      out.push({ day });
      prevDay = day;
    }
    out.push({ message: m });
  }
  return out;
});

function isNearBottom() {
  const el = listEl.value;
  return el ? el.scrollHeight - el.scrollTop - el.clientHeight < 90 : true;
}
function scrollBottom() {
  const el = listEl.value;
  if (!el) return;
  // 双 rAF：先让 Vue 把新消息渲染进 DOM，再让浏览器完成布局，再设 scrollTop
  requestAnimationFrame(() => {
    requestAnimationFrame(() => {
      el.scrollTop = el.scrollHeight;
    });
  });
}

const nearBottom = ref(true);
const unreadBelow = ref(0);
const showJumpBottom = computed(() => !nearBottom.value && messages.messages.length > 0);

// 图片/视频点击放大（灯箱）
const lightboxUrl = ref('');
function onImage(url) {
  if (url) lightboxUrl.value = url;
}
function closeLightbox() {
  lightboxUrl.value = '';
}

// 异步图片/视频加载完成会改变内容高度 → 若本就在底部则重新贴底（避免进入会话后停在“估算底部”）
function onMediaLoad(e) {
  const t = e.target;
  if (t && (t.tagName === 'IMG' || t.tagName === 'VIDEO') && nearBottom.value) scrollBottom();
}
onMounted(() => {
  listEl.value?.addEventListener('load', onMediaLoad, true);
});
onBeforeUnmount(() => {
  listEl.value?.removeEventListener('load', onMediaLoad, true);
});

function goBottom() {
  nearBottom.value = true;
  unreadBelow.value = 0;
  scrollBottom();
}

watch(
  () => messages.messages.length,
  async () => {
    if (nearBottom.value) await nextTick(scrollBottom);
  }
);
watch(
  () => messages.current?.id,
  async () => {
    unreadBelow.value = 0;
    nearBottom.value = true;
    await nextTick(scrollBottom);
  }
);
// 自增信号：发/收消息时——在底部则滚底；滚动中收到新消息则计数并显示悬浮按钮
watch(
  () => messages.scrollSignal,
  async () => {
    if (nearBottom.value) await nextTick(scrollBottom);
    else unreadBelow.value += 1;
  }
);

function onScroll() {
  const el = listEl.value;
  if (!el) return;
  const atBottom = el.scrollHeight - el.scrollTop - el.clientHeight < 90;
  if (atBottom) unreadBelow.value = 0;
  nearBottom.value = atBottom;
  if (el.scrollTop < 56) messages.loadOlderMessages();
}

function onMenu(e, message) {
  e.preventDefault();
  const items = [
    { label: '回复', icon: 'i-chat', onClick: () => messages.setReply(message) },
    {
      label: '复制',
      icon: 'i-copy',
      onClick: () => {
        if (message.content) navigator.clipboard?.writeText(message.content);
        ui.toast('已复制');
      }
    }
  ];
  // 编辑已发送的文本消息：仅客服（后端二次校验）
  if (!!Number(auth.user?.is_agent) && message.is_mine && message.id && String(message.id) !== '0' && Number(message.status) === 1 && message.type === 'text')
    items.push({ label: '编辑', icon: 'i-edit', onClick: () => ui.openEditMessage(message) });
  if (message.id && String(message.id) !== '0') {
    items.push({ label: messages.isPinned(message.id) ? '取消置顶' : '置顶消息', icon: 'i-pin', onClick: () => messages.pinMessage(message.id, !messages.isPinned(message.id)) });
    items.push({ label: '收藏', icon: 'i-star', onClick: () => messages.favoriteMessage(String(message.id)) });
  }
  if (message.is_mine && message.id && String(message.id) !== '0' && Number(message.status) === 1)
    items.push({ label: '撤回', icon: 'i-recall', danger: true, onClick: () => messages.recallMessage(String(message.id)) });
  ui.openContextMenu(e.clientX, e.clientY, items);
}
function onAvatar(userId) {
  if (userId) inspector.openUser(userId);
}
function onReplyJump(id) {
  const el = listEl.value?.querySelector(`[data-message-id="${id}"]`);
  if (el) {
    el.scrollIntoView({ behavior: 'smooth', block: 'center' });
    el.classList.add('reply-highlight');
    setTimeout(() => el.classList.remove('reply-highlight'), 1200);
  }
}
function onRetry(id) {
  messages.retryFailedMessage(id);
}
</script>

<template>
  <div class="message-list-wrap">
    <!-- 首屏消息拉取中且无缓存/无内容时显示进度条，避免被误认为白屏/卡死 -->
    <div v-if="messages.loadingInitial && !messages.messages.length" class="msg-loading">
      <div class="msg-loading-bar"><i></i></div>
      <span>正在载入消息…</span>
    </div>
    <div ref="listEl" class="message-list" @scroll="onScroll">
      <div v-if="!rendered.length" class="empty-list-state"><strong>还没有消息</strong><span>发送第一条消息开始沟通</span></div>
      <template v-for="(row, i) in rendered" :key="row.day ? 'd' + i : 'm' + row.message.id">      <div v-if="row.day" class="message-day">{{ row.day }}</div>
        <MessageRow
          v-else
          :message="row.message"
          @menu="onMenu"
          @avatar="onAvatar"
          @reply-jump="onReplyJump"
          @retry="onRetry"
          @image="onImage"
          @money="m => emit('money', m)"
        />
      </template>
    </div>
    <button v-if="showJumpBottom" class="jump-bottom-fab" type="button" @click="goBottom">
      <svg><use href="#i-chevron" /></svg>
      <span>{{ unreadBelow > 0 ? unreadBelow + ' 条新消息' : '回到底部' }}</span>
    </button>
    <div v-if="lightboxUrl" class="media-overlay" @click.self="closeLightbox">
      <button class="media-overlay-close" type="button" @click="closeLightbox">关闭</button>
      <img :src="lightboxUrl" alt="预览" @click="closeLightbox">
    </div>
  </div>
</template>
