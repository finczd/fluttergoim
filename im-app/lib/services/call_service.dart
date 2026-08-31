import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart' show MaterialPageRoute;
import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'ws_service.dart';

/// 通话阶段
enum CallPhase { idle, outgoing, incoming, connected }

/// 通话信令动作（承载在 type=7 消息的 content JSON 里）
class CallAction {
  static const invite = 'invite';
  static const accept = 'accept';
  static const reject = 'reject';
  static const hangup = 'hangup';
  static const cancel = 'cancel'; // 主叫在对方接听前挂断
}

/// 全局通话状态（UI 通过 ValueNotifier 监听）
class CallState {
  final String convId;
  final String callType; // voice / video
  final String peerName;
  final String peerAvatar;
  final CallPhase phase;
  final bool isCaller;

  const CallState({
    required this.convId,
    required this.callType,
    required this.peerName,
    required this.peerAvatar,
    required this.phase,
    required this.isCaller,
  });

  CallState copyWith({CallPhase? phase}) => CallState(
        convId: convId,
        callType: callType,
        peerName: peerName,
        peerAvatar: peerAvatar,
        phase: phase ?? this.phase,
        isCaller: isCaller,
      );
}

/// 一次性通话事件（供通话页弹提示 / 关闭页面）
class CallEvent {
  final String action; // accept / reject / hangup / cancel / timeout
  final String convId;
  final int duration;
  const CallEvent(this.action, this.convId, {this.duration = 0});
}

/// 通话信令服务（全局单例）
///
/// 职责：
/// 1. 主叫：发 invite → 等 accept（超时 45s 自动 cancel）
/// 2. 被叫：收 invite → 置 incoming（UI 弹来电页）→ accept/reject
/// 3. 任一方挂断：发 hangup（带时长），对端收到后关闭
///
/// 信令全部走 type=7 消息，content 为 JSON：{action, callType, roomId, ...}
class CallService {
  CallService._();
  static final CallService instance = CallService._();

  final ValueNotifier<CallState?> state = ValueNotifier(null);

  final _events = StreamController<CallEvent>.broadcast();
  Stream<CallEvent> get events => _events.stream;

  VoidCallback? _wsCancel;
  String _myId = '';
  Timer? _ringTimer;
  DateTime? _connectedAt;

  static const int _ringTimeoutSec = 45;

  /// 通话累计秒数（通话页每秒回写，挂断时用于上报通话时长）
  int _callSeconds = 0;

  int get callSeconds => _callSeconds;

  /// 通话页每秒回写一次自己的计时
  void syncCallSeconds(int s) {
    _callSeconds = s;
  }

  String get myId => _myId;

  /// 登录后调用：登记自己的 ID + 挂上全局 WS 监听
  Future<void> attach() async {
    await _ensureMyId();
    _wsCancel ??= GlobalWs.instance.onMessage(_onWsMessage);
    GlobalWs.instance.ensureConnected();
  }

  /// 自己的 ID（用于过滤自己信令的回显，避免把自己发的 invite 当成来电）
  Future<void> _ensureMyId() async {
    if (_myId.isNotEmpty) return;
    try {
      final r = await ApiClient.instance.get('/api/v1/user/profile');
      _myId =
          ((r.data['data'] as Map<String, dynamic>?)?['id'])?.toString() ?? '';
    } catch (_) {}
  }

  void detach() {
    _wsCancel?.call();
    _wsCancel = null;
    _ringTimer?.cancel();
    _ringTimer = null;
    state.value = null;
  }

  /// 退出登录 / 切换账号：把通话相关的全局态彻底清干净。
  /// 不清的话 `_myId` 仍是上一个账号，接听来电时会把自己的信令回显误判成对方来电。
  Future<void> resetSession() async {
    _ringTimer?.cancel();
    _ringTimer = null;
    _connectedAt = null;
    _callSeconds = 0;
    state.value = null;
    detach();
    _myId = ''; // 换号登录必须清空，否则 attach 时会复用旧 ID
  }

  // ============================ 主叫 ============================

  /// 发起通话：发 invite 信令，进入 outgoing（等待对方接听）
  Future<void> startCall({
    required String convId,
    required String callType,
    required String peerName,
    String peerAvatar = '',
  }) async {
    await _sendSignal(
      convId: convId,
      action: CallAction.invite,
      callType: callType,
    );
    state.value = CallState(
      convId: convId,
      callType: callType,
      peerName: peerName,
      peerAvatar: peerAvatar,
      phase: CallPhase.outgoing,
      isCaller: true,
    );
    _startRingTimeout(convId);
  }

  void _startRingTimeout(String convId) {
    _ringTimer?.cancel();
    _ringTimer = Timer(const Duration(seconds: _ringTimeoutSec), () {
      final s = state.value;
      if (s != null && s.convId == convId && s.phase == CallPhase.outgoing) {
        _sendSignal(
            convId: convId,
            action: CallAction.cancel,
            callType: s.callType,
            silent: true);
        _reset();
        _emit(CallEvent(CallAction.cancel, convId));
      }
    });
  }

  // ============================ 被叫 ============================

  /// 接听：发 accept，进入 connected
  Future<void> accept() async {
    final s = state.value;
    if (s == null) return;
    _ringTimer?.cancel();
    await _sendSignal(
      convId: s.convId,
      action: CallAction.accept,
      callType: s.callType,
    );
    _connectedAt = DateTime.now();
    _callSeconds = 0;
    state.value = s.copyWith(phase: CallPhase.connected);
    _emit(CallEvent(CallAction.accept, s.convId));
  }

  /// 拒接：发 reject，回到 idle
  Future<void> reject() async {
    final s = state.value;
    if (s == null) return;
    _ringTimer?.cancel();
    await _sendSignal(
      convId: s.convId,
      action: CallAction.reject,
      callType: s.callType,
      silent: true,
    );
    _reset();
  }

  // ============================ 通用 ============================

  /// 挂断：发 hangup（带通话时长），回到 idle
  Future<void> hangup() async {
    final s = state.value;
    if (s == null) return;
    _ringTimer?.cancel();
    _connectedAt = null;
    // 主叫在对方未接听时挂断 → 发 cancel；已接通 → 发 hangup
    final action =
        s.phase == CallPhase.connected ? CallAction.hangup : CallAction.cancel;
    await _sendSignal(
      convId: s.convId,
      action: action,
      callType: s.callType,
      duration: _elapsedSec(),
      silent: true,
    );
    _reset();
  }

  int _elapsedSec() {
    final t = _connectedAt;
    if (t == null) return 0;
    return DateTime.now().difference(t).inSeconds;
  }

  void _reset() {
    _ringTimer?.cancel();
    _ringTimer = null;
    _connectedAt = null;
    state.value = null;
    _callSeconds = 0;
  }

  void _emit(CallEvent e) {
    if (!_events.isClosed) _events.add(e);
  }

  // ============================ 收信令 ============================

  Future<void> _onWsMessage(Map<String, dynamic> m) async {
    // 只处理通话信令 type=7
    final type = (m['type'] as num?)?.toInt();
    if (type != 7) return;

    // 自己 ID 未知时补拉一次，否则会把自己的信令回显当成对方来电
    await _ensureMyId();
    final senderId = m['senderId']?.toString() ?? '';
    // 自己的回显忽略
    if (senderId.isNotEmpty && senderId == _myId) return;

    final convId = m['conversationId']?.toString() ?? '';
    if (convId.isEmpty) return;

    Map<String, dynamic> sig = {};
    try {
      final raw = m['content'];
      sig = raw is String
          ? (jsonDecode(raw) as Map<String, dynamic>)
          : (raw as Map<String, dynamic>);
    } catch (_) {
      return;
    }
    final action = sig['action']?.toString() ?? CallAction.invite;
    final callType = sig['callType']?.toString() ?? 'voice';

    switch (action) {
      case CallAction.invite:
        // 已在通话中 → 直接回 busy（用 reject 语义）
        if (state.value != null) {
          _sendSignal(
              convId: convId,
              action: CallAction.reject,
              callType: callType,
              silent: true);
          return;
        }
        state.value = CallState(
          convId: convId,
          callType: callType,
          peerName: sig['callerName']?.toString() ?? '',
          peerAvatar: sig['callerAvatar']?.toString() ?? '',
          phase: CallPhase.incoming,
          isCaller: false,
        );
        break;

      case CallAction.accept:
        final s = state.value;
        if (s == null || s.convId != convId) return;
        _ringTimer?.cancel();
        _connectedAt = DateTime.now();
        _callSeconds = 0;
        state.value = s.copyWith(phase: CallPhase.connected);
        _emit(CallEvent(CallAction.accept, convId));
        break;

      case CallAction.reject:
      case CallAction.hangup:
      case CallAction.cancel:
        final s = state.value;
        if (s == null || s.convId != convId) return;
        _reset();
        _emit(CallEvent(action, convId,
            duration: (sig['duration'] as num?)?.toInt() ?? 0));
        break;
    }
  }

  // ============================ 发送信令 ============================

  Future<void> _sendSignal({
    required String convId,
    required String action,
    required String callType,
    int duration = 0,
    bool silent = false,
  }) async {
    try {
      final token = await ApiClient.instance.readToken();
      await ApiClient.instance.dio.post(
        '/api/v1/message/send',
        data: {
          'conversationId': convId,
          'type': 7,
          'content': jsonEncode({
            'action': action,
            'callType': callType,
            'roomId': convId,
            'duration': duration,
            'callerName': state.value?.peerName ?? '',
            'ts': DateTime.now().millisecondsSinceEpoch,
          }),
          'clientMsgId':
              'call-$action-${DateTime.now().millisecondsSinceEpoch}',
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (_) {
      // 信令发送失败不阻断 UI
    }
  }

  /// 通话结束后写一条可见的通话记录（type=7 hangup，带时长）
  Future<void> writeCallRecord({int? duration}) async {
    final s = state.value;
    if (s == null) return;
    await _sendSignal(
      convId: s.convId,
      action: CallAction.hangup,
      callType: s.callType,
      duration: duration ?? _elapsedSec(),
    );
  }
}
