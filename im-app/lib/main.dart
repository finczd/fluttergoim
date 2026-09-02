import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'app_navigator.dart';
import 'config/app_config.dart';
import 'l10n/app_locale.dart';
import 'pages/home_shell.dart';
import 'pages/incoming_call_page.dart';
import 'pages/login_page.dart';
import 'services/api_client.dart';
import 'services/keep_alive_service.dart';
import 'services/local_notify_service.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Android 保活：注册前台服务通信端口（必须 runApp 之前）
  KeepAliveService.instance.init();
  // 需求5：加载运行时接口配置（config/app_config.json），改 IP 不用重新编译
  await AppConfig.instance.loadRuntimeConfig();
  // 需求10：任意接口 401 且刷新失败 → 清登录态并跳转登录页
  ApiClient.instance.onUnauthorized = () {
    appNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  };
  // 需求7-8：加载本地设置（深色模式 / 通知开关）
  await AppSettings.instance.init();
  // 需求3：App 后台时 WS 新消息 → 通知栏本地通知（极光只推离线用户）
  unawaited(LocalNotifyService.instance.init());
  runApp(const ImApp());
}

class ImApp extends StatelessWidget {
  const ImApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppSettings>.value(
      value: AppSettings.instance,
      child: LocaleProvider(
        child: Builder(builder: (ctx) {
          // 主题实时切换：跟随 AppSettings 的深色模式开关
          final settings = ctx.watch<AppSettings>();
          // 语言实时切换：MaterialApp.locale 跟随 LocaleProvider 当前语言
          final loc = AppLocalizations.of(ctx).locale;
          return MaterialApp(
            title: 'ChatPulse',
            theme: settings.dark ? AppTheme.dark() : AppTheme.light(),
            locale: loc,
            supportedLocales: const [Locale('zh'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            navigatorKey: appNavigatorKey,
            home: const AuthGate(),
            builder: (context, child) => CallOverlay(child: child),
          );
        }),
      ),
    );
  }
}

/// 启动登录态判断（需求：杀进程后不用每次重新登录）
/// token 已持久化在 FlutterSecureStorage，401 拦截器会自动 refresh+重试。
/// 这里只判断"有没有 refresh token"：有 → 直接进主界面（由拦截器续期），
/// 没有 → 登录页。不再写死 home: LoginPage。
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Widget _body = const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );

  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    final api = ApiClient.instance;
    final rt = await api.readRefresh();
    Widget target;
    if (rt != null && rt.isNotEmpty) {
      // 有 refresh token：先静默续期一次拿 access（失败也不拦，
      // 进主界面后首个请求 401 会再走拦截器 refresh 流程）
      try {
        await api.refreshAccess();
      } catch (_) {}
      target = const HomeShell();
    } else {
      target = const LoginPage();
    }
    if (!mounted) return;
    setState(() => _body = target);
  }

  @override
  Widget build(BuildContext context) => _body;
}
