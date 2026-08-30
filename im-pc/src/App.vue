<script setup>
import { onMounted, computed, watch } from 'vue';
import { useAuthStore } from './stores/auth';
import { useUiStore } from './stores/ui';
import LoginView from './components/LoginView.vue';
import MainView from './components/MainView.vue';
import ToastStack from './components/ToastStack.vue';
import Dialogs from './components/Dialogs.vue';
import Inspector from './components/Inspector.vue';
import ContextMenu from './components/ContextMenu.vue';
import CallLayer from './components/CallLayer.vue';

const auth = useAuthStore();
const ui = useUiStore();

const isLoggedIn = computed(() => !!auth.token);

// 品牌随配置变化持续应用（文档标题 + 带 data-brand-* 的元素）。
watch(() => auth.brand, () => auth.applyBrand(), { deep: true });

function updateViewport() {
  ui.showViewport = window.innerWidth < 1024;
}
window.addEventListener('resize', updateViewport);

// inspector 打开时给 app-root 加 has-inspector，让内容区右侧留出 316px 给悬浮 inspector
watch(
  () => ui.inspector.open,
  open => {
    const root = document.querySelector('.app-root');
    if (root) root.classList.toggle('has-inspector', !!open);
  }
);

onMounted(async () => {
  ui.initTheme();
  updateViewport();
  if (isLoggedIn.value) {
    try {
      await auth.enterMain();
    } catch (_) {
      auth.startQr();
    }
  } else {
    auth.startQr();
  }
});
</script>

<template>
  <div class="app-root">
    <LoginView v-if="!isLoggedIn" />
    <MainView v-else />
  </div>

  <div v-if="ui.showViewport" class="blocking-screen viewport-screen">
    <div class="blocking-card compact">
      <div class="blocking-logo" data-brand-mark>{{ auth.brand.mark }}</div>
      <h1>请使用电脑访问</h1>
      <p>PC 网页版最低支持 1024 像素宽度。手机端请使用对应 App 或 H5。</p>
    </div>
  </div>

  <ToastStack />
  <Dialogs />
  <Inspector />
  <ContextMenu />
  <CallLayer />
</template>
