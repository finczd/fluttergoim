import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'trtc_engine.dart';

/// 语音通话页（设计稿：模糊背景 + 大头像 + 对方姓名 + 通话时长 + 底部按钮栏）
/// 需求11：接腾讯云 TRTC（native 真通话 / H5 模拟）
class VoiceCallPage extends StatefulWidget {
  final String peerName;
  final String peerAvatar;
  final String? convId; // 会话 ID（房间号）
  const VoiceCallPage({super.key, required this.peerName, this.peerAvatar = '', this.convId});

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

  @override
  void initState() {
    super.initState();
    _initTrtc();
  }

  /// 需求11：后端拉 TRTC 配置 + usersig → 进房
  Future<void> _initTrtc() async {
    try {
      final api = ApiClient.instance;
      final conf = await api.get('/api/v1/trtc/config');
      final c = (conf.data['data'] as Map<String, dynamic>?) ?? {};
      if (c['enabled'] != true) {
        _setStatus('TRTC 未配置，模拟通话');
        return;
      }
      final sig = await api.get('/api/v1/trtc/usersig',
          query: {'room': widget.convId ?? ''});
      final d = (sig.data['data'] as Map<String, dynamic>?) ?? {};
      if (d['userSig'] == null) {
        _setStatus('获取音视频凭证失败');
        return;
      }
      final roomId = int.tryParse((widget.convId ?? '').isNotEmpty
              ? widget.convId!.substring(widget.convId!.length - 8)
              : '1') ??
          1;
      final engine = createTrtcEngine();
      final err = await engine.enterRoom(
        sdkAppId: (d['appId'] as num?)?.toInt() ?? 0,
        userId: d['userId']?.toString() ?? '',
        userSig: d['userSig']?.toString() ?? '',
        roomId: roomId,
        isVideo: false,
      );
      if (err != null) {
        _setStatus(err);
        return;
      }
      _engine = engine;
      setState(() => _connecting = false);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _seconds++);
      });
    } catch (e) {
      _setStatus('通话启动失败: $e');
    }
  }

  void _setStatus(String s) {
    if (!mounted) return;
    setState(() {
      _status = s;
      _connecting = false;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _engine?.exitRoom();
    super.dispose();
  }

  String get _timeText {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _hangup() => Navigator.of(context).pop();

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
                  AppTheme.primary.withOpacity(0.3),
                  Colors.transparent,
                  Colors.black.withOpacity(0.6),
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
                      IconButton(
                        onPressed: _hangup,
                        icon: const Icon(Icons.expand_more,
                            color: Colors.white, size: 28),
                      ),
                      const Spacer(),
                      const Text('语音通话',
                          style: TextStyle(color: Colors.white, fontSize: 14)),
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
                        color: Colors.white.withOpacity(0.7),
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
    final initial = widget.peerName.isEmpty ? '?' : widget.peerName.characters.first;
    return Container(
      width: 120, height: 120,
      decoration: BoxDecoration(
        color: AppTheme.primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 24,
              offset: const Offset(0, 8)),
        ],
      ),
      alignment: Alignment.center,
      child: Text(initial,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 44,
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _bottomBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ctrlBtn(_muted ? Icons.mic_off : Icons.mic, _muted ? '已静音' : '麦克风',
            _toggleMute,
            active: _muted),
        _ctrlBtn(Icons.call_end, '挂断', _hangup, danger: true),
        _ctrlBtn(_speaker ? Icons.volume_up : Icons.volume_off,
            _speaker ? '扬声器' : '听筒',
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
            : Colors.white.withOpacity(0.85);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkResponse(
          onTap: onTap,
          radius: 36,
          child: Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: danger ? AppTheme.danger : Colors.white.withOpacity(0.2),
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
