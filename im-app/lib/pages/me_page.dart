import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_locale.dart';
import '../services/api_client.dart';
import '../services/call_service.dart';
import '../services/feature_flags.dart';
import '../services/friend_service.dart';
import '../services/update_service.dart';
import '../services/user_cache.dart';
import '../widgets/update_dialog.dart';
import 'keep_alive_guide_page.dart';
import '../services/wallet_store.dart';
import '../services/ws_service.dart';
import '../widgets/lang_picker.dart';
import '../theme/app_theme.dart';
import '../widgets/app_dialogs.dart';
import 'favorites_page.dart';
import 'login_page.dart';
import 'my_qr_page.dart';
import 'policy_page.dart';
import 'profile_page.dart';
import 'account_security_page.dart';
import 'system_settings_page.dart';
import 'wallet_page.dart';

/// 我的（设计稿：顶栏"我的"+ 资料卡片 + 设置列表）
class MePage extends StatefulWidget {
  const MePage({super.key});

  @override
  State<MePage> createState() => _MePageState();
}

class _MePageState extends State<MePage> {
  final _svc = FriendService();
  final _api = ApiClient.instance;
  Map<String, dynamic>? _profile;
  String _inviteCode = ''; // 我的邀请码（用户中心展示 + 点击复制）

  @override
  void initState() {
    super.initState();
    // 立刻用全局身份缓存垫底：登录后消息列表/通讯录已拉过我的资料并写入 UserCache，
    // 这里直接显示，避免 profile 接口偶发抖动时"我的"页闪/卡在"未登录"。
    final ident = UserCache.myProfileData;
    if (ident != null) _profile = ident;
    _loadCachedProfile();
    _load();
    _refreshBalance();
    // 功能开关（零钱/邀请码）：后台可实时开关，进入本页刷新一次
    FeatureFlags.instance.load();
  }

  /// 先读本地缓存的资料，首帧直接渲染昵称/头像，
  /// 修复「快速切到'我的'先显示'未登录'/默认头像，接口回来才变」。
  /// 网络返回后再覆盖刷新（缓存只做展示兜底，不阻断更新）。
  Future<void> _loadCachedProfile() async {
    try {
      final raw = await _api.readPref('profile');
      if (raw == null || raw.isEmpty || !mounted) return;
      final cached = jsonDecode(raw);
      if (cached is Map<String, dynamic> &&
          _profile == null &&
          (cached['id']?.toString() ?? '').isNotEmpty) {
        setState(() => _profile = cached);
      }
    } catch (_) {}
  }

  /// 钱包余额走后端（"我的钱包"行 trailing 展示）。
  /// B-20：以前只在 initState 拉一次，而本页常驻在 HomeShell 的 _pages 里不销毁，
  /// 后台给用户加了余额后 App 里永远是旧值。改为可重复调用（切回"我的" tab 时会触发）。
  Future<void> _refreshBalance() async {
    await WalletStore.instance.refresh();
    if (mounted) setState(() {});
  }

  /// 下拉刷新：重新拉资料 + 余额。
  /// 主链路是服务端 WS 主动推送（B-24），这里只是给用户一个"手动刷新"的入口，
  /// 同时也兜住 WS 断开 / 推送丢失的情况。
  Future<void> _onPullRefresh() async {
    await Future.wait([_load(), _refreshBalance()]);
  }

  Future<void> _load({int retry = 0}) async {
    try {
      final p = await _svc.profile();
      if (mounted) {
        setState(() {
          _profile = p;
          _inviteCode = p['myInviteCode']?.toString() ?? '';
        });
        // 同步全局身份缓存：供失败兜底，也避免其他页面再拉一遍
        UserCache.setMyProfile(p);
        // 资料写入本地缓存，下次进 App / 切 tab 首帧即有昵称头像
        unawaited(_api.writePref('profile', jsonEncode(p)));
      }
    } catch (e) {
      // 首次请求偶发超时（服务端瞬时慢，与登录/进群超时同款）→ 自动重试，
      // 否则"我的"页会一直显示"未登录"，直到手动下拉刷新
      if (retry < 2 && mounted) {
        await Future.delayed(Duration(milliseconds: 600 * (retry + 1)));
        if (!mounted) return;
        return _load(retry: retry + 1);
      }
      // 重试耗尽也不应卡在"未登录"：用全局身份缓存（消息列表/通讯录已拉过）兜底
      if (mounted) {
        final fallback = UserCache.myProfileData;
        if (fallback != null) setState(() => _profile = fallback);
      }
    }
  }

  Future<void> _logout() async {
    final t = AppLocalizations.of(context).t;
    final confirm = await AppDialogs.confirm(
      context,
      title: t('meLogoutTitle'),
      message: t('meLogoutMsg'),
      confirmText: t('meLogoutConfirm'),
      danger: true,
    );
    if (confirm != true) return;
    // 关键：退出登录必须清干净全局态，否则再登录会白屏 / 复用上一个账号的连接。
    // 1) CallService：清通话态 + 关悬浮小窗 + 释放 TRTC 引擎 + 清空 _myId
    // 2) GlobalWs：断开 WS 并清空监听列表（原连接带的是旧 token）
    // 两步都套 3s 超时兜底（B-18）：局部清理失败/卡住也必须把用户送到登录页，
    // 不能出现"点了退出登录没反应"。
    await CallService.instance
        .resetSession()
        .timeout(const Duration(seconds: 3), onTimeout: () {});
    GlobalWs.instance.close();
    // 这里不要再单独 close 一次浮窗：resetSession 已经在关了，
    // 重复调用反而会撞上"插件不回 result → await 永久挂起"的坑（B-18）。
    // ApiClient.logout 内部已改成"先清本地 token，再通知服务端"，
    // 所以这里压到 2s 也只是放弃服务端通知，不影响本地已登出。
    await _api.logout().timeout(const Duration(seconds: 2), onTimeout: () {});
    UserCache.clear(); // 清用户信息缓存：换账号登录不能复用上一个会话的数据
    // 钱包：清内存余额（磁盘快照已由 logout→LocalStore.clearUserData 清）。
    // 不清的话换账号登录后、refresh() 返回前会短暂显示上一个人的余额。
    WalletStore.instance.reset();
    if (!mounted) return;
    // 用 pushAndRemoveUntil 清栈，避免回退键还能回到已登出的首页
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    // 已登录时绝不应显示"未登录"：优先用本页 profile，再退回全局身份缓存
    // （profile 接口偶发抖动时，消息列表/通讯录早已写入 UserCache，可兜底显示真实昵称）。
    final p = _profile ?? UserCache.myProfileData;
    final name = (p?['nickname']?.toString() ?? '').isNotEmpty
        ? p!['nickname'].toString()
        : t('meNotLoggedIn');
    final account = p?['account']?.toString() ?? '';
    final shortId = p?['shortId']?.toString() ?? '';
    // 靓号标识：short_id 来自后台靓号池（已分配）→ ID 前显示红色「靓ID」徽标
    final isVipShort = p?['vipShortId'] == true && shortId.isNotEmpty;

    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _onPullRefresh,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              // 顶栏"我的"
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Text(t('me'),
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface)),
              ),
              // 资料卡片：头像 + 姓名 + ID + 二维码
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  onTap: () async {
                    // 编辑资料返回后刷新（IndexedStack 常驻后 initState 不再重跑，必须手动刷）
                    await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ProfilePage()));
                    if (mounted) _load();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 18),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Row(
                      children: [
                        _meAvatar(name, p?['avatar']?.toString()),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w700,
                                      color: scheme.onSurface)),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  // 靓号徽标：红色框住「靓ID：123456」
                                  if (isVipShort) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: const Color(0xFFE5484D),
                                            width: 1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        t('vipIdBadge', {'id': shortId}),
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFFE5484D)),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  // 靓号时徽标已含「靓ID：xxx」，不再重复显示普通 ID
                                  Flexible(
                                    child: isVipShort
                                        ? const SizedBox.shrink()
                                        : Text(
                                            shortId.isNotEmpty
                                                ? 'ID: $shortId'
                                                : t('meAccount',
                                                    {'account': account}),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: scheme.onSurfaceVariant),
                                          ),
                                  ),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () {
                                      final v = shortId.isNotEmpty
                                          ? shortId
                                          : account;
                                      if (v.isEmpty) return;
                                      Clipboard.setData(ClipboardData(text: v));
                                      AppDialogs.toast(context, t('meCopied'));
                                    },
                                    child: Icon(Icons.copy_all_rounded,
                                        size: 15,
                                        color: scheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const MyQrPage())),
                          child: Icon(Icons.qr_code_2,
                              size: 22, color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.chevron_right,
                            size: 18, color: scheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // 我的服务（钱包/收藏/邀请码）
              _groupLabel(t('meMyServices')),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                // 功能开关实时驱动：后台关闭「零钱/邀请码」后立即隐藏对应入口
                child: AnimatedBuilder(
                    animation: Listenable.merge([
                      FeatureFlags.instance.walletOn,
                      FeatureFlags.instance.inviteOn,
                    ]),
                    builder: (_, __) => _card([
                          if (FeatureFlags.instance.walletOn.value)
                            _row(Icons.account_balance_wallet_outlined,
                                t('meWallet'),
                                color: AppTheme.transfer,
                                // 余额用监听而不是快照：后台改了余额 / 领了红包后不用手动 setState（B-20）
                                trailingWidget: ValueListenableBuilder<double>(
                                  valueListenable:
                                      WalletStore.instance.balanceNotifier,
                                  builder: (_, v, __) => Text(
                                      '¥ ${WalletStore.instance.fmt(v)}',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant)),
                                ), onTap: () async {
                              await Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => const WalletPage()));
                              // 从零钱页返回后强刷一次（在零钱页可能刚发生收支）
                              if (mounted) _refreshBalance();
                            }),
                          _row(Icons.favorite_border_rounded, t('meFavorites'),
                              color: AppTheme.pink, onTap: () {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => const FavoritesPage()));
                          }),
                          if (FeatureFlags.instance.inviteOn.value)
                            _row(
                              Icons.share_outlined,
                              t('meInviteCode'),
                              color: AppTheme.green,
                              // 后台关联的邀请码：直接展示 + 整行可点复制
                              trailingWidget: _inviteCode.isNotEmpty
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(_inviteCode,
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: scheme.onSurfaceVariant)),
                                        const SizedBox(width: 4),
                                        Icon(Icons.copy_all_rounded,
                                            size: 15,
                                            color: scheme.onSurfaceVariant),
                                      ],
                                    )
                                  : null,
                              onTap: () {
                                if (_inviteCode.isNotEmpty) {
                                  Clipboard.setData(
                                      ClipboardData(text: _inviteCode));
                                  AppDialogs.toast(context, t('meCopied'));
                                } else {
                                  AppDialogs.toast(
                                      context, t('meInviteCodeToast'));
                                }
                              },
                            ),
                        ])),
              ),
              // 设置（账号安全/切换语言/检测更新/设置）
              _groupLabel(t('meSettings')),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _card([
                  _row(Icons.shield_outlined, t('meAccountSecurity'),
                      color: AppTheme.purple, onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const AccountSecurityPage()));
                  }),
                  _row(Icons.language, t('meSwitchLanguage'),
                      color: AppTheme.purple,
                      trailing: _otherLangLabel(context),
                      onTap: () => _showLangPicker(context)),
                  // 消息保活设置引导（仅移动端显示，Web 无前台服务概念）
                  if (!kIsWeb)
                    _row(Icons.battery_saver_outlined, t('kaTitle'),
                        color: AppTheme.green, onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const KeepAliveGuidePage()));
                    }),
                  _row(Icons.info_outline, t('meAboutUs'), color: AppTheme.cyan,
                      onTap: () {
                    Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AboutPage()));
                  }),
                  _row(Icons.settings_outlined, t('meSettings'),
                      color: scheme.onSurfaceVariant, onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const SystemSettingsPage()));
                  }),
                ]),
              ),
              const SizedBox(height: 24),
              // 退出登录按钮
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: _logout,
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.surface,
                      foregroundColor: AppTheme.danger,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd)),
                    ),
                    child: Text(t('meLogoutTitle'),
                        style: const TextStyle(fontSize: 15)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 右侧显示当前语言（语言入口已改为弹窗菜单选择）
  String _otherLangLabel(BuildContext context) {
    final loc = AppLocalizations.of(context).locale;
    return AppLocalizations.langNativeName(loc);
  }

  /// 语言选择弹窗（跟随系统 + 四语），实现见 widgets/lang_picker.dart（登录/注册/扫码页共用）
  void _showLangPicker(BuildContext context) => showLangPicker(context);

  Widget _groupLabel(String text) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Text(text,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant)),
    );
  }

  /// 头像：优先网络头像，无则首字色块
  Widget _meAvatar(String name, String? url) {
    final initial = name.isEmpty ? '?' : name.characters.first;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: (url != null && url.isNotEmpty)
          ? Image.network(
              url,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _meAvatarBlock(initial),
            )
          : _meAvatarBlock(initial),
    );
  }

  Widget _meAvatarBlock(String initial) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primary, AppTheme.primary.withValues(alpha: 0.7)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      alignment: Alignment.center,
      child: Text(initial,
          style: const TextStyle(
              fontSize: 26, color: Colors.white, fontWeight: FontWeight.w600)),
    );
  }

  Widget _card(List<Widget> rows) {
    final scheme = Theme.of(context).colorScheme;
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      children.add(rows[i]);
      if (i != rows.length - 1) {
        children.add(Divider(
            height: 1,
            indent: 50,
            endIndent: 14,
            color: scheme.outlineVariant));
      }
    }
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(children: children),
    );
  }

  Widget _row(IconData icon, String title,
      {VoidCallback? onTap,
      String? trailing,
      Widget? trailingWidget,
      Color color = AppTheme.primary,
      bool dot = false}) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurface)),
            ),
            if (trailingWidget != null)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: trailingWidget,
              ),
            if (trailing != null)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(trailing,
                    style: TextStyle(
                        fontSize: 13, color: scheme.onSurfaceVariant)),
              ),
            if (dot)
              Container(
                margin: const EdgeInsets.only(right: 6),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.pink,
                  shape: BoxShape.circle,
                ),
              ),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant, size: 18),
          ],
        ),
      ),
    );
  }
}

/// 关于页：版本号 + 更新内容 + 下载地址（数据来自后台 /auth/config）
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});
  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  final _api = ApiClient.instance;
  // 本地版本基准：统一走 UpdateService（由 apply_config 自动同步，勿手改）
  String get _currentVersion => UpdateService.currentVersion;

  /// 后台配置的软件名（无配置回落默认名）——政策文案/简介统一替换
  String get _appName => _brandName.isNotEmpty ? _brandName : 'ChatPulse';

  String _version = '';
  String _updateLog = '';
  String _androidUrl = '';
  String _iosUrl = '';
  String _brandName = '';
  String _brandLogo = ''; // 后台配置的品牌 logo（appLogo/brandLogo）

  @override
  void initState() {
    super.initState();
    _loadCached(); // 缓存直出：品牌/版本信息首帧即显，不空屏等待
    _load();
  }

  /// 先渲染本地缓存的品牌与版本配置，网络回来后覆盖刷新
  Future<void> _loadCached() async {
    try {
      final raw = await _api.readPref('authConfig');
      if (raw == null || raw.isEmpty || !mounted) return;
      final d = jsonDecode(raw);
      if (d is Map) _applyConfig(Map<String, dynamic>.from(d));
    } catch (_) {}
  }

  void _applyConfig(Map<String, dynamic> d) {
    setState(() {
      _version = d['appVersion']?.toString() ?? '';
      _updateLog = d['updateLog']?.toString() ?? '';
      _androidUrl = d['androidUrl']?.toString() ?? '';
      _iosUrl = d['iosUrl']?.toString() ?? '';
      _brandName = (d['brandName'] ?? d['appName'] ?? '').toString();
      _brandLogo = (d['brandLogo'] ?? d['appLogo'] ?? '').toString();
    });
  }

  Future<void> _load() async {
    try {
      // 品牌信息（名称/logo）与版本配置同接口，这里一次拉全
      final r = await _api.get('/api/v1/auth/config');
      final d =
          (r.data as Map<String, dynamic>)['data'] as Map<String, dynamic>? ??
              {};
      if (mounted && d.isNotEmpty) {
        _applyConfig(d);
        // 配置类内容"请求一次缓存即可"：落盘，下次进页直出
        unawaited(_api.writePref('authConfig', jsonEncode(d)));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(t('meAboutUs'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 品牌 logo：读取后台配置，无配置回落默认品牌头像
          Center(
            child: _brandLogo.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.network(
                      _brandLogo,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          AppTheme.brandAvatar(size: 72),
                    ),
                  )
                : AppTheme.brandAvatar(size: 72),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(_brandName.isEmpty ? t('meAbout') : _brandName,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface)),
          ),
          if (_version.isNotEmpty)
            Center(
              child: Text(t('meVersion', {'version': _version}),
                  style:
                      TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
            ),
          const SizedBox(height: 24),
          if (_updateLog.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t('meWhatsNew'),
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface)),
                  const SizedBox(height: 8),
                  Text(_updateLog,
                      style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                          height: 1.6)),
                ],
              ),
            ),
          const SizedBox(height: 16),
          // 更多信息
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('meAboutUs'),
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface)),
                const SizedBox(height: 8),
                Text(
                  t('meAboutDesc').replaceAll('ChatPulse', _appName),
                  style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                      height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _infoRow(Icons.system_update_outlined, t('meCheckUpdate'),
                    _checkUpdate,
                    trailing: _version.isEmpty
                        ? null
                        : (_version == _currentVersion
                            ? t('meUpToDate')
                            : t('meNewVersion'))),
                Divider(height: 1, indent: 50, color: scheme.outlineVariant),
                _infoRow(Icons.policy_outlined, t('mePrivacyPolicy'), () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => PolicyPage(
                          title: t('mePrivacyPolicy'),
                          content: kPrivacyPolicy,
                          appName: _appName)));
                }),
                Divider(height: 1, indent: 50, color: scheme.outlineVariant),
                _infoRow(Icons.gavel_outlined, t('meTermsOfService'), () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => PolicyPage(
                          title: t('meTermsOfService'),
                          content: kTermsOfService,
                          appName: _appName)));
                }),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
                'Copyright © ${_brandName.isEmpty ? 'ChatPulse' : _brandName}',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ),
          const SizedBox(height: 16),
          if (_androidUrl.isNotEmpty)
            _linkRow(Icons.android, t('meAndroidDownload'), _androidUrl),
          if (_iosUrl.isNotEmpty)
            _linkRow(Icons.apple, t('meIosDownload'), _iosUrl),
        ],
      ),
    );
  }

  /// 检测更新：拉后台配置，有新版本弹新版更新弹窗（外部浏览器下载）
  Future<void> _checkUpdate() async {
    // 重新拉一次保证拿到最新后台配置
    final info = await UpdateService.fetch();
    if (!mounted) return;
    final t = AppLocalizations.of(context).t;
    if (info == null || info.version.isEmpty) {
      AppDialogs.toast(context, t('meGetVersionFailed'));
      return;
    }
    final shown = await UpdateDialog.showIfAvailable(context, info);
    if (!shown && mounted) {
      AppDialogs.toast(
          context, t('meAlreadyLatestVersion', {'version': _currentVersion}));
    }
  }

  Widget _infoRow(IconData icon, String label, VoidCallback onTap,
      {String? trailing}) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(fontSize: 15, color: scheme.onSurface)),
            ),
            if (trailing != null && trailing.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(trailing,
                    style: TextStyle(
                        fontSize: 13, color: scheme.onSurfaceVariant)),
              ),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _linkRow(IconData icon, String label, String url) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () async {
        // 直接调系统外部浏览器打开下载地址
        final uri = Uri.tryParse(url);
        if (uri == null || !uri.hasScheme) return;
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {}
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
                child: Text(label,
                    style: TextStyle(fontSize: 14, color: scheme.onSurface))),
            Icon(Icons.open_in_new, size: 16, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
