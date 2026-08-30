<script setup>
import { ref, computed, watch } from 'vue';
import { useUiStore } from '../stores/ui';
import { useConversationsStore } from '../stores/conversations';
import { useContactsStore } from '../stores/contacts';
import { useMessagesStore } from '../stores/messages';
import { useContentStore } from '../stores/content';
import { useAuthStore } from '../stores/auth';
import { useDialogs } from '../composables/useDialogs';
import { useMediaPreview } from '../composables/useMediaPreview';
import api from '../api/client';
import Avatar from './Avatar.vue';
import { preview, timeText, formatBytes, initials } from '../utils/format';

const ui = useUiStore();
const conversations = useConversationsStore();
const contacts = useContactsStore();
const messages = useMessagesStore();
const content = useContentStore();
const auth = useAuthStore();
const dialogs = useDialogs();
const { openMedia } = useMediaPreview();

const META = {
  chats: { kicker: '沟通', title: '消息', placeholder: '搜索会话', filters: [['all', '全部'], ['unread', '未读']], action: '添加好友' },
  contacts: { kicker: '通讯录', title: '联系人', placeholder: '搜索联系人', filters: [['all', '联系人'], ['requests', '新的朋友']], action: '添加联系人' },
  groups: { kicker: '协作', title: '群聊', placeholder: '搜索群聊', filters: [['all', '全部群聊'], ['unread', '未读']], action: '发起群聊' },
  favorites: { kicker: '个人内容', title: '收藏', placeholder: '搜索收藏内容', filters: [], action: '' },
  files: { kicker: '个人内容', title: '文件', placeholder: '搜索文件', filters: [['all', '全部'], ['image', '图片'], ['video', '视频'], ['file', '文件']], action: '' },
  settings: { kicker: '偏好', title: '设置', placeholder: '搜索设置', filters: [], action: '' }
};
const meta = computed(() => META[ui.view] || META.chats);

const query = computed(() => ui.search.toLowerCase());

const conversationList = computed(() => {
  const list = conversations.list;
  const isGroup = ui.view === 'groups';
  return list
    .filter(item => (!isGroup || item.type === 'group'))
    .filter(item => ui.filter !== 'unread' || Number(item.unread_count) > 0)
    .filter(item => {
      if (!query.value) return true;
      const text = (item.title || '') + ' ' + preview(item.last_message || {});
      return text.toLowerCase().includes(query.value);
    });
});

const friendList = computed(() => {
  const list = ui.filter === 'requests' ? contacts.requests : contacts.friends;
  if (!query.value) return list;
  return list.filter(item => String(item.nickname || item.remark || item.username || '').toLowerCase().includes(query.value));
});

// 收藏（左侧列表，对齐原编译版 favoriteRow）
const favList = computed(() =>
  content.favorites.filter(it => !query.value || `${it.content || ''} ${it.sender_name || ''} ${it.conversation_title || ''}`.toLowerCase().includes(query.value))
);
// 文件（左侧列表，对齐原编译版 mediaRow）
const mediaList = computed(() =>
  content.media.filter(
    it => (ui.filter === 'all' || it.type === ui.filter) && (!query.value || `${it.file_name || ''} ${it.conversation_title || ''}`.toLowerCase().includes(query.value))
  )
);

const settingsNav = [
  { key: 'notice', label: '通知与提醒', preview: '查看并修改通知设置' },
  { key: 'privacy', label: '隐私与安全', preview: '查看并修改隐私设置' },
  { key: 'appearance', label: '外观与语言', preview: '主题与语言设置' },
  { key: 'about', label: '关于系统', preview: '版本与许可信息' }
];

const catalogStatus = computed(() => {
  if (ui.view === 'chats') return `${conversations.list.length} 个会话`;
  if (ui.view === 'groups') return `${conversations.list.filter(i => i.type === 'group').length} 个群聊`;
  if (ui.view === 'contacts') return ui.filter === 'requests' ? `${contacts.requests.length} 条申请` : `${contacts.friends.length} 位联系人`;
  if (ui.view === 'favorites') return `${content.favorites.length} 条收藏`;
  if (ui.view === 'files') return `${content.media.length} 个文件`;
  return '';
});

// 进入收藏/文件视图时确保数据已加载
watch(
  () => ui.view,
  v => {
    if (v === 'favorites' && !content.favorites.length) content.loadFavorites().catch(() => {});
    if (v === 'files' && !content.media.length) content.loadMedia().catch(() => {});
  },
  { immediate: true }
);

function onAction() {
  // 需求12：消息页 + 号改为"添加好友"（不能直接输 ID 建聊）
  if (ui.view === 'chats') dialogs.open('add-friend');
  else if (ui.view === 'contacts') dialogs.open('add-friend');
  else if (ui.view === 'groups') dialogs.open('create-group');
}
function openConversation(id) {
  messages.openConversation(String(id));
}
// 通讯录：点击好友 → 右侧工作区展示联系人卡片（含"发送消息"按钮），再异步补齐详细资料
async function openUser(userOrId) {
  const fallback = userOrId && typeof userOrId === 'object' ? userOrId : null;
  const userId = String(fallback ? fallback.id : userOrId);
  if (!userId) return;
  ui.openContact({ ...(fallback || {}), id: userId });
  try {
    const detail = await api('users/detail', { user_id: userId });
    if (detail && String(ui.selectedContact?.id) === userId) {
      ui.openContact({ ...(fallback || {}), ...detail, id: userId });
    }
  } catch (_) {
    /* 保留列表里的基础数据即可 */
  }
}
function openFavorite(convId) {
  if (convId) messages.openConversation(String(convId));
}
function openMediaItem(item) {
  const r = openMedia(item);
  if (!r.ok) ui.toast('文件地址不可用', '', 'error');
}
</script>

<template>
  <aside class="catalog-pane">
    <header class="catalog-header">
      <div>
        <span class="catalog-kicker">{{ meta.kicker }}</span>
        <h1>{{ meta.title }}</h1>
      </div>
      <button v-if="meta.action" class="icon-button" type="button" :title="meta.action" @click="onAction">
        <svg><use href="#i-plus" /></svg>
      </button>
    </header>

    <div class="catalog-search">
      <svg><use href="#i-search" /></svg>
      <input v-model="ui.search" :placeholder="meta.placeholder" />
      <button v-if="ui.search" class="clear-search" type="button" aria-label="清空" @click="ui.search = ''">
        <svg><use href="#i-close" /></svg>
      </button>
    </div>

    <div v-if="meta.filters.length" class="catalog-filters">
      <button
        v-for="(f, i) in meta.filters"
        :key="f[0]"
        type="button"
        :class="{ active: ui.filter === f[0] }"
        :data-filter="f[0]"
        @click="ui.filter = f[0]"
      >
        {{ f[1] }}
      </button>
    </div>

    <div class="catalog-list" aria-live="polite">
      <!-- 消息 / 群聊 -->
      <template v-if="ui.view === 'chats' || ui.view === 'groups'">
        <div v-if="!conversationList.length" class="empty-list-state"><strong>暂无会话</strong><span>新建聊天开始沟通</span></div>
        <button
          v-for="item in conversationList"
          :key="item.id"
          class="catalog-item"
          :class="{ active: String(messages.current?.id) === String(item.id) }"
          type="button"
          @click="openConversation(item.id)"
        >
          <span class="avatar-wrap">
            <Avatar :user="item" size="medium" />
            <span v-if="item.type === 'direct'" class="status-corner" :class="item.peer?.is_online ? 'online' : 'offline'"></span>
          </span>
          <span class="catalog-item-main">
            <span class="catalog-item-top">
              <span class="catalog-item-title">{{ item.title || '未命名会话' }}</span>
              <span class="catalog-item-time">{{ timeText(item.last_message?.created_at) }}</span>
            </span>
            <span class="catalog-item-bottom">
              <span class="catalog-preview">{{ preview(item.last_message) }}</span>
              <span v-if="Number(item.unread_count)" class="unread-badge">{{ item.unread_count > 99 ? '99+' : item.unread_count }}</span>
            </span>
          </span>
        </button>
      </template>

      <!-- 联系人 -->
      <template v-else-if="ui.view === 'contacts'">
        <div v-if="!friendList.length" class="empty-list-state"><strong>暂无{{ ui.filter === 'requests' ? '好友申请' : '联系人' }}</strong></div>

        <!-- 新的朋友：显示昵称/账号 + 通过/拒绝按钮 -->
        <template v-if="ui.filter === 'requests'">
          <button
            v-for="r in friendList"
            :key="r.id"
            class="catalog-item request-card"
            type="button"
          >
            <Avatar :user="{ nickname: r.sender_name, avatar: r.sender_avatar }" size="medium" />
            <span class="catalog-item-main">
              <span class="catalog-item-top">
                <span class="catalog-item-title">{{ r.sender_name || '用户' }}</span>
                <span class="catalog-item-time">{{ timeText(r.created_at) }}</span>
              </span>
              <span class="catalog-item-bottom">
                <span class="catalog-preview">{{ r.sender_account || '' }} {{ r.message ? '：' + r.message : '' }}</span>
              </span>
              <span class="request-actions" @click.stop>
                <button class="mini-button primary" type="button" @click="contacts.respondFriendRequest(r.id, true)">通过</button>
                <button class="mini-button" type="button" @click="contacts.respondFriendRequest(r.id, false)">拒绝</button>
              </span>
            </span>
          </button>
        </template>

        <!-- 联系人列表 -->
        <button
          v-else
          v-for="u in friendList"
          :key="u.id"
          class="catalog-item"
          type="button"
          @click="openUser(u.id)"
        >
          <Avatar :user="u" size="medium" />
          <span class="catalog-item-main">
            <span class="catalog-item-top"><span class="catalog-item-title">{{ u.remark || u.nickname || u.username }}</span></span>
            <span class="catalog-item-bottom"><span class="catalog-preview">{{ u.online_text || '离线' }}</span></span>
          </span>
        </button>
      </template>

      <!-- 收藏 -->
      <template v-else-if="ui.view === 'favorites'">
        <div v-if="!favList.length" class="empty-list-state"><strong>暂无收藏</strong><span>收藏的消息会显示在这里</span></div>
        <button
          v-for="item in favList"
          :key="item.id"
          class="catalog-item"
          type="button"
          @click="openFavorite(item.conversation_id)"
        >
          <span class="avatar medium">★</span>
          <span class="catalog-item-main">
            <span class="catalog-item-top"><span class="catalog-item-title">{{ item.conversation_title || item.sender_name || '收藏消息' }}</span></span>
            <span class="catalog-item-bottom"><span class="catalog-preview">{{ preview(item) }}</span></span>
          </span>
          <span class="catalog-item-time">{{ timeText(item.favorited_at || item.created_at) }}</span>
        </button>
      </template>

      <!-- 文件 -->
      <template v-else-if="ui.view === 'files'">
        <div v-if="!mediaList.length" class="empty-list-state"><strong>暂无文件</strong><span>聊天中的文件会自动归集到这里</span></div>
        <button
          v-for="item in mediaList"
          :key="item.id"
          class="catalog-item"
          type="button"
          @click="openMediaItem(item)"
        >
          <span class="avatar medium">{{ item.type === 'image' ? '图' : item.type === 'video' ? '视' : item.type === 'voice' ? '音' : '文' }}</span>
          <span class="catalog-item-main">
            <span class="catalog-item-top"><span class="catalog-item-title">{{ item.file_name || ({ image: '图片', video: '视频', voice: '语音' }[item.type] || '文件') }}</span></span>
            <span class="catalog-item-bottom"><span class="catalog-preview">{{ item.conversation_title || '' }} · {{ formatBytes(item.file_size) }}</span></span>
          </span>
          <span class="catalog-item-time">{{ timeText(item.created_at) }}</span>
        </button>
      </template>

      <!-- 设置 -->
      <template v-else-if="ui.view === 'settings'">
        <button class="catalog-item active" type="button">
          <span class="avatar medium">{{ initials(auth.user?.nickname) }}</span>
          <span class="catalog-item-main">
            <span class="catalog-item-top"><span class="catalog-item-title">{{ auth.user?.nickname || '我的账号' }}</span></span>
            <span class="catalog-item-bottom"><span class="catalog-preview">账号：{{ auth.user?.public_id || auth.user?.username || '' }}</span></span>
          </span>
        </button>
        <div class="section-label">设置分类</div>
        <button
          v-for="s in settingsNav"
          :key="s.key"
          class="catalog-item settings-catalog"
          type="button"
        >
          <span class="catalog-item-main">
            <span class="catalog-item-top"><span class="catalog-item-title">{{ s.label }}</span></span>
            <span class="catalog-item-bottom"><span class="catalog-preview">{{ s.preview }}</span></span>
          </span>
          <svg><use href="#i-chevron" /></svg>
        </button>
      </template>
    </div>

    <footer v-if="catalogStatus" class="catalog-status">{{ catalogStatus }}</footer>
  </aside>
</template>
