<template>
  <Teleport to="body">
    <div class="modal-mask" @click.self="$emit('close')">
      <div class="modal-wrap" role="dialog" aria-modal="true">
        <div class="modal-head">
          <h3>{{ title }}</h3>
          <button class="close-btn" @click="$emit('close')" aria-label="关闭">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#86909c" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
          </button>
        </div>
        <div class="modal-body"><slot /></div>
      </div>
    </div>
  </Teleport>
</template>

<script setup lang="ts">
defineProps<{ title: string }>()
defineEmits<{ (e: 'close'): void }>()
</script>

<style scoped>
.modal-mask {
  position: fixed; inset: 0; z-index: 1000;
  background: rgba(29, 33, 41, 0.45);
  display: flex; align-items: center; justify-content: center;
  padding: 20px;
  backdrop-filter: blur(2px);
}
.modal-wrap {
  background: #fff; border-radius: 14px;
  width: 100%; max-width: 560px;
  max-height: 90vh; overflow: hidden;
  display: flex; flex-direction: column;
  box-shadow: 0 24px 60px rgba(0, 0, 0, 0.18);
}
.modal-head {
  display: flex; align-items: center; justify-content: space-between;
  padding: 16px 20px; border-bottom: 1px solid #f2f3f5;
}
.modal-head h3 { margin: 0; font-size: 16px; font-weight: 700; color: #1d2129; }
.close-btn {
  background: transparent; border: none; padding: 4px; border-radius: 6px; cursor: pointer;
  display: inline-flex; align-items: center; justify-content: center;
}
.close-btn:hover { background: #f2f3f5; }
.modal-body { padding: 20px; overflow: auto; }
</style>
