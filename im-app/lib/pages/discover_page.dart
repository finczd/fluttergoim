import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../l10n/app_locale.dart';
import '../theme/app_theme.dart';
import 'moments_page.dart';
import 'scan_qr_login_page.dart';
import 'web_browser_page.dart';

/// 发现：列表展示后台配置的网页小程序，点击打开（H5 新标签页 / native 浏览器）
class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final _dio = ApiClient.instance.dio;
  final _api = ApiClient.instance;
  List<Map<String, dynamic>> _apps = [];
  bool _loading = true;

  static const _icons = [
    Icons.web,
    Icons.help_outline,
    Icons.folder_special_outlined,
    Icons.build_outlined,
    Icons.dashboard_outlined,
    Icons.widgets_outlined,
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await _dio.get('/api/v1/app/list',
          options: Options(
              headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
      final data =
          (r.data as Map<String, dynamic>)['data'] as List<dynamic>? ?? [];
      if (mounted) {
        setState(() {
          _apps = data.map((e) => e as Map<String, dynamic>).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _name(Map<String, dynamic> a) {
    final loc = Localizations.localeOf(context).languageCode;
    return (loc == 'zh' ? a['nameZh']?.toString() : a['nameEn']?.toString()) ??
        a['nameZh']?.toString() ??
        AppLocalizations.of(context).t('discoverMiniApp');
  }

  Future<void> _open(Map<String, dynamic> a) async {
    final url = a['url']?.toString() ?? '';
    if (url.isEmpty) return;
    // 内置浏览器打开（右上角圆形按钮关闭返回发现页）
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => WebBrowserPage(url: url, title: _name(a))));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 顶栏：标题 + 扫一扫入口（扫码登录）
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                    child: Row(
                      children: [
                        Text(t('discover'),
                            style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: scheme.onSurface)),
                        const Spacer(),
                        IconButton(
                          onPressed: _openQrScanner,
                          icon: Icon(Icons.qr_code_scanner,
                              size: 24, color: scheme.onSurface),
                          splashRadius: 22,
                          tooltip: t('discoverScan'),
                        ),
                      ],
                    ),
                  ),
                  // 快捷入口（扫一扫 / 朋友圈）
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: _quickEntry(
                              scheme,
                              Icons.qr_code_scanner,
                              t('discoverScan'),
                              t('discoverScanSubtitle'),
                              AppTheme.cyan,
                              _openQrScanner),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _quickEntry(scheme, Icons.camera_alt_outlined,
                              t('discoverMoments'), t('discoverMomentsSubtitle'),
                              AppTheme.orange, () {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => const MomentsPage()));
                          }),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _apps.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.apps_outage_outlined,
                                    size: 56,
                                    color: scheme.onSurfaceVariant
                                        .withValues(alpha: 0.5)),
                                const SizedBox(height: 12),
                                Text(t('discoverNoApps'),
                                    style: TextStyle(
                                        color: scheme.onSurfaceVariant,
                                        fontSize: 14)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            itemCount: _apps.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) =>
                                _appTile(scheme, _apps[i], i),
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _quickEntry(ColorScheme scheme, IconData icon, String label,
      String subtitle, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 扫一扫：手机端扫 PC 端二维码登录
  void _openQrScanner() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ScanQrLoginPage()));
  }

  Widget _appTile(ColorScheme scheme, Map<String, dynamic> a, int i) {
    final cat = a['category']?.toString() ?? '';
    final icon = a['icon']?.toString() ?? '';
    final tone = AppTheme.avatarColors[i % AppTheme.avatarColors.length];
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        onTap: () => _open(a),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                child: icon.isNotEmpty
                    ? Image.network(
                        icon,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _appIconBlock(i, tone),
                      )
                    : _appIconBlock(i, tone),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_name(a),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: scheme.onSurface)),
                    if (cat.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(cat,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12, color: scheme.onSurfaceVariant)),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 18, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _appIconBlock(int i, Color tone) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      alignment: Alignment.center,
      child: Icon(_icons[i % _icons.length], size: 22, color: tone),
    );
  }
}
