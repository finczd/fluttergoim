<script setup>
import { computed } from 'vue';
import { useMessagesStore } from '../stores/messages';
import { useAuthStore } from '../stores/auth';
import { asset, esc, replyPreview, formatBytes, timeText, initials } from '../utils/format';
import { isTransferClaimed } from '../composables/useTransferClaimed';
import Avatar from './Avatar.vue';

const props = defineProps({ message: { type: Object, required: true } });
const emit = defineEmits(['menu', 'avatar', 'reply-jump', 'retry', 'money']);

const messages = useMessagesStore();
const auth = useAuthStore();
const isGroup = computed(() => messages.current?.type === 'group');

const localClass = computed(() =>
  props.message.local_status === 'sending' ? ' local-pending' : props.message.local_status === 'failed' ? ' local-failed' : ''
);

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
  const fileUrl = asset(m.file_url);
  if (m.type === 'image' && fileUrl)
    return `<img class="message-image" src="${esc(fileUrl)}" alt="图片" loading="lazy">`;
  if (m.type === 'video' && fileUrl) return `<video class="message-video" src="${esc(fileUrl)}" controls preload="metadata"></video>`;
  if (m.type === 'file' && fileUrl)
    return `<a class="file-card" href="${esc(fileUrl)}" target="_blank" rel="noopener"><span class="file-icon">FILE</span><span><strong>${esc(m.file_name || m.content || '文件')}</strong><span>${formatBytes(m.file_size)}</span></span></a>`;
  if (m.type === 'voice') return `<span>语音消息 ${Number(m.duration || 0)} 秒</span>`;
  if (m.type === 'card') {
    const extra = m.extra || {};
    if (['voice_call', 'video_call'].includes(extra.card_type)) return `<span>${extra.card_type === 'video_call' ? '视频通话' : '语音通话'} · ${esc(extra.display_text || m.content || '')}</span>`;
    return `<span>${esc(m.content || '[卡片]')}</span>`;
  }
  if (m.type === 'call') {
    // 通话信令：invite 显示"发起通话"，hangup 显示"通话时长"
    let label = '通话';
    try {
      const p = JSON.parse(m.content || '{}');
      const isVideo = p.callType === 'video';
      if (p.action === 'hangup') {
        const d = Number(p.duration || 0);
        const mm = String(Math.floor(d / 60)).padStart(2, '0');
        const ss = String(d % 60).padStart(2, '0');
        label = `${isVideo ? '视频通话' : '语音通话'} ${mm}:${ss}`;
      } else if (p.action === 'accept') {
        label = `${isVideo ? '视频' : '语音'}通话已接通`;
      } else if (p.action === 'reject') {
        label = '对方已拒绝通话';
      } else {
        label = `${isVideo ? '视频通话' : '语音通话'}`;
      }
    } catch (_) { label = esc(m.content || '通话'); }
    return `<span class="call-record">${label}</span>`;
  }
  return esc(m.content || '').replace(/\n/g, '<br>');
});

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
  >{{ message.content || '系统消息' }}</div>
  <div
    v-else
    class="message-row"
    :class="[message.is_mine ? 'mine' : '', localClass]"
    :data-message-id="message.id"
    @contextmenu="emit('menu', $event, message)"
  >
    <button class="avatar medium message-avatar" type="button" @click="emit('avatar', String(message.sender_id || 0))">
      <Avatar :user="{ nickname: message.sender_name, avatar: message.sender_avatar }" size="medium" />
    </button>
    <div class="message-content">
      <div v-if="isGroup" class="message-sender">{{ message.sender_name || '用户' }}</div>
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
      <div v-else class="message-bubble" v-html="bodyHtml"></div>
      <div class="message-meta">
        <span>{{ timeText(message.created_at) }}</span>
        <span v-if="delivery" v-html="delivery" @click="e => { if (e.target.dataset.retry) emit('retry', e.target.dataset.retry); }"></span>
      </div>
    </div>
  </div>
</template>
