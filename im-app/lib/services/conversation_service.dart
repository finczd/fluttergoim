import 'dart:convert';

import 'package:dio/dio.dart';

import 'api_client.dart';
import '../l10n/app_locale.dart';

class ConvItem {
  final Map<String, dynamic> conversation;
  final int unread;
  final Map<String, dynamic>? lastMessage;
  final int memberCount;
  final bool mute;
  final bool pinned;
  final String conversationName;
  final bool peerOnline; // 单聊对方在线（需求4）
  final List<dynamic> peerOnlineDev; // 在线设备：["mobile","web",...]
  final String peerOnlineZh; // 单聊对方在线类型中文
  final String peerShortId; // 单聊对方靓号/ID
  final String peerRemark; // 我对对方设置的备注（需求：备注优先显示）

  ConvItem.fromJson(Map<String, dynamic> j)
      : conversation = j['conversation'] ?? {},
        unread = (j['unread'] as num?)?.toInt() ?? 0,
        lastMessage = j['lastMessage'],
        memberCount = (j['memberCount'] as num?)?.toInt() ?? 0,
        mute = j['mute'] ?? false,
        pinned = j['pinned'] ?? false,
        conversationName = j['conversationName'] ?? '',
        peerOnline = j['peerOnline'] == true,
        peerOnlineDev = (j['peerOnlineDev'] as List<dynamic>?) ?? [],
        peerOnlineZh = j['peerOnlineZh']?.toString() ?? '',
        peerShortId = j['peerShortId']?.toString() ?? '',
        peerRemark = j['peerRemark']?.toString() ?? '';

  /// 会话 ID（雪花 ID 全程字符串，H5 上 int 会丢精度）
  String get id => conversation['id']?.toString() ?? '';

  /// 是否小助手会话（助手是虚拟 uid -1；消息列表/通讯录用它显示「官方」标识）
  bool get isAssistant => (conversation['peerId']?.toString() ?? '') == '-1';

  /// 会话头像（群头像 / 单聊对方头像），可能为空
  String get avatarUrl {
    final v = conversation['avatar'] ?? conversation['peerAvatar'];
    return v?.toString() ?? '';
  }

  String get lastMsgPreview {
    final t = AppLocalizations.instance.t;
    final m = lastMessage;
    if (m == null) return '';
    if (m['recalled'] == true) return t('svcMsgRecalled');
    final type = (m['type'] as num?)?.toInt() ?? 1;
    if (type == 7) return _callPreview(m['content']);
    // 红包/转账：显示专门样式（不透出 JSON）
    if (type == 8) {
      final note = _moneyNote(m['content']);
      return note.isEmpty
          ? t('svcRedPacket')
          : t('svcRedPacketNote', {'note': note});
    }
    if (type == 9) {
      final note = _moneyNote(m['content']);
      return note.isEmpty
          ? t('svcTransfer')
          : t('svcTransferNote', {'note': note});
    }
    final typeMap = {
      2: t('svcImage'),
      3: t('svcFile'),
      4: t('svcVoice'),
      5: t('svcVideo')
    };
    final label = typeMap[type] ?? '';
    // 文本(type=1)直接拼接内容；图片/文件/语音/视频仅显示类型标签，不透出 URL/原始内容
    if (type == 1) return label + (m['content']?.toString() ?? '');
    return label;
  }

  /// 红包/转账留言解析（JSON {kind,amount,note}）
  String _moneyNote(dynamic content) {
    try {
      final j = content is String ? jsonDecode(content) : content;
      if (j is Map) return (j['note'] ?? '').toString();
    } catch (_) {}
    return '';
  }

  /// 通话记录预览：invite/reject/cancel/hangup 解析成人话
  String _callPreview(dynamic content) {
    final t = AppLocalizations.instance.t;
    if (content == null) return t('svcCall');
    Map<String, dynamic> sig;
    try {
      sig = content is String
          ? (jsonDecode(content) as Map<String, dynamic>)
          : (content as Map<String, dynamic>);
    } catch (_) {
      return t('svcCall');
    }
    final action = sig['action']?.toString() ?? 'hangup';
    final callType = sig['callType']?.toString() ?? 'voice';
    final duration = (sig['duration'] as num?)?.toInt() ?? 0;
    final durText = duration > 0 ? ' ${_formatDuration(duration)}' : '';
    final isVideo = callType == 'video';
    switch (action) {
      case 'invite':
        return isVideo ? t('svcCallMissedVideo') : t('svcCallMissedVoice');
      case 'cancel':
        return isVideo ? t('svcCallCanceledVideo') : t('svcCallCanceledVoice');
      case 'reject':
        return isVideo ? t('svcCallRejectedVideo') : t('svcCallRejectedVoice');
      case 'hangup':
        return durText.isEmpty
            ? (isVideo ? t('svcCallVideo') : t('svcCallVoice'))
            : t(isVideo ? 'svcCallVideoDur' : 'svcCallVoiceDur',
                {'dur': durText.trim()});
      default:
        return isVideo ? t('svcCallVideo') : t('svcCallVoice');
    }
  }

  String _formatDuration(int seconds) {
    final t = AppLocalizations.instance.t;
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m > 0) return '$m:${s.toString().padLeft(2, '0')}';
    return t('svcSecs', {'n': '$s'});
  }

  String get timeText {
    final raw = lastMessage?['createdAt'] ?? conversation['createdAt'];
    if (raw == null) return '';
    final dt = DateTime.tryParse(raw.toString())?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    final hm =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return hm;
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year &&
        dt.month == yesterday.month &&
        dt.day == yesterday.day) {
      return AppLocalizations.instance.t('svcYesterday', {'time': hm});
    }
    return '${dt.month}/${dt.day}';
  }
}

class ConversationService {
  final Dio _dio = ApiClient.instance.dio;
  final _api = ApiClient.instance;

  Future<List<ConvItem>> list() async {
    final r = await _api.get('/api/v1/conversation/list');
    final data = r.data['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => ConvItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 所有 ID 参数均为 String（雪花 ID 字符串，H5 精度安全）
  Future<Map<String, dynamic>> createDirect(String userId) async {
    final r = await _dio.post('/api/v1/conversation/direct',
        data: {'userId': userId},
        options: Options(
            headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return (r.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> send(String convId, String content,
      {String? clientMsgId, String? replyTo, List<String>? mentions}) async {
    final r = await _dio.post('/api/v1/message/send',
        data: {
          'conversationId': convId,
          'type': 1,
          'content': content,
          'clientMsgId': clientMsgId,
          'replyTo': replyTo,
          'mention': mentions,
        },
        options: Options(
            headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return (r.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
  }

  /// 需求3：发送图片消息（type=2，content=URL）
  Future<Map<String, dynamic>> sendImage(String convId, String url,
      {String? clientMsgId}) async {
    final r = await _dio.post('/api/v1/message/send',
        data: {
          'conversationId': convId,
          'type': 2,
          'content': url,
          'clientMsgId': clientMsgId,
        },
        options: Options(
            headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return (r.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
  }

  /// 红包/转账（type=8 红包 / type=9 转账，content=JSON 自定义负载）
  Future<Map<String, dynamic>> sendMoney(
      String convId, int type, Map<String, dynamic> contentData,
      {String? clientMsgId}) async {
    contentData['ts'] = DateTime.now().millisecondsSinceEpoch;
    final r = await _dio.post('/api/v1/message/send',
        data: {
          'conversationId': convId,
          'type': type,
          'content': jsonEncode(contentData),
          'clientMsgId': clientMsgId,
        },
        options: Options(
            headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    // 业务 code 必须判：后端余额不足 / 参数错误时 HTTP 仍是 200 但 data 为 null，
    // 不判 code 的话上层会当成"发送成功"（B-19：0 余额也能把红包发出去）。
    final body = (r.data as Map<String, dynamic>);
    final code = (body['code'] as num?)?.toInt() ?? 0;
    if (code != 0) {
      throw Exception((body['message'] ?? '发送失败').toString());
    }
    return (body['data'] as Map<String, dynamic>? ?? {});
  }

  Future<List<Map<String, dynamic>>> history(String convId,
      {int beforeMsgId = 0}) async {
    final r = await _dio.get('/api/v1/message/history',
        queryParameters: {
          'convId': convId,
          'beforeMsgId': '$beforeMsgId',
          'limit': 50
        },
        options: Options(
            headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return ((r.data as Map<String, dynamic>)['data'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  Future<void> markRead(String convId, String msgId) async {
    await _dio.post('/api/v1/message/read',
        data: {'conversationId': convId, 'msgId': msgId},
        options: Options(
            headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
  }

  /// 群置顶消息列表（按置顶顺序，含 content/senderName/type/createdAt）
  Future<List<Map<String, dynamic>>> pinnedMessages(String convId) async {
    final r = await _dio.get('/api/v1/conversation/$convId/pins',
        options: Options(
            headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    final data = (r.data['data'] as List<dynamic>?) ?? [];
    return data.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  /// 增量补拉：重连补偿（seq > afterSeq）
  Future<List<Map<String, dynamic>>> sync(String convId, int afterSeq) async {
    final r = await _dio.get('/api/v1/message/sync',
        queryParameters: {
          'convId': convId,
          'afterSeq': '$afterSeq',
          'limit': 200
        },
        options: Options(
            headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return ((r.data as Map<String, dynamic>)['data'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  // ============ 会话设置 ============

  Future<bool> setPin(String convId, bool pinned) async {
    final r = await _dio.put('/api/v1/conversation/$convId/pin',
        data: {'pinned': pinned},
        options: Options(
            headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return (r.data as Map<String, dynamic>)['code'] == 0;
  }

  Future<bool> setMute(String convId, bool mute) async {
    final r = await _dio.put('/api/v1/conversation/$convId/mute',
        data: {'mute': mute},
        options: Options(
            headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return (r.data as Map<String, dynamic>)['code'] == 0;
  }

  Future<bool> quit(String convId) async {
    final r = await _dio.post('/api/v1/conversation/$convId/quit',
        options: Options(
            headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return (r.data as Map<String, dynamic>)['code'] == 0;
  }

  Future<bool> disband(String convId) async {
    final r = await _dio.post('/api/v1/conversation/$convId/disband',
        options: Options(
            headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return (r.data as Map<String, dynamic>)['code'] == 0;
  }

  /// 创建群聊：name + 成员 ID（含自己自动添加为群主）
  Future<Map<String, dynamic>> createGroup(
      String nameZh, List<String> memberIds) async {
    final r = await _dio.post('/api/v1/conversation/group',
        data: {'nameZh': nameZh, 'memberIds': memberIds},
        options: Options(
            headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return (r.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
  }

  /// 会话成员列表（群设置用）
  Future<List<Map<String, dynamic>>> members(String convId) async {
    final r = await _dio.get('/api/v1/conversation/$convId/members',
        options: Options(
            headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return ((r.data as Map<String, dynamic>)['data'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  // ============ 搜索 / 收藏 ============

  /// 消息搜索（仅自己参与的会话）
  Future<Map<String, dynamic>> searchMessages(String kw, {int page = 1}) async {
    final r = await _dio.get('/api/v1/message/search',
        queryParameters: {'kw': kw, 'page': page, 'size': 20},
        options: Options(
            headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return (r.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
  }

  Future<bool> favoriteAdd(String convId, String msgId) async {
    final r = await _dio.post('/api/v1/message/favorite',
        data: {'conversationId': convId, 'msgId': msgId},
        options: Options(
            headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return (r.data as Map<String, dynamic>)['code'] == 0;
  }

  // ============ 群功能 ============

  /// 置顶/取消置顶消息（群主/管理员；msgId 传 0 取消）
  Future<bool> setPinMessage(
      String convId, String msgId, String content) async {
    final r = await _dio.put('/api/v1/conversation/$convId/pin-message',
        data: {'msgId': msgId, 'content': content},
        options: Options(
            headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return (r.data as Map<String, dynamic>)['code'] == 0;
  }

  /// 更新群公告（群主/管理员）
  Future<bool> updateAnnouncement(String convId, String zh, String en) async {
    final r = await _dio.put('/api/v1/conversation/$convId/announcement',
        data: {'announcementZh': zh, 'announcementEn': en},
        options: Options(
            headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return (r.data as Map<String, dynamic>)['code'] == 0;
  }

  /// 撤回消息（本人 2min / 群主管理员）
  Future<bool> recall(String msgId) async {
    final r = await _dio.post('/api/v1/message/$msgId/recall',
        options: Options(
            headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return (r.data as Map<String, dynamic>)['code'] == 0;
  }

  Future<List<Map<String, dynamic>>> favorites({int limit = 50}) async {
    final r = await _dio.get('/api/v1/message/favorites',
        queryParameters: {'limit': limit},
        options: Options(
            headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return ((r.data as Map<String, dynamic>)['data'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }
}
