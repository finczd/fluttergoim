<template>
  <div class="custom-page">
    <!-- ============ HERO ============ -->
    <section class="hero">
      <div class="hero-bg-deco" aria-hidden="true">
        <span class="orb orb-1"></span>
        <span class="orb orb-2"></span>
      </div>
      <div class="container hero-inner">
        <span class="hero-badge">10+ 年 IM 行业经验</span>
        <h1 class="hero-title">企业定制 IM 开发服务</h1>
        <p class="hero-subtitle">
          从需求分析、UI 设计、开发、部署到运维的全流程服务，帮您打造属于自己的即时通讯品牌
        </p>
        <div class="hero-cta">
          <NuxtLink to="/contact" class="btn btn-primary btn-lg">获取定制方案</NuxtLink>
          <NuxtLink to="/pricing" class="btn btn-outline btn-lg hero-outline">查看授权方式</NuxtLink>
        </div>
      </div>
    </section>

    <!-- ============ PROCESS TIMELINE ============ -->
    <section class="section">
      <div class="container">
        <h2 class="section-title fade-in-up">服务流程</h2>
        <p class="section-subtitle fade-in-up">五步标准化交付流程，全程透明可控，确保项目按时、按质、按预算落地</p>

        <div class="process-steps">
          <div
            v-for="(step, i) in processSteps"
            :key="step.id"
            class="process-step fade-in-up"
            :style="{ animationDelay: (i * .08) + 's' }"
          >
            <div class="step-top">
              <div class="step-circle">
                <span class="step-num">{{ i + 1 }}</span>
              </div>
              <div v-if="i < processSteps.length - 1" class="step-line" aria-hidden="true"></div>
            </div>
            <h3 class="step-title">{{ step.title }}</h3>
            <p class="step-desc">{{ step.desc }}</p>
          </div>
        </div>
      </div>
    </section>

    <!-- ============ CUSTOMIZE SCOPE ============ -->
    <section class="section section-bg-2">
      <div class="container">
        <h2 class="section-title fade-in-up">我们能定制什么</h2>
        <p class="section-subtitle fade-in-up">从视觉到功能、从前端到后端、从单端到全平台，ChatPulse 支持全方位深度定制</p>

        <div class="grid-3 scope-grid">
          <div
            v-for="(item, i) in scopeItems"
            :key="item.title"
            class="card scope-card fade-in-up"
            :style="{ animationDelay: (i * .06) + 's' }"
          >
            <span class="scope-icon" :style="{ background: item.gradient }" v-html="item.icon"></span>
            <h3 class="scope-title">{{ item.title }}</h3>
            <ul class="scope-list">
              <li v-for="point in item.points" :key="point">
                <span class="scope-dot"></span>{{ point }}
              </li>
            </ul>
          </div>
        </div>
      </div>
    </section>

    <!-- ============ DELIVERABLES ============ -->
    <section class="section">
      <div class="container">
        <h2 class="section-title fade-in-up">交付清单</h2>
        <p class="section-subtitle fade-in-up">一次授权，完整交付，真正实现代码、文档、培训、服务四位一体的全流程保障</p>

        <div class="grid-2 deliver-grid">
          <div
            v-for="(item, i) in deliverables"
            :key="item.title"
            class="card deliver-card fade-in-up"
            :style="{ animationDelay: (i * .08) + 's' }"
          >
            <div class="deliver-left">
              <span class="deliver-icon" v-html="item.icon"></span>
            </div>
            <div class="deliver-content">
              <h3 class="deliver-title">{{ item.title }}</h3>
              <p class="deliver-desc">{{ item.desc }}</p>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- ============ CASES ============ -->
    <section class="section section-bg-2">
      <div class="container">
        <h2 class="section-title fade-in-up">典型客户案例</h2>
        <p class="section-subtitle fade-in-up">服务覆盖多行业场景，满足不同组织架构、不同合规要求的专属 IM 需求</p>

        <div class="grid-2 case-grid">
          <div
            v-for="(item, i) in cases"
            :key="item.title"
            class="card case-card fade-in-up"
            :style="{ animationDelay: (i * .08) + 's' }"
          >
            <div class="case-head">
              <span class="case-tag" :style="{ background: item.tagBg, color: item.tagColor }">{{ item.tag }}</span>
              <span class="case-icon" :style="{ background: item.gradient }" v-html="item.icon"></span>
            </div>
            <h3 class="case-title">{{ item.title }}</h3>
            <p class="case-desc">{{ item.desc }}</p>
            <ul class="case-highlights">
              <li v-for="h in item.highlights" :key="h">
                <span class="case-check">
                  <svg width="14" height="14" viewBox="0 0 16 16" fill="none"><path d="M3.5 8.5l3 3 6-6.5" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
                </span>{{ h }}
              </li>
            </ul>
          </div>
        </div>
      </div>
    </section>

    <!-- ============ CTA ============ -->
    <section class="cta-section">
      <div class="container cta-inner">
        <h2 class="cta-title">获取专属定制方案</h2>
        <p class="cta-sub">联系 Telegram 商务团队，1 对 1 沟通需求，获取专业方案与透明报价</p>
        <NuxtLink to="/contact" class="btn btn-lg cta-btn">联系 Telegram 商务 →</NuxtLink>
        <p class="cta-tips">响应时效：1 个工作日内 · 支持中文 / English 双语沟通</p>
      </div>
    </section>
  </div>
</template>

<script setup lang="ts">
useHead({
  title: '企业定制 IM 开发服务 - ChatPulse',
  meta: [
    {
      name: 'description',
      content:
        'ChatPulse 企业定制 IM 开发服务：UI/UX 定制、功能模块定制、钱包支付定制、第三方对接、服务器部署定制、多端定制。覆盖政府、医疗、教育、企业集团等典型场景，源码交付，终身技术支持。',
    },
    {
      name: 'keywords',
      content:
        '企业IM定制开发,即时通讯源码定制,品牌聊天APP开发,私有化部署IM定制,OA集成对接,音视频集成,支付定制,HarmonyOS定制,Flutter IM定制,政企IM定制',
    },
  ],
})

const processSteps = [
  {
    id: '1',
    title: '需求沟通',
    desc: '专属方案顾问 1 对 1 深入了解您的业务场景、用户规模、功能清单与合规要求，输出初步需求确认文档。',
  },
  {
    id: '2',
    title: '方案设计',
    desc: '基于需求清单输出架构设计、UI 交互原型、技术选型、排期计划与工作量评估，双方确认里程碑节点。',
  },
  {
    id: '3',
    title: '合同与报价',
    desc: '提供透明合理的分项报价、付款节点、交付标准与售后条款，签订正式合同后进入开发阶段。',
  },
  {
    id: '4',
    title: '开发交付',
    desc: '按里程碑节奏推进开发、联调与内部测试，每周同步进度，客户可在演示环境随时验收阶段成果。',
  },
  {
    id: '5',
    title: '上线与运维',
    desc: '协助部署至客户生产环境，提供运维培训与 30 天上线护航，终身 bug 修复与长期有偿扩展服务。',
  },
]

const scopeItems = [
  {
    title: 'UI/UX 定制',
    gradient: 'var(--c-gradient)',
    icon: '<svg width="26" height="26" viewBox="0 0 24 24" fill="none"><path d="M12 2l2.4 6.6L21 11l-6.6 2.4L12 20l-2.4-6.6L3 11l6.6-2.4L12 2z" fill="#fff" fill-opacity=".9"/></svg>',
    points: [
      '品牌主色、辅色、主题色自由定制',
      'LOGO、启动页、引导页设计',
      '表情包与聊天贴纸定制',
      '多语言国际化（中英日韩越等）',
    ],
  },
  {
    title: '功能模块定制',
    gradient: 'var(--c-gradient-green)',
    icon: '<svg width="26" height="26" viewBox="0 0 24 24" fill="none"><rect x="3" y="4" width="18" height="5" rx="2" fill="#fff"/><rect x="3" y="11" width="8" height="9" rx="2" fill="#fff"/><rect x="13" y="11" width="8" height="9" rx="2" fill="#fff"/></svg>',
    points: [
      'OA 集成、CRM 对接、组织架构管理',
      '审批流程、电子签章、任务协同',
      '多人会议白板、屏幕共享',
      '阅后即焚、端到端加密、安全等级',
    ],
  },
  {
    title: '钱包与支付定制',
    gradient: 'var(--c-gradient-orange)',
    icon: '<svg width="26" height="26" viewBox="0 0 24 24" fill="none"><rect x="3" y="6" width="18" height="13" rx="2.5" fill="#fff"/><rect x="3" y="10" width="18" height="3" fill="#ff7d00"/><circle cx="16.5" cy="16" r="1.4" fill="#ff7d00"/></svg>',
    points: [
      '多种支付通道接入（微信、支付宝、银联、USDT 等）',
      '法币 / 虚拟币双通道配置',
      '收单商户体系、分润与结算策略',
      '提现手续费策略与对账中心',
    ],
  },
  {
    title: '第三方服务对接',
    gradient: 'var(--c-gradient-purple)',
    icon: '<svg width="26" height="26" viewBox="0 0 24 24" fill="none"><circle cx="6" cy="6" r="3" fill="#fff"/><circle cx="18" cy="6" r="3" fill="#fff"/><circle cx="6" cy="18" r="3" fill="#fff"/><circle cx="18" cy="18" r="3" fill="#fff"/><path d="M9 6h6M6 9v6M18 9v6M9 18h6" stroke="#fff" stroke-width="1.5"/></svg>',
    points: [
      '语音视频服务商：TRTC / ZEGO / 声网',
      '推送服务：JPush / 华为 / 小米 / iOS APNs',
      'OCR 识别、机器翻译、短信通道',
      'AIGC 智能助手：文心一言 / 通义千问 / 本地大模型',
    ],
  },
  {
    title: '服务器与部署定制',
    gradient: 'var(--c-gradient)',
    icon: '<svg width="26" height="26" viewBox="0 0 24 24" fill="none"><rect x="3" y="3" width="18" height="7" rx="2" fill="#fff"/><rect x="3" y="14" width="18" height="7" rx="2" fill="#fff"/><circle cx="7.5" cy="6.5" r="1" fill="#165dff"/><circle cx="7.5" cy="17.5" r="1" fill="#165dff"/><path d="M11 6h6M11 17h6" stroke="#165dff" stroke-width="1.6" stroke-linecap="round"/></svg>',
    points: [
      '阿里云、腾讯云、华为云公云部署',
      '自建机房、内网环境、离线部署',
      'WSL / K8s 高可用集群化方案',
      '私有化一键部署脚本与容器镜像',
    ],
  },
  {
    title: '多端定制',
    gradient: 'var(--c-gradient-green)',
    icon: '<svg width="26" height="26" viewBox="0 0 24 24" fill="none"><rect x="5" y="2" width="10" height="18" rx="2" fill="#fff"/><rect x="3" y="7" width="18" height="13" rx="2" fill="#fff" fill-opacity=".6"/><circle cx="10" cy="17" r="1" fill="#00b42a"/></svg>',
    points: [
      'Android / iOS 原生 Flutter 双端',
      'Windows / macOS / Linux 桌面端',
      'H5 与微信小程序端',
      '鸿蒙 OpenHarmony / HarmonyOS NEXT 适配',
    ],
  },
]

const deliverables = [
  {
    title: '完整源代码 + 构建脚本',
    desc: '全栈源码一次性交付，后端 Go、管理后台 Vue、移动端 Flutter 全部无加密、无后门，配套 Makefile 与 Shell 构建脚本，支持客户自主二次开发。',
    icon: '<svg width="28" height="28" viewBox="0 0 24 24" fill="none"><path d="M8 6l-5 6 5 6M16 6l5 6-5 6M14 4l-4 16" stroke="#165dff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
  },
  {
    title: '技术文档 + 运维手册',
    desc: '架构设计文档、数据库设计文档、接口 API 文档、部署运维手册、常见问题 FAQ，覆盖从源码编译到生产运维的完整知识体系。',
    icon: '<svg width="28" height="28" viewBox="0 0 24 24" fill="none"><path d="M6 3h9l5 5v13a1 1 0 01-1 1H6a1 1 0 01-1-1V4a1 1 0 011-1z" stroke="#165dff" stroke-width="2"/><path d="M15 3v5h5M8 13h8M8 17h5" stroke="#165dff" stroke-width="2" stroke-linecap="round"/></svg>',
  },
  {
    title: '一对一培训 + 30 天护航',
    desc: '专属工程师通过远程会议，对客户技术团队进行源码解读、部署流程、后台操作与排障方法的系统化培训，并提供 30 天上线护航。',
    icon: '<svg width="28" height="28" viewBox="0 0 24 24" fill="none"><circle cx="9" cy="8" r="3.2" stroke="#165dff" stroke-width="2"/><path d="M2.5 20a6.5 6.5 0 0113 0M15 10l3 3M18 10l-3 3M22 14v4a2 2 0 01-2 2h-4" stroke="#165dff" stroke-width="2" stroke-linecap="round"/></svg>',
  },
  {
    title: '终身 bug 修复支持',
    desc: '官方承诺终身免费修复授权范围内的产品缺陷与安全漏洞，不设期限、不额外收费。同时提供有偿功能扩展与版本升级服务。',
    icon: '<svg width="28" height="28" viewBox="0 0 24 24" fill="none"><path d="M12 2l8 4v6c0 5-3.5 9-8 10-4.5-1-8-5-8-10V6l8-4z" stroke="#165dff" stroke-width="2"/><path d="M9 12l2 2 4-4" stroke="#165dff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
  },
]

const cases = [
  {
    tag: '政府单位',
    tagBg: '#e8f3ff',
    tagColor: '#165dff',
    gradient: 'var(--c-gradient)',
    icon: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none"><path d="M4 20V10h16v10H4zM3 20h18M12 4l8 4H4l8-4zM9 20v-6h6v6" stroke="#fff" stroke-width="1.8" stroke-linejoin="round"/></svg>',
    title: '政务协同内网 IM',
    desc: '为某省级单位打造内网部署的政务协同 IM，实现部门分级管理、密级消息、审计追溯与国产信创环境适配。',
    highlights: [
      '完全内网离线部署，无外部依赖',
      '多级组织架构与权限控制',
      '敏感词审计与消息溯源',
    ],
  },
  {
    tag: '医疗机构',
    tagBg: '#e8ffea',
    tagColor: '#00b42a',
    gradient: 'var(--c-gradient-green)',
    icon: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none"><path d="M12 3l8 4v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V7l8-4z" fill="#fff" fill-opacity=".9"/><path d="M12 9v6M9 12h6" stroke="#00b42a" stroke-width="2.2" stroke-linecap="round"/></svg>',
    title: '医护人员沟通系统',
    desc: '为三甲医院打造医护专属沟通平台，集成排班、会诊、病历附件、紧急通知，保障医疗信息流转高效安全。',
    highlights: [
      '科室群组自动创建与维护',
      '紧急通知 15 分钟必达确认',
      '病历附件加密传输与权限控制',
    ],
  },
  {
    tag: '教育行业',
    tagBg: '#fff1df',
    tagColor: '#ff7d00',
    gradient: 'var(--c-gradient-orange)',
    icon: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none"><path d="M3 9l9-5 9 5-9 5-9-5z" fill="#fff"/><path d="M7 11.5V15c0 2 2.5 4 5 4s5-2 5-4v-3.5M21 9v6" stroke="#ff7d00" stroke-width="2" stroke-linecap="round"/></svg>',
    title: '校园师生通讯 + 家长群',
    desc: '为 K12 教育集团建设覆盖师生家长三端的校园通讯系统，集成作业通知、成绩推送、缴费与家校群等场景。',
    highlights: [
      '组织架构按学校 / 年级 / 班级自动分组',
      '家长群实名制与教师身份标识',
      '作业通知已读统计与缴费集成',
    ],
  },
  {
    tag: '企业集团',
    tagBg: '#f0ecff',
    tagColor: '#7b61ff',
    gradient: 'var(--c-gradient-purple)',
    icon: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none"><rect x="3" y="4" width="18" height="16" rx="2" fill="#fff"/><rect x="3" y="9" width="18" height="3" fill="#7b61ff" fill-opacity=".6"/><path d="M7 14h4M7 18h3M14 14h3M14 18h4" stroke="#7b61ff" stroke-width="1.8" stroke-linecap="round"/></svg>',
    title: '海外多分支协同 + 钉钉集成',
    desc: '为跨国企业集团搭建全球多节点部署 IM，打通海外分支与国内总部的协同通讯，并深度集成钉钉组织架构。',
    highlights: [
      '全球多区域节点就近接入',
      '钉钉双向同步组织架构与考勤',
      '中英双语与海外推送通道适配',
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

/* ============ PROCESS TIMELINE ============ */
.process-steps {
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  gap: 20px;
  position: relative;
}

.process-step {
  display: flex;
  flex-direction: column;
  align-items: center;
  text-align: center;
  gap: 14px;
  position: relative;
}

.step-top {
  display: flex;
  align-items: center;
  width: 100%;
  position: relative;
  justify-content: center;
  margin-bottom: 6px;
}

.step-circle {
  width: 60px;
  height: 60px;
  border-radius: 50%;
  background: var(--c-gradient);
  box-shadow: 0 8px 20px rgba(22, 93, 255, .3);
  display: inline-flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  position: relative;
  z-index: 1;
}

.step-num {
  font-size: 24px;
  font-weight: 900;
  color: #fff;
  letter-spacing: 0;
}

.step-line {
  position: absolute;
  top: 50%;
  left: calc(50% + 30px);
  width: calc(100% - 60px);
  height: 2px;
  background: repeating-linear-gradient(
    to right,
    var(--c-primary-light) 0 8px,
    transparent 8px 16px
  );
  transform: translateY(-50%);
}

.step-title {
  font-size: 18px;
  font-weight: 800;
  color: var(--c-text-1);
  margin-top: 4px;
}

.step-desc {
  font-size: 13.5px;
  line-height: 1.7;
  color: var(--c-text-2);
  max-width: 200px;
}

/* ============ SCOPE CARDS ============ */
.section-bg-2 {
  background: var(--c-bg-2);
}

.scope-grid {
  align-items: stretch;
}

.scope-card {
  display: flex;
  flex-direction: column;
  gap: 16px;
  padding: 28px;
}

.scope-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 52px;
  height: 52px;
  border-radius: 14px;
  flex-shrink: 0;
  box-shadow: 0 6px 16px rgba(22, 93, 255, .18);
}

.scope-title {
  font-size: 20px;
  font-weight: 800;
  color: var(--c-text-1);
  letter-spacing: -.3px;
}

.scope-list {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding-top: 4px;
  border-top: 1px solid var(--c-border);
  margin-top: 4px;
}

.scope-list li {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  font-size: 14px;
  line-height: 1.6;
  color: var(--c-text-2);
  padding-top: 6px;
}

.scope-dot {
  flex-shrink: 0;
  margin-top: 7px;
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: var(--c-primary);
  opacity: .7;
}

/* ============ DELIVERABLES ============ */
.deliver-grid {
  gap: 20px;
}

.deliver-card {
  display: flex;
  align-items: flex-start;
  gap: 20px;
  padding: 28px;
  border: 1.5px solid var(--c-border-2);
  background: linear-gradient(135deg, #ffffff 0%, #fafcff 100%);
}

.deliver-left {
  flex-shrink: 0;
  width: 64px;
  height: 64px;
  border-radius: 16px;
  background: var(--c-primary-bg);
  display: inline-flex;
  align-items: center;
  justify-content: center;
}

.deliver-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
}

.deliver-content {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.deliver-title {
  font-size: 18px;
  font-weight: 800;
  color: var(--c-text-1);
  letter-spacing: -.2px;
}

.deliver-desc {
  font-size: 14.5px;
  line-height: 1.75;
  color: var(--c-text-2);
}

/* ============ CASES ============ */
.case-grid {
  gap: 24px;
}

.case-card {
  display: flex;
  flex-direction: column;
  gap: 16px;
  padding: 28px;
}

.case-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.case-tag {
  display: inline-block;
  padding: 5px 12px;
  font-size: 12.5px;
  font-weight: 700;
  border-radius: 999px;
}

.case-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 44px;
  height: 44px;
  border-radius: 12px;
}

.case-title {
  font-size: 20px;
  font-weight: 800;
  color: var(--c-text-1);
  letter-spacing: -.3px;
}

.case-desc {
  font-size: 14.5px;
  line-height: 1.75;
  color: var(--c-text-2);
}

.case-highlights {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding-top: 12px;
  border-top: 1px solid var(--c-border);
}

.case-highlights li {
  display: flex;
  align-items: flex-start;
  gap: 10px;
  font-size: 14px;
  line-height: 1.6;
  color: var(--c-text-2);
}

.case-check {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  width: 20px;
  height: 20px;
  border-radius: 50%;
  background: var(--c-primary-bg);
  color: var(--c-primary);
  margin-top: 2px;
}

/* ============ CTA ============ */
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

.cta-tips {
  margin-top: 22px;
  font-size: 14px;
  color: rgba(255, 255, 255, .8);
}

/* ============ RESPONSIVE ============ */
@media (max-width: 1100px) {
  .process-steps { grid-template-columns: repeat(3, 1fr); }
  .process-step:nth-child(n+4) { margin-top: 12px; }
  .step-line { display: none; }
}

@media (max-width: 900px) {
  .hero-title { font-size: 36px; }
  .scope-grid,
  .case-grid { grid-template-columns: 1fr; }
}

@media (max-width: 680px) {
  .process-steps { grid-template-columns: 1fr 1fr; }
  .deliver-card {
    flex-direction: column;
    align-items: flex-start;
    padding: 22px;
  }
  .deliver-left { width: 52px; height: 52px; }
}

@media (max-width: 600px) {
  .hero { padding: 48px 0 56px; }
  .hero-title { font-size: 28px; }
  .hero-subtitle { font-size: 15px; }
  .hero-cta .btn { flex: 1; justify-content: center; }
  .process-steps { grid-template-columns: 1fr; }
  .step-circle { width: 54px; height: 54px; }
  .step-num { font-size: 22px; }
  .cta-title { font-size: 26px; }
  .cta-sub { font-size: 15px; }
  .scope-card,
  .case-card { padding: 22px; }
  .deliver-title { font-size: 17px; }
  .deliver-desc { font-size: 14px; }
}
</style>
