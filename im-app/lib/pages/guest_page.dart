import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_locale.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'home_shell.dart';
import 'login_page.dart';

/// 引导页：后台开启游客注册时，未登录用户首屏进入。
/// 两个入口：游客登录（按设备号自动注册并登录）、登录/注册（走原有流程）。
/// 默认不自动进入游客登录，需用户主动点击。
class GuestPage extends StatefulWidget {
  const GuestPage({super.key});

  @override
  State<GuestPage> createState() => _GuestPageState();
}

class _GuestPageState extends State<GuestPage>
    with SingleTickerProviderStateMixin {
  final _svc = AuthService();
  final _api = ApiClient.instance;

  AuthConfig? _config;
  bool _loading = false;
  String _error = '';
  bool _autoCancelled = false;
  late final AnimationController _autoCtl;

  @override
  void initState() {
    super.initState();
    _autoCtl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..addStatusListener(_onAutoStatus);
    _load();
  }

  void _onAutoStatus(AnimationStatus s) {
    if (s == AnimationStatus.completed && mounted && !_autoCancelled) {
      _autoCancelled = true;
      _guestLogin();
    }
  }

  @override
  void dispose() {
    _autoCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final cfg = await _svc.getConfig();
      if (!mounted) return;
      // 后台未开启游客注册：直接进入常规登录页，避免多余的引导页闪现
      if (!cfg.guestOn) {
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginPage()));
        return;
      }
      setState(() => _config = cfg);
      if (!_autoCancelled) _autoCtl.forward();
    } catch (_) {
      // 配置拉取失败：退回常规登录页，不影响使用
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginPage()));
    }
  }

  int get _deviceType {
    // 设备类型与 im-server GuestRegister 对齐：1=Android 2=iOS 3=Web 4=Windows 5=macOS
    // 用 defaultTargetPlatform 替代 dart:io Platform（Web 上 dart:io Platform 抛
    // Unsupported operation: Platform._operatingSystem 直接崩页）。
    if (kIsWeb) return 3;
    if (defaultTargetPlatform == TargetPlatform.iOS) return 2;
    return 1; // Android 等默认
  }

  Future<void> _guestLogin() async {
    if (_loading) return;
    if (!_autoCancelled) {
      _autoCancelled = true;
      _autoCtl.stop();
    }
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final deviceId = await _api.getDeviceId();
      final r = await _svc.guestRegister(
          deviceId: deviceId, deviceType: _deviceType);
      await _api.saveToken(r.accessToken);
      await _api.saveRefresh(r.refreshToken);
      if (!mounted) return;
      // 后台开启邀请码：仅「新游客」登录后才引导填写（同一设备号复用老账号时已填过，不再重复打扰）
      if ((_config?.inviteCodeOn ?? false) && r.isNewGuest) {
        await _showInviteDialog();
        if (!mounted) return;
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeShell()));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  /// 登录后补填邀请码弹窗（不可点外部关闭）。确认有效码 → 绑定；跳过 → 直接进。
  Future<void> _showInviteDialog() async {
    final codeCtrl = TextEditingController();
    var loading = false;
    var err = '';
    final t = AppLocalizations.of(context).t;
    final scheme = Theme.of(context).colorScheme;
    final primary = AppTheme.primary;
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(t('guestInviteTitle')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t('guestInviteDesc'),
                  style: TextStyle(
                      fontSize: 13, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              TextField(
                controller: codeCtrl,
                autofocus: true,
                textInputAction: TextInputAction.done,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.5,
                    color: scheme.onSurface),
                decoration: InputDecoration(
                  hintText: t('guestInviteInputHint'),
                  hintStyle: TextStyle(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 12, right: 8),
                    child: Icon(Icons.confirmation_number_outlined,
                        color: primary, size: 20),
                  ),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 0, minHeight: 0),
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: primary, width: 1.6),
                  ),
                ),
              ),
              if (err.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(err,
                    style: TextStyle(fontSize: 12, color: AppTheme.danger)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: loading
                  ? null
                  : () => Navigator.of(ctx).pop(true), // 跳过
              child: Text(t('guestInviteSkip')),
            ),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      final code = codeCtrl.text.trim();
                      if (code.isEmpty) {
                        setSt(() => err = t('guestInviteInvalid'));
                        return;
                      }
                      setSt(() {
                        loading = true;
                        err = '';
                      });
                      try {
                        await _svc.bindInviteCode(code);
                        if (!mounted) return;
                        Navigator.of(ctx).pop(true);
                      } catch (e) {
                        setSt(() {
                          loading = false;
                          err = e.toString().replaceFirst('Exception: ', '');
                        });
                      }
                    },
              child: Text(t('guestInviteConfirm')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppTheme.primary;

    // 配置加载中（含可能重定向到登录页）
    if (_config == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: isDark ? scheme.surface : Colors.white,
        body: Container(
          decoration:
              isDark ? null : const BoxDecoration(gradient: _lightGradient),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  // 品牌 Logo
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [primary.withValues(alpha: 0.75), primary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.3),
                          blurRadius: 18,
                          spreadRadius: 1,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(Icons.chat_bubble_rounded,
                        color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    t('guestGuideTitle'),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t('guestGuideDesc'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(flex: 3),
                  if (_error.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDEAEA),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppTheme.danger.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded,
                              size: 18, color: AppTheme.danger),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.danger,
                                    fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  // 2秒倒计时彩色进度条：用户点任何按钮或自动完成时隐藏
                  if (!_autoCancelled) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        children: [
                          Text(t('autoGuestHint'),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant)),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              height: 8,
                              width: double.infinity,
                              color: scheme.surfaceContainerHighest,
                              child: AnimatedBuilder(
                                animation: _autoCtl,
                                builder: (_, __) {
                                  final v = _autoCtl.value.clamp(0.0, 1.0);
                                  return Align(
                                    alignment: Alignment.centerLeft,
                                    child: FractionallySizedBox(
                                      widthFactor: v,
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Color(0xFF4F8CFF),
                                              Color(0xFFB14FFF),
                                              Color(0xFFFF6F91),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // 游客登录（主按钮）
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _guestLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(t('guestLogin'),
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 登录 / 注册（次按钮）
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _loading
                          ? null
                          : () {
                              if (!_autoCancelled) {
                                _autoCancelled = true;
                                _autoCtl.stop();
                              }
                              Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                      builder: (_) => const LoginPage()));
                            },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primary,
                        side: BorderSide(color: primary),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(t('loginRegister'),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const _lightGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment(0, 0.45),
    colors: [Color(0xFFE8F2FF), Color(0xFFFFFFFF)],
  );
}
