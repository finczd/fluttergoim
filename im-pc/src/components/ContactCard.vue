<script setup>
import { computed } from 'vue';
import { useUiStore } from '../stores/ui';
import { useMessagesStore } from '../stores/messages';
import { useInspector } from '../composables/useInspector';
import Avatar from './Avatar.vue';

const ui = useUiStore();
const messages = useMessagesStore();
const inspector = useInspector();

const contact = computed(() => ui.selectedContact || {});
const name = computed(() => contact.value.remark || contact.value.nickname || contact.value.username || '联系人');

async function sendMessage() {
  const id = String(contact.value.id || '');
  if (!id) return;
  await messages.openDirect(id);
}

function viewProfile() {
  const id = String(contact.value.id || '');
  if (id) inspector.openUser(id, contact.value);
}
</script>

<template>
  <section class="contact-workspace" v-if="ui.selectedContact">
    <div class="contact-card">
      <div class="contact-hero">
        <Avatar :user="contact" size="huge" />
        <h2>{{ name }}</h2>
        <p>{{ contact.online_text || '离线' }}</p>
      </div>

      <div class="contact-actions">
        <button class="primary-button" type="button" @click="sendMessage">
          <svg><use href="#i-send" /></svg>
          <span>发送消息</span>
        </button>
        <button class="secondary-button" type="button" @click="viewProfile">查看资料</button>
      </div>

      <div class="inspector-section">
        <div class="detail-list">
          <div class="detail-button"><span>账号</span><small>{{ contact.public_id || contact.short_id || contact.username || '' }}</small></div>
          <div class="detail-button"><span>备注</span><small>{{ contact.remark || '未设置' }}</small></div>
          <div class="detail-button"><span>所在地</span><small>{{ contact.region || '未设置' }}</small></div>
          <div class="detail-button"><span>个性签名</span><small>{{ contact.bio || '未设置' }}</small></div>
        </div>
      </div>
    </div>
  </section>

  <section class="contact-workspace empty" v-else>
    <div class="empty-list-state">
      <strong>选择一个联系人</strong>
      <span>点击左侧好友，在这里查看资料并发消息</span>
    </div>
  </section>
</template>
