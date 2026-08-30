<script setup>
import { ref, watch, onMounted } from 'vue';

const props = defineProps({ payload: { type: String, default: '' } });
const canvas = ref(null);

function render() {
  if (!props.payload || !canvas.value || !window.ZcQr) return;
  const matrix = window.ZcQr.qrMatrix(props.payload);
  const ctx = canvas.value.getContext('2d');
  const quiet = 4;
  const size = matrix.length + quiet * 2;
  const cell = canvas.value.width / size;
  ctx.fillStyle = '#fff';
  ctx.fillRect(0, 0, canvas.value.width, canvas.value.height);
  ctx.fillStyle = '#101820';
  for (let row = 0; row < matrix.length; row++) {
    for (let col = 0; col < matrix.length; col++) {
      if (matrix[row][col]) {
        ctx.fillRect(Math.round((col + quiet) * cell), Math.round((row + quiet) * cell), Math.ceil(cell), Math.ceil(cell));
      }
    }
  }
}

onMounted(render);
watch(() => props.payload, render);
</script>

<template>
  <canvas ref="canvas" width="232" height="232" aria-label="登录二维码" :class="{ hidden: !payload }"></canvas>
</template>
