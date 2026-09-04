<script setup>
import { ref, computed } from 'vue';
import { useMessagesStore } from '../stores/messages';
import { useInspector } from '../composables/useInspector';
import { useUiStore } from '../stores/ui';
import { useAuthStore } from '../stores/auth';
import Avatar from './Avatar.vue';

const props = defineProps({
  conversationId: { type: String, required: true }
});
const emit = defineEmits(['close']);

const messages = useMessagesStore();
const inspector = useInspector();
const ui = useUiStore();
const auth = useAuthStore();

const members = computed(() => Array.isArray(messages.currentDetail?.members) ? messages.currentDetail.members : []);
const ownerId = computed(() => String(messages.currentDetail?.owner_id || ''));

// 普通成员（role=3）可设为管理员；群主与已管理员不可再操作
const candidates = computed(() => members.value.filter(m => {
  const r = Number(m.role || 3);
  return r === 3 && String(m.id) !== ownerId.value && String(m.id) !== String(auth.user?.id || '');
}));
const admins = computed(() => members.value.filter(m => Number(m.role) === 2));

const busyId = ref('');

async function promote(m) {
  busyId.value = String(m.id);
  try {
    await inspector.addGroupAdmin(props.conversationId, String(m.id), true);
    ui.toast('已设为管理员');
    await inspector.openConversation(messages.current);
  } catch (e) { ui.toast('操作失败', e.message, 'error'); }
  finally { busyId.value = ''; }
}
async function demote(m) {
  busyId.value = String(m.id);
  try {
    await inspector.addGroupAdmin(props.conversationId, String(m.id), false);
    ui.toast('已取消管理员');
    await inspector.openConversation(messages.current);
  } catch (e) { ui.toast('操作失败', e.message, 'error'); }
  finally { busyId.value = ''; }
}
</script>

<template>
  <div class="modal-layer" @click.self="emit('close')">
    <div class="modal-card add-members-modal">
      <header>
        <div>
          <span class="catalog-kicker">群管理</span>
          <h2>群管理员</h2>
        </div>
        <button class="icon-button" type="button" @click="emit('close')"><svg><use href="#i-close" /></svg></button>
      </header>
      <div class="modal-body">
        <div v-if="admins.length" class="group-admin-block">
          <div class="eyebrow">当前管理员</div>
          <label v-for="m in admins" :key="m.id" class="detail-button">
            <Avatar :user="m" size="medium" />
            <small class="group-admin-name">{{ m.alias || m.nickname || m.username || '成员' }}</small>
            <button class="mini-link danger" type="button" :disabled="busyId === String(m.id)" @click="demote(m)">取消</button>
          </label>
        </div>
        <div v-if="candidates.length" class="group-admin-block">
          <div class="eyebrow">设为管理员</div>
          <label v-for="m in candidates" :key="m.id" class="detail-button">
            <Avatar :user="m" size="medium" />
            <small class="group-admin-name">{{ m.alias || m.nickname || m.username || '成员' }}</small>
            <button class="mini-link" type="button" :disabled="busyId === String(m.id)" @click="promote(m)">设为</button>
          </label>
        </div>
        <div v-if="!admins.length && !candidates.length" class="empty-list-state"><span>没有可管理的成员</span></div>
      </div>
      <footer class="modal-footer">
        <button class="secondary-button" type="button" @click="emit('close')">关闭</button>
      </footer>
    </div>
  </div>
</template>
