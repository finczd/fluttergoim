<script setup>
import { useAuthStore } from '../../stores/auth';
const auth = useAuthStore();
</script>

<template>
  <section class="empty-workspace">
    <div class="empty-mark" data-brand-mark>{{ auth.brand.mark }}</div>
    <h2 data-brand-name>{{ auth.brand.name }}</h2>
    <p>从左侧选择会话、联系人或文件开始操作。</p>
    <div class="shortcut-hint"><kbd>Ctrl</kbd><span>+</span><kbd>K</kbd><span>快速搜索</span></div>
  </section>
</template>
