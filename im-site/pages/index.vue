<template>
  <div class="home">
    <!-- 滚动进度条 -->
    <div class="scroll-progress" :style="{ width: scrollProgress + '%' }"></div>

    <!-- ============ HERO ============ -->
    <section class="hero">
      <div class="hero-bg-deco" aria-hidden="true">
        <!-- 科技网格 -->
        <div class="tech-grid"></div>
        <!-- 浮动粒子 -->
        <span class="orb orb-1"></span>
        <span class="orb orb-2"></span>
        <span class="orb orb-3"></span>
        <span class="particle p1"></span>
        <span class="particle p2"></span>
        <span class="particle p3"></span>
        <span class="particle p4"></span>
        <span class="particle p5"></span>
        <span class="particle p6"></span>
      </div>
      <div class="container hero-inner">
        <div class="hero-content">
          <span class="hero-badge pulse-badge">{{ sc.value?.siteTitle?.slice(0, 14) || '企业级私有化 IM 解决方案' }}</span>
          <h1 class="hero-title">企业级即时通讯系统</h1>
          <h2 class="hero-slogan">源码出售 · 定制开发 · 私有化部署</h2>
          <p class="hero-subtitle">{{ sc.value?.siteDescription?.slice(0, 40) || '从源码到部署，一站式私有化 IM 解决方案' }}</p>
          <div class="hero-cta">
            <NuxtLink to="/features" class="btn btn-primary btn-lg">查看功能</NuxtLink>
            <NuxtLink to="/demo" class="btn btn-outline btn-lg hero-outline">在线体验</NuxtLink>
          </div>

          <!-- 一行 4 个简洁特性 -->
          <div class="hero-quick-feats">
            <div class="hq-item">
              <svg class="hq-icon" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>
              <span>终身授权 不限域名</span>
            </div>
            <div class="hq-divider"></div>
            <div class="hq-item">
              <svg class="hq-icon" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
              <span>私有化部署数据自主</span>
            </div>
            <div class="hq-divider"></div>
            <div class="hq-item">
              <svg class="hq-icon" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 17l10 5 10-5"/><path d="M2 12l10 5 10-5"/><path d="M12 2L2 7l10 5 10-5L12 2z"/></svg>
              <span>iOS / Android / H5 / Web</span>
            </div>
            <div class="hq-divider"></div>
            <div class="hq-item">
              <svg class="hq-icon" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>
              <span>单聊 群聊 音视频 红包</span>
            </div>
          </div>

          <ul class="trust-badges">
            <li><span class="dot"></span>Go + Vue + Flutter</li>
            <li><span class="dot"></span>开源可定制</li>
            <li><span class="dot"></span>私有化部署</li>
            <li><span class="dot"></span>终身授权</li>
          </ul>
        </div>

        <!-- 右侧 H5 iframe 预览 -->
        <div class="h5-iframe-wrap float" aria-label="APP H5 体验预览">
          <div class="h5-phone-frame">
            <div class="h5-notch"></div>
            <iframe
              v-if="h5Url"
              :src="h5Url"
              class="h5-iframe"
              frameborder="0"
              referrerpolicy="no-referrer-when-downgrade"
              loading="eager"
              title="ChatPulse H5 预览"
            ></iframe>
            <div v-else class="h5-iframe h5-placeholder">
              <svg width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="#86909c" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><rect x="5" y="2" width="14" height="20" rx="3"/><path d="M12 18h.01"/></svg>
              <span>H5 加载中...</span>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- ============ STATS BAR ============ -->
    <section class="stats-bar" ref="statsBarRef">
      <div class="container">
        <div class="stats-grid">
          <div class="stat-item" v-for="(st, i) in statsData" :key="i" :style="{ animationDelay: (i * .1) + 's' }">
            <span class="stat-num" ref="statNumRefs">{{ st.display }}</span>
            <span class="stat-label">{{ st.label }}</span>
          </div>
        </div>
      </div>
    </section>

    <!-- ============ APP SCREENSHOTS (SINGLE-ROW COVER FLOW) ============ -->
    <section class="section screenshots-section">
      <div class="container">
        <h2 class="section-title fade-in-up" style="color: #fff">产品展示</h2>
        <p class="section-subtitle fade-in-up" style="color: #8b949e">多端协同，极致体验</p>

        <div
          class="cf-stage"
          ref="cfStageRef"
          @mouseenter="paused = true"
          @mouseleave="paused = false"
        >
          <!-- 一路滑过去的单排 coverflow：中间突出、两侧渐隐 -->
          <div class="cf-track" :style="cfTrackStyle">
            <div
              v-for="(s, i) in screens"
              :key="'cf-' + i + '-' + (s.id ?? i)"
              class="cf-card"
              :style="cfCardStyle(i)"
              @click="goToSlide(i)"
            >
              <img
                :src="s.url || s.src"
                :alt="s.title || s.alt"
                :data-fallback="s._fallback"
                @error="onImgError"
              />
              <!-- 屏幕扫光 -->
              <div class="cf-shine" />
              <!-- 边框高亮（中间张才显示） -->
              <div class="cf-ring" />
              <div class="cf-caption" v-if="s.title || s.alt">{{ s.title || s.alt }}</div>
            </div>
          </div>

          <!-- 左右按钮：悬浮再显示 -->
          <button class="cf-nav cf-nav-prev" @click="prevSlide" aria-label="上一个">
            <svg width="28" height="28" viewBox="0 0 24 24" fill="none"><path d="M15 6l-6 6 6 6" stroke="rgba(255,255,255,.75)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
          </button>
          <button class="cf-nav cf-nav-next" @click="nextSlide" aria-label="下一个">
            <svg width="28" height="28" viewBox="0 0 24 24" fill="none"><path d="M9 6l6 6-6 6" stroke="rgba(255,255,255,.75)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
          </button>
        </div>

        <!-- 底部进度：当前页 / 总页 -->
        <div class="cf-progress">
          <button
            v-for="(s, i) in screens"
            :key="'dot' + i"
            :class="['cf-dot', { active: currentSlide === i }]"
            @click="goToSlide(i)"
            :aria-label="`跳到第 ${i + 1} 张`"
          />
        </div>
      </div>
    </section>

    <!-- ============ CORE FEATURES ============ -->
    <section class="section features">
      <div class="container">
        <h2 class="section-title fade-in-up">全方位通讯能力</h2>
        <p class="section-subtitle fade-in-up">覆盖即时通讯全场景的成熟功能矩阵，开箱即用，支持深度定制</p>
        <div class="grid-4 features-grid">
          <div
            v-for="(f, i) in features"
            :key="f.title"
            class="card feature-card tilt-card reveal"
            :style="{ animationDelay: (i * .08) + 's' }"
            @mousemove="onTilt($event)"
            @mouseleave="resetTilt($event)"
          >
            <span class="feature-icon" :style="{ background: f.gradient }" v-html="f.icon"></span>
            <h3 class="feature-title">{{ f.title }}</h3>
            <p class="feature-desc">{{ f.desc }}</p>
          </div>
        </div>
      </div>
    </section>

    <!-- ============ ARCHITECTURE ============ -->
    <section class="section section-bg-2 arch">
      <div class="container">
        <h2 class="section-title fade-in-up">技术架构</h2>
        <p class="section-subtitle fade-in-up">现代化全栈技术选型，高性能、高可用、易扩展</p>
        <div class="grid-3 arch-grid">
          <div
            v-for="(a, i) in architecture"
            :key="a.title"
            class="card arch-card fade-in-up"
            :style="{ animationDelay: (i * .1) + 's' }"
          >
            <span class="arch-tag" :style="{ background: a.gradient }">{{ a.tag }}</span>
            <h3 class="arch-title">{{ a.title }}</h3>
            <p class="arch-sub">{{ a.sub }}</p>
            <ul class="tech-list">
              <li v-for="t in a.techs" :key="t">
                <span class="tech-check">✓</span>{{ t }}
              </li>
            </ul>
          </div>
        </div>
      </div>
    </section>

    <!-- ============ WHY CHOOSE US ============ -->
    <section class="section why">
      <div class="container">
        <h2 class="section-title fade-in-up">为什么选择 ChatPulse</h2>
        <p class="section-subtitle fade-in-up">一次投入，长期受益，真正属于您自己的即时通讯系统</p>
        <div class="grid-4 why-grid">
          <div
            v-for="(w, i) in whyUs"
            :key="w.title"
            class="card why-card tilt-card reveal"
            :style="{ animationDelay: (i * .08) + 's' }"
            @mousemove="onTilt($event)"
            @mouseleave="resetTilt($event)"
          >
            <span class="why-icon" v-html="w.icon"></span>
            <h3 class="why-title">{{ w.title }}</h3>
            <p class="why-desc">{{ w.desc }}</p>
          </div>
        </div>
      </div>
    </section>

    <!-- ============ PRICING PREVIEW ============ -->
    <section class="section section-bg-2 pricing">
      <div class="container">
        <h2 class="section-title fade-in-up">透明的定价（USDT）</h2>
        <p class="section-subtitle fade-in-up">无隐藏费用，一次授权终身使用，按需选择最合适的方案，支持 USDT 支付</p>
        <div class="grid-3 pricing-grid">
          <!-- 部署版 -->
          <div
            class="card pricing-card fade-in-up"
            :class="{ featured: false }"
            style="animation-delay: 0s"
          >
            <span class="period-label">{{ pricingCfg.period || '终身授权' }}</span>
            <h3 class="pricing-name">部署版</h3>
            <div class="pricing-price">
              <span class="usdt-mini">T</span>
              <span class="pricing-amount">{{ formatHomePrice(pricingCfg.standard.usdt) }}</span>
              <span v-if="Number(pricingCfg.standard.usdt) > 0" class="pricing-unit">USDT</span>
            </div>
            <p class="pricing-note">{{ pricingCfg.standard.note || '不含源码，快速部署' }}</p>
            <ul class="pricing-list">
              <li v-for="feat in ['系统部署 + 部署文档', '单聊 / 群聊 / 朋友圈', '音视频 / 红包 / 靓号', 'AI 助手 + 数据看板', '3 个月技术支持']" :key="feat">
                <span class="tech-check">✓</span>{{ feat }}
              </li>
            </ul>
            <NuxtLink to="/contact" class="btn pricing-cta btn-outline">立即咨询</NuxtLink>
          </div>
          <!-- 开源版 -->
          <div
            class="card pricing-card fade-in-up featured"
            style="animation-delay: .1s"
          >
            <span class="pricing-badge">推荐</span>
            <span class="period-label gold">{{ pricingCfg.period || '终身授权' }}</span>
            <h3 class="pricing-name">开源版</h3>
            <div class="pricing-price">
              <span class="usdt-mini gold">T</span>
              <span class="pricing-amount">{{ formatHomePrice(pricingCfg.professional.usdt) }}</span>
              <span v-if="Number(pricingCfg.professional.usdt) > 0" class="pricing-unit">USDT</span>
            </div>
            <p class="pricing-note">{{ pricingCfg.professional.note || '含完整源码' }}</p>
            <ul class="pricing-list">
              <li v-for="feat in ['完整前后端 + 移动端源码', '音视频 / 红包 / 朋友圈', '靓号系统 + AI 助手', '1 年技术支持', '集群部署授权']" :key="feat">
                <span class="tech-check">✓</span>{{ feat }}
              </li>
            </ul>
            <NuxtLink to="/contact" class="btn pricing-cta btn-primary">立即咨询</NuxtLink>
          </div>
          <!-- 定制版 -->
          <div
            class="card pricing-card fade-in-up"
            :class="{ featured: false }"
            style="animation-delay: .2s"
          >
            <span class="period-label">定制</span>
            <h3 class="pricing-name">定制版</h3>
            <div class="pricing-price">
              <span class="usdt-mini">T</span>
              <span class="pricing-amount">{{ pricingCfg.enterprise.text || '面议' }}</span>
            </div>
            <p class="pricing-note">{{ pricingCfg.enterprise.note || '尊享服务' }}</p>
            <ul class="pricing-list">
              <li v-for="feat in ['专业版全部功能', '专属定制开发服务', '私有化部署实施', '终身技术支持', 'SLA 服务保障']" :key="feat">
                <span class="tech-check">✓</span>{{ feat }}
              </li>
            </ul>
            <NuxtLink to="/contact" class="btn pricing-cta btn-outline">商务洽谈</NuxtLink>
          </div>
        </div>
      </div>
    </section>

    <!-- ============ ARTICLES / NEWS ============ -->
    <section class="section" style="background: var(--c-bg-2)">
      <div class="container">
        <div class="articles-head">
          <div>
            <h2 class="section-title fade-in-up" style="text-align: left">资讯动态</h2>
            <p class="section-subtitle fade-in-up" style="text-align: left; margin: 0">了解 IM 行业最新趋势与技术实践</p>
          </div>
          <NuxtLink to="/articles" class="btn btn-outline">查看全部 →</NuxtLink>
        </div>

        <div v-if="pending" class="articles-loading">加载中...</div>
        <div v-else-if="articles.length" class="articles-list">
          <NuxtLink
            v-for="a in articles"
            :key="a.id"
            :to="`/articles/${a.slug}`"
            class="article-card"
          >
            <div class="article-meta">
              <span class="article-cat">{{ a.category || '技术分享' }}</span>
              <span class="article-date">{{ formatDate(a.createdAt) }}</span>
            </div>
            <h3 class="article-title">{{ a.title }}</h3>
            <p class="article-summary">{{ a.summary || '点击查看全文...' }}</p>
          </NuxtLink>
        </div>
        <div v-else class="articles-empty">暂无文章，请到后台添加</div>
      </div>
    </section>

    <!-- ============ FINAL CTA ============ -->
    <section class="cta-section">
      <div class="container cta-inner">
        <h2 class="cta-title">立即开始搭建您的专属 IM 系统</h2>
        <p class="cta-sub">源码交付 · 私有化部署 · 终身更新，与我们的技术团队沟通您的需求</p>
        <a :href="telegramUrl" target="_blank" class="btn btn-lg cta-btn">联系我们 →</a>
      </div>
    </section>
  </div>
</template>

<script setup lang="ts">
// 显式引入需要的 Vue API（ref/computed 已由 Nuxt 自动注入，但 watch / nextTick 等还是建议显式引用更稳）
import { computed, ref, watch, onMounted, onBeforeUnmount } from 'vue'

// 站点基础配置：server 端阻塞等待确保有值，避免 SSR 无数据
const defaultConfig = {
  siteTitle: 'ChatPulse - 企业级即时通讯系统',
  siteDescription: 'ChatPulse 企业级即时通讯系统，Go + Vue + Flutter 全栈技术，支持单聊群聊、音视频通话、红包转账、朋友圈、靓号系统。源码出售、私有化部署、定制开发、终身授权。',
  siteKeywords: '即时通讯系统,IM系统源码,企业通讯,聊天APP源码,Go IM,Flutter聊天,私有化部署IM,定制开发,ChatPulse',
  logo: '/favicon.svg',
  contactTelegram: '@ChatPulse_BD',
  h5DemoUrl: 'https://im.x123.wang/h5/',
}

const defaultPricing = {
  period: '终身授权',
  standard:   { usdt: 699,  note: '适合中小企业，源码+基础功能+管理后台' },
  professional:{ usdt: 1399, note: '全功能版：音视频通话+红包转账+靓号+AI助手' },
  enterprise: { text: '面议', note: '独占授权 / 定制开发：SLA 保障、专属技术团队' },
}

const { data: scData } = await useFetch('/api/site-config', {
  server: true,
  lazy: false,
  default: () => ({ code: 0, data: { ...defaultConfig, pricing: { ...defaultPricing } } }),
})
const sc = computed(() => ({ ...defaultConfig, ...(scData.value?.data || {}) }))
const pricingCfg = computed(() => ({
  ...defaultPricing,
  ...(scData.value?.data?.pricing || {}),
}))
const telegramUrl = computed(() => {
  const tg = sc.value?.contactTelegram || '@ChatPulse_BD'
  return `https://t.me/${tg.replace(/^@/, '')}`
})
function formatHomePrice(val: number | string) {
  const n = Number(val)
  if (!isFinite(n) || n <= 0) return '面议'
  return new Intl.NumberFormat('en-US').format(n)
}
// H5 预览 URL（独立 ref 避免骨架消失后闪烁）
const h5Url = ref('')

// —— 合并所有 onMounted：H5 iframe、窗口尺寸监听、轮播定时器 ——
onMounted(() => {
  requestAnimationFrame(() => { h5Url.value = sc.value.h5DemoUrl })
  updateStageWidth()
  if (typeof window !== 'undefined') window.addEventListener('resize', updateStageWidth)
  startTimer()
  // 滚动进度条
  window.addEventListener('scroll', onScroll, { passive: true })
  // 数字 count-up
  initCountUp()
  // 滚动揭示
  initReveal()
})
onBeforeUnmount(() => {
  if (typeof window !== 'undefined') window.removeEventListener('resize', updateStageWidth)
  if (typeof window !== 'undefined') window.removeEventListener('scroll', onScroll)
  stopTimer()
})

// ===== 滚动进度条 =====
const scrollProgress = ref(0)
function onScroll() {
  const el = document.documentElement
  const max = el.scrollHeight - el.clientHeight
  scrollProgress.value = max > 0 ? Math.min(100, (el.scrollTop / max) * 100) : 0
}

// ===== 数字 count-up 动画 =====
const statsBarRef = ref<HTMLElement | null>(null)
const statNumRefs = ref<HTMLElement[]>([])
const statsData = ref([
  { target: 500, suffix: '+', display: '0+', label: '企业客户' },
  { target: 99.9, suffix: '%', display: '0%', label: '可用性' },
  { target: 50, suffix: '万+', display: '0万+', label: '日均消息' },
  { target: 7, suffix: '×24', display: '7×24', label: '技术支持' },
])
let statsAnimated = false
function initCountUp() {
  if (!statsBarRef.value) return
  const io = new IntersectionObserver((entries) => {
    entries.forEach(e => {
      if (e.isIntersecting && !statsAnimated) {
        statsAnimated = true
        statsData.value.forEach((s, i) => {
          const duration = 1400
          const start = performance.now()
          const isFloat = s.target % 1 !== 0
          function tick(now: number) {
            const t = Math.min(1, (now - start) / duration)
            const eased = 1 - Math.pow(1 - t, 3)
            const val = s.target * eased
            s.display = (isFloat ? val.toFixed(1) : Math.floor(val)) + s.suffix
            if (t < 1) requestAnimationFrame(tick)
            else s.display = (isFloat ? s.target.toFixed(1) : s.target) + s.suffix
          }
          requestAnimationFrame(tick)
        })
        io.disconnect()
      }
    })
  }, { threshold: 0.3 })
  io.observe(statsBarRef.value)
}

// ===== 3D 卡片倾斜效果 =====
function onTilt(e: MouseEvent) {
  const el = e.currentTarget as HTMLElement
  const rect = el.getBoundingClientRect()
  const cx = rect.left + rect.width / 2
  const cy = rect.top + rect.height / 2
  const dx = (e.clientX - cx) / (rect.width / 2)
  const dy = (e.clientY - cy) / (rect.height / 2)
  const maxTilt = 6
  el.style.transform = `perspective(800px) rotateX(${(-dy * maxTilt).toFixed(2)}deg) rotateY(${(dx * maxTilt).toFixed(2)}deg) translateY(-4px)`
  el.style.setProperty('--tilt-x', (dx * 50 + 50) + '%')
  el.style.setProperty('--tilt-y', (dy * 50 + 50) + '%')
}
function resetTilt(e: MouseEvent) {
  const el = e.currentTarget as HTMLElement
  el.style.transform = ''
}

// ===== 滚动揭示动画 =====
function initReveal() {
  const els = document.querySelectorAll('.reveal, .fade-in-up')
  if (!els.length) return
  const io = new IntersectionObserver((entries) => {
    entries.forEach(e => {
      if (e.isIntersecting) {
        e.target.classList.add('revealed')
        io.unobserve(e.target)
      }
    })
  }, { threshold: 0.1, rootMargin: '0px 0px -60px 0px' })
  els.forEach(el => io.observe(el))
}

useHead(() => ({
  title: sc.value?.siteTitle || '企业级即时通讯系统 - 源码出售+定制开发',
  meta: [
    { name: 'description', content: sc.value?.siteDescription || 'ChatPulse 企业级即时通讯系统，Go + Vue + Flutter 全栈技术，支持单聊群聊、音视频通话、红包转账、朋友圈、靓号系统。源码出售、私有化部署、定制开发、终身授权。' },
    { name: 'keywords', content: sc.value?.siteKeywords || '即时通讯系统,IM系统源码,企业通讯,聊天APP源码,Go IM,Flutter聊天,私有化部署IM,定制开发,ChatPulse' },
  ],
}))

// ===== Coverflow 单排轮播（中间突出，一路横向滑过去）=====
// 数据库默认会存相对 URL：/uploads/1.jpg ~ /uploads/17.jpg
// - 生产：Nginx + Node 都能按当前域名正确拼（服务端 /api/screenshots 已做 normalize）
// - 本地：如果用户没有把 1~17.jpg 放到 public/uploads，就自动回退到
//        public/screenshots 目录下的本地示例图（下面 LOCAL_FALLBACKS）。
const defaultTitles = [
  '单聊界面', '群聊功能', '通讯录',  '登录注册', '朋友圈',
  '个人中心', '红包功能', '转账功能','音视频通话', '管理后台',
  '消息列表', '会话搜索', '我的钱包','好友详情', '群组设置',
  '靓号中心', 'AI 助手',
]

// 本地开发兜底：public/screenshots/ 下已经存在的 10 张图，按顺序循环映射 17 张
const LOCAL_FALLBACKS = [
  'chat.jpg', 'group-chat.jpg', 'contacts.jpg', 'login.jpg', 'moments.jpg',
  'profile.jpg', 'red-packet.jpg', 'transfer.jpg', 'video-call.jpg', 'admin.jpg',
]
function fallbackSrc(i: number) {
  const idx = (i - 1) % LOCAL_FALLBACKS.length
  return `/screenshots/${LOCAL_FALLBACKS[idx]}`
}

// 17 张默认图（优先走 /uploads/N.jpg，失败再 fallback）
const defaultScreens = Array.from({ length: 17 }, (_, i) => ({
  id: `d${i + 1}`,
  src: `/uploads/${i + 1}.jpg`,
  alt: defaultTitles[i] ?? `产品截图 ${i + 1}`,
  title: defaultTitles[i] ?? `产品截图 ${i + 1}`,
  _fallback: fallbackSrc(i + 1),
}))

// 从 API 加载截图；若后台还没录入就用默认
const { data: shotData } = await useFetch('/api/screenshots')
const screens = computed(() => {
  const apiList = shotData.value?.data
  if (apiList && apiList.length > 0) {
    return apiList.map((s: any, i: number) => ({
      id: s.id,
      src: s.url,
      url: s.url,
      alt: s.title,
      title: s.title,
      // 如果 API 返回的也是 uploads/x.jpg 相对路径，给它一份对应的本地 fallback
      _fallback: (s.rawUrl || s.url || '').match(/\/uploads\/(\d+)\.jpg/i)
        ? fallbackSrc(Number(RegExp.$1) || (i + 1))
        : fallbackSrc(i + 1),
    }))
  }
  return defaultScreens
})

/**
 * 图片加载失败时回退到 public/screenshots 下的本地示例图。
 * 生产上 www.x123.wang/uploads/1.jpg~17.jpg 已存在，永远不会触发；
 * 本地 localhost:3000 上没有这 17 张文件就自动兜底，避免一直红叉。
 */
function onImgError(e: Event) {
  const img = e.target as HTMLImageElement
  const fallback = (img as any).dataset.fallback as string | undefined
  if (!fallback) return
  if (img.src.endsWith(fallback)) return // 已经 fallback，防止死循环
  img.src = fallback
}

// —— 产品轮播状态（声明必须在使用它们的 computed/function 之前）——
const cfStageRef = ref<HTMLElement | null>(null)
const stageWidth = ref(1200)

// 卡宽 & 间距：保留你喜欢的大卡尺寸（PC 230×480 + 间距 36）
const cardW = ref(230)
const cardGap = ref(36)
const cardStep = computed(() => cardW.value + cardGap.value)

// 根据舞台宽度（≈ 容器宽度断点）选卡宽/间距
function updateStageWidth() {
  if (!cfStageRef.value) return
  const w = cfStageRef.value.clientWidth || 1200
  stageWidth.value = w
  if (w <= 480)       { cardW.value = 170; cardGap.value = 22 }
  else if (w <= 768)  { cardW.value = 190; cardGap.value = 28 }
  else if (w <= 1024) { cardW.value = 210; cardGap.value = 32 }
  else                { cardW.value = 230; cardGap.value = 36 }
  cfStageRef.value.style.setProperty('--cf-w',   `${cardW.value}px`)
  cfStageRef.value.style.setProperty('--cf-gap', `${cardGap.value}px`)
}

/**
 * currentSlide 初始化策略：
 *   一进来就定位到中间索引，舞台上立刻呈现「左 1 张 + 中 1 张突出 + 右 1 张」共 3 张，
 *   不会出现「左边全空/只有右边有内容」的感觉。
 *   （不要再强行做 ±2 张环形绕圈塞 5 张，那样左右两侧会被压变形。）
 */
const screensLen = computed(() => Math.max(1, screens.value.length))
const currentSlide = ref(Math.floor(screensLen.value / 2))

// 首次 screens 从 0 条加载到真实数据时，再把 currentSlide 校正为新的中点（避免 fallback 是 17 张，DB 实际 5 张 → 中点对不上）
watch(screensLen, (n, oldN) => {
  if (n !== oldN) {
    const mid = Math.floor(n / 2)
    // 只在首次初始化 / 中点差很大时重置；用户手动跳转过就不覆盖
    if (Math.abs(currentSlide.value - mid) > 2 || oldN === 0) {
      currentSlide.value = mid
    }
  }
})

// —— Track 水平位移：把 currentSlide 这张正好推到舞台正中央 ——
const cfTrackStyle = computed(() => {
  const center = stageWidth.value / 2
  const offsetX = center - (cardW.value / 2) - currentSlide.value * cardStep.value
  return {
    transform: `translate3d(${offsetX}px, 0, 0)`,
    transition: 'transform .7s cubic-bezier(.22,.61,.36,1)',
  }
})

// —— 每张卡片独立的 scale / z-index / 亮度 / 标题透明度 ——
//    回到经典 3 张 Cover Flow 视觉：
//       0 ：中间  1.12  最亮、蓝色高亮光晕、阴影最大（突出）
//      ±1 ：邻 1  0.78  偏暗、在舞台左右两边各一张
//      ±2 ：邻 2  0.60  很暗、贴边缘、作为“边缘过渡”(舞台外基本被裁剪)
function cfCardStyle(i: number) {
  const total = screens.value.length
  let diff = i - currentSlide.value
  if (Math.abs(diff) > total / 2) diff = diff > 0 ? diff - total : diff + total
  const abs = Math.abs(diff)
  const isCenter = abs === 0
  const isAdj1 = abs === 1

  let scale = isCenter ? 1.12 : isAdj1 ? 0.78 : 0.58
  let zIndex = 100 - abs
  let brightness = isCenter ? 1.0 : isAdj1 ? 0.68 : 0.45
  // 只有 ±1 以内 100% 可见；≥ ±2 就快速淡出，让用户看到明显的 3 张
  let opacity = abs <= 1 ? 1 : abs === 2 ? 0.35 : 0.05
  let translateY = isCenter ? -10 : 0

  const deepShadow = '0 26px 72px rgba(22,93,255,.36), 0 12px 32px rgba(0,0,0,.52)'
  const sideShadow = '0 14px 36px rgba(0,0,0,.44)'
  const farShadow  = '0 6px 18px rgba(0,0,0,.34)'

  return {
    width: `${cardW.value}px`,
    marginLeft: i === 0 ? '0px' : `${cardGap.value}px`,
    transform: `translate3d(0, ${translateY}px, 0) scale(${scale})`,
    transformOrigin: 'center center',
    zIndex,
    filter: `brightness(${brightness}) saturate(${isCenter ? 1.05 : 0.88})`,
    opacity,
    boxShadow: isCenter ? deepShadow : isAdj1 ? sideShadow : farShadow,
    borderColor: isCenter ? 'rgba(22, 93, 255, .48)' : 'rgba(255,255,255,.08)',
    transition:
      'transform .7s cubic-bezier(.22,.61,.36,1), opacity .55s ease, filter .55s ease, box-shadow .55s ease, border-color .55s ease',
    ['--cf-caption-opacity' as any]: isCenter ? '1' : '0',
    ['--cf-ring-opacity' as any]: isCenter ? '1' : '0',
    ['--cf-shine-pos' as any]: isCenter ? '120%' : '-30%',
  }
}

function nextSlide() {
  currentSlide.value = (currentSlide.value + 1) % screensLen.value
}
function prevSlide() {
  const len = screensLen.value
  currentSlide.value = (currentSlide.value - 1 + len) % len
}
function goToSlide(i: number) {
  currentSlide.value = i
}

// 自动轮播：5s 一次，慢慢切换
let slideTimer: ReturnType<typeof setInterval> | null = null
const paused = ref(false)
function startTimer() {
  stopTimer()
  slideTimer = setInterval(() => { if (!paused.value) nextSlide() }, 5000)
}
function stopTimer() {
  if (slideTimer) { clearInterval(slideTimer); slideTimer = null }
}
// ↑ onMounted / onBeforeUnmount 已在文件顶部统一注册

// ===== 首页文章 =====
const { data: articleData, pending } = await useFetch('/api/articles', {
  params: { page: 1, pageSize: 6 },
})
const articles = computed(() => articleData.value?.data?.list || [])

function formatDate(s: string) {
  if (!s) return ''
  const d = new Date(s)
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

const features = [
  {
    title: '单聊群聊',
    desc: '支持万人群组、消息已读、@提及、撤回与多端同步，畅快沟通。',
    gradient: 'var(--c-gradient)',
    icon: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M7 4h10a3 3 0 0 1 3 3v6a3 3 0 0 1-3 3H9l-4 3v-3a3 3 0 0 1-1-2V7a3 3 0 0 1 3-3z" fill="#fff"/><circle cx="8.5" cy="10" r="1.1" fill="#165dff"/><circle cx="12" cy="10" r="1.1" fill="#165dff"/><circle cx="15.5" cy="10" r="1.1" fill="#165dff"/></svg>',
  },
  {
    title: '音视频通话',
    desc: '基于腾讯 TRTC，1v1 与多人会议低延迟、高清稳定通话体验。',
    gradient: 'var(--c-gradient-green)',
    icon: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><rect x="2.5" y="5.5" width="13" height="13" rx="3" fill="#fff"/><path d="M16 10l4.5-2.5v9L16 14v-4z" fill="#fff"/><circle cx="9" cy="12" r="2.6" fill="#00b42a"/></svg>',
  },
  {
    title: '红包转账',
    desc: '内置钱包系统，支持红包、转账、余额与流水，安全可靠。',
    gradient: 'var(--c-gradient-orange)',
    icon: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><rect x="3" y="5" width="18" height="14" rx="3" fill="#fff"/><rect x="3" y="9" width="18" height="3" fill="#ff7d00"/><circle cx="12" cy="14.5" r="1.6" fill="#ff7d00"/></svg>',
  },
  {
    title: '朋友圈',
    desc: '图文动态、点赞评论、隐私分组，打造企业内部社交圈子。',
    gradient: 'var(--c-gradient-purple)',
    icon: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><rect x="3" y="4" width="18" height="16" rx="3" fill="#fff"/><circle cx="9" cy="10" r="1.8" fill="#7b61ff"/><path d="M5 17l3.5-4 2.5 3 3.5-5 4 6H5z" fill="#7b61ff"/></svg>',
  },
  {
    title: '靓号系统',
    desc: 'VIP 靓号体系，支持号码交易与竞价，沉淀用户数字资产。',
    gradient: 'var(--c-gradient-orange)',
    icon: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M12 2.5l2.6 5.3 5.9.9-4.3 4.1 1 5.8L12 16l-5.2 2.6 1-5.8-4.3-4.1 5.9-.9L12 2.5z" fill="#fff"/></svg>',
  },
  {
    title: '智能助手',
    desc: 'AI 助手接入大模型，支持问答、摘要、翻译与效率提升。',
    gradient: 'var(--c-gradient-purple)',
    icon: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><rect x="5" y="6" width="14" height="12" rx="3" fill="#fff"/><circle cx="9" cy="11" r="1.2" fill="#7b61ff"/><circle cx="15" cy="11" r="1.2" fill="#7b61ff"/><path d="M9 14h6" stroke="#7b61ff" stroke-width="1.4" stroke-linecap="round"/><path d="M12 3v3M8.5 4.5l1 2M15.5 4.5l-1 2" stroke="#7b61ff" stroke-width="1.2" stroke-linecap="round"/></svg>',
  },
  {
    title: '后台管理',
    desc: 'Vue 管理后台，用户/群组/财务/统计一站可视，权限可控。',
    gradient: 'var(--c-gradient)',
    icon: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><rect x="3" y="3" width="8" height="8" rx="2" fill="#fff"/><rect x="13" y="3" width="8" height="5" rx="2" fill="#fff"/><rect x="13" y="10" width="8" height="11" rx="2" fill="#fff"/><rect x="3" y="13" width="8" height="8" rx="2" fill="#fff"/></svg>',
  },
  {
    title: '文件存储',
    desc: 'MinIO 分布式对象存储，海量文件高可用，MongoDB 存消息。',
    gradient: 'var(--c-gradient-green)',
    icon: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M7 14a4 4 0 0 1 .5-7.97A5 5 0 0 1 17 7a3.5 3.5 0 0 1 .5 6.97H7z" fill="#fff"/><path d="M9 17.5l3 3 3-3M12 14v6.5" stroke="#00b42a" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/></svg>',
  },
]

const architecture = [
  {
    tag: '后端',
    title: 'Go + Gin + GORM',
    sub: '高性能服务端，支撑海量并发',
    gradient: 'var(--c-gradient)',
    techs: ['Go 语言 + Gin 框架', 'GORM 数据访问层', 'MySQL / Redis / MongoDB', 'MinIO 对象存储', 'WebSocket 长连接'],
  },
  {
    tag: '前端',
    title: 'Vue 3 + Arco Design',
    sub: '现代化管理后台界面',
    gradient: 'var(--c-gradient-green)',
    techs: ['Vue 3 Composition API', 'Arco Design 组件库', 'Pinia 状态管理', 'Vite 构建工具', 'ECharts 数据可视化'],
  },
  {
    tag: '移动端',
    title: 'Flutter 跨平台',
    sub: '一套代码，iOS + Android',
    gradient: 'var(--c-gradient-purple)',
    techs: ['Flutter 跨平台框架', 'iOS + Android 双端', '原生性能体验', 'TRTC 音视频 SDK', '本地缓存与离线消息'],
  },
]

const whyUs = [
  {
    title: '源码全部交付',
    desc: '购买即获完整前后端源代码，无加密、无后门，可二次开发。',
    icon: '<svg width="26" height="26" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M9 8l-4 4 4 4M15 8l4 4-4 4" stroke="#165dff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/><path d="M13 6l-2 12" stroke="#165dff" stroke-width="2" stroke-linecap="round"/></svg>',
  },
  {
    title: '私有化部署',
    desc: '完全部署在您自己的服务器，数据自主可控，符合合规要求。',
    icon: '<svg width="26" height="26" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><rect x="3" y="4" width="18" height="6" rx="2" stroke="#165dff" stroke-width="2"/><rect x="3" y="14" width="18" height="6" rx="2" stroke="#165dff" stroke-width="2"/><circle cx="7" cy="7" r="1" fill="#165dff"/><circle cx="7" cy="17" r="1" fill="#165dff"/></svg>',
  },
  {
    title: '定制开发',
    desc: '提供专业团队按需定制功能，贴合业务场景，灵活扩展。',
    icon: '<svg width="26" height="26" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M14.7 6.3l3 3L7 20l-4 1 1-4L14.7 6.3z" stroke="#165dff" stroke-width="2" stroke-linejoin="round"/><path d="M13 8l3 3" stroke="#165dff" stroke-width="2"/></svg>',
  },
  {
    title: '终身免费更新',
    desc: '一次购买终身授权，持续迭代功能与安全补丁，无订阅压力。',
    icon: '<svg width="26" height="26" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M21 12a9 9 0 1 1-2.6-6.4" stroke="#165dff" stroke-width="2" stroke-linecap="round"/><path d="M21 4v4h-4" stroke="#165dff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
  },
]

</script>

<style scoped>
/* ============ 单排 Coverflow（中间突出 + 一路滑过去）============ */
.screenshots-section {
  padding: 80px 0 96px;
  background:
    radial-gradient(1200px 500px at 50% 40%, rgba(22, 93, 255, .18) 0%, transparent 60%),
    radial-gradient(ellipse at center, #1a2233 0%, #0d1117 100%);
  overflow: hidden;
}

/* 舞台：左右各 2 张 + 中 1 张突出 = 5 张首屏全可见
   宽/高按你喜欢的大卡比例还原（230 × 480 手机 1:2.1）*/
.cf-stage {
  position: relative;
  width: 100%;
  height: 560px;
  margin-top: 24px;
  overflow: hidden;
  perspective: 1600px;
  /* 与脚本 updateStageWidth() 默认值保持一致（PC 230+36） */
  --cf-w: 230px;
  --cf-gap: 36px;
}

.cf-track {
  position: absolute;
  top: 0;
  left: 0;
  height: 100%;
  display: flex;
  align-items: center;
  will-change: transform;
}

.cf-card {
  position: relative;
  flex: 0 0 auto;
  width: var(--cf-w);        /* 由脚本响应式断点同步（PC 230，小屏 170~210） */
  height: 480px;
  border-radius: 20px;
  overflow: hidden;
  cursor: pointer;
  background: #0b0f17;
  border: 2px solid rgba(255, 255, 255, .08);
  will-change: transform, opacity, filter, box-shadow, border-color;
  user-select: none;
}
.cf-card img {
  width: 100%;
  height: 100%;
  object-fit: cover;           /* 手机竖长截图不变形 */
  display: block;
  pointer-events: none;
}

/* 屏幕扫光：中间张扫过，制造玻璃质感 */
.cf-shine {
  position: absolute;
  top: 0; bottom: 0;
  left: -30%;
  width: 40%;
  background: linear-gradient(
    118deg,
    transparent 0%,
    rgba(255, 255, 255, .14) 40%,
    rgba(255, 255, 255, .06) 55%,
    transparent 100%
  );
  transform: translateX(var(--cf-shine-pos, -30%));
  transition: transform 1.3s ease;
  pointer-events: none;
  mix-blend-mode: screen;
}

/* 高亮环：中间张才淡入蓝色发光 */
.cf-ring {
  position: absolute;
  inset: 0;
  border-radius: inherit;
  border: 2px solid rgba(120, 171, 255, 0);
  box-shadow:
    inset 0 0 0 2px rgba(120, 171, 255, calc(var(--cf-ring-opacity, 0) * 0.55)),
    0 0 0 1px rgba(120, 171, 255, calc(var(--cf-ring-opacity, 0) * 0.2));
  pointer-events: none;
  transition: all .5s ease;
}

/* 卡片标题：仅中间张显示 */
.cf-caption {
  position: absolute;
  left: 0; right: 0; bottom: 0;
  padding: 14px 16px 16px;
  color: #fff;
  font-size: 14px;
  font-weight: 600;
  letter-spacing: .2px;
  opacity: var(--cf-caption-opacity, 0);
  transform: translateY(calc((1 - var(--cf-caption-opacity, 0)) * 14px));
  transition: opacity .5s ease, transform .5s ease;
  background: linear-gradient(180deg, transparent 0%, rgba(0,0,0,.72) 100%);
  backdrop-filter: blur(2px);
  pointer-events: none;
}

/* 左右导航：默认半透明淡，hover 才亮 */
.cf-nav {
  position: absolute;
  top: 50%;
  transform: translateY(-50%);
  z-index: 20;
  width: 44px;
  height: 44px;
  border-radius: 50%;
  border: 1px solid rgba(255, 255, 255, .12);
  background: rgba(255, 255, 255, .04);
  backdrop-filter: blur(6px);
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all .3s ease;
  opacity: 0;
  padding: 0;
}
.cf-stage:hover .cf-nav { opacity: 1; }
.cf-nav:hover {
  background: rgba(22, 93, 255, .28);
  border-color: rgba(22, 93, 255, .6);
  transform: translateY(-50%) scale(1.06);
}
.cf-nav-prev { left: 12px; }
.cf-nav-next { right: 12px; }

/* 底部进度点：蓝-白渐变风格 */
.cf-progress {
  display: flex;
  gap: 8px;
  justify-content: center;
  margin-top: 28px;
}
.cf-dot {
  width: 8px;
  height: 8px;
  border-radius: 99px;
  border: none;
  background: rgba(255, 255, 255, .18);
  cursor: pointer;
  transition: all .35s cubic-bezier(.22,.61,.36,1);
  padding: 0;
}
.cf-dot:hover { background: rgba(255, 255, 255, .38); }
.cf-dot.active {
  width: 34px;
  background: linear-gradient(90deg, #165dff 0%, #722ed1 100%);
  box-shadow: 0 2px 10px rgba(22, 93, 255, .5);
}

/* ===== 响应式（还原成大卡尺寸）===== */
@media (max-width: 1024px) {
  .cf-stage { height: 500px; }
  .cf-card { height: 420px; }
}
@media (max-width: 768px) {
  .cf-stage { height: 460px; }
  .cf-card {
    height: 380px;
    border-radius: 16px;
  }
  .cf-nav { opacity: .85; width: 38px; height: 38px; }
  .cf-nav-prev { left: 4px; }
  .cf-nav-next { right: 4px; }
}
@media (max-width: 480px) {
  .cf-stage { height: 420px; }
  .cf-card { height: 340px; }
}

/* ============ ARTICLES ============ */
.articles-head {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  margin-bottom: 32px;
}
.articles-list {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
}
.article-card {
  display: block;
  padding: 24px 28px;
  background: #fff;
  border: 1px solid var(--c-border);
  border-radius: 12px;
  transition: box-shadow .3s, transform .3s, border-color .3s;
  text-decoration: none;
}
.article-card:hover {
  box-shadow: 0 8px 24px rgba(0,0,0,.08);
  transform: translateY(-3px);
  border-color: var(--c-primary-light);
}
.article-meta {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 8px;
}
.article-cat {
  display: inline-block;
  padding: 2px 10px;
  background: var(--c-primary-bg);
  color: var(--c-primary);
  font-size: 12px;
  font-weight: 500;
  border-radius: 4px;
}
.article-date {
  font-size: 12px;
  color: var(--c-text-3);
}
.article-title {
  font-size: 16px;
  font-weight: 600;
  color: var(--c-text-1);
  margin-bottom: 6px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.article-summary {
  font-size: 14px;
  color: var(--c-text-3);
  line-height: 1.6;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
.articles-loading, .articles-empty {
  text-align: center;
  color: var(--c-text-3);
  padding: 40px 0;
  font-size: 14px;
}
@media (max-width: 768px) {
  .articles-list { grid-template-columns: 1fr; }
  .articles-head { flex-direction: column; gap: 12px; align-items: flex-start; }
}

/* ============ HERO ============ */
.hero {
  position: relative;
  background: linear-gradient(135deg, #165dff 0%, #4080ff 100%);
  color: #fff;
  padding: 96px 0 120px;
  overflow: hidden;
}

.hero-bg-deco {
  position: absolute;
  inset: 0;
  pointer-events: none;
  overflow: hidden;
}

.orb {
  position: absolute;
  border-radius: 50%;
  filter: blur(60px);
  opacity: .35;
}

.orb-1 { width: 360px; height: 360px; background: #6ea8ff; top: -120px; right: -60px; }
.orb-2 { width: 280px; height: 280px; background: #0e42d2; bottom: -100px; left: -80px; opacity: .5; }
.orb-3 { width: 200px; height: 200px; background: #b3d1ff; top: 40%; left: 45%; opacity: .2; }

.hero-inner {
  position: relative;
  z-index: 1;
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 48px;
  align-items: center;
}

.hero-badge {
  display: inline-block;
  padding: 7px 16px;
  font-size: 14px;
  font-weight: 600;
  color: #fff;
  background: rgba(255, 255, 255, .15);
  border: 1px solid rgba(255, 255, 255, .25);
  border-radius: 999px;
  margin-bottom: 24px;
  backdrop-filter: blur(8px);
}

.hero-title {
  font-size: 52px;
  font-weight: 900;
  line-height: 1.1;
  letter-spacing: -1px;
  margin-bottom: 10px;
}

.hero-slogan {
  font-size: 22px;
  font-weight: 700;
  letter-spacing: .5px;
  margin: 0 0 16px;
  display: inline-block;
  background: linear-gradient(90deg, #ffe68a 0%, #ffd28a 55%, #fff1c4 100%);
  -webkit-background-clip: text;
  background-clip: text;
  -webkit-text-fill-color: transparent;
}

.hero-subtitle {
  font-size: 17px;
  color: rgba(255, 255, 255, .9);
  margin-bottom: 28px;
  font-weight: 400;
}

.hero-cta {
  display: flex;
  gap: 16px;
  margin-bottom: 22px;
  flex-wrap: wrap;
}

.hero-outline {
  color: #fff;
  border: 2px solid rgba(255, 255, 255, .7);
  background: rgba(255, 255, 255, .08);
}

.hero-outline:hover {
  background: #fff;
  color: var(--c-primary);
  border-color: #fff;
}

/* 一行 4 个特性条（inline，非网格） */
.hero-quick-feats {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 16px 20px;
  padding: 16px 20px;
  background: rgba(255, 255, 255, .08);
  border: 1px solid rgba(255, 255, 255, .15);
  border-radius: 14px;
  backdrop-filter: blur(6px);
  margin-bottom: 20px;
}
.hq-item {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  flex: 1 1 0;
  min-width: 0;
}
.hq-icon { flex-shrink: 0; color: #6effa8; }
.hq-item span {
  font-size: 13px;
  font-weight: 600;
  color: rgba(255, 255, 255, .95);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.hq-divider {
  width: 1px;
  height: 18px;
  background: rgba(255, 255, 255, .2);
  flex-shrink: 0;
}
@media (max-width: 860px) {
  .hq-divider:nth-of-type(2) { display: none; }
  .hq-item { flex: 0 0 calc(50% - 12px); }
}

.trust-badges {
  list-style: none;
  display: flex;
  flex-wrap: wrap;
  gap: 24px;
}

.trust-badges li {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  font-size: 14px;
  color: rgba(255, 255, 255, .92);
  font-weight: 500;
}

.trust-badges .dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: #6effa8;
  box-shadow: 0 0 8px rgba(110, 255, 168, .8);
}

/* H5 iframe 预览
 * 关键点：iframe 本身是 390×694 真实手机 H5 视口（iPhone 14 标准），
 * H5 页面 meta viewport 按 390 宽正常渲染（不会被放大），
 * 然后外层 .h5-phone-frame 用 transform:scale(.82) 做视觉缩小，
 * 外壳尺寸仍旧保持 280×560 的"手机模型"外观大小。
 */
.h5-iframe-wrap {
  width: 100%;
  max-width: 340px; /* 外壳缩放后占位约 320px，给缩放后留空间 */
  margin-left: auto;
  display: flex;
  align-items: center;
  justify-content: center;
  /* 抵消 transform 缩放导致的容器空白 */
  transform-origin: right center;
  padding: 30px 0;
}
.h5-phone-frame {
  position: relative;
  width: 390px;    /* 真实手机 H5 视口宽度 */
  height: 694px;   /* 真实手机 H5 视口高度 */
  transform: scale(.82); /* 视觉缩小到原先 280×560 大小 */
  transform-origin: center center;
  border-radius: 46px;
  background: #000;
  padding: 12px;
  box-shadow: 0 30px 80px rgba(0,0,0,.4), 0 0 0 2px rgba(255,255,255,.06);
  overflow: hidden;
}
.h5-phone-frame::before {
  content: '';
  position: absolute;
  inset: -2px;
  border-radius: 48px;
  background: linear-gradient(135deg, #4080ff 0%, rgba(64,128,255,.15) 40%, transparent 60%);
  padding: 2px;
  -webkit-mask: linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0);
  -webkit-mask-composite: xor;
  mask-composite: exclude;
  pointer-events: none;
}
.h5-notch {
  position: absolute;
  top: 16px;
  left: 50%;
  transform: translateX(-50%);
  width: 120px;
  height: 30px;
  background: #000;
  border-radius: 18px;
  z-index: 10;
}
.h5-iframe {
  width: 100%;
  height: 100%;
  border-radius: 34px;
  background: #fff;
  border: none;
  display: block;
}
.h5-iframe.h5-placeholder {
  background: linear-gradient(180deg, #f7f8fa, #eef0f3);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 10px;
  color: #86909c;
  font-size: 13px;
}

/* Demo Modal */
.demo-modal-mask {
  position: fixed;
  inset: 0;
  background: rgba(13, 17, 23, .7);
  backdrop-filter: blur(6px);
  z-index: 9999;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 24px;
}
.demo-modal {
  position: relative;
  width: 100%;
  max-width: 480px;
  background: #fff;
  border-radius: 16px;
  padding: 40px 32px 28px;
  box-shadow: 0 20px 60px rgba(0,0,0,.3);
  text-align: center;
}
.demo-close {
  position: absolute;
  top: 14px;
  right: 14px;
  width: 32px;
  height: 32px;
  border-radius: 8px;
  border: none;
  background: #f2f3f5;
  color: #86909c;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all .2s;
  padding: 0;
}
.demo-close:hover { background: #e5e6eb; color: #1d2129; }
.demo-badge {
  display: inline-block;
  padding: 5px 14px;
  background: linear-gradient(135deg, #e8f3ff, #dbeafe);
  color: #165dff;
  font-size: 12px;
  font-weight: 600;
  border-radius: 999px;
  margin-bottom: 16px;
}
.demo-title {
  font-size: 26px;
  font-weight: 800;
  color: #1d2129;
  margin-bottom: 12px;
  letter-spacing: -.4px;
}
.demo-desc {
  font-size: 14px;
  color: #4e5969;
  line-height: 1.7;
  margin-bottom: 20px;
}
.demo-telegram-card {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 16px 18px;
  background: linear-gradient(135deg, #f5f8ff, #eef4ff);
  border: 1px solid #dbeafe;
  border-radius: 12px;
  margin-bottom: 12px;
  text-align: left;
}
.tg-icon {
  width: 48px;
  height: 48px;
  border-radius: 50%;
  flex-shrink: 0;
  overflow: hidden;
  display: flex;
  align-items: center;
  justify-content: center;
}
.tg-label {
  font-size: 12px;
  color: #86909c;
  font-weight: 500;
}
.tg-user {
  font-size: 17px;
  font-weight: 700;
  color: #1d2129;
  letter-spacing: .3px;
}
.demo-telegram-card > a {
  margin-left: auto;
}
.demo-hint {
  font-size: 12px;
  color: #86909c;
  margin-bottom: 20px;
}
.demo-actions {
  display: flex;
  gap: 10px;
  justify-content: center;
}
.modal-fade-enter-active,
.modal-fade-leave-active {
  transition: opacity .25s ease;
}
.modal-fade-enter-from,
.modal-fade-leave-to {
  opacity: 0;
}

/* ============ 科技风动画增强 ============ */

/* 滚动进度条 */
.scroll-progress {
  position: fixed;
  top: 0; left: 0;
  height: 3px;
  background: linear-gradient(90deg, #165dff, #4080ff, #7b61ff);
  z-index: 9999;
  transition: width .1s linear;
  box-shadow: 0 0 8px rgba(22, 93, 255, .6);
}

/* 科技网格背景 */
.tech-grid {
  position: absolute;
  inset: 0;
  background-image:
    linear-gradient(rgba(255,255,255,.04) 1px, transparent 1px),
    linear-gradient(90deg, rgba(255,255,255,.04) 1px, transparent 1px);
  background-size: 48px 48px;
  mask-image: radial-gradient(ellipse 80% 70% at 50% 40%, #000 0%, transparent 70%);
  -webkit-mask-image: radial-gradient(ellipse 80% 70% at 50% 40%, #000 0%, transparent 70%);
  animation: grid-pan 20s linear infinite;
}
@keyframes grid-pan {
  0% { background-position: 0 0, 0 0; }
  100% { background-position: 48px 48px, 48px 48px; }
}

/* 浮动粒子 */
.particle {
  position: absolute;
  border-radius: 50%;
  pointer-events: none;
}
.particle::after {
  content: '';
  position: absolute;
  inset: -4px;
  border-radius: 50%;
  background: inherit;
  filter: blur(8px);
  opacity: .6;
}
.p1 { width: 6px; height: 6px; background: #6ea8ff; top: 15%; left: 8%; animation: float-p 8s ease-in-out infinite; }
.p2 { width: 4px; height: 4px; background: #b3d1ff; top: 60%; left: 12%; animation: float-p 10s ease-in-out infinite reverse; }
.p3 { width: 8px; height: 8px; background: #6ea8ff; top: 25%; left: 85%; animation: float-p 7s ease-in-out infinite; }
.p4 { width: 5px; height: 5px; background: #b3d1ff; top: 70%; left: 90%; animation: float-p 9s ease-in-out infinite reverse; }
.p5 { width: 3px; height: 3px; background: #fff; top: 40%; left: 50%; animation: float-p 6s ease-in-out infinite; }
.p6 { width: 5px; height: 5px; background: #6ea8ff; top: 80%; left: 45%; animation: float-p 11s ease-in-out infinite reverse; }
@keyframes float-p {
  0%, 100% { transform: translate(0, 0); opacity: .8; }
  25% { transform: translate(20px, -30px); opacity: 1; }
  50% { transform: translate(-15px, -15px); opacity: .6; }
  75% { transform: translate(10px, 25px); opacity: .9; }
}

/* Badge 脉冲发光 */
.pulse-badge {
  position: relative;
  overflow: hidden;
}
.pulse-badge::before {
  content: '';
  position: absolute;
  inset: 0;
  border-radius: inherit;
  background: linear-gradient(90deg, transparent, rgba(255,255,255,.3), transparent);
  transform: translateX(-100%);
  animation: badge-sweep 3s ease-in-out infinite;
}
@keyframes badge-sweep {
  0%, 100% { transform: translateX(-100%); }
  50% { transform: translateX(100%); }
}

/* 3D 倾斜卡片 + 填充效果 */
.tilt-card {
  position: relative;
  overflow: hidden;
  transition: transform .2s ease, box-shadow .3s ease, border-color .4s ease;
  transform-style: preserve-3d;
  --tilt-x: 50%;
  --tilt-y: 50%;
}
/* 底部缓慢上升的蓝紫渐变填充 */
.tilt-card::before {
  content: '';
  position: absolute;
  inset: 0;
  border-radius: inherit;
  background: linear-gradient(135deg, rgba(22, 93, 255, 0.07) 0%, rgba(64, 128, 255, 0.05) 40%, rgba(123, 97, 255, 0.04) 100%);
  transform: translateY(101%);
  transition: transform .55s cubic-bezier(0.22, 0.61, 0.36, 1);
  z-index: 0;
  pointer-events: none;
}
.tilt-card:hover::before { transform: translateY(0); }
/* 鼠标跟随光晕 */
.tilt-card::after {
  content: '';
  position: absolute;
  inset: 0;
  border-radius: inherit;
  background: radial-gradient(
    circle 200px at var(--tilt-x) var(--tilt-y),
    rgba(22, 93, 255, .12),
    transparent 70%
  );
  opacity: 0;
  transition: opacity .3s ease;
  pointer-events: none;
  z-index: 1;
}
.tilt-card:hover::after { opacity: 1; }
/* 卡片内容保持在填充层之上 */
.tilt-card > * { position: relative; z-index: 2; }
.tilt-card:hover {
  box-shadow: 0 12px 36px rgba(22, 93, 255, .15), 0 0 0 1px rgba(22, 93, 255, .12);
  border-color: rgba(22, 93, 255, .15);
}

/* 滚动揭示 */
.reveal, .fade-in-up {
  opacity: 0;
  transform: translateY(30px);
  transition: opacity .6s ease, transform .6s ease;
}
.reveal.revealed, .fade-in-up.revealed {
  opacity: 1;
  transform: translateY(0);
}
/* 保留原有 animation 的元素（如 stat-item）不会被 IntersectionObserver 覆盖 */
.stat-item {
  opacity: 0;
  transform: translateY(20px);
  transition: opacity .5s ease, transform .5s ease;
}
.stat-item.revealed {
  opacity: 1;
  transform: translateY(0);
}

/* 数字发光 */
.stat-num {
  text-shadow: 0 0 20px rgba(22, 93, 255, .15);
}

/* 手机框浮动增强 */
.float {
  animation: gentle-float 6s ease-in-out infinite;
}
@keyframes gentle-float {
  0%, 100% { transform: translateY(0); }
  50% { transform: translateY(-12px); }
}
.modal-fade-enter-active .demo-modal,
.modal-fade-leave-active .demo-modal {
  transition: transform .3s cubic-bezier(.25,.46,.45,.94), opacity .25s ease;
}
.modal-fade-enter-from .demo-modal,
.modal-fade-leave-to .demo-modal {
  opacity: 0;
  transform: translateY(20px) scale(.96);
}

/* ============ STATS BAR ============ */
.stats-bar {
  background: #fff;
  border-bottom: 1px solid var(--c-border);
  padding: 36px 0;
}

.stats-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 24px;
  text-align: center;
}

.stat-item {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.stat-num {
  font-size: 38px;
  font-weight: 900;
  background: var(--c-gradient);
  -webkit-background-clip: text;
  background-clip: text;
  -webkit-text-fill-color: transparent;
  letter-spacing: -1px;
}

.stat-label {
  font-size: 15px;
  color: var(--c-text-3);
}

/* ============ FEATURES ============ */
.section-bg-2 {
  background: var(--c-bg-2);
}

.feature-card {
  text-align: left;
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.feature-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 48px;
  height: 48px;
  border-radius: 12px;
  flex-shrink: 0;
}

.feature-title {
  font-size: 18px;
  font-weight: 700;
  color: var(--c-text-1);
}

.feature-desc {
  font-size: 14px;
  color: var(--c-text-2);
  line-height: 1.65;
}

/* ============ ARCHITECTURE ============ */
.arch-grid { gap: 28px; }

.arch-card {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.arch-tag {
  display: inline-flex;
  align-self: flex-start;
  padding: 5px 14px;
  font-size: 13px;
  font-weight: 600;
  color: #fff;
  border-radius: 999px;
}

.arch-title {
  font-size: 22px;
  font-weight: 800;
  color: var(--c-text-1);
  margin-top: 4px;
}

.arch-sub {
  font-size: 14px;
  color: var(--c-text-3);
  margin-bottom: 8px;
}

.tech-list {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.tech-list li {
  display: flex;
  align-items: center;
  gap: 10px;
  font-size: 14px;
  color: var(--c-text-2);
}

.tech-check {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 18px;
  height: 18px;
  border-radius: 50%;
  background: var(--c-primary-bg);
  color: var(--c-primary);
  font-size: 11px;
  font-weight: 800;
  flex-shrink: 0;
}

/* ============ WHY CHOOSE US ============ */
.why-card {
  text-align: center;
  align-items: center;
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.why-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 56px;
  height: 56px;
  border-radius: 14px;
  background: var(--c-primary-bg);
}

.why-title {
  font-size: 18px;
  font-weight: 700;
  color: var(--c-text-1);
}

.why-desc {
  font-size: 14px;
  color: var(--c-text-2);
  line-height: 1.65;
}

/* ============ PRICING ============ */
.pricing-grid { gap: 28px; }

.pricing-card {
  position: relative;
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.pricing-card.featured {
  border: 2px solid transparent;
  background:
    linear-gradient(#fff, #fff) padding-box,
    var(--c-gradient) border-box;
  box-shadow: 0 12px 36px rgba(22, 93, 255, .18);
  transform: scale(1.02);
}

.pricing-badge {
  position: absolute;
  top: -13px;
  left: 50%;
  transform: translateX(-50%);
  padding: 5px 18px;
  font-size: 13px;
  font-weight: 700;
  color: #fff;
  background: var(--c-gradient);
  border-radius: 999px;
  white-space: nowrap;
  box-shadow: 0 4px 12px rgba(22, 93, 255, .35);
}

.period-label {
  display: inline-block;
  padding: 3px 10px;
  font-size: 12px;
  font-weight: 600;
  color: #165dff;
  background: #e8f3ff;
  border-radius: 999px;
  align-self: flex-start;
}
.period-label.gold {
  color: #8a6d00;
  background: linear-gradient(135deg, #fff4c7 0%, #ffe492 100%);
  border: 1px solid #e8cd5a;
}

.pricing-name {
  font-size: 20px;
  font-weight: 800;
  color: var(--c-text-1);
}

.pricing-price {
  display: flex;
  align-items: center;
  gap: 8px;
  padding-bottom: 14px;
  border-bottom: 1px solid var(--c-border);
}

.usdt-mini {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 30px;
  height: 30px;
  border-radius: 8px;
  background: linear-gradient(135deg, #fff4c7 0%, #ffe492 100%);
  border: 1px solid #e8cd5a;
  color: #7a5d00;
  font-weight: 900;
  font-size: 16px;
  font-family: 'Arial Black', Arial, sans-serif;
  flex-shrink: 0;
}
.usdt-mini.gold {
  background: linear-gradient(135deg, #ffe98a 0%, #ffc94a 100%);
  border-color: #d4a200;
  width: 34px;
  height: 34px;
  font-size: 18px;
  color: #5a4400;
  box-shadow: 0 2px 8px rgba(218, 165, 0, .25);
}

.pricing-amount {
  font-size: 36px;
  font-weight: 900;
  color: var(--c-text-1);
  letter-spacing: -1px;
}

.pricing-card.featured .pricing-amount {
  background: var(--c-gradient);
  -webkit-background-clip: text;
  background-clip: text;
  -webkit-text-fill-color: transparent;
}

.pricing-unit {
  font-size: 15px;
  font-weight: 700;
  color: #7a5d00;
  background: linear-gradient(135deg, #fff4c7 0%, #ffe492 100%);
  padding: 3px 8px;
  border-radius: 6px;
  margin-left: auto;
}

.pricing-note {
  font-size: 13px;
  color: var(--c-text-3);
  margin: 0;
  padding-bottom: 10px;
  border-bottom: 1px dashed var(--c-border);
}

.pricing-list {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 12px;
  flex: 1;
}

.pricing-list li {
  display: flex;
  align-items: center;
  gap: 10px;
  font-size: 14px;
  color: var(--c-text-2);
}

.pricing-cta {
  justify-content: center;
  margin-top: 4px;
}

/* ============ FINAL CTA ============ */
.cta-section {
  background: linear-gradient(135deg, #165dff 0%, #4080ff 100%);
  color: #fff;
  padding: 72px 0;
  text-align: center;
  position: relative;
  overflow: hidden;
}

.cta-inner { position: relative; z-index: 1; }

.cta-title {
  font-size: 38px;
  font-weight: 900;
  letter-spacing: -1px;
  margin-bottom: 14px;
}

.cta-sub {
  font-size: 17px;
  color: rgba(255, 255, 255, .9);
  margin-bottom: 32px;
}

.cta-btn {
  background: #fff;
  color: var(--c-primary);
  box-shadow: 0 8px 24px rgba(0, 0, 0, .2);
}

.cta-btn:hover {
  transform: translateY(-2px);
  background: #fff;
  color: var(--c-primary);
  box-shadow: 0 12px 32px rgba(0, 0, 0, .28);
}

/* ============ RESPONSIVE ============ */
@media (max-width: 960px) {
  .hero-inner {
    grid-template-columns: 1fr;
    gap: 56px;
  }
  .hero-title { font-size: 42px; }
  .dashboard-mock, .h5-iframe-wrap { max-width: 100%; }
  .h5-phone-frame { transform: scale(.68); }
}

@media (max-width: 600px) {
  .hero { padding: 56px 0 72px; }
  .hero-title { font-size: 34px; }
  .hero-subtitle { font-size: 17px; }
  .hero-cta .btn { flex: 1; justify-content: center; }
  .trust-badges { gap: 14px; }
  .stats-grid { grid-template-columns: repeat(2, 1fr); gap: 32px; }
  .stat-num { font-size: 30px; }
  .cta-title { font-size: 28px; }
  .cta-sub { font-size: 15px; }
  .pricing-card.featured { transform: none; }
}
</style>
