<template>
  <div class="privacy-page">
    <!-- ============ HERO ============ -->
    <section class="hero">
      <div class="hero-bg-deco" aria-hidden="true">
        <span class="orb orb-1"></span>
        <span class="orb orb-2"></span>
      </div>
      <div class="container hero-inner">
        <span class="hero-badge">用户隐私至上</span>
        <h1 class="hero-title">ChatPulse 隐私政策</h1>
        <p class="hero-subtitle">最后更新：2026年9月2日</p>
      </div>
    </section>

    <!-- ============ POLICY SECTIONS ============ -->
    <section class="section">
      <div class="container policy-wrap">

        <div
          v-for="(item, index) in sections"
          :key="item.id"
          class="card policy-card fade-in-up"
          :style="{ animationDelay: (index * .06) + 's' }"
        >
          <div class="card-accent" aria-hidden="true"></div>
          <h3 class="card-title">
            <span class="card-num">{{ String(index + 1).padStart(2, '0') }}</span>
            {{ item.title }}
          </h3>
          <div class="card-body" v-html="item.body"></div>
        </div>

      </div>
    </section>

    <!-- ============ CONSENT BANNER ============ -->
    <section class="consent-section">
      <div class="container consent-wrap fade-in-up">
        <div class="consent-icon" aria-hidden="true">
          <svg width="28" height="28" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
            <path d="M12 2l8 4v6c0 5-3.5 9-8 10-4.5-1-8-5-8-10V6l8-4z" fill="#fff" fill-opacity=".9"/>
            <path d="M9 12l2 2 4-4" stroke="#165dff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>
          </svg>
        </div>
        <p class="consent-text">
          继续使用 ChatPulse 服务表示您已阅读并同意本政策。如您对本政策有任何疑问，可随时通过
          <NuxtLink to="/contact" class="consent-link">客服渠道</NuxtLink>
          与我们联系。
        </p>
      </div>
    </section>
  </div>
</template>

<script setup lang="ts">
useHead({
  title: '隐私政策 - ChatPulse 企业级 IM',
  meta: [
    {
      name: 'description',
      content:
        'ChatPulse 隐私政策：我们如何收集、使用、存储与保护您的个人信息，包括注册账号、设备信息、日志信息、钱包交易信息，以及您在信息查询、更正、删除、撤回同意、注销账户等方面的权利。',
    },
    {
      name: 'keywords',
      content:
        'ChatPulse 隐私政策,个人信息保护,用户数据保护,隐私声明,GDPR合规,数据安全,用户权利,信息存储,Cookie政策,未成年人保护',
    },
  ],
})

const sections = [
  {
    id: 'intro',
    title: '引言',
    body: `
      <p>ChatPulse 非常重视您的个人信息与隐私保护。本隐私政策旨在向您说明，在您使用 ChatPulse 即时通讯产品及相关服务（以下简称"本服务"）的过程中，我们会如何收集、使用、存储、共享与保护您的个人信息，以及您所享有的相关权利。</p>
      <p>本政策适用于 ChatPulse 官方提供的全部客户端应用、管理后台、网页端与服务端接口。请您在使用本服务前，务必仔细阅读并充分理解本政策的全部内容。您一旦开始使用 ChatPulse 服务，即视为您已同意本政策的全部条款。</p>
    `,
  },
  {
    id: 'collect',
    title: '我们收集的信息',
    body: `
      <p>为向您提供稳定、安全、个性化的 IM 服务，我们仅在必要范围内收集以下类别的信息：</p>
      <ul>
        <li><strong>注册账号信息：</strong>当您注册 ChatPulse 账号时，我们会收集您的手机号（用于身份验证与登录）、昵称、头像与个人简介等资料，以便建立您的用户档案并支持其他用户搜索添加。</li>
        <li><strong>设备信息：</strong>为保证多端消息同步与兼容性，我们会收集您使用的设备机型、操作系统版本、设备唯一标识（如 IMEI / IDFA / Android ID）、屏幕分辨率与网络类型等信息。</li>
        <li><strong>日志信息：</strong>当您访问或使用本服务时，我们会自动记录您的 IP 地址、登录时间、访问页面、操作行为、崩溃日志与异常退出信息，用于服务稳定性分析与账户安全风控。</li>
        <li><strong>钱包与交易信息：</strong>如您使用红包、转账、充值或提现等钱包功能，我们会收集您的交易金额、交易时间、交易对手、支付通道订单号与余额变动记录，以保障资金安全并满足合规审计要求。</li>
      </ul>
    `,
  },
  {
    id: 'usage',
    title: '信息使用目的',
    body: `
      <p>我们将所收集的信息严格用于以下合法、正当且必要的目的：</p>
      <ul>
        <li><strong>提供 IM 服务：</strong>用于完成消息收发、群聊管理、音视频通话、好友关系维护、文件传输、朋友圈动态等核心通讯功能。</li>
        <li><strong>账户安全：</strong>通过登录地点、设备指纹与异常行为检测，识别并拦截盗号、刷单、群发骚扰等风险操作，保障您的账号与财产安全。</li>
        <li><strong>客服支持：</strong>当您通过客服渠道提交工单或反馈问题时，我们会使用您的账号信息与操作日志快速定位问题并提供解答。</li>
        <li><strong>产品改进：</strong>基于匿名化或聚合后的使用数据进行统计分析，用于优化界面体验、修复缺陷、规划新功能迭代。</li>
        <li><strong>合规要求：</strong>在法律法规规定的范围内，留存必要的登录日志、交易记录与消息元数据，以配合监管检查与司法取证。</li>
      </ul>
    `,
  },
  {
    id: 'share',
    title: '信息共享披露',
    body: `
      <p>ChatPulse 不会向任何第三方出售您的个人信息。仅在以下三种情形下，我们可能会共享或披露您的相关信息：</p>
      <ul>
        <li><strong>征得您的同意：</strong>在您明确授权或主动选择的情况下，例如将信息同步至您指定的第三方应用或服务，我们会按您的指示进行共享。</li>
        <li><strong>执法机关合法要求：</strong>当有权机关依照法定程序提出要求时，我们会在法律法规允许的范围内，提供必要的信息以配合行政执法、刑事侦查或司法审判。</li>
        <li><strong>合并、收购或资产转让：</strong>如 ChatPulse 发生合并、分立、收购、资产或业务重组等情形，您的个人信息可能会随同相关业务一并转让给受让方，我们会要求受让方继续受本政策约束，否则将重新征求您的同意。</li>
      </ul>
    `,
  },
  {
    id: 'security',
    title: '信息存储安全',
    body: `
      <p>我们采取业界通行的多层安全措施来保护您的个人信息：</p>
      <ul>
        <li><strong>传输加密：</strong>客户端与服务端之间的通信全部采用 TLS 1.2 及以上版本加密传输，防止数据在传输过程中被窃取或篡改。</li>
        <li><strong>存储加密：</strong>敏感信息（如密码、身份证号、银行卡号）采用加盐哈希或 AES-256 加密后存储，数据库层与文件层均配置访问控制。</li>
        <li><strong>最小权限访问：</strong>内部仅授权特定岗位员工在必要范围内访问用户信息，所有访问操作均会被审计记录。</li>
        <li><strong>保存期限：</strong>我们仅在实现使用目的所必需的最短期限内保存您的个人信息。超出保存期限后，我们将对信息进行匿名化处理或依法予以销毁，但法律法规另有规定的除外。</li>
      </ul>
    `,
  },
  {
    id: 'rights',
    title: '您的权利',
    body: `
      <p>您对自己的个人信息享有完整的控制权，具体包括以下权利：</p>
      <ul>
        <li><strong>查询权：</strong>您可随时在个人中心查看自己的账号资料、登录设备、钱包流水与隐私设置。</li>
        <li><strong>更正权：</strong>当您的资料发生变更或存在错误时，可在个人中心自助修改昵称、头像、签名、绑定手机号等信息。</li>
        <li><strong>删除权：</strong>在符合法律法规的前提下，您有权请求删除您的个人信息。您可通过客服渠道提交删除申请，我们将在 15 日内处理。</li>
        <li><strong>撤回同意：</strong>您可在系统设置中关闭位置、相册、麦克风、通知等权限，或撤回此前作出的同意；但这可能影响部分功能的正常使用。</li>
        <li><strong>注销账户：</strong>您可在"设置 - 账号安全 - 注销账号"中自助申请注销，或联系人工客服协助。账户注销后，除法律要求必须留存的记录外，相关信息将在 30 日内被清除或匿名化。</li>
      </ul>
    `,
  },
  {
    id: 'cookie',
    title: 'Cookie 与同类技术',
    body: `
      <p>ChatPulse 官网、管理后台与 H5 页面会使用 Cookie 及类似的本地存储技术（如 LocalStorage、SessionStorage），用于以下目的：</p>
      <ul>
        <li><strong>会话保持：</strong>维持您的登录状态，避免您在浏览多个页面时重复登录。</li>
        <li><strong>登录态记录：</strong>记住您的账号偏好，简化下次登录流程。</li>
        <li><strong>分析用途：</strong>通过匿名化的访问统计，了解页面流量与功能使用情况，以便持续优化产品体验。</li>
      </ul>
      <p>您可通过浏览器的隐私设置清除或拒绝 Cookie，但这可能导致部分功能无法正常使用。移动端 APP 中，我们也会使用类似的设备标识与 SDK 能力，您可在系统权限管理中随时关闭。</p>
    `,
  },
  {
    id: 'minor',
    title: '未成年人保护',
    body: `
      <p>ChatPulse 非常重视未成年人的个人信息保护。若您未满 18 周岁，请在监护人的陪同下仔细阅读本政策，并在取得监护人明确同意后再使用本服务。</p>
      <p>我们不会主动收集未成年人的个人信息，也不会向未成年人推送与其年龄不相符的商业内容。如我们发现在未获得监护人同意的情况下收集了未成年人的信息，将尽快采取删除或匿名化措施。监护人如发现其监护的未成年人未经同意注册或使用本服务，可通过客服渠道联系我们，我们将协助处理相关账号与信息。</p>
    `,
  },
  {
    id: 'thirdparty',
    title: '第三方服务',
    body: `
      <p>为向您提供完整的 IM 能力，ChatPulse 集成了以下第三方服务组件。这些组件由其对应主体独立运营，并受各自隐私政策约束，我们建议您一并查阅：</p>
      <ul>
        <li><strong>音视频服务（TRTC）：</strong>由腾讯云提供实时音视频通话能力，涉及通话信令与媒体流处理，详见《腾讯云隐私政策》。</li>
        <li><strong>消息推送（JPush）：</strong>由极光提供离线消息推送服务，可能收集设备标识与网络信息，详见《极光隐私政策》。</li>
        <li><strong>对象存储（MinIO）：</strong>用于聊天图片、文件、语音等资源的存储，客户可选择私有化部署，存储位置完全由客户控制。</li>
        <li><strong>支付通道：</strong>充值提现等交易功能会对接支付宝、微信支付、银联及其他第三方支付渠道，相关支付信息直接由对应支付机构采集与处理。</li>
      </ul>
    `,
  },
  {
    id: 'update',
    title: '政策更新',
    body: `
      <p>为适应法律法规变化与产品功能迭代，本隐私政策可能会不定期进行更新。</p>
      <p>当政策发生重大变更（例如信息收集目的变化、共享主体变更、您的权利范围变化等），我们会通过官网公告、站内信或客户端弹窗等方式向您告知，并在必要时重新征求您的同意。对于非重大的文字调整或补充说明，更新版本将自发布之日起生效。</p>
      <p>建议您定期查阅本页面，以了解最新版本的隐私政策。本政策顶部"最后更新"日期即为最近一次修订日期。</p>
    `,
  },
  {
    id: 'contact',
    title: '联系我们',
    body: `
      <p>如您对本隐私政策有任何疑问、意见或建议，或希望行使您的相关权利（查询、更正、删除、撤回同意、注销账户等），均可通过以下方式与我们联系：</p>
      <ul>
        <li><strong>Telegram 客服：</strong>您可通过官网 <NuxtLink to="/contact" class="text-link">联系我们</NuxtLink> 页面中的 Telegram 入口与在线客服取得联系。</li>
        <li><strong>响应时效：</strong>我们承诺在收到您的请求后 15 个工作日内完成身份核验并给出响应处理结果。若情况复杂或需额外核实，处理时间可能相应延长，我们会及时向您说明原因。</li>
      </ul>
      <p>感谢您对 ChatPulse 的信任。我们将一如既往地把用户隐私保护放在最高优先级，与您共同守护数据安全。</p>
    `,
  },
]
</script>

<style scoped>
/* ============ HERO ============ */
.hero {
  position: relative;
  background: linear-gradient(135deg, #1e4fc4 0%, #4a8bff 100%);
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
  opacity: .3;
}

.orb-1 { width: 320px; height: 320px; background: #6ea8ff; top: -100px; right: -60px; }
.orb-2 { width: 260px; height: 260px; background: #0e3aa8; bottom: -100px; left: -80px; opacity: .45; }

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
  margin-bottom: 14px;
}

.hero-subtitle {
  font-size: 16px;
  color: rgba(255, 255, 255, .85);
  font-weight: 400;
}

/* ============ POLICY WRAP ============ */
.policy-wrap {
  display: flex;
  flex-direction: column;
  gap: 24px;
  max-width: 880px;
}

.policy-card {
  position: relative;
  background: var(--c-bg-2);
  border: 1px solid var(--c-border);
  padding: 28px 28px 28px 36px;
  overflow: hidden;
}

.card-accent {
  position: absolute;
  top: 0;
  left: 0;
  width: 4px;
  height: 100%;
  background: var(--c-gradient);
  border-top-left-radius: 14px;
}

.card-title {
  display: flex;
  align-items: center;
  gap: 14px;
  font-size: 22px;
  font-weight: 800;
  color: var(--c-text-1);
  margin-bottom: 16px;
  letter-spacing: -.3px;
}

.card-num {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 40px;
  height: 28px;
  padding: 0 10px;
  font-size: 13px;
  font-weight: 800;
  color: var(--c-primary);
  background: var(--c-primary-bg);
  border-radius: 6px;
  font-family: 'JetBrains Mono', Menlo, Consolas, monospace;
  letter-spacing: 0;
}

.card-body :deep(p) {
  font-size: 15px;
  line-height: 1.85;
  color: var(--c-text-2);
  margin-bottom: 14px;
}

.card-body :deep(p:last-child) {
  margin-bottom: 0;
}

.card-body :deep(ul) {
  list-style: none;
  padding: 0;
  margin: 0 0 8px;
}

.card-body :deep(ul li) {
  position: relative;
  padding-left: 20px;
  margin-bottom: 12px;
  font-size: 15px;
  line-height: 1.8;
  color: var(--c-text-2);
}

.card-body :deep(ul li::before) {
  content: '';
  position: absolute;
  top: 12px;
  left: 4px;
  width: 6px;
  height: 6px;
  background: var(--c-primary);
  border-radius: 50%;
  opacity: .85;
}

.card-body :deep(strong) {
  color: var(--c-text-1);
  font-weight: 700;
}

.text-link {
  color: var(--c-primary);
  font-weight: 600;
  text-decoration: none;
}

.text-link:hover {
  text-decoration: underline;
}

/* ============ CONSENT BANNER ============ */
.consent-section {
  padding: 48px 0 80px;
}

.consent-wrap {
  display: flex;
  align-items: center;
  gap: 20px;
  padding: 28px 32px;
  background: linear-gradient(135deg, #eaf2ff 0%, #ffffff 100%);
  border: 1px solid #cde0ff;
  border-radius: 14px;
  box-shadow: 0 4px 16px rgba(22, 93, 255, .08);
  max-width: 880px;
  margin: 0 auto;
}

.consent-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  width: 56px;
  height: 56px;
  border-radius: 14px;
  background: var(--c-gradient);
  box-shadow: 0 6px 16px rgba(22, 93, 255, .3);
}

.consent-text {
  flex: 1;
  font-size: 15px;
  line-height: 1.75;
  color: var(--c-text-2);
}

.consent-link {
  font-weight: 700;
  color: var(--c-primary);
  text-decoration: none;
  white-space: nowrap;
}

.consent-link:hover {
  text-decoration: underline;
}

/* ============ RESPONSIVE ============ */
@media (max-width: 900px) {
  .hero-title { font-size: 36px; }
  .card-title { font-size: 20px; }
}

@media (max-width: 600px) {
  .hero { padding: 48px 0 56px; }
  .hero-title { font-size: 28px; }
  .hero-subtitle { font-size: 15px; }
  .policy-card { padding: 22px 20px 22px 26px; }
  .card-title {
    font-size: 18px;
    gap: 10px;
    flex-wrap: wrap;
  }
  .card-num {
    min-width: 34px;
    height: 24px;
    font-size: 12px;
  }
  .card-body :deep(p),
  .card-body :deep(ul li) { font-size: 14px; }
  .consent-wrap {
    flex-direction: column;
    align-items: flex-start;
    padding: 22px 20px;
    gap: 14px;
  }
  .consent-icon {
    width: 48px;
    height: 48px;
  }
  .consent-text { font-size: 14px; }
}
</style>
