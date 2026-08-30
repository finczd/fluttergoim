<template>
  <div class="login-page">
    <div class="card">
      <h1>{{ t('app.name') }}</h1>

      <!-- 登录 / 注册 Tab -->
      <div class="tabs">
        <button :class="{ active: mode === 'login' }" @click="mode = 'login'">{{ t('auth.login') }}</button>
        <button :class="{ active: mode === 'register' }" @click="switchRegister">{{ t('auth.register') }}</button>
      </div>

      <form @submit.prevent="onSubmit">
        <input v-model="account" :placeholder="t('auth.account')" autocomplete="username" />
        <input v-model="password" type="password" :placeholder="t('auth.password')" autocomplete="current-password" />

        <!-- 注册：昵称 -->
        <template v-if="mode === 'register'">
          <input v-model="nickname" :placeholder="t('auth.nickname')" />
        </template>

        <!-- 图形验证码（防刷，注册/发码前必填） -->
        <div class="code-row">
          <input v-model="captchaCode" :placeholder="t('auth.captcha')" maxlength="4" />
          <img v-if="captchaImg" :src="'data:image/png;base64,' + captchaImg" class="captcha-img" @click="loadCaptcha" :alt="t('auth.captcha')" />
          <button v-else type="button" @click="loadCaptcha">{{ t('auth.refresh') }}</button>
        </div>

        <!-- 认证模式：sms/email 显示短信/邮箱验证码 -->
        <div v-if="authConfig.authMode !== 'none' && mode === 'register'" class="code-row">
          <input v-model="code" :placeholder="t('auth.code')" />
          <button type="button" :disabled="countdown > 0" @click="sendCode">
            {{ countdown > 0 ? countdown + 's' : t('auth.sendCode') }}
          </button>
        </div>

        <!-- 邀请码开关 -->
        <input v-if="authConfig.inviteCodeOn && mode === 'register'" v-model="inviteCode" :placeholder="t('auth.inviteCode')" />

        <button type="submit" class="primary" :disabled="loading">
          {{ loading ? t('common.loading') : mode === 'login' ? t('auth.login') : t('auth.register') }}
        </button>
      </form>

      <div class="footer">
        <button class="lang-btn" @click="toggleLang">{{ currentLang === 'zh-CN' ? 'EN' : '中文' }}</button>
        <span class="error">{{ error }}</span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import { setLocale } from '@/i18n'
import { useAuthStore } from '@/stores/auth'
import { authApi, type AuthConfig } from '@/api/auth'

const { t, locale } = useI18n()
const router = useRouter()
const auth = useAuthStore()

const mode = ref<'login' | 'register'>('login')
const currentLang = ref(locale.value as string)
const langKey = computed(() => locale.value as string)

const account = ref('')
const password = ref('')
const nickname = ref('')
const code = ref('')
const inviteCode = ref('')
const captchaId = ref('')
const captchaCode = ref('')
const captchaImg = ref('')
const countdown = ref(0)
const loading = ref(false)
const error = ref('')

const authConfig = ref<AuthConfig>({ authMode: 'none', inviteCodeOn: false, registerOn: true, e2eOn: false })

onMounted(async () => {
  const { data: cfg } = await authApi.getConfig()
  authConfig.value = cfg.data
  await loadCaptcha()
})

async function loadCaptcha() {
  const { data } = await authApi.captcha()
  captchaId.value = data.data.captchaId
  captchaImg.value = data.data.image
  captchaCode.value = ''
}

function switchRegister() {
  mode.value = 'register'
  if (authConfig.value.registerOn === false) {
    error.value = t('auth.registerOff')
  }
}

async function sendCode() {
  error.value = ''
  try {
    await authApi.sendCode(account.value, captchaId.value, captchaCode.value)
    countdown.value = 60
    const timer = setInterval(() => {
      countdown.value--
      if (countdown.value <= 0) clearInterval(timer)
    }, 1000)
  } catch (e: unknown) {
    error.value = (e as { message?: string }).message || t('common.error')
  }
}

async function onSubmit() {
  error.value = ''
  loading.value = true
  try {
    if (mode.value === 'login') {
      const { data } = await authApi.login({ account: account.value, password: password.value, deviceType: 3 })
      if (data.code !== 0) return (error.value = data.message)
      auth.setToken(data.data.accessToken)
      auth.setRefresh(data.data.refreshToken)
      router.push('/')
    } else {
      const { data } = await authApi.register({
        account: account.value,
        password: password.value,
        nickname: nickname.value,
        code: authConfig.value.authMode !== 'none' ? code.value : undefined,
        inviteCode: authConfig.value.inviteCodeOn ? inviteCode.value : undefined,
        captchaId: captchaId.value,
        captchaCode: captchaCode.value,
        deviceType: 3
      })
      if (data.code !== 0) {
        error.value = data.message
        await loadCaptcha() // 失败刷新图形验证码
        return
      }
      auth.setToken(data.data.accessToken)
      auth.setRefresh(data.data.refreshToken)
      router.push('/')
    }
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
.login-page { height: 100vh; display: flex; align-items: center; justify-content: center; background: #f5f7fa; }
.card { width: 360px; background: #fff; border-radius: 16px; padding: 32px; box-shadow: 0 8px 32px rgba(20,24,31,.08); }
.card h1 { margin: 0 0 20px; font-size: 22px; }
.tabs { display: flex; gap: 8px; margin-bottom: 20px; }
.tabs button { flex: 1; padding: 8px; border: 1px solid #edeff2; background: #fff; border-radius: 8px; cursor: pointer; color: #6b7480; }
.tabs button.active { background: #1f6feb; color: #fff; border-color: #1f6feb; }
.card form { display: flex; flex-direction: column; gap: 12px; }
.card input, .card select { padding: 10px 14px; border: 1px solid #edeff2; border-radius: 8px; font-size: 14px; }
.primary { padding: 10px; background: #1f6feb; color: #fff; border: none; border-radius: 8px; cursor: pointer; font-size: 14px; }
.primary:disabled { opacity: .6; }
.code-row { display: flex; gap: 8px; }
.code-row input { flex: 1; min-width: 0; }
.code-row button { flex-shrink: 0; padding: 0 12px; border: 1px solid #edeff2; background: #fff; border-radius: 8px; cursor: pointer; color: #1f6feb; }
.captcha-img { width: 96px; height: 38px; border-radius: 8px; cursor: pointer; border: 1px solid #edeff2; }
.footer { margin-top: 16px; display: flex; justify-content: space-between; align-items: center; }
.lang-btn { border: none; background: none; color: #1f6feb; cursor: pointer; font-size: 13px; }
.error { color: #f53f3f; font-size: 12px; max-width: 200px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
</style>
