import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import api from '../api/client';
import { useContactsStore } from './contacts';

export const useConversationsStore = defineStore('conversations', () => {
  const list = ref([]);

  const totalUnread = computed(() => list.value.reduce((sum, item) => sum + Number(item.unread_count || 0), 0));
  const requestCount = computed(() => useContactsStore().requests.length);

  async function load(render = true) {
    try {
      list.value = (await api('conversations')) || [];
      if (render) return list.value;
    } catch (error) {
      if (render) throw error;
    }
    return list.value;
  }

  function findById(id) {
    return list.value.find(item => String(item.id) === String(id)) || null;
  }

  function upsert(conversation) {
    const idx = list.value.findIndex(item => String(item.id) === String(conversation.id));
    if (idx >= 0) list.value[idx] = { ...list.value[idx], ...conversation };
    else list.value.unshift(conversation);
  }

  return { list, totalUnread, requestCount, load, findById, upsert };
});
