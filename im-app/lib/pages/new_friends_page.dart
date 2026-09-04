import 'package:flutter/material.dart';

import '../services/friend_service.dart';
import '../services/friend_req_store.dart';
import '../l10n/app_locale.dart';
import '../theme/app_theme.dart';
import '../widgets/app_dialogs.dart';

/// 新朋友：好友申请记录（需求8）—— 显示申请者昵称/账号/留言 + 通过/拒绝按钮
class NewFriendsPage extends StatefulWidget {
  const NewFriendsPage({super.key});

  @override
  State<NewFriendsPage> createState() => _NewFriendsPageState();
}

class _NewFriendsPageState extends State<NewFriendsPage> {
  final _svc = FriendService();
  List<FriendRequest> _requests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final requests = await _svc.incoming();
      if (mounted) {
        setState(() {
          _requests = requests;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handle(String reqId, bool agree) async {
    await _svc.handle(reqId, agree);
    if (!mounted) return;
    final t = AppLocalizations.of(context).t;
    AppDialogs.toast(context,
        agree ? t('newFriendsApproved') : t('newFriendsRejectedToast'));
    _load();
    // 审批后主动刷新全局申请数（被申请人收不到 friend.accepted WS 事件）
    FriendReqStore.instance.refresh();
  }

  /// 申请人头像：有头像加载网络图，失败/无头像回落首字母色块
  Widget _avatar(FriendRequest r, String name) {
    final initial = name.isNotEmpty ? name[0] : '?';
    final color =
        AppTheme.avatarColors[name.hashCode.abs() % AppTheme.avatarColors.length];
    final block = Container(
      width: 44,
      height: 44,
      color: color,
      alignment: Alignment.center,
      child: Text(initial,
          style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: (r.fromUserAvatar.isNotEmpty)
          ? Image.network(
              r.fromUserAvatar,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => block,
            )
          : block,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(t('newFriendsTitle')),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
              ? Center(
                  child: Text(t('newFriendsEmpty'),
                      style: TextStyle(color: context.cs.onSurfaceVariant)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _requests.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _tile(_requests[i]),
                ),
    );
  }

  Widget _tile(FriendRequest r) {
    final t = AppLocalizations.of(context).t;
    final approved = r.status == 1;
    final rejected = r.status == 2;
    // 优先用后端注入的申请人昵称/账号，兜底到 ID
    final name = r.fromUserName.isNotEmpty
        ? r.fromUserName
        : (r.fromUserAccount.isNotEmpty ? r.fromUserAccount : r.fromUser);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cs.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _avatar(r, name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: context.cs.onSurface)),
                if (r.message.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(r.message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, color: context.cs.onSurfaceVariant)),
                ],
              ],
            ),
          ),
          if (approved)
            Text(t('newFriendsAccepted'),
                style: const TextStyle(fontSize: 13, color: AppTheme.success))
          else if (rejected)
            Text(t('newFriendsDeclined'),
                style:
                    TextStyle(fontSize: 13, color: context.cs.onSurfaceVariant))
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _miniBtn(t('newFriendsAccept'), AppTheme.primary,
                    () => _handle(r.id, true)),
                const SizedBox(width: 8),
                _miniBtn(t('newFriendsDecline'), AppTheme.danger,
                    () => _handle(r.id, false)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _miniBtn(String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 13)),
      ),
    );
  }
}
