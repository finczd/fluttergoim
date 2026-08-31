// 纯展示工具函数：从编译版 app.js 1:1 移植，保持行为一致。

export function esc(value) {
  return String(value ?? '').replace(/[&<>'"]/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;' }[char]));
}

export function attr(value) {
  return esc(value).replace(/`/g, '&#96;');
}

export function initials(value) {
  return Array.from(String(value || '用').trim())[0] || '用';
}

export function replyPreview(reply) {
  if (!reply) return '';
  const map = {
    image: '[图片]',
    file: '[文件] ' + (reply.file_name || ''),
    voice: '[语音]',
    video: '[视频]',
    location: '[位置]',
    card: '[名片]',
    system: '[系统消息]'
  };
  const text = map[reply.type] || reply.content || '消息';
  return String(text).replace(/\s+/g, ' ').slice(0, 45);
}

export function asset(value) {
  if (!value) return '';
  let raw = String(value);
  if (/^https?:\/\//i.test(raw)) {
    // 需求2修复：存量消息里的 localhost:9000（MinIO）对手机/局域网不可达 → 换成当前访问主机
    if (/localhost|127\.0\.0\.1/.test(raw)) {
      raw = raw.replace(/localhost|127\.0\.0\.1/, window.location.hostname || 'localhost');
    }
    return raw;
  }
  // 所有非 http(s) 路径都拼到站点 origin 根目录下
  // （无论页面在 /pc/ 还是 /pc-vue-test/，资源都在 /admin/、/uploads/ 等根路径下）
  const rel = raw.replace(/^\/+/, '');
  return new URL(rel, window.location.origin + '/').href;
}

export function avatarStyle(value) {
  const url = asset(value);
  return url ? `style="background-image:url('${attr(url.replace(/'/g, '%27'))}');font-size:0"` : '';
}

// 生成头像 DOM（用于 innerHTML 拼接的场景，如 pinned、inspector）。
export function avatarHtml(user = {}, size = 'medium', extra = '') {
  const name = user.remark || user.alias || user.nickname || user.title || '用户';
  const avatar = user.avatar || user.sender_avatar || '';
  const members = Array.isArray(user.avatar_members) ? user.avatar_members.filter(Boolean).slice(0, 9) : [];
  if (!avatar && members.length) {
    const cells = members.map(member => {
      const url = asset(member.avatar || '');
      return `<i ${url ? `style="background-image:url('${attr(url.replace(/'/g, '%27'))}')"` : ''}>${url ? '' : esc(initials(member.nickname || member.name || '用户'))}</i>`;
    }).join('');
    return `<span class="avatar ${size} ${extra} group-mosaic count-${members.length}">${cells}</span>`;
  }
  return `<span class="avatar ${size} ${extra}" ${avatarStyle(avatar)}>${esc(initials(name))}</span>`;
}

export function normalizeDate(value) {
  if (!value) return null;
  const date = new Date(String(value).replace(' ', 'T'));
  return Number.isNaN(date.getTime()) ? null : date;
}

export function timeText(value, full = false) {
  const date = normalizeDate(value);
  if (!date) return '';
  if (full) return date.toLocaleString('zh-CN', { year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' });
  const now = new Date();
  if (now.toDateString() === date.toDateString()) return date.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' });
  const yesterday = new Date(now);
  yesterday.setDate(now.getDate() - 1);
  if (yesterday.toDateString() === date.toDateString()) return '昨天';
  if (now.getFullYear() === date.getFullYear()) return `${date.getMonth() + 1}/${date.getDate()}`;
  return `${date.getFullYear()}/${date.getMonth() + 1}/${date.getDate()}`;
}

export function dayText(value) {
  const date = normalizeDate(value);
  if (!date) return '';
  const now = new Date();
  if (now.toDateString() === date.toDateString()) return '今天';
  const yesterday = new Date(now);
  yesterday.setDate(now.getDate() - 1);
  if (yesterday.toDateString() === date.toDateString()) return '昨天';
  return date.toLocaleDateString('zh-CN', { year: 'numeric', month: 'long', day: 'numeric' });
}

export function formatBytes(bytes) {
  const n = Number(bytes || 0);
  if (!n) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB'];
  let i = 0;
  let value = n;
  while (value >= 1024 && i < units.length - 1) {
    value /= 1024;
    i++;
  }
  return `${value >= 10 || i === 0 ? value.toFixed(0) : value.toFixed(1)} ${units[i]}`;
}

export function preview(message) {
  if (!message) return '暂无消息';
  if (Number(message.status) === 2) return '一条消息已撤回';
  if (message.type === 'card') {
    const extra = message.extra || {};
    if (extra.card_type === 'voice_call') return '[语音通话]';
    if (extra.card_type === 'video_call') return '[视频通话]';
  }
  if (message.type === 'call') {
    let sig = {};
    try { sig = typeof message.content === 'string' ? JSON.parse(message.content) : (message.content || {}); } catch (_) {}
    const action = sig.action || 'hangup';
    const callType = sig.callType === 'video' ? '视频' : '语音';
    const duration = Number(sig.duration || 0);
    const durText = duration > 0 ? ` ${formatDuration(duration)}` : '';
    if (action === 'invite') return `[${callType}通话 未接]`;
    if (action === 'cancel') return `[${callType}通话 已取消]`;
    if (action === 'reject') return `[${callType}通话 已拒绝]`;
    return `[${callType}通话${durText}]`;
  }
  if (message.type === 'redpacket' || message.type === 'transfer') {
    let data = {};
    try { data = typeof message.content === 'string' ? JSON.parse(message.content) : (message.content || {}); } catch (_) {}
    const note = (data && data.note) || '';
    if (message.type === 'redpacket') return note ? `[红包] ${note}` : '[红包]';
    const amount = Number((data && data.amount) || 0);
    return note ? `[转账] ${note}` : `[转账] ¥${amount}`;
  }
  return ({ image: '[图片]', file: '[文件]', voice: '[语音]', video: '[视频]', location: '[位置]', card: '[卡片]', system: '[系统消息]' }[message.type] || message.content || '新消息');
}

function formatDuration(seconds) {
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  if (m > 0) return `${m}:${String(s).padStart(2, '0')}`;
  return `${s}秒`;
}
