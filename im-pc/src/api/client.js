// API 适配层：把青鸟 IM PC 版（im-pc）的 PHP 契约适配到当前 Go 后端。
// 设计原则：组件/Store 的调用方式不变（api('auth/login', ...)），
// 只在这里做「路径映射 + 参数转换 + 响应转换」，ID 全程字符串防雪花精度丢失。
import { useAuthStore } from '../stores/auth';
import { deviceId } from '../utils/helpers';

// ====================== 基础配置 ======================
// Go 后端网关地址：开发走 vite 代理（/api → 8080），生产走 nginx 同源反代
const API = import.meta.env.VITE_API_BASE || '/api/v1';
const WS = import.meta.env.VITE_WS_BASE || '/ws';

// ====================== 工具 ======================

/** 消息类型映射：Go 数字类型 → 青鸟字符串类型 */
function goTypeToStr(t) {
  return ({ 1: 'text', 2: 'image', 3: 'file', 4: 'voice', 5: 'video', 6: 'system', 7: 'call', 8: 'redpacket', 9: 'transfer' })[Number(t)] || 'text';
}

/** 青鸟字符串类型 → Go 数字类型 */
function strTypeToGo(t) {
  return ({ text: 1, image: 2, file: 3, voice: 4, video: 5, system: 6, card: 6, call: 7, redpacket: 8, transfer: 9 })[t] || 1;
}

/** Go 消息对象 → 青鸟消息字段（组件/Store 期望的契约） */
function goMsgToQm(m, myId = '') {
  if (!m) return null;
  const file = m.file || {};
  // 引用：仅 replyTo 有效（非 0/空/undefined）才带（修复"所有消息都是引用"）
  const hasReply = m.replyTo !== undefined && m.replyTo !== null && String(m.replyTo) !== '0' && String(m.replyTo) !== '';
  // 引用快照：后端发送时冗余存了被引用消息内容/发送者
  const snap = m.replySnapshot || {};
  return {
    id: String(m.msgId ?? m.id ?? ''),
    msg_id: String(m.msgId ?? m.id ?? ''),
    client_msg_id: m.clientMsgId || '',
    conversation_id: String(m.conversationId ?? ''),
    sender_id: String(m.senderId ?? ''),
    sender_name: String(m.senderId ?? '') === '-1' ? '小助手' : (m.senderName || ''),
    type: goTypeToStr(m.type),
    content: m.content || '',
    file_url: file.url || m.fileUrl || '',
    file_name: file.name || m.fileName || '',
    file_size: Number(file.size || 0),
    duration: Number(file.duration || m.duration || 0),
    extra: m.file || m.extra || {},
    reply: hasReply
      ? {
          id: String(m.replyTo),
          sender_name: snap.senderName || '',
          type: goTypeToStr(snap.type),
          content: snap.content || '[消息]',
          file_name: snap.fileName || ''
        }
      : null,
    reply_to_id: hasReply ? String(m.replyTo) : 0,
    status: m.recalled ? 2 : 1,
    is_mine: myId ? String(m.senderId ?? '') === String(myId) : false,
    delivery_state: m.deliveryState || '',
    seq: m.seq || 0,
    created_at: (m.createdAt || '').replace('T', ' ').slice(0, 19),
    local_status: ''
  };
}

/** Go 会话对象 → 青鸟会话字段 */
function goConvToQm(item, myId = '') {
  const conv = item.conversation || {};
  const isGroup = Number(conv.type) === 2;
  // 在线状态：单聊对方在线设备（web/ios/android/windows/macos）
  const peerOnline = !!item.peerOnline;
  const peerDev = Array.isArray(item.peerOnlineDev) ? item.peerOnlineDev : [];
  const isPhoneOnline = peerDev.some(d => d === 'ios' || d === 'android');
  // 后端透传的设备中文类型（手机在线/H5在线/电脑在线），前端兜底再算一次
  const onlineZh = item.peerOnlineZh || (peerOnline ? (isPhoneOnline ? '手机在线' : '电脑在线') : '离线');
  const onlineIps = Array.isArray(item.peerOnlineIp) ? item.peerOnlineIp : [];
  return {
    id: String(conv.id ?? ''),
    title: item.conversationName || conv.nameZh || (isGroup ? '群聊' : '会话'),
    type: isGroup ? 'group' : 'direct',
    unread_count: Number(item.unread || 0),
    last_message: goMsgToQm(item.lastMessage, myId),
    member_count_cache: Number(item.memberCount || 0),
    mute: !!item.mute,
    pinned: !!item.pinned,
    peer: {
      id: String(item.peerId ?? ''),
      nickname: isGroup ? '' : (item.conversationName || ''),
      avatar: conv.avatar || '',
      // 需求1：单聊对方账号为空时回退显示短 id
      short_id: item.peerShortId || '',
      public_id: item.peerAccount || '',
      is_online: peerOnline,
      online_device: peerDev,
      online_text: peerOnline ? onlineZh : '离线',
      online_zh: onlineZh,
      online_ip: onlineIps
    },
    avatar: conv.avatar || '',
    owner_id: conv.ownerId ? String(conv.ownerId) : '',
    conversation: conv
  };
}

/** Go 用户对象 → 青鸟用户字段 */
function goUserToQm(u) {
  if (!u) return null;
  return {
    id: String(u.id ?? ''),
    username: u.account || u.username || '',
    public_id: u.account || u.public_id || '',
    // 需求1：账号为空时回退显示短 id（靓号），由资料接口 shortId 字段透传
    short_id: u.shortId || '',
    nickname: u.nickname || u.account || '',
    avatar: u.avatar || '',
    phone: u.phone || '',
    email: u.email || '',
    bio: u.bio || '',
    region: u.region || '',
    online_text: u.onlineText || (u.isOnline ? '在线' : '离线'),
    is_online: !!u.isOnline,
    is_agent: u.isAgent ? 1 : 0,
    // 需求5修复：群成员 role（1=群主 2=管理员 3=成员）必须透传，否则前端无法判断管理权限
    role: (u.role !== undefined && u.role !== null) ? Number(u.role) : 3
  };
}

/** Go 好友申请 → 青鸟申请字段 */
function goRequestToQm(r) {
  if (!r) return null;
  const fromId = String(r.fromUser ?? r.fromUserId ?? '');
  return {
    id: String(r.id ?? ''),
    from_user_id: fromId,
    to_user_id: String(r.toUser ?? r.toUserId ?? ''),
    sender_id: fromId,
    sender_name: r.fromUserName || r.nickname || '用户',
    sender_avatar: r.fromUserAvatar || '',
    sender_account: r.fromUserAccount || '',
    message: r.message || '',
    status: Number(r.status ?? 0),
    created_at: (r.createdAt || '').replace('T', ' ').slice(0, 19)
  };
}

/** Go 朋友圈对象 → 前端朋友圈字段（兼容 list 的 momentOut 结构 与 publish 返回的原始模型） */
function momentOut(m, myId = '') {
  if (!m) return null;
  let images = [];
  if (Array.isArray(m.images)) images = m.images;
  else if (typeof m.images === 'string' && m.images) {
    try { images = JSON.parse(m.images); } catch (_) { images = []; }
  }
  const senderId = String(m.userId ?? m.user_id ?? '');
  const auth = useAuthStore();
  const isMine = !!m.mine || (myId && senderId && String(senderId) === String(myId));
  return {
    id: String(m.id ?? ''),
    user_id: senderId,
    sender_name: m.senderName || m.sender_name ||
      (senderId === '-1' ? '小助手' : (isMine ? (auth.user?.nickname || '') : '')),
    sender_avatar: m.senderAvatar || m.sender_avatar ||
      (isMine ? (auth.user?.avatar || '') : ''),
    assistant: !!m.assistant || senderId === '-1',
    content: m.content || '',
    images: Array.isArray(images) ? images : [],
    like_count: Number(m.likeCount ?? m.like_count ?? 0),
    liked: !!m.liked,
    hidden: !!m.hidden,
    mine: isMine,
    created_at: (m.createdAt || m.created_at || '').replace('T', ' ').slice(0, 19)
  };
}

/** 朋友圈列表响应 → {total, list} */
function momentListOut(r, myId = '') {
  if (!r) return { total: 0, list: [] };
  const list = Array.isArray(r.list) ? r.list : (Array.isArray(r) ? r : []);
  return {
    total: Number(r.total ?? list.length ?? 0),
    list: list.map(m => momentOut(m, myId)).filter(Boolean)
  };
}

// ====================== HTTP 核心 ======================

async function http(path, data = {}, method = 'GET', auth = true, options = {}) {
  const authStore = useAuthStore();
  const headers = {
    'Content-Type': 'application/json',
    'X-Client-Platform': 'web-pc',
    'X-Device-ID': deviceId()
  };
  if (auth && authStore.token) headers.Authorization = 'Bearer ' + authStore.token;

  const query = method === 'GET' && Object.keys(data).length
    ? '?' + new URLSearchParams(Object.entries(data).reduce((acc, [k, v]) => {
        acc[k] = v == null ? '' : String(v);
        return acc;
      }, {})).toString()
    : '';
  const controller = options.timeout ? new AbortController() : null;
  const timer = controller ? setTimeout(() => controller.abort(), options.timeout) : null;
  try {
    const response = await fetch(API + path + query, {
      method,
      headers,
      body: method === 'GET' ? undefined : JSON.stringify(data),
      signal: controller?.signal,
      cache: 'no-store'
    });
    const body = await response.json().catch(() => null);
    if (!response.ok || !body || body.code !== 0) {
      if (response.status === 401 && auth) authStore.handleExpiredLogin();
      const error = new Error(body?.message || `请求失败（${response.status}）`);
      error.status = response.status;
      error.apiCode = body?.code;
      error.data = body?.data;
      throw error;
    }
    return body.data;
  } catch (error) {
    if (error?.name === 'AbortError') {
      const e = new Error('请求超时，请检查网络连接');
      e.status = 408;
      throw e;
    }
    throw error;
  } finally {
    if (timer) clearTimeout(timer);
  }
}

// ====================== 路径映射 + 响应转换 ======================

/**
 * 统一入口：青鸟 API 路径 → 当前 Go 后端。
 * 未覆盖的路径保持原样（返回空/兜底），保证 Store 层不报错。
 */
async function api(path, data = {}, method = 'GET', auth = true, options = {}) {
  const myId = String(useAuthStore().user?.id || '');

  switch (path) {
    // ---------- 认证 ----------
    case 'auth/login': {
      const r = await http('/auth/login', { account: data.account, password: data.password, deviceType: 3 }, 'POST', false, options);
      return { token: r.accessToken, refresh_token: r.refreshToken, user: goUserToQm(r.user) };
    }
    case 'auth/captcha': {
      // 图形验证码：返回 { captchaId, image(base64) }
      return await http('/auth/captcha', {}, 'GET', false, options);
    }
    case 'auth/send-code': {
      // 发送短信/邮箱验证码（注册用，需先通过图形验证码）
      return await http('/auth/send-code', {
        account: data.account,
        countryCode: data.countryCode || '+86',
        captchaId: data.captchaId || '',
        captchaCode: data.captchaCode || ''
      }, 'POST', false, options);
    }
    case 'auth/register': {
      const r = await http('/auth/register', {
        account: data.account,
        password: data.password,
        nickname: data.nickname || '',
        countryCode: data.countryCode || '+86',
        departmentId: data.departmentId || 0,
        code: data.code || '',
        inviteCode: data.inviteCode || '',
        captchaId: data.captchaId || '',
        captchaCode: data.captchaCode || '',
        deviceId: deviceId(),
        deviceType: 3
      }, 'POST', false, options);
      return { token: r.accessToken, refresh_token: r.refreshToken, user: goUserToQm(r.user) };
    }
    case 'system/config': {
      try {
        const r = await http('/auth/config', {}, 'GET', false, options);
        const c = r || {};
        return {
          app_name: c.appName || c.app_name || 'ChatPulse',
          brand_name: c.appName || c.app_name || 'ChatPulse',
          brand_short_name: c.brandShortName || c.brand_short_name || 'ChatPulse',
          brand_mark: c.brandMark || c.brand_mark || 'C',
          brand_logo: c.brandLogo || c.brand_logo || '',
          register_enabled: c.registerEnabled ?? true
        };
      } catch (_) {
        return { app_name: 'ChatPulse', brand_name: 'ChatPulse', brand_short_name: 'ChatPulse', brand_mark: 'C', brand_logo: '', register_enabled: true };
      }
    }
    // ---------- 实时音视频（TRTC）----------
    case 'trtc/config': {
      const r = await http('/trtc/config', {}, 'GET', false, options);
      return { enabled: !!r?.enabled, appId: r?.appId || 0, sdkUrl: r?.sdkUrl || '' };
    }
    case 'trtc/usersig': {
      const r = await http('/trtc/usersig?room=' + encodeURIComponent(data?.room || ''), {}, 'GET', auth, options);
      return { appId: r?.appId || 0, userId: r?.userId || '', userSig: r?.userSig || '', expire: r?.expire || 0 };
    }
    case 'me': {
      const r = await http('/user/profile', {}, 'GET', auth, options);
      return goUserToQm(r);
    }
    case 'me/preferences': {
      if (method === 'POST') {
        // 本地持久化主题，无后端偏好接口
        try { localStorage.setItem('qm_pc_preferences', JSON.stringify(data || {})); } catch (_) {}
        return { theme: data.theme || 'system' };
      }
      try {
        const saved = JSON.parse(localStorage.getItem('qm_pc_preferences') || '{}');
        return saved;
      } catch (_) { return {}; }
    }
    case 'me/media':
      // 后端暂无媒体库接口，返回空
      return [];

    // ---------- 会话 ----------
    case 'conversations': {
      const list = await http('/conversation/list', {}, 'GET', auth, options);
      return (Array.isArray(list) ? list : []).map(item => goConvToQm(item, myId));
    }
    case 'conversations/direct': {
      const r = await http('/conversation/direct', { userId: String(data.user_id) }, 'POST', auth, options);
      return goConvToQm({ conversation: r, unread: 0, memberCount: 2, peerId: String(data.user_id) }, myId);
    }
    case 'conversations/bootstrap': {
      const id = String(data.conversation_id ?? '');
      // 1) 会话详情
      let detail = null;
      try {
        const convs = await http('/conversation/list', {}, 'GET', auth, options);
        const found = (Array.isArray(convs) ? convs : []).find(c => String(c.conversation?.id) === id);
        detail = found ? goConvToQm(found, myId) : null;
      } catch (_) {}
      // 2) 最近消息
      let messages = [];
      try {
        const rows = await http('/message/history', { convId: id, beforeMsgId: 0, limit: 50 }, 'GET', auth, options);
        messages = (Array.isArray(rows) ? rows : []).map(m => goMsgToQm(m, myId)).filter(Boolean);
      } catch (_) {}
      // 3) 群成员
      let members = [];
      try {
        if (detail?.type === 'group') {
          const ms = await http(`/conversation/${id}/members`, {}, 'GET', auth, options);
          members = (Array.isArray(ms) ? ms : []).map(goUserToQm).filter(Boolean);
          detail = { ...detail, members };
        }
      } catch (_) {}
      // 4) 置顶消息列表（多条）
      let pins = [];
      try {
        const ids = await http(`/conversation/${id}/pins`, {}, 'GET', auth, options);
        if (Array.isArray(ids) && ids.length) {
          pins = messages.filter(m => ids.includes(String(m.id)) || ids.includes(String(m.message_id)));
        }
      } catch (_) {}
      return {
        conversation: detail || { id, title: '会话', type: 'direct' },
        messages,
        pins,
        has_more: messages.length >= 50,
        read_state: {}
      };
    }
    case 'conversations/detail': {
      const id = String(data.conversation_id ?? '');
      let detail = null;
      try {
        const convs = await http('/conversation/list', {}, 'GET', auth, options);
        const found = (Array.isArray(convs) ? convs : []).find(c => String(c.conversation?.id) === id);
        detail = found ? goConvToQm(found, myId) : null;
      } catch (_) {}
      if (detail?.type === 'group') {
        try {
          const ms = await http(`/conversation/${id}/members`, {}, 'GET', auth, options);
          detail.members = (Array.isArray(ms) ? ms : []).map(goUserToQm).filter(Boolean);
        } catch (_) {}
      }
      return detail || { id, title: '会话', type: 'direct' };
    }
    case 'conversations/create': {
      const r = await http('/conversation/group', {
        nameZh: data.title || '群聊',
        memberIds: (data.member_ids || []).map(String)
      }, 'POST', auth, options);
      return goConvToQm({ conversation: r, unread: 0, memberCount: (data.member_ids || []).length + 1 }, myId);
    }

    // ---------- 消息 ----------
    case 'messages': {
      const rows = await http('/message/history', {
        convId: String(data.conversation_id ?? ''),
        beforeMsgId: data.before_id || 0,
        limit: 50
      }, 'GET', auth, options);
      return (Array.isArray(rows) ? rows : []).map(m => goMsgToQm(m, myId)).filter(Boolean);
    }
    case 'messages/send': {
      const payload = {
        conversationId: String(data.conversation_id ?? ''),
        clientMsgId: data.client_msg_id || '',
        type: strTypeToGo(data.message_type || 'text'),
        content: data.content || ''
      };
      // replyTo 为空字符串时 Go 的 ,string 解码会报错 → 仅在有效时携带
      if (data.reply_to_id) payload.replyTo = String(data.reply_to_id);
      if (data.file_url) payload.file = { url: data.file_url, name: data.file_name || '', size: data.file_size || 0, duration: data.duration || 0 };
      const r = await http('/message/send', payload, 'POST', auth, options);
      return goMsgToQm(r, myId);
    }
    case 'messages/recall': {
      const id = String(data.message_id ?? '');
      await http(`/message/${id}/recall`, {}, 'POST', auth, options);
      return { ok: true };
    }
    case 'messages/read': {
      await http('/message/read', {
        conversationId: String(data.conversation_id ?? ''),
        msgId: String(data.message_id ?? '')
      }, 'POST', auth, options);
      return { ok: true };
    }
    case 'messages/favorite': {
      const r = await http('/message/favorite', {
        conversationId: String(data.conversation_id ?? ''),
        msgId: String(data.message_id ?? '')
      }, 'POST', auth, options);
      return r || { ok: true };
    }
    case 'messages/favorites': {
      const rows = await http('/message/favorites', {}, 'GET', auth, options);
      return (Array.isArray(rows) ? rows : []).map(m => goMsgToQm(m, myId)).filter(Boolean);
    }
    case 'messages/pin': {
      const id = String(data.conversation_id ?? '');
      await http(`/conversation/${id}/pin-message`, {
        msgId: String(data.message_id ?? ''),
        content: data.content || '',
        pinned: !!data.pinned
      }, 'PUT', auth, options);
      return { ok: true };
    }
    case 'messages/pins': {
      // 置顶消息列表（多条）：GET /conversation/:id/pins → [msgId,...]
      const id = String(data.conversation_id ?? '');
      const ids = await http(`/conversation/${id}/pins`, {}, 'GET', auth, options);
      return Array.isArray(ids) ? ids.map(v => String(v)) : [];
    }
    case 'messages/edit':
      // 后端暂无编辑接口：直接返回成功（内容不变）
      return { ok: true };

    // ---------- 好友 ----------
    case 'friends': {
      const list = await http('/friend/list', {}, 'GET', auth, options);
      return (Array.isArray(list) ? list : []).map(goUserToQm).filter(Boolean);
    }
    case 'friends/requests': {
      const list = await http('/friend/request/incoming', {}, 'GET', auth, options);
      return (Array.isArray(list) ? list : []).map(goRequestToQm).filter(Boolean);
    }
    case 'friends/respond': {
      const id = String(data.request_id ?? '');
      await http(`/friend/request/${id}/handle?agree=${data.accepted ? 1 : 0}`, {}, 'POST', auth, options);
      return { ok: true };
    }
    case 'friends/request': {
      await http('/friend/request', {
        toId: String(data.friend_id ?? data.user_id ?? ''),
        message: data.message || ''
      }, 'POST', auth, options);
      return { ok: true };
    }
    case 'friends/remove': {
      const id = String(data.friend_id ?? '');
      await http(`/friend/${id}`, {}, 'DELETE', auth, options);
      return { ok: true };
    }

    // ---------- 用户 ----------
    case 'users/search': {
      const list = await http('/user/search', { kw: data.keyword || data.kw || '' }, 'GET', auth, options);
      return (Array.isArray(list) ? list : []).map(goUserToQm).filter(Boolean);
    }
    case 'users/detail': {
      const id = String(data.user_id ?? '');
      const r = await http(`/user/${id}`, {}, 'GET', auth, options);
      return goUserToQm(r);
    }

    // ---------- 群组 ----------
    case 'groups/add-members': {
      await http(`/conversation/${String(data.conversation_id ?? '')}/invite`, {
        memberIds: (data.member_ids || []).map(String)
      }, 'POST', auth, options);
      return { ok: true };
    }
    case 'groups/remove-member': {
      await http(
        `/conversation/${String(data.conversation_id ?? '')}/members/${String(data.user_id ?? '')}`,
        {}, 'DELETE', auth, options);
      return { ok: true };
    }
    case 'groups/announcement': {
      await http(`/conversation/${String(data.conversation_id ?? '')}/announcement`, {
        announcementZh: data.content || ''
      }, 'PUT', auth, options);
      return { ok: true };
    }
    case 'groups/announcement/read':
      // 后端无公告已读接口
      return { ok: true };

    // ---------- 个人资料（昵称 / 头像 / 密码） ----------
    case 'me/update': {
      // 后端 PUT /user/profile 仅返回 {code,message}，成功后重新拉取确保本地同步
      await http('/user/profile', {
        nickname: data.nickname || '',
        avatar: data.avatar || ''
      }, 'PUT', auth, options);
      return { ok: true };
    }
    case 'me/password': {
      await http('/user/password', {
        oldPassword: data.oldPassword || '',
        newPassword: data.newPassword || ''
      }, 'PUT', auth, options);
      return { ok: true };
    }

    // ---------- 群管理（群主） ----------
    case 'groups/settings': {
      const id = String(data.conversation_id ?? '');
      if (method === 'PUT') {
        const patch = {};
        if (typeof data.privacyEnabled === 'boolean') patch.privacyEnabled = data.privacyEnabled;
        if (typeof data.muteAll === 'boolean') patch.muteAll = data.muteAll;
        if (typeof data.allowMemberInvite === 'boolean') patch.allowMemberInvite = data.allowMemberInvite;
        if (typeof data.qrJoinEnabled === 'boolean') patch.qrJoinEnabled = data.qrJoinEnabled;
        await http(`/conversation/${id}/settings`, patch, 'PUT', auth, options);
        return { ok: true };
      }
      const r = await http(`/conversation/${id}/settings`, {}, 'GET', auth, options);
      return r || {};
    }
    case 'groups/update': {
      const id = String(data.conversation_id ?? '');
      await http(`/conversation/${id}`, {
        nameZh: data.nameZh || '',
        avatar: data.avatar || ''
      }, 'PUT', auth, options);
      return { ok: true };
    }
    case 'groups/add-admin': {
      const id = String(data.conversation_id ?? '');
      await http(`/conversation/${id}/admin`, {
        userId: String(data.userId || ''),
        admin: !!data.admin
      }, 'PUT', auth, options);
      return { ok: true };
    }

    // ---------- 扫码登录（Go 后端：/auth/qr/ticket + /auth/qr/status） ----------
    case 'pc/qr/create': {
      const info = await http('/auth/qr/ticket', {}, 'POST', null, options);
      // http() 已解包 body.data → info 即 ticket 信息；兼容极端情况再兜底
      return {
        ticket: info?.ticket, secret: info?.secret, payload: info?.payload,
        expires: info?.expires, status: info?.status
      };
    }
    case 'pc/qr/status': {
      const st = await http(`/auth/qr/status?ticket=${encodeURIComponent(data.ticket || '')}&secret=${encodeURIComponent(data.secret || '')}`, {}, 'GET', null, options);
      // http() 已解包 body.data → st 即 {status, accessToken, refreshToken, user}
      if (st?.status === 'confirmed' && st?.accessToken) {
        return { status: 'confirmed', token: st.accessToken, refresh: st.refreshToken, user: st.user };
      }
      return { status: st?.status || 'pending', message: st?.message || '' };
    }

    // ---------- 同步（长轮询 → 由 useSync 走 WebSocket，这里兜底空包） ----------
    case 'sync/bootstrap':
    case 'sync/poll':
      return { conversations: [], messages: [], events: [], drafts: [], read_state: {}, signature: '', message_cursor: 0, event_cursor: 0, message_has_more: false };

    // ---------- 红包 / 转账（钱包）----------
    case 'wallet/redpacket/detail': {
      const r = await http(`/wallet/redpacket/${encodeURIComponent(String(data.msg_id ?? ''))}`, {}, 'GET', auth, options);
      return r || {};
    }
    case 'wallet/redpacket/claim': {
      const r = await http(`/wallet/redpacket/${encodeURIComponent(String(data.msg_id ?? ''))}/claim`, {}, 'POST', auth, options);
      return r || {};
    }
    case 'wallet/record': {
      // 【已废弃】服务端已停止该接口的记账能力（B-21）：入账类直接拒绝，
      // 出账类改为幂等 no-op（发红包/转账的扣款已在发消息时由服务端原子完成）。
      // 仅保留调用以兼容未刷新的老页面，新代码一律不要用。
      const r = await http('/wallet/record', {
        type: data.type || '',
        amount: Number(data.amount || 0),
        refId: String(data.ref_id ?? '')
      }, 'POST', auth, options);
      return r || {};
    }
    case 'wallet/transfer/accept': {
      // 转账收款：只传消息 ID，金额由服务端按转账消息内容核算 + 会话成员校验 + 幂等去重
      const r = await http(`/wallet/transfer/${encodeURIComponent(String(data.msg_id ?? ''))}/accept`, {}, 'POST', auth, options);
      return r || {};
    }

    // ---------- 朋友圈 ----------
    case 'moments': {
      const r = await http('/moments', { page: data.page || 1, size: data.size || 20 }, 'GET', auth, options);
      return momentListOut(r, myId);
    }
    case 'moments/user': {
      const r = await http(`/moments/${encodeURIComponent(String(data.owner_id ?? ''))}`, { page: data.page || 1, size: data.size || 20 }, 'GET', auth, options);
      return momentListOut(r, myId);
    }
    case 'moments/publish': {
      const r = await http('/moments', {
        content: data.content || '',
        images: Array.isArray(data.images) ? data.images : []
      }, 'POST', auth, options);
      return momentOut(r, myId);
    }
    case 'moments/like': {
      // 后端返回 { liked: bool }（toggle 后状态）
      const r = await http(`/moments/${encodeURIComponent(String(data.id ?? ''))}/like`, {}, 'POST', auth, options);
      return { liked: !!(r && r.liked) };
    }

    // ---------- 未映射路径 ----------
    default:
      // 未知接口：返回空对象避免 Store 崩溃
      return {};
  }
}

// ====================== 文件上传 ======================

export async function uploadFile(file) {
  const authStore = useAuthStore();
  // 当前 Go 后端已接 MinIO：POST /api/v1/upload (multipart)
  const form = new FormData();
  form.append('file', file, file.name);
  form.append('dir', file.type?.startsWith('image/') ? 'chat/' : 'chat/');
  const headers = { Authorization: 'Bearer ' + authStore.token };
  const response = await fetch(API + '/upload', { method: 'POST', headers, body: form });
  const body = await response.json().catch(() => null);
  if (!response.ok || !body || body.code !== 0) {
    const error = new Error(body?.message || `上传失败（${response.status}）`);
    error.status = response.status;
    throw error;
  }
  const d = body.data || {};
  return {
    id: d.object || String(Date.now()),
    url: d.url || '',
    name: d.name || file.name,
    size: Number(d.size || file.size || 0),
    mime_type: d.mimeType || file.type || 'application/octet-stream'
  };
}

export default api;
