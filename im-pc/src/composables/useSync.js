import { ref } from 'vue';
import { useAuthStore } from '../stores/auth';
import { useConversationsStore } from '../stores/conversations';
import { useMessagesStore } from '../stores/messages';
import { useContactsStore } from '../stores/contacts';
import { useUiStore } from '../stores/ui';
import { clearAllMessageCaches } from '../utils/messageCache';

// 实时同步引擎：适配当前 Go 后端（WebSocket 推送）。
// 原青鸟长轮询 sync/bootstrap + sync/poll 被替换为：
//  - bootstrap()：拉会话列表（conversations + 好友 + 申请）
//  - start()：建立 WS 长连接，服务端推送 {type: message|recall|read|system, data}
//  - 重连自动补拉（reconnect + onReconnected 全量刷新）
const syncStatus = ref('connecting');
const syncFailures = ref(0);
let loopId = 0;
let running = false;
let ws = null;
let heartbeatTimer = null;

async function bootstrap(currentConversationId = 0) {
  syncStatus.value = navigator.onLine ? 'connecting' : 'offline';
  const conversations = useConversationsStore();
  const messages = useMessagesStore();
  const contacts = useContactsStore();
  const auth = useAuthStore();
  try {
    await conversations.load(false);
    await contacts.loadFriends(false);
    await contacts.loadRequests(false);
    // 如果有保存的当前会话，预打开
    if (currentConversationId) {
      const conv = conversations.findById(currentConversationId);
      if (conv) {
        try {
          await messages.openConversation(currentConversationId, false);
        } catch (_) {}
      }
    }
    syncStatus.value = 'online';
  } catch (_) {
    syncStatus.value = navigator.onLine ? 'error' : 'offline';
    // 兜底：即使 bootstrap 失败也尝试进入 WS 阶段
    if (navigator.onLine) syncStatus.value = 'online';
  }
}

function applyIncomingMessage(raw) {
  const messages = useMessagesStore();
  const conversations = useConversationsStore();
  const auth = useAuthStore();
  const myId = String(auth.user?.id || '');
  const m = adaptMessage(raw, myId);
  if (!m) return;
  // 需求7：音视频通话信令（type=7 call）——先处理信令，再合入会话（通话记录留在聊天里）
  if (m.type === 'call') {
    handleCallMessage(m, raw, myId);
    const convId = String(m.conversation_id || '');
    const currentId = String(messages.current?.id || '');
    if (currentId && convId === currentId) {
      messages.mergeMessages([m], false);
      messages.scheduleReadReceipt();
    } else {
      const conv = conversations.findById(convId);
      if (conv) {
        conv.last_message = m;
        if (m.is_mine !== true) conv.unread_count = Number(conv.unread_count || 0) + 1;
      }
      if (m.is_mine !== true && document.hidden) {
        notifyBrowser(conv?.title || '新消息', previewOf(m));
      }
    }
    conversations.load(false).catch(() => {});
    return;
  }
  const convId = String(m.conversation_id || '');
  const currentId = String(messages.current?.id || '');
  // 当前打开的就是该会话 → 直接合并
  if (currentId && convId === currentId) {
    messages.mergeMessages([m], false);
    messages.scheduleReadReceipt();
  } else {
    // 非当前会话 → 会话列表里更新最后一条 + 未读 +1
    const conv = conversations.findById(convId);
    if (conv) {
      conv.last_message = m;
      if (m.is_mine !== true) conv.unread_count = Number(conv.unread_count || 0) + 1;
    }
    // 需求13：右下角浏览器系统通知（新消息，非本人 + 非当前会话）
    if (m.is_mine !== true && document.hidden) {
      notifyBrowser(conv?.title || '新消息', previewOf(m));
    }
  }
  // 刷新会话列表排序（列表可能需重排）
  conversations.load(false).catch(() => {});
}

// 通话信令处理：
//   invite（他人）→ 弹来电窗口等用户点接听/拒绝；占线则自动回 reject
//   accept       → 主叫切到"通话中"
//   reject       → 主叫关闭，提示"对方已拒绝"
//   hangup/cancel→ 关闭，提示"通话已结束"/"对方已取消"
function handleCallMessage(m, raw, myId) {
  const ui = useUiStore();
  const messages = useMessagesStore();
  const conversations = useConversationsStore();
  let sig = m.content || '{}';
  try { sig = typeof sig === 'string' ? JSON.parse(sig) : sig; } catch (_) { sig = {}; }
  // 自己发出的回显忽略（避免自己处理自己的信令）
  if (m.is_mine) return;
  const action = sig.action || 'invite';
  const callType = sig.callType || 'voice';
  const convId = String(m.conversation_id || '');
  const conv = conversations.findById(convId);
  const title = conv?.title || sig.callerName || '通话';

  if (action === 'invite') {
    if (ui.call.open) {
      // 占线：直接回一条 reject，让主叫端收尾
      messages.sendCallSignal(convId, 'reject', callType);
      return;
    }
    ui.openCall(convId, callType, title, { role: 'callee', peerName: sig.callerName || title });
    notifyBrowser('来电', title + ' 邀请你进行' + (callType === 'video' ? '视频' : '语音') + '通话');
    return;
  }

  // 以下动作只对"当前正在进行的这一通"生效
  if (!ui.call.open || String(ui.call.convId) !== convId) return;

  if (action === 'accept') {
    ui.markCallAccepted();
  } else if (action === 'reject') {
    ui.closeCall();
    ui.toast('对方已拒绝', '', 'info');
  } else if (action === 'cancel') {
    ui.closeCall();
    ui.toast('对方已取消', '', 'info');
  } else if (action === 'hangup') {
    ui.closeCall();
    ui.toast('通话已结束', '', 'info');
  }
}

/** 消息预览（与 utils/format preview 一致，避免循环 import） */
function previewOf(m) {
  if (m.type === 'image') return '[图片]';
  if (m.type === 'file') return '[文件] ' + (m.file_name || '');
  if (m.type === 'voice') return '[语音]';
  if (m.type === 'video') return '[视频]';
  if (m.type === 'card') return '[卡片]';
  if (m.type === 'call') return '[通话]';
  return m.content || '新消息';
}

/** 浏览器桌面通知（Notification API；未授权则提示，不自动申请权限） */
function notifyBrowser(title, body) {
  try {
    if (!('Notification' in window)) return;
    if (Notification.permission === 'granted') {
      new Notification(title, { body, tag: 'im-msg' });
    } else if (Notification.permission === 'default') {
      // 首次：请求权限（用户交互时再申请更友好，这里静默申请一次）
      Notification.requestPermission();
    }
  } catch (_) {}
}

/** Go 消息对象 → 青鸟消息契约（与 client.js goMsgToQm 一致，避免循环依赖） */
function adaptMessage(m, myId = '') {
  if (!m) return null;
  const file = m.file || {};
  const hasReply = m.replyTo !== undefined && m.replyTo !== null && String(m.replyTo) !== '0' && String(m.replyTo) !== '';
  const snap = m.replySnapshot || {};
  return {
    id: String(m.msgId ?? m.id ?? ''),
    msg_id: String(m.msgId ?? m.id ?? ''),
    client_msg_id: m.clientMsgId || '',
    conversation_id: String(m.conversationId ?? ''),
    sender_id: String(m.senderId ?? ''),
    sender_name: m.senderName || '',
    type: ({ 1: 'text', 2: 'image', 3: 'file', 4: 'voice', 5: 'video', 6: 'system', 7: 'call' })[Number(m.type)] || 'text',
    content: m.content || '',
    file_url: file.url || '',
    file_name: file.name || '',
    file_size: Number(file.size || 0),
    duration: Number(file.duration || 0),
    extra: file,
    reply: hasReply
      ? { id: String(m.replyTo), sender_name: snap.senderName || '', type: ({ 1: 'text', 2: 'image', 3: 'file', 4: 'voice', 5: 'video' })[Number(snap.type)] || 'text', content: snap.content || '[消息]' }
      : null,
    reply_to_id: hasReply ? String(m.replyTo) : 0,
    status: m.recalled ? 2 : 1,
    is_mine: myId ? String(m.senderId ?? '') === String(myId) : false,
    seq: m.seq || 0,
    created_at: (m.createdAt || '').replace('T', ' ').slice(0, 19),
    local_status: ''
  };
}

function applyEvent(event) {
  const messages = useMessagesStore();
  const contacts = useContactsStore();
  const conversations = useConversationsStore();
  const ui = useUiStore();
  const type = event.type || '';
  const payload = event.data || {};
  const currentId = String(messages.current?.id || '');
  const convId = String(payload.conversationId || payload.conversation_id || '');

  if (type === 'message') {
    applyIncomingMessage(payload);
    return;
  }
  if (type === 'recall') {
    // 撤回：把本地对应消息标为撤回
    const msgId = String(payload.msgId || payload.message_id || '');
    const m = messages.messages.find(x => String(x.msg_id || x.id) === msgId);
    if (m) {
      m.status = 2;
      m.content = '消息已撤回';
      m.file_url = '';
      messages.messages = [...messages.messages];
    }
    conversations.load(false).catch(() => {});
    return;
  }
  if (type === 'read') {
    // 需求2：已读实时更新 —— 本地消息 delivery_state 改为 read（无需刷新）
    const readMsgId = String(payload.msgId || payload.message_id || '');
    const readConvId = String(payload.conversationId || payload.conversation_id || '');
    if (readMsgId || readConvId) {
      let changed = false;
      for (const m of messages.messages) {
        const mId = String(m.msg_id || m.id || '');
        const cId = String(m.conversation_id || '');
        if ((readMsgId && mId === readMsgId) || (!readMsgId && cId === readConvId)) {
          if (m.is_mine && m.delivery_state !== 'read') {
            m.delivery_state = 'read';
            changed = true;
          }
        }
      }
      if (changed) messages.messages = [...messages.messages];
    }
    // 会话列表最后一条也同步（全量刷一次）
    conversations.load(false).catch(() => {});
    return;
  }
  if (type === 'friend.request' || type === 'friend.accepted' || type === 'friend.deleted') {
    contacts.loadFriends(false);
    contacts.loadRequests(false);
    // 红点提示：新的好友申请 + 桌面通知
    if (type === 'friend.request') {
      const name = payload.fromUserName || '有人';
      ui.toast('新的好友申请', name + ' 请求添加你为好友', 'info');
      notifyBrowser('新的好友申请', name + ' 请求添加你为好友');
    } else if (type === 'friend.accepted') {
      const name = payload.fromUserName || '好友';
      ui.toast('好友申请已通过', name + ' 通过了你的好友申请', 'success');
      notifyBrowser('好友申请已通过', name + ' 通过了你的好友申请');
    }
    return;
  }
  if (type === 'conversation.updated') {
    conversations.load(false).catch(() => {});
    return;
  }
}

function connectWs() {
  const auth = useAuthStore();
  if (!auth.token) return;
  // 计算 WS 地址：把 http(s)://host/api/v1 换成 ws(s)://host/ws
  const base = (import.meta.env.VITE_WS_BASE || '/ws');
  let url;
  if (/^wss?:\/\//i.test(base)) {
    url = base;
  } else {
    const proto = location.protocol === 'https:' ? 'wss:' : 'ws:';
    url = proto + '//' + location.host + base;
  }
  const sep = url.includes('?') ? '&' : '?';
  url += sep + 'token=' + encodeURIComponent(auth.token) + '&deviceType=3'; // PC 端 Web

  try {
    ws = new WebSocket(url);
  } catch (_) {
    return;
  }

  ws.onopen = () => {
    syncStatus.value = 'online';
    syncFailures.value = 0;
    // 30s 心跳续期在线状态
    clearInterval(heartbeatTimer);
    heartbeatTimer = setInterval(() => {
      if (ws && ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ action: 'ping' }));
      }
    }, 30000);
  };

  ws.onmessage = (ev) => {
    try {
      const packet = JSON.parse(ev.data || '{}');
      if (packet.type === 'pong') return;
      applyEvent(packet);
    } catch (_) {}
  };

  ws.onclose = () => {
    clearInterval(heartbeatTimer);
    if (!running) return;
    syncFailures.value += 1;
    syncStatus.value = navigator.onLine ? 'connecting' : 'offline';
    // 指数退避重连
    const delay = Math.min(12000, 900 * Math.pow(2, Math.min(syncFailures.value, 4)));
    setTimeout(() => {
      if (running && useAuthStore().token) {
        // 重连前先全量刷一次会话（补拉丢的消息）
        bootstrap(0).catch(() => {});
        connectWs();
      }
    }, delay);
  };

  ws.onerror = () => {
    // onclose 会触发重连
  };
}

function start() {
  const id = ++loopId;
  running = true;
  syncFailures.value = 0;
  // 等 auth/user 就绪再连（enterMain 里 bootstrap 后调用）
  setTimeout(() => {
    if (id === loopId && running && useAuthStore().token) {
      connectWs();
    }
  }, 50);
}

function stop() {
  running = false;
  loopId++;
  clearInterval(heartbeatTimer);
  if (ws) {
    try { ws.close(); } catch (_) {}
    ws = null;
  }
  syncStatus.value = 'connecting';
  // 需求⑤：登出时清空所有会话的消息缓存
  clearAllMessageCaches();
}

export function useSync() {
  return { syncStatus, syncFailures, bootstrap, start, stop, applySyncPacket: applyEvent };
}
