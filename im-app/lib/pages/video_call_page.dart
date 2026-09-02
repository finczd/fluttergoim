import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_locale.dart';
import '../services/api_client.dart';
import '../services/call_service.dart';
import '../theme/app_theme.dart';
import '../utils/call_permissions.dart';
import '../widgets/app_dialogs.dart';
import 'trtc_engine.dart';

/// 视频通话页（设计稿：黑色背景 + 远端视频大画面 + 中央对方姓名标签 + 底部按钮栏 + 自己的小窗）
/// 修复：按钮固定底部；全屏显示远端画面，右上角小窗显示本地预览；进房前申请麦克风/摄像头权限
class VideoCallPage extends StatefulWidget {
  final String peerName;
  final String peerAvatar;
  final String? convId; // 会话 ID（房间号）
  const VideoCallPage(
      {super.key,
      required this.peerName,
      this.peerAvatar = '',
      this.convId});

  @override
  State<VideoCallPage> createState() => _VideoCallPageState();
}

class _VideoCallPageState extends State<VideoCallPage> {
  int _seconds = 0;
  bool _muted = false;
  bool _cameraOff = false;
  bool _flipCam = false;
  bool _connecting = true;
  String _status = '正在连接…';
  Timer? _timer;
  TrtcEngine? _engine;
  StreamSubscription<CallEvent>? _sub;

  bool _enteredRoom = false;
  bool _trtcEnabled = false;
  bool _prepared = false; // TRTC 配置是否已拉取完成
  bool _pendingAccept = false; // 配置未就绪时先收到的 accept
  Map<String, dynamic> _sig = {};

  /// 取本地化文案（未挂载时回退为 key，避免访问失效 context）
  String _t(String key, [Map<String, String>? params]) =>
      mounted ? AppLocalizations.of(context).t(key, params) : key;

  String? _remoteUserId;
  int? _localViewId;
  int? _remoteViewId;

  @override
  void initState() {
    super.initState();
    _sub = CallService.instance.events.listen(_onCallEvent);
    _prepare();
  }

  /// 订阅信令事件：accept → 进房；reject/hangup/cancel → 结束
  void _onCallEvent(CallEvent e) {
    if (e.convId != widget.convId) return;
    switch (e.action) {
      case CallAction.accept:
        _pendingAccept = true;
        _maybeEnter();
        break;
      case CallAction.reject:
        _finish(_t('videoCallPeerRejected'));
        break;
      case CallAction.hangup:
        _finish(_t('videoCallEnded'));
        break;
      case CallAction.cancel:
        _finish(_t('videoCallPeerCancelled'));
        break;
    }
  }

  /// 拉 TRTC 配置；若此时已接通则立即进房，否则等待 accept
  Future<void> _prepare() async {
    try {
      final api = ApiClient.instance;
      final conf = await api.get('/api/v1/trtc/config');
      final c = (conf.data['data'] as Map<String, dynamic>?) ?? {};
      debugPrint('[TRTC] config: $c');
      if (c['enabled'] != true) {
        debugPrint('[TRTC] 未启用或 appId 无效，走模拟通话');
        _trtcEnabled = false;
        _prepared = true;
        _maybeEnter();
        return;
      }
      final sig = await api
          .get('/api/v1/trtc/usersig', query: {'room': widget.convId ?? ''});
      final d = (sig.data['data'] as Map<String, dynamic>?) ?? {};
      debugPrint('[TRTC] usersig: $d');
      if (d['userSig'] == null) {
        _prepared = true;
        _setStatus(_t('videoCallUserSigFailed'));
        return;
      }
      _sig = d;
      _trtcEnabled = true;
      _prepared = true;
      _maybeEnter();
    } catch (e) {
      debugPrint('[TRTC] 拉配置失败: $e');
      _prepared = true;
      _setStatus(_t('videoCallStartFailed', {'error': '$e'}));
    }
  }

  /// 已接通（或已收到 accept）→ 进房；否则显示"等待对方接听…"
  void _maybeEnter() {
    final phase = CallService.instance.state.value?.phase;
    if (phase == CallPhase.connected || _pendingAccept) {
      _enterRoom();
    } else {
      _setStatus(_t('videoCallWaitingAnswer'));
    }
  }

  /// 进 TRTC 房间（TRTC 未配置时提示管理员配置，不再模拟通话）
  Future<void> _enterRoom() async {
    if (_enteredRoom || !mounted) return;
    if (!_prepared) return;
    _enteredRoom = true;

    if (!_trtcEnabled) {
      debugPrint('[Call] TRTC 未配置，请在后台系统配置填入 SDKAppID/SecretKey');
      setState(() => _status = _t('videoCallTrtcNotConfigured'));
      _startTimer();
      return;
    }
    try {
      final roomId = int.tryParse((widget.convId ?? '').isNotEmpty
              ? widget.convId!.substring(widget.convId!.length - 8)
              : '1') ??
          1;
      debugPrint('[Call] 申请麦克风/摄像头权限...');
      final granted = await CallPermissions.ensureForVideo();
      if (!granted) {
        debugPrint('[Call] 权限被拒');
        _setStatus(_t('videoCallNeedPermissions'));
        return;
      }
      debugPrint('[Call] 权限已获取，准备进房: room=$roomId');
      final engine = createTrtcEngine()
        ..onRemoteUserEntered = _onRemoteUserEntered
        ..onRemoteUserLeft = _onRemoteUserLeft;
      final err = await engine.enterRoom(
        sdkAppId: (_sig['appId'] as num?)?.toInt() ?? 0,
        userId: _sig['userId']?.toString() ?? '',
        userSig: _sig['userSig']?.toString() ?? '',
        roomId: roomId,
        isVideo: true,
      );
      if (err != null) {
        debugPrint('[Call] 进房失败: $err');
        _setStatus(err);
        return;
      }
      _engine = engine;
      debugPrint('[Call] 已成功加入房间');
      setState(() {
        _connecting = false;
        _status = _t('videoCallInProgress');
      });
      _startTimer();
      if (_localViewId != null) {
        engine.startLocalPreview(_localViewId!);
      }
    } catch (e) {
      debugPrint('[Call] 进房异常: $e');
      _setStatus(_t('videoCallEnterRoomFailed', {'error': '$e'}));
    }
  }

  void _onRemoteUserEntered(String userId) {
    debugPrint('[Call] 远端用户进入房间: $userId');
    if (!mounted) return;
    setState(() => _remoteUserId = userId);
    if (_remoteViewId != null) {
      _engine?.startRemoteView(userId, _remoteViewId!);
    }
  }

  void _onRemoteUserLeft(String userId) {
    debugPrint('[Call] 远端用户离开房间: $userId');
    if (!mounted) return;
    if (_remoteUserId == userId) {
      _engine?.stopRemoteView(userId);
      setState(() => _remoteUserId = null);
    }
  }

  void _onLocalViewCreated(int viewId) {
    _localViewId = viewId;
    if (_engine != null && _enteredRoom) {
      _engine?.startLocalPreview(viewId);
    }
  }

  void _onRemoteViewCreated(int viewId) {
    _remoteViewId = viewId;
    if (_remoteUserId != null && _engine != null) {
      _engine?.startRemoteView(_remoteUserId!, viewId);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (!mounted) return;
    setState(() => _connecting = false);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
      CallService.instance.syncCallSeconds(_seconds);
    });
  }

  void _setStatus(String s) {
    if (!mounted) return;
    setState(() {
      _status = s;
      _connecting = true;
    });
  }

  /// 结束通话：提示 N 秒后自动退出
  void _finish(String msg) {
    if (!mounted) return;
    _timer?.cancel();
    setState(() {
      _status = msg;
      _connecting = true;
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    _engine?.exitRoom();
    super.dispose();
  }

  String get _timeText {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// 挂断：经 CallService 发 hangup/cancel 信令（含时长），会话里可见通话记录
  Future<void> _hangup() async {
    _timer?.cancel();
    await CallService.instance.hangup();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _toggleMute() async {
    setState(() => _muted = !_muted);
    await _engine?.setMuted(_muted);
  }

  Future<void> _toggleCamera() async {
    setState(() => _cameraOff = !_cameraOff);
    await _engine?.setCameraOn(!_cameraOff);
  }

  Future<void> _switchCamera() async {
    setState(() => _flipCam = !_flipCam);
    await _engine?.switchCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // 顶部：最小化 + 安全 + 标题
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  const SizedBox(width: 48),
                  const Spacer(),
                  Row(
                    children: [
                      const Icon(Icons.lock, color: Colors.white70, size: 14),
                      const SizedBox(width: 4),
                      Text(_t('videoCallEndToEndEncrypted'),
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 12)),
                    ],
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
          // 远端视频大画面（扩展占满剩余空间）
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                _remoteArea(),
                // 顶部渐变遮罩
                IgnorePointer(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black54, Colors.transparent],
                      ),
                    ),
                  ),
                ),
                // 底部渐变遮罩
                IgnorePointer(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black87, Colors.transparent],
                      ),
                    ),
                  ),
                ),
                // 中央：对方头像 + 姓名 + 通话时长（需求4：拨打界面显示对方昵称+头像）
                Align(
                  alignment: const Alignment(0, -0.55),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _peerAvatarBadge(),
                      const SizedBox(height: 10),
                      Text(widget.peerName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 6),
                      Text(
                          _connecting
                              ? _status
                              : (_seconds == 0 ? _status : _timeText),
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 13)),
                    ],
                  ),
                ),
                // 本地小窗（右上角）
                Positioned(
                  right: 16,
                  top: 16,
                  child: _localPip(),
                ),
              ],
            ),
          ),
          // 底部按钮栏（固定到底部，不会被推到顶部）
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 24),
              child: _bottomBar(),
            ),
          ),
        ],
      ),
    );
  }

  /// 对方头像（无头像或加载失败回退首字母圆形）
  Widget _peerAvatarBadge() {
    final initial =
        widget.peerName.isEmpty ? '?' : widget.peerName.characters.first;
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppTheme.primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: widget.peerAvatar.isNotEmpty
          ? Image.network(
              widget.peerAvatar,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Text(initial,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w600)),
            )
          : Text(initial,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w600)),
    );
  }

  /// 远端视频区域：远端画面视图常驻（viewId 提前就绪），无远端时盖状态占位
  Widget _remoteArea() {
    if (!_enteredRoom || _engine == null || !_trtcEnabled) {
      return _statusPlaceholder(_status);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        _engine!.remoteVideoView(onViewCreated: _onRemoteViewCreated),
        if (_remoteUserId == null)
          IgnorePointer(child: _statusPlaceholder(_t('videoCallWaitingAnswer'))),
      ],
    );
  }

  Widget _statusPlaceholder(String text) {
    return Container(
      color: const Color(0xFF1A1A1A),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_cameraOff ? Icons.videocam_off : Icons.videocam,
              color: Colors.white24, size: 64),
          const SizedBox(height: 12),
          Text(text,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
        ],
      ),
    );
  }

  /// 本地预览小窗
  Widget _localPip() {
    if (_engine == null || !_trtcEnabled) {
      return _pipPlaceholder(Icons.person);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 110,
        height: 150,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: _cameraOff
            ? _pipPlaceholder(Icons.videocam_off,
                label: _t('videoCallCameraOffLabel'))
            : _engine!.localVideoView(onViewCreated: _onLocalViewCreated),
      ),
    );
  }

  Widget _pipPlaceholder(IconData icon, {String? label}) {
    return Container(
      width: 110,
      height: 150,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white24, size: 36),
          if (label != null) ...[
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(color: Colors.white60, fontSize: 11)),
          ],
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ctrlBtn(_muted ? Icons.mic_off : Icons.mic,
            _muted ? _t('videoCallMuted') : _t('videoCallMicrophone'),
            _toggleMute,
            active: _muted),
        _ctrlBtn(Icons.call_end, _t('videoCallHangUp'), _hangup, danger: true),
        _ctrlBtn(_cameraOff ? Icons.videocam_off : Icons.videocam,
            _cameraOff ? _t('videoCallCameraClosed') : _t('videoCallCamera'),
            _toggleCamera,
            active: _cameraOff),
        _ctrlBtn(Icons.cameraswitch, _t('videoCallFlip'), _switchCamera,
            active: _flipCam),
      ],
    );
  }

  Widget _ctrlBtn(IconData icon, String label, VoidCallback onTap,
      {bool active = false, bool danger = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkResponse(
          onTap: onTap,
          radius: 36,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: danger
                  ? AppTheme.danger
                  : (active
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.2)),
            ),
            child: Icon(icon,
                color: active && !danger ? Colors.black : Colors.white,
                size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
      ],
    );
  }
}
