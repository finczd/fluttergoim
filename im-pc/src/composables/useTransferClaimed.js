// 已收款的转账消息本地标记（localStorage 持久化，跨刷新保留）。
// 后端对转账没有"按领取人"的已领状态返回，故在客户端落盘标记。
import { reactive, watch } from 'vue';

const KEY = 'qm_pc_transfer_claimed';

function load() {
  try {
    const v = JSON.parse(localStorage.getItem(KEY) || '{}');
    return v && typeof v === 'object' ? v : {};
  } catch (_) {
    return {};
  }
}

export const claimedMap = reactive(load());

watch(claimedMap, () => {
  try { localStorage.setItem(KEY, JSON.stringify(claimedMap)); } catch (_) {}
}, { deep: true });

export function markTransferClaimed(msgId) {
  if (msgId) claimedMap[String(msgId)] = true;
}

export function isTransferClaimed(msgId) {
  return !!claimedMap[String(msgId)];
}
