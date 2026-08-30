<script setup>
import { onMounted, onBeforeUnmount, watch } from 'vue';
import { useUiStore } from '../stores/ui';
const ui = useUiStore();

function click(item) {
  item.onClick?.();
  ui.closeContextMenu();
}

// 点击页面任意位置 / 按 Esc / 滚动 / 改变窗口大小 都销毁菜单
// 注意：用捕获阶段监听，确保滚动容器内部触发的 scroll 事件也能被捕获
function onDocPointer(e) {
  if (!ui.contextMenu.open) return;
  const menu = document.querySelector('.context-menu');
  if (menu && menu.contains(e.target)) return; // 点菜单内部不关
  ui.closeContextMenu();
}
function onKey(e) {
  if (e.key === 'Escape' && ui.contextMenu.open) ui.closeContextMenu();
}
function onScrollOrResize() {
  if (ui.contextMenu.open) ui.closeContextMenu();
}

onMounted(() => {
  document.addEventListener('mousedown', onDocPointer, true);
  document.addEventListener('contextmenu', onDocPointer, true);
  document.addEventListener('keydown', onKey);
  window.addEventListener('scroll', onScrollOrResize, true);
  window.addEventListener('resize', onScrollOrResize);
});
onBeforeUnmount(() => {
  document.removeEventListener('mousedown', onDocPointer, true);
  document.removeEventListener('contextmenu', onDocPointer, true);
  document.removeEventListener('keydown', onKey);
  window.removeEventListener('scroll', onScrollOrResize, true);
  window.removeEventListener('resize', onScrollOrResize);
});
</script>

<template>
  <div
    v-if="ui.contextMenu.open"
    class="popover context-menu"
    :style="{ left: ui.contextMenu.x + 'px', top: ui.contextMenu.y + 'px' }"
    @click.stop
    @contextmenu.prevent.stop
  >
    <button
      v-for="(it, i) in ui.contextMenu.items"
      :key="i"
      type="button"
      :class="{ danger: it.danger }"
      @click="click(it)"
    >
      <svg><use :href="'#' + it.icon" /></svg><span>{{ it.label }}</span>
    </button>
  </div>
</template>
