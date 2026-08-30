<script setup>
import { ref, watch } from 'vue';
import { useAuthStore } from '../stores/auth';
import QrCanvas from './QrCanvas.vue';

const auth = useAuthStore();
// Go 后端暂未实现扫码登录：默认账号登录，扫码 tab 提示不可用
const activeTab = ref('password');
const account = ref('');
const password = ref('');
const busy = ref(false);

function switchTab(tab) {
  if (tab === 'qr') {
    auth.qrStatus = '扫码登录暂未接入，请使用账号密码登录';
    auth.qrOverlay = true;
    return;
  }
  activeTab.value = tab;
}

async function submit() {
  busy.value = true;
  const ok = await auth.passwordLogin(account.value, password.value);
  busy.value = false;
}

watch(() => auth.qr, () => {}, { deep: true });
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
            <div class="qr-placeholder">
              <svg width="140" height="140" viewBox="0 0 140 140" fill="none">
                <rect x="10" y="10" width="50" height="50" rx="6" stroke="currentColor" stroke-width="4"/>
                <rect x="80" y="10" width="50" height="50" rx="6" stroke="currentColor" stroke-width="4"/>
                <rect x="10" y="80" width="50" height="50" rx="6" stroke="currentColor" stroke-width="4"/>
                <path d="M80 90h10v10H80zm14 0h10v10H94zm0 14h10v10H94zm14-14h10v10h-10z" fill="currentColor"/>
              </svg>
            </div>
            <div v-if="auth.qrOverlay" class="qr-overlay">
              <span>{{ auth.qrStatus }}</span>
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
