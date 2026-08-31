import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../l10n/app_locale.dart';
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
    final t = AppLocalizations.of(context).t;
    final p = _profile;
    final name = p?['nickname']?.toString() ?? t('myQrDefaultName');
    final account = p?['account']?.toString() ?? '';
    final id = p?['id']?.toString() ?? '';
    final avatar = p?['avatar']?.toString() ?? '';
    final qrData = 'chatpulse://user?uid=$id&name=${Uri.encodeComponent(name)}';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(t('myQrTitle')),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            children: [
              // 头像 + 昵称 + 账号
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.center,
                child: avatar.isNotEmpty
                    ? Image.network(avatar,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Text(
                            name.isEmpty ? '?' : name.characters.first,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 26)))
                    : Text(name.isEmpty ? '?' : name.characters.first,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 26)),
              ),
              const SizedBox(height: 12),
              Text(name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600)),
              if (account.isNotEmpty) const SizedBox(height: 4),
              if (account.isNotEmpty)
                Text(account,
                    style: TextStyle(
                        fontSize: 13, color: context.cs.onSurfaceVariant)),
              const SizedBox(height: 24),
              // 二维码卡片
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.cs.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: id.isEmpty
                    ? const SizedBox(
                        width: 220,
                        height: 220,
                        child: Center(child: CircularProgressIndicator()))
                    : QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 220,
                        backgroundColor: Colors.white,
                        eyeStyle: QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: context.cs.onSurface),
                        dataModuleStyle: QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: context.cs.onSurface),
                      ),
              ),
              const SizedBox(height: 20),
              Text(t('myQrScanToAdd'),
                  style: TextStyle(
                      fontSize: 13, color: context.cs.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
