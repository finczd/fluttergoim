import { ref } from 'vue';
import api from '../api/client';
import { useUiStore } from '../stores/ui';
import { useMessagesStore } from '../stores/messages';
import { useContactsStore } from '../stores/contacts';
import { useConversationsStore } from '../stores/conversations';

// 各类弹窗（新建聊天 / 加好友 / 建群 / 用户资料）的共享状态与动作。
const dialog = ref({ open: false, type: '', data: {} });

function open(type, data = {}) {
  dialog.value = { open: true, type, data };
}
function close() {
  dialog.value = { open: false, type: '', data: {} };
}

async function searchUsers(keyword) {
  if (!keyword) return [];
  try {
    return (await api('users/search', { keyword })) || [];
  } catch (_) {
    return [];
  }
}

async function startDirectWithUser(userId) {
  const messages = useMessagesStore();
  const conversations = useConversationsStore();
  const ui = useUiStore();
  try {
    const conv = await api('conversations/direct', { user_id: String(userId) }, 'POST');
    if (!conversations.list.some(i => String(i.id) === String(conv.id))) conversations.list.unshift(conv);
    close();
    await messages.openConversation(conv.id);
  } catch (e) {
    ui.toast('无法发起聊天', e.message, 'error');
  }
}

async function sendFriendRequest(userId, message = '') {
  const contacts = useContactsStore();
  const ui = useUiStore();
  // 后端 friends/request 读 friend_id + message（message 必填），不能传 user_id/remark
  const payload = { friend_id: String(userId) };
  const text = (message || '').trim();
  if (text) payload.message = text;
  try {
    await api('friends/request', payload, 'POST');
    ui.toast('已发送好友申请');
    await contacts.loadRequests(false);
    close();
  } catch (e) {
    ui.toast('操作失败', e.message, 'error');
  }
}

async function createGroup(title, memberIds) {
  const ui = useUiStore();
  const conversations = useConversationsStore();
  const messages = useMessagesStore();
  try {
    const conv = await api('conversations/create', { type: 'group', title, member_ids: memberIds.map(String) }, 'POST');
    conversations.list.unshift(conv);
    close();
    await messages.openConversation(conv.id);
  } catch (e) {
    ui.toast('建群失败', e.message, 'error');
  }
}

export function useDialogs() {
  return { dialog, open, close, searchUsers, startDirectWithUser, sendFriendRequest, createGroup };
}
