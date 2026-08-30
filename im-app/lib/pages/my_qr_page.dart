import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/friend_service.dart';
import '../theme/app_theme.dart';

/// 我的二维码：个人名片二维码（内容 chatpulse://user?uid=xxx&name=xxx）
/// 好友扫码后可添加/发起聊天（需求9）
class MyQrPage extends StatefulWidget {
  const MyQrPage({super.key});

  @override
  State<MyQrPage> createState() => _MyQrPageState();
}

class _MyQrPageState extends State<MyQrPage> {
  final _svc = FriendService();
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

  @override
  Widget build(BuildContext context) {
    final p = _profile;
    final name = p?['nickname']?.toString() ?? 'ChatPulse 用户';
    final account = p?['account']?.toString() ?? '';
    final id = p?['id']?.toString() ?? '';
    final avatar = p?['avatar']?.toString() ?? '';
    final qrData = 'chatpulse://user?uid=$id&name=${Uri.encodeComponent(name)}';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('我的二维码'),
        backgroundColor: AppTheme.background,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            children: [
              // 头像 + 昵称 + 账号
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.center,
                child: avatar.isNotEmpty
                    ? Image.network(avatar, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Text(
                            name.isEmpty ? '?' : name.characters.first,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 26)))
                    : Text(name.isEmpty ? '?' : name.characters.first,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 26)),
              ),
              const SizedBox(height: 12),
              Text(name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600)),
              if (account.isNotEmpty)
                const SizedBox(height: 4),
              if (account.isNotEmpty)
                Text(account,
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textTertiary)),
              const SizedBox(height: 24),
              // 二维码卡片
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.divider, width: 0.5),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: id.isEmpty
                    ? const SizedBox(
                        width: 220, height: 220,
                        child: Center(child: CircularProgressIndicator()))
                    : QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 220,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: AppTheme.textPrimary),
                        dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: AppTheme.textPrimary),
                      ),
              ),
              const SizedBox(height: 20),
              const Text('扫一扫上面的二维码，添加我为好友',
                  style: TextStyle(fontSize: 13, color: AppTheme.textTertiary)),
            ],
          ),
        ),
      ),
    );
  }
}
