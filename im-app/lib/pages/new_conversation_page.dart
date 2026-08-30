import 'package:flutter/material.dart';

import '../services/conversation_service.dart';
import '../services/friend_service.dart';
import '../theme/app_theme.dart';
import 'chat_page.dart';

/// 新建会话/建群：
/// 1. 选择联系人（多选 1 人=单聊/多人=建群）
/// 2. 多人时填群名
/// 3. 创建后进入聊天
class NewConversationPage extends StatefulWidget {
  final String myId;
  const NewConversationPage({super.key, required this.myId});

  @override
  State<NewConversationPage> createState() => _NewConversationPageState();
}

class _NewConversationPageState extends State<NewConversationPage> {
  final _svc = FriendService();
  final _convSvc = ConversationService();
  final _nameCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _friends = [];
  final Set<String> _selected = {};
  bool _loading = true;
  bool _showGroupName = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final friends = await _svc.list();
      if (mounted) {
        setState(() {
          _friends = friends;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _name(Map<String, dynamic> u) =>
      (u['nickname'] ?? u['account'] ?? '用户').toString();
  String _sub(Map<String, dynamic> u) =>
      (u['account'] ?? u['email'] ?? u['phone'] ?? '').toString();

  Future<void> _next() async {
    if (_selected.length == 1) {
      // 单聊：标题显示好友昵称
      final friend =
          _friends.firstWhere((u) => (u['id']?.toString()) == _selected.first);
      try {
        final conv = await _convSvc.createDirect(_selected.first);
        _openChat(conv, _name(friend));
      } catch (e) {
        if (mounted) _toast('创建失败：${e.toString().replaceFirst('Exception: ', '')}');
      }
    } else {
      setState(() => _showGroupName = true);
    }
  }

  Future<void> _createGroup() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _toast('请输入群名称');
      return;
    }
    try {
      final conv = await _convSvc.createGroup(name, _selected.toList());
      _openChat(conv, name);
    } catch (e) {
      if (mounted) _toast('创建失败：${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  void _openChat(Map<String, dynamic> conv, String title) {
    if (!mounted) return;
    final item = ConvItem.fromJson({'conversation': conv, 'conversationName': title});
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ChatPage(conv: item, myId: widget.myId)));
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (_showGroupName) return _buildGroupNamePage();
    return _buildPickPage();
  }

  Widget _buildPickPage() {
    final q = _searchCtrl.text.toLowerCase();
    final filtered = q.isEmpty
        ? _friends
        : _friends.where((u) =>
            (_name(u) + ' ' + _sub(u)).toLowerCase().contains(q)).toList();
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('选择联系人'),
        actions: [
          TextButton(
            onPressed: _selected.isEmpty ? null : _next,
            child: Text('确定(${_selected.length})',
                style: TextStyle(
                    fontSize: 15,
                    color: _selected.isEmpty
                        ? AppTheme.textTertiary
                        : AppTheme.primary,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: AppTheme.authInput(hint: '搜索联系人', icon: Icons.search),
            ),
          ),
          if (_loading)
            const LinearProgressIndicator(minHeight: 2)
          else
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text('暂无联系人',
                          style: TextStyle(color: AppTheme.textTertiary)))
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(
                          height: 1, indent: 68, endIndent: 16, color: AppTheme.divider),
                      itemBuilder: (_, i) {
                        final u = filtered[i];
                        final id = (u['id'] ?? '').toString();
                        final selected = _selected.contains(id);
                        final name = _name(u);
                        return ListTile(
                          onTap: () => setState(() {
                            selected ? _selected.remove(id) : _selected.add(id);
                          }),
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primary,
                            child: Text(
                                name.isEmpty ? '?' : name.characters.first,
                                style: const TextStyle(color: Colors.white)),
                          ),
                          title: Text(name,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w500)),
                          subtitle: _sub(u).isEmpty
                              ? null
                              : Text(_sub(u),
                                  style: const TextStyle(
                                      fontSize: 12, color: AppTheme.textTertiary)),
                          trailing: Icon(
                            selected
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: selected
                                ? AppTheme.primary
                                : AppTheme.textTertiary,
                            size: 22,
                          ),
                        );
                      },
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildGroupNamePage() {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('群信息'),
        leading: IconButton(
          onPressed: () => setState(() => _showGroupName = false),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          TextButton(
            onPressed: _createGroup,
            child: const Text('创建',
                style: TextStyle(
                    fontSize: 15,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              maxLength: 30,
              decoration: AppTheme.authInput(hint: '群名称', icon: Icons.group),
            ),
            const SizedBox(height: 12),
            Text('已选 ${_selected.length} 位成员',
                style:
                    const TextStyle(fontSize: 13, color: AppTheme.textTertiary)),
          ],
        ),
      ),
    );
  }
}
