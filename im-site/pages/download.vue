<template>
  <div class="download-page">
    <div class="dl-container">
      <!-- iOS 提示弹窗（统一：苹果系统限制说明 + 下载链接 + 联系客服） -->
      <Teleport to="body">
        <transition name="modal-fade">
          <div v-if="showIosTip" class="dl-modal-mask" @click.self="dismissIos">
            <div class="dl-modal">
              <div class="dl-modal-icon">
                <svg width="48" height="48" viewBox="0 0 24 24" fill="none">
                  <path d="M17 4c-1.2 0-2.4.6-3.1 1.4-.7.8-1.3 1.8-1.1 2.9 1.2 0 2.3-.7 3-1.5.7-.9 1.1-1.8 1.2-2.8z" fill="#165dff"/>
                  <path d="M18 17.5c-.5 1.1-.8 1.6-1.5 2.6-1 1.4-2.4 3.1-4.1 3.1-1.5 0-1.9-1-3.9-1-2 0-2.5 1-4 1-1.7 0-3-1.6-4-3C-1 16.3.4 11 3.5 11c1.6 0 2.8 1 4.3 1 1.5 0 2.3-1 4-1 1 0 2.1.5 3 1.4" stroke="#165dff" stroke-width="1.5"/>
                </svg>
              </div>
              <h2 class="dl-modal-title">关于 iOS 下载</h2>
              <p class="dl-modal-desc">
                由于苹果系统限制，IPA 安装包无法像 Android APK 一样直接安装。<br/>
                {{ iosGuide || '下载的 IPA 文件需要自行签名测试' }}。
              </p>
              <div class="dl-modal-actions">
                <a v-if="iosUrl" :href="iosUrl" target="_blank" class="btn btn-primary btn-lg dl-modal-btn">
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="none"><path d="M12 4v12M6 10l6 6 6-6" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
                  下载 IPA 文件
                </a>
                <a :href="telegramUrl" target="_blank" class="btn btn-outline btn-lg dl-modal-btn">
                  <svg width="18" height="18" viewBox="0 0 48 48" fill="none"><circle cx="24" cy="24" r="24" fill="#165dff"/><path d="M20 34c-1.2 0-1.1-.5-1.6-1.8l-3.7-12.3c-.4-1.3.5-2 1.6-2.3l26.4-10.2c1.4-.5 2.9 0 2.9 1.9 0 .3-.1.6-.2.9L38.5 27c-.2 1-.9 1.3-1.9 1l-7.6-2.6-3.7 7.6c-.6 1-1.1 1.3-2.3 1.3z" fill="#fff"/></svg>
                  联系客服
                </a>
              </div>
            </div>
          </div>
        </transition>
      </Teleport>

      <!-- 主体内容 -->
      <div class="dl-card">
        <div class="dl-logo">
          <svg width="56" height="56" viewBox="0 0 48 48" fill="none">
            <defs><linearGradient id="dlLogo" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#4080ff"/><stop offset="100%" stop-color="#165dff"/></linearGradient></defs>
            <rect x="6" y="4" width="36" height="40" rx="8" fill="url(#dlLogo)"/>
            <rect x="10" y="8" width="28" height="28" rx="3" fill="#fff" opacity=".15"/>
            <circle cx="24" cy="36" r="2" fill="#fff"/>
            <path d="M16 16h16M16 20h16M16 24h10" stroke="#fff" stroke-width="2" stroke-linecap="round"/>
          </svg>
        </div>
        <h1 class="dl-app-name">ChatPulse</h1>
        <p class="dl-app-tagline">企业级即时通讯系统</p>

        <!-- Android 下载按钮 -->
        <div v-if="isAndroid" class="dl-android-section">
          <a :href="androidUrl || '#'" class="btn btn-primary btn-lg dl-download-btn" @click.prevent="handleAndroidClick">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none">
              <path d="M17 8h2a3 3 0 0 1 0 6h-2V8zM5 7h9v10H5a2 2 0 0 1-2-2V9a2 2 0 0 1 2-2zM2 12h1M14 8l3-2M14 16l3 2" stroke="#fff" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
            {{ androidUrl ? '下载 Android APK' : '联系客服获取下载' }}
          </a>
          <p v-if="androidUrl" class="dl-hint">点击下载安装包，安装时请允许"未知来源"</p>
        </div>

        <!-- iOS 用户：显示可点击的提示卡片 -->
        <div v-else-if="isIOS" class="dl-ios-section">
          <div class="dl-ios-tip dl-ios-tip-clickable" @click="showIosTip = true">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none">
              <path d="M17 4c-1.2 0-2.4.6-3.1 1.4-.7.8-1.3 1.8-1.1 2.9 1.2 0 2.3-.7 3-1.5.7-.9 1.1-1.8 1.2-2.8z" fill="#165dff"/>
              <path d="M18 17.5c-.5 1.1-.8 1.6-1.5 2.6-1 1.4-2.4 3.1-4.1 3.1-1.5 0-1.9-1-3.9-1-2 0-2.5 1-4 1-1.7 0-3-1.6-4-3C-1 16.3.4 11 3.5 11c1.6 0 2.8 1 4.3 1 1.5 0 2.3-1 4-1 1 0 2.1.5 3 1.4" stroke="#165dff" stroke-width="1.5"/>
            </svg>
            <span>iOS 下载 · 点击查看说明</span>
          </div>
        </div>

        <!-- 桌面端：显示二维码 -->
        <div v-else class="dl-desktop-section">
          <div class="dl-qr-wrapper">
            <canvas ref="qrCanvas" class="dl-qr-canvas"></canvas>
            <div v-if="!qrReady" class="dl-qr-placeholder">生成中...</div>
          </div>
          <p class="dl-qr-tip">使用手机扫码下载 APP</p>
          <div class="dl-platforms">
            <span class="dl-platform android">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none"><path d="M17 8h2a3 3 0 0 1 0 6h-2V8zM5 7h9v10H5a2 2 0 0 1-2-2V9a2 2 0 0 1 2-2zM2 12h1M14 8l3-2M14 16l3 2" stroke="#00b42a" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>
              Android
            </span>
            <span class="dl-platform ios" @click="showIosTip = true">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none"><path d="M17 4c-1.2 0-2.4.6-3.1 1.4-.7.8-1.3 1.8-1.1 2.9 1.2 0 2.3-.7 3-1.5.7-.9 1.1-1.8 1.2-2.8z" fill="#165dff"/></svg>
              iOS
            </span>
          </div>
        </div>

        <!-- 其他下载入口 -->
        <div v-if="pcClientUrl" class="dl-extra">
          <a :href="pcClientUrl" class="dl-extra-link">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none"><rect x="3" y="4" width="18" height="12" rx="2" stroke="#165dff" stroke-width="1.5"/><path d="M8 20h8M12 16v4" stroke="#165dff" stroke-width="1.5" stroke-linecap="round"/></svg>
            PC 客户端下载
          </a>
        </div>
        <div v-if="adminPanelUrl" class="dl-extra">
          <a :href="adminPanelUrl" target="_blank" class="dl-extra-link">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none"><rect x="3" y="3" width="18" height="18" rx="2" stroke="#165dff" stroke-width="1.5"/><path d="M3 9h18M9 21V9" stroke="#165dff" stroke-width="1.5"/></svg>
            管理后台
          </a>
        </div>
      </div>

      <!-- 底部联系客服 -->
      <div class="dl-contact">
        <p>遇到问题？</p>
        <a :href="telegramUrl" target="_blank" class="dl-contact-link">
          <svg width="18" height="18" viewBox="0 0 48 48" fill="none"><defs><linearGradient id="dlTg" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#4080ff"/><stop offset="100%" stop-color="#165dff"/></linearGradient></defs><circle cx="24" cy="24" r="24" fill="url(#dlTg)"/><path d="M20 34c-1.2 0-1.1-.5-1.6-1.8l-3.7-12.3c-.4-1.3.5-2 1.6-2.3l26.4-10.2c1.4-.5 2.9 0 2.9 1.9 0 .3-.1.6-.2.9L38.5 27c-.2 1-.9 1.3-1.9 1l-7.6-2.6-3.7 7.6c-.6 1-1.1 1.3-2.3 1.3z" fill="#fff"/></svg>
          联系 Telegram 客服
        </a>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { onMounted, ref, nextTick } from 'vue'

useHead({
  title: '下载 ChatPulse - 扫码下载 APP',
  meta: [
    { name: 'description', content: '扫描二维码下载 ChatPulse APP，Android APK 直接下载，iOS 敬请期待。' },
  ],
})

const androidUrl = ref('')
const iosUrl = ref('')
const iosGuide = ref('请自行签名安装测试')
const adminPanelUrl = ref('')
const pcClientUrl = ref('')
const contactTelegram = ref('')
const telegramUrl = ref('https://t.me/ChatPulse_BD')

const isAndroid = ref(false)
const isIOS = ref(false)
const showIosTip = ref(false)
const qrCanvas = ref<HTMLCanvasElement | null>(null)
const qrReady = ref(false)

function dismissIos() {
  showIosTip.value = false
}

function handleAndroidClick() {
  if (!androidUrl.value) {
    window.open(telegramUrl.value, '_blank')
  }
}

onMounted(async () => {
  // 检测设备
  const ua = navigator.userAgent.toLowerCase()
  isAndroid.value = ua.includes('android')
  isIOS.value = /iphone|ipad|ipod/.test(ua)

  // 读取后台配置
  try {
    const res: any = await $fetch('/api/site-config')
    androidUrl.value = res?.data?.androidDownloadUrl || ''
    iosUrl.value = res?.data?.iosDownloadUrl || ''
    iosGuide.value = res?.data?.iosSelfSignGuide || '下载的 IPA 文件需要自行签名测试'
    adminPanelUrl.value = res?.data?.adminPanelUrl || ''
    pcClientUrl.value = res?.data?.pcClientUrl || ''
    contactTelegram.value = res?.data?.contactTelegram || ''
    telegramUrl.value = `https://t.me/${(contactTelegram.value || '@ChatPulse_BD').replace(/^@/, '')}`
  } catch {}

  // 桌面端生成二维码（指向当前 /download 页面）
  if (!isAndroid.value && !isIOS.value) {
    await nextTick()
    try {
      const QRCode = await import('qrcode')
      const downloadUrl = window.location.href
      if (qrCanvas.value) {
        await QRCode.toCanvas(qrCanvas.value, downloadUrl, {
          width: 240,
          margin: 2,
          color: { dark: '#1d2129', light: '#ffffff' },
        })
        qrReady.value = true
      }
    } catch (e) {
      console.error('QR code generation failed:', e)
    }
  }
})
</script>

<style scoped>
.download-page {
  min-height: 100vh;
  background: linear-gradient(135deg, #f0f5ff 0%, #e8f3ff 50%, #f0f5ff 100%);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 40px 20px;
}

.dl-container {
  width: 100%;
  max-width: 420px;
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.dl-card {
  background: #fff;
  border-radius: 20px;
  padding: 40px 32px 32px;
  text-align: center;
  box-shadow: 0 12px 40px rgba(22, 93, 255, .1);
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 16px;
}

.dl-logo {
  display: flex;
  align-items: center;
  justify-content: center;
}

.dl-app-name {
  font-size: 28px;
  font-weight: 900;
  color: #1d2129;
  letter-spacing: -.5px;
}

.dl-app-tagline {
  font-size: 14px;
  color: #86909c;
  margin-top: -8px;
}

/* Android */
.dl-android-section {
  width: 100%;
  margin-top: 12px;
}

.dl-download-btn {
  width: 100%;
  justify-content: center;
  gap: 8px;
}

.dl-hint {
  font-size: 12px;
  color: #86909c;
  margin-top: 10px;
}

/* iOS */
.dl-ios-section {
  width: 100%;
  margin-top: 12px;
}

.dl-ios-tip {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 16px 20px;
  background: #f2f3f5;
  border-radius: 12px;
  color: #86909c;
  font-size: 15px;
  font-weight: 600;
  transition: all .2s;
}

.dl-ios-tip-clickable {
  background: #f5f8ff;
  border: 1px solid #dbeafe;
  color: #165dff;
  cursor: pointer;
}

.dl-ios-tip-clickable:hover {
  background: #e8f3ff;
  border-color: #165dff;
}

/* Desktop QR */
.dl-desktop-section {
  width: 100%;
  margin-top: 12px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
}

.dl-qr-wrapper {
  position: relative;
  width: 240px;
  height: 240px;
  border-radius: 16px;
  overflow: hidden;
  box-shadow: 0 4px 16px rgba(0, 0, 0, .08);
}

.dl-qr-canvas {
  width: 240px !important;
  height: 240px !important;
}

.dl-qr-placeholder {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 14px;
  color: #86909c;
  background: #f7f8fa;
}

.dl-qr-tip {
  font-size: 14px;
  color: #4e5969;
  font-weight: 600;
}

.dl-platforms {
  display: flex;
  gap: 10px;
}

.dl-platform {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 6px 14px;
  font-size: 13px;
  font-weight: 600;
  border-radius: 999px;
  background: #f7f8fa;
}

.dl-platform.android { color: #00b42a; }
.dl-platform.ios { color: #165dff; cursor: pointer; transition: all .2s; }
.dl-platform.ios:hover { background: #e8f3ff; }

/* Extra links */
.dl-extra {
  width: 100%;
  margin-top: 4px;
}

.dl-extra-link {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 12px 20px;
  font-size: 14px;
  font-weight: 600;
  color: #165dff;
  background: #f5f8ff;
  border: 1px solid #dbeafe;
  border-radius: 10px;
  text-decoration: none;
  transition: all .2s;
}

.dl-extra-link:hover {
  background: #e8f3ff;
  border-color: #165dff;
}

/* Contact */
.dl-contact {
  text-align: center;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
}

.dl-contact p {
  font-size: 13px;
  color: #86909c;
}

.dl-contact-link {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 14px;
  font-weight: 600;
  color: #165dff;
  text-decoration: none;
}

.dl-contact-link:hover {
  text-decoration: underline;
}

/* Modal */
.dl-modal-mask {
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

.dl-modal {
  position: relative;
  width: 100%;
  max-width: 400px;
  background: #fff;
  border-radius: 16px;
  padding: 36px 28px 24px;
  box-shadow: 0 20px 60px rgba(0, 0, 0, .3);
  text-align: center;
}

.dl-modal-icon {
  display: flex;
  justify-content: center;
  margin-bottom: 16px;
}

.dl-modal-title {
  font-size: 22px;
  font-weight: 800;
  color: #1d2129;
  margin-bottom: 8px;
}

.dl-modal-desc {
  font-size: 14px;
  color: #4e5969;
  margin-bottom: 20px;
}

.dl-modal-actions {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.dl-modal-btn {
  width: 100%;
  justify-content: center;
  gap: 8px;
}

.modal-fade-enter-active,
.modal-fade-leave-active {
  transition: opacity .25s ease;
}

.modal-fade-enter-from,
.modal-fade-leave-to {
  opacity: 0;
}

@media (max-width: 480px) {
  .dl-card { padding: 28px 20px 24px; }
  .dl-app-name { font-size: 24px; }
  .dl-qr-wrapper { width: 200px; height: 200px; }
  .dl-qr-canvas { width: 200px !important; height: 200px !important; }
}
</style>
