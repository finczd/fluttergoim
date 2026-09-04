<script setup>
import { ref, computed } from 'vue';
import { useUiStore } from '../stores/ui';
import { useAuthStore } from '../stores/auth';
import { useConversationsStore } from '../stores/conversations';
import { useContactsStore } from '../stores/contacts';
import { useNavigation } from '../composables/useNavigation';
import Avatar from './Avatar.vue';
import ProfileEdit from './ProfileEdit.vue';

const ui = useUiStore();
const auth = useAuthStore();
const conversations = useConversationsStore();
const contacts = useContactsStore();
const { switchView } = useNavigation();

const showProfile = ref(false);
const showProfileEdit = ref(false);

const rail = [
  { view: 'chats', label: '消息', icon: 'i-chat' },
  { view: 'contacts', label: '联系人', icon: 'i-contact' },
  { view: 'groups', label: '群聊', icon: 'i-group' },
  { view: 'favorites', label: '收藏', icon: 'i-star' },
  { view: 'files', label: '文件', icon: 'i-folder' },
  { view: 'moments', label: '朋友圈', icon: 'i-moments' }
];

const chatBadge = computed(() => (conversations.totalUnread > 99 ? '99+' : String(conversations.totalUnread)));
const contactBadge = computed(() => (contacts.requestCount > 9 ? '9+' : String(contacts.requestCount)));

function onRail(v) {
  showProfile.value = false;
  switchView(v);
}
function themeToggle() {
  const cur = document.documentElement.dataset.theme;
  ui.setTheme(cur === 'dark' ? 'light' : 'dark');
}
function logout() {
  showProfile.value = false;
  auth.logout();
}
function openProfile() {
  showProfile.value = false;
  showProfileEdit.value = true;
}
</script>

<template>
  <nav class="app-rail" aria-label="主导航">
    <button class="rail-brand" type="button" :title="auth.brand.name" data-brand-mark>{{ auth.brand.mark }}</button>
    <div class="rail-nav">
      <button
        v-for="r in rail"
        :key="r.view"
        class="rail-button"
        :class="{ active: ui.view === r.view }"
        :data-view="r.view"
        :data-label="r.label"
        :title="r.label"
        type="button"
        @click="onRail(r.view)"
      >
        <svg><use :href="'#' + r.icon" /></svg>
        <span
          v-if="(r.view === 'chats' && conversations.totalUnread > 0) || (r.view === 'contacts' && contacts.requestCount > 0)"
          class="rail-badge"
          >{{ r.view === 'chats' ? chatBadge : contactBadge }}</span
        >
      </button>
    </div>
    <div class="rail-bottom">
      <button class="rail-button" :class="{ active: ui.view === 'settings' }" data-label="设置" type="button" title="设置" @click="onRail('settings')">
        <svg><use href="#i-settings" /></svg>
      </button>
      <button class="self-avatar" data-label="我" type="button" :title="auth.user?.nickname || '我'" @click="showProfile = !showProfile">
        <Avatar :user="auth.user" size="medium" />
      </button>
    </div>
    <div v-if="showProfile" class="popover profile-menu">
      <button type="button" @click="openProfile"><svg><use href="#i-contact" /></svg><span>个人资料</span></button>
      <button type="button" @click="themeToggle"><svg><use href="#i-moon" /></svg><span>切换主题</span></button>
      <button type="button" class="danger" @click="logout"><svg><use href="#i-logout" /></svg><span>退出登录</span></button>
    </div>
    <ProfileEdit v-if="showProfileEdit" @close="showProfileEdit = false" />
  </nav>
</template>
