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

// 注册表单
const regNickname = ref('');
const regPassword = ref('');
const regConfirm = ref('');
const regSms = ref('');
const regCaptcha = ref('');
const smsLeft = ref(0);
let smsTimer = null;

async function startQr() {
  qrLoading.value = true;
  try {
    await auth.startQr();
    // 二维码内容 = payload（Go 后端返回），用 qrcode 库渲染到 canvas
    const payload = auth.qr?.payload || '';
    if (payload && qrCanvas.value) {
      const QRCode = await import('qrcode');
      await QRCode.toCanvas(qrCanvas.value, payload, { width: 232, margin: 1 });
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
  if (tab === 'register') {
    // 进入注册页先拉一张图形验证码
    auth.refreshCaptcha();
  }
}

async function submit() {
  busy.value = true;
  const ok = await auth.passwordLogin(account.value, password.value);
  busy.value = false;
}

async function getSmsCode() {
  if (smsLeft.value > 0) return;
  if (!account.value) {
    auth.loginError = '请先填写手机号 / 账号';
    return;
  }
  if (!auth.captcha?.captchaId || !regCaptcha.value) {
    auth.loginError = '请先填写图形验证码';
    return;
  }
  try {
    await auth.sendRegisterCode(account.value, auth.captcha.captchaId, regCaptcha.value);
    smsLeft.value = 60;
    smsTimer = setInterval(() => {
      smsLeft.value -= 1;
      if (smsLeft.value <= 0) { clearInterval(smsTimer); smsTimer = null; }
    }, 1000);
    auth.loginError = '';
  } catch (e) {
    auth.loginError = e?.message || '验证码发送失败';
    // 图形验证码可能已失效，刷新一张
    auth.refreshCaptcha();
  }
}

async function submitRegister() {
  busy.value = true;
  const ok = await auth.register({
    account: account.value,
    nickname: regNickname.value,
    password: regPassword.value,
    confirm: regConfirm.value,
    code: regSms.value,
    captchaId: auth.captcha?.captchaId || '',
    captchaCode: regCaptcha.value
  });
  busy.value = false;
}

// 二维码状态变化（scanned/confirmed）自动刷新 UI
watch(() => auth.qrStatus, () => {});
watch(() => auth.qr?.payload, () => {
  if (activeTab.value === 'qr' && auth.qr?.payload) {
    import('qrcode').then(QRCode => {
      if (qrCanvas.value) QRCode.toCanvas(qrCanvas.value, auth.qr.payload, { width: 232, margin: 1 });
    });
  }
});

onBeforeUnmount(() => {
  auth.stopQr();
  if (smsTimer) clearInterval(smsTimer);
});
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
          <button class="login-tab" :class="{ active: activeTab === 'register' }" type="button" @click="switchTab('register')">注册</button>
        </div>

        <div v-show="activeTab === 'qr'" class="login-pane active">
          <div class="qr-shell">
            <canvas v-show="auth.qr?.payload" ref="qrCanvas" width="232" height="232"></canvas>
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

        <form v-show="activeTab === 'register'" class="login-pane" novalidate @submit.prevent="submitRegister">
          <label class="field"><span>手机号 / 账号</span><input v-model="account" autocomplete="username" placeholder="用于登录的手机号或邮箱"></label>
          <label class="field"><span>昵称（选填）</span><input v-model="regNickname" placeholder="展示名称"></label>
          <label class="field"><span>密码</span><input v-model="regPassword" type="password" autocomplete="new-password" placeholder="8-20 位，含字母和数字"></label>
          <label class="field"><span>确认密码</span><input v-model="regConfirm" type="password" autocomplete="new-password" placeholder="再次输入密码"></label>
          <label class="field"><span>短信验证码</span>
            <div class="field-inline">
              <input v-model="regSms" placeholder="6 位短信验证码">
              <button type="button" class="mini-button" :disabled="smsLeft > 0" @click="getSmsCode">{{ smsLeft > 0 ? smsLeft + 's' : '获取验证码' }}</button>
            </div>
          </label>
          <label class="field"><span>图形验证码</span>
            <div class="field-inline">
              <input v-model="regCaptcha" placeholder="输入图中字符">
              <img v-if="auth.captcha?.image" class="captcha-img" :src="'data:image/png;base64,' + auth.captcha.image" alt="图形验证码" @click="auth.refreshCaptcha()" />
              <button v-else type="button" class="mini-button" @click="auth.refreshCaptcha()">加载</button>
            </div>
          </label>
          <button class="primary-button wide" type="submit" :disabled="busy">{{ busy ? '注册中…' : '注册并登录' }}</button>
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
