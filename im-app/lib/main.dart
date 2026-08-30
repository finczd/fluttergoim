import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_locale.dart';
import 'pages/login_page.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const ImApp());
}

class ImApp extends StatelessWidget {
  const ImApp({super.key});

  @override
  Widget build(BuildContext context) {
    return LocaleProvider(
      child: Builder(builder: (ctx) {
        // 语言实时切换：MaterialApp.locale 跟随 LocaleProvider 当前语言
        final loc = AppLocalizations.of(ctx).locale;
        return MaterialApp(
          title: 'ChatPulse',
          theme: AppTheme.light(),
          locale: loc,
          supportedLocales: const [Locale('zh'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const SplashPage(),
        );
      }),
    );
  }
}
