import { defineStore } from 'pinia';
import { ref } from 'vue';

// 全局 UI 状态：视图切换、主题、Toast、弹窗、Inspector、右键菜单、通话层。
export const useUiStore = defineStore('ui', () => {
  const view = ref(localStorage.getItem('qm_pc_view') || 'chats');
  const filter = ref('all');
  const search = ref('');
  const theme = ref(localStorage.getItem('qm_pc_theme') || 'system');
  const showViewport = ref(false);

  const toasts = ref([]);
  let toastSeq = 0;
  function toast(title, message = '', type = 'success', duration = 2600) {
    const id = ++toastSeq;
    toasts.value.push({ id, title, message, type });
    setTimeout(() => {
      toasts.value = toasts.value.filter(t => t.id !== id);
    }, duration);
  }

  const modal = ref({ open: false, title: '操作', kicker: '即时通讯', body: '', footer: '' });
  function openModal(title, body, footer = '', kicker = '即时通讯') {
    modal.value = { open: true, title, kicker, body, footer };
  }
  function closeModal() {
    modal.value = { ...modal.value, open: false };
  }

  const inspector = ref({ open: false, title: '详情', kind: 'html', user: null, conversation: null, body: '' });
  function openInspector(title, body) {
    inspector.value = { open: true, title, kind: 'html', user: null, conversation: null, body };
  }
  function openUserInspector(user) {
    inspector.value = { open: true, title: '个人资料', kind: 'user', user, conversation: null, body: '' };
  }
  function openConversationInspector(conversation) {
    const title = conversation?.type === 'group' ? '群聊详情' : '联系人资料';
    inspector.value = { open: true, title, kind: 'conversation', user: null, conversation, body: '' };
  }
  function closeInspector() {
    inspector.value = { ...inspector.value, open: false };
  }

  const contextMenu = ref({ open: false, x: 0, y: 0, items: [] });
  // 通讯录：点击好友后在右侧工作区展示联系人卡片
  const selectedContact = ref(null);
  function openContact(contact) {
    selectedContact.value = contact || null;
  }
  function closeContact() {
    selectedContact.value = null;
  }
  function openContextMenu(x, y, items) {
    contextMenu.value = { open: true, x, y, items };
  }
  function closeContextMenu() {
    contextMenu.value = { ...contextMenu.value, open: false };
  }

  // 编辑消息浮层：当前正在编辑的消息（仅客服可用）
  const editingMessage = ref(null);
  function openEditMessage(message) {
    editingMessage.value = message || null;
  }
  function closeEditMessage() {
    editingMessage.value = null;
  }

  const call = ref({ open: false, id: 0, type: 'voice', title: '通话' });
  function openCall(id, type = 'voice', title = '通话') {
    call.value = { open: true, id: Number(id), type, title };
  }
  function closeCall() {
    call.value = { ...call.value, open: false, id: 0 };
  }

  function setTheme(next, persist = true) {
    const normalized = ['light', 'dark', 'system'].includes(next) ? next : 'system';
    const effective = normalized === 'system' ? (matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light') : normalized;
    document.documentElement.dataset.theme = effective;
    theme.value = normalized;
    if (persist) localStorage.setItem('qm_pc_theme', normalized);
  }
  function initTheme() {
    setTheme(theme.value, false);
  }

  return {
    view, filter, search, theme, showViewport,
    toasts, modal, inspector, contextMenu, call, selectedContact,
    toast, openModal, closeModal, openInspector, openUserInspector, openConversationInspector, closeInspector,
    openContextMenu, closeContextMenu, editingMessage, openEditMessage, closeEditMessage, openCall, closeCall, openContact, closeContact,
    setTheme, initTheme
  };
});
