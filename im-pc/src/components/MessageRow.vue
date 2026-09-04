<script setup>
import { computed } from 'vue';
import { useMessagesStore } from '../stores/messages';
import { useAuthStore } from '../stores/auth';
import { useContactsStore } from '../stores/contacts';
import { asset, esc, replyPreview, formatBytes, timeText, initials, isHttpUrl, systemMessageText, callBubble } from '../utils/format';
import { isTransferClaimed } from '../composables/useTransferClaimed';
import Avatar from './Avatar.vue';

const props = defineProps({ message: { type: Object, required: true } });
const emit = defineEmits(['menu', 'avatar', 'reply-jump', 'retry', 'money', 'image']);

const messages = useMessagesStore();
const auth = useAuthStore();
const contacts = useContactsStore();
const isGroup = computed(() => messages.current?.type === 'group');

// 群系统消息里 actor/target 多为成员 id，用成员表解析成昵称
const memberMap = computed(() => {
  const map = {};
  const list = messages.currentDetail?.members || [];
  for (const m of list) map[String(m.id)] = m.alias || m.nickname || m.username || m.name || String(m.id);
  if (auth.user?.id) map[String(auth.user.id)] = auth.user.nickname || '我';
  return map;
});
function nameOf(id) {
  if (id == null) return '';
  const s = String(id);
  if (memberMap.value[s]) return memberMap.value[s];
  if (s === String(auth.user?.id || '')) return '我';
  return s; // 不在成员表（如“在线客服”）原样返回
}
const systemText = computed(() => systemMessageText(props.message.content, nameOf));
const callInfo = computed(() => callBubble(props.message));

const localClass = computed(() =>
  props.message.local_status === 'sending' ? ' local-pending' : props.message.local_status === 'failed' ? ' local-failed' : ''
);

// 发送者昵称/头像解析：后端 model.Message 不含 senderName/senderAvatar，
// 必须从「群成员表 / 单聊对方 / 好友缓存 / 自己」解析（需求3/5）。
const senderInfo = computed(() => {
  const m = props.message;
  const sid = String(m.sender_id || '');
  const myId = String(auth.user?.id || '');
  if (sid && sid === myId) {
    return { nickname: auth.user?.nickname || '我', avatar: auth.user?.avatar || '' };
  }
  if (isGroup.value) {
    const mem = (messages.currentDetail?.members || []).find(x => String(x.id) === sid);
    if (mem) return { nickname: mem.nickname || mem.username || String(mem.id), avatar: mem.avatar || '' };
  } else {
    const peer = messages.current?.peer || {};
    if (sid && String(peer.id || '') === sid) {
      return { nickname: peer.nickname || '对方', avatar: peer.avatar || '' };
    }
  }
  // 单聊对方常在好友列表，兜底解析
  const f = (contacts.friends || []).find(x => String(x.id) === sid);
  if (f) return { nickname: f.nickname || f.username || String(f.id), avatar: f.avatar || '' };
  // 最后兜底：消息自带（历史/缓存可能为空）→ 默认“用户”
  return { nickname: m.sender_name || '用户', avatar: m.sender_avatar || '' };
});

// 红包 / 转账气泡：解析 content JSON 渲染
const money = computed(() => {
  const m = props.message;
  if (m.type !== 'redpacket' && m.type !== 'transfer') return null;
  let data = {};
  try { data = JSON.parse(m.content || '{}'); } catch (_) {}
  const amount = Number(data.amount || 0);
  const amountText = amount > 0 ? '¥' + amount.toFixed(2) : '';
  if (m.type === 'redpacket') {
    return {
      kind: 'redpacket',
      icon: 'i-redpacket',
      title: data.note || '恭喜发财，大吉大利',
      sub: data.mode === 'lucky' ? '拼手气红包' : '普通红包',
      amountText,
      claimed: false
    };
  }
  const myId = String(auth.user?.id || '');
  const toId = data.toUserId ? String(data.toUserId) : '';
  const isReceiver = toId ? toId === myId : !m.is_mine;
  const claimed = isReceiver && isTransferClaimed(m.id);
  return {
    kind: 'transfer',
    icon: 'i-transfer',
    title: data.note || (isReceiver ? '转账给你' : ('转给 ' + (data.toName || '对方'))),
    sub: isReceiver ? (claimed ? '已收款' : '待你收款') : '转账',
    amountText,
    claimed
  };
});

const bodyHtml = computed(() => {
  const m = props.message;
  if (m.type === 'redpacket' || m.type === 'transfer') return '';
  if (Number(m.status) === 2) return '<span class="recalled-text">消息已撤回</span>';
  const fileUrl = asset(m.file_url) || (isHttpUrl(m.content) ? m.content : '');
  if (m.type === 'image' && fileUrl)
    return `<img class="message-image" src="${esc(fileUrl)}" alt="图片" loading="lazy">`;
  if (m.type === 'video' && fileUrl) return `<video class="message-video" src="${esc(fileUrl)}" controls preload="metadata"></video>`;
  if (m.type === 'file' && fileUrl)
    return `<a class="file-card" href="${esc(fileUrl)}" target="_blank" rel="noopener"><span class="file-icon">FILE</span><span><strong>${esc(m.file_name || m.content || '文件')}</strong><span>${formatBytes(m.file_size)}</span></span></a>`;
  if (m.type === 'voice') return `<span>语音消息 ${Number(m.duration || 0)} 秒</span>`;
  if (m.type === 'card') {
    const extra = m.extra || {};
    // voice_call / video_call 交给 callInfo 统一渲染气泡，这里跳过
    if (['voice_call', 'video_call'].includes(extra.card_type)) return '';
    return `<span>${esc(m.content || '[卡片]')}</span>`;
  }
  // call 信令消息交给 callInfo 统一渲染气泡，这里跳过
  if (m.type === 'call') return '';
  return esc(m.content || '').replace(/\n/g, '<br>');
});

function onBubbleClick(e) {
  const t = e.target;
  if (t && t.tagName === 'IMG' && t.classList && t.classList.contains('message-image')) {
    emit('image', t.getAttribute('src'));
  }
}

const delivery = computed(() => {
  const m = props.message;
  if (!m.is_mine) return '';
  if (m.local_status === 'sending') return '<span class="message-state-sending">发送中</span>';
  if (m.local_status === 'failed')
    return `<span class="message-state-failed">发送失败</span><button class="retry-message" type="button" data-retry="${String(m.id)}">重试</button>`;
  return `<span>${['read', 'delivered', 'sent'].includes(m.delivery_state) ? { read: '已读', delivered: '已送达', sent: '已发送' }[m.delivery_state] : '已发送'}</span>`;
});
</script>

<template>
  <div
    v-if="message.type === 'system'"
    class="system-message"
  ><span class="system-pill">{{ systemText || message.content || '系统消息' }}</span></div>
  <div
    v-else
    class="message-row"
    :class="[message.is_mine ? 'mine' : '', localClass]"
    :data-message-id="message.id"
    @contextmenu="emit('menu', $event, message)"
  >
    <button class="message-avatar" type="button" @click="emit('avatar', String(message.sender_id || 0))">
      <Avatar :user="{ nickname: senderInfo.nickname, avatar: senderInfo.avatar }" size="medium" />
    </button>
    <div class="message-content">
      <div v-if="isGroup" class="message-sender">{{ senderInfo.nickname }}</div>
      <div v-if="message.reply" class="reply-card" @click="emit('reply-jump', String(message.reply.id))">
        <span class="reply-card-name">{{ message.reply.sender_name || '用户' }}</span>
        <span class="reply-card-preview">{{ replyPreview(message.reply) }}</span>
      </div>
      <div v-if="money" class="money-bubble" :class="[money.kind, money.claimed ? 'money-claimed' : '']" @click="emit('money', message)">
        <div class="money-ico"><svg class="money-ico-svg"><use :href="'#' + money.icon" /></svg></div>
        <div class="money-body">
          <div class="money-title">{{ money.title }}</div>
          <div class="money-sub">{{ money.sub }}</div>
        </div>
        <div v-if="money.amountText" class="money-amount">{{ money.amountText }}</div>
      </div>
      <template v-else-if="callInfo">
        <div class="call-bubble" :class="callInfo.statusClass">
          <span class="call-ico"><svg><use :href="'#' + (callInfo.kind === 'video' ? 'i-video-call' : 'i-phone')" /></svg></span>
          <div class="call-body">
            <div class="call-title">{{ callInfo.kind === 'video' ? '视频通话' : '语音通话' }}</div>
            <div class="call-status">{{ callInfo.statusLabel }}</div>
          </div>
        </div>
      </template>
      <div v-else class="message-bubble" v-html="bodyHtml" @click="onBubbleClick"></div>
      <div class="message-meta">
        <span>{{ timeText(message.created_at) }}</span>
        <span v-if="delivery" v-html="delivery" @click="e => { if (e.target.dataset.retry) emit('retry', e.target.dataset.retry); }"></span>
      </div>
    </div>
  </div>
</template>
