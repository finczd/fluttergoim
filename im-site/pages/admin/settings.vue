<script setup lang="ts">
// /admin/settings 已合并到 /admin#settings，自动跳转
definePageMeta({ layout: false })
const router = useRouter()
onMounted(() => router.replace('/admin#settings'))
</script>

<template>
  <div style="display:flex;align-items:center;justify-content:center;height:100vh;font-family:sans-serif;color:#4e5969;">
    正在跳转到设置页...
  </div>
</template>
