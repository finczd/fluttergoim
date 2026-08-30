import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/friend_service.dart';
import '../theme/app_theme.dart';
import 'edit_profile_page.dart';
import 'my_qr_page.dart';

/// 个人资料（设计稿：返回+更多按钮 / 120 圆头像 / 昵称+账号+ID / 信息卡）
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
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
    final name = p?['nickname']?.toString() ?? '未登录';
    final account = p?['account']?.toString() ?? '';
    final phone = p?['phone']?.toString() ?? '';
    final email = p?['email']?.toString() ?? '';
    final id = p?['id']?.toString() ?? '';
    final avatar = p?['avatar']?.toString() ?? '';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // 顶栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 22),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.more_horiz, size: 24),
                  ),
                ],
              ),
            ),
            // 主区
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  // 头像 + 昵称
                  Column(
                    children: [
                      Container(
                        width: 120, height: 120,
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 24,
                                offset: const Offset(0, 8)),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        alignment: Alignment.center,
                        child: avatar.isNotEmpty
                            ? Image.network(avatar, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _avatarText(name))
                            : _avatarText(name),
                      ),
                      const SizedBox(height: 16),
                      Text(name,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      if (account.isNotEmpty)
                        Text('账号：$account',
                            style: const TextStyle(
                                fontSize: 14, color: AppTheme.textTertiary)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // 信息卡
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Column(
                      children: [
                        _infoRow('账号', account),
                        if (id.isNotEmpty) _infoRow('ID', id),
                        if (phone.isNotEmpty)
                          _infoRow('手机', phone, copy: phone),
                        if (email.isNotEmpty)
                          _infoRow('邮箱', email, copy: email),
                        _infoRow('二维码', '点击查看我的二维码', chevron: true,
                            onTap: () {}),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 操作按钮
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _bigAction(Icons.qr_code, '我的二维码', () {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => const MyQrPage()));
                          }),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _bigAction(Icons.edit_outlined, '编辑资料', () async {
                            final changed = await Navigator.of(context)
                                .push<bool>(MaterialPageRoute(
                                    builder: (_) => const EditProfilePage()));
                            if (changed == true) _load();
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarText(String name) => Text(
        name.isEmpty ? '?' : name.characters.first,
        style: const TextStyle(
            fontSize: 44, color: Colors.white, fontWeight: FontWeight.w600),
      );

  Widget _infoRow(String label, String value,
      {bool chevron = false, VoidCallback? onTap, String? copy}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 14, color: AppTheme.textTertiary)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 14, color: AppTheme.textPrimary)),
            ),
            if (copy != null)
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: copy));
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已复制')));
                },
                icon: const Icon(Icons.content_copy, size: 18, color: AppTheme.textTertiary),
              )
            else if (chevron)
              const Icon(Icons.chevron_right, color: AppTheme.textTertiary, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _bigAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primary, size: 24),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
