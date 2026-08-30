import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'qr_login_page.dart';
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
    Icons.web, Icons.help_outline, Icons.folder_special_outlined,
    Icons.build_outlined, Icons.dashboard_outlined, Icons.widgets_outlined,
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await _dio.get('/api/v1/app/list',
          options: Options(headers: {'Authorization': 'Bearer ${await _api.readToken()}'}));
      final data = (r.data as Map<String, dynamic>)['data'] as List<dynamic>? ?? [];
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
        '小程序';
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
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 顶栏：标题 + 扫一扫入口（扫码登录）
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                    child: Row(
                      children: [
                        const Text('发现',
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary)),
                        const Spacer(),
                        IconButton(
                          onPressed: _openQrScanner,
                          icon: const Icon(Icons.qr_code_scanner,
                              size: 24, color: AppTheme.textPrimary),
                          tooltip: '扫一扫',
                        ),
                      ],
                    ),
                  ),
                  // 快捷入口（扫一扫 / 朋友圈，占位后续接功能）
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(
                      children: [
                        _quickEntry(Icons.qr_code_scanner, '扫一扫', _openQrScanner),
                        const SizedBox(width: 12),
                        _quickEntry(Icons.camera_alt_outlined, '朋友圈', () {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('朋友圈（V2.0 上线）')));
                        }),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _apps.isEmpty
                        ? const Center(
                            child: Text('暂无应用，请在后台「小程序管理」上架',
                                style: TextStyle(color: AppTheme.textTertiary)))
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _apps.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) => _appTile(_apps[i], i),
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _quickEntry(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: AppTheme.primary),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
          ],
        ),
      ),
    );
  }

  /// 扫一扫：手机端扫 PC 端二维码登录
  void _openQrScanner() {
    Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ScanQrLoginPage()));
  }

  Widget _appTile(Map<String, dynamic> a, int i) {
    final cat = a['category']?.toString() ?? '';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _open(a),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: i.isEven ? const Color(0xFFEAF1FF) : const Color(0xFFE8F7EE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_icons[i % _icons.length], size: 22,
                    color: i.isEven ? AppTheme.primary : AppTheme.success),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_name(a),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                    if (cat.isNotEmpty)
                      Text(cat, style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: AppTheme.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
