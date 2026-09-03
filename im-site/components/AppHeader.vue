<template>
  <header class="app-header" :class="{ 'is-scrolled': isScrolled }">
    <div class="header-inner container">
      <!-- Logo -->
      <NuxtLink to="/" class="logo" @click="closeMobileMenu">
        <span class="logo-icon" aria-hidden="true">
          <svg width="34" height="34" viewBox="0 0 34 34" fill="none" xmlns="http://www.w3.org/2000/svg">
            <defs>
              <linearGradient id="logoGrad" x1="0" y1="0" x2="34" y2="34" gradientUnits="userSpaceOnUse">
                <stop offset="0" stop-color="#165dff" />
                <stop offset="1" stop-color="#4080ff" />
              </linearGradient>
            </defs>
            <path
              d="M17 3C9.27 3 3 8.6 3 15.5c0 3.78 1.84 7.17 4.77 9.45-.08 1.4-.55 3.04-1.7 4.55-.2.27.02.66.35.6 2.62-.5 4.5-1.62 5.6-2.5 1.55.55 3.23.85 4.98.85 7.73 0 14-5.6 14-12.5S24.73 3 17 3z"
              fill="url(#logoGrad)"
            />
            <circle cx="11.5" cy="15.5" r="1.8" fill="#fff" />
            <circle cx="17" cy="15.5" r="1.8" fill="#fff" />
            <circle cx="22.5" cy="15.5" r="1.8" fill="#fff" />
          </svg>
        </span>
        <span class="logo-text">ChatPulse</span>
      </NuxtLink>

      <!-- Desktop nav -->
      <nav class="nav-desktop" aria-label="Primary navigation">
        <NuxtLink
          v-for="item in navItems"
          :key="item.path"
          :to="item.path"
          class="nav-link"
        >
          {{ item.label }}
        </NuxtLink>
      </nav>

      <!-- CTA (desktop) -->
      <a
        :href="telegramLink"
        target="_blank"
        rel="noopener noreferrer"
        class="btn cta-desktop tg-btn"
      >
        <span class="tg-icon-wrap" aria-hidden="true">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
            <path d="M21.198 2.855a1.5 1.5 0 0 0-1.543-.236L3.44 10.703a1.5 1.5 0 0 0 .038 2.77l4.288 1.339 1.66 5.143a1.5 1.5 0 0 0 2.53.667l2.44-2.356 4.52 3.318a1.5 1.5 0 0 0 2.304-.77l3.24-14.5a1.5 1.5 0 0 0-.862-1.489zM9.58 16.94l-.983-3.128 8.947-5.643c.39-.244.754.086.42.382L9.58 16.94z" fill="currentColor"/>
          </svg>
        </span>
        <span class="tg-label">
          <span class="tg-label-main">联系飞机</span>
          <span class="tg-label-sub">{{ telegramDisplay }}</span>
        </span>
        <span class="tg-badge">BUSINESS</span>
      </a>

      <!-- Hamburger (mobile) -->
      <button
        type="button"
        class="hamburger"
        :class="{ 'is-open': isMobileMenuOpen }"
        :aria-expanded="isMobileMenuOpen"
        aria-label="Toggle navigation menu"
        @click="toggleMobileMenu"
      >
        <span></span>
        <span></span>
        <span></span>
      </button>
    </div>

    <!-- Mobile dropdown panel -->
    <transition name="dropdown">
      <div v-if="isMobileMenuOpen" class="mobile-panel">
        <nav class="mobile-nav" aria-label="Mobile primary navigation">
          <NuxtLink
            v-for="item in navItems"
            :key="item.path"
            :to="item.path"
            class="mobile-nav-link"
            @click="closeMobileMenu"
          >
            {{ item.label }}
          </NuxtLink>
        </nav>
        <a
          :href="telegramLink"
          target="_blank"
          rel="noopener noreferrer"
          class="btn mobile-cta tg-btn tg-btn-mobile"
          @click="closeMobileMenu"
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
            <path d="M21.198 2.855a1.5 1.5 0 0 0-1.543-.236L3.44 10.703a1.5 1.5 0 0 0 .038 2.77l4.288 1.339 1.66 5.143a1.5 1.5 0 0 0 2.53.667l2.44-2.356 4.52 3.318a1.5 1.5 0 0 0 2.304-.77l3.24-14.5a1.5 1.5 0 0 0-.862-1.489zM9.58 16.94l-.983-3.128 8.947-5.643c.39-.244.754.086.42.382L9.58 16.94z" fill="currentColor"/>
          </svg>
          联系飞机商务 · {{ telegramDisplay }}
        </a>
      </div>
    </transition>
  </header>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'

const navItems = [
  { label: '首页', path: '/' },
  { label: '功能', path: '/features' },
  { label: '定价', path: '/pricing' },
  { label: '资讯', path: '/articles' },
  { label: 'Demo体验', path: '/demo' },
  { label: '帮助', path: '/faq' },
]

// 站点配置：Telegram 账号
const { data: sc } = await useFetch('/api/site-config', {
  default: () => ({ contact_telegram: '@ChatPulse_BD' }),
  server: true,
  lazy: false,
  transform: (d: any) => d?.data || d || { contact_telegram: '@ChatPulse_BD' },
})

const telegramUsername = computed(() => {
  const v = String(sc.value?.contact_telegram || sc.value?.contactTelegram || '@ChatPulse_BD')
  // 规范化：去掉 t.me/ 、 https:// 等前缀
  let clean = v.trim()
  clean = clean.replace(/^https?:\/\/(www\.)?t\.me\//, '')
  if (!clean.startsWith('@')) clean = '@' + clean
  return clean
})

const telegramDisplay = computed(() => telegramUsername.value)
const telegramLink = computed(() => {
  const u = telegramUsername.value.replace(/^@/, '')
  return `https://t.me/${encodeURIComponent(u)}`
})

const isMobileMenuOpen = ref(false)
const isScrolled = ref(false)

const handleScroll = () => {
  isScrolled.value = window.scrollY > 4
}

const toggleMobileMenu = () => {
  isMobileMenuOpen.value = !isMobileMenuOpen.value
}

const closeMobileMenu = () => {
  isMobileMenuOpen.value = false
}

onMounted(() => {
  window.addEventListener('scroll', handleScroll, { passive: true })
  handleScroll()
})

onBeforeUnmount(() => {
  window.removeEventListener('scroll', handleScroll)
})
</script>

<style scoped>
.app-header {
  position: sticky;
  top: 0;
  z-index: 1000;
  height: 64px;
  background: #ffffff;
  border-bottom: 1px solid transparent;
  transition: box-shadow .25s ease, border-color .25s ease;
}

.app-header.is-scrolled {
  border-bottom-color: var(--c-border, #e5e6eb);
  box-shadow: 0 4px 12px rgba(0, 0, 0, .06);
}

.header-inner {
  height: 64px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 24px;
}

/* Logo */
.logo {
  display: inline-flex;
  align-items: center;
  gap: 10px;
  text-decoration: none;
  flex-shrink: 0;
}

.logo-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
}

.logo-text {
  font-size: 22px;
  font-weight: 800;
  letter-spacing: -.4px;
  background: var(--c-gradient, linear-gradient(135deg, #165dff 0%, #4080ff 100%));
  -webkit-background-clip: text;
  background-clip: text;
  -webkit-text-fill-color: transparent;
  color: #165dff;
}

/* Desktop nav */
.nav-desktop {
  display: flex;
  align-items: center;
  gap: 4px;
  margin-left: auto;
}

.nav-link {
  position: relative;
  display: inline-flex;
  align-items: center;
  padding: 8px 14px;
  font-size: 15px;
  font-weight: 500;
  color: var(--c-text-2, #4e5969);
  text-decoration: none;
  border-radius: 6px;
  transition: color .2s ease, background .2s ease;
}

.nav-link:hover {
  color: var(--c-primary, #165dff);
  background: var(--c-primary-bg, #e8f3ff);
}

.nav-link.router-link-active {
  color: var(--c-primary, #165dff);
  font-weight: 600;
}

/* CTA desktop */
.cta-desktop {
  margin-left: 8px;
  padding: 10px 22px;
  font-size: 14px;
}

/*  Telegram 商务按钮（更突出、天空蓝渐变 + 脉冲外圈）*/
.tg-btn {
  position: relative;
  display: inline-flex;
  align-items: center;
  gap: 10px;
  padding: 10px 18px 10px 14px;
  border-radius: 999px;
  border: none;
  color: #fff;
  font-weight: 700;
  letter-spacing: .2px;
  text-decoration: none;
  cursor: pointer;
  background: linear-gradient(135deg, #2AABEE 0%, #229ED9 40%, #1682C4 100%);
  box-shadow:
    0 6px 18px rgba(34, 158, 217, .42),
    0 0 0 0 rgba(42, 171, 238, .35);
  transition: transform .25s ease, box-shadow .25s ease, filter .25s ease;
}
.tg-btn::before {
  content: '';
  position: absolute;
  inset: -3px;
  border-radius: 999px;
  padding: 2px;
  background: linear-gradient(135deg, rgba(170, 230, 255, .9), rgba(22, 130, 196, .2));
  -webkit-mask:
    linear-gradient(#000 0 0) content-box,
    linear-gradient(#000 0 0);
  -webkit-mask-composite: xor;
          mask-composite: exclude;
  pointer-events: none;
  opacity: .7;
}
.tg-btn:hover {
  transform: translateY(-2px);
  box-shadow:
    0 12px 28px rgba(34, 158, 217, .55),
    0 0 0 6px rgba(42, 171, 238, .08);
  filter: brightness(1.05);
}
.tg-btn:active {
  transform: translateY(0);
  box-shadow: 0 4px 10px rgba(34, 158, 217, .45);
}

.tg-icon-wrap {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 32px;
  height: 32px;
  border-radius: 50%;
  background: rgba(255, 255, 255, .22);
  backdrop-filter: blur(2px);
  color: #fff;
  box-shadow: inset 0 0 0 1px rgba(255,255,255,.25);
}

.tg-label {
  display: inline-flex;
  flex-direction: column;
  align-items: flex-start;
  line-height: 1.1;
}
.tg-label-main {
  font-size: 14px;
  font-weight: 800;
}
.tg-label-sub {
  font-size: 11px;
  font-weight: 600;
  color: rgba(255, 255, 255, .82);
  margin-top: 2px;
}

.tg-badge {
  display: inline-block;
  margin-left: 4px;
  padding: 3px 8px;
  background: rgba(255,255,255,.18);
  color: #fff;
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 1px;
  border-radius: 6px;
  box-shadow: inset 0 0 0 1px rgba(255,255,255,.28);
}

.tg-btn-mobile {
  padding: 12px 16px;
  justify-content: center;
  width: 100%;
  margin-top: 12px;
  font-size: 15px;
  flex-direction: row;
}

/* Hamburger */
.hamburger {
  display: none;
  flex-direction: column;
  justify-content: center;
  gap: 5px;
  width: 40px;
  height: 40px;
  padding: 0;
  background: transparent;
  border: none;
  cursor: pointer;
  border-radius: 8px;
}

.hamburger span {
  display: block;
  width: 22px;
  height: 2px;
  margin: 0 auto;
  background: var(--c-text-1, #1d2129);
  border-radius: 2px;
  transition: transform .25s ease, opacity .25s ease;
}

.hamburger.is-open span:nth-child(1) {
  transform: translateY(7px) rotate(45deg);
}
.hamburger.is-open span:nth-child(2) {
  opacity: 0;
}
.hamburger.is-open span:nth-child(3) {
  transform: translateY(-7px) rotate(-45deg);
}

/* Mobile panel */
.mobile-panel {
  position: absolute;
  top: 64px;
  left: 0;
  right: 0;
  background: #ffffff;
  border-top: 1px solid var(--c-border, #e5e6eb);
  box-shadow: 0 12px 32px rgba(0, 0, 0, .1);
  padding: 12px 16px 20px;
}

.mobile-nav {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.mobile-nav-link {
  display: block;
  padding: 12px 14px;
  font-size: 16px;
  font-weight: 500;
  color: var(--c-text-2, #4e5969);
  text-decoration: none;
  border-radius: 8px;
  transition: color .2s ease, background .2s ease;
}

.mobile-nav-link:hover,
.mobile-nav-link.router-link-active {
  color: var(--c-primary, #165dff);
  background: var(--c-primary-bg, #e8f3ff);
}

.mobile-cta {
  margin-top: 12px;
  justify-content: center;
  width: 100%;
}

/* Dropdown transition */
.dropdown-enter-active,
.dropdown-leave-active {
  transition: opacity .2s ease, transform .2s ease;
}
.dropdown-enter-from,
.dropdown-leave-to {
  opacity: 0;
  transform: translateY(-8px);
}

/* Responsive */
@media (max-width: 860px) {
  .nav-desktop,
  .cta-desktop {
    display: none;
  }
  .hamburger {
    display: flex;
    margin-left: auto;
  }
}

@media (min-width: 861px) {
  .mobile-panel {
    display: none;
  }
}
</style>
