<template>
  <div class="ff-wrap">
    <label class="ff-label">
      <span>{{ label }}</span>
      <span v-if="required" class="ff-req">*</span>
    </label>
    <div class="ff-slot"><slot /></div>
    <small v-if="hint" class="ff-hint">{{ hint }}</small>
  </div>
</template>

<script setup lang="ts">
defineProps<{
  label: string
  required?: boolean
  hint?: string
}>()
</script>

<style scoped>
.ff-wrap { margin-bottom: 14px; }
.ff-label { display: block; font-size: 14px; font-weight: 500; color: #4e5969; margin-bottom: 6px; }
.ff-req { color: #f53f3f; margin-left: 2px; }
.ff-hint { display: block; color: #86909c; font-size: 12px; margin-top: 4px; }
</style>
