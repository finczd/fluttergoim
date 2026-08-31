import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'app_navigator.dart';
import 'config/app_config.dart';
import 'l10n/app_locale.dart';
import 'pages/incoming_call_page.dart';
import 'pages/login_page.dart';
import 'services/api_client.dart';
import 'services/keep_alive_service.dart';
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
            home: const SplashPage(),
            builder: (context, child) => CallOverlay(child: child),
          );
        }),
      ),
    );
  }
}
