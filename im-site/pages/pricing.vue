<template>
  <div class="pricing-page">
    <!-- ============ HERO ============ -->
    <section class="hero">
      <div class="hero-bg-deco" aria-hidden="true">
        <span class="orb orb-1"></span>
        <span class="orb orb-2"></span>
      </div>
      <div class="container hero-inner">
        <span class="hero-badge">透明定价 · {{ period || '终身授权' }}</span>
        <h1 class="hero-title">透明定价，按需选择</h1>
        <p class="hero-subtitle">无隐藏费用，一次授权终身使用，源码全交付，按业务规模选择最合适的方案，支持 USDT 支付</p>
      </div>
    </section>

    <!-- ============ PRICING CARDS ============ -->
    <section class="section">
      <div class="container">
        <div class="pricing-grid">
          <!-- 部署版 -->
          <div
            class="card pricing-card fade-in-up"
            :class="{ featured: false }"
            style="animation-delay: 0s"
          >
            <div class="plan-head">
              <span class="period-pill">{{ period || '终身授权' }}</span>
              <h3 class="plan-name">部署版</h3>
              <p class="plan-tag">{{ pricing.standard.note || '不含源码，快速部署' }}</p>
            </div>
            <div class="plan-price">
              <span class="usdt-pill" title="USDT">
                <span class="t-symbol">T</span>
              </span>
              <span class="price-amount">
                {{ formatPrice(pricing.standard.usdt) }}
              </span>
              <span v-if="Number(pricing.standard.usdt) > 0" class="price-unit">USDT</span>
            </div>
            <p class="plan-summary">不含源码，适合快速搭建专属 IM</p>
            <ul class="plan-features">
              <li v-for="feat in standardFeatures" :key="feat.text" :class="{ disabled: !feat.included }">
                <span class="feat-icon" v-html="feat.included ? checkSvg : crossSvg"></span>
                <span class="feat-text">{{ feat.text }}</span>
              </li>
            </ul>
            <NuxtLink
              to="/contact"
              class="btn plan-cta btn-outline"
            >
              立即咨询
            </NuxtLink>
          </div>

          <!-- 开源版 -->
          <div
            class="card pricing-card fade-in-up featured"
            style="animation-delay: .1s"
          >
            <span class="pricing-badge">推荐</span>
            <div class="plan-head">
              <span class="period-pill gold">{{ period || '终身授权' }}</span>
              <h3 class="plan-name">开源版</h3>
              <p class="plan-tag">{{ pricing.professional.note || '含完整源码' }}</p>
            </div>
            <div class="plan-price">
              <span class="usdt-pill gold" title="USDT">
                <span class="t-symbol">T</span>
              </span>
              <span class="price-amount">
                {{ formatPrice(pricing.professional.usdt) }}
              </span>
              <span v-if="Number(pricing.professional.usdt) > 0" class="price-unit">USDT</span>
            </div>
            <p class="plan-summary">完整源码交付，支持二次开发与定制</p>
            <ul class="plan-features">
              <li v-for="feat in professionalFeatures" :key="feat.text" :class="{ disabled: !feat.included }">
                <span class="feat-icon" v-html="feat.included ? checkSvg : crossSvg"></span>
                <span class="feat-text">{{ feat.text }}</span>
              </li>
            </ul>
            <NuxtLink
              to="/contact"
              class="btn plan-cta btn-primary"
            >
              立即购买
            </NuxtLink>
          </div>

          <!-- 定制版 -->
          <div
            class="card pricing-card fade-in-up"
            :class="{ featured: false }"
            style="animation-delay: .2s"
          >
            <div class="plan-head">
              <span class="period-pill">{{ period || '按需报价' }}</span>
              <h3 class="plan-name">定制版</h3>
              <p class="plan-tag">{{ pricing.enterprise.note || '独占授权 + 定制开发' }}</p>
            </div>
            <div class="plan-price">
              <span class="usdt-pill" title="USDT / 定制">
                <span class="t-symbol">T</span>
              </span>
              <span class="price-amount">
                {{ pricing.enterprise.text || '面议' }}
              </span>
            </div>
            <p class="plan-summary">专属定制与保障，适合大型集团与特殊行业</p>
            <ul class="plan-features">
              <li v-for="feat in enterpriseFeatures" :key="feat.text" :class="{ disabled: !feat.included }">
                <span class="feat-icon" v-html="feat.included ? checkSvg : crossSvg"></span>
                <span class="feat-text">{{ feat.text }}</span>
              </li>
            </ul>
            <NuxtLink
              to="/contact"
              class="btn plan-cta btn-outline"
            >
              商务洽谈
            </NuxtLink>
          </div>
        </div>

        <!-- Note box -->
        <div class="note-box">
          <span class="note-icon" v-html="infoSvg"></span>
          <p class="note-text">以上价格不含税，支持 USDT 支付，定制开发费用另计。最终价格以双方签订合同为准。</p>
        </div>
      </div>
    </section>

    <!-- ============ FAQ ============ -->
    <section class="section section-bg-2">
      <div class="container">
        <h2 class="section-title fade-in-up">常见问题</h2>
        <p class="section-subtitle fade-in-up">关于定价与授权，您可能想知道</p>
        <div class="faq-list">
          <div
            v-for="(item, i) in faqs"
            :key="i"
            class="card faq-item fade-in-up"
            :style="{ animationDelay: (i * .08) + 's' }"
          >
            <button
              type="button"
              class="faq-q"
              :aria-expanded="openIndex === i"
              @click="toggle(i)"
            >
              <span class="faq-q-text">{{ item.q }}</span>
              <span class="faq-toggle" :class="{ open: openIndex === i }">+</span>
            </button>
            <transition name="faq">
              <div v-if="openIndex === i" class="faq-a">
                <p>{{ item.a }}</p>
              </div>
            </transition>
          </div>
        </div>
      </div>
    </section>

    <!-- ============ CTA ============ -->
    <section class="cta-section">
      <div class="container cta-inner">
        <h2 class="cta-title">不确定哪个方案适合您？</h2>
        <p class="cta-sub">联系我们的方案顾问，根据业务规模与场景为您推荐最合适的方案</p>
        <NuxtLink to="/contact" class="btn btn-lg cta-btn">联系我们 →</NuxtLink>
      </div>
    </section>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'

const defaultPricing = {
  period: '终身授权',
  standard:   { usdt: 699,  note: '不含源码，快速部署上线' },
  professional:{ usdt: 1399, note: '含完整源码，支持二次开发' },
  enterprise: { text: '面议', note: '独占授权 + 定制开发 + SLA 保障' },
}

const { data: scData } = await useFetch('/api/site-config', {
  server: true,
  lazy: false,
  default: () => ({ code: 0, data: { pricing: { ...defaultPricing } } }),
})

const pricing = computed(() => ({
  ...defaultPricing,
  ...(scData.value?.data?.pricing || {}),
}))
const period = computed(() => pricing.value.period)

function formatPrice(val: number | string) {
  const n = Number(val)
  if (!isFinite(n) || n <= 0) return '面议'
  return new Intl.NumberFormat('en-US').format(n)
}

useHead(() => ({
  title: '定价方案 - ChatPulse 企业级 IM | USDT 支付',
  meta: [
    {
      name: 'description',
      content:
        `ChatPulse 透明定价（USDT 支付）：标准版 ${formatPrice(pricing.value.standard.usdt)} USDT（源码+基础功能+管理后台）、专业版 ${formatPrice(pricing.value.professional.usdt)} USDT（音视频+红包+靓号+AI助手）、企业版 ${pricing.value.enterprise.text}（独占授权+SLA+专属团队）。终身授权，源码交付，支持 USDT。`,
    },
    {
      name: 'keywords',
      content:
        'IM定价 USDT,即时通讯 USDT 价格,IM源码出售 USDT,ChatPulse定价 USDT,标准版专业版企业版,终身授权,私有化部署,USDT 支付',
    },
  ],
}))

const checkSvg =
  '<svg width="16" height="16" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M3.5 8.5l3 3 6-6.5" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>'

const crossSvg =
  '<svg width="16" height="16" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M4 4l8 8M12 4l-8 8" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>'

const infoSvg =
  '<svg width="20" height="20" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg"><circle cx="10" cy="10" r="8.5" stroke="currentColor" stroke-width="1.6"/><path d="M10 9v5" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/><circle cx="10" cy="6.5" r="1" fill="currentColor"/></svg>'

const standardFeatures = [
  { text: '系统部署 + 部署文档', included: true },
  { text: '单聊 / 群聊 / 朋友圈', included: true },
  { text: '管理后台（用户与群组管理）', included: true },
  { text: '音视频通话 / 红包转账', included: true },
  { text: '靓号系统 + AI 助手', included: true },
  { text: '消息审计 / 财务统计', included: true },
  { text: '社区技术支持', included: true },
  { text: '1 个域名授权', included: true },
  { text: '免费更新 3 个月', included: true },
  { text: '源码交付', included: false },
]

const professionalFeatures = [
  { text: '完整源码（后端 + 前端 + 移动端）', included: true },
  { text: '全部部署版功能', included: true },
  { text: '音视频通话（TRTC 底层）', included: true },
  { text: '红包转账与钱包支付', included: true },
  { text: '靓号系统', included: true },
  { text: '智能助手', included: true },
  { text: '支付配置', included: true },
  { text: '优先技术支持', included: true },
  { text: '3 个域名授权', included: true },
  { text: '免费更新 12 个月', included: true },
]

const enterpriseFeatures = [
  { text: '全部开源版功能', included: true },
  { text: '定制开发服务', included: true },
  { text: '独占授权', included: true },
  { text: 'SLA 服务保障', included: true },
  { text: '专属技术团队', included: true },
  { text: '永久免费更新', included: true },
  { text: '部署培训', included: true },
  { text: '不限域名授权', included: true },
  { text: '7×24 专属支持', included: true },
  { text: '安全审计与合规支持', included: true },
]

const openIndex = ref(0)

const toggle = (i: number) => {
  openIndex.value = openIndex.value === i ? -1 : i
}

const faqs = [
  {
    q: '授权是永久的吗？是否需要按年付费？',
    a: '是的，所有版本均为终身授权，一次付费即可永久使用，无需按年订阅。免费更新期结束后，您仍可继续使用现有版本，仅新版本更新需另行购买。支持 USDT 支付。',
  },
  {
    q: '源码是否会加密？是否可以二次开发？',
    a: '源码全量交付，无任何加密与后门，您可自由进行二次开发与定制。我们同时提供完整的技术文档与部署说明，便于团队接手。',
  },
  {
    q: '域名授权是什么意思？可以更换吗？',
    a: '域名授权指授权部署的域名数量。标准版 1 个、专业版 3 个、企业版不限。授权域名可在合同期内申请更换，请联系商务顾问办理。',
  },
  {
    q: '免费更新期结束后还能获得技术支持吗？',
    a: '免费更新期结束后，您可继续使用现有版本。如需继续获取新版本更新与优先技术支持，可选择按年购买更新服务，费用为原价的 20% / 年。',
  },
  {
    q: '是否支持私有化部署？数据是否安全？',
    a: '完全支持私有化部署，所有数据存储在您自己的服务器，自主可控。企业版另提供 SLA 服务保障、安全审计与合规支持，满足金融、政务等行业要求。',
  },
]
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

.orb-1 { width: 320px; height: 320px; background: #6ea8ff; top: -100px; right: -60px; }
.orb-2 { width: 260px; height: 260px; background: #0e42d2; bottom: -100px; left: -80px; opacity: .5; }

.hero-inner {
  position: relative;
  z-index: 1;
  max-width: 720px;
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
  margin-bottom: 20px;
  backdrop-filter: blur(8px);
}

.hero-title {
  font-size: 46px;
  font-weight: 900;
  line-height: 1.15;
  letter-spacing: -1px;
  margin-bottom: 18px;
}

.hero-subtitle {
  font-size: 18px;
  color: rgba(255, 255, 255, .9);
  font-weight: 400;
}

/* ============ PRICING CARDS ============ */
.section-bg-2 {
  background: var(--c-bg-2);
}

.pricing-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 24px;
  align-items: stretch;
}

.pricing-card {
  position: relative;
  display: flex;
  flex-direction: column;
  gap: 16px;
  padding: 32px;
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

/* Period pill on top of each column header */
.period-pill {
  display: inline-block;
  padding: 4px 12px;
  font-size: 12px;
  font-weight: 600;
  color: #165dff;
  background: #e8f3ff;
  border-radius: 999px;
  align-self: flex-start;
  margin-bottom: 4px;
}
.period-pill.gold {
  color: #8a6d00;
  background: linear-gradient(135deg, #fff4c7 0%, #ffe492 100%);
  border: 1px solid #e8cd5a;
}

.plan-head {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.plan-name {
  font-size: 22px;
  font-weight: 800;
  color: var(--c-text-1);
  letter-spacing: -.3px;
}

.plan-tag {
  font-size: 13px;
  color: var(--c-text-3);
}

.plan-price {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 8px 0 4px;
}

/* USDT pill with gold T symbol */
.usdt-pill {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 44px;
  height: 44px;
  border-radius: 10px;
  background: linear-gradient(135deg, #fff4c7 0%, #ffe492 100%);
  border: 1px solid #e8cd5a;
  box-shadow: 0 2px 8px rgba(218, 173, 0, .18);
  flex-shrink: 0;
}
.usdt-pill.gold {
  background: linear-gradient(135deg, #ffe98a 0%, #ffc94a 100%);
  border-color: #d4a200;
  box-shadow: 0 4px 14px rgba(218, 165, 0, .3);
  width: 50px;
  height: 50px;
}
.t-symbol {
  font-size: 24px;
  font-weight: 900;
  color: #7a5d00;
  letter-spacing: -1px;
  font-family: 'Arial Black', Arial, sans-serif;
}
.usdt-pill.gold .t-symbol {
  font-size: 28px;
  color: #5a4400;
}

.price-amount {
  font-size: 38px;
  font-weight: 900;
  color: var(--c-text-1);
  letter-spacing: -1px;
}

.pricing-card.featured .price-amount {
  background: var(--c-gradient);
  -webkit-background-clip: text;
  background-clip: text;
  -webkit-text-fill-color: transparent;
}

.price-unit {
  font-size: 16px;
  font-weight: 700;
  color: #7a5d00;
  background: linear-gradient(135deg, #fff4c7 0%, #ffe492 100%);
  padding: 4px 10px;
  border-radius: 6px;
  margin-left: auto;
  letter-spacing: .3px;
}

.plan-summary {
  font-size: 14px;
  color: var(--c-text-2);
  line-height: 1.6;
  padding-bottom: 16px;
  border-bottom: 1px solid var(--c-border);
}

.plan-features {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 12px;
  flex: 1;
}

.plan-features li {
  display: flex;
  align-items: center;
  gap: 10px;
  font-size: 14px;
  color: var(--c-text-2);
}

.plan-features li.disabled {
  color: var(--c-text-4);
}

.feat-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 20px;
  height: 20px;
  border-radius: 50%;
  flex-shrink: 0;
  color: var(--c-primary);
  background: var(--c-primary-bg);
}

.plan-features li.disabled .feat-icon {
  color: var(--c-text-4);
  background: var(--c-bg-3);
}

.plan-cta {
  justify-content: center;
  margin-top: 4px;
}

/* ============ NOTE BOX ============ */
.note-box {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-top: 32px;
  padding: 16px 20px;
  background: var(--c-primary-bg);
  border: 1px solid #d6e6ff;
  border-radius: var(--radius-md);
  color: var(--c-text-2);
}

.note-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  color: var(--c-primary);
  flex-shrink: 0;
}

.note-text {
  font-size: 14px;
  line-height: 1.6;
}

/* ============ FAQ ============ */
.faq-list {
  max-width: 820px;
  margin: 0 auto;
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.faq-item {
  padding: 0;
  overflow: hidden;
}

.faq-q {
  width: 100%;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  padding: 20px 24px;
  background: transparent;
  border: none;
  cursor: pointer;
  text-align: left;
  font-size: 16px;
  font-weight: 600;
  color: var(--c-text-1);
}

.faq-toggle {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 28px;
  height: 28px;
  border-radius: 50%;
  background: var(--c-primary-bg);
  color: var(--c-primary);
  font-size: 20px;
  font-weight: 600;
  flex-shrink: 0;
  transition: transform .25s ease;
}

.faq-toggle.open {
  transform: rotate(45deg);
  background: var(--c-gradient);
  color: #fff;
}

.faq-a {
  padding: 0 24px 20px;
  color: var(--c-text-2);
  font-size: 14px;
  line-height: 1.7;
}

.faq-enter-active,
.faq-leave-active {
  transition: opacity .25s ease, max-height .25s ease;
}

.faq-enter-from,
.faq-leave-to {
  opacity: 0;
}

/* ============ CTA ============ */
.cta-section {
  background: linear-gradient(135deg, #165dff 0%, #4080ff 100%);
  color: #fff;
  padding: 64px 0;
  text-align: center;
  position: relative;
  overflow: hidden;
}

.cta-inner { position: relative; z-index: 1; }

.cta-title {
  font-size: 34px;
  font-weight: 900;
  letter-spacing: -1px;
  margin-bottom: 14px;
}

.cta-sub {
  font-size: 16px;
  color: rgba(255, 255, 255, .9);
  margin-bottom: 28px;
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
@media (max-width: 900px) {
  .pricing-grid {
    grid-template-columns: 1fr;
    max-width: 480px;
    margin: 0 auto;
  }
  .pricing-card.featured { transform: none; }
  .hero-title { font-size: 38px; }
}

@media (max-width: 600px) {
  .hero { padding: 48px 0 56px; }
  .hero-title { font-size: 30px; }
  .pricing-card { padding: 24px; }
  .faq-q { padding: 16px 18px; font-size: 15px; }
  .faq-a { padding: 0 18px 16px; }
  .cta-title { font-size: 26px; }
  .price-amount { font-size: 32px; }
  .usdt-pill { width: 40px; height: 40px; }
  .t-symbol { font-size: 22px; }
}
</style>
