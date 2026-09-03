<template>
  <div class="docs-page">
    <!-- ============ HERO ============ -->
    <section class="hero">
      <div class="hero-bg-deco" aria-hidden="true">
        <span class="orb orb-1"></span>
        <span class="orb orb-2"></span>
      </div>
      <div class="container hero-inner">
        <span class="hero-badge">开发者中心</span>
        <h1 class="hero-title">ChatPulse 技术文档</h1>
        <p class="hero-subtitle">架构方案、数据库设计、API 接口、部署指南，一站式参考</p>
        <div class="hero-cta">
          <NuxtLink to="/api-docs" class="btn btn-primary btn-lg">立即查看 API 文档</NuxtLink>
          <a href="#quickstart" class="btn btn-outline btn-lg hero-outline">快速开始</a>
        </div>
      </div>
    </section>

    <!-- ============ DOC CATEGORIES ============ -->
    <section class="section">
      <div class="container">
        <h2 class="section-title fade-in-up">文档分类导航</h2>
        <p class="section-subtitle fade-in-up">四大文档主题体系，从整体架构到落地细节，逐步深入掌握 ChatPulse 全栈能力</p>

        <div class="grid-2 doc-nav-grid">
          <NuxtLink
            v-for="(cat, i) in docCategories"
            :key="cat.title"
            :to="cat.link"
            class="card doc-nav-card fade-in-up"
            :style="{ animationDelay: (i * .08) + 's' }"
          >
            <span class="doc-icon" :style="{ background: cat.gradient }" v-html="cat.icon"></span>
            <h3 class="doc-title">{{ cat.title }}</h3>
            <p class="doc-desc">{{ cat.desc }}</p>
            <div class="doc-cta">
              <span>{{ cat.cta }}</span>
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" class="arrow">
                <path d="M5 12h14M13 6l6 6-6 6" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>
              </svg>
            </div>
            <div v-if="cat.tags.length" class="doc-tags">
              <span v-for="t in cat.tags" :key="t" class="tag">{{ t }}</span>
            </div>
          </NuxtLink>
        </div>
      </div>
    </section>

    <!-- ============ TECH STACK ============ -->
    <section class="section section-bg-2">
      <div class="container">
        <h2 class="section-title fade-in-up">技术栈速览</h2>
        <p class="section-subtitle fade-in-up">Go + Vue + Flutter 全栈架构，精选成熟稳定的技术组件，兼顾性能与可维护性</p>

        <div class="grid-4 tech-grid">
          <div
            v-for="(tech, i) in techStack"
            :key="tech.title"
            class="card tech-card fade-in-up"
            :style="{ animationDelay: (i * .07) + 's' }"
          >
            <div class="tech-head">
              <span class="tech-icon" :style="{ background: tech.gradient }" v-html="tech.icon"></span>
              <h3 class="tech-title">{{ tech.title }}</h3>
            </div>
            <div class="tech-list">
              <span v-for="item in tech.items" :key="item" class="tech-chip">{{ item }}</span>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- ============ QUICK START ============ -->
    <section id="quickstart" class="section">
      <div class="container">
        <h2 class="section-title fade-in-up">快速开始</h2>
        <p class="section-subtitle fade-in-up">按四步顺序完成源码授权、服务部署、客户端构建与生产上线，最快半天即可跑通完整 IM 链路</p>

        <div class="card quickstart-card fade-in-up">
          <ol class="quick-list">
            <li
              v-for="(step, i) in quickSteps"
              :key="step.title"
              class="quick-item"
            >
              <div class="quick-num">{{ i + 1 }}</div>
              <div class="quick-body">
                <h3 class="quick-title">{{ step.title }}</h3>
                <p class="quick-desc">{{ step.desc }}</p>
                <div v-if="step.code" class="quick-code">
                  <span class="code-mark">$</span>
                  <code>{{ step.code }}</code>
                </div>
              </div>
            </li>
          </ol>
        </div>
      </div>
    </section>

    <!-- ============ BOTTOM CTA ============ -->
    <section class="cta-section">
      <div class="container cta-inner fade-in-up">
        <h2 class="cta-title">想直接看接口？</h2>
        <p class="cta-sub">完整的 REST / WebSocket 接口文档，支持在线调试，随用随查</p>
        <NuxtLink to="/api-docs" class="btn btn-lg cta-btn">前往 API 接口文档 →</NuxtLink>
      </div>
    </section>
  </div>
</template>

<script setup lang="ts">
useHead({
  title: '技术文档 - ChatPulse 开发者中心',
  meta: [
    {
      name: 'description',
      content:
        'ChatPulse 技术文档中心：架构方案与数据库设计、REST / WebSocket API 接口文档、Docker 与宝塔部署运维指南、充值提现对接文档。基于 Go 1.22 + Gin + GORM + Vue 3.5 + Flutter 3.22 全栈技术栈。',
    },
    {
      name: 'keywords',
      content:
        'ChatPulse技术文档,IM API文档,Go IM 架构,数据库设计,部署指南,Docker部署,宝塔部署IM,Flutter IM 教程,MinIO对象存储,TRTC音视频集成',
    },
  ],
})

const docCategories = [
  {
    title: '架构方案 / 数据库设计',
    desc: '系统整体架构、模块划分、消息中间件选型、数据库表结构、索引策略与分库分表建议，是二次开发的必看起点。',
    cta: '查看架构文档',
    link: '/api-docs?cat=arch',
    gradient: 'var(--c-gradient)',
    icon: '<svg width="28" height="28" viewBox="0 0 24 24" fill="none"><rect x="3" y="3" width="8" height="8" rx="2" fill="#fff"/><rect x="13" y="3" width="8" height="5" rx="2" fill="#fff"/><rect x="13" y="10" width="8" height="11" rx="2" fill="#fff"/><rect x="3" y="13" width="8" height="8" rx="2" fill="#fff"/></svg>',
    tags: ['系统架构', 'ER 图', '分库分表'],
  },
  {
    title: 'API 接口文档',
    desc: '用户、消息、群组、音视频、钱包、支付、朋友圈、管理后台等全模块 REST 与 WebSocket 接口，支持在线调用示例。',
    cta: '查看 API 文档',
    link: '/api-docs',
    gradient: 'var(--c-gradient-green)',
    icon: '<svg width="28" height="28" viewBox="0 0 24 24" fill="none"><path d="M7 7l4 4-4 4M13 7h6M13 11h4M13 15h6" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/><rect x="3.5" y="4.5" width="17" height="15" rx="3" stroke="#fff" stroke-width="1.5"/></svg>',
    tags: ['REST', 'WebSocket', '在线调试'],
  },
  {
    title: '部署运维指南',
    desc: 'Docker Compose 一键部署、WSL / CentOS 7+ 系统依赖、Nginx 反向代理、HTTPS 证书配置、日志备份与监控告警完整指南。',
    cta: '查看部署文档',
    link: '/api-docs?cat=deploy',
    gradient: 'var(--c-gradient-orange)',
    icon: '<svg width="28" height="28" viewBox="0 0 24 24" fill="none"><rect x="3" y="4" width="18" height="7" rx="2" fill="#fff"/><rect x="3" y="14" width="18" height="7" rx="2" fill="#fff"/><circle cx="7.5" cy="7.5" r="1.3" fill="#ff7d00"/><circle cx="7.5" cy="17.5" r="1.3" fill="#ff7d00"/><path d="M11 7.5h6M11 17.5h6" stroke="#ff7d00" stroke-width="1.8" stroke-linecap="round"/></svg>',
    tags: ['Docker', '宝塔', 'Nginx'],
  },
  {
    title: '充值 / 提现对接',
    desc: '支付宝、微信支付、USDT、银联等支付通道接入说明，充值回调处理、提现审核流程、对账中心与财务接口规范。',
    cta: '查看对接文档',
    link: '/api-docs?cat=recharge',
    gradient: 'var(--c-gradient-purple)',
    icon: '<svg width="28" height="28" viewBox="0 0 24 24" fill="none"><rect x="3" y="6" width="18" height="13" rx="2.5" fill="#fff"/><rect x="3" y="10" width="18" height="3" fill="#7b61ff"/><circle cx="16.5" cy="16" r="1.5" fill="#7b61ff"/></svg>',
    tags: ['支付通道', '对账', '财务 API'],
  },
]

const techStack = [
  {
    title: '后端',
    gradient: 'var(--c-gradient)',
    icon: '<svg width="26" height="26" viewBox="0 0 24 24" fill="none"><path d="M12 2v4M12 18v4M4.93 4.93l2.83 2.83M16.24 16.24l2.83 2.83M2 12h4M18 12h4M4.93 19.07l2.83-2.83M16.24 7.76l2.83-2.83" stroke="#fff" stroke-width="2" stroke-linecap="round"/></svg>',
    items: ['Go 1.22', 'Gin', 'GORM (MySQL)', 'Redis', 'MongoDB (消息)', 'MinIO'],
  },
  {
    title: '管理后台',
    gradient: 'var(--c-gradient-green)',
    icon: '<svg width="26" height="26" viewBox="0 0 24 24" fill="none"><rect x="3" y="4" width="18" height="13" rx="2.5" fill="#fff"/><path d="M3 10h18M8 20h8" stroke="#00b42a" stroke-width="2" stroke-linecap="round"/></svg>',
    items: ['Vue 3.5', 'TypeScript', 'Arco Design', 'Pinia', 'Vite'],
  },
  {
    title: '移动端',
    gradient: 'var(--c-gradient-purple)',
    icon: '<svg width="26" height="26" viewBox="0 0 24 24" fill="none"><rect x="6" y="2.5" width="12" height="19" rx="2.5" fill="#fff"/><circle cx="12" cy="19" r="1" fill="#7b61ff"/></svg>',
    items: ['Flutter 3.22', 'Dart', 'TRTC (音视频)', 'JPush'],
  },
  {
    title: '部署',
    gradient: 'var(--c-gradient-orange)',
    icon: '<svg width="26" height="26" viewBox="0 0 24 24" fill="none"><path d="M3 7l9-4 9 4v10l-9 4-9-4V7z" stroke="#fff" stroke-width="2" stroke-linejoin="round"/><path d="M12 7l9-4M3 7l9 4M12 11L3 7M12 11v10" stroke="#fff" stroke-width="2" stroke-linecap="round"/></svg>',
    items: ['Docker Compose', 'WSL / CentOS7+', 'Nginx', 'PM2 (官网)'],
  },
]

const quickSteps = [
  {
    title: '申请源码授权 / 获取演示账号',
    desc: '通过官网商务渠道或 Telegram 联系 ChatPulse 团队，确认授权版本后，您将获得源码仓库访问权限、官方演示环境账号与对应技术文档入口。建议使用您公司常用的邮箱与 Git 账号注册，以便后续绑定授权。',
    code: '',
  },
  {
    title: 'Docker 一键部署后端服务',
    desc: '在已安装 Docker 与 Docker Compose 的 Linux / WSL 环境中，进入源码根目录的 deploy 文件夹，编辑 .env 配置文件中的数据库与 Redis 连接信息，然后执行一键启动命令即可拉起 IM 网关、消息服务、支付服务、管理后台 API 与 MySQL / Redis / MongoDB / MinIO 依赖组件。',
    code: 'cd deploy && cp .env.example .env && docker compose up -d',
  },
  {
    title: '构建前端与 Flutter APP',
    desc: '管理后台与官方网站位于 admin 与 web 目录，均为 Vue 3 + Vite 项目，执行 npm install 与 npm run build 即可得到静态产物。移动端位于 app 目录，为 Flutter 3.22 工程，先 flutter pub get 安装依赖，然后通过 Android Studio 或 Xcode 配置签名，最后执行对应构建命令得到 APK / IPA / 桌面端安装包。',
    code: 'npm run build && flutter build apk --release',
  },
  {
    title: '按《宝塔部署指南》上线生产环境',
    desc: '生产环境推荐使用宝塔面板或成熟的云主机环境进行部署。参照文档中的《宝塔部署指南》完成域名解析、Nginx 反向代理、HTTPS 证书配置、MySQL 调优、Redis 持久化策略、MinIO 存储桶权限与防火墙规则设置，最终将前端静态文件、后端二进制、移动端安装包分别部署，即可正式对外开放 ChatPulse 服务。',
    code: '',
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
  max-width: 820px;
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

/* ============ DOC NAV ============ */
.doc-nav-grid {
  gap: 24px;
}

.doc-nav-card {
  position: relative;
  display: flex;
  flex-direction: column;
  gap: 14px;
  padding: 32px;
  text-decoration: none;
  color: inherit;
  transition: box-shadow .3s, transform .3s;
  overflow: hidden;
}

.doc-nav-card::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  height: 4px;
  background: var(--c-gradient);
  opacity: 0;
  transition: opacity .3s;
}

.doc-nav-card:hover::before {
  opacity: 1;
}

.doc-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 60px;
  height: 60px;
  border-radius: 16px;
  flex-shrink: 0;
  align-self: flex-start;
  box-shadow: 0 8px 20px rgba(22, 93, 255, .2);
}

.doc-title {
  font-size: 24px;
  font-weight: 800;
  color: var(--c-text-1);
  letter-spacing: -.4px;
}

.doc-desc {
  font-size: 15px;
  line-height: 1.8;
  color: var(--c-text-2);
  flex: 1;
}

.doc-cta {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding-top: 4px;
  font-size: 15px;
  font-weight: 700;
  color: var(--c-primary);
}

.doc-cta .arrow {
  transition: transform .25s;
}

.doc-nav-card:hover .arrow {
  transform: translateX(4px);
}

.doc-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  padding-top: 10px;
  border-top: 1px solid var(--c-border);
  margin-top: 4px;
}

.doc-tags .tag {
  display: inline-block;
  padding: 4px 12px;
  font-size: 12px;
  font-weight: 600;
  color: var(--c-text-2);
  background: var(--c-bg-2);
  border-radius: 999px;
}

/* ============ TECH STACK ============ */
.section-bg-2 {
  background: var(--c-bg-2);
}

.tech-grid {
  gap: 20px;
}

.tech-card {
  display: flex;
  flex-direction: column;
  gap: 16px;
  padding: 24px;
}

.tech-head {
  display: flex;
  align-items: center;
  gap: 14px;
}

.tech-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 48px;
  height: 48px;
  border-radius: 12px;
  flex-shrink: 0;
}

.tech-title {
  font-size: 18px;
  font-weight: 800;
  color: var(--c-text-1);
}

.tech-list {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.tech-chip {
  display: inline-block;
  padding: 5px 12px;
  font-size: 12.5px;
  font-weight: 600;
  font-family: 'JetBrains Mono', Menlo, Consolas, monospace;
  color: var(--c-text-1);
  background: var(--c-bg-2);
  border: 1px solid var(--c-border);
  border-radius: 8px;
}

/* ============ QUICK START ============ */
.quickstart-card {
  background: linear-gradient(135deg, #ffffff 0%, #fafcff 100%);
  padding: 40px;
  border: 1px solid var(--c-border);
  max-width: 960px;
  margin: 0 auto;
}

.quick-list {
  list-style: none;
  counter-reset: none;
  display: flex;
  flex-direction: column;
  gap: 28px;
}

.quick-item {
  display: flex;
  gap: 22px;
  position: relative;
}

.quick-item:not(:last-child)::after {
  content: '';
  position: absolute;
  left: 23px;
  top: 58px;
  bottom: -28px;
  width: 2px;
  background: linear-gradient(180deg, var(--c-primary-light), var(--c-primary-bg));
}

.quick-num {
  flex-shrink: 0;
  width: 48px;
  height: 48px;
  border-radius: 50%;
  background: var(--c-gradient);
  color: #fff;
  font-size: 20px;
  font-weight: 900;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 6px 16px rgba(22, 93, 255, .3);
  position: relative;
  z-index: 1;
}

.quick-body {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding-top: 6px;
}

.quick-title {
  font-size: 20px;
  font-weight: 800;
  color: var(--c-text-1);
  letter-spacing: -.2px;
}

.quick-desc {
  font-size: 15px;
  line-height: 1.85;
  color: var(--c-text-2);
}

.quick-code {
  margin-top: 6px;
  display: inline-flex;
  align-items: center;
  gap: 10px;
  align-self: flex-start;
  padding: 12px 18px;
  background: #0f172a;
  color: #e2e8f0;
  border-radius: 10px;
  font-family: 'JetBrains Mono', Menlo, Consolas, monospace;
  font-size: 13.5px;
  line-height: 1.6;
  box-shadow: 0 4px 12px rgba(15, 23, 42, .2);
}

.code-mark {
  color: #6ea8ff;
  font-weight: 700;
}

.quick-code code {
  color: #fff;
  font-family: inherit;
  white-space: nowrap;
}

/* ============ BOTTOM CTA ============ */
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
  font-size: 36px;
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
  box-shadow: 0 10px 28px rgba(0, 0, 0, .22);
}

.cta-btn:hover {
  transform: translateY(-2px);
  background: #fff;
  color: var(--c-primary);
  box-shadow: 0 14px 36px rgba(0, 0, 0, .3);
}

/* ============ RESPONSIVE ============ */
@media (max-width: 900px) {
  .hero-title { font-size: 36px; }
  .doc-nav-grid { grid-template-columns: 1fr; }
  .tech-grid { grid-template-columns: 1fr 1fr; }
  .quickstart-card { padding: 28px; }
}

@media (max-width: 600px) {
  .hero { padding: 48px 0 56px; }
  .hero-title { font-size: 28px; }
  .hero-subtitle { font-size: 15px; }
  .hero-cta .btn { flex: 1; justify-content: center; }
  .tech-grid { grid-template-columns: 1fr; }
  .doc-nav-card { padding: 24px; }
  .doc-title { font-size: 20px; }
  .quickstart-card { padding: 22px 18px; }
  .quick-item {
    flex-direction: column;
    gap: 12px;
  }
  .quick-item:not(:last-child)::after {
    left: 23px;
    top: 48px;
  }
  .quick-num {
    width: 42px;
    height: 42px;
    font-size: 18px;
  }
  .quick-title { font-size: 18px; }
  .quick-desc { font-size: 14px; }
  .quick-code {
    font-size: 12.5px;
    padding: 10px 14px;
    white-space: normal;
    width: 100%;
    overflow-x: auto;
  }
  .cta-title { font-size: 26px; }
  .cta-sub { font-size: 15px; }
}
</style>
