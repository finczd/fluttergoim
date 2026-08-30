<script setup>
import { ref, computed, onMounted, onBeforeUnmount } from 'vue';
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

let client = null;
let localStream = null;

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
    });
    client.on('peer-leave', () => {
      statusText.value = '对方已挂断';
      setTimeout(close, 1200);
    });
    client.on('error', err => {
      statusText.value = '通话异常：' + (err.message || '未知错误');
    });
    await client.join({ roomId });
    localStream = TRTC.createStream({ userId: sig.userId, audio: true, video: isVideo.value });
    await localStream.initialize();
    if (isVideo.value && localVideoRef.value) localStream.play(localVideoRef.value);
    await client.publish(localStream);
    statusText.value = '等待对方接听…';
    busy.value = false;
  } catch (e) {
    statusText.value = '通话启动失败：' + (e?.message || e || '未知');
    busy.value = false;
  }
}

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

async function close() {
  try {
    if (localStream) { localStream.close(); localStream = null; }
    if (client) { await client.leave(); client = null; }
  } catch (_) {}
  ui.closeCall();
}

onMounted(() => { if (ui.call.open) initCall(); });
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
      <div class="call-controls">
        <button class="call-btn" type="button" :class="{ active: muted }" @click="toggleMute" title="静音">
          <svg><use :href="muted ? '#i-mic-off' : '#i-mic'" /></svg>
        </button>
        <button v-if="isVideo" class="call-btn" type="button" :class="{ active: cameraOff }" @click="toggleCamera" title="摄像头">
          <svg><use :href="cameraOff ? '#i-camera-off' : '#i-camera'" /></svg>
        </button>
        <button class="call-btn danger" type="button" @click="close" title="挂断">
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
.call-btn svg { width: 22px; height: 22px; }
</style>
