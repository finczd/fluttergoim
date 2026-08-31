import 'package:flutter/material.dart';

import '../l10n/app_locale.dart';
import '../theme/app_theme.dart';
import 'web_browser_io.dart' if (dart.library.html) 'web_browser_web.dart';
import 'web_view_io.dart' if (dart.library.html) 'web_view_web.dart';

/// 内置浏览器（类似微信小程序）：网页内嵌展示，右上角圆形按钮关闭返回
class WebBrowserPage extends StatefulWidget {
  final String url;
  final String title;
  const WebBrowserPage({super.key, required this.url, required this.title});

  @override
  State<WebBrowserPage> createState() => _WebBrowserPageState();
}

class _WebBrowserPageState extends State<WebBrowserPage> {
  @override
  void initState() {
    super.initState();
    // Web 端：把 iframe 覆盖到 Flutter 页面下方（AppBar 之上可交互）
    openBrowserOverlay(widget.url);
  }

  @override
  void dispose() {
    closeBrowserOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: context.cs.surface,
        elevation: 0.5,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        // 微信小程序风格：细箭头返回
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 20, color: Color(0xFF111111)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.title,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: Color(0xFF111111))),
        centerTitle: true,
        // 微信小程序胶囊：左侧 ... / 右侧 ⭕
        actions: [
          _buildCapsule(),
          const SizedBox(width: 12),
        ],
      ),
      // 网页：Web 端由 iframe 覆盖，native 端内置 WebView
      body: SizedBox.expand(
        child: isWebOverlaySupported()
            ? const SizedBox.shrink()
            : buildNativeWebView(widget.url),
      ),
    );
  }

  /// 微信小程序风格胶囊按钮：左侧「···」菜单 / 右侧「⭕」关闭
  Widget _buildCapsule() {
    return Center(
      child: Container(
        width: 88,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          border: Border.all(color: const Color(0xFFE6E6E6), width: 0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: _showMoreMenu,
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(16)),
                child: const Center(
                  child: Icon(Icons.more_horiz,
                      size: 20, color: Color(0xFF111111)),
                ),
              ),
            ),
            const VerticalDivider(
                width: 0.5, color: Color(0xFFE6E6E6), indent: 6, endIndent: 6),
            Expanded(
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
                borderRadius:
                    const BorderRadius.horizontal(right: Radius.circular(16)),
                child: const Center(
                  child: Icon(Icons.radio_button_unchecked,
                      size: 18, color: Color(0xFF111111)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreMenu() {
    final t = AppLocalizations.of(context).t;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: ctx.cs.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Icon(Icons.refresh, color: context.cs.onSurface),
                title:
                    Text(t('webBrowserRefreshPage'), style: TextStyle(color: context.cs.onSurface)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  // Web 端刷新 iframe；native 端通过 WebView controller 刷新
                  if (isWebOverlaySupported()) {
                    openBrowserOverlay(widget.url);
                  } else {
                    // native WebView 刷新由 buildNativeWebView 内部持有 controller，
                    // 这里简单重新加载当前页（通过重建）
                    setState(() {});
                  }
                },
              ),
              ListTile(
                leading:
                    Icon(Icons.open_in_browser, color: context.cs.onSurface),
                title: Text(t('webBrowserOpenInBrowser'),
                    style: TextStyle(color: context.cs.onSurface)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  // url_launcher 已在 pubspec，但此处保持无依赖新增
                  // 如需跳转外部浏览器可在此接入
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
