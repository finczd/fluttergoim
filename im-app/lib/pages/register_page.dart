import 'package:flutter/material.dart';

import '../l10n/app_locale.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'home_shell.dart';
import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _account = TextEditingController();
  final _password = TextEditingController();
  final _inviteCode = TextEditingController();
  final _confirmPwd = TextEditingController();

  final _svc = AuthService();
  final _api = ApiClient.instance;

  AuthConfig? _config;
  bool _loading = false;
  String _error = '';
  String _logoUrl = '';
  String _brandName = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cfg = await _svc.getConfig();
    if (mounted && cfg != null) {
      setState(() {
        _config = cfg;
        _logoUrl = (cfg.appLogo ?? cfg.brandLogo ?? '').toString();
        _brandName = (cfg.appName ?? cfg.brandName ?? 'ChatPulse').toString();
      });
    }
  }

  Future<void> _register() async {
    if (_password.text != _confirmPwd.text) {
      setState(() => _error = AppLocalizations.of(context).t('pwdMismatch'));
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final r = await _svc.register(
        account: _account.text.trim(),
        password: _password.text,
        nickname: _account.text.trim(),
        inviteCode: (_config?.inviteCodeOn ?? false) ? _inviteCode.text.trim() : null,
        // 需求1：UI 不再收集图形验证码
        captchaId: null,
        captchaCode: null,
      );
      await _api.saveToken(r.accessToken);
      await _api.saveRefresh(r.refreshToken);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeShell()));
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    final cfg = _config;
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ===== 顶栏：返回 + 语言 pill =====
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 24),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const LoginPage())),
                      borderRadius: BorderRadius.circular(20),
                      child: const SizedBox(
                        width: 40, height: 40,
                        child: Icon(Icons.arrow_back,
                            color: AppTheme.textPrimary, size: 22),
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () => LocaleProvider.of(context)?.toggle(),
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.language, size: 16, color: AppTheme.primary),
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
              // ===== 品牌区 =====
              Center(child: _brandLogo()),
              if (_brandName.isNotEmpty) ...[
                const SizedBox(height: 14),
                Center(
                  child: Text(_brandName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                ),
              ],
              const SizedBox(height: 24),
              Text(t('createAccount'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      height: 1.2)),
              const SizedBox(height: 8),
              Text(t('fillInfo'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 15, color: AppTheme.textSecondary)),
              const SizedBox(height: 32),
              // ===== 用户名 / 账号 =====
              TextField(
                controller: _account,
                style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
                decoration: AppTheme.authInput(
                    hint: t('account'), icon: Icons.person_outline),
              ),
              const SizedBox(height: 14),
              // ===== 密码 =====
              TextField(
                controller: _password,
                obscureText: true,
                style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
                decoration: AppTheme.authInput(
                    hint: t('password'), icon: Icons.lock_outline),
              ),
              const SizedBox(height: 14),
              // ===== 确认密码 =====
              TextField(
                controller: _confirmPwd,
                obscureText: true,
                style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
                decoration: AppTheme.authInput(
                    hint: t('confirmPassword'), icon: Icons.lock_outline),
              ),
              const SizedBox(height: 14),
              // ===== 邀请码（开关开启时显示）=====
              if (cfg != null && cfg.inviteCodeOn) ...[
                TextField(
                  controller: _inviteCode,
                  style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
                  decoration: AppTheme.authInput(
                      hint: t('inviteCode'), icon: Icons.card_giftcard),
                ),
                const SizedBox(height: 14),
              ],
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(_error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppTheme.danger, fontSize: 13)),
              ],
              const SizedBox(height: 24),
              // ===== 注册按钮 =====
              AppTheme.primaryButton(
                label: _loading ? t('registering') : t('register'),
                onPressed: _loading ? null : _register,
              ),
              const SizedBox(height: 20),
              // ===== 已有账号去登录 =====
              Center(
                child: InkWell(
                  onTap: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginPage())),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(t('haveAccount'),
                          style: const TextStyle(
                              fontSize: 14, color: AppTheme.textSecondary)),
                      Text(' ${t('goLogin')}',
                          style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textLink,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _brandLogo() {
    if (_logoUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(_logoUrl, width: 96, height: 96, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => AppTheme.brandAvatar(size: 96)),
      );
    }
    return AppTheme.brandAvatar(size: 96);
  }
}
