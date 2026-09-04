import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../l10n/app_locale.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/lang_picker.dart';
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

  // ===== 接口状态指示（左上角：点 + 毫秒）=====
  // 0=检测中(灰) 1=正常(绿) 2=慢(黄) 3=不通(红)
  static const int _apiChecking = 0;
  static const int _apiOk = 1;
  static const int _apiSlow = 2;
  static const int _apiDown = 3;
  int _apiState = _apiChecking;
  int? _apiMs;
  Timer? _apiTimer;
  Dio? _apiProbe;

  final _svc = AuthService();

  @override
  void initState() {
    super.initState();
    _loadLogo();
    _probeApi();
    // 每 20 秒复测一次，保证离开页面进来说明是实时状态
    _apiTimer = Timer.periodic(const Duration(seconds: 20), (_) => _probeApi());
  }

  /// 探测接口延迟：GET /api/v1/health，独立轻量 Dio（3s 超时，不走鉴权拦截器）。
  /// 服务器有任何响应（含 4xx/5xx）都算"通"，只有连接失败/超时才算不通。
  Future<void> _probeApi() async {
    final sw = Stopwatch()..start();
    try {
      _apiProbe ??= Dio(BaseOptions(
        baseUrl: AppConfig.instance.apiBase,
        connectTimeout: const Duration(seconds: 3),
        receiveTimeout: const Duration(seconds: 3),
        // 服务器返回任何状态码都算连通（health 正常是 200，这里宽容处理）
        validateStatus: (_) => true,
      ));
      await _apiProbe!.get('/api/v1/health');
      sw.stop();
      if (!mounted) return;
      final ms = sw.elapsedMilliseconds;
      setState(() {
        _apiMs = ms;
        _apiState = ms > 1000 ? _apiSlow : _apiOk;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _apiState = _apiDown;
        _apiMs = null;
      });
    }
  }

  @override
  void dispose() {
    _apiTimer?.cancel();
    _apiProbe?.close();
    _accountCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
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
                // 左上角：接口状态指示（点 + 毫秒）
                Align(
                  alignment: Alignment.topLeft,
                  child: _buildApiStatusChip(scheme, t),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 8),
                      // 语言切换（右上角，显示"下一个语言"）
                      Align(
                        alignment: Alignment.centerRight,
                        child: _buildLangChip(scheme),
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

  // ========= 左上角接口状态指示 =========
  Widget _buildApiStatusChip(
    ColorScheme scheme,
    String Function(String, [Map<String, String>]) t,
  ) {
    late final Color dot;
    late final String label;
    switch (_apiState) {
      case _apiOk:
        dot = const Color(0xFF34C759); // 绿：正常
        label = '${_apiMs ?? 0}ms';
        break;
      case _apiSlow:
        dot = const Color(0xFFFFB020); // 黄：慢（>1000ms）
        label = '${_apiMs ?? 0}ms';
        break;
      case _apiDown:
        dot = const Color(0xFFE5484D); // 红：不通
        label = t('apiDown');
        break;
      default:
        dot = const Color(0xFF9E9E9E); // 灰：检测中
        label = t('apiChecking');
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12, left: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========= 右上角语言入口（点击弹语言菜单，见 widgets/lang_picker.dart） =========
  Widget _buildLangChip(ColorScheme scheme) {
    // 显示当前语言；点开弹窗可四语切换或恢复跟随系统
    final cur = AppLocalizations.of(context).locale;
    final curLabel = AppLocalizations.langNativeName(cur);
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
          onTap: () => showLangPicker(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.language, size: 18, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(
                  curLabel,
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
      // 网络超时/连接失败不再 dump 原始 DioException，给可读提示
      final msg = e is DioException && ApiClient.isTransient(e)
          ? t('bootLoadFailed')
          : e.toString().replaceFirst('Exception: ', '');
      AppDialogs.toast(context, msg.isEmpty ? t('unknownError') : msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
