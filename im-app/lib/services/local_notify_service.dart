import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 本地通知（需求：App 在线/后台挂 WS 时，新消息在通知栏提示）。
/// 背景：服务端极光只推"不在 WS 在线集合"的离线用户，
/// App 在前台或后台挂着 WS 时服务端不推极光 → 由 App 端本地发通知补齐。
///
/// 前台（resumed）不发（页内已有铃声+红点）；后台/锁屏才发。
/// 点击通知默认拉起 App（落在会话列表，红点可见）。
class LocalNotifyService {
  LocalNotifyService._();
  static final LocalNotifyService instance = LocalNotifyService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _inited = false;

  Future<void> init() async {
    if (_inited || kIsWeb) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings();
      await _plugin.initialize(const InitializationSettings(
        android: android,
        iOS: ios,
      ));
      // Android 13+ 通知运行时权限（KeepAliveService 已统一申请过，这里兜底）
      final impl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await impl?.requestNotificationsPermission();
      _inited = true;
    } catch (e) {
      debugPrint('[LocalNotify] init failed: $e');
    }
  }

  /// 新消息通知（App 处于后台时由 ChatListPage 调用）
  Future<void> showMessage({
    required String title,
    required String body,
  }) async {
    if (!_inited || kIsWeb) return;
    try {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'im_messages', // channel id
          '消息通知', // channel name
          channelDescription: '新消息通知栏提醒',
          importance: Importance.high,
          priority: Priority.high,
          onlyAlertOnce: true,
        ),
        iOS: DarwinNotificationDetails(),
      );
      // id 用时间戳截断避免重复 ID 互相覆盖
      final id = DateTime.now().millisecondsSinceEpoch ~/ 1000 % 2147480000 +
          Random().nextInt(1000);
      await _plugin.show(id, title, body, details);
    } catch (e) {
      debugPrint('[LocalNotify] show failed: $e');
    }
  }
}
