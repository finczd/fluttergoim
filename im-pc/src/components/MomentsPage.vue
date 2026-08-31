<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useUiStore } from '../stores/ui';
import { useAuthStore } from '../stores/auth';
import api, { uploadFile } from '../api/client';
import Avatar from './Avatar.vue';
import { asset } from '../utils/format';

const props = defineProps({ owner: { type: Object, default: null } });
const ui = useUiStore();
const auth = useAuthStore();

const isOwn = computed(() => !props.owner);
const title = computed(() => (props.owner ? (props.owner.name || '好友') + ' 的朋友圈' : '朋友圈'));

const posts = ref([]);
const total = ref(0);
const page = ref(1);
const size = ref(20);
const loading = ref(false);
const finished = computed(() => total.value > 0 && posts.value.length >= total.value);

async function load(reset = false) {
  if (loading.value) return;
  if (reset) { page.value = 1; posts.value = []; }
  loading.value = true;
  try {
    const params = { page: page.value, size: size.value };
    const r = isOwn.value
      ? await api('moments', params)
      : await api('moments/user', { ...params, owner_id: String(props.owner.id) });
    posts.value = reset ? (r.list || []) : [...posts.value, ...(r.list || [])];
    total.value = r.total || 0;
    page.value += 1;
  } catch (e) {
    ui.toast('朋友圈加载失败', e.message, 'error');
  } finally {
    loading.value = false;
  }
}

onMounted(() => load(true));
watch(() => props.owner, () => load(true));

function onScroll(e) {
  const el = e.target;
  if (el.scrollHeight - el.scrollTop - el.clientHeight < 120 && !loading.value && !finished.value) load(false);
}

// ============ 发布 ============
const draft = ref('');
const publishing = ref(false);
const pendingImages = ref([]);
const uploadBusy = ref(false);

async function onPickImages(e) {
  const files = Array.from(e.target.files || []).slice(0, 9 - pendingImages.value.length);
  uploadBusy.value = true;
  try {
    for (const f of files) {
      const up = await uploadFile(f);
      pendingImages.value.push({ url: up.url, name: up.name || f.name, size: up.size || f.size });
    }
  } catch (err) {
    ui.toast('图片上传失败', err.message, 'error');
  } finally {
    uploadBusy.value = false;
    e.target.value = '';
  }
}
function removeImage(i) { pendingImages.value.splice(i, 1); }

async function publish() {
  const content = draft.value.trim();
  if (!content && !pendingImages.value.length) {
    ui.toast('说点什么吧', '', 'warning');
    return;
  }
  publishing.value = true;
  try {
    const images = pendingImages.value.map(i => i.url);
    const post = await api('moments/publish', { content, images }, 'POST');
    posts.value.unshift(post);
    total.value += 1;
    draft.value = '';
    pendingImages.value = [];
    ui.toast('已发表');
  } catch (e) {
    ui.toast('发表失败', e.message, 'error');
  } finally {
    publishing.value = false;
  }
}

async function toggleLike(post) {
  try {
    const r = await api('moments/like', { id: String(post.id) }, 'POST');
    post.liked = !!r.liked;
    post.like_count = Math.max(0, Number(post.like_count || 0) + (post.liked ? 1 : -1));
  } catch (e) {
    ui.toast('操作失败', e.message, 'error');
  }
}

function back() { ui.openMoments(null); }
</script>

<template>
  <section class="moments-page">
    <header class="moments-header">
      <button v-if="!isOwn" class="moments-back" type="button" @click="back">返回</button>
      <h2>{{ title }}</h2>
    </header>

    <div class="moments-scroll" @scroll="onScroll">
      <!-- 发布框（仅自己的时间线） -->
      <div v-if="isOwn" class="moments-composer">
        <Avatar :user="auth.user" size="medium" />
        <div class="moments-composer-main">
          <textarea v-model="draft" rows="2" maxlength="1000" placeholder="这一刻的想法…"></textarea>
          <div v-if="pendingImages.length" class="moments-composer-images">
            <div v-for="(img, i) in pendingImages" :key="i" class="moments-thumb">
              <img :src="asset(img.url)" alt="图片" />
              <button type="button" class="moments-thumb-del" title="移除" @click="removeImage(i)">×</button>
            </div>
          </div>
          <div class="moments-composer-actions">
            <label class="moments-add-img" title="添加图片">
              <svg><use href="#i-image" /></svg>
              <input type="file" accept="image/*" multiple hidden @change="onPickImages" />
            </label>
            <button class="primary-button" type="button" :disabled="publishing || uploadBusy" @click="publish">
              {{ publishing ? '发表中…' : '发表' }}
            </button>
          </div>
        </div>
      </div>

      <!-- 时间线 -->
      <div v-if="!posts.length && !loading" class="empty-list-state">
        <strong>还没有动态</strong>
        <span>{{ isOwn ? '发表你的第一条朋友圈吧' : '对方还没有发布动态' }}</span>
      </div>

      <article v-for="post in posts" :key="post.id" class="moments-item">
        <Avatar :user="{ nickname: post.sender_name, avatar: post.sender_avatar }" size="medium" />
        <div class="moments-item-body">
          <div class="moments-item-name">{{ post.sender_name || '用户' }}</div>
          <div class="moments-item-content">{{ post.content }}</div>
          <div v-if="post.images && post.images.length" class="moments-item-images">
            <img v-for="(img, i) in post.images" :key="i" :src="asset(img)" alt="图片" loading="lazy" />
          </div>
          <div class="moments-item-footer">
            <span class="moments-item-time">{{ post.created_at }}</span>
            <button class="moments-like" type="button" :class="{ liked: post.liked }" @click="toggleLike(post)">
              <svg><use :href="post.liked ? '#i-heart-filled' : '#i-heart'" /></svg>
              <span v-if="post.like_count">{{ post.like_count }}</span>
            </button>
          </div>
        </div>
      </article>

      <div v-if="loading" class="moments-loading">加载中…</div>
      <button v-else-if="!finished && posts.length" class="moments-loadmore" type="button" @click="load(false)">加载更多</button>
    </div>
  </section>
</template>
