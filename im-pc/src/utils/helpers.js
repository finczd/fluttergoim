// 通用 helper：设备标识、随机数、sleep、localStorage 键名（与编译版一致，便于复用已有登录态）。

export const TOKEN_KEY = 'zclm_pc_token';
export const DEVICE_KEY = 'zclm_pc_device';
export const VIEW_KEY = 'qm_pc_view';
export const CONVERSATION_KEY = 'qm_pc_current_conversation';
export const THEME_KEY = 'qm_pc_theme';
export const SYNC_MESSAGE_KEY = 'qm_pc_sync_message_cursor';
export const SYNC_EVENT_KEY = 'qm_pc_sync_event_cursor';
export const DRAFT_CACHE_KEY = 'qm_pc_draft_cache';
export const EMOJIS = ['😀', '😄', '😁', '😂', '😊', '😍', '🥰', '😘', '😎', '🤔', '😅', '😭', '😡', '👍', '👏', '🙏', '💪', '🎉', '❤️', '💙', '🔥', '✨', '✅', '👀', '🙌', '🤝', '🌹', '🎁', '🍵', '☕', '📌', '💡'];

export function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

export function cryptoRandom(length = 24) {
  const bytes = new Uint8Array(Math.ceil(length / 2));
  crypto.getRandomValues(bytes);
  return Array.from(bytes, value => value.toString(16).padStart(2, '0')).join('').slice(0, length);
}

export function deviceId() {
  let id = localStorage.getItem(DEVICE_KEY);
  if (!id) {
    id = 'pc_' + cryptoRandom(24);
    localStorage.setItem(DEVICE_KEY, id);
  }
  return id;
}
