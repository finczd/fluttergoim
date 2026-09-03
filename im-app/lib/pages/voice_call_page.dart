import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_locale.dart';
import '../services/api_client.dart';
import '../services/call_service.dart';
import '../theme/app_theme.dart';
import '../utils/call_permissions.dart';
import '../widgets/app_dialogs.dart';
import 'trtc_engine.dart';

/// 语音通话页（设计稿：模糊背景 + 大头像 + 对方姓名 + 通话时长 + 底部按钮栏）
/// 需求11：接腾讯云 TRTC（native 真通话 / H5 占位）
/// 修复：真实进房前申请麦克风权限（TRTC 插件不会自动申请，缺权限双方都听不到声音）
class VoiceCallPage extends StatefulWidget {
  final String peerName;
  final String peerAvatar;
  final String? convId; // 会话 ID（房间号）
  const VoiceCallPage(
      {super.key, required this.peerName, this.peerAvatar = '', this.convId});

  @override
  State<VoiceCallPage> createState() => _VoiceCallPageState();
}

class _VoiceCallPageState extends State<VoiceCallPage> {
  int _seconds = 0;
  bool _muted = false;
  bool _speaker = true;
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
        _finish(_t('voiceCallPeerRejected'));
        break;
      case CallAction.hangup:
        _finish(_t('voiceCallEnded'));
        break;
      case CallAction.cancel:
        _finish(_t('voiceCallPeerCancelled'));
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
        _setStatus(_t('voiceCallUserSigFailed'));
        return;
      }
      _sig = d;
      _trtcEnabled = true;
      _prepared = true;
      _maybeEnter();
    } catch (e) {
      debugPrint('[TRTC] 拉配置失败: $e');
      _prepared = true;
      _setStatus(_t('voiceCallStartFailed', {'error': '$e'}));
    }
  }

  /// 已接通（或已收到 accept）→ 进房；否则显示"等待对方接听…"
  void _maybeEnter() {
    final phase = CallService.instance.state.value?.phase;
    if (phase == CallPhase.connected || _pendingAccept) {
      _enterRoom();
    } else {
      _setStatus(_t('voiceCallWaitingAnswer'));
    }
  }

  /// 进 TRTC 房间（TRTC 未配置时提示管理员配置，不再模拟通话）
  Future<void> _enterRoom() async {
    if (_enteredRoom || !mounted) return;
    if (!_prepared) return;
    _enteredRoom = true;

    if (!_trtcEnabled) {
      debugPrint('[Call] TRTC 未配置，请在后台系统配置填入 SDKAppID/SecretKey');
      setState(() => _status = _t('voiceCallTrtcNotConfigured'));
      _startTimer();
      return;
    }
    try {
      final roomId = int.tryParse((widget.convId ?? '').isNotEmpty
              ? widget.convId!.substring(widget.convId!.length - 8)
              : '1') ??
          1;
      debugPrint('[Call] 申请麦克风权限...');
      final granted = await CallPermissions.ensureForVoice();
      if (!granted) {
        debugPrint('[Call] 麦克风权限被拒');
        _setStatus(_t('voiceCallNeedMicPermission'));
        return;
      }
      debugPrint('[Call] 权限已获取，准备进房: room=$roomId');
      final engine = createTrtcEngine();
      final err = await engine.enterRoom(
        sdkAppId: (_sig['appId'] as num?)?.toInt() ?? 0,
        userId: _sig['userId']?.toString() ?? '',
        userSig: _sig['userSig']?.toString() ?? '',
        roomId: roomId,
        isVideo: false,
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
        _status = _t('voiceCallInProgress');
      });
      _startTimer();
    } catch (e) {
      debugPrint('[Call] 进房异常: $e');
      _setStatus(_t('voiceCallEnterRoomFailed', {'error': '$e'}));
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

  Future<void> _toggleSpeaker() async {
    setState(() => _speaker = !_speaker);
    await _engine?.setSpeaker(_speaker);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.primary.withValues(alpha: 0.3),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.6),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      const SizedBox(width: 48),
                      const Spacer(),
                      Text(_t('voiceCallTitle'),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14)),
                      const Spacer(),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                const SizedBox(height: 80),
                _bigAvatar(),
                const SizedBox(height: 16),
                Text(widget.peerName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(
                    _connecting
                        ? _status
                        : (_seconds == 0 ? _status : _timeText),
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                        letterSpacing: 1.2)),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 60),
                  child: _bottomBar(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bigAvatar() {
    final initial =
        widget.peerName.isEmpty ? '?' : widget.peerName.characters.first;
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: AppTheme.primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 24,
              offset: const Offset(0, 8)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      // 需求4：有头像显示网络头像，加载失败回退首字母
      child: widget.peerAvatar.isNotEmpty
          ? Image.network(
              widget.peerAvatar,
              width: 120,
              height: 120,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _initialAvatar(initial),
            )
          : _initialAvatar(initial),
    );
  }

  Widget _initialAvatar(String initial) => Text(initial,
      style: const TextStyle(
          color: Colors.white, fontSize: 44, fontWeight: FontWeight.w600));

  Widget _bottomBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ctrlBtn(
            _muted ? Icons.mic_off : Icons.mic,
            _muted ? _t('voiceCallMuted') : _t('voiceCallMicrophone'),
            _toggleMute,
            active: _muted),
        _ctrlBtn(Icons.call_end, _t('voiceCallHangUp'), _hangup, danger: true),
        _ctrlBtn(
            _speaker ? Icons.volume_up : Icons.volume_off,
            _speaker ? _t('voiceCallSpeaker') : _t('voiceCallEarpiece'),
            _toggleSpeaker,
            active: !_speaker),
      ],
    );
  }

  Widget _ctrlBtn(IconData icon, String label, VoidCallback onTap,
      {bool active = false, bool danger = false}) {
    final color = danger
        ? AppTheme.danger
        : active
            ? Colors.white
            : Colors.white.withValues(alpha: 0.85);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkResponse(
          onTap: onTap,
          radius: 36,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: danger
                  ? AppTheme.danger
                  : Colors.white.withValues(alpha: 0.2),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }
}
