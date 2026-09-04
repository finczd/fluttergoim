// 本地消息缓存：PC 端每次进入会话都全量拉取，这里做一层 localStorage 缓存，
// 进会话先同步渲染缓存、再被网络数据覆盖，避免白屏等待。
const PREFIX = 'qm_pc_msg_';
const MAX_PER_CONV = 200; // 单会话上限，超出只保留最近 200 条
const FALLBACK = 100;     // 配额超限时的兜底条数

export function cacheKey(id) {
  return PREFIX + id;
}

export function loadCache(id) {
  try {
    const raw = localStorage.getItem(cacheKey(id));
    if (!raw) return [];
    const arr = JSON.parse(raw);
    return Array.isArray(arr) ? arr : [];
  } catch (_) {
    return [];
  }
}

export function saveCache(id, list) {
  if (!id) return;
  const arr = Array.isArray(list) ? list : [];
  // 不缓存本地草稿 / 失败消息（id 以 local_ 开头），避免重进会话看到“发送中/失败”
  let out = arr.filter(m => m && !String(m.id || '').startsWith('local_'));
  if (out.length > MAX_PER_CONV) out = out.slice(out.length - MAX_PER_CONV);
  try {
    localStorage.setItem(cacheKey(id), JSON.stringify(out));
  } catch (_) {
    // 配额超限：降到兜底条数再试一次
    try {
      if (out.length > FALLBACK) out = out.slice(out.length - FALLBACK);
      localStorage.setItem(cacheKey(id), JSON.stringify(out));
    } catch (_) {}
  }
}

export function clearAllMessageCaches() {
  try {
    const keys = [];
    for (let i = 0; i < localStorage.length; i++) {
      const k = localStorage.key(i);
      if (k && k.indexOf(PREFIX) === 0) keys.push(k);
    }
    keys.forEach(k => {
      try { localStorage.removeItem(k); } catch (_) {}
    });
  } catch (_) {}
}
