<script setup>
import { ref, computed, watch } from 'vue';
import { useUiStore } from '../stores/ui';
import { useInspector } from '../composables/useInspector';
import { useAuthStore } from '../stores/auth';
import { useContactsStore } from '../stores/contacts';
import { useMessagesStore } from '../stores/messages';
import api from '../api/client';
import Avatar from './Avatar.vue';

const ui = useUiStore();
const inspector = useInspector();
const auth = useAuthStore();
const contacts = useContactsStore();
const messages = useMessagesStore();

const conv = computed(() => ui.inspector.conversation || {});
const isGroup = computed(() => conv.value?.type === 'group');
const members = computed(() => Array.isArray(conv.value?.members) ? conv.value.members : []);
const peer = computed(() => conv.value?.peer || {});

const memberIds = computed(() => new Set(members.value.map(m => String(m.id))));

const myRole = computed(() => {
  if (!isGroup.value) return null;
  const me = String(auth.user?.id || '');
  if (!me) return null;
  const m = members.value.find(x => String(x.id) === me);
  return m?.role || null;
});
const canManage = computed(() => myRole.value === 'owner' || myRole.value === 'admin');

function memberInitial(m) {
  return m.alias || m.nickname || m.name || '成员';
}

// ---- 添加成员弹窗 ----
const showAdd = ref(false);
const addSelected = ref([]);
const addBusy = ref(false);
const addKeyword = ref('');
const addResults = ref([]);
async function openAddMembers() {
  if (!contacts.friends.length) { try { await contacts.loadFriends(false); } catch (_) {} }
  showAdd.value = true;
  addSelected.value = [];
  addKeyword.value = '';
  addResults.value = (contacts.friends || []).filter(f => !memberIds.value.has(String(f.id)));
}
function closeAdd() { showAdd.value = false; addSelected.value = []; addKeyword.value = ''; addResults.value = []; }
function togglePick(id) {
  const i = addSelected.value.indexOf(id);
  if (i >= 0) addSelected.value.splice(i, 1);
  else addSelected.value.push(id);
}
const filteredAddResults = computed(() => {
  const k = addKeyword.value.trim().toLowerCase();
  if (!k) return addResults.value;
  return addResults.value.filter(f => `${f.nickname || ''} ${f.username || ''} ${f.public_id || ''}`.toLowerCase().includes(k));
});
async function submitAdd() {
  if (!addSelected.value.length) return;
  addBusy.value = true;
  try {
    const result = await api('groups/add-members', { conversation_id: String(conv.value.id), member_ids: addSelected.value.map(String), history_mode: 'none' }, 'POST');
    ui.toast(result?.requires_confirmation ? '邀请已发送，等待对方确认' : '成员已添加');
    closeAdd();
    try { await inspector.openConversation(conv.value); } catch (_) {}
  } catch (e) { ui.toast('添加失败', e.message, 'error'); }
  finally { addBusy.value = false; }
}

// ---- 群公告编辑 ----
const annText = ref('');
const annBusy = ref(false);
const editingAnn = ref(false);
watch(
  () => conv.value?.announcement,
  a => {
    if (a && typeof a === 'object') annText.value = a.content || a.text || '';
    else if (typeof a === 'string') annText.value = a;
  },
  { immediate: true }
);
function startEditAnn() { editingAnn.value = true; }
function cancelEditAnn() {
  editingAnn.value = false;
  // 还原原始
  const a = conv.value?.announcement;
  if (a && typeof a === 'object') annText.value = a.content || a.text || '';
  else if (typeof a === 'string') annText.value = a;
}
async function saveAnn() {
  if (!annText.value.trim()) { ui.toast('请输入公告内容', '', 'warning'); return; }
  annBusy.value = true;
  try {
    await api('groups/announcement', { conversation_id: String(conv.value.id), content: annText.value.trim() }, 'POST');
    ui.toast('群公告已发布');
    editingAnn.value = false;
    try { await inspector.openConversation(conv.value); } catch (_) {}
  } catch (e) { ui.toast('发布失败', e.message, 'error'); }
  finally { annBusy.value = false; }
}

// ---- 群成员搜索 + T 人 ----
const memberKeyword = ref('');
const filteredMembers = computed(() => {
  const k = memberKeyword.value.trim().toLowerCase();
  if (!k) return members.value;
  return members.value.filter(m => {
    const name = String(m.alias || m.nickname || m.name || '');
    const acc = String(m.public_id || m.username || '');
    return name.toLowerCase().includes(k) || acc.toLowerCase().includes(k);
  });
});
// 是否允许对某成员执行 T 人（管理员才能操作，且不能是群主/自己）
function canRemoveMember(m) {
  if (!canManage.value) return false;
  if (String(m.id) === String(auth.user?.id)) return false;
  if (String(m.id) === String(conv.value.owner_id)) return false;
  return true;
}

// ---- 右键移除成员 ----
const removeTarget = ref(null); // {id, nickname}
function onMemberContext(e, m) {
  if (!canRemoveMember(m)) return;
  e.preventDefault();
  removeTarget.value = m;
  ui.openContextMenu(e.clientX, e.clientY, [
    { label: 'T 出群聊', icon: 'i-close', danger: true, onClick: () => confirmRemove() }
  ]);
}
async function confirmRemove() {
  const m = removeTarget.value;
  if (!m) return;
  try {
    await api('groups/remove-member', { conversation_id: String(conv.value.id), user_id: String(m.id) }, 'POST');
    ui.toast('已移除 ' + memberInitial(m));
    removeTarget.value = null;
    try { await inspector.openConversation(conv.value); } catch (_) {}
  } catch (e) { ui.toast('移除失败', e.message, 'error'); }
  finally { removeTarget.value = null; }
}

// 直接点成员头像右上角的 × T 人
async function kickMember(m) {
  try {
    await api('groups/remove-member', { conversation_id: String(conv.value.id), user_id: String(m.id) }, 'POST');
    ui.toast('已移除 ' + memberInitial(m));
    try { await inspector.openConversation(conv.value); } catch (_) {}
  } catch (e) { ui.toast('移除失败', e.message, 'error'); }
}
</script>

<template>
  <aside v-if="ui.inspector.open" class="inspector">
    <header class="inspector-header">
      <strong>{{ ui.inspector.title }}</strong>
      <button class="icon-button" type="button" @click="ui.closeInspector()"><svg><use href="#i-close" /></svg></button>
    </header>

    <!-- 用户资料 -->
    <div v-if="ui.inspector.kind === 'user' && ui.inspector.user" class="inspector-body">
      <div class="inspector-profile">
        <Avatar :user="ui.inspector.user" size="huge" />
        <h3>{{ ui.inspector.user.nickname || '用户' }}</h3>
        <p>{{ ui.inspector.user.online_text || '' }}</p>
      </div>
      <div class="inspector-actions">
        <button class="secondary-button" type="button" @click="inspector.messageUser()">发消息</button>
      </div>
      <div class="inspector-section">
        <div class="detail-list">
          <div class="detail-button"><span>账号</span><small>{{ ui.inspector.user.public_id || ui.inspector.user.username || '' }}</small></div>
          <div class="detail-button"><span>所在地</span><small>{{ ui.inspector.user.region || '未设置' }}</small></div>
          <div class="detail-button"><span>个性签名</span><small>{{ ui.inspector.user.bio || '未设置' }}</small></div>
        </div>
      </div>
    </div>

    <!-- 会话资料：群聊 / 单聊 -->
    <div v-else-if="ui.inspector.kind === 'conversation'" class="inspector-body">
      <div class="inspector-profile">
        <Avatar :user="conv" size="huge" />
        <h3>{{ conv.title || (isGroup ? '群聊' : '会话') }}</h3>
        <p>{{ isGroup ? `${members.length} 位成员` : (peer.online_text || '在线聊天') }}</p>
      </div>

      <div v-if="isGroup && canManage" class="inspector-actions">
        <button class="secondary-button" type="button" @click="openAddMembers">+ 添加成员</button>
      </div>

      <!-- 群公告：群主/管理员可编辑 -->
      <div v-if="isGroup" class="inspector-section">
        <div class="inspector-section-title">
          <strong>群公告</strong>
          <button v-if="canManage && !editingAnn" class="mini-link" type="button" @click="startEditAnn">{{ annText ? '编辑' : '发布' }}</button>
        </div>
        <div v-if="editingAnn" class="ann-editor">
          <textarea v-model="annText" rows="3" maxlength="500" placeholder="向群成员发布公告…" />
          <div class="ann-editor-actions">
            <button class="secondary-button" type="button" @click="cancelEditAnn">取消</button>
            <button class="primary-button" type="button" :disabled="annBusy" @click="saveAnn">{{ annBusy ? '发布中…' : '发布' }}</button>
          </div>
        </div>
        <div v-else-if="annText" class="ann-display">{{ annText }}</div>
        <div v-else class="empty-list-state"><span>{{ canManage ? '暂未发布群公告' : '群主暂未发布公告' }}</span></div>
      </div>

      <div class="inspector-section">
        <div class="detail-list">
          <div class="detail-button" v-if="!isGroup"><span>账号</span><small>{{ peer.public_id || peer.username || '' }}</small></div>
          <div class="detail-button" v-if="!isGroup"><span>所在地</span><small>{{ peer.region || '未设置' }}</small></div>
          <div class="detail-button"><span>{{ isGroup ? '群号' : '签名' }}</span><small>{{ isGroup ? (conv.group_code || '—') : (peer.bio || '未设置') }}</small></div>
          <div v-if="isGroup" class="detail-button"><span>入群方式</span><small>{{ ({ invite: '邀请制', approval: '需审批', open: '自由加入' })[conv.join_mode] || '邀请制' }}</small></div>
        </div>
      </div>

      <!-- 群成员 -->
      <div v-if="isGroup" class="inspector-section">
        <div class="inspector-section-title">
          <strong>群成员</strong>
          <span>{{ members.length }} 人</span>
        </div>
        <div class="catalog-search member-search">
          <svg><use href="#i-search" /></svg>
          <input v-model="memberKeyword" placeholder="搜索成员昵称 / 账号" />
        </div>
        <div v-if="!filteredMembers.length" class="empty-list-state"><span>没有匹配的成员</span></div>
        <div v-else class="member-grid">
          <div v-for="m in filteredMembers" :key="m.id" class="member-wrap">
            <div
              class="member"
              role="button"
              tabindex="0"
              @click="inspector.openMember(m.id)"
              @keydown.enter="inspector.openMember(m.id)"
              @contextmenu="onMemberContext($event, m)"
            >
              <span class="member-avatar">
                <Avatar :user="m" size="medium" />
                <button
                  v-if="canRemoveMember(m)"
                  class="member-kick"
                  type="button"
                  title="T 出群聊"
                  @click.stop="kickMember(m)"
                >
                  <svg><use href="#i-close" /></svg>
                </button>
              </span>
              <span class="member-name">{{ memberInitial(m) }}</span>
            </div>
          </div>
        </div>
        <p v-if="canManage" class="member-tip">提示：点成员头像右上角 × 可 T 出群聊（也可右键）</p>
      </div>
    </div>

    <!-- 通用 HTML -->
    <div v-else class="inspector-body" v-html="ui.inspector.body"></div>

    <!-- 添加成员弹窗 -->
    <div v-if="showAdd" class="modal-layer" @click.self="closeAdd">
      <div class="modal-card add-members-modal">
        <header>
          <div>
            <span class="catalog-kicker">群管理</span>
            <h2>添加成员</h2>
          </div>
          <button class="icon-button" type="button" @click="closeAdd"><svg><use href="#i-close" /></svg></button>
        </header>
        <div class="modal-body">
          <div class="catalog-search">
            <svg><use href="#i-search" /></svg>
            <input v-model="addKeyword" placeholder="搜索好友" />
          </div>
          <div v-if="!filteredAddResults.length" class="empty-list-state"><strong>暂无可添加的好友</strong><span>先添加一些好友再拉人进群</span></div>
          <div v-else class="content-list">
            <label v-for="f in filteredAddResults" :key="f.id" class="detail-button">
              <Avatar :user="f" size="medium" />
              <small>{{ f.remark || f.nickname || f.username }}</small>
              <input type="checkbox" :checked="addSelected.includes(String(f.id))" @change="togglePick(String(f.id))" />
            </label>
          </div>
        </div>
        <footer class="modal-footer">
          <span class="add-selected-hint">已选 {{ addSelected.length }} 人</span>
          <button class="secondary-button" type="button" @click="closeAdd">取消</button>
          <button class="primary-button" type="button" :disabled="!addSelected.length || addBusy" @click="submitAdd">{{ addBusy ? '提交中…' : '添加' }}</button>
        </footer>
      </div>
    </div>
  </aside>
</template>

