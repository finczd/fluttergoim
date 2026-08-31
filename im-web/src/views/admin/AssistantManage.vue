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
        <a-form-item label="助手头像">
          <div style="display: flex; align-items: center; gap: 12px">
            <a-upload :show-file-list="false" :custom-request="(opt: any) => uploadAvatar(opt.file)">
              <a-button type="outline" :loading="uploadingAvatar">上传头像</a-button>
            </a-upload>
            <img v-if="cfg.avatar" :src="cfg.avatar" alt="助手头像"
                 style="width: 44px; height: 44px; border-radius: 10px; object-fit: cover" />
            <span v-else style="color: #86909c; font-size: 12px">未设置（默认头像）</span>
          </div>
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
          <a-popover position="bottom" trigger="click" :popup-visible="pickVisible" @popup-visible-change="(v: boolean) => pickVisible = v">
            <template #content>
              <div style="width: 320px">
                <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px">
                  <a-checkbox :model-value="allChecked" @change="(c: any) => toggleAll(!!c)">全选</a-checkbox>
                  <span style="color: #86909c; font-size: 12px">已选 {{ push.userIds.length }} / {{ users.length }} 人</span>
                  <a-button size="mini" type="text" @click="push.userIds = []; allChecked = false">清空</a-button>
                </div>
                <div style="max-height: 240px; overflow-y: auto; border: 1px solid var(--color-border-2); border-radius: 6px; padding: 6px 8px">
                  <a-checkbox-group v-model="push.userIds" direction="vertical" style="width: 100%">
                    <a-checkbox v-for="u in userOptions" :key="u.id" :value="u.id" style="margin: 4px 0; width: 100%">
                      {{ u.label }}
                    </a-checkbox>
                  </a-checkbox-group>
                  <div v-if="!userOptions.length" style="text-align: center; color: #86909c; padding: 16px 0">暂无用户</div>
                </div>
              </div>
            </template>
            <a-button style="width: 100%">
              选择用户（已选 {{ push.userIds.length }} 人）
            </a-button>
          </a-popover>
        </a-form-item>
        <a-form-item label="消息内容">
          <a-textarea v-model="push.content" :rows="3" placeholder="输入要发送的文字内容" />
        </a-form-item>
        <a-form-item label="图片（可选）">
          <div style="display: flex; align-items: center; gap: 12px">
            <a-upload :show-file-list="false" :custom-request="(opt: any) => uploadImage(opt.file)">
              <a-button type="outline" :loading="uploadingImage">上传图片</a-button>
            </a-upload>
            <img v-if="push.fileUrl" :src="push.fileUrl" alt="推送图片"
                 style="width: 56px; height: 56px; border-radius: 8px; object-fit: cover" />
            <a-input v-else v-model="push.fileUrl" placeholder="或直接填图片 URL" style="max-width: 260px" />
          </div>
        </a-form-item>
        <a-form-item :wrapper-col="{ offset: 5 }">
          <a-button type="primary" status="success" :loading="pushing" @click="doPush">立即推送</a-button>
        </a-form-item>
      </a-form>
    </a-card>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, computed, watch } from 'vue'
import { Message } from '@arco-design/web-vue'
import { adminApi } from '@/api/admin'

const cfg = ref({ enabled: false, name: '小助手', avatar: '', autoAdd: false, welcomeText: '' })
const saving = ref(false)
const pushing = ref(false)
const push = ref<{ userIds: string[]; content: string; fileUrl: string }>({ userIds: [], content: '', fileUrl: '' })
const users = ref<Array<{ id: string; label: string }>>([])
const uploadingAvatar = ref(false)
const uploadingImage = ref(false)
const allChecked = ref(false)
const pickVisible = ref(false)

const userOptions = computed(() => users.value)

// 勾选变化时同步"全选"状态
watch(() => push.value.userIds, (v: string[]) => {
  allChecked.value = users.value.length > 0 && v.length === users.value.length
}, { deep: true })

function toggleAll(checked: boolean) {
  push.value.userIds = checked ? users.value.map(u => u.id) : []
}
function toggleOne(id: string) {
  const i = push.value.userIds.indexOf(id)
  if (i >= 0) push.value.userIds.splice(i, 1)
  else push.value.userIds.push(id)
  allChecked.value = push.value.userIds.length === users.value.length && users.value.length > 0
}

/** 通用上传：POST /api/v1/upload → MinIO，返回 URL */
async function uploadToMinio(file: File, dir: string): Promise<string> {
  const fd = new FormData()
  fd.append('file', file)
  fd.append('dir', dir)
  const token = localStorage.getItem('im-token') || ''
  const resp = await fetch('/api/v1/upload', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
    body: fd
  })
  const json = await resp.json()
  if (json.code !== 0) throw new Error(json.message || '上传失败')
  return json.data.url
}

async function uploadAvatar(file: File) {
  uploadingAvatar.value = true
  try {
    cfg.value.avatar = await uploadToMinio(file, 'assistant/')
    Message.success('头像已上传，点击「保存配置」生效')
  } catch (e: any) {
    Message.error('头像上传失败：' + (e.message || e))
  } finally {
    uploadingAvatar.value = false
  }
}

async function uploadImage(file: File) {
  uploadingImage.value = true
  try {
    push.value.fileUrl = await uploadToMinio(file, 'assistant/')
    Message.success('图片已上传')
  } catch (e: any) {
    Message.error('图片上传失败：' + (e.message || e))
  } finally {
    uploadingImage.value = false
  }
}

function selectAll() {
  push.value.userIds = users.value.map(u => u.id)
  allChecked.value = true
}

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
    const { data } = await adminApi.users({ page: 1, size: 200 })
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
  if (!push.value.userIds.length) { Message.warning('请选择目标用户'); return }
  if (!push.value.content && !push.value.fileUrl) { Message.warning('请输入消息内容或图片'); return }
  pushing.value = true
  try {
    const { data } = await adminApi.assistantPush({
      userIds: push.value.userIds,
      content: push.value.content,
      fileUrl: push.value.fileUrl
    })
    if (data.code === 0) {
      Message.success(`已推送 ${push.value.userIds.length} 人`)
      push.value = { userIds: [], content: '', fileUrl: '' }
    } else Message.error(data.message)
  } finally {
    pushing.value = false
  }
}
</script>
