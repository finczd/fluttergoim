import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

/// WebSocket 长连接（消息实时收发）
/// - 连接时带 token 鉴权
/// - 30s 心跳续期在线状态
/// - 断线自动重连（指数退避，最大 30s），重连成功后回调 onReconnected 触发补拉
class WsService {
  WsService({required this.onMessage, required this.onRecall, this.onReconnected, this.onRead});

  /// 收到新消息：data = 服务端消息对象 Map
  final void Function(Map<String, dynamic> data) onMessage;

  /// 收到撤回通知：{conversationId, msgId, recalledBy}
  final void Function(Map<String, dynamic> data) onRecall;

  /// 收到已读事件：{conversationId, userId, msgId}
  final void Function(Map<String, dynamic> data)? onRead;

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
      final wsBase = const String.fromEnvironment('WS_BASE_URL',
          defaultValue: 'ws://192.168.1.11:9090/ws');
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
    final deviceType = (base.scheme == 'http' || base.scheme == 'https') ? 3 : 1;
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
