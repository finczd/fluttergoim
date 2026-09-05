<template>
  <div class="floating-wrap" :class="{ 'floating-wrap--show': visible }">
    <!-- 1. 返回顶部（滚深了才亮） -->
    <button
      v-if="scrolledFar"
      class="fab fab--top"
      @click="scrollToTop"
    >
      <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
        <path d="M12 19V5"/>
        <path d="M5 12l7-7 7 7"/>
      </svg>
      <span class="fab-text">返回顶部</span>
    </button>

    <!-- 2. 压力测试报告 -->
    <NuxtLink to="/stress-test" class="fab fab--bolt">
      <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
        <path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"/>
      </svg>
      <span class="fab-text">压测报告</span>
    </NuxtLink>

    <!-- 3. Demo 下载 -->
    <NuxtLink to="/demo" class="fab fab--download">
      <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
        <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
        <polyline points="7 10 12 15 17 10"/>
        <line x1="12" y1="15" x2="12" y2="3"/>
      </svg>
      <span class="fab-text">Demo 下载</span>
    </NuxtLink>

    <!-- 4. 联系客服（主 CTA，最大号 + 呼吸光环 + 脉冲） -->
    <a
      class="fab fab--chat"
      :href="telegramUrl"
      target="_blank"
      rel="noopener"
    >
      <!-- 呼吸脉冲光环 -->
      <span class="fab-pulse"></span>
      <span class="fab-pulse fab-pulse--d2"></span>
      <!-- 未读小红点 -->
      <span class="fab-dot"></span>
      <!-- 按钮本体 -->
      <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
        <path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z"/>
      </svg>
      <span class="fab-text">联系客服</span>
    </a>
  </div>
</template>

<script setup lang="ts">
const visible = ref(false)
const scrolledFar = ref(false)
const telegramUrl = ref('https://t.me/chatpulse')

onMounted(() => {
  onScroll()
  window.addEventListener('scroll', onScroll, { passive: true })
})
onBeforeUnmount(() => {
  window.removeEventListener('scroll', onScroll)
})

function onScroll() {
  const y = window.scrollY
  visible.value = y > 240
  scrolledFar.value = y > 600
}

function scrollToTop() {
  window.scrollTo({ top: 0, behavior: 'smooth' })
}

if (typeof window !== 'undefined') {
  fetch('/api/site-config')
    .then(r => r.json())
    .then(d => {
      const t = d?.contactTelegram || d?.contact_telegram
      if (t) telegramUrl.value = t.startsWith('http') ? t : `https://t.me/${t.replace(/^@/, '')}`
    })
    .catch(() => {})
}
</script>

<style scoped>
/* 整体位置：靠右但不贴边，距离右边缘 32px（桌面端） */
.floating-wrap {
  position: fixed;
  right: 32px;
  bottom: 40px;
  z-index: 9998;
  display: flex;
  flex-direction: column;
  align-items: stretch;
  gap: 10px;
}

/* ============ 通用 FAB ============ */
.fab {
  position: relative;
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 12px 18px;
  min-width: 140px;
  border-radius: 28px;
  border: 0;
  cursor: pointer;
  text-decoration: none;
  color: #fff;
  font-size: 13px;
  font-weight: 500;
  line-height: 1;
  box-shadow: 0 4px 14px rgba(0,0,0,.14);
  opacity: 0;
  transform: translateX(30px) scale(.92);
  transition:
    opacity .42s cubic-bezier(.22,.61,.36,1),
    transform .42s cubic-bezier(.22,.61,.36,1),
    box-shadow .25s ease,
    filter .25s ease,
    padding .25s ease;
  backdrop-filter: blur(8px);
}
.floating-wrap--show .fab {
  opacity: 1;
  transform: translateX(0) scale(1);
}
.floating-wrap--show .fab:nth-child(1) { transition-delay: .06s; }
.floating-wrap--show .fab:nth-child(2) { transition-delay: .14s; }
.floating-wrap--show .fab:nth-child(3) { transition-delay: .22s; }
.floating-wrap--show .fab:nth-child(4) { transition-delay: .30s; }

.fab:hover {
  transform: translateX(-2px) scale(1.02);
  filter: brightness(1.05);
  box-shadow: 0 8px 24px rgba(0,0,0,.20);
  padding: 12px 22px;   /* hover 时稍微向右延伸 */
}
.fab:active { transform: translateX(0) scale(.97); }

.fab svg { flex-shrink: 0; }
.fab-text { white-space: nowrap; }

/* ============ 按功能分色 ============ */
.fab--top {
  background: linear-gradient(135deg, rgba(107,114,128,.95), rgba(55,65,81,.95));
  box-shadow: 0 4px 14px rgba(55,65,81,.35);
}
.fab--top:hover { box-shadow: 0 8px 22px rgba(55,65,81,.50); }

.fab--bolt {
  background: linear-gradient(135deg, rgba(14,165,233,.95), rgba(37,99,235,.95));
  box-shadow: 0 4px 14px rgba(37,99,235,.35);
}
.fab--bolt:hover { box-shadow: 0 8px 22px rgba(37,99,235,.50); }

.fab--download {
  background: linear-gradient(135deg, rgba(16,185,129,.95), rgba(5,150,105,.95));
  box-shadow: 0 4px 14px rgba(16,185,129,.35);
}
.fab--download:hover { box-shadow: 0 8px 22px rgba(16,185,129,.50); }

/* ============ 联系客服（主 CTA：最宽 + 最大字 + 呼吸光环） ============ */
.fab--chat {
  background: linear-gradient(135deg, #165dff 0%, #7843ff 100%);
  min-width: 160px;
  padding: 14px 22px;
  font-size: 14px;
  font-weight: 600;
  box-shadow:
    0 6px 20px rgba(22,93,255,.50),
    0 2px 8px rgba(120,67,255,.40);
  animation: chat-float 2.8s ease-in-out infinite;
}
.fab--chat:hover {
  box-shadow:
    0 10px 32px rgba(22,93,255,.65),
    0 3px 12px rgba(120,67,255,.50);
  animation-play-state: paused;
  padding: 14px 26px;
}
@keyframes chat-float {
  0%, 100% { transform: translateX(0) translateY(0); }
  50%      { transform: translateX(0) translateY(-3px); }
}
.floating-wrap--show .fab--chat {
  animation: chat-pop-in .5s cubic-bezier(.34,1.56,.64,1) .30s both,
             chat-float 2.8s ease-in-out .78s infinite;
}
@keyframes chat-pop-in {
  from { opacity: 0; transform: translateX(30px) scale(.7); }
  to   { opacity: 1; transform: translateX(0) scale(1); }
}

/* 呼吸脉冲光环（2 层错开） */
.fab-pulse {
  position: absolute;
  inset: 0;
  border-radius: 28px;
  background: linear-gradient(135deg, #165dff, #7843ff);
  opacity: .40;
  z-index: -1;
  animation: chat-pulse 2s cubic-bezier(.4,0,.6,1) infinite;
}
.fab-pulse--d2 { animation-delay: 1s; }
@keyframes chat-pulse {
  0%        { transform: scale(1);   opacity: .50; }
  80%, 100% { transform: scale(1.18); opacity: 0; }
}

/* 未读小红点 */
.fab-dot {
  position: absolute;
  top: 6px;
  right: 8px;
  width: 10px;
  height: 10px;
  border-radius: 50%;
  background: #ff3b30;
  border: 2px solid #fff;
  box-shadow: 0 0 0 0 rgba(255,59,48,.55);
  animation: dot-beat 1.4s ease-in-out infinite;
}
@keyframes dot-beat {
  0%, 100% { box-shadow: 0 0 0 0 rgba(255,59,48,.55); }
  50%      { box-shadow: 0 0 0 6px rgba(255,59,48,0); }
}

/* hover 时图标弹跳 */
.fab--chat:hover svg {
  animation: icon-bounce .4s ease;
}
@keyframes icon-bounce {
  0%, 100% { transform: translateY(0); }
  50%      { transform: translateY(-3px); }
}

/* ============ 响应式 ============ */
@media (max-width: 640px) {
  .floating-wrap { right: 12px; bottom: 16px; gap: 8px; }
  .fab {
    padding: 10px 14px;
    min-width: 112px;
    font-size: 12px;
    gap: 8px;
  }
  .fab--chat { min-width: 128px; padding: 11px 16px; font-size: 13px; }
  .fab:hover { padding: 10px 16px; transform: translateX(-1px); }
  .fab--chat:hover { padding: 11px 18px; }
}
</style>
