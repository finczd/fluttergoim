<script setup>
import { ref, computed, onMounted } from 'vue';
import { useAuthStore } from '../stores/auth';
import api from '../api/client';
import Avatar from './Avatar.vue';
import { markTransferClaimed, isTransferClaimed } from '../composables/useTransferClaimed';

const props = defineProps({ message: { type: Object, required: true } });
const emit = defineEmits(['close']);
const auth = useAuthStore();

const isRed = computed(() => props.message.type === 'redpacket');
const myId = computed(() => String(auth.user?.id || ''));
const isSender = computed(() => !!props.message.is_mine);

const data = computed(() => {
  try { return JSON.parse(props.message.content || '{}'); } catch (_) { return {}; }
});

function formatAmount(v) {
  return '¥' + Number(v || 0).toFixed(2);
}

// ============ 红包 ============
const rpDetail = ref(null);
const rpLoading = ref(false);
const rpError = ref('');
const rpMyAmount = ref(0);
const busy = ref(false);

const rpClaimedByMe = computed(() => {
  const list = rpDetail.value?.list || [];
  return list.some(c => String(c.userId) === myId.value);
});
const rpClaimedUp = computed(() => {
  if (!rpDetail.value) return false;
  return Number(rpDetail.value.claimedCnt || 0) >= Number(rpDetail.value.count || 0);
});
// 资金包状态（B-22）：1进行中 2已领完 3已过期退回 4已关闭（旧版本遗留数据）
const rpStatus = computed(() => Number(rpDetail.value?.status || 0));
const rpExpired = computed(() => rpStatus.value === 3);
const rpClosed = computed(() => rpStatus.value === 4);
const rpRemain = computed(() => {
  const total = Number(rpDetail.value?.totalAmount || 0);
  const claimed = Number(rpDetail.value?.claimedSum || 0);
  return Math.max(0, Math.round((total - claimed) * 100) / 100);
});
const rpCanClaim = computed(() => {
  if (!rpDetail.value || isSender.value || rpClaimedByMe.value) return false;
  if (rpExpired.value || rpClosed.value) return false;
  return Number(rpDetail.value.claimedCnt || 0) < Number(rpDetail.value.count || 0);
});

async function openRedPacket() {
  if (busy.value) return;
  busy.value = true;
  rpError.value = '';
  try {
    const r = await api('wallet/redpacket/claim', { msg_id: String(props.message.id) }, 'POST');
    rpDetail.value = r || {};
    rpMyAmount.value = Number(r?.myAmount || 0);
  } catch (e) {
    rpError.value = e.message || '领取失败';
  } finally {
    busy.value = false;
  }
}

// ============ 转账 ============
const trIsReceiver = computed(() => {
  const toId = data.value.toUserId ? String(data.value.toUserId) : '';
  return toId ? toId === myId.value : !isSender.value;
});
const trClaimed = computed(() => isTransferClaimed(props.message.id));
const trError = ref('');
const trMyAmount = ref(Number(data.value.amount || 0)); // 实际到账金额（以服务端返回为准）

async function confirmTransfer() {
  if (busy.value) return;
  busy.value = true;
  trError.value = '';
  try {
    // B-21：只传消息 ID，金额由服务端从转账消息内容核算（客户端上报金额不可信），
    // 服务端同时校验会话成员身份 + 唯一索引去重，清缓存也领不了第二次。
    const r = await api('wallet/transfer/accept', { msg_id: String(props.message.id) }, 'POST');
    trMyAmount.value = Number(r?.amount || 0);
    markTransferClaimed(String(props.message.id));
  } catch (e) {
    trError.value = e.message || '收款失败';
  } finally {
    busy.value = false;
  }
}

onMounted(async () => {
  if (isRed.value) {
    rpLoading.value = true;
    try {
      const r = await api('wallet/redpacket/detail', { msg_id: String(props.message.id) }, 'GET');
      rpDetail.value = r || {};
    } catch (e) {
      rpError.value = e.message || '加载失败';
    } finally {
      rpLoading.value = false;
    }
  }
});
</script>

<template>
  <div class="modal-mask" @click.self="emit('close')">
    <div class="money-modal" :class="isRed ? 'money-modal-red' : 'money-modal-transfer'">
      <button class="money-modal-close" type="button" title="关闭" @click="emit('close')">
        <svg><use href="#i-close" /></svg>
      </button>

      <!-- 红包 -->
      <template v-if="isRed">
        <div class="money-modal-head">
          <Avatar :user="{ nickname: rpDetail?.senderName || message.sender_name, avatar: rpDetail?.senderAvatar || message.sender_avatar }" size="medium" />
          <div class="money-modal-head-text">
            <div class="money-modal-sender">{{ rpDetail?.senderName || message.sender_name || '用户' }} 的红包</div>
            <div class="money-modal-note">{{ data.note || '恭喜发财，大吉大利' }}</div>
          </div>
        </div>

        <div v-if="rpLoading" class="money-modal-loading">加载中…</div>
        <div v-else-if="rpError" class="money-modal-error">{{ rpError }}</div>

        <div v-else class="money-modal-body">
          <template v-if="rpCanClaim">
            <div class="money-amount-big">{{ formatAmount(data.amount) }}</div>
            <button class="money-open-btn" type="button" :disabled="busy" @click="openRedPacket">開</button>
          </template>
          <template v-else>
            <div v-if="rpClaimedByMe" class="money-amount-big">{{ formatAmount(rpMyAmount) }}</div>
            <div class="money-status-line">
              <span v-if="rpExpired">红包已超过 24 小时未领完，剩余 {{ formatAmount(rpRemain) }} 元已退回</span>
              <span v-else-if="rpClosed">该红包为旧版本数据，已停止领取</span>
              <span v-else-if="isSender">你的红包已被领取 {{ rpDetail.claimedCnt }}/{{ rpDetail.count }}</span>
              <span v-else-if="rpClaimedByMe">你领取了红包</span>
              <span v-else-if="rpClaimedUp">红包已被领完</span>
            </div>
            <div v-if="rpStatus === 1 && rpDetail?.expireAt" class="money-status-line">
              {{ rpDetail.expireAt }} 前未领完将自动退回
            </div>
            <div v-if="rpDetail?.list && rpDetail.list.length" class="money-claim-list">
              <div v-for="c in rpDetail.list" :key="c.userId" class="money-claim-row">
                <Avatar :user="{ nickname: c.userName, avatar: c.avatar }" size="small" />
                <span class="money-claim-name">{{ c.userName || '用户' }}</span>
                <span class="money-claim-amt">{{ formatAmount(c.amount) }}</span>
              </div>
            </div>
          </template>
        </div>
      </template>

      <!-- 转账 -->
      <template v-else>
        <div class="money-modal-head">
          <div class="money-modal-head-text">
            <div class="money-modal-sender">{{ trIsReceiver ? '收款' : '转账' }}</div>
            <div class="money-modal-note">{{ data.note || '' }}</div>
          </div>
        </div>
        <div class="money-modal-body">
          <!-- 已收款时展示服务端实际入账金额，便于和消息里的金额交叉核对 -->
          <div class="money-amount-big">{{ formatAmount(trClaimed ? trMyAmount : data.amount) }}</div>
          <template v-if="trIsReceiver">
            <div v-if="trClaimed" class="money-status-line money-status-done">已收款</div>
            <button v-else class="money-open-btn" type="button" :disabled="busy" @click="confirmTransfer">确认收款</button>
          </template>
          <div v-else class="money-status-line">{{ isSender ? '已转账，等待对方确认收款' : '转账' }}</div>
          <div v-if="trError" class="money-modal-error">{{ trError }}</div>
        </div>
      </template>
    </div>
  </div>
</template>
