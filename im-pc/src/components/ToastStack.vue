<script setup>
import { useUiStore } from '../stores/ui';
const ui = useUiStore();
</script>

<template>
  <div class="toast-stack" aria-live="polite">
    <div v-for="t in ui.toasts" :key="t.id" class="toast" :class="{ error: t.type === 'error' }">
      <strong>{{ t.title }}</strong>
      <span v-if="t.message">{{ t.message }}</span>
    </div>
  </div>
</template>
