import 'package:flutter/material.dart';

import '../l10n/app_locale.dart';
import '../services/api_client.dart';
import '../services/friend_service.dart';
import '../theme/app_theme.dart';
import 'favorites_page.dart';
import 'login_page.dart';
import 'profile_page.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await _svc.profile();
      if (mounted) setState(() => _profile = p);
    } catch (_) {}
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('退出', style: TextStyle(color: AppTheme.danger))),
        ],
      ),
    );
    if (confirm != true) return;
    await _api.logout();
    if (mounted) {
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    final p = _profile;
    final name = p?['nickname']?.toString() ?? '未登录';
    final account = p?['account']?.toString() ?? '';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            // 顶栏"我的"
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Text(t('me'),
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
            ),
            // 资料卡片（surface 灰底）
            InkWell(
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfilePage())),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                color: AppTheme.surface,
                child: Row(
                  children: [
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Text(name.isEmpty ? '?' : name.characters.first,
                          style: const TextStyle(
                              fontSize: 26,
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('账号：$account',
                              style: const TextStyle(
                                  fontSize: 13, color: AppTheme.textTertiary)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        color: AppTheme.textTertiary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // 我的服务
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _card([
                _row(Icons.favorite_outline, '我的收藏', () {
                  Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const FavoritesPage()));
                }),
                _row(Icons.star_border, '朋友圈', () {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('朋友圈（V2.0 上线）')));
                }),
                _row(Icons.account_balance_wallet_outlined, '钱包', () {}),
              ]),
            ),
            const SizedBox(height: 8),
            // 设置
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _card([
                _row(Icons.notifications_none, '消息通知', () {}),
                _row(Icons.privacy_tip_outlined, '隐私', () {}),
                _row(Icons.language, '语言 / Language', () {
                  LocaleProvider.of(context)?.toggle();
                  setState(() {});
                }),
                _row(Icons.info_outline, '关于 ChatPulse', () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const AboutPage()));
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
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.danger,
                    side: const BorderSide(color: AppTheme.divider),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('退出登录',
                      style: TextStyle(fontSize: 15)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(children: rows),
    );
  }

  Widget _row(IconData icon, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppTheme.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 15, color: AppTheme.textPrimary)),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textTertiary, size: 18),
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
  String _version = '';
  String _updateLog = '';
  String _androidUrl = '';
  String _iosUrl = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await _api.get('/api/v1/auth/config');
      final d = (r.data as Map<String, dynamic>)['data'] as Map<String, dynamic>? ?? {};
      if (mounted) {
        setState(() {
          _version = d['appVersion']?.toString() ?? '';
          _updateLog = d['updateLog']?.toString() ?? '';
          _androidUrl = d['androidUrl']?.toString() ?? '';
          _iosUrl = d['iosUrl']?.toString() ?? '';
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('关于 ChatPulse')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(child: AppTheme.brandAvatar(size: 72)),
          const SizedBox(height: 12),
          const Center(
            child: Text('ChatPulse',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          if (_version.isNotEmpty)
            Center(
              child: Text('版本 $_version',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textTertiary)),
            ),
          const SizedBox(height: 24),
          if (_updateLog.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('更新内容',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(_updateLog,
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary, height: 1.6)),
                ],
              ),
            ),
          const SizedBox(height: 16),
          if (_androidUrl.isNotEmpty)
            _linkRow(Icons.android, 'Android 下载', _androidUrl),
          if (_iosUrl.isNotEmpty)
            _linkRow(Icons.apple, 'iOS 下载', _iosUrl),
        ],
      ),
    );
  }

  Widget _linkRow(IconData icon, String label, String url) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('浏览器打开：$url')));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppTheme.primary),
            const SizedBox(width: 12),
            Expanded(
                child: Text(label,
                    style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary))),
            const Icon(Icons.open_in_new, size: 16, color: AppTheme.textTertiary),
          ],
        ),
      ),
    );
  }
}
