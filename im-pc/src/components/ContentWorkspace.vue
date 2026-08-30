<script setup>
import { ref, computed, watch } from 'vue';
import { useUiStore } from '../stores/ui';
import { useContentStore } from '../stores/content';
import { useAuthStore } from '../stores/auth';
import { useMessagesStore } from '../stores/messages';
import { useMediaPreview } from '../composables/useMediaPreview';
import { preview as previewText, timeText, formatBytes, asset } from '../utils/format';
import Avatar from './Avatar.vue';
import api from '../api/client';

const ui = useUiStore();
const content = useContentStore();
const auth = useAuthStore();
const messages = useMessagesStore();
const { previewing, openMedia, closePreview, onKeydown } = useMediaPreview();

const query = computed(() => ui.search.toLowerCase());

const favRows = computed(() =>
  content.favorites.filter(it => !query.value || `${it.content || ''} ${it.sender_name || ''} ${it.conversation_title || ''}`.toLowerCase().includes(query.value))
);
const fileRows = computed(() =>
  content.media.filter(
    it =>
      (ui.filter === 'all' || it.type === ui.filter) &&
      (!query.value || `${it.file_name || ''} ${it.conversation_title || ''}`.toLowerCase().includes(query.value))
  )
);

const META = {
  favorites: { kicker: '个人内容', title: '收藏', sub: '跨会话保存的重要消息' },
  files: { kicker: '个人内容', title: '文件', sub: '统一查看聊天中的图片、视频与文件' },
  settings: { kicker: '偏好', title: '设置', sub: '同步管理桌面端通知、隐私与外观' }
};

// 进入对应视图时按需加载数据
watch(
  () => ui.view,
  v => {
    if (v === 'favorites' && !content.favorites.length) content.loadFavorites().catch(() => {});
    if (v === 'files' && !content.media.length) content.loadMedia().catch(() => {});
  },
  { immediate: true }
);

const theme = ref(auth.theme);
async function saveSettings() {
  auth.setTheme(theme.value);
  try {
    await api('me/preferences', { theme: theme.value }, 'POST');
    ui.toast('设置已保存');
  } catch (e) {
    ui.toast('保存失败', e.message, 'error');
  }
}

function openConv(id) {
  messages.openConversation(String(id));
}

// 媒体预览浮层状态来自共享 composable（左栏文件点击也复用同一浮层）
</script>

<template>
  <section class="content-workspace" tabindex="-1" @keydown="onKeydown">
    <header class="content-header">
      <div>
        <span class="catalog-kicker">{{ (META[ui.view] || {}).kicker }}</span>
        <h2>{{ (META[ui.view] || {}).title }}</h2>
        <p>{{ (META[ui.view] || {}).sub }}</p>
      </div>
    </header>

    <div class="content-body">
      <!-- 收藏 -->
      <div v-if="ui.view === 'favorites'">
        <div v-if="!favRows.length" class="empty-list-state"><strong>暂无收藏</strong><span>在消息右键菜单中选择"收藏"</span></div>
        <div v-else class="content-grid">
          <article
            v-for="item in favRows"
            :key="item.id"
            class="content-card clickable"
            @click="openConv(item.conversation_id)"
          >
            <div class="content-card-head">
              <Avatar :user="{ nickname: item.sender_name, avatar: item.sender_avatar }" size="medium" />
              <div><h3>{{ item.conversation_title || item.sender_name || '收藏消息' }}</h3><div class="catalog-kicker">{{ item.sender_name || '' }}</div></div>
            </div>
            <p>{{ previewText(item) }}</p>
            <div class="content-card-meta"><span>{{ timeText(item.favorited_at || item.created_at, true) }}</span><span>打开会话</span></div>
          </article>
        </div>
      </div>

      <!-- 文件 -->
      <div v-else-if="ui.view === 'files'">
        <div v-if="!fileRows.length" class="empty-list-state"><strong>暂无文件</strong><span>聊天中的文件会自动归集到这里</span></div>
        <div v-else class="content-grid">
          <article
            v-for="item in fileRows"
            :key="item.id"
            class="content-card clickable"
            @click="openMedia(item)"
          >
            <div class="content-card-head">
              <span
                v-if="item.type === 'image' && asset(item.file_url)"
                class="avatar medium media-thumb"
                :style="{ backgroundImage: `url(${asset(item.file_url)})` }"
              ></span>
              <span v-else class="avatar medium">{{ item.type === 'image' ? '图' : item.type === 'video' ? '视' : item.type === 'voice' ? '音' : '文' }}</span>
              <div><h3>{{ item.file_name || ({ image: '图片', video: '视频', voice: '语音' }[item.type] || '文件') }}</h3><div class="catalog-kicker">{{ formatBytes(item.file_size) }}</div></div>
            </div>
            <p>{{ item.conversation_title || '聊天文件' }}</p>
            <div class="content-card-meta"><span>{{ timeText(item.created_at, true) }}</span><span>{{ item.sender_name || '' }}</span></div>
          </article>
        </div>
      </div>

      <!-- 设置 -->
      <div v-else-if="ui.view === 'settings'" class="settings-panel">
        <div class="detail-list">
          <div class="detail-button">
            <span>外观主题</span>
            <select v-model="theme">
              <option value="system">跟随系统</option>
              <option value="light">浅色</option>
              <option value="dark">深色</option>
            </select>
          </div>
        </div>
        <button class="primary-button" type="button" @click="saveSettings">保存设置</button>
      </div>
    </div>

    <!-- 媒体预览叠层 -->
    <div v-if="previewing" class="media-overlay" @click.self="closePreview">
      <div class="media-overlay-card">
        <header>
          <strong>{{ previewing.title }}</strong>
          <button class="icon-button" type="button" @click="closePreview"><svg><use href="#i-close" /></svg></button>
        </header>
        <div class="media-overlay-body">
          <img v-if="previewing.kind === 'image'" :src="previewing.url" :alt="previewing.title" />
          <video v-else-if="previewing.kind === 'video'" :src="previewing.url" controls autoplay></video>
          <div v-else class="file-detail">
            <h3>{{ previewing.title }}</h3>
            <p v-if="previewing.sub">{{ previewing.sub }}</p>
            <div class="catalog-kicker">{{ previewing.size }} · {{ previewing.time }}</div>
            <a class="primary-button" :href="previewing.url" target="_blank" rel="noopener" style="margin-top:14px;text-decoration:none;display:inline-grid;place-items:center">在新标签页打开</a>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>
