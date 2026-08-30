import 'package:dio/dio.dart';

import 'api_client.dart';

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

  ConvItem.fromJson(Map<String, dynamic> j)
      : conversation = j['conversation'] ?? {},
        unread = (j['unread'] as num?)?.toInt() ?? 0,
        lastMessage = j['lastMessage'],
        memberCount = (j['memberCount'] as num?)?.toInt() ?? 0,
        mute = j['mute'] ?? false,
        pinned = j['pinned'] ?? false,
        conversationName = j['conversationName'] ?? '',
        peerOnline = j['peerOnline'] == true,
        peerOnlineDev = (j['peerOnlineDev'] as List<dynamic>?) ?? [];

  /// 会话 ID（雪花 ID 全程字符串，H5 上 int 会丢精度）
  String get id => conversation['id']?.toString() ?? '';

  String get lastMsgPreview {
    final m = lastMessage;
    if (m == null) return '';
    if (m['recalled'] == true) return '[消息已撤回]';
    final typeMap = {1: '', 2: '[图片]', 3: '[文件]', 4: '[语音]', 5: '[视频]'};
    return (typeMap[(m['type'] as num?)?.toInt()] ?? '') +
        (m['content']?.toString() ?? '');
  }

  String get timeText {
    final raw = lastMessage?['createdAt'] ?? conversation['createdAt'];
    if (raw == null) return '';
    final dt = DateTime.tryParse(raw.toString())?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    final hm = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) return hm;
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day) {
      return '昨天 $hm';
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
    return data.map((e) => ConvItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 所有 ID 参数均为 String（雪花 ID 字符串，H5 精度安全）
  Future<Map<String, dynamic>> createDirect(String userId) async {
    final r = await _dio.post('/api/v1/conversation/direct',
        data: {'userId': userId},
        options: Options(headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
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
        options: Options(headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return (r.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> history(String convId, {int beforeMsgId = 0}) async {
    final r = await _dio.get('/api/v1/message/history',
        queryParameters: {'convId': convId, 'beforeMsgId': '$beforeMsgId', 'limit': 50},
        options: Options(headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return ((r.data as Map<String, dynamic>)['data'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  Future<void> markRead(String convId, String msgId) async {
    await _dio.post('/api/v1/message/read',
        data: {'conversationId': convId, 'msgId': msgId},
        options: Options(headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
  }

  /// 增量补拉：重连补偿（seq > afterSeq）
  Future<List<Map<String, dynamic>>> sync(String convId, int afterSeq) async {
    final r = await _dio.get('/api/v1/message/sync',
        queryParameters: {'convId': convId, 'afterSeq': '$afterSeq', 'limit': 200},
        options: Options(headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return ((r.data as Map<String, dynamic>)['data'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  // ============ 会话设置 ============

  Future<bool> setPin(String convId, bool pinned) async {
    final r = await _dio.put('/api/v1/conversation/$convId/pin',
        data: {'pinned': pinned},
        options: Options(headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return (r.data as Map<String, dynamic>)['code'] == 0;
  }

  Future<bool> setMute(String convId, bool mute) async {
    final r = await _dio.put('/api/v1/conversation/$convId/mute',
        data: {'mute': mute},
        options: Options(headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return (r.data as Map<String, dynamic>)['code'] == 0;
  }

  Future<bool> quit(String convId) async {
    final r = await _dio.post('/api/v1/conversation/$convId/quit',
        options: Options(headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return (r.data as Map<String, dynamic>)['code'] == 0;
  }

  Future<bool> disband(String convId) async {
    final r = await _dio.post('/api/v1/conversation/$convId/disband',
        options: Options(headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return (r.data as Map<String, dynamic>)['code'] == 0;
  }

  /// 创建群聊：name + 成员 ID（含自己自动添加为群主）
  Future<Map<String, dynamic>> createGroup(String nameZh, List<String> memberIds) async {
    final r = await _dio.post('/api/v1/conversation/group',
        data: {'nameZh': nameZh, 'memberIds': memberIds},
        options: Options(headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return (r.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
  }

  /// 会话成员列表（群设置用）
  Future<List<Map<String, dynamic>>> members(String convId) async {
    final r = await _dio.get('/api/v1/conversation/$convId/members',
        options: Options(headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return ((r.data as Map<String, dynamic>)['data'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  // ============ 搜索 / 收藏 ============

  /// 消息搜索（仅自己参与的会话）
  Future<Map<String, dynamic>> searchMessages(String kw, {int page = 1}) async {
    final r = await _dio.get('/api/v1/message/search',
        queryParameters: {'kw': kw, 'page': page, 'size': 20},
        options: Options(headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return (r.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
  }

  Future<bool> favoriteAdd(String convId, String msgId) async {
    final r = await _dio.post('/api/v1/message/favorite',
        data: {'conversationId': convId, 'msgId': msgId},
        options: Options(headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return (r.data as Map<String, dynamic>)['code'] == 0;
  }

  // ============ 群功能 ============

  /// 置顶/取消置顶消息（群主/管理员；msgId 传 0 取消）
  Future<bool> setPinMessage(String convId, String msgId, String content) async {
    final r = await _dio.put('/api/v1/conversation/$convId/pin-message',
        data: {'msgId': msgId, 'content': content},
        options: Options(headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return (r.data as Map<String, dynamic>)['code'] == 0;
  }

  /// 更新群公告（群主/管理员）
  Future<bool> updateAnnouncement(String convId, String zh, String en) async {
    final r = await _dio.put('/api/v1/conversation/$convId/announcement',
        data: {'announcementZh': zh, 'announcementEn': en},
        options: Options(headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return (r.data as Map<String, dynamic>)['code'] == 0;
  }

  /// 撤回消息（本人 2min / 群主管理员）
  Future<bool> recall(String msgId) async {
    final r = await _dio.post('/api/v1/message/$msgId/recall',
        options: Options(headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return (r.data as Map<String, dynamic>)['code'] == 0;
  }

  Future<List<Map<String, dynamic>>> favorites({int limit = 50}) async {
    final r = await _dio.get('/api/v1/message/favorites',
        queryParameters: {'limit': limit},
        options: Options(headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return ((r.data as Map<String, dynamic>)['data'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }
}
