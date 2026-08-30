import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'scan_camera_io.dart' if (dart.library.html) 'scan_camera_web.dart';

/// 移动端扫一扫（需求1）：扫 PC 端二维码 → 解析 ticket → 确认登录
/// - native：mobile_scanner 摄像头实时扫码
/// - H5：摄像头受限，弹输入框手动粘贴 ticket（兜底）
class ScanQrLoginPage extends StatefulWidget {
  const ScanQrLoginPage({super.key});

  @override
  State<ScanQrLoginPage> createState() => _ScanQrLoginPageState();
}

class _ScanQrLoginPageState extends State<ScanQrLoginPage> {
  final _api = ApiClient.instance;
  final _ticketCtrl = TextEditingController();
  bool _processing = false;
  String _msg = '';

  @override
  void dispose() {
    _ticketCtrl.dispose();
    super.dispose();
  }

  /// 解析二维码内容（chatpulse://qr?ticket=xxx&secret=xxx）→ 提取 ticket
  String _extractTicket(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null) return raw.trim();
    return uri.queryParameters['ticket'] ?? raw.trim();
  }

  /// 手机端确认登录：POST /auth/qr/confirm（需登录态）
  Future<void> _confirm(String ticket) async {
    if (ticket.isEmpty || _processing) return;
    setState(() {
      _processing = true;
      _msg = '';
    });
    try {
      final r = await _api.post('/api/v1/auth/qr/confirm', data: {'ticket': ticket});
      final code = (r.data as Map<String, dynamic>)['code'];
      if (mounted) {
        setState(() {
          _msg = code == 0 ? '已确认登录，请回到电脑端查看' : '确认失败，请重试';
        });
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_msg)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _msg = '确认失败：${e.toString().replaceFirst('Exception: ', '')}');
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

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
      body: kIsWeb ? _buildWebFallback() : _buildCamera(),
    );
  }

  /// native：摄像头扫码
  Widget _buildCamera() {
    return ScanCamera(onScan: (raw) => _confirm(_extractTicket(raw)));
  }

  /// H5：输入框粘贴 ticket（浏览器无摄像头权限时兜底）
  Widget _buildWebFallback() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Column(
              children: [
                Icon(Icons.qr_code_scanner, size: 64, color: Colors.white54),
                SizedBox(height: 12),
                Text('浏览器环境不支持调起摄像头',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                Text('请用手机 App 扫电脑端二维码，或手动粘贴 ticket',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _ticketCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '粘贴二维码中的 ticket',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF2A2A2A),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _processing
                  ? null
                  : () => _confirm(_ticketCtrl.text.trim()),
              child: Text(_processing ? '确认中…' : '确认登录'),
            ),
          ),
        ],
      ),
    );
  }
}
