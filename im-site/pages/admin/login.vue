<template>
  <div class="login-page">
    <div class="login-card">
      <div class="login-header">
        <svg viewBox="0 0 64 64" width="48" height="48">
          <defs>
            <linearGradient id="lg" x1="0" y1="0" x2="1" y2="1">
              <stop offset="0%" stop-color="#165dff"/>
              <stop offset="100%" stop-color="#4080ff"/>
            </linearGradient>
          </defs>
          <rect width="64" height="64" rx="14" fill="url(#lg)"/>
          <path d="M20 22h24a4 4 0 0 1 4 4v12a4 4 0 0 1-4 4H30l-8 6v-6h-2a4 4 0 0 1-4-4V26a4 4 0 0 1 4-4z" fill="#fff"/>
        </svg>
        <h1>ChatPulse 后台管理</h1>
        <p>输入账号和密码登录</p>
      </div>

      <form @submit.prevent="doLogin" novalidate>
        <div class="input-group">
          <label class="label">管理员账号</label>
          <input
            v-model="username"
            type="text"
            placeholder="admin"
            :disabled="loading"
            autocomplete="username"
            autofocus
          />
        </div>

        <div class="input-group">
          <label class="label">密码</label>
          <div class="pwd-wrap">
            <input
              v-model="password"
              :type="showPwd ? 'text' : 'password'"
              placeholder="请输入密码"
              :disabled="loading"
              autocomplete="current-password"
              @keyup.enter.prevent="doLogin"
            />
            <button
              type="button"
              class="eye-btn"
              @click="showPwd = !showPwd"
              :aria-label="showPwd ? '隐藏密码' : '显示密码'"
            >
              <svg v-if="!showPwd" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#86909c" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8S1 12 1 12z"/><circle cx="12" cy="12" r="3"/></svg>
              <svg v-else width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#86909c" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20C5 20 1 12 1 12a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19M1 1l22 22"/><path d="M14.12 14.12A3 3 0 1 1 9.88 9.88"/></svg>
            </button>
          </div>
        </div>

        <div v-if="error" class="error-banner">{{ error }}</div>
        <button type="submit" class="login-btn" :disabled="loading || !username || !password">
          {{ loading ? '登录中...' : '登 录' }}
        </button>
      </form>
    </div>
  </div>
</template>

<script setup lang="ts">
definePageMeta({ layout: false })
useHead({
  title: '登录 - ChatPulse 后台管理',
  meta: [{ name: 'robots', content: 'noindex,nofollow' }],
})

const username = ref('')
const password = ref('')
const showPwd = ref(false)
const loading = ref(false)
const error = ref('')

async function doLogin() {
  error.value = ''
  if (!username.value.trim() || !password.value) {
    error.value = '请输入账号和密码'
    return
  }
  loading.value = true
  try {
    const res = await $fetch<any>('/api/admin/login', {
      method: 'POST',
      body: { username: username.value.trim(), password: password.value },
    })
    if (res.code === 0) {
      await navigateTo('/admin')
    } else {
      error.value = res.message || '登录失败'
    }
  } catch (e: any) {
    error.value = e.data?.message || e.message || '登录失败，请检查账号密码'
  } finally {
    loading.value = false
  }
}

onMounted(async () => {
  try {
    await $fetch('/api/admin/me')
    await navigateTo('/admin')
  } catch { /* 未登录，停留 */ }
})
</script>

<style scoped>
.login-page {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 100vh;
  background: linear-gradient(135deg, #165dff 0%, #4080ff 100%);
  padding: 24px;
}
.login-card {
  width: 400px;
  max-width: 100%;
  background: #fff;
  border-radius: 16px;
  padding: 40px 32px 32px;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.15);
}
.login-header {
  text-align: center;
  margin-bottom: 24px;
}
.login-header h1 {
  font-size: 22px;
  font-weight: 700;
  color: #1d2129;
  margin: 12px 0 4px;
}
.login-header p {
  font-size: 14px;
  color: #86909c;
  margin: 0;
}
.input-group {
  margin-bottom: 16px;
}
.label {
  display: block;
  font-size: 13px;
  font-weight: 500;
  color: #4e5969;
  margin-bottom: 6px;
}
.input-group input {
  width: 100%;
  padding: 12px 16px;
  border: 1px solid #e5e6eb;
  border-radius: 10px;
  font-size: 15px;
  transition: border-color 0.2s, box-shadow 0.2s;
  outline: none;
  background: #fff;
  box-sizing: border-box;
}
.input-group input:focus {
  border-color: #165dff;
  box-shadow: 0 0 0 3px rgba(22, 93, 255, 0.12);
}
.pwd-wrap {
  position: relative;
}
.pwd-wrap input {
  padding-right: 44px;
}
.eye-btn {
  position: absolute;
  right: 8px;
  top: 50%;
  transform: translateY(-50%);
  background: transparent;
  border: none;
  padding: 6px;
  cursor: pointer;
  border-radius: 6px;
}
.eye-btn:hover {
  background: #f2f3f5;
}
.error-banner {
  background: #ffece8;
  color: #f53f3f;
  font-size: 13px;
  padding: 10px 12px;
  border-radius: 8px;
  margin-top: 4px;
  margin-bottom: 16px;
  line-height: 1.5;
}
.login-btn {
  width: 100%;
  margin-top: 8px;
  padding: 12px;
  background: linear-gradient(135deg, #165dff, #4080ff);
  color: #fff;
  border: none;
  border-radius: 10px;
  font-size: 15px;
  font-weight: 600;
  cursor: pointer;
  transition: opacity 0.2s, transform 0.1s;
}
.login-btn:hover:not(:disabled) {
  opacity: 0.92;
}
.login-btn:active:not(:disabled) {
  transform: translateY(1px);
}
.login-btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}
</style>
