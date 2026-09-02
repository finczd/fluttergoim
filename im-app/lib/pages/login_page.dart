import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_locale.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_dialogs.dart';
import 'home_shell.dart';
import 'pay_ui.dart';
import 'register_page.dart';

/// 登录页（美化版：上移重心 + 单大卡片 + 去扫码登录）
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _accountCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  bool _pwdVisible = false;
  bool _loading = false;
  String _logoUrl = ''; // 接口下发的品牌 Logo（appLogo / brandLogo）

  final _svc = AuthService();

  @override
  void initState() {
    super.initState();
    _loadLogo();
  }

  Future<void> _loadLogo() async {
    try {
      final cfg = await _svc.getConfig();
      if (!mounted) return;
      setState(() {
        _logoUrl = cfg.appLogo.isNotEmpty ? cfg.appLogo : cfg.brandLogo;
      });
    } catch (_) {
      // 接口失败静默回退默认 Logo
    }
  }

  @override
  void dispose() {
    _accountCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  // ========= 品牌 Logo（优先接口图片，失败/未加载回退默认） =========
  Widget _brandLogo({double size = 72}) {
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
    return AppTheme.brandAvatar(size: size);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
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
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 8),
                      // 语言切换（右上角）
                      Align(
                        alignment: Alignment.centerRight,
                        child: _buildLangChip(scheme, isZh, t),
                      ),
                      // 品牌 Logo（接口加载，居中 + 紧凑；不显示软件名）
                      const SizedBox(height: 12),
                      _brandLogo(size: 56),
                      const SizedBox(height: 16),
                      // 欢迎语（居中 + 紧凑）
                      Text(
                        t('welcomeBack'),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        t('loginSubtitle'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? scheme.onSurfaceVariant
                              : const Color(0xFF888888),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // 单大卡片（紧凑 padding）
                      _buildLoginCard(t, scheme, isDark),
                      const SizedBox(height: 16),
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
  Widget _buildLangChip(
    ColorScheme scheme,
    bool isZh,
    String Function(String, [Map<String, String>]) t,
  ) {
    // 外层 SafeArea(top:true) 已经处理状态栏高度，这里只用 Padding 给语言胶囊留顶部设计间距
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: scheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => LocaleProvider.of(context)?.toggle(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.language, size: 18, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(
                  isZh ? '中文' : 'English',
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
      ),
    );
  }

  // ========= 登录大卡片 =========
  Widget _buildLoginCard(String Function(String, [Map<String, String>]) t,
      ColorScheme scheme, bool isDark) {
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
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _field(
              controller: _accountCtrl,
              hint: t('loginAccountHint'),
              prefixIcon: Icons.person_outline_rounded,
              scheme: scheme,
              isDark: isDark,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return t('loginAccountRequired');
                }
                if (v.trim().length < 3) return t('loginAccountTooShort');
                return null;
              },
            ),
            const SizedBox(height: 12),
            _field(
              controller: _pwdCtrl,
              hint: t('loginPwdHint'),
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
              validator: (v) {
                if (v == null || v.isEmpty) return t('loginPwdRequired');
                if (v.length < 6) return t('loginPwdTooShort');
                return null;
              },
              onFieldSubmitted: (_) => _doLogin(t),
            ),
            const SizedBox(height: 20),
            PayUI.blueButton(
              label: t('loginSubmit'),
              onPressed: _loading ? null : () => _doLogin(t),
            ),
            const SizedBox(height: 12),
            // 忘记密码（左） + 立即注册（右）——去掉扫码登录
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () {
                    AppDialogs.toast(context, '请联系管理员重置密码');
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      t('forgotPassword'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const RegisterPage())),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      t('registerNow'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
    String? Function(String?)? validator,
    void Function(String)? onFieldSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
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
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
        errorStyle: const TextStyle(fontSize: 12, height: 0.9),
      ),
    );
  }

  Future<void> _doLogin(
      String Function(String, [Map<String, String>]) t) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final account = _accountCtrl.text.trim();
      final password = _pwdCtrl.text.trim();
      final r = await _svc.login(account, password);
      if (!mounted) return;
      await ApiClient.instance.saveToken(r.accessToken);
      await ApiClient.instance.saveRefresh(r.refreshToken);
      AppDialogs.toast(context, t('loginSuccess'));
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeShell()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      AppDialogs.toast(context, msg.isEmpty ? t('unknownError') : msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
