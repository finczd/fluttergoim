<script setup>
import { ref, computed, onMounted, onBeforeUnmount, watch } from 'vue';
import { useUiStore } from '../stores/ui';
import { useAuthStore } from '../stores/auth';
import { useMessagesStore } from '../stores/messages';
import api from '../api/client';

// 需求11：腾讯云 TRTC Web SDK 实时音视频（不自己造轮子）
// 使用官方 trtc-js-sdk（npm 包，CDN 兜底）
let TRTC = null;
const ui = useUiStore();
const auth = useAuthStore();
const messages = useMessagesStore();

const statusText = ref('连接中…');
const localVideoRef = ref(null);
const remoteVideoRef = ref(null);
const busy = ref(true);
const muted = ref(false);
const cameraOff = ref(false);
const isVideo = computed(() => ui.call.type === 'video');
// 主叫 / 被叫：被叫要先显示"接听/拒绝"，不自动进房
const isCallee = computed(() => ui.call.role === 'callee');
const accepted = computed(() => ui.call.accepted === true);

let client = null;
let localStream = null;
let connectedAt = 0;
let ringTimer = null;
let trtcOk = false;
// initCall 是否正在进行中。被叫点「接听」时会先 markCallAccepted()、后 initCall()，
// watcher 触发时 TRTC 还没初始化完，必须区分「正在接通」和「真的没启用 TRTC」，
// 否则会误显示「通话中（模拟）」。
let trtcStarting = false;
const RING_TIMEOUT_MS = 45000;

function loadSdk() {
  return new Promise((resolve, reject) => {
    if (window.TRTC) return resolve(window.TRTC);
    // 先试 npm 包，失败用 CDN
    try {
      import('trtc-js-sdk').then(m => {
        window.TRTC = m.default || m;
        resolve(window.TRTC);
      }).catch(() => {
        const s = document.createElement('script');
        s.src = 'https://web.sdk.qcloud.com/trtc/webrtc/latest/trtc.js';
        s.onload = () => resolve(window.TRTC);
        s.onerror = () => reject(new Error('TRTC SDK 加载失败'));
        document.head.appendChild(s);
      });
    } catch (_) {
      const s = document.createElement('script');
      s.src = 'https://web.sdk.qcloud.com/trtc/webrtc/latest/trtc.js';
      s.onload = () => resolve(window.TRTC);
      s.onerror = () => reject(new Error('TRTC SDK 加载失败'));
      document.head.appendChild(s);
    }
  });
}

async function initCall() {
  trtcStarting = true;
  busy.value = true;
  try {
    TRTC = await loadSdk();
    // 从后端拉 TRTC 配置 + UserSig（后端不暴露 secretKey）
    const conf = await api('trtc/config', {}, 'GET', true);
    if (!conf || !conf.enabled) {
      statusText.value = 'TRTC 未配置（请在后台系统配置填入 SDKAppID/SecretKey）';
      busy.value = false;
      return;
    }
    const sig = await api('trtc/usersig', { room: String(ui.call.id) }, 'GET', true);
    if (!sig || !sig.userSig) {
      statusText.value = '获取音视频凭证失败';
      busy.value = false;
      return;
    }
    trtcOk = true;
    // 房间号：会话 ID 取后 8 位数字（TRTC roomId 为 number）
    const roomId = Number(String(ui.call.id).slice(-8)) || 1;
    client = TRTC.createClient({ mode: 'rtc', sdkAppId: sig.appId, userId: sig.userId, userSig: sig.userSig });
    client.on('stream-added', event => {
      const remoteStream = event.stream;
      client.subscribe(remoteStream);
    });
    client.on('stream-subscribed', event => {
      const stream = event.stream;
      stream.play(remoteVideoRef.value);
      statusText.value = '通话中';
      busy.value = false;
      connectedAt = Date.now(); // 接通时刻（通话记录时长基准）
    });
    client.on('peer-leave', () => {
      statusText.value = '对方已挂断';
      setTimeout(() => close(true), 1200);
    });
    client.on('error', err => {
      statusText.value = '通话异常：' + (err.message || '未知错误');
    });
    await client.join({ roomId });
    localStream = TRTC.createStream({ userId: sig.userId, audio: true, video: isVideo.value });
    await localStream.initialize();
    if (isVideo.value && localVideoRef.value) localStream.play(localVideoRef.value);
    await client.publish(localStream);
    // 是否已接通由上层状态决定（主叫等 accept，被叫点接听时已 accept）
    applyConnectedState();
    busy.value = false;
  } catch (e) {
    statusText.value = '通话启动失败：' + (e?.message || e || '未知');
    busy.value = false;
  } finally {
    trtcStarting = false;
  }
}

/// 根据"对方是否已接听"设置状态与计时起点
function applyConnectedState() {
  if (!accepted.value) {
    statusText.value = '等待对方接听…';
    return;
  }
  connectedAt = Date.now();
  if (trtcOk) {
    statusText.value = '通话中';
  } else if (trtcStarting) {
    // 已接听但 TRTC 还在初始化 → 不是"模拟"，别误导
    statusText.value = '正在接通…';
  } else {
    // 兜底：其余情况一律当作"正在接通"，绝不误报"模拟"
    // （只有 initCall 里明确 conf.enabled===false 才会显示"模拟"）
    statusText.value = '正在接通…';
  }
}

// 对方接听 → 主叫侧切到"通话中"并开始计时
watch(accepted, (v) => {
  if (!v || !ui.call.open) return;
  clearTimeout(ringTimer);
  applyConnectedState();
});

async function toggleMute() {
  if (!localStream) return;
  muted.value = !muted.value;
  localStream.setAudioEnabled(!muted.value);
}

async function toggleCamera() {
  if (!localStream || !isVideo.value) return;
  cameraOff.value = !cameraOff.value;
  localStream.setVideoEnabled(!cameraOff.value);
}

async function close(writeRecord = false) {
  clearTimeout(ringTimer);
  const convId = ui.call.convId;
  const wasAccepted = connectedAt > 0;
  const duration = wasAccepted ? Math.max(0, Math.round((Date.now() - connectedAt) / 1000)) : 0;
  try {
    // 通话记录：挂断时发一条 type=7 信令（含通话时长），双方会话都可见
    //  - 已接通 → hangup；未接通 → cancel
    if (writeRecord && convId) {
      messages.sendCallSignal(convId, wasAccepted ? 'hangup' : 'cancel', isVideo.value ? 'video' : 'voice', {
        roomId: String(ui.call.id),
        duration
      });
    }
    if (localStream) { localStream.close(); localStream = null; }
    if (client) { await client.leave(); client = null; }
  } catch (_) {}
  ui.closeCall();
}

/// 被叫点"接听"：发 accept 信令 → 置已接听 → 进房
async function acceptIncoming() {
  if (!ui.call.convId) return;
  busy.value = true;
  statusText.value = '正在接通…';
  await messages.sendCallSignal(ui.call.convId, 'accept', ui.call.type);
  ui.markCallAccepted();
  await initCall();
}

/// 被叫点"拒绝"：发 reject 信令 → 关闭
async function rejectIncoming() {
  if (ui.call.convId) messages.sendCallSignal(ui.call.convId, 'reject', ui.call.type);
  clearTimeout(ringTimer);
  ui.closeCall();
}

/// 主叫振铃超时：45s 无人接听 → 发 cancel 后收起
function startRingTimeout() {
  clearTimeout(ringTimer);
  ringTimer = setTimeout(() => {
    if (!ui.call.open || accepted.value) return;
    if (ui.call.convId) messages.sendCallSignal(ui.call.convId, 'cancel', ui.call.type);
    close(false);
    ui.toast('对方无应答', '', 'info');
  }, RING_TIMEOUT_MS);
}

onMounted(() => {
  if (!ui.call.open) return;
  if (isCallee.value) {
    // 被叫：等用户点接听，不自动进房
    statusText.value = '来电';
    busy.value = false;
    return;
  }
  startRingTimeout();
  initCall();
});

onBeforeUnmount(() => { close(); });
</script>

<template>
  <div v-if="ui.call.open" class="call-layer">
    <div class="call-window" :class="{ video: isVideo }">
      <!-- 本地预览（视频时小窗，语音时大头像） -->
      <div class="call-video-main">
        <video v-if="isVideo" ref="remoteVideoRef" class="remote-video" autoplay playsinline></video>
        <div v-else class="voice-avatar">{{ ui.call.title?.charAt(0) || '?' }}</div>
        <video v-if="isVideo" ref="localVideoRef" class="local-video" autoplay playsinline muted></video>
        <div v-else class="voice-info">
          <strong>{{ ui.call.title }}</strong>
          <span>{{ statusText }}</span>
        </div>
      </div>
      <!-- 被叫未接听：显示拒绝 / 接听 -->
      <div v-if="isCallee && !accepted" class="call-controls">
        <button class="call-btn danger" type="button" @click="rejectIncoming" title="拒绝">
          <svg><use href="#i-phone-off" /></svg>
        </button>
        <button class="call-btn accept" type="button" @click="acceptIncoming" title="接听">
          <svg><use :href="isVideo ? '#i-video' : '#i-phone'" /></svg>
        </button>
      </div>
      <!-- 已接通 / 主叫：静音 · 摄像头 · 挂断 -->
      <div v-else class="call-controls">
        <button class="call-btn" type="button" :class="{ active: muted }" @click="toggleMute" title="静音">
          <svg><use :href="muted ? '#i-mic-off' : '#i-mic'" /></svg>
        </button>
        <button v-if="isVideo" class="call-btn" type="button" :class="{ active: cameraOff }" @click="toggleCamera" title="摄像头">
          <svg><use :href="cameraOff ? '#i-camera-off' : '#i-camera'" /></svg>
        </button>
        <button class="call-btn danger" type="button" @click="close(true)" title="挂断">
          <svg><use href="#i-phone-off" /></svg>
        </button>
      </div>
      <div class="call-status">{{ statusText }}</div>
    </div>
  </div>
</template>

<style scoped>
.call-layer { position: fixed; inset: 0; z-index: 9999; background: rgba(0,0,0,.6); display: flex; align-items: center; justify-content: center; }
.call-window { width: min(720px, 90vw); height: min(480px, 80vh); background: #0f1419; border-radius: 16px; overflow: hidden; position: relative; display: flex; flex-direction: column; }
.call-window.video { background: #000; }
.call-video-main { flex: 1; position: relative; }
.remote-video { width: 100%; height: 100%; object-fit: cover; }
.local-video { position: absolute; right: 16px; bottom: 16px; width: 160px; border-radius: 10px; border: 2px solid rgba(255,255,255,.3); object-fit: cover; background: #333; }
.voice-avatar { width: 96px; height: 96px; border-radius: 50%; background: #0088cc; color: #fff; font-size: 40px; display: flex; align-items: center; justify-content: center; position: absolute; top: 50%; left: 50%; transform: translate(-50%, -70%); }
.voice-info { position: absolute; top: calc(50% + 40px); left: 0; right: 0; text-align: center; color: #fff; display: flex; flex-direction: column; gap: 8px; }
.voice-info strong { font-size: 20px; }
.voice-info span { font-size: 14px; color: rgba(255,255,255,.7); }
.call-status { position: absolute; bottom: 72px; left: 0; right: 0; text-align: center; color: rgba(255,255,255,.8); font-size: 14px; }
.call-controls { position: absolute; bottom: 16px; left: 0; right: 0; display: flex; justify-content: center; gap: 24px; }
.call-btn { width: 52px; height: 52px; border-radius: 50%; border: 0; background: rgba(255,255,255,.15); color: #fff; display: flex; align-items: center; justify-content: center; cursor: pointer; transition: .2s; }
.call-btn:hover { background: rgba(255,255,255,.3); }
.call-btn.active { background: rgba(255, 193, 7, .8); }
.call-btn.danger { background: #e02f2f; }
.call-btn.accept { background: #34c759; }
.call-btn svg { width: 22px; height: 22px; }
</style>
