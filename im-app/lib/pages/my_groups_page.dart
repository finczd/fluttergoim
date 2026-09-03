import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/conversation_service.dart';
import '../l10n/app_locale.dart';
import '../theme/app_theme.dart';
import 'chat_page.dart';

/// 我的群聊（需求9）：显示我加入的所有群，点击进入聊天
class MyGroupsPage extends StatefulWidget {
  final String myId;
  const MyGroupsPage({super.key, required this.myId});

  @override
  State<MyGroupsPage> createState() => _MyGroupsPageState();
}

class _MyGroupsPageState extends State<MyGroupsPage> {
  final _svc = ConversationService();
  final _api = ApiClient.instance;
  List<ConvItem> _groups = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _svc.list();
      final groups = list
          .where((c) => (c.conversation['type'] as num?)?.toInt() == 2)
          .toList();
      if (mounted) {
        setState(() {
          _groups = groups;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(t('myGroupsTitle')),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _groups.isEmpty
              ? Center(
                  child: Text(t('myGroupsEmpty'),
                      style: TextStyle(color: context.cs.onSurfaceVariant)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _groups.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _tile(_groups[i]),
                ),
    );
  }

  Widget _tile(ConvItem g) {
    final t = AppLocalizations.of(context).t;
    return InkWell(
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ChatPage(conv: g, myId: widget.myId)));
        if (mounted) _load();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.cs.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // 群头像：优先显示群头像图，无图回落首字母（修复通讯录群聊不显示群头像）
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: g.avatarUrl.isNotEmpty
                  ? Image.network(
                      g.avatarUrl,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _letterAvatar(g),
                    )
                  : _letterAvatar(g),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(g.conversationName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: context.cs.onSurface)),
                  if (g.lastMsgPreview.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(g.lastMsgPreview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: context.cs.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                size: 18, color: context.cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  /// 无群头像时的首字母占位
  Widget _letterAvatar(ConvItem g) {
    final t = AppLocalizations.of(context).t;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
          g.conversationName.isEmpty
              ? t('myGroupsInitial')
              : g.conversationName.characters.first,
          style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
    );
  }
}
