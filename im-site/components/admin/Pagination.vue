<template>
  <div class="pagination">
    <button :disabled="!canPrev" @click="go(-1)" class="page-btn">上一页</button>
    <span class="page-info">第 {{ page }} 页 / 共 {{ totalPages }} 页 ({{ total }} 条)</span>
    <button :disabled="!canNext" @click="go(1)" class="page-btn">下一页</button>
  </div>
</template>

<script setup lang="ts">
const props = withDefaults(defineProps<{
  page: number
  total: number
  pageSize: number
}>(), { page: 1, total: 0, pageSize: 20 })

const emit = defineEmits<{
  (e: 'update:page', v: number): void
  (e: 'change'): void
}>()

const totalPages = computed(() => Math.max(1, Math.ceil(props.total / props.pageSize)))
const canPrev = computed(() => props.page > 1)
const canNext = computed(() => props.page < totalPages.value)

function go(dir: number) {
  const next = Math.min(totalPages.value, Math.max(1, props.page + dir))
  if (next !== props.page) {
    emit('update:page', next)
    emit('change')
  }
}
</script>

<style scoped>
.pagination { display: flex; align-items: center; justify-content: flex-end; gap: 12px; margin-top: 18px; }
.page-btn {
  padding: 6px 16px; border: 1px solid #e5e6eb; border-radius: 8px;
  background: #fff; color: #4e5969; cursor: pointer; font-size: 14px;
  transition: all .2s;
}
.page-btn:hover:not(:disabled) { border-color: #165dff; color: #165dff; }
.page-btn:disabled { opacity: .5; cursor: not-allowed; }
.page-info { font-size: 14px; color: #86909c; }
</style>
