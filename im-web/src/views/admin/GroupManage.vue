<template>
  <div class="page">
    <a-card title="群组管理">
      <a-table :data="list" row-key="id" :loading="loading" :pagination="false">
        <template #columns>
          <a-table-column title="群名称" :width="200">
            <template #cell="{ record }">{{ record.nameZh || '(未命名)' }}</template>
          </a-table-column>
          <a-table-column title="群英文名" data-index="nameEn" :width="200" />
          <a-table-column title="群主" :width="160">
            <template #cell="{ record }">{{ record.ownerId || '-' }}</template>
          </a-table-column>
          <a-table-column title="人数上限" data-index="maxMembers" :width="90" />
          <a-table-column title="创建时间" :width="180">
            <template #cell="{ record }">{{ fmt(record.createdAt) }}</template>
          </a-table-column>
          <a-table-column title="操作" :width="120">
            <template #cell="{ record }">
              <a-popconfirm content="确认解散该群？解散后不可恢复" @ok="disband(record)">
                <a-button size="mini" status="danger">解散</a-button>
              </a-popconfirm>
            </template>
          </a-table-column>
        </template>
      </a-table>
      <a-empty v-if="!list.length && !loading" :description="'暂无群聊'" />
    </a-card>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { Message } from '@arco-design/web-vue'
import { adminApi } from '@/api/admin'

const list = ref<Array<Record<string, any>>>([])
const loading = ref(false)

onMounted(load)

async function load() {
  loading.value = true
  try {
    const { data } = await adminApi.groups()
    if (data.code === 0) list.value = data.data as never
  } finally {
    loading.value = false
  }
}

function fmt(t?: string) {
  return t ? new Date(t).toLocaleString() : '-'
}

async function disband(record: Record<string, any>) {
  // record.id 为字符串（雪花 ID），直接透传避免 JS 精度丢失
  const { data } = await adminApi.groupDisband(record.id as string)
  if (data.code === 0) {
    Message.success('已解散')
    await load()
  } else Message.error(data.message)
}
</script>
