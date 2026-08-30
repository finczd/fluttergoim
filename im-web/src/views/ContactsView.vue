<template>
  <div class="contacts-page">
    <a-tabs v-model:active-key="tab" type="rounded">
      <a-tab-pane key="friends" :title="t('nav.contacts')">
        <div class="toolbar">
          <a-input-search
            v-model="kw"
            :placeholder="t('chat.searchPlaceholder')"
            style="width: 280px"
            allow-clear
            @search="searchUser"
          />
          <a-button type="primary" :icon="iconAdd" @click="showAdd = true">
            {{ t('contacts.addFriend') }}
          </a-button>
        </div>

        <a-list :bordered="false">
          <a-list-item v-for="f in friends" :key="f.id">
            <a-list-item-meta :title="f.nickname" :description="f.email || f.phone || f.account">
              <template #avatar>
                <a-avatar :style="avatarStyle(f)">{{ f.nickname?.slice(0, 1) }}</a-avatar>
              </template>
            </a-list-item-meta>
            <template #actions>
              <a-button size="mini" @click="chatWith(f)">{{ t('contacts.sendMsg') }}</a-button>
              <a-popconfirm :content="t('contacts.delFriend')" @ok="delFriend(f.id)">
                <a-button size="mini" status="danger">{{ t('contacts.del') }}</a-button>
              </a-popconfirm>
            </template>
          </a-list-item>
        </a-list>
        <a-empty v-if="!friends.length" :description="t('common.empty')" />
      </a-tab-pane>

      <a-tab-pane key="requests" :title="t('contacts.requests')">
        <a-list :bordered="false">
          <a-list-item v-for="r in requests" :key="r.id">
            <a-list-item-meta :title="userName(r.fromUser)" :description="r.message" />
            <template #actions>
              <a-button size="mini" type="primary" @click="handleReq(r.id, true)">{{ t('common.confirm') }}</a-button>
              <a-button size="mini" status="danger" @click="handleReq(r.id, false)">{{ t('common.cancel') }}</a-button>
            </template>
          </a-list-item>
        </a-list>
        <a-empty v-if="!requests.length" :description="t('common.empty')" />
      </a-tab-pane>
    </a-tabs>

    <!-- 添加好友弹窗 -->
    <a-modal v-model:visible="showAdd" :title="t('contacts.addFriend')" @cancel="searchResult = []">
      <a-input-search v-model="searchKw" :placeholder="t('contacts.searchHint')" @search="searchUser" />
      <a-list v-if="searchResult.length" :bordered="false" class="search-result">
        <a-list-item v-for="u in searchResult" :key="u.id">
          <a-list-item-meta :title="u.nickname" :description="u.email || u.phone || u.account" />
          <template #actions>
            <a-button size="mini" type="primary" @click="requestAdd(u.id)">{{ t('contacts.addFriend') }}</a-button>
          </template>
        </a-list-item>
      </a-list>
      <a-empty v-else-if="searched" :description="t('common.empty')" />
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, computed, h } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import { IconPlus } from '@arco-design/web-vue/es/icon'
import { userApi } from '@/api/auth'
import { friendApi, type FriendReq } from '@/api/friend'
import { Message } from '@arco-design/web-vue'

const { t } = useI18n()
const router = useRouter()
const iconAdd = () => h(IconPlus)

const tab = ref('friends')
const friends = ref<Array<Record<string, any>>>([])
const kw = ref('')
const showAdd = ref(false)
const searchKw = ref('')
const searchResult = ref<Array<Record<string, any>>>([])
const searched = ref(false)

const deptTree = ref<Array<Record<string, any>>>([])
const selectedDept = ref<number | undefined>(undefined)
const deptMembers = ref<Array<Record<string, any>>>([])
const requests = ref<FriendReq[]>([])


const AVATAR_COLORS = ['#4E8CFF', '#7B61FF', '#FF7D00', '#00B42A', '#F53F3F', '#14C9C9']
function avatarStyle(u: Record<string, any>) {
  return { backgroundColor: AVATAR_COLORS[Number(u.id) % AVATAR_COLORS.length] }
}

onMounted(async () => {
  await Promise.all([loadFriends(), loadRequests()])
})

async function loadFriends() {
  const { data } = await friendApi.list()
  friends.value = data.data as never
}

async function loadRequests() {
  const { data } = await friendApi.incoming()
  requests.value = data.data as never
}

async function searchUser() {
  const { data } = await userApi.search(kw.value || searchKw.value)
  const list = data.data as never
  searchResult.value = list as never
  searched.value = true
  if (!showAdd.value && kw.value) {
    // 主搜索直接展示结果
    showAdd.value = true
    searchKw.value = kw.value
  }
}

async function requestAdd(toId: number) {
  const { data } = await friendApi.request(toId)
  if (data.code === 0) Message.success(t('contacts.sent'))
  else Message.error(data.message)
}

async function handleReq(id: number, agree: boolean) {
  const { data } = await friendApi.handle(id, agree)
  if (data.code === 0) {
    Message.success(t('common.confirm'))
    await loadRequests()
    await loadFriends()
  } else Message.error(data.message)
}

async function delFriend(id: number) {
  await friendApi.del(id)
  Message.success(t('contacts.del'))
  await loadFriends()
}

function chatWith(f: Record<string, any>) {
  Message.info(`TODO: 打开与 ${f.nickname} 的会话（阶段 3）`)
}

function userName(uid: number) {
  return `用户 #${uid}`
}
</script>

<style scoped>
.contacts-page { padding: 4px 8px; }
.toolbar { display: flex; justify-content: space-between; margin-bottom: 12px; }
.dept-members { margin-top: 12px; }
.search-result { margin-top: 12px; }
</style>
