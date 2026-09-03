<template>
  <div class="quote-page">
    <!-- 打印按钮（不打印） -->
    <div class="no-print print-bar">
      <button @click="printPage" class="btn btn-primary btn-lg">
        打印 / 导出 PDF
      </button>
      <NuxtLink to="/contact" class="btn btn-outline btn-lg">联系商务洽谈</NuxtLink>
    </div>

    <div class="quote-doc" id="quote-doc">
      <!-- 抬头 -->
      <header class="quote-header">
        <div class="qh-left">
          <div class="logo-row">
            <svg viewBox="0 0 64 64" width="48" height="48">
              <defs><linearGradient id="qg" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#165dff"/><stop offset="100%" stop-color="#4080ff"/></linearGradient></defs>
              <rect width="64" height="64" rx="14" fill="url(#qg)"/>
              <path d="M20 22h24a4 4 0 0 1 4 4v12a4 4 0 0 1-4 4H30l-8 6v-6h-2a4 4 0 0 1-4-4V26a4 4 0 0 1 4-4z" fill="#fff"/>
            </svg>
            <div>
              <h1>ChatPulse</h1>
              <p>企业级即时通讯系统</p>
            </div>
          </div>
        </div>
        <div class="qh-right">
          <h2>商 务 报 价 单</h2>
          <table class="meta-table">
            <tr><td>报价单号</td><td>CP-2026-001</td></tr>
            <tr><td>报价日期</td><td>{{ today }}</td></tr>
            <tr><td>有效期限</td><td>{{ expiry }}</td></tr>
            <tr><td>报价人</td><td>ChatPulse 商务部</td></tr>
          </table>
        </div>
      </header>

      <div class="quote-divider"></div>

      <!-- 客户信息 -->
      <section class="customer-info">
        <h3>致：尊敬的客户</h3>
        <p>感谢您对 ChatPulse 企业级即时通讯系统的关注。基于贵公司的需求，我们提供以下三档报价方案：部署版（不含源码）、开源版（含完整源码）、定制版（独占授权+定制开发）。</p>
      </section>

      <!-- 套餐对比表 -->
      <section class="plans-section">
        <h3 class="section-heading">一、套餐方案对比</h3>
        <table class="quote-table">
          <thead>
            <tr>
              <th class="col-item">项目</th>
              <th class="col-plan">部署版<br><small>{{ formatPrice(pricing.standard.usdt) }} USDT</small></th>
              <th class="col-plan highlight">开源版（推荐）<br><small>{{ formatPrice(pricing.professional.usdt) }} USDT</small></th>
              <th class="col-plan">定制版<br><small>{{ pricing.enterprise.text || '面议' }}</small></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="row in planRows" :key="row.item">
              <td class="col-item">{{ row.item }}</td>
              <td class="col-plan" :class="{ 'has-value': row.standard }">
                <span v-if="row.standard === true" class="check">✓</span>
                <span v-else-if="row.standard === false" class="cross">—</span>
                <span v-else>{{ row.standard }}</span>
              </td>
              <td class="col-plan highlight-col" :class="{ 'has-value': row.pro }">
                <span v-if="row.pro === true" class="check">✓</span>
                <span v-else-if="row.pro === false" class="cross">—</span>
                <span v-else>{{ row.pro }}</span>
              </td>
              <td class="col-plan" :class="{ 'has-value': row.enterprise }">
                <span v-if="row.enterprise === true" class="check">✓</span>
                <span v-else-if="row.enterprise === false" class="cross">—</span>
                <span v-else>{{ row.enterprise }}</span>
              </td>
            </tr>
          </tbody>
        </table>
      </section>

      <!-- 价格明细 -->
      <section class="price-section">
        <h3 class="section-heading">二、价格明细</h3>
        <table class="quote-table price-table">
          <thead>
            <tr>
              <th>套餐</th>
              <th>授权范围</th>
              <th>包含服务</th>
              <th class="price-col">价格（USDT）</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>部署版</td>
              <td>1 个域名<br>单机部署</td>
              <td>系统部署 + 部署文档 + 3 个月社区支持 + 3 个月免费更新（不含源码）</td>
              <td class="price-col">{{ formatPrice(pricing.standard.usdt) }}</td>
            </tr>
            <tr>
              <td>开源版</td>
              <td>3 个域名<br>集群部署</td>
              <td>完整源码 + 部署文档 + 12 个月优先支持 + 12 个月免费更新</td>
              <td class="price-col">{{ formatPrice(pricing.professional.usdt) }}</td>
            </tr>
            <tr>
              <td>定制版</td>
              <td>不限域名<br>独占授权</td>
              <td>全部开源版 + 定制开发 + SLA 服务保障 + 专属技术团队 + 永久更新 + 部署培训</td>
              <td class="price-col">{{ pricing.enterprise.text || '面议' }}</td>
            </tr>
          </tbody>
        </table>
        <p class="price-note">* 以上价格为 USDT 报价，支持 USDT 支付。人民币参考价请咨询商务客服。<br>* 定制开发费用根据需求复杂度另行评估。</p>
      </section>

      <!-- 功能清单 -->
      <section class="feature-list-section">
        <h3 class="section-heading">三、功能清单</h3>
        <div class="feature-grid">
          <div class="feature-group" v-for="group in featureGroups" :key="group.title">
            <h4>{{ group.title }}</h4>
            <ul>
              <li v-for="item in group.items" :key="item">{{ item }}</li>
            </ul>
          </div>
        </div>
      </section>

      <!-- 服务条款 -->
      <section class="terms-section">
        <h3 class="section-heading">四、服务条款</h3>
        <ol class="terms-list">
          <li><strong>交付方式</strong>：合同签订后 3 个工作日内交付完整源码及技术文档。</li>
          <li><strong>支付方式</strong>：合同签订后支付 50% 预付款，交付验收后支付 50% 尾款。支持银行转账、支付宝、微信支付。</li>
          <li><strong>技术支持</strong>：标准版提供 6 个月社区工单支持；专业版提供 12 个月优先工单支持（工作日 24 小时内响应）；企业定制版提供 SLA 服务保障（7×24 小时电话+工单）。</li>
          <li><strong>更新策略</strong>：免费更新期内享受所有功能更新和 Bug 修复；期满后可选续费更新（标准版 ¥1,500/年，专业版 ¥3,000/年）。</li>
          <li><strong>授权范围</strong>：购买后可自由修改源码用于自有业务，不得转售源码本身。企业定制版可获独占授权。</li>
          <li><strong>退款政策</strong>：源码交付后不支持退款。交付前可全额退款。</li>
          <li><strong>部署环境</strong>：推荐 Linux 服务器（2 核 4G+），需 Docker 环境。提供宝塔面板部署教程。部署环境由客户提供。</li>
          <li><strong>知识产权</strong>：源码著作权归 ChatPulse 团队所有，授权客户使用。客户定制部分知识产权可另行约定。</li>
        </ol>
      </section>

      <!-- 联系方式 -->
      <section class="contact-section">
        <h3 class="section-heading">五、联系方式</h3>
        <div class="contact-grid">
          <div class="contact-item">
            <span class="ci-label">Telegram 客服</span>
            <a class="ci-value ci-link" :href="telegramUrl" target="_blank">{{ contactTelegram || '@ChatPulse_BD' }}</a>
          </div>
          <div v-if="contactEmail" class="contact-item">
            <span class="ci-label">邮箱</span>
            <span class="ci-value">{{ contactEmail }}</span>
          </div>
          <div v-if="contactPhone" class="contact-item">
            <span class="ci-label">电话</span>
            <span class="ci-value">{{ contactPhone }}</span>
          </div>
          <div v-if="contactQq" class="contact-item">
            <span class="ci-label">QQ</span>
            <span class="ci-value">{{ contactQq }}</span>
          </div>
        </div>
      </section>

      <!-- 签章 -->
      <section class="sign-section">
        <div class="sign-block">
          <p class="sign-title">供方（盖章）</p>
          <p class="sign-name">ChatPulse 团队</p>
          <p class="sign-date">日期：_________</p>
        </div>
        <div class="sign-block">
          <p class="sign-title">需方（盖章）</p>
          <p class="sign-name">&nbsp;</p>
          <p class="sign-date">日期：_________</p>
        </div>
      </section>

      <div class="quote-footer">
        <p>本报价单最终解释权归 ChatPulse 团队所有。报价有效期 30 天，逾期需重新询价。</p>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'

useHead({
  title: '报价单 - 企业级 IM 系统方案',
  description: 'ChatPulse 企业级即时通讯系统报价单 - 面向中小企业客户，三档套餐：部署版、开源版、定制版，支持 USDT 支付。',
  keywords: 'IM系统报价,即时通讯报价,企业通讯系统价格,ChatPulse报价单,源码出售价格,USDT支付',
})

const today = new Date().toLocaleDateString('zh-CN', { year: 'numeric', month: 'long', day: 'numeric' })
const expiryDate = new Date()
expiryDate.setDate(expiryDate.getDate() + 30)
const expiry = expiryDate.toLocaleDateString('zh-CN', { year: 'numeric', month: 'long', day: 'numeric' })

const defaultPricing = {
  period: '终身授权',
  standard:    { usdt: 699,  note: '不含源码，快速部署' },
  professional:{ usdt: 1399, note: '含完整源码，二次开发' },
  enterprise:  { text: '面议', note: '独占授权 + 定制开发' },
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
const contactTelegram = computed(() => scData.value?.data?.contactTelegram || '')
const contactEmail = computed(() => scData.value?.data?.contactEmail || '')
const contactPhone = computed(() => scData.value?.data?.contactPhone || '')
const contactQq = computed(() => scData.value?.data?.contactQq || '')
const telegramUrl = computed(() => {
  const tg = contactTelegram.value || '@ChatPulse_BD'
  return `https://t.me/${tg.replace(/^@/, '')}`
})

function formatPrice(val: number | string) {
  const n = Number(val)
  if (!isFinite(n) || n <= 0) return '面议'
  return new Intl.NumberFormat('en-US').format(n)
}

const planRows = [
  { item: '完整后端源码 (Go)', standard: false, pro: true, enterprise: true },
  { item: '完整前端源码 (Vue3)', standard: false, pro: true, enterprise: true },
  { item: '完整移动端源码 (Flutter)', standard: false, pro: true, enterprise: true },
  { item: '单聊 / 群聊', standard: true, pro: true, enterprise: true },
  { item: '朋友圈 / 动态', standard: true, pro: true, enterprise: true },
  { item: '消息撤回 / 转发 / 收藏', standard: true, pro: true, enterprise: true },
  { item: '文件 / 图片 / 语音消息', standard: true, pro: true, enterprise: true },
  { item: '管理后台 (Vue)', standard: true, pro: true, enterprise: true },
  { item: '用户管理 / 群组管理', standard: true, pro: true, enterprise: true },
  { item: '音视频通话 (TRTC)', standard: true, pro: true, enterprise: true },
  { item: '红包 / 转账 / 钱包', standard: true, pro: true, enterprise: true },
  { item: '充值 / 提现 / 支付配置', standard: true, pro: true, enterprise: true },
  { item: '靓号系统', standard: true, pro: true, enterprise: true },
  { item: '智能助手', standard: true, pro: true, enterprise: true },
  { item: '消息审计 / 日志', standard: true, pro: true, enterprise: true },
  { item: '财务统计 / 数据看板', standard: true, pro: true, enterprise: true },
  { item: '集群部署支持', standard: false, pro: false, enterprise: true },
  { item: '定制开发', standard: false, pro: false, enterprise: true },
  { item: '独占授权', standard: false, pro: false, enterprise: true },
  { item: 'SLA 服务保障', standard: false, pro: false, enterprise: true },
  { item: '域名授权数', standard: '1 个', pro: '3 个', enterprise: '不限' },
  { item: '免费更新期', standard: '3 个月', pro: '12 个月', enterprise: '永久' },
  { item: '技术支持', standard: '社区工单', pro: '优先工单', enterprise: '7×24 电话' },
  { item: '部署协助', standard: '文档', pro: '远程协助', enterprise: '现场培训' },
  { item: '源码交付', standard: '不含源码', pro: '全量交付', enterprise: '全量交付' },
]

const featureGroups = [
  {
    title: '即时通讯核心',
    items: ['单聊（文字/图片/语音/表情/文件）', '群聊（500人，@提及）', '消息撤回/转发/收藏', '消息已读回执', '在线状态/输入指示']
  },
  {
    title: '音视频通话',
    items: ['一对一语音通话', '一对一视频通话', '多人音视频会议', 'TRTC 底层支持']
  },
  {
    title: '钱包与支付',
    items: ['零钱余额管理', '红包（拼手气/普通）', '转账功能', '充值（收款码上传）', '提现（多渠道绑定）', '后台支付配置']
  },
  {
    title: '社交功能',
    items: ['朋友圈（图文/视频）', '点赞 / 评论', '靓号系统（批量生成/分配/冻结）', '智能助手（自动添加/群发/回复）']
  },
  {
    title: '管理后台',
    items: ['用户管理（增删改查/充值）', '群组管理', '消息审计', '系统配置', '财务统计 / 数据看板', '操作日志']
  },
  {
    title: '技术架构',
    items: ['后端：Go + Gin + GORM', '数据库：MySQL + Redis + MongoDB', '文件存储：MinIO', '前端：Vue3 + Arco Design', '移动端：Flutter（iOS + Android）', '容器化：Docker + Docker Compose']
  },
]

function printPage() {
  window.print()
}
</script>

<style scoped>
/* 不打印的元素 */
@media print {
  .no-print { display: none !important; }
  body { background: #fff !important; }
}

.quote-page {
  max-width: 900px;
  margin: 0 auto;
  padding: 40px 24px 80px;
}

.print-bar {
  display: flex;
  gap: 12px;
  justify-content: center;
  margin-bottom: 32px;
}

.quote-doc {
  background: #fff;
  padding: 48px;
  border: 1px solid #e5e6eb;
  border-radius: 8px;
  box-shadow: 0 2px 16px rgba(0,0,0,.06);
}

/* 抬头 */
.quote-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 24px;
}
.qh-left .logo-row {
  display: flex;
  align-items: center;
  gap: 14px;
}
.qh-left h1 {
  font-size: 26px;
  font-weight: 800;
  color: #1d2129;
  background: linear-gradient(135deg, #165dff, #4080ff);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
}
.qh-left p {
  font-size: 13px;
  color: #86909c;
  margin-top: 2px;
}
.qh-right {
  text-align: right;
}
.qh-right h2 {
  font-size: 22px;
  font-weight: 700;
  color: #1d2129;
  letter-spacing: 4px;
  margin-bottom: 10px;
}
.meta-table {
  font-size: 13px;
  color: #4e5969;
  border-collapse: collapse;
}
.meta-table td {
  padding: 3px 8px;
  border-bottom: 1px solid #f2f3f5;
}
.meta-table td:first-child {
  color: #86909c;
  white-space: nowrap;
}
.meta-table td:last-child {
  font-weight: 500;
}

.quote-divider {
  height: 3px;
  background: linear-gradient(90deg, #165dff, #4080ff);
  margin: 28px 0;
}

/* 客户信息 */
.customer-info h3 {
  font-size: 16px;
  font-weight: 600;
  color: #1d2129;
  margin-bottom: 8px;
}
.customer-info p {
  font-size: 14px;
  color: #4e5969;
  line-height: 1.8;
}

/* 章节标题 */
.section-heading {
  font-size: 17px;
  font-weight: 700;
  color: #1d2129;
  margin: 32px 0 16px;
  padding-left: 12px;
  border-left: 4px solid #165dff;
}

/* 报价表格 */
.quote-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;
}
.quote-table th {
  background: #f7f8fa;
  color: #1d2129;
  font-weight: 600;
  padding: 10px 8px;
  text-align: center;
  border: 1px solid #e5e6eb;
}
.quote-table th small {
  font-size: 12px;
  color: #165dff;
  font-weight: 700;
}
.quote-table th.highlight {
  background: #e8f3ff;
}
.quote-table td {
  padding: 8px;
  text-align: center;
  border: 1px solid #e5e6eb;
  color: #4e5969;
}
.quote-table .col-item {
  text-align: left;
  font-weight: 500;
  color: #1d2129;
  background: #fafbfc;
}
.quote-table .col-plan {
  font-size: 14px;
}
.quote-table .highlight-col {
  background: #f0f7ff;
}
.check {
  color: #00b42a;
  font-size: 16px;
  font-weight: 700;
}
.cross {
  color: #c9cdd4;
}
.price-col {
  font-weight: 700;
  color: #165dff;
  font-size: 15px !important;
}
.price-note {
  font-size: 12px;
  color: #86909c;
  margin-top: 8px;
  line-height: 1.8;
}

/* 功能清单 */
.feature-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 20px;
}
.feature-group h4 {
  font-size: 14px;
  font-weight: 600;
  color: #1d2129;
  margin-bottom: 8px;
}
.feature-group ul {
  list-style: none;
  padding: 0;
}
.feature-group li {
  font-size: 13px;
  color: #4e5969;
  padding: 3px 0;
  padding-left: 18px;
  position: relative;
}
.feature-group li::before {
  content: '✓';
  position: absolute;
  left: 0;
  color: #00b42a;
  font-weight: 700;
}

/* 服务条款 */
.terms-list {
  padding-left: 20px;
  font-size: 13px;
  color: #4e5969;
  line-height: 2;
}
.terms-list li {
  margin-bottom: 6px;
}
.terms-list strong {
  color: #1d2129;
}

/* 联系方式 */
.contact-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
}
.contact-item {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 10px 14px;
  background: #f7f8fa;
  border-radius: 6px;
}
.ci-label {
  font-size: 13px;
  color: #86909c;
  flex-shrink: 0;
}
.ci-value {
  font-size: 14px;
  color: #1d2129;
  font-weight: 500;
}
.ci-link {
  color: #165dff;
  text-decoration: none;
}
.ci-link:hover {
  text-decoration: underline;
}

/* 签章 */
.sign-section {
  display: flex;
  justify-content: space-between;
  margin-top: 48px;
  gap: 24px;
}
.sign-block {
  flex: 1;
  text-align: center;
  padding: 24px;
  border: 1px dashed #c9cdd4;
  border-radius: 8px;
}
.sign-title {
  font-size: 14px;
  color: #86909c;
  margin-bottom: 32px;
}
.sign-name {
  font-size: 15px;
  font-weight: 600;
  color: #1d2129;
  min-height: 24px;
}
.sign-date {
  font-size: 13px;
  color: #86909c;
  margin-top: 12px;
}

.quote-footer {
  margin-top: 32px;
  text-align: center;
  font-size: 12px;
  color: #86909c;
  padding-top: 16px;
  border-top: 1px solid #f2f3f5;
}

/* 打印优化 */
@media print {
  .quote-page { padding: 0; max-width: none; }
  .quote-doc { box-shadow: none; border: none; padding: 24px; }
  .quote-table th { background: #f7f8fa !important; -webkit-print-color-adjust: exact; }
  .highlight-col { background: #f0f7ff !important; -webkit-print-color-adjust: exact; }
}

/* 响应式 */
@media (max-width: 768px) {
  .quote-doc { padding: 24px 16px; }
  .quote-header { flex-direction: column; }
  .qh-right { text-align: left; }
  .feature-grid { grid-template-columns: 1fr; }
  .contact-grid { grid-template-columns: 1fr; }
  .sign-section { flex-direction: column; }
  .quote-table { font-size: 12px; }
}
</style>
