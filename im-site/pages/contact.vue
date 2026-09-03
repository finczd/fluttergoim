<template>
  <div class="contact-page">
    <!-- ============ HERO ============ -->
    <section class="hero">
      <div class="hero-bg-deco" aria-hidden="true">
        <span class="orb orb-1"></span>
        <span class="orb orb-2"></span>
      </div>
      <div class="container hero-inner">
        <span class="hero-badge">1 个工作日内回复</span>
        <h1 class="hero-title">联系我们</h1>
        <p class="hero-subtitle">留下您的姓名和联系方式，我们主动与您沟通</p>
      </div>
    </section>

    <!-- ============ CONTACT MAIN ============ -->
    <section class="section">
      <div class="container">
        <div class="contact-grid">
          <!-- LEFT: FORM -->
          <div class="card form-card fade-in-up">
            <h2 class="form-title">提交您的信息</h2>
            <p class="form-sub">填写下方两项信息即可，简单快捷</p>

            <form class="contact-form" @submit.prevent="handleSubmit">
              <div class="form-field">
                <label for="name">姓名 <span class="req">*</span></label>
                <input
                  id="name"
                  v-model="form.name"
                  type="text"
                  placeholder="请输入您的姓名"
                  maxlength="50"
                  required
                />
              </div>
              <div class="form-field">
                <label for="contact">联系方式 <span class="req">*</span></label>
                <input
                  id="contact"
                  v-model="form.contact"
                  type="text"
                  placeholder="手机号 / 邮箱 / 微信号 / QQ号"
                  maxlength="100"
                  required
                />
                <small class="field-hint">仅支持数字、字母和符号</small>
              </div>
              <button type="submit" class="btn btn-primary btn-lg submit-btn" :disabled="submitting">
                {{ submitting ? '提交中...' : (submitted ? '已提交 ✓' : '提交') }}
              </button>

              <div class="direct-contact-divider">
                <span>或</span>
              </div>

              <a :href="`https://t.me/${(sc?.contactTelegram || '@ChatPulse_BD').replace(/^@/, '')}`" target="_blank" class="btn btn-outline btn-lg direct-tg-btn">
                <svg width="18" height="18" viewBox="0 0 48 48" fill="none"><defs><linearGradient id="dtgbtn" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#4080ff"/><stop offset="100%" stop-color="#165dff"/></linearGradient></defs><circle cx="24" cy="24" r="24" fill="url(#dtgbtn)"/><path d="M20 34c-1.2 0-1.1-.5-1.6-1.8l-3.7-12.3c-.4-1.3.5-2 1.6-2.3l26.4-10.2c1.4-.5 2.9 0 2.9 1.9 0 .3-.1.6-.2.9L38.5 27c-.2 1-.9 1.3-1.9 1l-7.6-2.6-3.7 7.6c-.6 1-1.1 1.3-2.3 1.3z" fill="#fff"/></svg>
                直接联系 Telegram 客服
              </a>

              <transition name="fade">
                <div v-if="errorMsg" class="error-msg">⚠️ {{ errorMsg }}</div>
              </transition>
              <transition name="fade">
                <div v-if="submitted" class="success-msg">
                  <span class="success-icon">
                    <svg width="18" height="18" viewBox="0 0 18 18" fill="none"><path d="M4 9l3.5 3.5L14 5.5" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
                  </span>
                  提交成功！我们已收到您的信息，将尽快与您联系。
                </div>
              </transition>
            </form>
          </div>

          <!-- RIGHT: CONTACT INFO -->
          <div class="info-side fade-in-up" style="animation-delay:.1s">
            <h2 class="info-title">直接联系我们</h2>
            <p class="info-sub">以下渠道均可直接触达，欢迎随时沟通</p>

            <div class="info-cards">
              <a
                v-for="item in contactInfo"
                :key="item.label"
                class="card info-card info-card-link"
                :href="item.link"
                target="_blank"
                rel="noopener"
              >
                <span class="info-icon" :style="{ background: item.gradient }" v-html="item.icon"></span>
                <div class="info-meta">
                  <span class="info-label">{{ item.label }}</span>
                  <span class="info-value">{{ item.value }}</span>
                </div>
              </a>
            </div>
          </div>
        </div>
      </div>
    </section>
  </div>
</template>

<script setup lang="ts">
import { reactive, ref, computed } from 'vue'

// 站点配置：Telegram 客服
const { data: scData } = await useFetch('/api/site-config')
const sc = computed(() => scData.value?.data)

useHead(() => ({
  title: '联系我们 - ChatPulse 企业级 IM',
  meta: [
    { name: 'description', content: `联系 ChatPulse Telegram 商务客服 ${sc.value?.contactTelegram || '@ChatPulse_BD'}：提交姓名和联系方式即可，我们主动与您沟通。` },
    { name: 'keywords', content: '联系ChatPulse,Telegram客服,IM咨询,商务合作,私有化部署咨询,ChatPulse' },
  ],
}))

const form = reactive({
  name: '',
  contact: '',
})

const submitting = ref(false)
const submitted = ref(false)
const errorMsg = ref('')

// 只允许数字、字母和符号
const validPattern = /^[a-zA-Z0-9@._\-+()#&\s]+$/

const handleSubmit = async () => {
  errorMsg.value = ''
  if (!form.name.trim()) {
    errorMsg.value = '请输入姓名'
    return
  }
  if (!form.contact.trim()) {
    errorMsg.value = '请输入联系方式'
    return
  }
  if (!validPattern.test(form.contact)) {
    errorMsg.value = '联系方式只允许数字、字母和符号'
    return
  }

  submitting.value = true
  try {
    await $fetch('/api/contact', {
      method: 'POST',
      body: { name: form.name, contact: form.contact, message: '' },
    })
    submitted.value = true
    form.name = ''
    form.contact = ''
    setTimeout(() => { submitted.value = false }, 5000)
  } catch (e: any) {
    errorMsg.value = e?.data?.message || '提交失败，请稍后重试'
  } finally {
    submitting.value = false
  }
}

const contactInfo = computed(() => [{
  label: 'Telegram 商务客服',
  value: sc.value?.contactTelegram || '@ChatPulse_BD',
  gradient: 'var(--c-gradient)',
  icon: `<svg viewBox="0 0 48 48" width="22" height="22"><defs><linearGradient id="tgmini" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#4080ff"/><stop offset="100%" stop-color="#165dff"/></linearGradient></defs><circle cx="24" cy="24" r="24" fill="url(#tgmini)"/><path d="M20 34c-1.2 0-1.1-.5-1.6-1.8l-3.7-12.3c-.4-1.3.5-2 1.6-2.3l26.4-10.2c1.4-.5 2.9 0 2.9 1.9 0 .3-.1.6-.2.9L38.5 27c-.2 1-.9 1.3-1.9 1l-7.6-2.6-3.7 7.6c-.6 1-1.1 1.3-2.3 1.3z" fill="#fff"/></svg>`,
  link: `https://t.me/${(sc.value?.contactTelegram || '@ChatPulse_BD').replace(/^@/, '')}`,
}])
</script>

<style scoped>
/* ============ HERO ============ */
.hero {
  position: relative;
  background: linear-gradient(135deg, #165dff 0%, #4080ff 100%);
  color: #fff;
  padding: 72px 0 80px;
  overflow: hidden;
  text-align: center;
}
.hero-bg-deco { position: absolute; inset: 0; pointer-events: none; overflow: hidden; }
.orb { position: absolute; border-radius: 50%; filter: blur(60px); opacity: .35; }
.orb-1 { width: 320px; height: 320px; background: #6ea8ff; top: -100px; right: -60px; }
.orb-2 { width: 260px; height: 260px; background: #0e42d2; bottom: -100px; left: -80px; opacity: .5; }
.hero-inner { position: relative; z-index: 1; max-width: 720px; }
.hero-badge {
  display: inline-block; padding: 7px 16px; font-size: 14px; font-weight: 600;
  color: #fff; background: rgba(255,255,255,.15);
  border: 1px solid rgba(255,255,255,.25);
  border-radius: 999px; margin-bottom: 20px; backdrop-filter: blur(8px);
}
.hero-title { font-size: 46px; font-weight: 900; line-height: 1.15; letter-spacing: -1px; margin-bottom: 18px; }
.hero-subtitle { font-size: 18px; color: rgba(255,255,255,.9); }

/* ============ GRID ============ */
.contact-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 32px; align-items: start; }

/* FORM */
.form-card { padding: 36px; }
.form-title { font-size: 24px; font-weight: 800; color: var(--c-text-1); }
.form-sub { font-size: 14px; color: var(--c-text-3); margin-top: 6px; margin-bottom: 24px; }
.contact-form { display: flex; flex-direction: column; gap: 18px; }
.form-field { display: flex; flex-direction: column; gap: 6px; }
.form-field label { font-size: 14px; font-weight: 600; color: var(--c-text-2); }
.req { color: var(--c-danger); }
.form-field input {
  width: 100%; padding: 12px 14px; font-size: 14px; font-family: inherit;
  color: var(--c-text-1); background: var(--c-bg-2);
  border: 1px solid var(--c-border); border-radius: var(--radius-md);
  transition: border-color .2s, background .2s;
}
.form-field input::placeholder { color: var(--c-text-4); }
.form-field input:focus { outline: none; border-color: var(--c-primary); background: #fff; box-shadow: 0 0 0 3px var(--c-primary-bg); }
.field-hint { font-size: 12px; color: var(--c-text-4); }
.submit-btn { margin-top: 4px; }
.submit-btn:disabled { opacity: .7; cursor: default; }

.success-msg {
  display: flex; align-items: center; gap: 10px;
  padding: 14px 16px; background: rgba(0,180,42,.08);
  border: 1px solid rgba(0,180,42,.25); border-radius: var(--radius-md);
  color: var(--c-accent); font-size: 14px; font-weight: 600;
}
.success-icon {
  display: inline-flex; align-items: center; justify-content: center;
  width: 24px; height: 24px; border-radius: 50%;
  background: var(--c-accent); color: #fff; flex-shrink: 0;
}
.error-msg {
  padding: 12px 14px; background: rgba(230,72,42,.08);
  border: 1px solid rgba(230,72,42,.25); border-radius: var(--radius-md);
  color: var(--c-danger); font-size: 14px;
}

.direct-contact-divider {
  display: flex;
  align-items: center;
  text-align: center;
  margin: 8px 0;
}

.direct-contact-divider::before,
.direct-contact-divider::after {
  content: '';
  flex: 1;
  height: 1px;
  background: var(--c-border);
}

.direct-contact-divider span {
  padding: 0 16px;
  font-size: 13px;
  color: var(--c-text-3);
}

.direct-tg-btn {
  width: 100%;
  justify-content: center;
  gap: 8px;
}

.fade-enter-active, .fade-leave-active { transition: opacity .3s ease; }
.fade-enter-from, .fade-leave-to { opacity: 0; }

/* INFO SIDE */
.info-title { font-size: 24px; font-weight: 800; color: var(--c-text-1); }
.info-sub { font-size: 14px; color: var(--c-text-3); margin-top: 6px; margin-bottom: 24px; }
.info-cards { display: flex; flex-direction: column; gap: 14px; }
.info-card { display: flex; align-items: center; gap: 14px; padding: 18px 20px; }
.info-card-link { text-decoration: none; transition: transform .2s; }
.info-card-link:hover { transform: translateY(-2px); border-color: var(--c-primary-light); }
.info-icon { display: inline-flex; align-items: center; justify-content: center; width: 44px; height: 44px; border-radius: 12px; flex-shrink: 0; }
.info-meta { display: flex; flex-direction: column; gap: 2px; }
.info-label { font-size: 12px; color: var(--c-text-3); font-weight: 600; }
.info-value { font-size: 15px; font-weight: 700; color: var(--c-text-1); }

/* ============ RESPONSIVE ============ */
@media (max-width: 900px) {
  .contact-grid { grid-template-columns: 1fr; }
  .hero-title { font-size: 38px; }
}
@media (max-width: 600px) {
  .hero { padding: 48px 0 56px; }
  .hero-title { font-size: 30px; }
  .hero-subtitle { font-size: 16px; }
  .form-card { padding: 24px; }
  .submit-btn { width: 100%; justify-content: center; }
}
</style>
