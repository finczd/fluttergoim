<template>
  <div class="faq-page">
    <!-- ============ HERO ============ -->
    <section class="hero">
      <div class="hero-bg-deco" aria-hidden="true">
        <span class="orb orb-1"></span>
        <span class="orb orb-2"></span>
      </div>
      <div class="container hero-inner">
        <span class="hero-badge">帮助文档 & 常见问题</span>
        <h1 class="hero-title">常见问题与帮助文档</h1>
        <p class="hero-subtitle">这里整理了客户最关心的问题，涵盖部署、功能、技术、售后与定制开发</p>
      </div>
    </section>

    <!-- ============ FAQ MAIN ============ -->
    <section class="section">
      <div class="container">
        <div class="faq-layout">
          <!-- LEFT: CATEGORY SIDEBAR -->
          <aside class="faq-sidebar">
            <h3 class="sidebar-title">问题分类</h3>
            <nav class="category-tabs">
              <button
                v-for="cat in categories"
                :key="cat.key"
                type="button"
                class="category-tab"
                :class="{ active: activeCategory === cat.key }"
                @click="selectCategory(cat.key)"
              >
                <span class="cat-icon" v-html="cat.icon"></span>
                <span class="cat-label">{{ cat.label }}</span>
                <span class="cat-count">{{ cat.count }}</span>
              </button>
            </nav>
          </aside>

          <!-- RIGHT: CONTENT AREA -->
          <div class="faq-content">
            <div class="content-header fade-in-up">
              <h2 class="content-title">{{ currentCategory.label }}</h2>
              <p class="content-sub">{{ currentCategory.desc }}</p>
            </div>

            <div class="accordion">
              <div
                v-for="(item, i) in currentQuestions"
                :key="activeCategory + '-' + i"
                class="accordion-item card"
                :class="{ open: openIndex === i }"
              >
                <button
                  type="button"
                  class="accordion-header"
                  :aria-expanded="openIndex === i"
                  @click="toggle(i)"
                >
                  <span class="q-badge">Q</span>
                  <span class="q-text">{{ item.q }}</span>
                  <span class="q-arrow" aria-hidden="true">
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                      <path d="M6 9l6 6 6-6" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                    </svg>
                  </span>
                </button>
                <div class="accordion-body">
                  <div class="accordion-inner">
                    <span class="a-badge">A</span>
                    <p class="a-text">{{ item.a }}</p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- ============ CTA ============ -->
    <section class="cta-section">
      <div class="container cta-inner">
        <h2 class="cta-title">还有其他问题？联系我们</h2>
        <p class="cta-sub">如果没有找到您关心的内容，欢迎随时与我们的方案顾问沟通</p>
        <NuxtLink to="/contact" class="btn btn-lg cta-btn">联系我们 →</NuxtLink>
      </div>
    </section>
  </div>
</template>

<script setup>
useHead({
  title: '常见问题 - ChatPulse 企业级 IM',
  meta: [
    {
      name: 'description',
      content: 'ChatPulse IM系统常见问题与技术文档',
    },
    {
      name: 'keywords',
      content: 'ChatPulse,常见问题,FAQ,帮助文档,IM部署,IM技术,定制开发,售后支持',
    },
  ],
})

const activeCategory = ref('deploy')
const openIndex = ref(0)

const categories = [
  {
    key: 'deploy',
    label: '部署相关',
    desc: '关于系统环境、部署方式与数据迁移的常见问题',
    icon: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none"><rect x="3" y="4" width="18" height="6" rx="2" stroke="currentColor" stroke-width="2"/><rect x="3" y="14" width="18" height="6" rx="2" stroke="currentColor" stroke-width="2"/><circle cx="7" cy="7" r="1" fill="currentColor"/><circle cx="7" cy="17" r="1" fill="currentColor"/></svg>',
  },
  {
    key: 'feature',
    label: '功能相关',
    desc: '关于系统能力、容量上限与消息存储的常见问题',
    icon: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none"><path d="M7 4h10a3 3 0 0 1 3 3v6a3 3 0 0 1-3 3H9l-4 3v-3a3 3 0 0 1-1-2V7a3 3 0 0 1 3-3z" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/></svg>',
  },
  {
    key: 'tech',
    label: '技术相关',
    desc: '关于技术选型、架构与存储方案的常见问题',
    icon: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none"><path d="M9 8l-4 4 4 4M15 8l4 4-4 4M13 6l-2 12" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
  },
  {
    key: 'support',
    label: '售后相关',
    desc: '关于授权方式、更新、技术支持与退款的常见问题',
    icon: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none"><path d="M12 21s-7-4.5-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 11c0 5.5-7 10-7 10z" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/></svg>',
  },
  {
    key: 'custom',
    label: '定制开发',
    desc: '关于定制范围、开发周期与费用计算的常见问题',
    icon: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none"><path d="M14.7 6.3l3 3L7 20l-4 1 1-4L14.7 6.3z" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/><path d="M13 8l3 3" stroke="currentColor" stroke-width="2"/></svg>',
  },
]

const faqData = {
  deploy: [
    {
      q: '系统环境要求是什么？',
      a: '推荐 Linux 服务器（CentOS 7+ / Ubuntu 18.04+），最低配置 2 核 4G 内存，建议 4 核 8G 以上以支撑更高并发。系统支持 Docker 一键部署，也可手动部署。需要开放 WebSocket、HTTP 与 TRTC 相关端口。',
    },
    {
      q: '支持 Windows 部署吗？',
      a: '支持。后端 Go 服务、前端 Vue 项目与 MongoDB / Redis / MinIO 均可在 Windows 环境运行，但生产环境仍推荐 Linux，性能与稳定性更优。Windows 部署更适合本地开发与内部测试。',
    },
    {
      q: '宝塔面板如何部署？',
      a: '宝塔面板部署流程：1) 安装宝塔 Linux 版；2) 在软件商店安装 Docker 与 Docker Compose；3) 上传部署包到 /www/wwwroot/；4) 通过 SSH 终端执行 docker-compose up -d 启动；5) 在宝塔网站中配置反向代理与 SSL 证书。我们提供详细的宝塔部署文档。',
    },
    {
      q: '数据迁移怎么做？',
      a: '数据迁移分三步：1) MongoDB 消息数据使用 mongodump / mongorestore 备份恢复；2) MySQL 业务数据使用 mysqldump 或宝塔备份导出导入；3) MinIO 文件可通过 rclone 或客户端工具批量同步。我们提供迁移脚本与技术支持，协助平滑迁移。',
    },
  ],
  feature: [
    {
      q: '支持多少人同时在线？',
      a: '单机部署可支撑 5000-10000 并发在线，集群部署可线性扩展至 10 万+。实际并发量取决于服务器配置与网络带宽，我们提供压测报告与集群方案，按业务规模推荐合适的部署形态。',
    },
    {
      q: '群聊人数上限多少？',
      a: '默认群聊上限 500 人，可在后台配置调整。万人群组场景可通过集群部署 + 优化消息分发策略支持，需要根据实际业务场景评估服务器资源。系统已对超大规模群做了消息广播优化。',
    },
    {
      q: '消息存储多久？',
      a: '消息默认永久存储于 MongoDB，可在后台配置保留策略（如 90 天 / 1 年 / 永久）。文件类资源存储于 MinIO，支持配额管理与生命周期策略自动清理，节省存储成本。',
    },
    {
      q: '支持消息端到端加密吗？',
      a: '标准版采用传输层加密（TLS / WSS）+ 存储加密，保障传输与静态数据安全。端到端加密（E2EE）属于定制开发能力，可基于业务需求集成 Signal Protocol 或国密算法，需企业版授权。',
    },
  ],
  tech: [
    {
      q: '后端用什么语言？',
      a: '后端使用 Go 语言开发，基于 Gin 框架与 GORM 数据访问层。Go 的高并发特性非常适合 IM 长连接场景，配合 WebSocket 实现实时消息推送，性能稳定可靠。',
    },
    {
      q: '前端框架是什么？',
      a: '管理后台基于 Vue 3 + Arco Design 开发，使用 Composition API + Pinia 状态管理 + Vite 构建，配合 ECharts 做数据可视化。现代前端技术栈，维护方便、性能优秀。',
    },
    {
      q: '移动端用什么开发？',
      a: '移动端采用 Flutter 跨平台框架，一套代码同时输出 iOS 与 Android 双端，原生性能体验。集成 TRTC 音视频 SDK 与本地缓存机制，支持离线消息与多端同步。',
    },
    {
      q: '消息用什么存储？',
      a: '消息主体存储于 MongoDB，适合海量非结构化消息的高吞吐写入与查询。业务数据存储于 MySQL，缓存与在线状态使用 Redis，文件资源使用 MinIO 分布式对象存储。多存储协同，各司其职。',
    },
  ],
  support: [
    {
      q: '源码授权方式是什么？',
      a: '采用终身授权模式，一次购买即获完整前后端源代码与单机 / 集群部署授权。源码无加密、无后门，客户可自由进行二次开发。授权范围按授权数量（单机 / 集群）区分，详见定价页。',
    },
    {
      q: '后续更新免费吗？',
      a: '标准版赠送 3 个月免费更新，专业版赠送 1 年免费更新，企业版终身免费更新。更新范围包括功能迭代、Bug 修复与安全补丁。更新期满后可按年续费更新服务，原系统永久可用。',
    },
    {
      q: '技术支持响应时间多久？',
      a: '工作日 9:00-18:00 内响应，标准版 24 小时内回复，专业版 4 小时内回复，企业版 1 小时内响应并提供 7×24 紧急通道。支持远程协助、电话沟通与现场服务（企业版）。',
    },
    {
      q: '可以退款吗？',
      a: '由于源码属于数字商品，授权交付后不支持无理由退款。但我们承诺售前充分沟通，确保产品能力与您的需求匹配；售后提供完整技术支持与功能保障，如遇重大未解决问题可协商处理。',
    },
  ],
  custom: [
    {
      q: '支持哪些定制开发？',
      a: '支持全链路定制：UI 界面换肤、业务功能扩展（如 OA 审批、考勤、CRM 集成）、第三方系统对接（如单点登录、企业通讯录）、特殊行业合规改造（金融、政务、医疗）、性能优化与集群方案。详情可沟通需求清单。',
    },
    {
      q: '定制开发周期多久？',
      a: '小型定制（UI 调整、单个功能模块）约 1-2 周；中型定制（业务流程对接、多模块集成）约 3-6 周；大型定制（行业化改造、完整业务系统）1-3 个月。具体周期在需求评审后给出明确排期。',
    },
    {
      q: '定制费用如何计算？',
      a: '定制费用按工作量评估：1) 需求评审确认范围；2) 拆解任务估算人天；3) 按人天单价（800-1500 元 / 人天，视技术难度）汇总；4) 给出报价与排期。签订定制合同后按里程碑分期付款，源码同步交付。',
    },
  ],
}

const currentCategory = computed(() => {
  const cat = categories.find(c => c.key === activeCategory.value)
  return {
    ...cat,
    count: faqData[activeCategory.value].length,
  }
})

const currentQuestions = computed(() => faqData[activeCategory.value])

function selectCategory(key) {
  if (activeCategory.value === key) return
  activeCategory.value = key
  openIndex.value = 0
}

function toggle(index) {
  openIndex.value = openIndex.value === index ? -1 : index
}
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
  max-width: 760px;
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

/* ============ FAQ LAYOUT ============ */
.faq-layout {
  display: grid;
  grid-template-columns: 280px 1fr;
  gap: 40px;
  align-items: flex-start;
}

/* ============ SIDEBAR ============ */
.faq-sidebar {
  position: sticky;
  top: 24px;
  background: var(--c-bg-1);
  border: 1px solid var(--c-border);
  border-radius: var(--radius-lg);
  padding: 20px;
  box-shadow: var(--shadow-card);
}

.sidebar-title {
  font-size: 13px;
  font-weight: 700;
  color: var(--c-text-3);
  text-transform: uppercase;
  letter-spacing: 1px;
  margin-bottom: 14px;
  padding-left: 4px;
}

.category-tabs {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.category-tab {
  display: flex;
  align-items: center;
  gap: 10px;
  width: 100%;
  padding: 11px 14px;
  background: transparent;
  border: 1px solid transparent;
  border-radius: var(--radius-md);
  font-size: 14px;
  font-weight: 600;
  color: var(--c-text-2);
  cursor: pointer;
  transition: all .2s;
  text-align: left;
}

.category-tab:hover {
  background: var(--c-bg-2);
  color: var(--c-text-1);
}

.category-tab.active {
  background: var(--c-primary-bg);
  color: var(--c-primary);
  border-color: rgba(22, 93, 255, .2);
}

.cat-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 28px;
  height: 28px;
  border-radius: 8px;
  background: var(--c-bg-2);
  color: var(--c-text-2);
  flex-shrink: 0;
  transition: all .2s;
}

.category-tab.active .cat-icon {
  background: var(--c-gradient);
  color: #fff;
}

.cat-label {
  flex: 1;
}

.cat-count {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 22px;
  height: 22px;
  padding: 0 7px;
  font-size: 12px;
  font-weight: 700;
  color: var(--c-text-3);
  background: var(--c-bg-2);
  border-radius: 999px;
  transition: all .2s;
}

.category-tab.active .cat-count {
  background: rgba(22, 93, 255, .2);
  color: var(--c-primary);
}

/* ============ CONTENT ============ */
.content-header {
  margin-bottom: 24px;
}

.content-title {
  font-size: 28px;
  font-weight: 800;
  color: var(--c-text-1);
  letter-spacing: -.5px;
  margin-bottom: 8px;
}

.content-sub {
  font-size: 15px;
  color: var(--c-text-3);
}

/* ============ ACCORDION ============ */
.accordion {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.accordion-item {
  padding: 0;
  overflow: hidden;
  transition: box-shadow .3s, transform .3s, border-color .3s;
}

.accordion-item:hover {
  transform: none;
}

.accordion-item.open {
  border-color: rgba(22, 93, 255, .35);
  box-shadow: 0 8px 24px rgba(22, 93, 255, .1);
}

.accordion-header {
  display: flex;
  align-items: center;
  gap: 14px;
  width: 100%;
  padding: 18px 22px;
  background: transparent;
  border: none;
  cursor: pointer;
  text-align: left;
  font-size: 16px;
  font-weight: 600;
  color: var(--c-text-1);
  transition: background .2s;
}

.accordion-header:hover {
  background: var(--c-bg-2);
}

.q-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 28px;
  height: 28px;
  border-radius: 8px;
  background: var(--c-primary-bg);
  color: var(--c-primary);
  font-size: 13px;
  font-weight: 800;
  flex-shrink: 0;
}

.q-text {
  flex: 1;
  line-height: 1.5;
}

.q-arrow {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  color: var(--c-text-3);
  transition: transform .3s ease, color .2s;
  flex-shrink: 0;
}

.accordion-item.open .q-arrow {
  transform: rotate(180deg);
  color: var(--c-primary);
}

.accordion-body {
  max-height: 0;
  overflow: hidden;
  transition: max-height .35s ease;
}

.accordion-item.open .accordion-body {
  max-height: 500px;
}

.accordion-inner {
  display: flex;
  gap: 14px;
  padding: 4px 22px 22px;
  align-items: flex-start;
}

.a-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 28px;
  height: 28px;
  border-radius: 8px;
  background: rgba(0, 180, 42, .12);
  color: var(--c-accent);
  font-size: 13px;
  font-weight: 800;
  flex-shrink: 0;
}

.a-text {
  flex: 1;
  font-size: 14px;
  line-height: 1.75;
  color: var(--c-text-2);
  padding-top: 4px;
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
  .faq-layout {
    grid-template-columns: 1fr;
    gap: 24px;
  }

  .faq-sidebar {
    position: static;
  }

  .category-tabs {
    flex-direction: row;
    overflow-x: auto;
    gap: 8px;
    padding-bottom: 4px;
  }

  .category-tab {
    flex-shrink: 0;
    padding: 9px 14px;
  }

  .cat-count { display: none; }

  .hero-title { font-size: 36px; }
  .content-title { font-size: 24px; }
}

@media (max-width: 600px) {
  .hero { padding: 48px 0 56px; }
  .hero-title { font-size: 30px; }
  .hero-subtitle { font-size: 16px; }

  .accordion-header {
    padding: 14px 16px;
    gap: 10px;
    font-size: 15px;
  }

  .q-badge,
  .a-badge {
    width: 24px;
    height: 24px;
    font-size: 12px;
  }

  .accordion-inner {
    padding: 4px 16px 16px;
    gap: 10px;
  }

  .a-text { font-size: 13px; }

  .cta-title { font-size: 26px; }
  .cta-sub { font-size: 15px; }
}
</style>
