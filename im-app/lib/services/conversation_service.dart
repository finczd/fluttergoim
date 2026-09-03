import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'api_client.dart';
import '../l10n/app_locale.dart';
import 'local_store.dart';

/// 服务端业务错误（HTTP 200 + code != 0）：带 code 供页面区分处理
/// （如 4006 成员隐私 → 显示"群主已开启成员隐私"而不是报错）
class ApiException implements Exception {
  final int code;
  final String message;
  ApiException(this.code, this.message);
  @override
  String toString() => message;
}

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
  final bool peerVipShortId; // 对方是否靓号（预留池已绑定）→ 资料页显示「靓ID」徽标
  final String peerRemark; // 我对对方设置的备注（需求：备注优先显示）
  final String peerId; // 单聊对方用户 ID（顶层字段，雪花 ID 字符串）

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
        peerVipShortId = j['peerVipShortId'] == true,
        peerRemark = j['peerRemark']?.toString() ?? '',
        peerId = j['peerId']?.toString() ?? '';

  /// 会话 ID（雪花 ID 全程字符串，H5 上 int 会丢精度）
  String get id => conversation['id']?.toString() ?? '';

  /// 是否小助手会话（助手是虚拟 uid -1；消息列表/通讯录用它显示「官方」标识）
  /// 优先读顶层 peerId（服务端 ConvItem 结构），旧数据回落 conversation.peerId
  bool get isAssistant =>
      (peerId == '-1') || (conversation['peerId']?.toString() ?? '') == '-1';

  /// 会话头像（群头像 / 单聊对方头像），可能为空
  String get avatarUrl {
    final v = conversation['avatar'] ?? conversation['peerAvatar'];
    return v?.toString() ?? '';
  }

  /// 单聊对方最近上线时间（ISO8601 字符串；服务端单聊接口实时下发，可能为空）
  String get lastLoginAt => conversation['lastLoginAt']?.toString() ?? '';

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

  /// 最近一次会话列表接口的原始数据（供页面落本地缓存）
  List<dynamic> lastConvRaw = [];

  /// 进程内历史消息缓存：convId → 最近一页原始消息。
  /// 打开会话先直出缓存再后台刷新，消掉转圈；WS 新消息实时追加。
  static final Map<String, List<Map<String, dynamic>>> _historyCache = {};

  static List<Map<String, dynamic>>? historyCached(String convId) =>
      _historyCache[convId];

  /// WS 收到/发送成功后把原始消息追加进缓存（按 msgId/clientMsgId 幂等去重）
  static void historyCacheAppend(String convId, Map<String, dynamic> raw) {
    final c = _historyCache[convId];
    if (c == null) return;
    final id = raw['msgId']?.toString() ?? '';
    final cm = raw['clientMsgId']?.toString() ?? '';
    for (final x in c) {
      if ((id.isNotEmpty && x['msgId']?.toString() == id) ||
          (cm.isNotEmpty && x['clientMsgId']?.toString() == cm)) {
        return;
      }
    }
    c.add(raw);
    if (c.length > 80) c.removeRange(0, c.length - 80);
    // 同步落盘（异步，不阻塞 UI）：杀进程后重开仍能看到这些消息
    unawaited(LocalStore.appendMessage(convId, raw));
  }

  /// 冷启动兜底：内存没缓存时从本地持久化（Hive）回填。
  /// 返回 true 表示有数据可直出（调用方再读 historyCached 即可）。
  static Future<bool> hydrateFromDisk(String convId) async {
    if (_historyCache.containsKey(convId)) return true;
    final disk = await LocalStore.loadMessages(convId);
    if (disk == null || disk.isEmpty) return false;
    _historyCache[convId] = disk;
    return true;
  }

  /// 订阅 Hive 缓存损坏事件：脏数据已被 LocalStore 清掉，这里同步把
  /// **内存缓存也失效**，保证下次打开该会话走网络重拉并重新落盘
  /// （否则损坏的脏数据会一直留在内存里，UI 反复显示错误内容）。
  /// 'conv_list' 由 chat_list_page 自己处理（它本来每次进页都全量刷新）。
  static void bindLocalStore() {
    LocalStore.addCorruptListener((key) {
      if (key == 'conv_list') return;
      _historyCache.remove(key);
    });
  }

  Future<List<ConvItem>> list() async {
    final r = await _api.get('/api/v1/conversation/list');
    final data = r.data['data'] as List<dynamic>? ?? [];
    lastConvRaw = data;
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

  /// 历史消息（服务端返回**时间正序**：最旧在前）。
  ///
  /// [beforeMsgId]：分页游标，传当前最旧一条的 msgId 拉更早的（0/'0' = 拉最新一页）。
  /// 类型用 String 而非 int——雪花 ID 在 Web（JS）上超过 2^53 会丢精度。
  ///
  /// limit 固定 80：与 LocalStore.maxMessagesPerConv 对齐。
  /// 之前是 50，导致冷启动先用 Hive 的 80 条缓存渲染、网络回来只给 50 条，
  /// 列表凭空少 30 条（上翻时会发现消息断层）。
  Future<List<Map<String, dynamic>>> history(String convId,
      {String beforeMsgId = '0'}) async {
    final r = await _dio.get('/api/v1/message/history',
        queryParameters: {
          'convId': convId,
          'beforeMsgId': beforeMsgId,
          'limit': 80
        },
        options: Options(
            headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    final list =
        ((r.data as Map<String, dynamic>)['data'] as List<dynamic>? ?? [])
            .map((e) => e as Map<String, dynamic>)
            .toList();
    // 只缓存"最新一页"（无 beforeMsgId 的首拉），上翻加载的更早历史不覆盖
    if (beforeMsgId == '0' && list.isNotEmpty) {
      _historyCache[convId] = list;
      unawaited(LocalStore.saveMessages(convId, list)); // 落盘：冷启动秒开
    }
    return list;
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

  /// 最近一次 members() 响应携带的群成员总数（隐私限量模式下列表被截断，总数照实下发）
  int _lastMembersCount = 0;
  int get lastMembersCount => _lastMembersCount;

  /// 会话成员列表（群设置用）；code!=0 抛 ApiException（如 4006 成员隐私）
  Future<List<Map<String, dynamic>>> members(String convId) async {
    final r = await _dio.get('/api/v1/conversation/$convId/members',
        options: Options(
            headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    final body = r.data as Map<String, dynamic>;
    _lastMembersCount = (body['memberCount'] as num?)?.toInt() ?? 0;
    return _dataList(body);
  }

  List<Map<String, dynamic>> _dataList(dynamic body) {
    final map = body as Map<String, dynamic>;
    final code = (map['code'] as num?)?.toInt() ?? 0;
    if (code != 0) throw ApiException(code, map['message']?.toString() ?? '');
    return ((map['data'] as List<dynamic>?) ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Map<String, dynamic> _dataMap(dynamic body) {
    final map = body as Map<String, dynamic>;
    final code = (map['code'] as num?)?.toInt() ?? 0;
    if (code != 0) throw ApiException(code, map['message']?.toString() ?? '');
    return ((map['data'] as Map?) ?? {})
        .map((k, v) => MapEntry(k.toString(), v));
  }

  // ============ 群聊管理 ============

  /// 读取群管理设置（muteAll/privacyEnabled/allowMemberInvite/qrJoinEnabled）
  Future<Map<String, dynamic>> groupSettings(String convId) async {
    final r = await _dio.get('/api/v1/conversation/$convId/settings',
        options: Options(
            headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return _dataMap(r.data);
  }

  /// 更新群管理设置（仅群主；未传的开关服务端保持原值）
  Future<bool> setGroupSettings(String convId,
      {bool? muteAll,
      bool? privacyEnabled,
      bool? allowInvite,
      bool? qrJoin}) async {
    final r = await _dio.put('/api/v1/conversation/$convId/settings',
        data: {
          if (muteAll != null) 'muteAll': muteAll,
          if (privacyEnabled != null) 'privacyEnabled': privacyEnabled,
          if (allowInvite != null) 'allowMemberInvite': allowInvite,
          if (qrJoin != null) 'qrJoinEnabled': qrJoin,
        },
        options: Options(
            headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return ((r.data as Map<String, dynamic>)['code'] as num?)?.toInt() == 0;
  }

  /// 设置/取消群管理员（仅群主）
  Future<bool> setGroupAdmin(String convId, String userId, bool admin) async {
    final r = await _dio.put('/api/v1/conversation/$convId/admin',
        data: {'userId': userId, 'admin': admin},
        options: Options(
            headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return ((r.data as Map<String, dynamic>)['code'] as num?)?.toInt() == 0;
  }

  /// 禁言/解除禁言成员（群主/管理员；minutes 为禁言时长分钟数）
  Future<bool> muteMember(String convId, String userId, bool mute,
      {int minutes = 10}) async {
    final r = await _dio.put('/api/v1/conversation/$convId/mute-member',
        data: {'userId': userId, 'mute': mute, 'minutes': minutes},
        options: Options(
            headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    return ((r.data as Map<String, dynamic>)['code'] as num?)?.toInt() == 0;
  }

  /// 扫群二维码进群（返回会话对象）。
  /// join 幂等（重复调用服务端按"已是成员"跳过）→ 走瞬时重试，
  /// 服务端偶发 >10s 响应慢时自动重试，不再报「进群失败 receive timeout」
  Future<Map<String, dynamic>> joinGroup(String convId) async {
    final r = await _api.postIdempotent('/api/v1/conversation/$convId/join',
        headers: {'Authorization': 'Bearer ${await _api.readToken()}'});
    return _dataMap(r.data);
  }

  /// 扫码进群前的群信息预览（二次确认页：conversation + memberCount）。
  /// GET 走 ApiClient.get（自带瞬时重试）
  Future<Map<String, dynamic>> groupPreview(String convId) async {
    final r = await _api.get('/api/v1/conversation/$convId/preview');
    return _dataMap(r.data);
  }

  /// 邀请成员进群（群主/管理员，或开启"允许成员邀请"的普通成员）
  Future<bool> inviteMembers(String convId, List<String> userIds) async {
    final r = await _dio.post('/api/v1/conversation/$convId/invite',
        data: {'memberIds': userIds},
        options: Options(
            headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    final body = r.data as Map<String, dynamic>;
    final code = (body['code'] as num?)?.toInt() ?? 0;
    if (code != 0) throw ApiException(code, body['message']?.toString() ?? '');
    return code == 0;
  }

  /// 移除群成员（群主/管理员）
  Future<bool> removeMember(String convId, String userId) async {
    final r = await _dio.delete('/api/v1/conversation/$convId/members/$userId',
        options: Options(
            headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    final body = r.data as Map<String, dynamic>;
    final code = (body['code'] as num?)?.toInt() ?? 0;
    if (code != 0) throw ApiException(code, body['message']?.toString() ?? '');
    return code == 0;
  }

  /// 更新群信息（群名/群头像；name 双语同值，App 内单语言展示）
  Future<bool> updateGroupInfo(String convId,
      {String? name, String? avatar}) async {
    final r = await _dio.put('/api/v1/conversation/$convId',
        data: {
          if (name != null) ...{'nameZh': name, 'nameEn': name},
          if (avatar != null) 'avatar': avatar,
        },
        options: Options(
            headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
    final body = r.data as Map<String, dynamic>;
    final code = (body['code'] as num?)?.toInt() ?? 0;
    if (code != 0) throw ApiException(code, body['message']?.toString() ?? '');
    return code == 0;
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
