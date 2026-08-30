<template>
  <div class="page">
    <a-card title="智能小助手" style="margin-bottom: 16px">
      <a-form :label-col="{ span: 5 }" :wrapper-col="{ span: 14 }">
        <a-form-item label="启用小助手">
          <a-switch v-model="cfg.enabled" />
        </a-form-item>
        <a-form-item label="助手名称">
          <a-input v-model="cfg.name" placeholder="小助手" />
        </a-form-item>
        <a-form-item label="助手头像（URL）">
          <a-input v-model="cfg.avatar" placeholder="https://..." />
        </a-form-item>
        <a-form-item label="新注册自动添加">
          <a-switch v-model="cfg.autoAdd" />
        </a-form-item>
        <a-form-item label="自动添加后的欢迎语">
          <a-textarea v-model="cfg.welcomeText" :rows="2" placeholder="你好，我是小助手，有问题随时找我～" />
        </a-form-item>
        <a-form-item :wrapper-col="{ offset: 5 }">
          <a-button type="primary" :loading="saving" @click="saveConfig">保存配置</a-button>
        </a-form-item>
      </a-form>
    </a-card>

    <a-card title="以助手身份推送消息">
      <a-form :label-col="{ span: 5 }" :wrapper-col="{ span: 14 }">
        <a-form-item label="目标用户">
          <a-select
            v-model="push.userId"
            :options="userOptions"
            show-search
            option-filter-prop="label"
            placeholder="选择用户（按账号/昵称搜索）"
            style="width: 100%"
          />
        </a-form-item>
        <a-form-item label="消息内容">
          <a-textarea v-model="push.content" :rows="3" placeholder="输入要发送的文字内容" />
        </a-form-item>
        <a-form-item label="图片 URL（可选）">
          <a-input v-model="push.fileUrl" placeholder="https://...（传图片时填写）" />
        </a-form-item>
        <a-form-item :wrapper-col="{ offset: 5 }">
          <a-button type="primary" status="success" :loading="pushing" @click="doPush">立即推送</a-button>
        </a-form-item>
      </a-form>
    </a-card>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { Message } from '@arco-design/web-vue'
import { adminApi } from '@/api/admin'

const cfg = ref({ enabled: false, name: '小助手', avatar: '', autoAdd: false, welcomeText: '' })
const saving = ref(false)
const pushing = ref(false)
const push = ref({ userId: '', content: '', fileUrl: '' })
const users = ref<Array<{ id: string; label: string }>>([])

const userOptions = computed(() => users.value)

onMounted(async () => {
  // 读配置
  try {
    const { data } = await adminApi.assistantConfigGet()
    if (data.code === 0 && data.data) {
      const d: any = data.data
      cfg.value = {
        enabled: !!d.enabled,
        name: String(d.name || '小助手'),
        avatar: String(d.avatar || ''),
        autoAdd: !!d.autoAdd,
        welcomeText: String(d.welcomeText || '')
      }
    }
  } catch (_) {}
  // 用户列表（推送目标）
  try {
    const { data } = await adminApi.users({ page: 1, size: 100 })
    if (data.code === 0) {
      const list: any[] = data.data?.list || []
      users.value = list.map(u => ({ id: String(u.id), label: `${u.nickname || ''} (${u.account || ''})` }))
    }
  } catch (_) {}
})

async function saveConfig() {
  saving.value = true
  try {
    const { data } = await adminApi.assistantConfigSet(cfg.value)
    if (data.code === 0) Message.success('配置已保存')
    else Message.error(data.message)
  } finally {
    saving.value = false
  }
}

async function doPush() {
  if (!push.value.userId) { Message.warning('请选择目标用户'); return }
  if (!push.value.content && !push.value.fileUrl) { Message.warning('请输入消息内容或图片'); return }
  pushing.value = true
  try {
    const { data } = await adminApi.assistantPush({
      userId: push.value.userId,
      content: push.value.content,
      fileUrl: push.value.fileUrl
    })
    if (data.code === 0) {
      Message.success('推送成功')
      push.value = { userId: '', content: '', fileUrl: '' }
    } else Message.error(data.message)
  } finally {
    pushing.value = false
  }
}
</script>
