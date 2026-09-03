<template>
  <div class="features-page">
    <!-- ============ HERO ============ -->
    <section class="hero">
      <div class="hero-bg-deco" aria-hidden="true">
        <span class="orb orb-1"></span>
        <span class="orb orb-2"></span>
      </div>
      <div class="container hero-inner">
        <span class="hero-badge">全栈 IM 功能矩阵</span>
        <h1 class="hero-title">全栈IM功能，开箱即用</h1>
        <p class="hero-subtitle">覆盖即时通讯、音视频、钱包支付、社交互动、后台管理与智能助手六大模块，成熟稳定，支持深度定制</p>
        <div class="hero-cta">
          <NuxtLink to="/pricing" class="btn btn-primary btn-lg">查看定价</NuxtLink>
          <NuxtLink to="/contact" class="btn btn-outline btn-lg hero-outline">咨询定制</NuxtLink>
        </div>
      </div>
    </section>

    <!-- ============ FEATURE CATEGORIES ============ -->
    <section class="section">
      <div class="container">
        <h2 class="section-title fade-in-up">按模块查看功能</h2>
        <p class="section-subtitle fade-in-up">六大模块，覆盖企业 IM 全场景需求，每个模块均可独立配置与扩展</p>

        <div class="feature-categories">
          <div
            v-for="(cat, i) in categories"
            :key="cat.title"
            class="card feature-cat fade-in-up"
            :style="{ animationDelay: (i * .08) + 's' }"
          >
            <div class="cat-header">
              <span class="cat-icon" :style="{ background: cat.gradient }" v-html="cat.icon"></span>
              <div class="cat-titles">
                <span class="cat-tag">{{ cat.tag }}</span>
                <h3 class="cat-title">{{ cat.title }}</h3>
                <p class="cat-desc">{{ cat.desc }}</p>
              </div>
            </div>
            <ul class="cat-features">
              <li v-for="feat in cat.features" :key="feat">
                <span class="check-icon" v-html="checkSvg"></span>
                <span class="feat-text">{{ feat }}</span>
              </li>
            </ul>
          </div>
        </div>
      </div>
    </section>

    <!-- ============ CTA ============ -->
    <section class="cta-section">
      <div class="container cta-inner">
        <h2 class="cta-title">需要更多功能？支持定制开发</h2>
        <p class="cta-sub">专属团队按需打造贴合业务场景的 IM 能力，源码交付、终身授权</p>
        <NuxtLink to="/contact" class="btn btn-lg cta-btn">联系定制 →</NuxtLink>
      </div>
    </section>
  </div>
</template>

<script setup>
useHead({
  title: '功能特性 - ChatPulse 企业级 IM',
  meta: [
    {
      name: 'description',
      content:
        'ChatPulse 全栈 IM 功能矩阵：即时通讯(单聊群聊/撤回/已读/@/表情文件)、音视频通话(TRTC/多人会议/画板)、钱包支付(红包/转账/充值提现/二维码)、社交(朋友圈/靓号)、管理后台(用户/群组/审计/财务)、智能助手(自动加好友/群发)。',
    },
    {
      name: 'keywords',
      content:
        'IM功能,即时通讯功能,单聊群聊,音视频通话,TRTC,红包转账,朋友圈,靓号系统,管理后台,智能助手,ChatPulse',
    },
  ],
})

const checkSvg =
  '<svg width="16" height="16" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M3.5 8.5l3 3 6-6.5" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>'

const categories = [
  {
    tag: '即时通讯',
    title: '稳定可靠的消息体系',
    desc: '支持万人群组、多端同步与丰富的消息类型，畅快沟通',
    gradient: 'var(--c-gradient)',
    icon: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M7 4h10a3 3 0 0 1 3 3v6a3 3 0 0 1-3 3H9l-4 3v-3a3 3 0 0 1-1-2V7a3 3 0 0 1 3-3z" fill="#fff"/><circle cx="8.5" cy="10" r="1.1" fill="#165dff"/><circle cx="12" cy="10" r="1.1" fill="#165dff"/><circle cx="15.5" cy="10" r="1.1" fill="#165dff"/></svg>',
    features: [
      '单聊：文本、图片、语音消息全支持',
      '群聊：单群最多 500 人，灵活管理',
      '消息撤回 / 转发 / 收藏一应俱全',
      '消息已读回执，沟通状态清晰可见',
      '@提及功能，重要信息不错过',
      '表情、文件传输，沟通更丰富',
    ],
  },
  {
    tag: '音视频通话',
    title: '高清稳定的实时通话',
    desc: '基于腾讯 TRTC 底层，低延迟、高可用，支撑各种会议场景',
    gradient: 'var(--c-gradient-green)',
    icon: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><rect x="2.5" y="5.5" width="13" height="13" rx="3" fill="#fff"/><path d="M16 10l4.5-2.5v9L16 14v-4z" fill="#fff"/><circle cx="9" cy="12" r="2.6" fill="#00b42a"/></svg>',
    features: [
      '一对一语音 / 视频通话',
      '多人视频会议，灵活接入',
      '画板共享，协作更高效',
      '腾讯 TRTC 底层能力，低延迟稳定',
      '支持弱网环境下流畅通话',
      '通话录制与回放可选',
    ],
  },
  {
    tag: '钱包支付',
    title: '安全可靠的资金流转',
    desc: '内置钱包系统，红包、转账、充值提现与二维码支付全打通',
    gradient: 'var(--c-gradient-orange)',
    icon: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><rect x="3" y="5" width="18" height="14" rx="3" fill="#fff"/><rect x="3" y="9" width="18" height="3" fill="#ff7d00"/><circle cx="12" cy="14.5" r="1.6" fill="#ff7d00"/></svg>',
    features: [
      '零钱余额，资金管理一目了然',
      '红包：拼手气 / 普通两种模式',
      '转账功能，资金秒到账',
      '充值 / 提现，对接支付通道',
      '支付二维码，扫码即付',
      '资金流水可追溯，安全合规',
    ],
  },
  {
    tag: '社交功能',
    title: '丰富的社交互动玩法',
    desc: '朋友圈、点赞评论与靓号体系，打造企业内部社交圈子',
    gradient: 'var(--c-gradient-purple)',
    icon: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><rect x="3" y="4" width="18" height="16" rx="3" fill="#fff"/><circle cx="9" cy="10" r="1.8" fill="#7b61ff"/><path d="M5 17l3.5-4 2.5 3 3.5-5 4 6H5z" fill="#7b61ff"/></svg>',
    features: [
      '朋友圈：图文 / 视频动态发布',
      '点赞与评论，互动更活跃',
      '靓号系统：批量生成 / 分配 / 冻结',
      '靓号竞价与交易，沉淀数字资产',
      '好友关系链与隐私分组',
      '动态推送与消息提醒',
    ],
  },
  {
    tag: '管理后台',
    title: '一站可视的运营管理',
    desc: '用户、群组、消息、财务、配置与日志统一管理，权限可控',
    gradient: 'var(--c-gradient)',
    icon: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><rect x="3" y="3" width="8" height="8" rx="2" fill="#fff"/><rect x="13" y="3" width="8" height="5" rx="2" fill="#fff"/><rect x="13" y="10" width="8" height="11" rx="2" fill="#fff"/><rect x="3" y="13" width="8" height="8" rx="2" fill="#fff"/></svg>',
    features: [
      '用户管理：注册、封禁、权限分配',
      '群组管理：创建、审核、解散',
      '消息审计：敏感词过滤与追溯',
      '系统配置：参数灵活调整',
      '支付配置：通道与费率管理',
      '财务统计与运行日志',
    ],
  },
  {
    tag: '智能助手',
    title: 'AI 驱动的效率提升',
    desc: '自动添加好友、欢迎语、群发推送与会话回复，运营更轻松',
    gradient: 'var(--c-gradient-purple)',
    icon: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><rect x="5" y="6" width="14" height="12" rx="3" fill="#fff"/><circle cx="9" cy="11" r="1.2" fill="#7b61ff"/><circle cx="15" cy="11" r="1.2" fill="#7b61ff"/><path d="M9 14h6" stroke="#7b61ff" stroke-width="1.4" stroke-linecap="round"/><path d="M12 3v3M8.5 4.5l1 2M15.5 4.5l-1 2" stroke="#7b61ff" stroke-width="1.2" stroke-linecap="round"/></svg>',
    features: [
      '自动添加好友，运营无遗漏',
      '欢迎语配置，新成员体验佳',
      '群发推送，活动信息触达',
      '会话自动回复，提升响应效率',
      '关键词触发与多场景话术',
      '数据统计与效果分析',
    ],
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

/* ============ FEATURE CATEGORIES ============ */
.feature-categories {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 24px;
}

.feature-cat {
  display: flex;
  flex-direction: column;
  gap: 20px;
  padding: 32px;
}

.cat-header {
  display: flex;
  gap: 16px;
  align-items: flex-start;
}

.cat-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 52px;
  height: 52px;
  border-radius: 14px;
  flex-shrink: 0;
}

.cat-titles {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.cat-tag {
  display: inline-block;
  align-self: flex-start;
  padding: 3px 10px;
  font-size: 12px;
  font-weight: 600;
  color: var(--c-primary);
  background: var(--c-primary-bg);
  border-radius: 999px;
  margin-bottom: 4px;
}

.cat-title {
  font-size: 22px;
  font-weight: 800;
  color: var(--c-text-1);
  letter-spacing: -.3px;
}

.cat-desc {
  font-size: 14px;
  color: var(--c-text-3);
  line-height: 1.6;
}

.cat-features {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding-top: 4px;
  border-top: 1px solid var(--c-border);
  margin-top: 4px;
}

.cat-features li {
  display: flex;
  align-items: center;
  gap: 10px;
  font-size: 14px;
  color: var(--c-text-2);
  padding-top: 8px;
}

.check-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 22px;
  height: 22px;
  border-radius: 50%;
  background: var(--c-primary-bg);
  color: var(--c-primary);
  flex-shrink: 0;
}

.feat-text {
  line-height: 1.5;
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
  .feature-categories {
    grid-template-columns: 1fr;
  }
  .hero-title { font-size: 38px; }
}

@media (max-width: 600px) {
  .hero { padding: 48px 0 56px; }
  .hero-title { font-size: 30px; }
  .hero-subtitle { font-size: 16px; }
  .hero-cta .btn { flex: 1; justify-content: center; }
  .feature-cat { padding: 24px; }
  .cat-title { font-size: 20px; }
  .cta-title { font-size: 26px; }
}
</style>
