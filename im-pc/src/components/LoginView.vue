<script setup>
import { ref, watch, onBeforeUnmount } from 'vue';
import { useAuthStore } from '../stores/auth';

const auth = useAuthStore();
const activeTab = ref('password');
const account = ref('');
const password = ref('');
const busy = ref(false);
const qrCanvas = ref(null);
const qrLoading = ref(false);

async function startQr() {
  qrLoading.value = true;
  try {
    await auth.startQr();
    // 二维码内容 = payload（Go 后端返回），用 qrcode 库渲染到 canvas
    const payload = auth.qr?.payload || '';
    if (payload && qrCanvas.value) {
      const QRCode = await import('qrcode');
      await QRCode.toCanvas(qrCanvas.value, payload, { width: 180, margin: 1 });
    }
  } catch (e) {
    auth.qrStatus = e?.message || '二维码生成失败';
    auth.qrOverlay = true;
  } finally {
    qrLoading.value = false;
  }
}

function switchTab(tab) {
  activeTab.value = tab;
  if (tab === 'qr') {
    startQr();
  } else {
    auth.stopQr();
  }
}

async function submit() {
  busy.value = true;
  const ok = await auth.passwordLogin(account.value, password.value);
  busy.value = false;
}

// 二维码状态变化（scanned/confirmed）自动刷新 UI
watch(() => auth.qrStatus, () => {});
watch(() => auth.qr?.payload, () => {
  if (activeTab.value === 'qr' && auth.qr?.payload) {
    import('qrcode').then(QRCode => {
      if (qrCanvas.value) QRCode.toCanvas(qrCanvas.value, auth.qr.payload, { width: 180, margin: 1 });
    });
  }
});

onBeforeUnmount(() => auth.stopQr());
</script>

<template>
  <section class="login-view">
    <div class="login-window">
      <div class="login-brand-panel">
        <div class="brand-lockup">
          <div class="brand-symbol" data-brand-mark>{{ auth.brand.mark }}</div>
          <div>
            <strong data-brand-name>{{ auth.brand.name }}</strong>
            <span>安全、稳定的私有化沟通平台</span>
          </div>
        </div>
        <div class="brand-copy">
          <span class="eyebrow light" data-brand-short>{{ auth.brand.shortName }}</span>
          <h1>让沟通回到清晰、可靠和高效。</h1>
          <p>消息、联系人、群聊和文件统一在一个桌面工作区中。</p>
        </div>
        <div class="brand-features"><span>私有化部署</span><span>多端同步</span><span>开源版</span></div>
        <div class="brand-foot"><span data-brand-name>{{ auth.brand.name }}</span></div>
      </div>

      <div class="login-form-panel">
        <div class="login-title"><h2>登录</h2><p>使用手机扫码，或输入账号密码。</p></div>
        <div class="login-tabs" role="tablist">
          <button class="login-tab" :class="{ active: activeTab === 'qr' }" type="button" @click="switchTab('qr')">扫码登录</button>
          <button class="login-tab" :class="{ active: activeTab === 'password' }" type="button" @click="switchTab('password')">账号登录</button>
        </div>

        <div v-show="activeTab === 'qr'" class="login-pane active">
          <div class="qr-shell">
            <canvas v-show="auth.qr?.payload" ref="qrCanvas" width="180" height="180"></canvas>
            <div v-if="qrLoading || (!auth.qr?.payload && !auth.qrOverlay)" class="qr-placeholder">
              <span>{{ qrLoading ? '正在生成…' : '二维码加载中…' }}</span>
            </div>
            <div v-if="auth.qrOverlay" class="qr-overlay">
              <span>{{ auth.qrStatus }}</span>
              <button type="button" @click="startQr">刷新二维码</button>
              <button type="button" @click="activeTab = 'password'">使用账号登录</button>
            </div>
          </div>
          <strong>{{ auth.qrStatus }}</strong>
          <p>打开手机端，点击右上角“+”后选择扫一扫。</p>
        </div>

        <form v-show="activeTab === 'password'" class="login-pane" novalidate @submit.prevent="submit">
          <label class="field"><span>账号</span><input v-model="account" autocomplete="username" placeholder="账号、手机号或邮箱"></label>
          <label class="field"><span>密码</span><input v-model="password" type="password" autocomplete="current-password" placeholder="请输入登录密码"></label>
          <button class="primary-button wide" type="submit" :disabled="busy">{{ busy ? '登录中…' : '登录' }}</button>
        </form>

        <div v-if="auth.loginError" class="form-error" aria-live="polite">{{ auth.loginError }}</div>
        <div class="login-foot">
          <span><span data-brand-name>{{ auth.brand.name }}</span> v7.9.1</span>
          <span>安全连接</span>
        </div>
      </div>
    </div>
  </section>
</template>
