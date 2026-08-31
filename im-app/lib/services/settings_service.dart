import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 全局设置（本地持久化）：深色模式 + 系统通知开关
class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  final _storage = const FlutterSecureStorage();

  /// 深色模式（false=浅色，true=深色）
  bool dark = false;

  /// 系统通知：新消息悬浮窗 + 提示音（false=静默）
  bool notifications = true;

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> init() async {
    try {
      dark = (await _storage.read(key: 'set_dark')) == '1';
      notifications = (await _storage.read(key: 'set_notify')) != '0';
    } catch (_) {}
    _loaded = true;
    notifyListeners();
  }

  Future<void> setDark(bool v) async {
    if (dark == v) return;
    dark = v;
    try {
      await _storage.write(key: 'set_dark', value: v ? '1' : '0');
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setNotifications(bool v) async {
    if (notifications == v) return;
    notifications = v;
    try {
      await _storage.write(key: 'set_notify', value: v ? '1' : '0');
    } catch (_) {}
    notifyListeners();
  }
}
