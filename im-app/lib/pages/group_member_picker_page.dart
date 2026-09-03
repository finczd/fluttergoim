import 'package:flutter/material.dart';

import '../l10n/app_locale.dart';
import '../theme/app_theme.dart';

/// 群转账：选择收款人（单选，返回成员 Map {id, nickname, ...}）
class GroupMemberPickerPage extends StatelessWidget {
  final List<Map<String, dynamic>> members;
  final String myId;
  const GroupMemberPickerPage(
      {super.key, required this.members, required this.myId});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    final selectable =
        members.where((m) => (m['id']?.toString() ?? '') != myId).toList();
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(t('memberPickerTitle'),
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: context.cs.onSurface)),
      ),
      body: selectable.isEmpty
          ? Center(
              child: Text(t('memberPickerEmpty'),
                  style: TextStyle(
                      fontSize: 13, color: context.cs.onSurfaceVariant)))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: selectable.length,
              itemBuilder: (ctx, i) {
                final m = selectable[i];
                final id = m['id']?.toString() ?? '';
                final name =
                    (m['nickname'] ?? m['name'] ?? t('memberPickerMember'))
                        .toString();
                final avatar = (m['avatar'] ?? '').toString();
                return InkWell(
                  onTap: () => Navigator.pop(context, m),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: context.cs.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: AppTheme.avatarColors[id.hashCode.abs() %
                                AppTheme.avatarColors.length],
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          // 有头像显示真实头像，加载失败/无头像回落首字母
                          child: avatar.isNotEmpty
                              ? Image.network(
                                  avatar,
                                  width: 42,
                                  height: 42,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Text(
                                      name.characters.first,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600)),
                                )
                              : Text(name.characters.first,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(name,
                              style: TextStyle(
                                  fontSize: 15, color: context.cs.onSurface)),
                        ),
                        Icon(Icons.chevron_right,
                            size: 18, color: context.cs.onSurfaceVariant),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
