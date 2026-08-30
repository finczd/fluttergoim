<template>
  <div class="page">
    <a-card>
      <div class="toolbar">
        <a-input-search v-model="query.kw" placeholder="昵称 / 账号 / 手机号 / 邮箱" style="width: 260px" allow-clear @search="load(1)" />
        <a-select v-model="query.status" placeholder="状态" style="width: 120px" allow-clear @change="load(1)">
          <a-option :value="1">正常</a-option>
          <a-option :value="2">禁用</a-option>
        </a-select>
        <a-button type="primary" @click="showCreate = true">创建账号</a-button>
      </div>

      <a-table :data="list" :pagination="pagination" :loading="loading" row-key="id" @page-change="load">
        <template #columns>
          <a-table-column title="昵称" data-index="nickname" :width="140" />
          <a-table-column title="账号" data-index="account" :width="200" />
          <a-table-column title="角色" :width="90">
            <template #cell="{ record }">
              <a-tag :color="record.role === 2 ? 'arcoblue' : 'gray'">{{ record.role === 2 ? '管理员' : '用户' }}</a-tag>
            </template>
          </a-table-column>
          <a-table-column title="状态" :width="90">
            <template #cell="{ record }">
              <a-tag :color="record.status === 1 ? 'green' : 'red'">{{ record.status === 1 ? '正常' : '禁用' }}</a-tag>
            </template>
          </a-table-column>
          <a-table-column title="注册时间" :width="170">
            <template #cell="{ record }">{{ fmt(record.createdAt) }}</template>
          </a-table-column>
          <a-table-column title="操作" :width="200">
            <template #cell="{ record }">
              <a-switch :model-value="record.status === 1" size="small" @change="(v: any) => toggleStatus(record, !!v)" />
              <a-button size="mini" style="margin-left: 8px" @click="resetPwd(record)">重置密码</a-button>
            </template>
          </a-table-column>
        </template>
      </a-table>
    </a-card>

    <!-- 创建账号 -->
    <a-modal v-model:visible="showCreate" title="创建账号" @ok="createUser" @cancel="resetForm()">
      <a-form :model="form" layout="vertical">
        <a-form-item label="账号（手机号或邮箱）" required><a-input v-model="form.account" /></a-form-item>
        <a-form-item label="密码" required><a-input-password v-model="form.password" placeholder="8-20 位含字母数字" /></a-form-item>
        <a-form-item label="昵称"><a-input v-model="form.nickname" /></a-form-item>
        <a-form-item label="角色">
          <a-radio-group v-model="form.role">
            <a-radio :value="1">用户</a-radio>
            <a-radio :value="2">管理员</a-radio>
          </a-radio-group>
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { Message } from '@arco-design/web-vue'
import { adminApi } from '@/api/admin'

const list = ref<Array<Record<string, any>>>([])
const loading = ref(false)
const showCreate = ref(false)
const form = reactive({ account: '', password: '', nickname: '',  role: 1 })
const query = reactive({ kw: '', status: undefined as number | undefined })
const pagination = reactive({ current: 1, pageSize: 10, total: 0, showTotal: true })

onMounted(() => load(1))

async function load(page = pagination.current) {
  loading.value = true
  try {
    const { data } = await adminApi.users({ ...query, page, size: pagination.pageSize })
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

async function toggleStatus(record: Record<string, any>, enabled: boolean) {
  const { data } = await adminApi.userStatus(record.id, enabled ? 1 : 2)
  if (data.code === 0) {
    record.status = enabled ? 1 : 2
    Message.success(enabled ? '已启用' : '已禁用')
  }
}

async function resetPwd(record: Record<string, any>) {
  const v = await import('@arco-design/web-vue').then((m) => m.Modal.prompt({
    title: `重置 ${record.nickname} 的密码`, content: '请输入新密码（8-20 位含字母数字）'
  }))
  const pwd = v.data as string
  if (!pwd || pwd.length < 8) return Message.error('密码长度不足')
  const { data } = await adminApi.userResetPwd(record.id, pwd)
  data.code === 0 ? Message.success('已重置') : Message.error(data.message)
}

function resetForm() {
  Object.assign(form, { account: "", password: "", nickname: "", departmentId: undefined, role: 1 })
}

async function createUser() {
  if (!form.account || !form.password) return Message.error('请填写账号和密码')
  const { data } = await adminApi.userCreate({ ...form })
  if (data.code === 0) {
    Message.success('创建成功')
    showCreate.value = false
    Object.assign(form, { account: '', password: '', nickname: '', role: 1 })
    await load(1)
  } else Message.error(data.message)
}
</script>

<style scoped>
.toolbar { display: flex; gap: 12px; margin-bottom: 16px; }
</style>
