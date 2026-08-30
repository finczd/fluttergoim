import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'trtc_engine.dart';

/// 视频通话页（设计稿：黑色背景 + 远端视频大画面 + 顶部最小化 + 中央对方姓名标签 + 底部按钮栏 + 自己的小窗）
/// 需求11：接腾讯云 TRTC（native 真通话 / H5 模拟）
class VideoCallPage extends StatefulWidget {
  final String peerName;
  final String? convId; // 会话 ID（房间号）
  const VideoCallPage({super.key, required this.peerName, this.convId});

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

  @override
  void initState() {
    super.initState();
    _initTrtc();
  }

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
        isVideo: true,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 远端视频占满
          Positioned.fill(
            child: _cameraOff
                ? _blackPlaceholder()
                : Container(color: const Color(0xFF1A1A1A)),
          ),
          // 顶部 + 底部渐变遮罩（设计稿）
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black54,
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black87,
                    ],
                    stops: [0, 0.18, 0.65, 1],
                  ),
                ),
              ),
            ),
          ),
          // 顶部：最小化 + 安全 + 标题
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _hangup,
                    icon: const Icon(Icons.expand_more,
                        color: Colors.white, size: 28),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      const Icon(Icons.lock, color: Colors.white70, size: 14),
                      const SizedBox(width: 4),
                      Text('端到端加密', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12)),
                    ],
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
          // 中央下方：对方姓名 + 通话时长
          Positioned(
            left: 0, right: 0, top: 80,
            child: Center(
              child: Column(
                children: [
                  Text(widget.peerName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Text(_connecting ? _status : (_seconds == 0 ? _status : _timeText),
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 13)),
                ],
              ),
            ),
          ),
          // 自己的小窗（右上角）
          Positioned(
            right: 16, top: 100,
            child: Container(
              width: 110, height: 150,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white24, width: 1),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(_cameraOff ? Icons.videocam_off : Icons.person,
                        color: Colors.white24, size: 36),
                  ),
                  if (_cameraOff)
                    const Center(
                      child: Text('摄像头已关',
                          style: TextStyle(color: Colors.white60, fontSize: 11)),
                    ),
                ],
              ),
            ),
          ),
          // 底部按钮栏
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
                child: _bottomBar(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blackPlaceholder() {
    return Container(
      color: const Color(0xFF1A1A1A),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam_off, color: Colors.white24, size: 64),
          const SizedBox(height: 12),
          Text('对方已关闭摄像头', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ctrlBtn(_muted ? Icons.mic_off : Icons.mic, _muted ? '已静音' : '麦克风',
            () => setState(() => _muted = !_muted), active: _muted),
        _ctrlBtn(Icons.call_end, '挂断', _hangup, danger: true),
        _ctrlBtn(_cameraOff ? Icons.videocam_off : Icons.videocam,
            _cameraOff ? '已关闭' : '摄像头',
            () => setState(() => _cameraOff = !_cameraOff),
            active: _cameraOff),
        _ctrlBtn(Icons.cameraswitch, '翻转', () => setState(() => _flipCam = !_flipCam),
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
            width: 60, height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: danger
                  ? AppTheme.danger
                  : (active ? Colors.white : Colors.white.withOpacity(0.2)),
            ),
            child: Icon(icon,
                color: active && !danger ? Colors.black : Colors.white,
                size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.85), fontSize: 12)),
      ],
    );
  }
}
