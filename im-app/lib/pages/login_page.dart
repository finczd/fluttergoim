import 'package:flutter/material.dart';

import '../l10n/app_locale.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/call_service.dart';
import '../services/ws_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_dialogs.dart';
import 'home_shell.dart';
import 'qr_login_page.dart';
import 'register_page.dart';

/// 登录页（Aura Messaging 设计稿图 1 + 需求调整）
/// - 顶部无品牌行（用户需求）
/// - 右上角语言 pill：点击切换中/英（AppLocalizations 实时刷新）
/// - 居中 logo + 名称：从后端 /auth/config 读取（appLogo/appName），有则用，无则回退蓝色圆形 send
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _account = TextEditingController();
  final _password = TextEditingController();
  final _api = ApiClient.instance;
  final _svc = AuthService();
  bool _loading = false;
  bool _obscure = true;
  String _error = '';
  String _logoUrl = '';
  String _brandName = '';

  @override
  void initState() {
    super.initState();
    _loadBrand();
  }

  /// 从后端读 brand 配置（logo + 名称）
  Future<void> _loadBrand() async {
    try {
      final cfg = await _svc.getConfig();
      if (mounted) {
        setState(() {
          _logoUrl = (cfg.appLogo ?? cfg.brandLogo ?? '').toString();
          _brandName = (cfg.appName ?? cfg.brandName ?? 'ChatPulse').toString();
        });
      }
    } catch (_) {}
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final r = await _svc.login(_account.text.trim(), _password.text);
      await _api.saveToken(r.accessToken);
      await _api.saveRefresh(r.refreshToken);
      // 换号登录兜底：清掉上一个账号残留的通话态 / 旧 WS 连接，
      // 保证 HomeShell 里 ensureConnected 是用新 token 建的连。
      // 套一层 3s 超时兜底（B-18）：任何一步意外卡住都不能让按钮停在"登录中"。
      await CallService.instance
          .resetSession()
          .timeout(const Duration(seconds: 3), onTimeout: () {});
      GlobalWs.instance.close();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeShell()));
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _forgotPassword() {
    AppDialogs.toast(context, AppLocalizations.of(context).t('contactAdmin'));
  }

  void _goRegister() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const RegisterPage()));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ===== 顶栏：仅语言 pill（按需求 3 去掉 ChatPulse 行）=====
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  const Spacer(),
                  InkWell(
                    onTap: () => LocaleProvider.of(context)?.toggle(),
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: context.cs.surfaceContainer,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusFull),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.language,
                              size: 16, color: AppTheme.primary),
                          const SizedBox(width: 4),
                          Text(isZh ? t('langZh') : t('langEn'),
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.primary)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ===== 主区 =====
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 60),
                    Center(child: _brandLogo()),
                    if (_brandName.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Center(
                        child: Text(_brandName,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: context.cs.onSurface)),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(t('welcomeBack'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: context.cs.onSurface,
                            height: 1.2)),
                    const SizedBox(height: 8),
                    Text(t('signInContinue'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 15, color: context.cs.onSurfaceVariant)),
                    const SizedBox(height: 40),
                    TextField(
                      controller: _account,
                      style:
                          TextStyle(fontSize: 15, color: context.cs.onSurface),
                      decoration: AppTheme.authInput(
                          hint: t('account'), icon: Icons.person_outline),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _password,
                      obscureText: _obscure,
                      style:
                          TextStyle(fontSize: 15, color: context.cs.onSurface),
                      decoration: AppTheme.authInput(
                        hint: t('password'),
                        icon: Icons.lock_outline,
                        suffix: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                              _obscure
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              size: 20,
                              color: context.cs.onSurfaceVariant),
                        ),
                      ),
                      onSubmitted: (_) => _login(),
                    ),
                    if (_error.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(_error,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppTheme.danger, fontSize: 13)),
                    ],
                    const SizedBox(height: 24),
                    AppTheme.primaryButton(
                      label: _loading ? t('loggingIn') : t('login'),
                      onPressed: _loading ? null : _login,
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: _forgotPassword,
                            child: Text(t('forgotPassword'),
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textLink,
                                    fontWeight: FontWeight.w500)),
                          ),
                          const Spacer(),
                          InkWell(
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const _NavigateToQr())),
                            child: Text(t('scanLogin'),
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textLink,
                                    fontWeight: FontWeight.w500)),
                          ),
                          const SizedBox(width: 20),
                          InkWell(
                            onTap: _goRegister,
                            child: Text(t('goRegister'),
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textLink,
                                    fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 后端 logo 优先；无则回退蓝色 send 圆
  Widget _brandLogo() {
    if (_logoUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(_logoUrl,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => AppTheme.brandAvatar(size: 80)),
      );
    }
    return AppTheme.brandAvatar(size: 80);
  }
}

/// 占位：登录跳扫码页（实际由路由处理）
class _NavigateToQr extends StatelessWidget {
  const _NavigateToQr();
  @override
  Widget build(BuildContext context) => const QrLoginPage();
}

/// 启动页：检查本地 Token 决定进入登录页还是首页
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final token = await ApiClient.instance.readToken();
    if (!mounted) return;
    if (token == null) {
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginPage()));
      return;
    }
    // 有登录态：先尝试用 refreshToken 续期（长期保持登录），
    // 续期失败（refresh 也过期）才视为未登录跳登录页
    final ok = await ApiClient.instance.refreshAccess();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => ok ? const HomeShell() : const LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
