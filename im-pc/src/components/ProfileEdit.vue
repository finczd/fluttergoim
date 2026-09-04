<script setup>
import { ref } from 'vue';
import { useAuthStore } from '../stores/auth';
import { useUiStore } from '../stores/ui';
import { uploadFile } from '../api/client';
import Avatar from './Avatar.vue';

const emit = defineEmits(['close']);
const auth = useAuthStore();
const ui = useUiStore();

const me = auth.user || {};
const nickname = ref(me.nickname || '');
const avatarUrl = ref(me.avatar || '');

const nickBusy = ref(false);
const avatarBusy = ref(false);
const pwdBusy = ref(false);

async function saveNickname() {
  if (!nickname.value.trim()) { ui.toast('昵称不能为空', '', 'warning'); return; }
  nickBusy.value = true;
  try {
    await auth.updateProfile({ nickname: nickname.value.trim(), avatar: avatarUrl.value });
    ui.toast('昵称已更新');
  } catch (e) { ui.toast('更新失败', e.message, 'error'); }
  finally { nickBusy.value = false; }
}

async function pickAvatar() {
  const input = document.createElement('input');
  input.type = 'file';
  input.accept = 'image/*';
  input.onchange = async () => {
    const file = input.files[0];
    if (!file) return;
    avatarBusy.value = true;
    try {
      const up = await uploadFile(file);
      avatarUrl.value = up.url;
      await auth.updateProfile({ nickname: nickname.value.trim(), avatar: up.url });
      ui.toast('头像已更新');
    } catch (e) { ui.toast('头像更新失败', e.message, 'error'); }
    finally { avatarBusy.value = false; }
  };
  input.click();
}

const oldPwd = ref('');
const newPwd = ref('');
const pwdError = ref('');

async function changePassword() {
  pwdError.value = '';
  if (!oldPwd.value || !newPwd.value) { pwdError.value = '请输入原密码和新密码'; return; }
  pwdBusy.value = true;
  try {
    await auth.changePassword(oldPwd.value, newPwd.value);
    ui.toast('密码已修改');
    oldPwd.value = '';
    newPwd.value = '';
  } catch (e) { pwdError.value = e.message || '修改失败'; }
  finally { pwdBusy.value = false; }
}
</script>

<template>
  <div class="modal-layer" @click.self="emit('close')">
    <div class="modal-card profile-edit-modal">
      <header>
        <div>
          <span class="catalog-kicker">个人资料</span>
          <h2>编辑资料</h2>
        </div>
        <button class="icon-button" type="button" @click="emit('close')"><svg><use href="#i-close" /></svg></button>
      </header>
      <div class="modal-body">
        <div class="profile-edit-head">
          <Avatar :user="{ nickname: nickname, avatar: avatarUrl }" size="huge" />
          <button class="secondary-button" type="button" :disabled="avatarBusy" @click="pickAvatar">
            {{ avatarBusy ? '上传中…' : '更换头像' }}
          </button>
        </div>

        <div class="profile-edit-field">
          <label>昵称</label>
          <div class="profile-edit-row">
            <input v-model="nickname" maxlength="24" placeholder="请输入昵称" />
            <button class="primary-button" type="button" :disabled="nickBusy" @click="saveNickname">
              {{ nickBusy ? '保存中…' : '保存' }}
            </button>
          </div>
        </div>

        <div class="profile-edit-divider"></div>

        <div class="profile-edit-field">
          <label>修改密码</label>
          <input v-model="oldPwd" type="password" placeholder="原密码" />
          <input v-model="newPwd" type="password" placeholder="新密码（8-20 位）" />
          <div v-if="pwdError" class="profile-edit-error">{{ pwdError }}</div>
          <button class="primary-button wide" type="button" :disabled="pwdBusy" @click="changePassword">
            {{ pwdBusy ? '提交中…' : '确认修改密码' }}
          </button>
        </div>
      </div>
      <footer class="modal-footer">
        <button class="secondary-button" type="button" @click="emit('close')">关闭</button>
      </footer>
    </div>
  </div>
</template>
