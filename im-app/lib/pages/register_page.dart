import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_locale.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/lang_picker.dart';
import 'home_shell.dart';
import 'login_page.dart';
import 'pay_ui.dart';

/// 注册页（美化版：登录页同风格）
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
  final _captchaCode = TextEditingController();
  final _smsCode = TextEditingController();

  final _svc = AuthService();
  final _api = ApiClient.instance;

  AuthConfig? _config;
  bool _loading = false;
  String _error = '';
  String _logoUrl = '';
  bool _pwdVisible = false;
  bool _confirmPwdVisible = false;

  // 图形验证码 + 短信验证码
  Captcha? _captcha;
  Uint8List? _captchaBytes; // 解码一次，避免倒计时每秒重建导致闪烁
  int _smsLeft = 0;
  Timer? _smsTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 后台开启短信/邮箱认证（authMode != none）时，需要图形验证码（发码前置）+ 短信验证码
  bool get _needAuth {
    final m = _config?.authMode ?? 'none';
    return m.isNotEmpty && m != 'none';
  }

  Future<void> _load() async {
    final cfg = await _svc.getConfig();
    if (!mounted) return;
    setState(() {
      _config = cfg;
      _logoUrl = cfg.appLogo.isNotEmpty ? cfg.appLogo : cfg.brandLogo;
    });
    if (_needAuth) {
      await _loadCaptcha();
    }
  }

  Future<void> _loadCaptcha() async {
    try {
      final c = await _svc.getCaptcha();
      if (!mounted) return;
      Uint8List bytes;
      try {
        bytes = base64Decode(c.imageBase64);
      } catch (_) {
        bytes = Uint8List(0);
      }
      // 只在拿到新验证码时解码一次，避免倒计时每秒重建导致图片闪烁
      setState(() {
        _captcha = c;
        _captchaBytes = bytes;
      });
    } catch (_) {
      // 静默失败：保留旧验证码或空；用户可点击图片重试
    }
  }

  void _startSmsCountdown() {
    _smsTimer?.cancel();
    _smsTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_smsLeft <= 1) {
        timer.cancel();
        setState(() => _smsLeft = 0);
      } else {
        setState(() => _smsLeft--);
      }
    });
  }

  Future<void> _sendCode() async {
    final acc = _account.text.trim();
    if (acc.isEmpty) {
      setState(() => _error = '请先填写手机号 / 账号');
      return;
    }
    if (_captcha == null) {
      setState(() => _error = '图形验证码加载中，请稍候');
      return;
    }
    if (_captchaCode.text.trim().isEmpty) {
      setState(() => _error = '请先填写图形验证码');
      return;
    }
    // 账号含 @ 视为邮箱，走邮箱渠道；否则走短信渠道
    final channel = acc.contains('@') ? 'email' : 'sms';
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final ch = await _svc.sendCode(acc, _captcha!.captchaId,
          _captchaCode.text.trim(),
          channel: channel);
      if (!mounted) return;
      setState(() => _smsLeft = 60);
      _startSmsCountdown();
      final label =
          ch == 'email' ? '验证码已发送至邮箱' : '验证码已发送至短信';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(label),
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    final t = AppLocalizations.of(context).t;
    if (_password.text != _confirmPwd.text) {
      setState(() => _error = t('pwdMismatch'));
      return;
    }
    if (_password.text.length < 6) {
      setState(() => _error = '密码至少 6 位');
      return;
    }
    if (_account.text.trim().length < 3) {
      setState(() => _error = '账号至少 3 位');
      return;
    }
    // 后台开启认证模式时的前置校验
    if (_needAuth) {
      if (_captcha == null) {
        setState(() => _error = '图形验证码加载中，请稍候');
        return;
      }
      if (_captchaCode.text.trim().isEmpty) {
        setState(() => _error = '请填写图形验证码');
        return;
      }
      if (_smsCode.text.trim().isEmpty) {
        setState(() => _error = '请填写短信验证码');
        return;
      }
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
        inviteCode:
            (_config?.inviteCodeOn ?? false) ? _inviteCode.text.trim() : null,
        code: _needAuth ? _smsCode.text.trim() : null,
        captchaId: _needAuth && _captcha != null ? _captcha!.captchaId : null,
        captchaCode: _needAuth ? _captchaCode.text.trim() : null,
        channel: _account.text.trim().contains('@') ? 'email' : 'sms',
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
  void dispose() {
    _account.dispose();
    _password.dispose();
    _inviteCode.dispose();
    _confirmPwd.dispose();
    _captchaCode.dispose();
    _smsCode.dispose();
    _smsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    final cfg = _config;
    final primary = AppTheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    const lightGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment(0, 0.45),
      colors: [Color(0xFFE8F2FF), Color(0xFFFFFFFF)],
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: isDark ? scheme.surface : Colors.white,
        resizeToAvoidBottomInset: true,
        body: Container(
          decoration:
              isDark ? null : const BoxDecoration(gradient: lightGradient),
          child: SafeArea(
            top: true,
            child: Stack(
              children: [
                // 单屏展示：去掉滚动，所有信息压缩在一屏内（Issue 2）
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 8),
                      // 返回 + 语言胶囊
                      Row(
                        children: [
                          InkWell(
                            onTap: () => Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                    builder: (_) => const LoginPage())),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: scheme.surface.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Icon(Icons.arrow_back_ios_new_rounded,
                                  color: scheme.onSurface, size: 16),
                            ),
                          ),
                          const Spacer(),
                          _buildLangChip(scheme, isZh, t),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // 品牌 Logo（接口加载，居中 + 紧凑；不显示软件名）
                      _brandLogo(primary, size: 56),
                      const SizedBox(height: 16),
                      Text(
                        t('createAccount'),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        t('fillInfo'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? scheme.onSurfaceVariant
                              : const Color(0xFF888888),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      // 单大卡片
                      _buildRegisterCard(t, scheme, primary, isDark, cfg),
                      const SizedBox(height: 12),
                      // 已有账号去登录
                      Center(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                  builder: (_) => const LoginPage())),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  t('haveAccount'),
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: scheme.onSurfaceVariant),
                                ),
                                Text(
                                  ' ${t('goLogin')}',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ========= 右上角语言胶囊 =========
  Widget _buildLangChip(ColorScheme scheme, bool isZh,
      String Function(String, [Map<String, String>]) t) {
    return Material(
      color: scheme.surface.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(999),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => showLangPicker(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.language, size: 18, color: AppTheme.primary),
              const SizedBox(width: 6),
              // 显示当前语言；点开弹窗可四语切换
              Text(
                AppLocalizations.langNativeName(
                    AppLocalizations.of(context).locale),
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  // ========= 品牌 Logo =========
  Widget _brandLogo(Color primary, {double size = 72}) {
    if (_logoUrl.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.3),
              blurRadius: 18,
              spreadRadius: 1,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.network(
            _logoUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => AppTheme.brandAvatar(size: size),
          ),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [primary.withValues(alpha: 0.75), primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.3),
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(Icons.chat_bubble_rounded,
          color: Colors.white, size: size * 0.5),
    );
  }

  // ========= 注册大卡片 =========
  Widget _buildRegisterCard(
    String Function(String, [Map<String, String>]) t,
    ColorScheme scheme,
    Color primary,
    bool isDark,
    AuthConfig? cfg,
  ) {
    final needAuth = _needAuth;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.09),
            blurRadius: 20,
            spreadRadius: -2,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _field(
            controller: _account,
            hint: t('account'),
            prefixIcon: Icons.person_outline_rounded,
            scheme: scheme,
            isDark: isDark,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          _field(
            controller: _password,
            hint: t('password'),
            prefixIcon: Icons.lock_outline_rounded,
            scheme: scheme,
            isDark: isDark,
            obscureText: !_pwdVisible,
            suffix: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _pwdVisible = !_pwdVisible),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  _pwdVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _field(
            controller: _confirmPwd,
            hint: t('confirmPassword'),
            prefixIcon: Icons.shield_outlined,
            scheme: scheme,
            isDark: isDark,
            obscureText: !_confirmPwdVisible,
            suffix: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () =>
                  setState(() => _confirmPwdVisible = !_confirmPwdVisible),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  _confirmPwdVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          // ===== 图形验证码 + 短信验证码（后台开启认证模式时显示）=====
          if (needAuth) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _field(
                    controller: _captchaCode,
                    hint: t('graphicCaptcha'),
                    prefixIcon: Icons.verified_user_outlined,
                    scheme: scheme,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _loadCaptcha,
                  child: Container(
                    width: 112,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isDark
                              ? scheme.outlineVariant
                              : const Color(0xFFE2E5EA)),
                      color: isDark
                          ? scheme.surfaceContainerHighest
                          : const Color(0xFFF7F8FA),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _captchaBytes == null
                          ? const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : Image.memory(
                              _captchaBytes!,
                              fit: BoxFit.fill,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.refresh),
                            ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox.shrink(),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _field(
                    controller: _smsCode,
                    hint: t('smsCode'),
                    prefixIcon: Icons.sms_outlined,
                    scheme: scheme,
                    isDark: isDark,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (_smsLeft > 0 || _loading) ? null : _sendCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      disabledForegroundColor: scheme.onSurfaceVariant,
                      disabledBackgroundColor: isDark
                          ? scheme.surfaceContainerHighest
                          : const Color(0xFFEDEFF2),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: Text(
                      _smsLeft > 0 ? '$_smsLeft s' : t('sendCode'),
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (cfg != null && cfg.inviteCodeOn) ...[
            const SizedBox(height: 12),
            _field(
              controller: _inviteCode,
              hint: t('inviteCode'),
              prefixIcon: Icons.card_giftcard_rounded,
              scheme: scheme,
              isDark: isDark,
            ),
          ],
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFDEAEA),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppTheme.danger.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded,
                      size: 18, color: AppTheme.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error,
                      style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.danger,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          PayUI.blueButton(
            label: _loading ? t('registering') : t('register'),
            onPressed: _loading ? null : _register,
          ),
        ],
      ),
    );
  }

  // ========= 字段封装 =========
  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData prefixIcon,
    required ColorScheme scheme,
    required bool isDark,
    Widget? suffix,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(fontSize: 15, color: scheme.onSurface),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            fontSize: 15,
            color: isDark ? scheme.outlineVariant : const Color(0xFFAAAAAA)),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 4, right: 8),
          child: Icon(prefixIcon, size: 20, color: scheme.onSurfaceVariant),
        ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 36, maxHeight: 36),
        suffixIcon: suffix == null
            ? null
            : Padding(padding: const EdgeInsets.only(right: 6), child: suffix),
        suffixIconConstraints:
            const BoxConstraints(minWidth: 36, maxHeight: 36),
        filled: true,
        fillColor:
            isDark ? scheme.surfaceContainerHighest : const Color(0xFFF7F8FA),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
