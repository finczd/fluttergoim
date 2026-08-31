<script setup>
import { ref, computed, watch, nextTick } from 'vue';
import { useMessagesStore } from '../stores/messages';
import { useUiStore } from '../stores/ui';
import { preview } from '../utils/format';
import ChatHeader from './ChatHeader.vue';
import MessageList from './MessageList.vue';
import Composer from './Composer.vue';
import MoneyModal from './MoneyModal.vue';

const messages = useMessagesStore();
const ui = useUiStore();
const editDraft = ref('');
const editSaving = ref(false);
const editInput = ref(null);

// 红包 / 转账：点击气泡打开领取弹窗
const moneyMessage = ref(null);
function onMoney(m) { moneyMessage.value = m; }

// 编辑浮层：打开时预填原内容并聚焦
watch(
  () => ui.editingMessage,
  m => {
    editDraft.value = m ? String(m.content || '') : '';
    if (m) nextTick(() => editInput.value?.focus());
  }
);
async function saveEdit() {
  const m = ui.editingMessage;
  if (!m || editSaving.value) return;
  editSaving.value = true;
  try {
    await messages.editMessage(String(m.id), editDraft.value);
    ui.closeEditMessage();
  } finally {
    editSaving.value = false;
  }
}

// ---- 置顶消息：单条轮播，点击切换到下一条并跳到该消息 ----
const pinList = computed(() => (Array.isArray(messages.pins) ? messages.pins : []));
const pinIndex = ref(0);
const currentPin = computed(() => (pinList.value.length ? pinList.value[pinIndex.value % pinList.value.length] : null));

// 置顶列表变化时把索引收回到合法范围
watch(() => pinList.value.length, len => { if (pinIndex.value >= len) pinIndex.value = 0; });

function jumpTo(messageId) {
  const el = document.querySelector(`[data-message-id="${messageId}"]`);
  if (!el) return;
  el.scrollIntoView({ behavior: 'smooth', block: 'center' });
  el.classList.remove('reply-highlight');
  // 强制重排以重新触发动画
  void el.offsetWidth;
  el.classList.add('reply-highlight');
  setTimeout(() => el.classList.remove('reply-highlight'), 1200);
}

function cyclePin() {
  if (!currentPin.value) return;
  const id = currentPin.value.message_id || currentPin.value.id;
  // 先跳到当前这条
  jumpTo(id);
  // 再切换到下一条
  if (pinList.value.length > 1) {
    pinIndex.value = (pinIndex.value + 1) % pinList.value.length;
  }
}

async function unpin(messageId) {
  await messages.pinMessage(messageId, false);
}

// ---- 群公告：置顶展示，成员可 x 掉（标记已读）----
const announcement = computed(() => {
  const a = messages.currentDetail?.announcement;
  return a && typeof a === 'object' ? a : null;
});
const showAnn = computed(() => {
  const a = announcement.value;
  return !!a && a.has_read === false;
});
const annBusy = ref(false);

async function dismissAnn() {
  const a = announcement.value;
  if (!a?.id) return;
  annBusy.value = true;
  try {
    await messages.dismissAnnouncement(a.id);
  } finally {
    annBusy.value = false;
  }
}
</script>

<template>
  <section class="chat-workspace">
    <ChatHeader />

    <!-- 群公告：置顶横幅，点 × 标记已读后消失 -->
    <div v-if="showAnn" class="announcement-bar">
      <svg><use href="#i-info" /></svg>
      <div class="announcement-body">
        <strong>群公告</strong>
        <span>{{ announcement.content || announcement.text || '' }}</span>
      </div>
      <button class="announcement-close" type="button" title="不再显示" :disabled="annBusy" @click="dismissAnn">
        <svg><use href="#i-close" /></svg>
      </button>
    </div>

    <!-- 置顶消息：单条轮播，点击切换下一条并跳转 -->
    <div v-if="currentPin" class="pinned-bar pinned-bar-carousel" @click="cyclePin">
      <svg class="pin-icon"><use href="#i-pin" /></svg>
      <div class="pinned-text">
        <span class="pinned-sender">{{ currentPin.sender_name || currentPin.nickname || '' }}</span>
        <span class="pinned-preview">{{ preview(currentPin.message || currentPin) }}</span>
      </div>
      <span v-if="pinList.length > 1" class="pin-counter">{{ (pinIndex % pinList.length) + 1 }}/{{ pinList.length }}</span>
      <button class="pinned-unpin" type="button" title="取消置顶" @click.stop="unpin(currentPin.message_id || currentPin.id)">
        <svg><use href="#i-close" /></svg>
      </button>
    </div>

    <MessageList @money="onMoney" />

    <!-- 红包 / 转账领取弹窗 -->
    <MoneyModal v-if="moneyMessage" :message="moneyMessage" @close="moneyMessage = null" />

    <!-- 编辑消息浮层（仅客服）：右键"编辑"打开，替换输入框 -->
    <div v-if="ui.editingMessage" class="edit-message-bar" @keydown.esc="ui.closeEditMessage">
      <div class="edit-message-head">
        <span>编辑消息</span>
        <button type="button" class="edit-message-close" title="取消 (Esc)" @click="ui.closeEditMessage">
          <svg><use href="#i-close" /></svg>
        </button>
      </div>
      <textarea
        ref="editInput"
        v-model="editDraft"
        class="edit-message-input"
        rows="3"
        maxlength="2000"
        placeholder="修改消息内容…（仅客服可编辑）"
        @keydown.enter.exact.prevent="saveEdit"
        @keydown.ctrl.enter.prevent="saveEdit"
      ></textarea>
      <div class="edit-message-actions">
        <span class="edit-message-hint">Enter 保存 · Esc 取消</span>
        <button type="button" class="edit-message-save" :disabled="editSaving" @click="saveEdit">
          {{ editSaving ? '保存中…' : '保存' }}
        </button>
      </div>
    </div>

    <Composer v-else />
  </section>
</template>
