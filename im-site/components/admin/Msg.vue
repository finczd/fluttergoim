<template>
  <div v-if="msg" :class="['msg-banner', msg.ok ? 'ok' : 'err']">{{ msg.text }}</div>
</template>

<script setup lang="ts">
defineProps<{ msg: { ok: boolean; text: string } | null }>()
</script>

<style scoped>
.msg-banner {
  padding: 10px 14px;
  border-radius: 8px;
  font-size: 13px;
  margin-bottom: 14px;
  line-height: 1.5;
}
.msg-banner.ok { background: #e8ffea; color: #00b42a; border: 1px solid #bff3c6; }
.msg-banner.err { background: #ffece8; color: #f53f3f; border: 1px solid #ffccc2; }
</style>
