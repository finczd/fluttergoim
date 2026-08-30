import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tencent_trtc_cloud/tencent_trtc_cloud.dart';

import 'trtc_engine.dart';

/// native 实现：腾讯云 TRTC 官方 Flutter 插件
class TrtcEngineImpl implements TrtcEngine {
  TRTCCloud? _cloud;
  bool _inRoom = false;

  @override
  bool get isReal => true;

  @override
  Future<String?> enterRoom({
    required int sdkAppId,
    required String userId,
    required String userSig,
    required int roomId,
    required bool isVideo,
    dynamic localView,
    dynamic remoteView,
  }) async {
    try {
      final cloud = await TRTCCloud.sharedInstance();
      _cloud = cloud;
      // 监听远端画面
      cloud.onRemoteUserEnterRoom = (userId) {
        debugPrint('[TRTC] remote user enter: $userId');
      };
      cloud.onRemoteUserLeaveRoom = (userId, reason) {
        debugPrint('[TRTC] remote user leave: $userId reason=$reason');
      };
      cloud.onFirstVideoFrame = (userId, streamType, width, height) {
        debugPrint('[TRTC] first video frame: $userId');
      };
      // 进房参数
      final params = TRTCParams(
        sdkAppId: sdkAppId,
        userId: userId,
        userSig: userSig,
        roomId: roomId,
        role: TRTCRole.anchor,
      );
      await cloud.enterRoom(params);
      _inRoom = true;
      // 采集音频
      final audioParams = TRTCAudioQuality.defaultMode;
      await cloud.startLocalAudio(quality: audioParams);
      if (isVideo && localView is int) {
        await cloud.startLocalPreview(isFrontCamera: true, viewId: localView);
      }
      return null;
    } catch (e) {
      return 'TRTC 初始化失败: $e';
    }
  }

  @override
  Future<void> exitRoom() async {
    if (_cloud != null && _inRoom) {
      try {
        await _cloud!.stopLocalAudio();
        await _cloud!.exitRoom();
      } catch (_) {}
      _inRoom = false;
    }
    if (_cloud != null) {
      TRTCCloud.destroySharedInstance();
      _cloud = null;
    }
  }

  @override
  Future<void> setMuted(bool muted) async {
    try {
      if (muted) {
        await _cloud?.muteLocalAudio();
      } else {
        await _cloud?.unmuteLocalAudio();
      }
    } catch (_) {}
  }

  @override
  Future<void> setSpeaker(bool on) async {
    try {
      await _cloud?.setAudioRoute(on ? TRTCAudioRoute.speaker : TRTCAudioRoute.earpiece);
    } catch (_) {}
  }

  @override
  Future<void> setCameraOn(bool on) async {
    try {
      if (on) {
        await _cloud?.startLocalPreview(isFrontCamera: true);
      } else {
        await _cloud?.stopLocalPreview();
      }
    } catch (_) {}
  }
}
