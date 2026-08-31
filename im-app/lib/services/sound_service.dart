import 'package:audioplayers/audioplayers.dart';

import 'settings_service.dart';

/// 铃声 / 提示音服务（新消息 / 来电 / 加好友）
/// - 短提示音：一次播放（消息、加好友）
/// - 来电铃声：循环播放，接听/拒绝时停止
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  final AudioPlayer _msg = AudioPlayer();
  final AudioPlayer _friend = AudioPlayer();
  AudioPlayer? _ring; // 来电铃声（循环）

  /// 新消息提示音
  Future<void> playNewMessage() async {
    // 系统通知开关关闭时不播放提示音
    if (!AppSettings.instance.notifications) return;
    try {
      await _msg.stop();
      await _msg.play(AssetSource('sounds/msg.wav'));
    } catch (_) {}
  }

  /// 被添加好友提示音
  Future<void> playFriendAdded() async {
    try {
      await _friend.stop();
      await _friend.play(AssetSource('sounds/friend.wav'));
    } catch (_) {}
  }

  /// 来电铃声（循环，语音/视频不同音色）
  Future<void> startRing({required bool video}) async {
    try {
      await stopRing();
      _ring = AudioPlayer()..setReleaseMode(ReleaseMode.loop);
      await _ring!.play(AssetSource(
          video ? 'sounds/ring_video.wav' : 'sounds/ring_voice.wav'));
    } catch (_) {}
  }

  /// 停止来电铃声（接听 / 拒绝 / 挂断时调用）
  Future<void> stopRing() async {
    try {
      await _ring?.stop();
      await _ring?.dispose();
      _ring = null;
    } catch (_) {
      _ring = null;
    }
  }
}
