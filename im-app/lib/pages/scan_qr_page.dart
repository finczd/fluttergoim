import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 扫一扫占位页（V2.0 二维码功能后续接）
class ScanQrPage extends StatelessWidget {
  const ScanQrPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('扫一扫', style: TextStyle(color: Colors.white)),
      ),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.qr_code_scanner, size: 96, color: Colors.white70),
            SizedBox(height: 16),
            Text(
              '对准二维码即可扫描\n（V2.0 上线）',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.white60, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
