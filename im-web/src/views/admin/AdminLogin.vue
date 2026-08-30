<template>
  <div class="admin-login">
    <a-card class="card">
      <h2>企业IM管理后台</h2>
      <a-form :model="form" layout="vertical" @submit="onLogin">
        <a-form-item label="账号">
          <a-input v-model="form.account" placeholder="管理员账号" />
        </a-form-item>
        <a-form-item label="密码">
          <a-input-password v-model="form.password" placeholder="密码" />
        </a-form-item>
        <a-form-item label="图形验证码">
          <div class="code-row">
            <a-input v-model="form.captchaCode" placeholder="验证码" maxlength="4" />
            <img v-if="captchaImg" :src="'data:image/png;base64,' + captchaImg" class="captcha-img" @click="loadCaptcha" alt="captcha" />
          </div>
        </a-form-item>
        <a-form-item>
          <a-button type="primary" long html-type="submit" :loading="loading">登录</a-button>
        </a-form-item>
      </a-form>
      <a-alert v-if="error" type="error" :message="error" />
      <a-button class="lang-btn" size="mini" @click="toggleLang">{{ currentLang === 'zh-CN' ? 'EN' : '中文' }}</a-button>
    </a-card>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Message } from '@arco-design/web-vue'
import { useI18n } from 'vue-i18n'
import { authApi } from '@/api/auth'
import { setLocale } from '@/i18n'

const router = useRouter()
const { locale } = useI18n()
const currentLang = ref(locale.value as string)

const form = ref({ account: '', password: '', captchaCode: '' })
const captchaId = ref('')
const captchaImg = ref('')
const loading = ref(false)
const error = ref('')

onMounted(loadCaptcha)

async function loadCaptcha() {
  const { data } = await authApi.captcha()
  captchaId.value = data.data.captchaId
  captchaImg.value = data.data.image
  form.value.captchaCode = ''
}

async function onLogin() {
  error.value = ''
  loading.value = true
  try {
    const { data } = await authApi.login({ account: form.value.account, password: form.value.password, deviceType: 3 })
    if (data.code !== 0) {
      error.value = data.message
      await loadCaptcha()
      return
    }
    const role = (data.data.user as { role?: number })?.role
    if (role !== 2) {
      error.value = '非管理员账号'
      await loadCaptcha()
      return
    }
    localStorage.setItem('im-token', data.data.accessToken)
    localStorage.setItem('im-refresh', data.data.refreshToken)
    Message.success('登录成功')
    router.push('/admin/users')
  } catch {
    error.value = '登录失败'
  } finally {
    loading.value = false
  }
}

function toggleLang() {
  const next = currentLang.value === 'zh-CN' ? 'en-US' : 'zh-CN'
  setLocale(next)
  currentLang.value = next
}
</script>

<style scoped>
.admin-login { height: 100vh; display: flex; align-items: center; justify-content: center; background: #1f2329; }
.card { width: 380px; }
.card h2 { margin: 0 0 20px; }
.code-row { display: flex; gap: 8px; width: 100%; }
.code-row :deep(.arco-input) { flex: 1; }
.captcha-img { width: 96px; height: 32px; border-radius: 6px; cursor: pointer; border: 1px solid var(--color-border-2); }
.lang-btn { margin-top: 12px; }
</style>
