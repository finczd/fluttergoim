import 'package:flutter/material.dart';

import '../services/conversation_service.dart';
import '../theme/app_theme.dart';

/// 会话设置：置顶 / 免打扰 / 群公告 / 群置顶消息 / 群成员 / 退出或解散
class ConvSettingsPage extends StatefulWidget {
  final ConvItem conv;
  const ConvSettingsPage({super.key, required this.conv});

  @override
  State<ConvSettingsPage> createState() => _ConvSettingsPageState();
}

class _ConvSettingsPageState extends State<ConvSettingsPage> {
  final _svc = ConversationService();
  bool _pinned = false;
  bool _mute = false;
  List<Map<String, dynamic>> _members = [];

  bool get isGroup => (widget.conv.conversation['type'] as num?)?.toInt() == 2;

  String get _announcement =>
      widget.conv.conversation['announcementZh']?.toString() ?? '';
  String get _pinnedContent =>
      widget.conv.conversation['pinnedMsgContent']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _pinned = widget.conv.pinned;
    _mute = widget.conv.mute;
    if (isGroup) _loadMembers();
  }

  Future<void> _loadMembers() async {
    final list = await _svc.members(widget.conv.id);
    if (mounted) setState(() => _members = list);
  }

  Future<void> _togglePin(bool v) async {
    final ok = await _svc.setPin(widget.conv.id, v);
    if (ok && mounted) setState(() => _pinned = v);
  }

  Future<void> _toggleMute(bool v) async {
    final ok = await _svc.setMute(widget.conv.id, v);
    if (ok && mounted) setState(() => _mute = v);
  }

  Future<void> _exit() async {
    // 群聊退出 / 单聊删除会话（后端 quit 均移除自己的成员记录）
    final ok = await _svc.quit(widget.conv.id);
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _disband() async {
    final ok = await _svc.disband(widget.conv.id);
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  void _editAnnouncement() {
    showDialog(
      context: context,
      builder: (_) {
        final ctrl = TextEditingController(text: _announcement);
        return AlertDialog(
          title: const Text('查看 / 编辑群公告'),
          content: TextField(
            controller: ctrl,
            maxLines: 4,
            maxLength: 200,
            decoration: const InputDecoration(hintText: '公告内容（群主/管理员可编辑）'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final ok = await _svc.updateAnnouncement(widget.conv.id, ctrl.text.trim(), '');
                if (ok && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('公告已保存')));
                  Navigator.of(context).pop(true);
                }
              },
              child: const Text('保存', style: TextStyle(color: AppTheme.primary)),
            ),
          ],
        );
      },
    );
  }

  void _showMembers() {
    showDialog(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('群成员'),
        children: [
          if (_members.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('暂无成员', textAlign: TextAlign.center),
            )
          else
            ..._members.map((m) => SimpleDialogOption(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppTheme.primary,
                        child: Text(
                          (m['nickname']?.toString() ?? '?').characters.first,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(m['nickname']?.toString() ?? m['account']?.toString() ?? ''),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text(widget.conv.conversationName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card([
            SwitchListTile(
              value: _pinned,
              onChanged: _togglePin,
              title: const Text('置顶会话', style: TextStyle(fontSize: 15)),
              activeColor: AppTheme.primary,
            ),
            SwitchListTile(
              value: _mute,
              onChanged: _toggleMute,
              title: const Text('消息免打扰', style: TextStyle(fontSize: 15)),
              activeColor: AppTheme.primary,
            ),
          ]),
          if (isGroup) ...[
            const SizedBox(height: 12),
            _card([
              ListTile(
                leading: const Icon(Icons.group_outlined, color: AppTheme.textSecondary),
                title: Text('群成员 (${_members.length})', style: const TextStyle(fontSize: 15)),
                trailing: const Icon(Icons.chevron_right, size: 18, color: AppTheme.textTertiary),
                onTap: _showMembers,
              ),
            ]),
            const SizedBox(height: 12),
            _card([
              ListTile(
                leading: const Icon(Icons.campaign_outlined, color: AppTheme.textSecondary),
                title: const Text('群公告', style: TextStyle(fontSize: 15)),
                subtitle: Text(
                  _announcement.isNotEmpty ? _announcement : '暂无公告',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textTertiary),
                ),
                trailing: const Icon(Icons.chevron_right, size: 18, color: AppTheme.textTertiary),
                onTap: _editAnnouncement,
              ),
            ]),
            const SizedBox(height: 12),
            _card([
              ListTile(
                leading: const Icon(Icons.push_pin_outlined, color: AppTheme.textSecondary),
                title: const Text('置顶消息', style: TextStyle(fontSize: 15)),
                subtitle: Text(
                  _pinnedContent.isNotEmpty ? _pinnedContent : '暂无置顶消息（聊天中长按消息可置顶）',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textTertiary),
                ),
              ),
            ]),
          ],
          const SizedBox(height: 24),
          if (isGroup)
            FilledButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('解散群聊'),
                  content: const Text('解散后所有成员将无法再进入该群，确定解散吗？'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _disband();
                      },
                      child: const Text('解散', style: TextStyle(color: AppTheme.danger)),
                    ),
                  ],
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.danger,
                side: const BorderSide(color: AppTheme.divider),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('解散群聊'),
            )
          else
            FilledButton(
              onPressed: _exit,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.danger,
                side: const BorderSide(color: AppTheme.divider),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('删除会话'),
            ),
        ],
      ),
    );
  }

  Widget _card(List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(children: rows),
    );
  }
}
