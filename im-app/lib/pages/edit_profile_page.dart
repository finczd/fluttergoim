import 'package:flutter/material.dart';

import '../services/friend_service.dart';
import '../theme/app_theme.dart';

/// 个人资料编辑（需求9）：昵称 / 头像 / 签名（后端 PUT /user/profile）
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _svc = FriendService();
  final _nickname = TextEditingController();
  final _bio = TextEditingController();
  String _avatar = '';
  bool _loading = true;
  bool _saving = false;
  String _msg = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nickname.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p = await _svc.profile();
      if (mounted) {
        setState(() {
          _nickname.text = p['nickname']?.toString() ?? '';
          _avatar = p['avatar']?.toString() ?? '';
          _bio.text = p['bio']?.toString() ?? '';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _msg = '';
    });
    try {
      final r = await _svc.updateProfile(
        nickname: _nickname.text.trim(),
        bio: _bio.text.trim(),
        avatar: _avatar,
      );
      if (mounted) {
        setState(() => _msg = r ? '已保存' : '保存失败');
        if (r) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('已保存')));
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _msg = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('编辑资料'),
        backgroundColor: AppTheme.background,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '保存中…' : '保存',
                style: const TextStyle(
                    fontSize: 15,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 头像（点击换头像：MinIO 上传 V2.0）
                Center(
                  child: GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('头像上传（V2.0 接入 MinIO）')));
                    },
                    child: Stack(
                      children: [
                        Container(
                          width: 88, height: 88,
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                          ),
                          clipBehavior: Clip.antiAlias,
                          alignment: Alignment.center,
                          child: _avatar.isNotEmpty
                              ? Image.network(_avatar, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _initialText())
                              : _initialText(),
                        ),
                        Positioned(
                          right: 0, bottom: 0,
                          child: Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.photo_camera,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                _field('昵称', _nickname, icon: Icons.badge_outlined),
                const SizedBox(height: 14),
                _field('个性签名', _bio, icon: Icons.edit_note, maxLines: 3),
                if (_msg.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(_msg,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppTheme.danger, fontSize: 13)),
                ],
              ],
            ),
    );
  }

  Widget _initialText() => Text(
        _nickname.text.isEmpty ? '?' : _nickname.text.characters.first,
        style: const TextStyle(
            color: Colors.white, fontSize: 32, fontWeight: FontWeight.w600),
      );

  Widget _field(String label, TextEditingController ctrl,
      {required IconData icon, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, color: AppTheme.textTertiary)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          maxLength: maxLines > 1 ? 100 : 20,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20, color: AppTheme.textTertiary),
            filled: true,
            fillColor: AppTheme.surface,
            isDense: true,
            counterText: '',
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primary, width: 1.2),
            ),
          ),
        ),
      ],
    );
  }
}
