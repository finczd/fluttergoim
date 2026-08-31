<script setup>
import { ref, computed, watch, nextTick } from 'vue';
import { useMessagesStore } from '../stores/messages';
import { useUiStore } from '../stores/ui';
import { useAuthStore } from '../stores/auth';
import { uploadFile } from '../api/client';
import { EMOJIS } from '../utils/helpers';

const messages = useMessagesStore();
const ui = useUiStore();
const auth = useAuthStore();
const text = ref('');
const inputEl = ref(null);
const showEmoji = ref(false);
const draftTimer = ref(null);

// 需求11：语音/视频通话（TRTC，单聊）—— 先发 invite 信令再开窗，否则对方不会响铃
function onCallClick() {
  if (!messages.current) {
    ui.toast('请先选择一个会话');
    return;
  }
  if (messages.current.type === 'group') {
    ui.toast('暂仅支持单聊通话', '', 'warning');
    return;
  }
  if (ui.call.open) {
    ui.toast('正在通话中', '', 'warning');
    return;
  }
  startCall(messages.current.id, 'voice', messages.current.title || '通话');
}

function startCall(convId, callType, peerName) {
  messages.sendCallSignal(convId, 'invite', callType);
  ui.openCall(convId, callType, peerName, { role: 'caller', peerName });
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

// ============ 红包 / 转账 ============
const isGroup = computed(() => messages.current?.type === 'group');
const peerOptions = computed(() => {
  if (!isGroup.value) return [];
  const members = messages.currentDetail?.members || [];
  return members
    .filter(m => String(m.id) !== String(auth.user?.id))
    .map(m => ({ id: String(m.id), name: m.nickname || m.username || '用户' }));
});

const showMoney = ref(false);
const moneyKind = ref('redpacket');
const moneyAmount = ref('');
const moneyNote = ref('');
const moneyMode = ref('normal');
const moneyCount = ref(1);
const moneyPeerId = ref('');
const moneyBusy = ref(false);
const moneyError = ref('');

function openMoney(kind) {
  if (!messages.current) {
    ui.toast('请先选择一个会话');
    return;
  }
  moneyKind.value = kind;
  moneyAmount.value = '';
  moneyNote.value = '';
  moneyMode.value = 'normal';
  moneyCount.value = 1;
  moneyError.value = '';
  if (isGroup.value) {
    const opts = peerOptions.value;
    moneyPeerId.value = opts.length ? opts[0].id : '';
  } else {
    moneyPeerId.value = messages.current.peer?.id || '';
  }
  showMoney.value = true;
}
function closeMoney() { showMoney.value = false; }

async function submitMoney() {
  if (moneyBusy.value) return;
  const amount = Number(moneyAmount.value || 0);
  if (!amount || amount <= 0) {
    moneyError.value = '请输入有效金额';
    return;
  }
  moneyBusy.value = true;
  moneyError.value = '';
  try {
    const payload = { kind: moneyKind.value, amount, note: moneyNote.value.trim() };
    if (moneyKind.value === 'redpacket') {
      payload.mode = moneyMode.value;
      payload.count = Number(moneyCount.value || 1);
    } else {
      const o = peerOptions.value.find(p => p.id === moneyPeerId.value);
      payload.toUserId = String(moneyPeerId.value || '');
      payload.toName = (o ? o.name : '') || messages.current.title || '';
    }
    await messages.sendMoney(payload);
    showMoney.value = false;
  } catch (e) {
    moneyError.value = e.message || '发送失败';
  } finally {
    moneyBusy.value = false;
  }
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
      <button class="tool-button" type="button" title="红包" @click="openMoney('redpacket')"><svg><use href="#i-redpacket" /></svg></button>
      <button class="tool-button" type="button" title="转账" @click="openMoney('transfer')"><svg><use href="#i-transfer" /></svg></button>
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

    <!-- 红包 / 转账输入弹窗 -->
    <div v-if="showMoney" class="modal-mask" @click.self="closeMoney">
      <div class="money-compose-modal">
        <div class="money-compose-head">
          <span>{{ moneyKind === 'redpacket' ? '发红包' : '转账' }}</span>
          <button class="money-modal-close" type="button" title="关闭" @click="closeMoney"><svg><use href="#i-close" /></svg></button>
        </div>

        <div v-if="isGroup && moneyKind === 'transfer'" class="money-field">
          <label>收款人</label>
          <select v-model="moneyPeerId">
            <option v-for="o in peerOptions" :key="o.id" :value="o.id">{{ o.name }}</option>
          </select>
        </div>

        <div class="money-field">
          <label>金额</label>
          <input v-model="moneyAmount" type="number" min="0.01" step="0.01" placeholder="0.00" />
        </div>

        <template v-if="moneyKind === 'redpacket' && isGroup">
          <div class="money-field">
            <label>类型</label>
            <select v-model="moneyMode">
              <option value="normal">普通红包</option>
              <option value="lucky">拼手气红包</option>
            </select>
          </div>
          <div v-if="moneyMode === 'lucky'" class="money-field">
            <label>个数</label>
            <input v-model="moneyCount" type="number" min="1" step="1" />
          </div>
        </template>

        <div class="money-field">
          <label>留言</label>
          <input v-model="moneyNote" maxlength="30" :placeholder="moneyKind === 'redpacket' ? '恭喜发财，大吉大利' : '添加转账说明'" />
        </div>

        <div v-if="moneyError" class="money-modal-error">{{ moneyError }}</div>

        <div class="money-compose-actions">
          <button class="money-cancel" type="button" @click="closeMoney">取消</button>
          <button class="money-submit" type="button" :disabled="moneyBusy" @click="submitMoney">
            {{ moneyBusy ? '发送中…' : (moneyKind === 'redpacket' ? '塞钱进红包' : '确认转账') }}
          </button>
        </div>
      </div>
    </div>
  </footer>
</template>
