import 'package:flutter/widgets.dart';

/// 极简国际化：仅支持 zh-CN / en-US，避免引入 intl/flutter_localizations 依赖
class AppLocalizations {
  final Locale locale;
  const AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext ctx) {
    final p = ctx.dependOnInheritedWidgetOfExactType<_LocaleScope>();
    return p?.localizations ?? const AppLocalizations(Locale('zh', 'CN'));
  }

  static const Map<String, Map<String, String>> _dict = {
    'zh': {
      'login': '登录',
      'register': '注册',
      'account': '手机号 / 账号',
      'password': '密码',
      'confirmPassword': '确认密码',
      'inviteCode': '邀请码',
      'forgotPassword': '忘记密码？',
      'goRegister': '注册新账号',
      'haveAccount': '已有账号？',
      'goLogin': '去登录',
      'welcomeBack': '欢迎回来',
      'signInContinue': '登录以继续',
      'createAccount': '创建账号',
      'fillInfo': '请填写以下详细信息',
      'loggingIn': '登录中…',
      'registering': '注册中…',
      'langZh': '简体中文',
      'langEn': 'English',
      'home': '消息',
      'contacts': '通讯录',
      'discover': '发现',
      'me': '我的',
      'contactAdmin': '请联系管理员重置密码',
      'pwdMismatch': '两次密码输入不一致',
      'scanLogin': '扫码登录',
    },
    'en': {
      'login': 'Log in',
      'register': 'Sign up',
      'account': 'Phone / Account',
      'password': 'Password',
      'confirmPassword': 'Confirm password',
      'inviteCode': 'Invite code',
      'forgotPassword': 'Forgot password?',
      'goRegister': 'Sign up',
      'haveAccount': 'Have an account?',
      'goLogin': 'Log in',
      'welcomeBack': 'Welcome Back',
      'signInContinue': 'Sign in to continue',
      'createAccount': 'Create account',
      'fillInfo': 'Please fill in the details',
      'loggingIn': 'Logging in…',
      'registering': 'Signing up…',
      'langZh': '简体中文',
      'langEn': 'English',
      'home': 'Chats',
      'contacts': 'Contacts',
      'discover': 'Discover',
      'me': 'Me',
      'contactAdmin': 'Please contact admin to reset password',
      'pwdMismatch': 'Passwords do not match',
      'scanLogin': 'Scan to log in',
    },
  };

  String t(String key) {
    final lang = _dict[locale.languageCode] ?? _dict['zh']!;
    return lang[key] ?? _dict['zh']![key] ?? key;
  }
}

class _LocaleScope extends InheritedWidget {
  final AppLocalizations localizations;
  const _LocaleScope({required this.localizations, required super.child});
  @override
  bool updateShouldNotify(covariant _LocaleScope old) =>
      old.localizations.locale != localizations.locale;
}

class LocaleProvider extends StatefulWidget {
  final Widget child;
  const LocaleProvider({super.key, required this.child});
  @override
  State<LocaleProvider> createState() => _LocaleProviderState();
  static _LocaleProviderState? of(BuildContext ctx) =>
      ctx.findAncestorStateOfType<_LocaleProviderState>();
}

class _LocaleProviderState extends State<LocaleProvider> {
  Locale _locale = const Locale('zh', 'CN');
  void toggle() {
    setState(() {
      _locale = _locale.languageCode == 'zh' ? const Locale('en', 'US') : const Locale('zh', 'CN');
    });
  }
  @override
  Widget build(BuildContext context) {
    return _LocaleScope(
      localizations: AppLocalizations(_locale),
      child: widget.child,
    );
  }
}
