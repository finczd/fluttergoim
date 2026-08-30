import { useUiStore } from '../stores/ui';
import { useMessagesStore } from '../stores/messages';
import api from '../api/client';

// 打开用户资料面板（右侧 Inspector）。优先用已传入的用户对象，否则按 id 拉取详情。
export function useInspector() {
  const ui = useUiStore();
  const messages = useMessagesStore();

  async function openUser(userId, fallback = null) {
    if (fallback) ui.openUserInspector(fallback);
    else ui.openUserInspector({ id: String(userId), nickname: '用户' });
    try {
      const user = await api('users/detail', { user_id: String(userId) });
      if (ui.inspector.kind === 'user') ui.openUserInspector(user);
    } catch (_) {}
  }

  // 打开会话资料面板：群聊显示成员，单聊显示对方
  async function openConversation(conversation) {
    const conv = conversation || messages.current;
    if (!conv) return;
    const id = String(conv.id);
    if (!id) return;
    // 先复用已有的 currentDetail（通常已含 members）立即渲染，避免点击后空白等待
    let detail = messages.currentDetail && String(messages.currentDetail.id) === id ? messages.currentDetail : conv;
    ui.openConversationInspector(detail);
    if (conv.type === 'group') {
      try {
        const fresh = await api('conversations/detail', { conversation_id: id });
        // 只在用户仍停在该会话的资料面板时才覆盖，避免切换会话后串数据
        if (fresh && ui.inspector.kind === 'conversation' && String(ui.inspector.conversation?.id) === id) {
          ui.openConversationInspector(fresh);
        }
      } catch (e) {
        ui.toast('群资料加载失败', e?.message || '', 'error');
      }
    }
  }

  function messageUser() {
    const user = ui.inspector.user;
    ui.closeInspector();
    if (user?.id) messages.openDirect(user.id);
  }

  function openMember(memberId) {
    if (memberId) openUser(String(memberId));
  }

  return { openUser, openConversation, messageUser, openMember };
}
