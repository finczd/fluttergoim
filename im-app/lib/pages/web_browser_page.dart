import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import 'web_browser_io.dart' if (dart.library.html) 'web_browser_web.dart';

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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text(widget.title,
            style: const TextStyle(fontSize: 16, color: AppTheme.textPrimary)),
        centerTitle: true,
        actions: [
          // 右上角圆形关闭按钮：点击返回（回到发现页）
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF0F2F5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 18, color: AppTheme.textSecondary),
                ),
              ),
            ),
          ),
        ],
      ),
      // 网页由 iframe 覆盖（Web）或占位提示（native）
      body: SizedBox.expand(child: _content()),
    );
  }

  Widget _content() {
    if (isWebOverlaySupported()) {
      return const SizedBox.shrink(); // iframe 已覆盖，此处留空
    }
    // native：外部浏览器兜底
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.open_in_new, size: 48, color: Color(0xFF9AA3AE)),
          const SizedBox(height: 12),
          Text(widget.url,
              style: const TextStyle(color: Color(0xFF6B7480)),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => launchUrl(Uri.parse(widget.url)),
            icon: const Icon(Icons.launch),
            label: const Text('在浏览器中打开'),
          ),
        ],
      ),
    );
  }
}
