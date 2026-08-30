<script setup>
import { ref, watch, computed } from 'vue';
import { useDialogs } from '../composables/useDialogs';
import { useContactsStore } from '../stores/contacts';
import { useAuthStore } from '../stores/auth';
import Avatar from './Avatar.vue';

const dialogs = useDialogs();
const contacts = useContactsStore();
const auth = useAuthStore();

const keyword = ref('');
const results = ref([]);
const searching = ref(false);
const friendMessage = ref('');
const groupName = ref('');
const selected = ref([]);

const titleMap = { 'new-chat': '新建聊天', 'add-friend': '添加联系人', 'create-group': '发起群聊' };

watch(
  () => dialogs.dialog.value.open,
  open => {
    if (open) {
      keyword.value = '';
      results.value = [];
      // 默认验证消息，方便用户直接发送；后端 friends/request 要求 message 非空
      const who = auth.user?.nickname || auth.user?.username || '';
      friendMessage.value = who ? `你好，我是 ${who}` : '你好，希望能加你为好友';
      groupName.value = '';
      selected.value = [];
    }
  }
);

async function doSearch() {
  if (!keyword.value.trim()) {
    results.value = [];
    return;
  }
  searching.value = true;
  results.value = await dialogs.searchUsers(keyword.value.trim());
  searching.value = false;
}
function toggle(id) {
  const i = selected.value.indexOf(id);
  if (i >= 0) selected.value.splice(i, 1);
  else selected.value.push(id);
}
const canSubmit = computed(() => {
  if (dialogs.dialog.value.type === 'create-group') return selected.value.length >= 1;
  return results.value.length > 0;
});

function addFriendFromRow(user) {
  // 后端 friends/request 必填 friend_id + message
  return dialogs.sendFriendRequest(user.id, friendMessage.value);
}

async function submit() {
  const type = dialogs.dialog.value.type;
  if (type === 'new-chat' && results.value[0]) await dialogs.startDirectWithUser(results.value[0].id);
  else if (type === 'add-friend' && results.value[0]) await dialogs.sendFriendRequest(results.value[0].id, friendMessage.value);
  else if (type === 'create-group') await dialogs.createGroup(groupName.value || '新建群聊', selected.value);
}
</script>

<template>
  <div v-if="dialogs.dialog.value.open" class="modal-layer" @click.self="dialogs.close()">
    <div class="modal-card">
      <header>
        <div>
          <span class="catalog-kicker">操作</span>
          <h2>{{ titleMap[dialogs.dialog.value.type] || '操作' }}</h2>
        </div>
        <button class="icon-button" type="button" @click="dialogs.close()"><svg><use href="#i-close" /></svg></button>
      </header>
      <div class="modal-body">
        <div class="catalog-search">
          <svg><use href="#i-search" /></svg>
          <input v-model="keyword" placeholder="输入账号 / 昵称搜索" @input="doSearch" />
        </div>

        <div v-if="dialogs.dialog.value.type === 'create-group'" class="field" style="margin:10px 0">
          <span>群名称</span>
          <input v-model="groupName" placeholder="留空则使用默认名称" />
        </div>

        <div v-if="searching" class="loading-list"><div class="skeleton"></div></div>
        <div v-else-if="!results.length" class="empty-list-state"><span>输入关键字搜索用户</span></div>
        <div v-else class="content-list">
          <label v-for="u in results" :key="u.id" class="detail-button">
            <Avatar :user="u" size="medium" />
            <small>{{ u.remark || u.nickname || u.username }}</small>
            <input
              v-if="dialogs.dialog.value.type === 'create-group'"
              type="checkbox"
              :checked="selected.includes(u.id)"
              @change="toggle(u.id)"
            />
            <button v-else-if="dialogs.dialog.value.type === 'new-chat'" class="secondary-button" type="button" @click="dialogs.startDirectWithUser(u.id)">发起聊天</button>
            <button v-else class="secondary-button" type="button" @click="addFriendFromRow(u)">加为好友</button>
          </label>
        </div>

        <div v-if="dialogs.dialog.value.type === 'add-friend'" class="field" style="margin-top:10px">
          <span>验证消息</span>
          <input v-model="friendMessage" maxlength="100" placeholder="向对方打个招呼吧" />
        </div>
      </div>
      <footer v-if="dialogs.dialog.value.type === 'create-group'" class="modal-footer">
        <button class="btn btn-primary btn-block" type="button" :disabled="!canSubmit" @click="submit">创建群聊</button>
      </footer>
    </div>
  </div>
</template>
