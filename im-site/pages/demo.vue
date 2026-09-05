<template>
  <div class="demo-page">
    <!-- 进入演示页时的客服弹窗 -->
    <Teleport to="body">
      <transition name="modal-fade">
        <div v-if="showModal" class="demo-modal-mask" @click.self="showModal = false">
          <div class="demo-modal">
            <button class="demo-close" @click="showModal = false" aria-label="关闭">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
            </button>
            <div class="demo-badge">专属体验通道</div>
            <h2 class="demo-title">欢迎来到演示中心</h2>
            <p class="demo-desc">
              为了让您更全面地了解真实的 ChatPulse，我们会为您开通完整的演示账号与专属 H5 链接。
              请添加 Telegram 商务客服，秒内获取最新演示账号、APP 下载与完整体验入口。
            </p>
            <div class="demo-telegram-card">
              <div class="tg-icon">
                <svg viewBox="0 0 48 48" width="32" height="32"><defs><linearGradient id="tglogo" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#4080ff"/><stop offset="100%" stop-color="#165dff"/></linearGradient></defs><circle cx="24" cy="24" r="24" fill="url(#tglogo)"/><path d="M20 34c-1.2 0-1.1-.5-1.6-1.8l-3.7-12.3c-.4-1.3.5-2 1.6-2.3l26.4-10.2c1.4-.5 2.9 0 2.9 1.9 0 .3-.1.6-.2.9L38.5 27c-.2 1-.9 1.3-1.9 1l-7.6-2.6-3.7 7.6c-.6 1-1.1 1.3-2.3 1.3z" fill="#fff"/></svg>
              </div>
              <div>
                <p class="tg-label">Telegram 商务客服</p>
                <p class="tg-user">{{ contactTelegram || '@ChatPulse_BD' }}</p>
              </div>
              <a :href="`https://t.me/${(contactTelegram || '@ChatPulse_BD').replace(/^@/, '')}`" target="_blank" class="btn btn-primary btn-sm">立即沟通</a>
            </div>
            <p class="demo-hint">客服响应时间：工作日 1 小时内</p>
            <div class="demo-actions">
              <button class="btn btn-outline" @click="showModal = false">我先自行浏览</button>
            </div>
          </div>
        </div>
      </transition>
    </Teleport>

    <!-- iOS 下载说明弹窗 -->
    <Teleport to="body">
      <transition name="modal-fade">
        <div v-if="showIosTipModal" class="demo-modal-mask" @click.self="showIosTipModal = false">
          <div class="demo-modal">
            <button class="demo-close" @click="showIosTipModal = false" aria-label="关闭">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
            </button>
            <div class="demo-badge" style="background:linear-gradient(135deg,#fff7e6,#fff2b8);color:#d48806">iOS 下载说明</div>
            <h2 class="demo-title">关于 iOS 下载</h2>
            <p class="demo-desc">
              由于苹果系统限制，IPA 安装包无法像 Android APK 一样直接安装到手机上。<br/>
              {{ iosSelfSignGuide || '下载的 IPA 文件需要自行签名测试' }}。
            </p>
            <div class="demo-actions" style="flex-direction:column;gap:10px">
                <a v-if="iosDownloadUrl" :href="iosDownloadUrl" target="_blank" class="btn btn-primary" style="justify-content:center">
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none"><path d="M12 4v12M6 10l6 6 6-6" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
                  下载 IPA 文件
                </a>
                <a :href="`https://t.me/${(contactTelegram || '@ChatPulse_BD').replace(/^@/, '')}`" target="_blank" class="btn btn-outline" style="justify-content:center">
                  <svg width="16" height="16" viewBox="0 0 48 48" fill="none"><circle cx="24" cy="24" r="24" fill="#165dff"/><path d="M20 34c-1.2 0-1.1-.5-1.6-1.8l-3.7-12.3c-.4-1.3.5-2 1.6-2.3l26.4-10.2c1.4-.5 2.9 0 2.9 1.9 0 .3-.1.6-.2.9L38.5 27c-.2 1-.9 1.3-1.9 1l-7.6-2.6-3.7 7.6c-.6 1-1.1 1.3-2.3 1.3z" fill="#fff"/></svg>
                  联系客服
                </a>
              </div>
          </div>
        </div>
      </transition>
    </Teleport>

    <!-- ============ HERO ============ -->
    <section class="hero">
      <div class="hero-bg-deco" aria-hidden="true">
        <span class="orb orb-1"></span>
        <span class="orb orb-2"></span>
      </div>
      <div class="container hero-inner">
        <span class="hero-badge">在线 Demo 体验中心</span>
        <h1 class="hero-title">在线体验 ChatPulse</h1>
        <p class="hero-subtitle">扫码或点击进入，体验完整的即时通讯功能</p>
        <div class="hero-cta">
          <a href="#demo-entry" class="btn btn-primary btn-lg">立即体验</a>
          <NuxtLink to="/features" class="btn btn-outline btn-lg hero-outline">查看功能</NuxtLink>
        </div>
      </div>
    </section>

    <!-- ============ DEMO ENTRY ============ -->
    <section id="demo-entry" class="section">
      <div class="container">
        <h2 class="section-title fade-in-up">多种方式进入体验</h2>
        <p class="section-subtitle fade-in-up">移动端扫码下载、Web 端直接体验，选择您最方便的方式</p>

        <div class="grid-2 demo-grid">
          <!-- LEFT: QR CODE -->
          <div class="card qr-card fade-in-up">
            <div class="qr-box">
              <canvas ref="demoQrCanvas" class="qr-canvas"></canvas>
              <div v-if="!qrReady" class="qr-placeholder">
                <svg width="40" height="40" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                  <rect x="5" y="2" width="14" height="28" rx="3" fill="#fff"/>
                  <rect x="6.5" y="3.5" width="11" height="22" rx="1.5" fill="#165dff" opacity=".12"/>
                  <circle cx="12" cy="20" r="1.4" fill="#165dff"/>
                  <path d="M9 7h6M9 10h6M9 13h4" stroke="#165dff" stroke-width="1.4" stroke-linecap="round"/>
                </svg>
              </div>
            </div>
            <h3 class="qr-title">扫描二维码下载体验</h3>
            <p class="qr-sub">使用手机相机或微信扫一扫，即可跳转下载页面</p>
            <NuxtLink to="/download" class="btn btn-outline btn-sm qr-direct-link">
              或直接进入下载页
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none"><path d="M5 12h14M13 6l6 6-6 6" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
            </NuxtLink>
            <div class="qr-platforms">
              <span class="platform-tag">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none"><path d="M17 8h2a3 3 0 0 1 0 6h-2V8zM5 7h9v10H5a2 2 0 0 1-2-2V9a2 2 0 0 1 2-2zM2 12h1M14 8l3-2M14 16l3 2" stroke="#00b42a" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>
                Android
              </span>
              <span class="platform-tag ios">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none"><path d="M17 4c-1.2 0-2.4.6-3.1 1.4-.7.8-1.3 1.8-1.1 2.9 1.2 0 2.3-.7 3-1.5.7-.9 1.1-1.8 1.2-2.8z" fill="#00b42a"/></svg>
                iOS 支持（自签名）
              </span>
            </div>
            <p class="qr-support">扫码进入下载页 · Android 下载 / iOS 自签名安装指南</p>
          </div>

          <!-- RIGHT: WEB DEMO -->
          <div class="card web-card fade-in-up">
            <div class="web-preview" aria-hidden="true">
              <div class="preview-bar">
                <span class="dot r"></span>
                <span class="dot y"></span>
                <span class="dot g"></span>
                <span class="preview-url">admin.chatpulse.demo</span>
              </div>
              <div class="preview-body">
                <div class="preview-sidebar">
                  <span class="side-item active"></span>
                  <span class="side-item"></span>
                  <span class="side-item"></span>
                  <span class="side-item"></span>
                </div>
                <div class="preview-main">
                  <div class="preview-stats">
                    <span class="ps-item"><i></i><b>用户</b></span>
                    <span class="ps-item"><i></i><b>群组</b></span>
                    <span class="ps-item"><i></i><b>消息</b></span>
                  </div>
                  <div class="preview-chart">
                    <span style="height: 50%"></span>
                    <span style="height: 70%"></span>
                    <span style="height: 45%"></span>
                    <span style="height: 85%"></span>
                    <span style="height: 60%"></span>
                    <span style="height: 92%"></span>
                    <span style="height: 75%"></span>
                  </div>
                </div>
              </div>
            </div>
            <h3 class="web-title">管理后台演示</h3>
            <p class="web-sub">体验完整的用户、群组、财务与统计管理能力</p>
            <a v-if="adminPanelUrl" :href="adminPanelUrl" target="_blank" class="btn btn-primary web-btn">
              进入演示后台
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none"><path d="M5 12h14M13 6l6 6-6 6" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
            </a>
            <a v-else href="#" class="btn btn-primary web-btn" @click.prevent="showContactTip">
              进入演示后台
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none"><path d="M5 12h14M13 6l6 6-6 6" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
            </a>

            <div class="app-download">
              <h4 class="app-download-title">APP 下载</h4>
              <p class="app-download-sub">直接下载 Android 安装包体验完整移动端</p>
              <div class="app-download-btns">
                <a v-if="androidDownloadUrl" :href="androidDownloadUrl" target="_blank" class="btn btn-outline android-btn">
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none"><path d="M17 8h2a3 3 0 0 1 0 6h-2V8zM5 7h9v10H5a2 2 0 0 1-2-2V9a2 2 0 0 1 2-2zM2 12h1" stroke="#165dff" stroke-width="1.6" stroke-linecap="round"/><path d="M14 8l3-2M14 16l3 2" stroke="#165dff" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/></svg>
                  Android APK
                </a>
                <a v-else href="#" class="btn btn-outline android-btn" @click.prevent="showContactTip">
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none"><path d="M17 8h2a3 3 0 0 1 0 6h-2V8zM5 7h9v10H5a2 2 0 0 1-2-2V9a2 2 0 0 1 2-2zM2 12h1" stroke="#165dff" stroke-width="1.6" stroke-linecap="round"/><path d="M14 8l3-2M14 16l3 2" stroke="#165dff" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/></svg>
                  Android APK
                </a>
                <a href="#" class="btn btn-outline ios-btn" @click.prevent="showIosTipModal = true">
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none"><path d="M17 4c-1.2 0-2.4.6-3.1 1.4-.7.8-1.3 1.8-1.1 2.9 1.2 0 2.3-.7 3-1.5.7-.9 1.1-1.8 1.2-2.8z" fill="#165dff"/><path d="M18 17.5c-.5 1.1-.8 1.6-1.5 2.6-1 1.4-2.4 3.1-4.1 3.1-1.5 0-1.9-1-3.9-1-2 0-2.5 1-4 1-1.7 0-3-1.6-4-3C-1 16.3.4 11 3.5 11c1.6 0 2.8 1 4.3 1 1.5 0 2.3-1 4-1 1 0 2.1.5 3 1.4" stroke="#165dff" stroke-width="1.6" stroke-linecap="round"/></svg>
                  iOS
                </a>
                <a v-if="pcClientUrl" :href="pcClientUrl" target="_blank" class="btn btn-outline pc-btn">
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none"><rect x="3" y="4" width="18" height="12" rx="2" stroke="#165dff" stroke-width="1.6"/><path d="M8 20h8M12 16v4" stroke="#165dff" stroke-width="1.6" stroke-linecap="round"/></svg>
                  PC 客户端
                </a>
              </div>
              <div class="ios-tip">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none"><circle cx="12" cy="12" r="10" stroke="#86909c" stroke-width="1.6"/><path d="M12 7v5l3 2" stroke="#86909c" stroke-width="1.6" stroke-linecap="round"/></svg>
                {{ iosSelfSignGuide || 'iOS · 请自行签名安装测试' }}
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- ============ DEMO ACCOUNTS ============ -->
    <section class="section section-bg-2">
      <div class="container">
        <div class="accounts-box fade-in-up">
          <span class="accounts-icon" aria-hidden="true">
            <svg width="28" height="28" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
              <circle cx="12" cy="8" r="4" stroke="#fff" stroke-width="2"/>
              <path d="M4 20c0-4 4-6 8-6s8 2 8 6" stroke="#fff" stroke-width="2" stroke-linecap="round"/>
            </svg>
          </span>
          <div class="accounts-content">
            <h3 class="accounts-title">测试账号</h3>
            <div class="accounts-list">
              <div class="account-item">
                <span class="account-label">后台</span>
                <code class="account-code">admin / <span style="opacity:.85">联系客服获取</span></code>
              </div>
              <div class="account-item">
                <span class="account-label">APP 1</span>
                <code class="account-code">223344 / qq123123</code>
              </div>
              <div class="account-item">
                <span class="account-label">APP 2</span>
                <code class="account-code">112233 / 123123</code>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>

    <!-- ============ FEATURE CHECKLIST ============ -->
    <section class="section">
      <div class="container">
        <h2 class="section-title fade-in-up">您可以体验的功能</h2>
        <p class="section-subtitle fade-in-up">完整功能矩阵开放体验，感受 ChatPulse 的成熟通讯能力</p>

        <div class="grid-3 checklist-grid">
          <div
            v-for="(item, i) in checklist"
            :key="item.title"
            class="card checklist-card fade-in-up"
            :style="{ animationDelay: (i * .08) + 's' }"
          >
            <span class="check-icon" v-html="checkSvg"></span>
            <h3 class="checklist-title">{{ item.title }}</h3>
            <p class="checklist-desc">{{ item.desc }}</p>
          </div>
        </div>
      </div>
    </section>

    <!-- ============ DISCLAIMER ============ -->
    <section class="section-sm disclaimer-section">
      <div class="container">
        <div class="disclaimer-box fade-in-up">
          <span class="disclaimer-icon" aria-hidden="true">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
              <path d="M12 2L1 21h22L12 2z" stroke="#ff7d00" stroke-width="2" stroke-linejoin="round"/>
              <path d="M12 9v5M12 17.5v.5" stroke="#ff7d00" stroke-width="2" stroke-linecap="round"/>
            </svg>
          </span>
          <p class="disclaimer-text">Demo 环境数据每日重置，请勿输入真实信息</p>
        </div>
      </div>
    </section>

    <!-- ============ CTA ============ -->
    <section class="cta-section">
      <div class="container cta-inner">
        <h2 class="cta-title">想要私有化部署？联系我</h2>
        <p class="cta-sub">获取源码授权、定制开发与私有化部署方案，与我们的技术团队沟通您的需求</p>
        <NuxtLink to="/contact" class="btn btn-lg cta-btn">联系我们 →</NuxtLink>
      </div>
    </section>
  </div>
</template>

<script setup lang="ts">
import { onMounted, ref, nextTick } from 'vue'
const showModal = ref(false)
const showIosTipModal = ref(false)
const contactTelegram = ref('')
const androidDownloadUrl = ref('')
const iosDownloadUrl = ref('')
const iosSelfSignGuide = ref('请自行签名安装测试')
const adminPanelUrl = ref('')
const pcClientUrl = ref('')
const demoQrCanvas = ref<HTMLCanvasElement | null>(null)
const qrReady = ref(false)

function showContactTip() {
  showModal.value = true
}

onMounted(async () => {
  try {
    const res: any = await $fetch('/api/site-config')
    contactTelegram.value = res?.data?.contactTelegram || ''
    androidDownloadUrl.value = res?.data?.androidDownloadUrl || ''
    iosDownloadUrl.value = res?.data?.iosDownloadUrl || ''
    iosSelfSignGuide.value = res?.data?.iosSelfSignGuide || '请自行签名安装测试'
    adminPanelUrl.value = res?.data?.adminPanelUrl || ''
    pcClientUrl.value = res?.data?.pcClientUrl || ''
  } catch {}

  // 生成指向 /download 页面的二维码
  await nextTick()
  try {
    const QRCode = await import('qrcode')
    const downloadUrl = window.location.origin + '/download'
    if (demoQrCanvas.value) {
      await QRCode.toCanvas(demoQrCanvas.value, downloadUrl, {
        width: 200,
        margin: 2,
        color: { dark: '#1d2129', light: '#ffffff' },
      })
      qrReady.value = true
    }
  } catch (e) {
    console.error('QR generation failed:', e)
  }

  // 页面进入后稍微延迟再弹窗，体验更自然
  setTimeout(() => { showModal.value = true }, 300)
})

useHead({
  title: '在线体验 - ChatPulse 企业级 IM',
  meta: [
    { name: 'description', content: 'ChatPulse IM系统在线Demo体验' },
    { name: 'keywords', content: 'ChatPulse,在线体验,IM Demo,即时通讯演示,管理后台,APP下载,在线试用' },
  ],
})

const checkSvg = '<svg width="26" height="26" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><circle cx="12" cy="12" r="11" fill="#00b42a" opacity=".12"/><path d="M7 12.5l3.5 3.5 6.5-7" stroke="#00b42a" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>'

const checklist = [
  {
    title: '单聊 / 群聊',
    desc: '完整的消息收发、已读回执、撤回、@提及与多端同步体验。',
  },
  {
    title: '发红包 / 转账',
    desc: '内置钱包系统，体验红包、转账、余额与流水全链路。',
  },
  {
    title: '朋友圈',
    desc: '图文动态发布、点赞评论与隐私分组，打造社交圈子。',
  },
  {
    title: '音视频通话',
    desc: '基于 TRTC 的 1v1 与多人会议，低延迟高清通话体验。',
  },
  {
    title: '后台管理',
    desc: '用户、群组、财务、统计一站可视，权限可控可配。',
  },
  {
    title: '多端同步',
    desc: 'iOS / Android / Web / 管理后台，消息多端实时同步。',
  },
]
</script>

<style scoped>
/* Demo Modal（Telegram提示） - 全局 */
.demo-modal-mask {
  position: fixed; inset: 0;
  background: rgba(13, 17, 23, .7);
  backdrop-filter: blur(6px);
  z-index: 9999;
  display: flex; align-items: center; justify-content: center;
  padding: 24px;
}
.demo-modal {
  position: relative; width: 100%; max-width: 480px;
  background: #fff; border-radius: 16px; padding: 40px 32px 28px;
  box-shadow: 0 20px 60px rgba(0,0,0,.3); text-align: center;
}
.demo-close {
  position: absolute; top: 14px; right: 14px;
  width: 32px; height: 32px; border-radius: 8px;
  border: none; background: #f2f3f5; color: #86909c;
  cursor: pointer; display: flex; align-items: center; justify-content: center;
  transition: all .2s; padding: 0;
}
.demo-close:hover { background: #e5e6eb; color: #1d2129; }
.demo-badge {
  display: inline-block; padding: 5px 14px;
  background: linear-gradient(135deg, #e8f3ff, #dbeafe);
  color: #165dff; font-size: 12px; font-weight: 600;
  border-radius: 999px; margin-bottom: 16px;
}
.demo-title { font-size: 26px; font-weight: 800; color: #1d2129; margin-bottom: 12px; letter-spacing: -.4px; }
.demo-desc { font-size: 14px; color: #4e5969; line-height: 1.7; margin-bottom: 20px; }
.demo-telegram-card {
  display: flex; align-items: center; gap: 14px; padding: 16px 18px;
  background: linear-gradient(135deg, #f5f8ff, #eef4ff);
  border: 1px solid #dbeafe; border-radius: 12px; margin-bottom: 12px; text-align: left;
}
.tg-icon {
  width: 48px; height: 48px; border-radius: 50%;
  flex-shrink: 0; overflow: hidden;
  display: flex; align-items: center; justify-content: center;
}
.tg-label { font-size: 12px; color: #86909c; font-weight: 500; }
.tg-user { font-size: 17px; font-weight: 700; color: #1d2129; letter-spacing: .3px; }
.demo-telegram-card > a { margin-left: auto; }
.demo-hint { font-size: 12px; color: #86909c; margin-bottom: 20px; }
.demo-actions { display: flex; gap: 10px; justify-content: center; }
.modal-fade-enter-active, .modal-fade-leave-active { transition: opacity .25s ease; }
.modal-fade-enter-from, .modal-fade-leave-to { opacity: 0; }
.modal-fade-enter-active .demo-modal,
.modal-fade-leave-active .demo-modal { transition: transform .3s cubic-bezier(.25,.46,.45,.94), opacity .25s ease; }
.modal-fade-enter-from .demo-modal,
.modal-fade-leave-to .demo-modal { opacity: 0; transform: translateY(20px) scale(.96); }

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

/* ============ DEMO ENTRY ============ */
.section-bg-2 {
  background: var(--c-bg-2);
}

.demo-grid {
  align-items: stretch;
}

/* QR Card */
.qr-card {
  text-align: center;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 14px;
  padding: 36px 28px;
}

.qr-box {
  position: relative;
  width: 200px;
  height: 200px;
  border-radius: var(--radius-lg);
  background: #fff;
  border: 1px solid var(--c-border);
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 8px 24px rgba(22, 93, 255, .12);
  overflow: hidden;
}

.qr-canvas {
  width: 200px !important;
  height: 200px !important;
  display: block;
}

.qr-placeholder {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #f7f8fa;
}

.qr-direct-link {
  margin-top: 4px;
  font-size: 13px;
}

.platform-tag.ios {
  color: var(--c-text-3);
}

.qr-title {
  font-size: 20px;
  font-weight: 800;
  color: var(--c-text-1);
  margin-top: 6px;
}

.qr-sub {
  font-size: 14px;
  color: var(--c-text-2);
  line-height: 1.6;
}

.qr-platforms {
  display: flex;
  gap: 10px;
  margin-top: 4px;
}

.platform-tag {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 6px 14px;
  font-size: 13px;
  font-weight: 600;
  color: var(--c-text-2);
  background: var(--c-bg-2);
  border: 1px solid var(--c-border);
  border-radius: 999px;
}

.qr-support {
  font-size: 13px;
  color: var(--c-text-3);
  font-weight: 500;
}

/* Web Card */
.web-card {
  display: flex;
  flex-direction: column;
  gap: 14px;
  padding: 28px;
}

.web-preview {
  border-radius: var(--radius-md);
  overflow: hidden;
  border: 1px solid var(--c-border);
  box-shadow: var(--shadow-sm);
}

.preview-bar {
  display: flex;
  align-items: center;
  gap: 7px;
  padding: 10px 14px;
  background: #f7f8fa;
  border-bottom: 1px solid var(--c-border);
}

.preview-bar .dot { width: 10px; height: 10px; border-radius: 50%; }
.preview-bar .dot.r { background: #ff5f57; }
.preview-bar .dot.y { background: #febc2e; }
.preview-bar .dot.g { background: #28c840; }

.preview-url {
  margin-left: 10px;
  font-size: 12px;
  color: var(--c-text-3);
  font-weight: 500;
}

.preview-body {
  display: grid;
  grid-template-columns: 64px 1fr;
  background: #fff;
  min-height: 200px;
}

.preview-sidebar {
  background: #1d2129;
  padding: 14px 8px;
  display: flex;
  flex-direction: column;
  gap: 12px;
  align-items: center;
}

.preview-sidebar .side-item {
  width: 36px;
  height: 36px;
  border-radius: 8px;
  background: rgba(255, 255, 255, .1);
}

.preview-sidebar .side-item.active {
  background: var(--c-primary);
}

.preview-main {
  padding: 16px;
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.preview-stats {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 10px;
}

.preview-stats .ps-item {
  display: flex;
  flex-direction: column;
  gap: 6px;
  padding: 10px;
  background: #f7f8fa;
  border-radius: 6px;
  font-size: 11px;
  color: var(--c-text-3);
  font-weight: 600;
}

.preview-stats .ps-item i {
  display: block;
  width: 70%;
  height: 6px;
  background: var(--c-gradient);
  border-radius: 3px;
}

.preview-stats .ps-item b {
  font-size: 14px;
  color: var(--c-text-1);
}

.preview-chart {
  display: flex;
  align-items: flex-end;
  gap: 6px;
  height: 70px;
  padding: 10px;
  background: #f7f8fa;
  border-radius: 6px;
}

.preview-chart span {
  flex: 1;
  background: linear-gradient(180deg, #4080ff 0%, #165dff 100%);
  border-radius: 3px 3px 0 0;
  opacity: .85;
}

.web-title {
  font-size: 20px;
  font-weight: 800;
  color: var(--c-text-1);
}

.web-sub {
  font-size: 14px;
  color: var(--c-text-2);
  line-height: 1.6;
  margin-bottom: 4px;
}

.web-btn {
  align-self: flex-start;
}

.app-download {
  margin-top: 8px;
  padding-top: 18px;
  border-top: 1px dashed var(--c-border);
}

.app-download-title {
  font-size: 16px;
  font-weight: 700;
  color: var(--c-text-1);
  margin-bottom: 4px;
}

.app-download-sub {
  font-size: 13px;
  color: var(--c-text-3);
  margin-bottom: 14px;
}

.app-download-btns {
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
  margin-bottom: 12px;
}

.app-download-btns .btn {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 9px 18px;
  font-size: 14px;
  font-weight: 600;
}

.android-btn,
.pc-btn {
  align-self: flex-start;
}

/* ============ ACCOUNTS ============ */
.accounts-box {
  display: flex;
  align-items: center;
  gap: 24px;
  padding: 32px 36px;
  background: linear-gradient(135deg, #165dff 0%, #4080ff 100%);
  border-radius: var(--radius-lg);
  color: #fff;
  box-shadow: 0 12px 36px rgba(22, 93, 255, .22);
}

.accounts-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 60px;
  height: 60px;
  border-radius: 14px;
  background: rgba(255, 255, 255, .18);
  flex-shrink: 0;
}

.accounts-title {
  font-size: 20px;
  font-weight: 800;
  margin-bottom: 10px;
}

.accounts-list {
  display: flex;
  gap: 24px;
  flex-wrap: wrap;
}

.account-item {
  display: inline-flex;
  align-items: center;
  gap: 10px;
}

.account-label {
  font-size: 13px;
  font-weight: 600;
  color: rgba(255, 255, 255, .85);
}

.account-code {
  padding: 6px 12px;
  font-size: 14px;
  font-weight: 700;
  color: #fff;
  background: rgba(255, 255, 255, .15);
  border: 1px solid rgba(255, 255, 255, .25);
  border-radius: 6px;
  font-family: 'JetBrains Mono', 'Fira Code', monospace;
}

/* ============ CHECKLIST ============ */
.checklist-grid {
  gap: 24px;
}

.checklist-card {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.check-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 48px;
  height: 48px;
}

.checklist-title {
  font-size: 18px;
  font-weight: 700;
  color: var(--c-text-1);
}

.checklist-desc {
  font-size: 14px;
  color: var(--c-text-2);
  line-height: 1.65;
}

/* ============ DISCLAIMER ============ */
.disclaimer-section {
  padding: 32px 0;
}

.disclaimer-box {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 20px 28px;
  background: rgba(255, 125, 0, .08);
  border: 1px solid rgba(255, 125, 0, .3);
  border-left: 4px solid var(--c-warning);
  border-radius: var(--radius-md);
}

.disclaimer-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.disclaimer-text {
  font-size: 15px;
  font-weight: 600;
  color: var(--c-warning);
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
  .hero-title { font-size: 36px; }
}

@media (max-width: 600px) {
  .hero { padding: 48px 0 56px; }
  .hero-title { font-size: 30px; }
  .hero-subtitle { font-size: 16px; }
  .hero-cta .btn { flex: 1; justify-content: center; }

  .qr-card,
  .web-card { padding: 24px 18px; }

  .qr-box { width: 160px; height: 160px; }

  .accounts-box {
    flex-direction: column;
    align-items: flex-start;
    gap: 16px;
    padding: 24px 20px;
  }

  .accounts-list { gap: 14px; }

  .cta-title { font-size: 26px; }
  .cta-sub { font-size: 15px; }
}
</style>
