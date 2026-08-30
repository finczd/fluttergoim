<script setup>
import { ref, watch, nextTick } from 'vue';
import { useMessagesStore } from '../stores/messages';
import { useUiStore } from '../stores/ui';
import { uploadFile } from '../api/client';
import { EMOJIS } from '../utils/helpers';

const messages = useMessagesStore();
const ui = useUiStore();
const text = ref('');
const inputEl = ref(null);
const showEmoji = ref(false);
const draftTimer = ref(null);

// 需求11：语音/视频通话（TRTC，单聊）
function onCallClick() {
  if (!messages.current) {
    ui.toast('请先选择一个会话');
    return;
  }
  if (messages.current.type === 'group') {
    ui.toast('暂仅支持单聊通话', '', 'warning');
    return;
  }
  ui.openCall(messages.current.id, 'voice', messages.current.title || '通话');
}

watch(
  () => messages.current?.id,
  async id => {
    await nextTick();
    text.value = id ? messages.draftFor(id) : '';
    if (inputEl.value) inputEl.value.focus();
  },
  { immediate: true }
);

function onInput() {
  messages.draftDirty = true;
  clearTimeout(draftTimer.value);
  draftTimer.value = setTimeout(() => {
    if (messages.current) messages.saveDraft(messages.current.id, text.value);
  }, 600);
}

function send() {
  if (!text.value.trim() || !messages.current) return;
  messages.sendMessage({ content: text.value });
  text.value = '';
  messages.clearDraft(messages.current.id);
}

function onKey(e) {
  if (e.key === 'Enter' && !e.shiftKey && !e.isComposing) {
    e.preventDefault();
    send();
  }
}

function cancelReply() {
  messages.clearReply();
}

async function uploadAndSend(file) {
  if (!messages.current || !file) return;
  if (!file.type.startsWith('image/')) return;
  try {
    const up = await uploadFile(file);
    await messages.sendMessage({
      message_type: 'image',
      content: file.name,
      file_url: up.url,
      file_name: up.name || file.name,
      file_size: up.size || file.size,
      extra: { upload_id: up.id, mime_type: up.mime_type }
    });
  } catch (e) {
    ui.toast('图片发送失败', e.message, 'error');
  }
}

async function sendFile(file) {
  if (!messages.current || !file) return;
  try {
    const up = await uploadFile(file);
    const type = file.type.startsWith('video/') ? 'video' : 'file';
    await messages.sendMessage({
      message_type: type,
      content: file.name,
      file_url: up.url,
      file_name: up.name || file.name,
      file_size: up.size || file.size,
      extra: { upload_id: up.id, mime_type: up.mime_type }
    });
  } catch (e) {
    ui.toast('文件发送失败', e.message, 'error');
  }
}

function pickFiles(kind) {
  if (!messages.current) return;
  const input = document.createElement('input');
  input.type = 'file';
  input.multiple = true;
  if (kind === 'image') input.accept = 'image/*';
  input.onchange = () => {
    for (const f of input.files) {
      const type = kind || (f.type.startsWith('image/') ? 'image' : f.type.startsWith('video/') ? 'video' : 'file');
      if (type === 'image') uploadAndSend(f);
      else sendFile(f);
    }
  };
  input.click();
}

// 微信式：粘贴剪贴板图片（截图/复制图片）直接发送
function onPaste(e) {
  const images = [];
  const files = e.clipboardData?.files || [];
  for (const f of files) if (f.type.startsWith('image/')) images.push(f);
  if (!images.length) {
    const items = e.clipboardData?.items || [];
    for (const it of items) {
      if (it.kind === 'file' && it.type.startsWith('image/')) {
        const f = it.getAsFile();
        if (f) images.push(f);
      }
    }
  }
  if (!images.length) return;
  e.preventDefault();
  images.forEach(uploadAndSend);
}

// 微信式：拖入图片到输入区直接发送
function onDrop(e) {
  const images = [...(e.dataTransfer?.files || [])].filter(f => f.type.startsWith('image/'));
  if (!images.length) return;
  e.preventDefault();
  images.forEach(uploadAndSend);
}

async function startCall(type) {
  // 已废弃：当前版本不支持主动发起通话
  onCallClick();
  return;
}
</script>

<template>
  <footer class="composer" @dragover.prevent @drop.prevent="onDrop">
    <div v-if="messages.replyTo" class="reply-bar">
      <div class="reply-bar-body">
        <span class="reply-bar-tag">回复</span>
        <div class="reply-bar-info">
          <strong>{{ messages.replyTo.sender_name }}</strong>
          <span>{{ messages.replyTo.content || (messages.replyTo.type === 'image' ? '[图片]' : messages.replyTo.type === 'file' ? '[文件]' : '消息') }}</span>
        </div>
      </div>
      <button class="reply-cancel" type="button" title="取消回复" @click="cancelReply"><svg><use href="#i-close" /></svg></button>
    </div>

    <div class="composer-tools">
      <button class="tool-button" type="button" title="表情" @click="showEmoji = !showEmoji"><svg><use href="#i-smile" /></svg></button>
      <button class="tool-button" type="button" title="发送图片" @click="pickFiles('image')"><svg><use href="#i-image" /></svg></button>
      <button class="tool-button" type="button" title="发送文件" @click="pickFiles('file')"><svg><use href="#i-paperclip" /></svg></button>
      <button class="tool-button" type="button" title="语音通话" @click="onCallClick"><svg><use href="#i-phone" /></svg></button>
      <button class="tool-button" type="button" title="视频通话" @click="onCallClick"><svg><use href="#i-video-call" /></svg></button>
      <span class="upload-status"></span>
    </div>

    <div v-if="showEmoji" class="emoji-panel">
      <button v-for="e in EMOJIS" :key="e" type="button" @click="text += e">{{ e }}</button>
    </div>

    <textarea
      ref="inputEl"
      v-model="text"
      class="composer-input"
      rows="1"
      maxlength="5000"
      placeholder="输入消息，Enter 发送，Shift + Enter 换行"
      @input="onInput"
      @keydown="onKey"
      @paste="onPaste"
    ></textarea>

    <div class="composer-bottom">
      <span class="composer-hint">Enter 发送 · Shift + Enter 换行</span>
      <button class="send-button" type="button" @click="send"><span>发送</span><svg><use href="#i-send" /></svg></button>
    </div>
  </footer>
</template>
