<template>
  <div class="page"><h2>{{ t("nav.calls") }}</h2><p class="tip">通话记录（V2.0 TRTC 实现）</p></div>
</template>

<script setup lang="ts">
import { useI18n } from "vue-i18n"
const { t } = useI18n()
</script>

<style scoped>
.page { padding: 24px; }
.tip { color: #9aa3ae; }
</style>
