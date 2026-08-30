import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import api from '../api/client';
import { TOKEN_KEY, DEVICE_KEY, deviceId } from '../utils/helpers';
import { useUiStore } from './ui';
import { useConversationsStore } from './conversations';
import { useContactsStore } from './contacts';
import { useMessagesStore } from './messages';
import { useSync } from '../composables/useSync';

export const useAuthStore = defineStore('auth', () => {
  const token = ref(localStorage.getItem(TOKEN_KEY) || '');
  const user = ref(null);
  const config = ref(null);
  const license = ref(null);
  const loginError = ref('');
  const preferences = ref({});
  const qr = ref(null);
  const qrStatus = ref('正在生成登录二维码');
  const qrOverlay = ref(false);

  const brand = computed(() => {
    const cfg = config.value || {};
    const name = String(cfg.app_name || cfg.brand_name || '即时通讯').trim() || '即时通讯';
    const shortName = String(cfg.brand_short_name || name.slice(0, 4)).trim() || name.slice(0, 4);
    const mark = String(cfg.brand_mark || shortName.slice(0, 1) || '聊').trim().slice(0, 4);
    const logo = String(cfg.brand_logo || '').trim();
    return { name, shortName, mark, logo };
  });

  function setToken(next, nextUser = null) {
    token.value = next || '';
    user.value = nextUser || null;
    if (token.value) localStorage.setItem(TOKEN_KEY, token.value);
    else localStorage.removeItem(TOKEN_KEY);
  }

  function handleExpiredLogin() {
    if (!token.value) return;
    setToken('', null);
    useSync().stop();
    const ui = useUiStore();
    ui.toast('登录已失效', '请重新登录', 'error');
  }

  function requireLicense() {
    // 开源版不会触发；保留兼容位。
    license.value = { success: false, code: 'LICENSE_REQUIRED', message: '需要授权' };
  }

  function applyBrand() {
    const b = brand.value;
    document.title = b.name;
    document.querySelectorAll('[data-brand-name]').forEach(el => (el.textContent = b.name));
    document.querySelectorAll('[data-brand-short]').forEach(el => (el.textContent = b.shortName));
    document.querySelectorAll('[data-brand-mark]').forEach(el => {
      el.textContent = b.mark;
      const url = b.logo ? new URL('../' + b.logo.replace(/^\//, ''), location.href).href : '';
      if (url) {
        el.style.backgroundImage = `url('${url.replace(/'/g, '%27')}')`;
        el.style.backgroundSize = 'cover';
        el.style.backgroundPosition = 'center';
        el.style.fontSize = '0';
      } else {
        el.style.backgroundImage = '';
        el.style.fontSize = '';
      }
    });
  }

  async function loadConfig() {
    try {
      config.value = await api('system/config', {}, 'GET', false);
      applyBrand();
    } catch (_) {}
  }

  async function loadPreferences(render = true) {
    try {
      preferences.value = (await api('me/preferences')) || {};
      if (preferences.value.theme) useUiStore().setTheme(preferences.value.theme);
    } catch (_) {}
  }

  // 当前登录用户资料（加好友默认验证消息、头像/昵称展示依赖它）
  async function loadMe() {
    try {
      const me = await api('me');
      if (me) user.value = me;
    } catch (_) {}
  }

  async function passwordLogin(account, password) {
    const ui = useUiStore();
    loginError.value = '';
    if (!account || !password) {
      loginError.value = '请输入账号和密码';
      return false;
    }
    try {
      const result = await api('auth/login', {
        account,
        password,
        device_id: deviceId(),
        device_name: navigator.platform || '电脑浏览器',
        platform: 'web-pc'
      }, 'POST', false, { timeout: 12000 });
      setToken(result.token, result.user);
      await enterMain();
      return true;
    } catch (error) {
      loginError.value = error.message;
      return false;
    }
  }

  // —— 扫码登录 ——
  let qrTimer = null;
  async function startQr() {
    if (qrTimer) clearInterval(qrTimer);
    qr.value = null;
    qrOverlay.value = false;
    qrStatus.value = '正在生成登录二维码';
    try {
      qr.value = await api('pc/qr/create', { device_id: deviceId(), device_name: navigator.platform || '电脑浏览器' }, 'POST', false, { timeout: 10000 });
      qrStatus.value = '等待手机扫码';
      qrTimer = setInterval(checkQr, 1400);
    } catch (error) {
      qrStatus.value = error.message;
      qrOverlay.value = true;
    }
  }
  async function checkQr() {
    if (!qr.value) return;
    try {
      const result = await api('pc/qr/status', { ticket: qr.value.ticket, secret: qr.value.secret }, 'GET', false, { timeout: 8000 });
      if (result.status === 'scanned') qrStatus.value = '已扫码，请在手机上确认';
      else if (result.status === 'confirmed' && result.token) {
        if (qrTimer) clearInterval(qrTimer);
        qrTimer = null;
        setToken(result.token, result.user);
        await enterMain();
      } else if (['expired', 'cancelled', 'consumed'].includes(result.status)) {
        if (qrTimer) clearInterval(qrTimer);
        qrTimer = null;
        qrStatus.value = result.message || '二维码已失效';
        qrOverlay.value = true;
      }
    } catch (error) {
      if ([404, 409].includes(error.status)) {
        if (qrTimer) clearInterval(qrTimer);
        qrTimer = null;
        qrOverlay.value = true;
      }
    }
  }
  function stopQr() {
    if (qrTimer) clearInterval(qrTimer);
    qrTimer = null;
  }

  // 登录成功后的主流程引导（对齐原 showMain）。
  async function enterMain() {
    const ui = useUiStore();
    const conversations = useConversationsStore();
    const contacts = useContactsStore();
    const messages = useMessagesStore();
    const sync = useSync();
    stopQr();
    await loadConfig();
    const saved = String(localStorage.getItem('qm_pc_current_conversation') || '');
    await Promise.allSettled([
      loadMe(),
      conversations.load(false),
      contacts.loadFriends(false),
      contacts.loadRequests(false),
      loadPreferences(false),
      sync.bootstrap(saved)
    ]);
    ui.view = ui.view || 'chats';
    sync.start();
    if (saved && ['chats', 'groups'].includes(ui.view) && conversations.list.some(item => String(item.id) === saved)) {
      await messages.openConversation(saved, false);
    }
  }

  function logout() {
    setToken('', null);
    stopQr();
    useSync().stop();
  }

  return {
    token, user, config, license, loginError, qr, qrStatus, qrOverlay, brand, preferences,
    setToken, handleExpiredLogin, requireLicense, applyBrand, loadConfig, loadPreferences, loadMe,
    passwordLogin, startQr, checkQr, stopQr, enterMain, logout
  };
});
