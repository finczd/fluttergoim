import { defineStore } from 'pinia';
import { ref } from 'vue';
import api from '../api/client';
import { cryptoRandom } from '../utils/helpers';
import { useAuthStore } from './auth';
import { useUiStore } from './ui';
import { useConversationsStore } from './conversations';

export const useMessagesStore = defineStore('messages', () => {
  const current = ref(null);
  const currentDetail = ref(null);
  const messages = ref([]);
  const pins = ref([]);
  const hasMoreMessages = ref(false);
  const loadingOlder = ref(false);
  const replyTo = ref(null);
  const drafts = ref({});
  const draftDirty = ref(false);
  const readState = ref({});
  // 自增信号：发消息/收消息都 +1，MessageList 监听后强制滚到底（不受 isNearBottom 限制）
  const scrollSignal = ref(0);

  let messageLoopId = 0;

  function mergeMessages(rows, prepend = false) {
    const byId = new Map();
    const byClient = new Map();
    for (const m of messages.value) {
      byId.set(String(m.id), m);
      if (m.client_msg_id) byClient.set(m.client_msg_id, m);
    }
    for (const row of rows || []) {
      const id = String(row.id);
      let target = byId.get(id);
      if (!target && row.client_msg_id && byClient.has(row.client_msg_id)) target = byClient.get(row.client_msg_id);
      if (target) {
        Object.assign(target, row);
        target.local_status = row.local_status || '';
        target.delivery_state = row.delivery_state || '';
        if (id && id !== 'null' && id !== 'undefined') target.id = id;
      } else {
        byId.set(id, row);
      }
    }
    messages.value = [...byId.values()].sort((a, b) => {
      // seq 服务端单调递增；乐观消息 seq=0 排最后（发送中）
      const sa = Number(a.seq || 0);
      const sb = Number(b.seq || 0);
      if (sa && sb) return sa - sb;
      if (sa) return -1;
      if (sb) return 1;
      return String(a.id).localeCompare(String(b.id));
    });
    scrollSignal.value += 1;
    return true;
  }

  async function openConversation(id, render = true) {
    const conversations = useConversationsStore();
    const ui = useUiStore();
    // 切换会话时：关闭右侧资料卡片 / 群聊卡片 / 撤回正在编辑的回复
    ui.closeInspector();
    ui.closeContact();
    if (!id) return;
    current.value = conversations.findById(id) || { id };
    messages.value = [];
    pins.value = [];
    hasMoreMessages.value = false;
    localStorage.setItem('qm_pc_current_conversation', String(id));
    const loopId = ++messageLoopId;
    try {
      const bootstrap = await api('conversations/bootstrap', { conversation_id: id });
      if (loopId !== messageLoopId) return;
      current.value = { ...(current.value || {}), ...bootstrap.conversation };
      currentDetail.value = bootstrap.conversation;
      pins.value = bootstrap.pins || [];
      hasMoreMessages.value = Boolean(bootstrap.has_more);
      mergeMessages(bootstrap.messages || [], false);
      applyReadState(bootstrap.read_state);
      clearReply();
      scheduleReadReceipt();
    } catch (error) {
      throw error;
    }
  }

  async function loadOlderMessages() {
    if (!current.value || loadingOlder.value || !hasMoreMessages.value) return;
    const first = messages.value.find(item => item.id && String(item.id) !== '0');
    if (!first) return;
    loadingOlder.value = true;
    try {
      const rows = await api('messages', { conversation_id: current.value.id, before_id: first.id });
      hasMoreMessages.value = Array.isArray(rows) && rows.length >= 50;
      mergeMessages(rows || [], false);
    } catch (error) {
      useUiStore().toast('历史消息加载失败', error.message, 'error');
    } finally {
      loadingOlder.value = false;
    }
  }

  function setReply(message) {
    if (!message) return;
    replyTo.value = {
      id: String(message.id),
      sender_name: message.sender_name || '用户',
      type: message.type,
      content: message.content,
      file_name: message.file_name
    };
  }
  function clearReply() {
    replyTo.value = null;
  }

  async function sendMessage(payload = {}, retryMessage = null) {
    const auth = useAuthStore();
    const conversations = useConversationsStore();
    const ui = useUiStore();
    if (!current.value) return;
    const text = retryMessage ? String(retryMessage.retry_payload?.content || retryMessage.content || '') : payload.content ?? '';
    if (!payload.message_type && !retryMessage && !String(text).trim()) return;

    const clientId = retryMessage?.client_msg_id || 'pc_' + Date.now() + '_' + cryptoRandom(12);
    const requestPayload =
      retryMessage?.retry_payload || {
        conversation_id: String(current.value.id),
        client_msg_id: clientId,
        message_type: payload.message_type || 'text',
        content: payload.content ?? text,
        reply_to_id: replyTo.value ? String(replyTo.value.id) : 0,
        ...payload
      };

    let optimistic = retryMessage;
    if (!optimistic) {
      optimistic = {
        id: 'local_' + clientId,
        client_msg_id: clientId,
        conversation_id: String(current.value.id),
        sender_id: String(auth.user?.id || ''),
        sender_name: auth.user?.nickname || '我',
        sender_avatar: auth.user?.avatar || '',
        message_type: requestPayload.message_type,
        type: requestPayload.message_type,
        content: requestPayload.content || '',
        file_url: requestPayload.file_url || '',
        file_name: requestPayload.file_name || '',
        file_size: Number(requestPayload.file_size || 0),
        duration: Number(requestPayload.duration || 0),
        extra: requestPayload.extra || {},
        reply: replyTo.value ? { ...replyTo.value } : null,
        status: 1,
        is_mine: true,
        delivery_state: 'sending',
        local_status: 'sending',
        local_created_ms: Date.now(),
        created_at: new Date().toISOString().slice(0, 19).replace('T', ' '),
        retry_payload: requestPayload
      };
      mergeMessages([optimistic], false);
      clearReply();
    } else {
      optimistic.local_status = 'sending';
      optimistic.retry_payload = requestPayload;
    }
    try {
      const message = await api('messages/send', requestPayload, 'POST');
      mergeMessages([message], false);
      await conversations.load(false);
    } catch (error) {
      optimistic.local_status = 'failed';
      optimistic.retry_payload = requestPayload;
      ui.toast('消息发送失败', error.message, 'error');
    }
  }

  // 通话信令：invite / accept / reject / cancel / hangup
  // 与 sendMessage 的区别：不走 current.value（来电所属会话未必是当前打开的会话），
  // 也不做乐观插入（信令只驱动通话状态，可见的通话记录由 hangup 那条消息承载）
  async function sendCallSignal(convId, action, callType = 'voice', extra = {}) {
    if (!convId) return;
    const auth = useAuthStore();
    try {
      await api('messages/send', {
        conversation_id: String(convId),
        client_msg_id: 'call_' + action + '_' + Date.now(),
        message_type: 'call',
        type: 7,
        content: JSON.stringify({
          action,
          callType,
          roomId: String(convId),
          callerName: auth.user?.nickname || '',
          ts: Date.now(),
          ...extra
        })
      }, 'POST');
    } catch (_) { /* 信令失败不阻断 UI */ }
  }

  // 发红包 / 转账：构造 content JSON（对齐移动端 chat_page._openMoneyPage），乐观插入
  async function sendMoney(payload = {}) {
    const auth = useAuthStore();
    const conversations = useConversationsStore();
    const ui = useUiStore();
    if (!current.value) return;
    const kind = payload.kind === 'transfer' ? 'transfer' : 'redpacket';
    const contentData = {
      kind,
      amount: Number(payload.amount || 0),
      note: payload.note || '',
      ts: Date.now()
    };
    if (kind === 'redpacket') {
      contentData.mode = payload.mode === 'lucky' ? 'lucky' : 'normal';
      contentData.count = Number(payload.count || 1);
    } else {
      // 转账：收款人 = 当前会话对方（单聊）
      const peerId = payload.toUserId || current.value.peer?.id || '';
      contentData.toUserId = String(peerId);
      contentData.toName = payload.toName || current.value.peer?.nickname || current.value.title || '';
    }
    const clientId = 'pc_' + Date.now() + '_' + cryptoRandom(12);
    const requestPayload = {
      conversation_id: String(current.value.id),
      client_msg_id: clientId,
      message_type: kind,
      content: JSON.stringify(contentData)
    };
    const optimistic = {
      id: 'local_' + clientId,
      client_msg_id: clientId,
      conversation_id: String(current.value.id),
      sender_id: String(auth.user?.id || ''),
      sender_name: auth.user?.nickname || '我',
      sender_avatar: auth.user?.avatar || '',
      message_type: kind,
      type: kind,
      content: JSON.stringify(contentData),
      file_url: '',
      file_name: '',
      file_size: 0,
      duration: 0,
      extra: {},
      reply: null,
      status: 1,
      is_mine: true,
      delivery_state: 'sending',
      local_status: 'sending',
      local_created_ms: Date.now(),
      created_at: new Date().toISOString().slice(0, 19).replace('T', ' '),
      retry_payload: requestPayload
    };
    mergeMessages([optimistic], false);
    try {
      const message = await api('messages/send', requestPayload, 'POST');
      mergeMessages([message], false);
      // 发红包/转账的扣款已由服务端在发消息时原子完成（B-19），
      // 这里**绝对不能再调 wallet/record 记支出**，否则会重复扣款。
      // 发送成功即代表已扣款成功，余额由服务端保证一致。
      await conversations.load(false);
    } catch (error) {
      optimistic.local_status = 'failed';
      optimistic.retry_payload = requestPayload;
      ui.toast('发送失败', error.message, 'error');
    }
  }

  function retryFailedMessage(tempId) {
    const message = messages.value.find(item => String(item.id) === String(tempId));
    if (message && message.local_status === 'failed') sendMessage({}, message);
  }

  async function recallMessage(id) {
    try {
      await api('messages/recall', { message_id: String(id) }, 'POST');
      const message = messages.value.find(item => String(item.id) === String(id));
      if (message) {
        message.status = 2;
        message.content = '消息已撤回';
        message.file_url = '';
      }
    } catch (error) {
      useUiStore().toast('撤回失败', error.message, 'error');
    }
  }

  // 编辑已发送的文本消息（仅客服 is_agent=1；后端二次校验）
  async function editMessage(id, content) {
    const ui = useUiStore();
    const message = messages.value.find(item => String(item.id) === String(id));
    if (!message || !message.is_mine || message.type !== 'text') return;
    const trimmed = String(content ?? '').trim();
    if (!trimmed) {
      ui.toast('消息内容不能为空', '', 'error');
      return;
    }
    try {
      const r = await api('messages/edit', { message_id: String(id), content: trimmed }, 'POST');
      message.content = r.content ?? trimmed;
      message.edited_at = r.edited_at || new Date().toISOString().slice(0, 19).replace('T', ' ');
      message.edit_count = Number(r.edit_count || 0);
      ui.toast('消息已编辑');
    } catch (error) {
      ui.toast('编辑失败', error.message, 'error');
    }
  }

  async function favoriteMessage(id) {
    try {
      await api('messages/favorite', { message_id: String(id), conversation_id: String(current.value?.id || '') }, 'POST');
      useUiStore().toast('已收藏');
    } catch (error) {
      useUiStore().toast('收藏失败', error.message, 'error');
    }
  }

  // 群公告：标记已读（成员点 × 关闭置顶公告横幅）
  async function dismissAnnouncement(announcementId) {
    const ui = useUiStore();
    try {
      await api('groups/announcement/read', { announcement_id: String(announcementId) }, 'POST');
      // 乐观更新本地 currentDetail，避免再拉一次 conversations/detail
      if (currentDetail.value?.announcement && String(currentDetail.value.announcement.id) === String(announcementId)) {
        currentDetail.value.announcement.has_read = true;
      }
      return true;
    } catch (error) {
      ui.toast('操作失败', error.message, 'error');
      return false;
    }
  }

  // 置顶 / 取消置顶
  async function pinMessage(messageId, pinned = true) {
    const ui = useUiStore();
    try {
      // 需求3修复：必须传 conversation_id，否则后端 URL 变 /conversation//pin-message → 1003
      const convId = String(current.value?.id || '');
      const msg = messages.value.find(item => String(item.id) === String(messageId));
      await api('messages/pin', {
        message_id: String(messageId),
        conversation_id: convId,
        content: msg?.content || '',
        pinned: !!pinned
      }, 'POST');
      ui.toast(pinned ? '已置顶' : '已取消置顶');
      // 重新拉置顶列表
      if (convId) {
        try {
          pins.value = (await api('messages/pins', { conversation_id: convId })) || [];
        } catch (_) {}
      }
    } catch (error) {
      ui.toast('操作失败', error.message, 'error');
    }
  }
  // 判断消息是否已置顶
  function isPinned(messageId) {
    return Array.isArray(pins.value) && pins.value.some(p => String(p.message_id) === String(messageId) || String(p.id) === String(messageId));
  }

  async function openDirect(userId) {
    const conversations = useConversationsStore();
    const ui = useUiStore();
    try {
      const conversation = await api('conversations/direct', { user_id: String(userId) }, 'POST');
      if (!conversations.list.some(item => String(item.id) === String(conversation.id))) conversations.list.unshift(conversation);
      ui.view = 'chats';
      await openConversation(conversation.id);
    } catch (error) {
      ui.toast('无法发起聊天', error.message, 'error');
    }
  }

  // —— 草稿 ——
  function draftFor(id) {
    const row = drafts.value[String(id)];
    return row?.content || '';
  }
  function clearDraft(id) {
    if (drafts.value[String(id)]) {
      delete drafts.value[String(id)];
      persistDraftCache();
    }
  }
  function saveDraft(id, content) {
    if (content) drafts.value[String(id)] = { conversation_id: String(id), content, origin_device_id: '' };
    else clearDraft(id);
    draftDirty.value = false;
    persistDraftCache();
  }
  function persistDraftCache() {
    try {
      localStorage.setItem('qm_pc_draft_cache', JSON.stringify(drafts.value));
    } catch (_) {}
  }
  function normalizeDraftRows(rows) {
    const next = {};
    for (const row of rows || []) {
      if (row?.conversation_id) next[Number(row.conversation_id)] = row;
    }
    drafts.value = next;
  }

  function applyReadState(stateMap) {
    if (stateMap && typeof stateMap === 'object') readState.value = { ...readState.value, ...stateMap };
  }
  async function scheduleReadReceipt() {
    if (!current.value) return;
    const lastMine = [...messages.value].reverse().find(m => m.id && String(m.id) !== '0' && !m.is_mine);
    if (!lastMine) return;
    try {
      await api('messages/read', { conversation_id: String(current.value.id), message_id: String(lastMine.id) }, 'POST');
    } catch (_) {}
  }

  return {
    current, currentDetail, messages, pins, hasMoreMessages, loadingOlder, replyTo, drafts, draftDirty, readState, scrollSignal,
    mergeMessages, openConversation, loadOlderMessages, sendMessage, sendMoney, sendCallSignal, retryFailedMessage,
    recallMessage, editMessage, favoriteMessage, pinMessage, isPinned, dismissAnnouncement, openDirect, setReply, clearReply,
    draftFor, clearDraft, saveDraft, persistDraftCache, normalizeDraftRows, applyReadState, scheduleReadReceipt
  };
});
