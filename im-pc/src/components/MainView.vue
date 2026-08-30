<script setup>
import { computed } from 'vue';
import { useUiStore } from '../stores/ui';
import { useMessagesStore } from '../stores/messages';
import RailNav from './RailNav.vue';
import CatalogPane from './CatalogPane.vue';
import ChatWorkspace from './ChatWorkspace.vue';
import ContentWorkspace from './ContentWorkspace.vue';
import ContactCard from './ContactCard.vue';
import EmptyWorkspace from './common/EmptyWorkspace.vue';

const ui = useUiStore();
const messages = useMessagesStore();

const showChat = computed(() => (ui.view === 'chats' || ui.view === 'groups') && messages.current);
const showContent = computed(() => ['favorites', 'files', 'settings'].includes(ui.view));
const showContacts = computed(() => ui.view === 'contacts');
</script>

<template>
  <section class="main-view">
    <RailNav />
    <CatalogPane />
    <main class="workspace">
      <ChatWorkspace v-if="showChat" />
      <ContentWorkspace v-else-if="showContent" />
      <ContactCard v-else-if="showContacts" />
      <EmptyWorkspace v-else />
    </main>
  </section>
</template>
