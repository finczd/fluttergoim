import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_locale.dart';
import '../services/api_client.dart';
import '../services/friend_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_dialogs.dart';

/// 个人资料编辑（需求9）：昵称 / 头像 / 签名（后端 PUT /user/profile）
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

/// 取异常的**后端原始提示**（去掉 Dart 的 "Exception: " 前缀），失败时回退 fallback。
String _errMsg(Object e, String fallback) {
  var s = e.toString().trim();
  if (s.startsWith('Exception:')) s = s.substring('Exception:'.length).trim();
  if (s.startsWith('DioException')) s = fallback;
  return s.isEmpty ? fallback : s;
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _svc = FriendService();
  final _nickname = TextEditingController();
  final _bio = TextEditingController();
  String _avatar = '';
  bool _loading = true;
  bool _saving = false;
  bool _uploadingAvatar = false; // 头像上传中：禁用点击 + 显示菊花
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
          _bio.text = p['signature']?.toString() ?? '';
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
        signature: _bio.text.trim(),
        avatar: _avatar,
      );
      if (mounted) {
        final t = AppLocalizations.of(context).t;
        setState(() =>
            _msg = r ? t('editProfileSaved') : t('editProfileSaveFailed'));
        if (r) {
          AppDialogs.toast(context, t('editProfileSaved'));
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
    final t = AppLocalizations.of(context).t;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(t('editProfileTitle')),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? t('editProfileSaving') : t('editProfileSave'),
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
                // 头像（点击选图 → 上传 MinIO → 仅本地预览，保存时与昵称/签名一起 PUT）
                Center(
                  child: GestureDetector(
                    onTap: _uploadingAvatar ? null : _pickAvatar,
                    child: Stack(
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: const BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                          ),
                          clipBehavior: Clip.antiAlias,
                          alignment: Alignment.center,
                          child: _avatar.isNotEmpty
                              ? Image.network(_avatar,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _initialText())
                              : _initialText(),
                        ),
                        if (_uploadingAvatar)
                          Positioned.fill(
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              ),
                            ),
                          ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 28,
                            height: 28,
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
                _field(t('editProfileNickname'), _nickname,
                    icon: Icons.badge_outlined),
                const SizedBox(height: 14),
                _field(t('editProfileBio'), _bio,
                    icon: Icons.edit_note, maxLines: 3),
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

  /// 头像：相册选图 → MinIO 上传 → 仅本地预览 URL。
  /// 与昵称/签名一起在用户点「保存」时一并 PUT（避免选完图不保存直接退页产生的脏数据）。
  /// 失败回滚到旧头像，toast 提示。
  Future<void> _pickAvatar() async {
    if (_uploadingAvatar) return;
    final t = AppLocalizations.of(context).t;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() => _uploadingAvatar = true);
    final oldAvatar = _avatar;
    try {
      final up = await ApiClient.instance.uploadFile(
        picked.path,
        picked.name.isEmpty ? 'avatar.jpg' : picked.name,
        dir: 'avatar/',
      );
      if (!mounted) return;
      setState(() => _avatar = (up['url'] ?? '').toString());
      AppDialogs.toast(context, t('editProfileAvatarUploaded'));
    } catch (e) {
      if (!mounted) return;
      setState(() => _avatar = oldAvatar); // 失败回滚
      AppDialogs.toast(context, _errMsg(e, t('editProfileAvatarUploadFailed')));
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
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
            style: TextStyle(fontSize: 13, color: context.cs.onSurfaceVariant)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          maxLength: maxLines > 1 ? 100 : 20,
          decoration: InputDecoration(
            prefixIcon:
                Icon(icon, size: 20, color: context.cs.onSurfaceVariant),
            filled: true,
            fillColor: context.cs.surface,
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
