import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_locale.dart';
import '../services/api_client.dart';
import '../services/moment_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_dialogs.dart';

/// 朋友圈（微信风格：封面 + 发布 + 时间线 + 点赞）
/// 数据走后端 /api/v1/moments（含小助手动态、好友动态；被屏蔽的仅自己可见）
class MomentsPage extends StatefulWidget {
  /// 指定用户 ID（好友资料页"朋友圈"入口）；为空=我的朋友圈
  final String? userId;
  final String? userName;
  const MomentsPage({super.key, this.userId, this.userName});

  @override
  State<MomentsPage> createState() => _MomentsPageState();
}

class _MomentsPageState extends State<MomentsPage> {
  final _svc = MomentService.instance;
  bool _loading = true;
  List<Map<String, dynamic>> _posts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = widget.userId != null
          ? await _svc.listByUser(widget.userId!)
          : await _svc.list();
      if (mounted) {
        setState(() {
          _posts = ((data['list'] as List<dynamic>?) ?? [])
              .map((e) => (e as Map).cast<String, dynamic>())
              .toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _publish() async {
    final t = AppLocalizations.of(context).t;
    final ctrl = TextEditingController();
    final images = <XFile>[];
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cs.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t('momentsPublishTitle'),
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: context.cs.onSurface)),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLines: 4,
                autofocus: true,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: t('momentsThoughtHint'),
                  hintStyle: TextStyle(color: context.cs.onSurfaceVariant),
                  filled: true,
                  fillColor: Theme.of(context).scaffoldBackgroundColor,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in images)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(File(f.path),
                          width: 72, height: 72, fit: BoxFit.cover),
                    ),
                  if (images.length < 9)
                    InkWell(
                      onTap: () async {
                        final x = await ImagePicker().pickImage(
                            source: ImageSource.gallery, imageQuality: 80);
                        if (x != null) setSheet(() => images.add(x));
                      },
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: context.cs.surfaceContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.add_a_photo_outlined,
                            color: context.cs.onSurfaceVariant),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style:
                      FilledButton.styleFrom(backgroundColor: AppTheme.primary),
                  child: Text(t('momentsPublish')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    final text = ctrl.text.trim();
    if (text.isEmpty && images.isEmpty) {
      AppDialogs.toast(context, t('momentsEmptyContent'));
      return;
    }
    try {
      // 图片先上传（除网络图外逐张走 /upload）
      final urls = <String>[];
      for (final f in images) {
        final url = await _uploadImage(f);
        if (url.isNotEmpty) urls.add(url);
      }
      await _svc.publish(text, urls);
      AppDialogs.toast(context, t('momentsPublished'));
      _load();
    } catch (_) {
      AppDialogs.toast(context, t('momentsPublishFailed'));
    }
  }

  Future<String> _uploadImage(XFile f) async {
    try {
      final data =
          await ApiClient.instance.uploadFile(f.path, f.name, dir: 'moments/');
      return (data['url'] ?? '').toString();
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 190,
              backgroundColor: context.cs.surface,
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new,
                    size: 20, color: Colors.white),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset('assets/images/beijing.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: const Color(0xFF2E4A6B))),
                    Positioned(
                      right: 16,
                      bottom: 14,
                      child: Row(
                        children: [
                          Text(widget.userName ?? t('momentsMe'),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  shadows: [
                                    Shadow(blurRadius: 6, color: Colors.black54)
                                  ])),
                          const SizedBox(width: 10),
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            alignment: Alignment.center,
                            child: Text(widget.userName ?? t('momentsMe'),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                // 仅「我的朋友圈」显示发布相机，查看他人时不显示
                if (widget.userId == null)
                  IconButton(
                    onPressed: _publish,
                    icon: const Icon(Icons.camera_alt_outlined,
                        color: Colors.white),
                    tooltip: t('momentsPublishTitle'),
                  ),
              ],
            ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(
                    child: CircularProgressIndicator(color: AppTheme.primary)),
              )
            else if (_posts.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                      widget.userId != null
                          ? t('momentsFriendEmpty')
                          : t('momentsMyEmpty'),
                      style: TextStyle(
                          fontSize: 13, color: context.cs.onSurfaceVariant)),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _postItem(_posts[i]),
                  childCount: _posts.length,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _postItem(Map<String, dynamic> p) {
    final name = (p['senderName'] ?? '').toString();
    final avatar = (p['senderAvatar'] ?? '').toString();
    final content = (p['content'] ?? '').toString();
    final images = ((p['images'] as List<dynamic>?) ?? [])
        .map((e) => e.toString())
        .toList();
    final likeCount = (p['likeCount'] as num?)?.toInt() ?? 0;
    final liked = p['liked'] == true;
    final hidden = p['hidden'] == true;
    final time = (p['createdAt'] ?? '').toString();
    final id = (p['id'] ?? '').toString();
    return Container(
      color: context.cs.surface,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      margin: const EdgeInsets.only(bottom: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头像（网络图或首字占位）
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            child: avatar.isNotEmpty
                ? Image.network(avatar,
                    width: 42,
                    height: 42,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Text(
                        name.isEmpty ? '?' : name.characters.first,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600)))
                : Text(name.isEmpty ? '?' : name.characters.first,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF3D6BA8))),
                    if (p['assistant'] == true) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(AppLocalizations.of(context).t('momentsOfficial'),
                            style: const TextStyle(
                                fontSize: 10, color: AppTheme.primary)),
                      ),
                    ],
                    if (hidden) ...[
                      const Spacer(),
                      Icon(Icons.lock_outline,
                          size: 13, color: context.cs.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Text(AppLocalizations.of(context).t('momentsOnlyMe'),
                          style: TextStyle(
                              fontSize: 11,
                              color: context.cs.onSurfaceVariant)),
                    ],
                  ],
                ),
                if (content.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(content,
                        style: TextStyle(
                            fontSize: 15, color: context.cs.onSurface)),
                  ),
                if (images.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final img in images)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(img,
                                width: 108,
                                height: 108,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                    width: 108,
                                    height: 108,
                                    color: Theme.of(context)
                                        .scaffoldBackgroundColor)),
                          ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Text(time,
                          style: TextStyle(
                              fontSize: 12,
                              color: context.cs.onSurfaceVariant)),
                      const Spacer(),
                      InkWell(
                        onTap: () async {
                          try {
                            final nowLiked = await _svc.like(id);
                            if (mounted) {
                              setState(() {
                                p['liked'] = nowLiked;
                                p['likeCount'] =
                                    likeCount + (nowLiked ? 1 : -1);
                              });
                            }
                          } catch (_) {
                            AppDialogs.toast(
                                context,
                                AppLocalizations.of(context)
                                    .t('momentsActionFailed'));
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                liked ? Icons.favorite : Icons.favorite_border,
                                size: 16,
                                color: liked
                                    ? const Color(0xFFE9564E)
                                    : context.cs.onSurfaceVariant,
                              ),
                              if (likeCount > 0) ...[
                                const SizedBox(width: 4),
                                Text('$likeCount',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: context.cs.onSurfaceVariant)),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 14, color: context.cs.outlineVariant),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
