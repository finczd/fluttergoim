import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// native 摄像头扫码（mobile_scanner）
class ScanCamera extends StatelessWidget {
  final ValueChanged<String> onScan;
  const ScanCamera({super.key, required this.onScan});

  @override
  Widget build(BuildContext context) {
    return MobileScanner(
      onDetect: (capture) {
        final raw = capture.barcodes.firstOrNull?.rawValue ?? '';
        if (raw.isNotEmpty) onScan(raw);
      },
      errorBuilder: (context, error) => Center(
        child: Text('摄像头不可用：$error',
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ),
    );
  }
}
