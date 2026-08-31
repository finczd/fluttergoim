import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_config.dart';
import 'api_client.dart';
import 'wallet_store.dart';

/// WebSocket 长连接（消息实时收发）
/// - 连接时带 token 鉴权
/// - 30s 心跳续期在线状态
/// - 断线自动重连（指数退避，最大 30s），重连成功后回调 onReconnected 触发补拉
class WsService {
  WsService(
      {required this.onMessage,
      required this.onRecall,
      this.onReconnected,
      this.onRead,
      this.onWallet,
      this.onFriendRequest});

  /// 收到新消息：data = 服务端消息对象 Map
  final void Function(Map<String, dynamic> data) onMessage;

  /// 收到撤回通知：{conversationId, msgId, recalledBy}
  final void Function(Map<String, dynamic> data) onRecall;

  /// 收到余额变动通知：{balance, frozen}（B-24）
  /// 后台加款 / 红包被领 / 到期退回时服务端主动推，客户端收到即刷新，
  /// 不必再靠"切 tab"或"杀进程重进"才能看到新余额。
  final void Function(Map<String, dynamic> data)? onWallet;

  /// 收到已读事件：{conversationId, userId, msgId}
  final void Function(Map<String, dynamic> data)? onRead;

  /// 收到好友申请/通过事件（需求6：通讯录红点）
  final void Function(Map<String, dynamic> data)? onFriendRequest;

  /// 重连成功回调（用于按 lastSeq 补拉缺失消息）
  final void Function()? onReconnected;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _heartbeat;
  bool _closed = false;
  int _retry = 0;

  static const _maxRetrySec = 30;

  Future<void> connect(String token) async {
    _closed = false;
    _retry = 0;
    _open(token);
  }

  void _open(String token) {
    if (_closed) return;
    try {
      final wsBase = AppConfig.instance.wsBase;
      final wsUrl = _resolveWsUrl(wsBase, token);
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _sub = _channel!.stream.listen(
        (data) => _handleFrame(data),
        onDone: () => _scheduleReconnect(token),
        onError: (_) => _scheduleReconnect(token),
        cancelOnError: true,
      );
      _startHeartbeat();
    } catch (_) {
      _scheduleReconnect(token);
    }
  }

  /// WS 地址解析：相对路径（H5 场景，如 /ws）→ 拼当前页面 origin 转 ws/wss
  String _resolveWsUrl(String wsBase, String token) {
    // deviceType：H5=3(web) / native=1(android)——用于在线状态多端登记
    final base = Uri.base;
    final deviceType =
        (base.scheme == 'http' || base.scheme == 'https') ? 3 : 1;
    if (wsBase.startsWith('ws://') || wsBase.startsWith('wss://')) {
      return '$wsBase?token=$token&deviceType=$deviceType';
    }
    if (base.scheme == 'http' || base.scheme == 'https') {
      final scheme = base.scheme == 'https' ? 'wss' : 'ws';
      return '$scheme://${base.authority}$wsBase?token=$token&deviceType=$deviceType';
    }
    return '$wsBase?token=$token&deviceType=$deviceType'; // native 未配置时回退
  }

  void _handleFrame(dynamic raw) {
    final Map<String, dynamic> frame;
    try {
      frame = jsonDecode(raw.toString()) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (frame['type']) {
      case 'pong':
        break;
      case 'message':
        final data = frame['data'];
        if (data is Map<String, dynamic>) onMessage(data);
        break;
      case 'recall':
        final data = frame['data'];
        if (data is Map<String, dynamic>) onRecall(data);
        break;
      case 'read':
        final data = frame['data'];
        if (data is Map<String, dynamic>) onRead?.call(data);
        break;
      case 'friend.request':
      case 'friend.accepted':
      case 'friend.deleted':
        final data = frame['data'];
        if (data is Map<String, dynamic>) onFriendRequest?.call(data);
        break;
      case 'wallet':
        // B-24：余额/冻结变动（后台加款、红包被领、到期退回）→ 立即拉最新值
        final data = frame['data'];
        onWallet?.call(data is Map<String, dynamic> ? data : const {});
        break;
    }
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 30), (_) {
      _channel?.sink.add(jsonEncode({'action': 'ping'}));
    });
  }

  void _scheduleReconnect(String token) {
    if (_closed) return;
    _heartbeat?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    final delay = (_retry * 2).clamp(1, _maxRetrySec);
    _retry++;
    Timer(Duration(seconds: delay), () {
      if (_closed) return;
      _open(token);
      onReconnected?.call(); // 重连成功 → 页面按 lastSeq 补拉
    });
  }

  void sendPing() {
    _channel?.sink.add(jsonEncode({'action': 'ping'}));
  }

  void close() {
    _closed = true;
    _heartbeat?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
  }
}

/// 全局 WS 单例：登录后建立一条长连接，各页面（会话列表/通讯录/聊天页）共享
/// 需求7：消息列表实时接收推送，无需刷新
class GlobalWs {
  static final GlobalWs instance = GlobalWs._();
  GlobalWs._();

  WsService? _ws;
  bool _connecting = false;

  final List<void Function(Map<String, dynamic>)> _messageListeners = [];
  final List<void Function(Map<String, dynamic>)> _recallListeners = [];
  final List<void Function(Map<String, dynamic>)> _readListeners = [];
  final List<void Function(Map<String, dynamic>)> _friendListeners = [];
  final List<void Function()> _reconnectedListeners = [];

  /// 建立全局连接（登录成功后调用；已有连接则复用）
  Future<void> ensureConnected() async {
    if (_ws != null || _connecting) return;
    _connecting = true;
    try {
      final token = await ApiClient.instance.readToken();
      if (token == null) return;
      _ws = WsService(
        onMessage: (m) => _notify(_messageListeners, m),
        onRecall: (m) => _notify(_recallListeners, m),
        onRead: (m) => _notify(_readListeners, m),
        onFriendRequest: (m) => _notify(_friendListeners, m),
        // B-24：余额变动是**全局**事件，与当前停在哪个页面无关，
        // 所以不走页面监听器列表，直接刷 WalletStore（valueNotifier 会自动驱动 UI）。
        onWallet: (_) => unawaited(WalletStore.instance.refresh()),
        onReconnected: () {
          // 断线期间可能漏收余额变动，重连后补拉一次兜底
          unawaited(WalletStore.instance.refresh());
          for (final cb in _reconnectedListeners) {
            cb();
          }
        },
      );
      await _ws!.connect(token);
    } finally {
      _connecting = false;
    }
  }

  void _notify(
      List<void Function(Map<String, dynamic>)> list, Map<String, dynamic> m) {
    for (final cb in List.of(list)) {
      cb(m);
    }
  }

  /// 注册消息监听，返回取消函数
  VoidCallback onMessage(void Function(Map<String, dynamic>) cb) {
    _messageListeners.add(cb);
    return () => _messageListeners.remove(cb);
  }

  VoidCallback onRecall(void Function(Map<String, dynamic>) cb) {
    _recallListeners.add(cb);
    return () => _recallListeners.remove(cb);
  }

  VoidCallback onRead(void Function(Map<String, dynamic>) cb) {
    _readListeners.add(cb);
    return () => _readListeners.remove(cb);
  }

  VoidCallback onFriend(void Function(Map<String, dynamic>) cb) {
    _friendListeners.add(cb);
    return () => _friendListeners.remove(cb);
  }

  VoidCallback onReconnected(void Function() cb) {
    _reconnectedListeners.add(cb);
    return () => _reconnectedListeners.remove(cb);
  }

  void close() {
    _ws?.close();
    _ws = null;
    _messageListeners.clear();
    _recallListeners.clear();
    _readListeners.clear();
    _friendListeners.clear();
    _reconnectedListeners.clear();
  }
}
