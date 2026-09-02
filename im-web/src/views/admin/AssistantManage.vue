<template>
  <div class="page">
    <a-card :bordered="false">
      <a-tabs default-active-key="base">
        <!-- ===== 子分类 1：基础设置 ===== -->
        <a-tab-pane key="base" title="基础设置">
          <a-form :label-col="{ span: 5 }" :wrapper-col="{ span: 14 }" style="max-width: 640px; margin-top: 8px">
            <a-form-item label="启用小助手">
              <a-switch v-model="cfg.enabled" />
            </a-form-item>
            <a-form-item label="助手名称">
              <a-input v-model="cfg.name" placeholder="小助手" />
            </a-form-item>
            <a-form-item label="助手头像">
              <ImageUpload v-model="cfg.avatar" dir="assistant/" round :inline="true" :size="96"
                           hint="圆形预览，建议 128×128。上传后点击「保存配置」生效，点「清除」可恢复默认头像。" />
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
        </a-tab-pane>

        <!-- ===== 子分类 2：推送消息 ===== -->
        <a-tab-pane key="push" title="推送消息">
          <a-form :label-col="{ span: 5 }" :wrapper-col="{ span: 14 }" style="max-width: 640px; margin-top: 8px">
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
        </a-tab-pane>

        <!-- ===== 子分类 3：会话消息 ===== -->
        <a-tab-pane key="conv" title="会话消息">
          <div class="conv-wrap">
            <!-- 左：会话列表 -->
            <div class="conv-list">
              <a-spin :loading="convLoading" style="width: 100%">
                <div v-if="!convs.length && !convLoading" class="conv-empty">暂无助手会话</div>
                <div v-for="cv in convs" :key="cv.userId" class="conv-item"
                     :class="{ active: sel && sel.userId === cv.userId }" @click="openConv(cv)">
                  <a-avatar :size="38" style="background: #165dff; flex-shrink: 0">
                    <img v-if="cv.avatar" :src="cv.avatar" alt="" />
                    <span v-else>{{ (cv.nickname || '用户').slice(0, 1) }}</span>
                  </a-avatar>
                  <div class="conv-info">
                    <div class="conv-name">
                      <span class="nick">{{ cv.nickname || cv.account || cv.userId }}</span>
                      <span class="time">{{ fmtTime(cv.lastMessage?.createdAt) }}</span>
                    </div>
                    <div class="conv-last">{{ preview(cv.lastMessage) }}</div>
                  </div>
                </div>
              </a-spin>
            </div>

            <!-- 右：消息记录 + 回复 -->
            <div class="conv-main">
              <template v-if="sel">
                <div class="conv-title">
                  与 {{ sel.nickname || sel.account || sel.userId }} 的对话
                  <a-button size="mini" type="text" @click="loadMsgs(true)"
                            :loading="msgsLoading" :disabled="!hasMore">加载更早消息</a-button>
                </div>
                <div class="msg-scroll">
                  <a-spin :loading="msgsLoading" style="width: 100%">
                    <div v-if="!msgs.length && !msgsLoading" class="conv-empty">暂无消息</div>
                    <div v-for="m in msgs" :key="m.msgId" class="msg-row" :class="{ mine: String(m.senderId) === '-1' }">
                      <div class="msg-meta">
                        {{ String(m.senderId) === '-1' ? '助手' : '用户' }} · {{ fmtTime(m.createdAt) }}
                      </div>
                      <div class="msg-bubble">
                        <template v-if="m.recalled">[已撤回]</template>
                        <template v-else-if="m.type === 2">
                          <img v-if="m.content" :src="m.content" class="msg-img" alt="" />
                          <span v-else>[图片]</span>
                        </template>
                        <template v-else-if="m.type === 3">[文件] {{ m.content }}</template>
                        <template v-else-if="m.type === 7">[通话]</template>
                        <template v-else-if="m.type === 8">[红包]</template>
                        <template v-else-if="m.type === 9">[转账]</template>
                        <template v-else>{{ m.content }}</template>
                      </div>
                    </div>
                  </a-spin>
                </div>
                <div class="reply-bar">
                  <a-textarea v-model="replyText" :rows="2" :max-length="500"
                              placeholder="以助手身份回复该用户" />
                  <a-button type="primary" :loading="replying" @click="sendReply">回复</a-button>
                </div>
              </template>
              <div v-else class="conv-empty" style="height: 100%">选择左侧会话查看消息</div>
            </div>
          </div>
        </a-tab-pane>
      </a-tabs>
    </a-card>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, computed, watch } from 'vue'
import { Message } from '@arco-design/web-vue'
import { adminApi } from '@/api/admin'
import ImageUpload from './ImageUpload.vue'

const cfg = ref({ enabled: false, name: '小助手', avatar: '', autoAdd: false, welcomeText: '' })
const saving = ref(false)
const pushing = ref(false)
const push = ref<{ userIds: string[]; content: string; fileUrl: string }>({ userIds: [], content: '', fileUrl: '' })
const users = ref<Array<{ id: string; label: string }>>([])
const uploadingImage = ref(false)
const allChecked = ref(false)
const pickVisible = ref(false)

const userOptions = computed(() => users.value)

// ===== 助手会话消息 =====
const convs = ref<Array<Record<string, any>>>([])
const convLoading = ref(false)
const sel = ref<Record<string, any> | null>(null)
const msgs = ref<Array<Record<string, any>>>([])
const msgsLoading = ref(false)
const replyText = ref('')
const replying = ref(false)
const hasMore = ref(false)

async function loadConvs() {
  convLoading.value = true
  try {
    const { data } = await adminApi.assistantConversations()
    if (data.code === 0) convs.value = data.data || []
  } catch (_) {} finally { convLoading.value = false }
}

async function openConv(cv: Record<string, any>) {
  sel.value = cv
  msgs.value = []
  hasMore.value = false
  await loadMsgs()
}

/** 拉取消息；older=true 时向前翻页（插到前面） */
async function loadMsgs(older = false) {
  if (!sel.value) return
  msgsLoading.value = true
  try {
    const before = older && msgs.value.length
      ? (msgs.value[0].msgId as string | number)
      : undefined
    const { data } = await adminApi.assistantMessages({
      userId: sel.value.userId as string, beforeMsgId: before, limit: 50
    })
    if (data.code === 0) {
      const list: Array<Record<string, any>> = data.data || []
      hasMore.value = list.length >= 50
      msgs.value = older ? [...list, ...msgs.value] : list
    } else Message.error(data.message)
  } catch (e: any) {
    Message.error('消息加载失败：' + (e.message || e))
  } finally { msgsLoading.value = false }
}

async function sendReply() {
  const content = replyText.value.trim()
  if (!sel.value || !content) { Message.warning('请输入回复内容'); return }
  replying.value = true
  try {
    const { data } = await adminApi.assistantPush({
      userIds: [String(sel.value.userId)], content
    })
    if (data.code === 0) {
      Message.success('已回复')
      replyText.value = ''
      await loadMsgs()
      await loadConvs()
    } else Message.error(data.message)
  } finally { replying.value = false }
}

function fmtTime(t: any): string {
  if (!t) return ''
  const d = new Date(t)
  if (isNaN(d.getTime())) return ''
  const p = (n: number) => String(n).padStart(2, '0')
  return `${d.getMonth() + 1}-${d.getDate()} ${p(d.getHours())}:${p(d.getMinutes())}`
}

function preview(m: any): string {
  if (!m) return ''
  if (m.recalled) return '[已撤回]'
  const map: Record<number, string> = { 2: '[图片]', 3: '[文件]', 7: '[通话]', 8: '[红包]', 9: '[转账]' }
  if (map[m.type]) return map[m.type]
  return (m.content || '').slice(0, 40)
}

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

/** 通用上传：admin 接口 → MinIO，返回 URL
 * 走 adminApi.uploadFile（axios），不再用裸 fetch('/api/v1/upload')，
 * 否则反向代环境下 multipart body 可能丢失 → 后端 FormFile("file") 拿不到 → 报 1001「缺少文件」。
 */
async function uploadToMinio(file: File, dir: string): Promise<string> {
  return adminApi.uploadFile(file, dir)
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
  // 助手会话列表
  loadConvs()
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

<style scoped>
.conv-wrap {
  display: flex;
  gap: 16px;
  height: 520px;
  margin-top: 8px;
}
.conv-list {
  width: 320px;
  flex-shrink: 0;
  border: 1px solid var(--color-border-2);
  border-radius: 8px;
  overflow-y: auto;
  padding: 6px;
}
.conv-item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 9px 10px;
  border-radius: 8px;
  cursor: pointer;
}
.conv-item:hover { background: var(--color-fill-1); }
.conv-item.active { background: var(--color-fill-2); }
.conv-info { min-width: 0; flex: 1; }
.conv-name {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 8px;
}
.conv-name .nick {
  font-size: 14px;
  font-weight: 500;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.conv-name .time { font-size: 11px; color: #86909c; flex-shrink: 0; }
.conv-last {
  font-size: 12px;
  color: #86909c;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  margin-top: 2px;
}
.conv-main {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  border: 1px solid var(--color-border-2);
  border-radius: 8px;
}
.conv-title {
  padding: 10px 14px;
  border-bottom: 1px solid var(--color-border-2);
  font-size: 14px;
  font-weight: 500;
  display: flex;
  justify-content: space-between;
  align-items: center;
}
.msg-scroll {
  flex: 1;
  overflow-y: auto;
  padding: 14px;
}
.msg-row { margin-bottom: 12px; }
.msg-row.mine { text-align: right; }
.msg-meta { font-size: 11px; color: #86909c; margin-bottom: 4px; }
.msg-bubble {
  display: inline-block;
  max-width: 75%;
  padding: 8px 12px;
  border-radius: 8px;
  background: var(--color-fill-2);
  font-size: 13px;
  text-align: left;
  word-break: break-word;
  white-space: pre-wrap;
}
.msg-row.mine .msg-bubble {
  background: rgb(var(--primary-6));
  color: #fff;
}
.msg-img {
  max-width: 200px;
  max-height: 200px;
  border-radius: 6px;
  display: block;
}
.reply-bar {
  display: flex;
  gap: 10px;
  align-items: flex-end;
  padding: 10px 14px;
  border-top: 1px solid var(--color-border-2);
}
.conv-empty {
  display: flex;
  align-items: center;
  justify-content: center;
  color: #86909c;
  font-size: 13px;
  padding: 24px 0;
  height: 100%;
}
</style>
