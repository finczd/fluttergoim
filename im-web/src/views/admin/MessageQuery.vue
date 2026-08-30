<template>
  <div class="page">
    <a-card>
      <div class="toolbar">
        <a-input-search v-model="query.kw" placeholder="按消息内容搜索" style="width: 240px" allow-clear @search="load(1)" />
        <a-date-picker v-model="dateRange" type="daterange" value-format="YYYY-MM-DD" style="width: 260px" />
        <a-button type="primary" @click="load(1)">查询</a-button>
      </div>

      <a-table :data="list" row-key="msgId" :pagination="pagination" :loading="loading" @page-change="load">
        <template #columns>
          <a-table-column title="消息ID" data-index="msgId" :width="180" />
          <a-table-column title="会话ID" data-index="conversationId" :width="180" />
          <a-table-column title="发送者" data-index="senderId" :width="160" />
          <a-table-column title="类型" :width="70">
            <template #cell="{ record }">{{ typeMap[record.type] || record.type }}</template>
          </a-table-column>
          <a-table-column title="内容" data-index="content" ellipsis />
          <a-table-column title="时间" :width="170">
            <template #cell="{ record }">{{ fmt(record.createdAt) }}</template>
          </a-table-column>
        </template>
      </a-table>
    </a-card>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, watch } from 'vue'
import { adminApi } from '@/api/admin'

const list = ref<Array<Record<string, any>>>([])
const loading = ref(false)
const dateRange = ref<Array<string | number> | undefined>(undefined)
const query = reactive({ kw: '' })
const pagination = reactive({ current: 1, pageSize: 20, total: 0, showTotal: true })

const typeMap: Record<number, string> = { 1: '文本', 2: '图片', 3: '文件', 4: '语音', 5: '视频', 6: '系统' }

onMounted(() => load(1))
watch(dateRange, () => load(1))

async function load(page = pagination.current) {
  loading.value = true
  try {
    const [from, to] = dateRange.value?.length
      ? [new Date(dateRange.value[0] as string).getTime(), new Date(dateRange.value[1] as string).getTime() + 86399999]
      : [0, 0]
    const { data } = await adminApi.messages({ ...query, from, to, page, size: pagination.pageSize })
    if (data.code === 0) {
      list.value = data.data.list
      pagination.total = data.data.total
      pagination.current = page
    }
  } finally {
    loading.value = false
  }
}

function fmt(t?: string) {
  return t ? new Date(t).toLocaleString() : '-'
}
</script>

<style scoped>
.toolbar { display: flex; gap: 12px; margin-bottom: 16px; }
</style>
