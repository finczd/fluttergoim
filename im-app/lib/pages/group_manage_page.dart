import 'package:flutter/material.dart';

import '../l10n/app_locale.dart';
import '../services/conversation_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_dialogs.dart';
import 'group_members_page.dart';

/// 群聊管理页（仅群主入口）：
/// - 四个群设置开关：二维码进群 / 成员隐私 / 全员禁言 / 允许成员邀请
/// - 群管理员：查看 + 添加/移除
/// - 群二维码：展示入群二维码（需开启"二维码进群"才可被扫码加入）
class GroupManagePage extends StatefulWidget {
  final ConvItem conv;
  const GroupManagePage({super.key, required this.conv});

  @override
  State<GroupManagePage> createState() => _GroupManagePageState();
}

class _GroupManagePageState extends State<GroupManagePage> {
  final _svc = ConversationService();
  Map<String, dynamic> _settings = {};
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await _svc.groupSettings(widget.conv.id);
      final m = await _svc.members(widget.conv.id);
      if (mounted) {
        setState(() {
          _settings = s;
          _members = m;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(String key, bool v) async {
    if (_saving) return;
    final t = AppLocalizations.of(context).t;
    setState(() {
      _settings = {..._settings, key: v}; // 乐观更新
      _saving = true;
    });
    try {
      switch (key) {
        case 'muteAll':
          await _svc.setGroupSettings(widget.conv.id, muteAll: v);
        case 'privacyEnabled':
          await _svc.setGroupSettings(widget.conv.id, privacyEnabled: v);
        case 'allowMemberInvite':
          await _svc.setGroupSettings(widget.conv.id, allowInvite: v);
        case 'qrJoinEnabled':
          await _svc.setGroupSettings(widget.conv.id, qrJoin: v);
      }
      if (mounted) AppDialogs.toast(context, t('groupSettingsSaved'));
    } catch (_) {
      if (mounted) {
        setState(() => _settings = {..._settings, key: !v}); // 失败回滚
        AppDialogs.toast(context, t('groupSettingsSaveFailed'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 添加管理员：从普通成员中单选
  Future<void> _addAdmin() async {
    final t = AppLocalizations.of(context).t;
    final candidates =
        _members.where((m) => (m['role'] as num?)?.toInt() == 3).toList();
    if (candidates.isEmpty) {
      AppDialogs.toast(context, t('groupNoAdminCandidate'));
      return;
    }
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: ctx.cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(t('groupAddAdminPick'),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: candidates.length,
                itemBuilder: (_, i) {
                  final m = candidates[i];
                  final name = m['nickname']?.toString() ??
                      m['account']?.toString() ??
                      '';
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: AppTheme.avatarColors[
                          (m['id']?.toString() ?? '').hashCode.abs() %
                              AppTheme.avatarColors.length],
                      child: Text(name.isEmpty ? '?' : name.characters.first,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ),
                    title: Text(name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => Navigator.of(ctx).pop(m),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    try {
      await _svc.setGroupAdmin(
          widget.conv.id, picked['id']?.toString() ?? '', true);
      if (mounted) {
        AppDialogs.toast(context, t('groupSetAdminSuccess'));
        _load();
      }
    } catch (_) {
      if (mounted) AppDialogs.toast(context, t('groupSetAdminFailed'));
    }
  }

  Future<void> _removeAdmin(Map<String, dynamic> m) async {
    final t = AppLocalizations.of(context).t;
    try {
      await _svc.setGroupAdmin(
          widget.conv.id, m['id']?.toString() ?? '', false);
      if (mounted) {
        AppDialogs.toast(context, t('groupUnsetAdminSuccess'));
        _load();
      }
    } catch (_) {
      if (mounted) AppDialogs.toast(context, t('groupSetAdminFailed'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    final admins =
        _members.where((m) => (m['role'] as num?)?.toInt() == 2).toList();
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(t('groupManageTitle'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _card(Column(
                  children: [
                    _switchRow(
                        t('groupSwitchQrJoin'),
                        t('groupSwitchQrJoinSub'),
                        _settings['qrJoinEnabled'] == true,
                        (v) => _toggle('qrJoinEnabled', v)),
                    _divider(),
                    _switchRow(
                        t('groupSwitchPrivacy'),
                        t('groupSwitchPrivacySub'),
                        _settings['privacyEnabled'] == true,
                        (v) => _toggle('privacyEnabled', v)),
                    _divider(),
                    _switchRow(
                        t('groupSwitchMuteAll'),
                        t('groupSwitchMuteAllSub'),
                        _settings['muteAll'] == true,
                        (v) => _toggle('muteAll', v)),
                    _divider(),
                    _switchRow(
                        t('groupSwitchAllowInvite'),
                        t('groupSwitchAllowInviteSub'),
                        _settings['allowMemberInvite'] == true,
                        (v) => _toggle('allowMemberInvite', v)),
                  ],
                )),
                const SizedBox(height: 12),
                _sectionHeader(t('groupAdminsSection')),
                _card(Column(
                  children: [
                    for (var i = 0; i < admins.length; i++) ...[
                      if (i > 0) _divider(),
                      _adminRow(admins[i]),
                    ],
                    _divider(),
                    ListTile(
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor:
                            AppTheme.primary.withValues(alpha: 0.12),
                        child: Icon(Icons.person_add_alt_1,
                            size: 20, color: AppTheme.primary),
                      ),
                      title: Text(t('groupAddAdmin'),
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: context.cs.onSurface)),
                      onTap: _addAdmin,
                    ),
                  ],
                )),
                const SizedBox(height: 12),
                _sectionHeader(t('convSetGroupMembers')),
                _card(ListTile(
                  leading: Icon(Icons.group_outlined,
                      size: 24, color: AppTheme.primary),
                  title: Text(t('groupMembersManageEntry'),
                      style:
                          TextStyle(fontSize: 15, color: context.cs.onSurface)),
                  trailing: Icon(Icons.chevron_right,
                      size: 18, color: context.cs.onSurfaceVariant),
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => GroupMembersPage(conv: widget.conv)));
                    if (mounted) _load();
                  },
                )),
              ],
            ),
    );
  }

  Widget _adminRow(Map<String, dynamic> m) {
    final t = AppLocalizations.of(context).t;
    final name = m['nickname']?.toString() ??
        m['account']?.toString() ??
        t('contactsUser');
    final uid = m['id']?.toString() ?? '';
    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: AppTheme
            .avatarColors[uid.hashCode.abs() % AppTheme.avatarColors.length],
        child: Text(name.isEmpty ? '?' : name.characters.first,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
      ),
      title: Text(name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 15, color: context.cs.onSurface)),
      trailing: TextButton(
        onPressed: () => _removeAdmin(m),
        style: TextButton.styleFrom(
          foregroundColor: AppTheme.danger,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child:
            Text(t('groupRemoveAdmin'), style: const TextStyle(fontSize: 13)),
      ),
    );
  }

  Widget _card(Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: context.cs.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
      child: Text(title,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.cs.onSurface)),
    );
  }

  Widget _divider() {
    return Divider(
        height: 1, indent: 16, endIndent: 16, color: context.cs.outlineVariant);
  }

  Widget _switchRow(
      String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Text(title,
                    style:
                        TextStyle(fontSize: 15, color: context.cs.onSurface)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12, color: context.cs.onSurfaceVariant)),
                const SizedBox(height: 6),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
