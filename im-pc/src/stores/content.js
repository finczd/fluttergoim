import { defineStore } from 'pinia';
import { ref } from 'vue';
import api from '../api/client';

export const useContentStore = defineStore('content', () => {
  const favorites = ref([]);
  const media = ref([]);

  async function loadFavorites() {
    try {
      favorites.value = (await api('messages/favorites')) || [];
    } catch (_) {}
    return favorites.value;
  }
  async function loadMedia() {
    try {
      media.value = (await api('me/media', { type: 'all' })) || [];
    } catch (_) {}
    return media.value;
  }
  return { favorites, media, loadFavorites, loadMedia };
});
