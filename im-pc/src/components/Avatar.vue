<script setup>
import { computed, ref, watch } from 'vue';
import { asset, initials } from '../utils/format';

const props = defineProps({
  user: { type: Object, default: () => ({}) },
  size: { type: String, default: 'medium' },
  extra: { type: String, default: '' }
});

// 父组件可能显式传入 null（如未登录时 auth.user 为 null、inspector.user 未打开时为 null）。
// Vue 的 prop default 仅在值为 undefined 时生效，传 null 不会回退，故这里统一兜底为空对象，
// 否则 props.user.avatar_members / props.user.avatar 会抛 TypeError，导致整个头像区渲染失败。
const safeUser = computed(() => props.user || {});
const name = computed(() => safeUser.value.remark || safeUser.value.alias || safeUser.value.nickname || safeUser.value.title || '用户');
const avatar = computed(() => safeUser.value.avatar || safeUser.value.sender_avatar || '');
const members = computed(() => (Array.isArray(safeUser.value.avatar_members) ? safeUser.value.avatar_members.filter(Boolean).slice(0, 9) : []));
const url = computed(() => asset(avatar.value));
// 用 Image 预加载探测 URL 是否可加载；加载失败时回退首字（@error 对 background-image 不生效）
const imageFailed = ref(false);
watch(
  () => url.value,
  () => {
    imageFailed.value = false;
    if (!url.value) return;
    const probe = new Image();
    probe.onload = () => { /* ok */ };
    probe.onerror = () => { imageFailed.value = true; };
    probe.src = url.value;
  },
  { immediate: true }
);
const initialChar = computed(() => initials(name.value));
</script>

<template>
  <span
    v-if="(!avatar || imageFailed) && members.length"
    class="avatar"
    :class="[size, extra, 'group-mosaic', 'count-' + members.length]"
  >
    <i
      v-for="(m, i) in members"
      :key="i"
      :style="m.avatar ? { backgroundImage: `url('${asset(m.avatar)}')` } : null"
      >{{ m.avatar ? '' : initials(m.nickname || m.name || '用户') }}</i
    >
  </span>
  <span
    v-else-if="url && !imageFailed"
    class="avatar avatar-with-image"
    :class="[size, extra]"
    :style="{ backgroundImage: `url('${url}')` }"
  ></span>
  <span v-else class="avatar" :class="[size, extra]">{{ initialChar }}</span>
</template>
