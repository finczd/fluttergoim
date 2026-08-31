import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import api from '../api/client';
import { useUiStore } from './ui';

export const useContactsStore = defineStore('contacts', () => {
  const friends = ref([]);
  const requests = ref([]);

  // 需求1：待处理好友申请数（通讯录/新朋友红点）
  const requestCount = computed(() => requests.value.filter(r => Number(r.status) === 0).length);

  async function loadFriends(render = true) {
    try {
      friends.value = (await api('friends')) || [];
    } catch (_) {}
    return friends.value;
  }
  async function loadRequests(render = true) {
    try {
      requests.value = (await api('friends/requests')) || [];
    } catch (_) {}
    return requests.value;
  }
  async function respondFriendRequest(requestId, accepted) {
    const ui = useUiStore();
    try {
      await api('friends/respond', { request_id: requestId, accepted }, 'POST');
      ui.toast(accepted ? '已添加好友' : '已拒绝申请');
      await Promise.all([loadRequests(false), loadFriends(false)]);
    } catch (error) {
      ui.toast('操作失败', error.message, 'error');
    }
  }
  async function addFriend(userId, message = '') {
    const ui = useUiStore();
    // 后端 friends/request 读 friend_id + message（message 必填）
    const payload = { friend_id: String(userId) };
    const text = (message || '').trim();
    if (text) payload.message = text;
    try {
      await api('friends/request', payload, 'POST');
      ui.toast('已发送好友申请');
    } catch (error) {
      ui.toast('操作失败', error.message, 'error');
    }
  }

  return { friends, requests, requestCount, loadFriends, loadRequests, respondFriendRequest, addFriend };
});
