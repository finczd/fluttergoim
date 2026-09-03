import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Android 保活服务（前台服务，flutter_foreground_task）
///
/// 设计：
///   - 仅 Android 启动：iOS 没有前台服务概念，强杀即销毁（离线推送兜底）。
///   - 目的：让 App 进程退到后台/划掉任务后仍存活，WS 长连接不断，
///     在线消息继续实时收；进程真被杀时走极光离线推送兜底。
///   - 通知权限在启动时通过插件 API 申请（覆盖 Android 13+ POST_NOTIFICATIONS），
///     顺带引导用户加电池优化白名单（国产 ROM 杀后台的主因）。
///   - 服务本身是"空任务"：不处理数据，只维持进程与通知栏常驻入口。
///
/// 注意：
///   - Android 15（targetSdk 35）对 dataSync 类型有 24 小时内最多 6 小时限制，
///     超时被系统杀后 allowAutoRestart 会自动重启服务兜底。
///   - 各厂商（小米/OPPO/VIVO/荣耀）的自启动/后台权限仍需用户手动开启，
///     通知权限弹框只是第一步。
class KeepAliveService {
  KeepAliveService._();
  static final KeepAliveService instance = KeepAliveService._();

  bool _inited = false;

  /// 进程级初始化：必须在 runApp 之前调用（main.dart），注册通信端口。
  void init() {
    if (kIsWeb) return; // 插件不支持 Web
    FlutterForegroundTask.initCommunicationPort();
  }

  /// 登录进首页后调用（HomeShell.initState）：
  /// 申请通知权限 + 电池优化白名单，然后启动前台服务。
  Future<void> start() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      _ensureInit();
      // Android 13+ 通知权限：未授权则弹系统授权框（只弹一次）
      final perm = await FlutterForegroundTask.checkNotificationPermission();
      if (perm != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
      // 电池优化白名单：国产 ROM 杀后台的头号原因，未加白则弹系统申请框
      if (!(await FlutterForegroundTask.isIgnoringBatteryOptimizations)) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
      // 启动前台服务（已在运行时插件内部会返回失败结果，不会抛异常）
      // notificationIcon：单色小图标（白色气泡），必须配合 AndroidManifest 的
      // meta-data io.github.imapp.keep_alive.notification_icon 使用；
      // 不传则插件回退 launcher 彩色图标 → 通知栏只渲染 alpha 通道显示灰色空白方块
      final result = await FlutterForegroundTask.startService(
        serviceTypes: const [
          ForegroundServiceTypes.dataSync,
          ForegroundServiceTypes.remoteMessaging,
        ],
        notificationTitle: '消息服务运行中',
        notificationText: '保持连接以确保消息及时送达',
        notificationIcon: const NotificationIcon(
          metaDataName: 'io.github.imapp.keep_alive.notification_icon',
        ),
        callback: startCallback,
      );
      if (result is ServiceRequestFailure) {
        debugPrint('[KeepAlive] start failed: ${result.error}');
      } else {
        debugPrint('[KeepAlive] foreground service started');
      }
    } catch (e) {
      // 保活失败不影响主流程（还有极光离线推送兜底）
      debugPrint('[KeepAlive] start error: $e');
    }
  }

  /// 退出登录时调用：停掉前台服务（通知栏消失，进程可被正常回收）
  Future<void> stop() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      if (!(await FlutterForegroundTask.isRunningService)) return;
      final result = await FlutterForegroundTask.stopService();
      if (result is ServiceRequestFailure) {
        debugPrint('[KeepAlive] stop failed: ${result.error}');
      }
    } catch (e) {
      debugPrint('[KeepAlive] stop error: $e');
    }
  }

  void _ensureInit() {
    if (_inited) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'keep_alive_service',
        channelName: '消息保活服务',
        channelDescription: '保持与消息服务器的连接，确保消息及时送达',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        showBadge: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        // 空任务：不注册周期回调，纯粹维持进程存活
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: true,
        // WS 长连接依赖 CPU 与 Wi-Fi，保持唤醒
        allowWakeLock: true,
        allowWifiLock: true,
        // Android 15 dataSync 6 小时超时被杀后自动重启服务（兜底）
        allowAutoRestart: true,
      ),
    );
    _inited = true;
  }
}

/// 前台服务入口：必须是顶层函数 + vm:entry-point（isolate 重入 Flutter 引擎用）
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(_KeepAliveHandler());
}

/// 空任务处理器：只保活，不处理数据/事件
class _KeepAliveHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}
