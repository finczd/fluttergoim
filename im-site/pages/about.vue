<template>
  <div class="about-page">
    <!-- ============ HERO ============ -->
    <section class="hero">
      <div class="hero-bg-deco" aria-hidden="true">
        <span class="orb orb-1"></span>
        <span class="orb orb-2"></span>
      </div>
      <div class="container hero-inner">
        <span class="hero-badge">企业级 IM 解决方案提供商</span>
        <h1 class="hero-title">关于 ChatPulse</h1>
        <p class="hero-subtitle">一支专注于企业级即时通讯系统的技术团队，用代码连接每一次沟通</p>
        <div class="hero-cta">
          <NuxtLink to="/contact" class="btn btn-primary btn-lg">联系我们</NuxtLink>
          <NuxtLink to="/features" class="btn btn-outline btn-lg hero-outline">了解功能</NuxtLink>
        </div>
      </div>
    </section>

    <!-- ============ COMPANY INTRO ============ -->
    <section class="section">
      <div class="container intro-wrap">
        <div class="intro-content fade-in-up">
          <p>
            ChatPulse 是一家专注于企业级即时通讯系统研发的技术团队。我们坚信，沟通是企业运转的基石，而一套稳定、安全、可定制的 IM 系统，是数字化转型中不可或缺的基础设施。自立项以来，我们持续打磨产品，为各行业客户提供成熟的私有化部署方案。
          </p>
          <p>
            我们采用 Go + Vue + Flutter 全栈技术架构，从后端服务、管理后台到移动端，全链路自主可控。源码全量交付，无加密、无后门，客户可自由进行二次开发，真正让 IM 系统成为自己的数字资产。无论是金融、政务、教育还是医疗，我们都能提供贴合业务场景的解决方案。
          </p>
          <p>
            区别于 SaaS 化的通用产品，我们坚持私有化部署与终身授权模式，让数据始终掌握在客户手中。同时配备专业团队提供定制开发、部署培训与持续技术支持，确保系统从落地到长期运行的全生命周期保障。我们不做一次性买卖，而是与客户共同成长的长期伙伴。
          </p>
        </div>
      </div>
    </section>

    <!-- ============ VALUES ============ -->
    <section class="section section-bg-2">
      <div class="container">
        <h2 class="section-title fade-in-up">我们的价值观</h2>
        <p class="section-subtitle fade-in-up">三条原则贯穿我们每一次产品迭代与客户服务</p>
        <div class="grid-3 values-grid">
          <div
            v-for="(v, i) in values"
            :key="v.title"
            class="card value-card fade-in-up"
            :style="{ animationDelay: (i * .1) + 's' }"
          >
            <span class="value-icon" :style="{ background: v.gradient }" v-html="v.icon"></span>
            <h3 class="value-title">{{ v.title }}</h3>
            <p class="value-desc">{{ v.desc }}</p>
          </div>
        </div>
      </div>
    </section>

    <!-- ============ TIMELINE ============ -->
    <section class="section">
      <div class="container">
        <h2 class="section-title fade-in-up">发展历程</h2>
        <p class="section-subtitle fade-in-up">从立项到上线，我们一步一个脚印持续打磨产品</p>

        <div class="timeline">
          <div
            v-for="(item, i) in timeline"
            :key="item.time"
            class="timeline-item fade-in-up"
            :class="{ 'is-right': i % 2 === 1 }"
            :style="{ animationDelay: (i * .1) + 's' }"
          >
            <div class="timeline-dot"></div>
            <div class="timeline-card card">
              <span class="timeline-time">{{ item.time }}</span>
              <h3 class="timeline-title">{{ item.title }}</h3>
              <p class="timeline-desc">{{ item.desc }}</p>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- ============ CTA ============ -->
    <section class="cta-section">
      <div class="container cta-inner">
        <h2 class="cta-title">想了解更多？联系我们</h2>
        <p class="cta-sub">我们的方案顾问随时为您解答产品、定价与定制开发相关问题</p>
        <NuxtLink to="/contact" class="btn btn-lg cta-btn">联系我们 →</NuxtLink>
      </div>
    </section>
  </div>
</template>

<script setup>
useHead({
  title: '关于我们 - ChatPulse 企业级 IM',
  meta: [
    {
      name: 'description',
      content:
        'ChatPulse 是一家专注于企业级即时通讯系统研发的技术团队，Go + Vue + Flutter 全栈架构，源码全交付，私有化部署，终身授权。价值观：技术驱动、客户至上、持续迭代。',
    },
    {
      name: 'keywords',
      content:
        'ChatPulse,关于我们,IM团队,即时通讯系统,私有化部署,企业IM,源码交付,定制开发',
    },
  ],
})

const values = [
  {
    title: '技术驱动',
    desc: '以扎实的技术选型与工程质量为根基，持续引入前沿能力，让 IM 系统稳定、高性能、可扩展。',
    gradient: 'var(--c-gradient)',
    icon: '<svg width="26" height="26" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M9 8l-4 4 4 4M15 8l4 4-4 4M13 6l-2 12" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
  },
  {
    title: '客户至上',
    desc: '从需求理解到落地交付，全程以客户业务场景为核心，提供贴合实际、可落地的解决方案。',
    gradient: 'var(--c-gradient-green)',
    icon: '<svg width="26" height="26" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M12 21s-7-4.5-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 11c0 5.5-7 10-7 10z" fill="#fff"/></svg>',
  },
  {
    title: '持续迭代',
    desc: '产品永远在进化，我们持续打磨细节、补齐能力、修复问题，让每一次更新都更有价值。',
    gradient: 'var(--c-gradient-purple)',
    icon: '<svg width="26" height="26" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M21 12a9 9 0 1 1-2.6-6.4" stroke="#fff" stroke-width="2" stroke-linecap="round"/><path d="M21 4v4h-4" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
  },
]

const timeline = [
  {
    time: '2023 Q1',
    title: '项目立项',
    desc: 'ChatPulse 正式立项，确立 Go + Vue + Flutter 全栈技术路线，开始核心架构设计。',
  },
  {
    time: '2023 Q3',
    title: '核心功能完成',
    desc: '单聊、群聊、消息撤回与已读回执等核心通讯能力研发完成，进入内部测试阶段。',
  },
  {
    time: '2024 Q1',
    title: '移动端上线',
    desc: 'Flutter 移动端正式上线，iOS + Android 双端发布，多端消息同步能力打通。',
  },
  {
    time: '2024 Q3',
    title: '支付系统',
    desc: '钱包、红包、转账与充值提现支付体系上线，资金流转全链路打通。',
  },
  {
    time: '2025 Q1',
    title: '官网上线',
    desc: 'ChatPulse 官方网站正式上线，对外开放授权咨询与定制开发服务，迈向新阶段。',
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
  margin-bottom: 32px;
  font-weight: 400;
}

.hero-cta {
  display: flex;
  gap: 16px;
  justify-content: center;
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

/* ============ INTRO ============ */
.section-bg-2 {
  background: var(--c-bg-2);
}

.intro-wrap {
  max-width: 820px;
}

.intro-content p {
  font-size: 16px;
  line-height: 1.85;
  color: var(--c-text-2);
  margin-bottom: 20px;
}

.intro-content p:last-child {
  margin-bottom: 0;
}

/* ============ VALUES ============ */
.value-card {
  text-align: center;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 14px;
  padding: 32px 24px;
}

.value-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 56px;
  height: 56px;
  border-radius: 14px;
  flex-shrink: 0;
}

.value-title {
  font-size: 20px;
  font-weight: 800;
  color: var(--c-text-1);
}

.value-desc {
  font-size: 14px;
  color: var(--c-text-2);
  line-height: 1.7;
}

/* ============ TIMELINE ============ */
.timeline {
  position: relative;
  max-width: 880px;
  margin: 0 auto;
  padding: 8px 0;
}

.timeline::before {
  content: '';
  position: absolute;
  left: 50%;
  top: 0;
  bottom: 0;
  width: 2px;
  background: linear-gradient(180deg, var(--c-primary) 0%, var(--c-primary-light) 100%);
  transform: translateX(-50%);
}

.timeline-item {
  position: relative;
  width: 50%;
  padding-right: 40px;
  margin-bottom: 32px;
}

.timeline-item.is-right {
  margin-left: 50%;
  padding-right: 0;
  padding-left: 40px;
}

.timeline-dot {
  position: absolute;
  top: 24px;
  right: -8px;
  width: 16px;
  height: 16px;
  border-radius: 50%;
  background: #fff;
  border: 3px solid var(--c-primary);
  box-shadow: 0 0 0 4px var(--c-primary-bg);
  z-index: 1;
}

.timeline-item.is-right .timeline-dot {
  right: auto;
  left: -8px;
}

.timeline-card {
  padding: 20px 24px;
}

.timeline-time {
  display: inline-block;
  padding: 3px 10px;
  font-size: 12px;
  font-weight: 700;
  color: var(--c-primary);
  background: var(--c-primary-bg);
  border-radius: 999px;
  margin-bottom: 10px;
}

.timeline-title {
  font-size: 18px;
  font-weight: 800;
  color: var(--c-text-1);
  margin-bottom: 6px;
}

.timeline-desc {
  font-size: 14px;
  color: var(--c-text-2);
  line-height: 1.65;
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
@media (max-width: 760px) {
  .timeline::before {
    left: 8px;
    transform: none;
  }
  .timeline-item,
  .timeline-item.is-right {
    width: 100%;
    margin-left: 0;
    padding-left: 40px;
    padding-right: 0;
  }
  .timeline-dot,
  .timeline-item.is-right .timeline-dot {
    left: 0;
    right: auto;
  }
  .hero-title { font-size: 36px; }
}

@media (max-width: 600px) {
  .hero { padding: 48px 0 56px; }
  .hero-title { font-size: 30px; }
  .hero-subtitle { font-size: 16px; }
  .hero-cta .btn { flex: 1; justify-content: center; }
  .intro-content p { font-size: 15px; }
  .value-card { padding: 24px 18px; }
  .timeline-card { padding: 16px 18px; }
  .cta-title { font-size: 26px; }
}
</style>
