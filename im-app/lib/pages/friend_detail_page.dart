import 'package:flutter/material.dart';

import '../l10n/app_locale.dart';
import '../services/conversation_service.dart';
import '../services/friend_service.dart';
import '../theme/app_theme.dart';
import 'moments_page.dart';
import '../widgets/app_dialogs.dart';
import 'chat_page.dart';

/// 好友详情：资料 / 发消息 / 备注 / 删除 / 拉黑
class FriendDetailPage extends StatefulWidget {
  final Map<String, dynamic> friend;
  final String myId;
  const FriendDetailPage({super.key, required this.friend, required this.myId});

  @override
  State<FriendDetailPage> createState() => _FriendDetailPageState();
}

class _FriendDetailPageState extends State<FriendDetailPage> {
  final _svc = FriendService();
  final _convSvc = ConversationService();

  Map<String, dynamic> get f => widget.friend;
  String get _id => f['id']?.toString() ?? '';
  String get _name {
    final r = f['remark']?.toString() ?? '';
    if (r.isNotEmpty) return r;
    return f['nickname']?.toString() ??
        f['account']?.toString() ??
        AppLocalizations.instance.t('friendDetailUser');
  }

  Future<void> _sendMsg() async {
    try {
      final conv = await _convSvc.createDirect(_id);
      if (!mounted) return;
      final item = ConvItem.fromJson({
        'conversation': conv,
        'conversationName': _name,
      });
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChatPage(conv: item, myId: widget.myId)));
    } catch (e) {
      if (mounted) {
        AppDialogs.toast(
            context,
            AppLocalizations.of(context)
                .t('friendDetailStartConvFailed', {'error': '$e'}));
      }
    }
  }

  Future<void> _setRemark() async {
    final t = AppLocalizations.of(context).t;
    final result = await AppDialogs.input(
      context,
      title: t('friendDetailSetRemark'),
      hint: t('friendDetailRemarkHint'),
      maxLines: 1,
      maxLength: 20,
    );
    if (result != null && result.isNotEmpty) {
      // 后端 remark 接口（PUT /friend/:id/remark）暂未接入 UI 展示，仅调用
      final ok = await _svc.setRemark(_id, result);
      if (ok && mounted) {
        AppDialogs.toast(context, AppLocalizations.of(context).t('friendDetailRemarkSaved'));
      }
    }
  }

  Future<void> _confirmDelete() async {
    final t = AppLocalizations.of(context).t;
    final yes = await AppDialogs.confirm(
      context,
      title: t('friendDetailDeleteFriend'),
      message: t('friendDetailDeleteMsg'),
      confirmText: t('friendDetailDelete'),
      danger: true,
    );
    if (yes != true) return;
    final ok = await _svc.delete(_id);
    if (ok && mounted) {
      AppDialogs.toast(context, AppLocalizations.of(context).t('friendDetailFriendDeleted'));
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _confirmBlock() async {
    final t = AppLocalizations.of(context).t;
    final yes = await AppDialogs.confirm(
      context,
      title: t('friendDetailBlockTitle'),
      message: t('friendDetailBlockMsg'),
      confirmText: t('friendDetailBlock'),
      danger: true,
    );
    if (yes != true) return;
    final ok = await _svc.blacklistAdd(_id);
    if (ok && mounted) {
      AppDialogs.toast(context, AppLocalizations.of(context).t('friendDetailBlocked'));
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(t('friendDetailTitle'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 头部资料
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: context.cs.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppTheme.primary,
                  child: Text(_name.characters.first,
                      style: const TextStyle(
                          fontSize: 24,
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 10),
                Text(_name,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(f['account']?.toString() ?? '',
                    style: TextStyle(
                        fontSize: 13, color: context.cs.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: context.cs.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.chat_bubble_outline,
                      color: AppTheme.primary),
                  title: Text(t('friendDetailSendMessage'),
                      style: const TextStyle(fontSize: 15)),
                  trailing: Icon(Icons.chevron_right,
                      size: 18, color: context.cs.onSurfaceVariant),
                  onTap: _sendMsg,
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Icon(Icons.edit_outlined,
                      color: context.cs.onSurfaceVariant),
                  title: Text(t('friendDetailSetRemark'),
                      style: const TextStyle(fontSize: 15)),
                  trailing: Icon(Icons.chevron_right,
                      size: 18, color: context.cs.onSurfaceVariant),
                  onTap: _setRemark,
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.photo_album_outlined,
                      color: AppTheme.orange),
                  title: Text(t('friendDetailMoments'),
                      style: const TextStyle(fontSize: 15)),
                  trailing: Icon(Icons.chevron_right,
                      size: 18, color: context.cs.onSurfaceVariant),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          MomentsPage(userId: _id, userName: _name))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _confirmDelete,
            style: FilledButton.styleFrom(
              backgroundColor: context.cs.surface,
              foregroundColor: AppTheme.danger,
              side: BorderSide(color: context.cs.outlineVariant),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(t('friendDetailDeleteFriend')),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _confirmBlock,
            style: FilledButton.styleFrom(
              backgroundColor: context.cs.surface,
              foregroundColor: AppTheme.danger,
              side: BorderSide(color: context.cs.outlineVariant),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(t('friendDetailBlockTitle')),
          ),
        ],
      ),
    );
  }
}
