import 'package:flutter/material.dart';

import '../services/conversation_service.dart';
import '../services/friend_service.dart';
import '../theme/app_theme.dart';
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
  String get _name => f['nickname']?.toString() ?? f['account']?.toString() ?? '用户';

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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('无法开始会话：$e')));
      }
    }
  }

  Future<void> _setRemark() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('设置备注'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: '备注名')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.of(context).pop(ctrl.text.trim()), child: const Text('保存')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      // 后端 remark 接口（PUT /friend/:id/remark）暂未接入 UI 展示，仅调用
      final ok = await _svc.setRemark(_id, result);
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('备注已保存')));
      }
    }
  }

  Future<void> _delete() async {
    final ok = await _svc.delete(_id);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已删除好友')));
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _block() async {
    final ok = await _svc.blacklistAdd(_id);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已拉黑（同时解除好友）')));
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('好友详情')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 头部资料
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.divider)),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppTheme.primary,
                  child: Text(_name.characters.first,
                      style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 10),
                Text(_name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(f['account']?.toString() ?? '', style: const TextStyle(fontSize: 13, color: AppTheme.textTertiary)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.divider)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.chat_bubble_outline, color: AppTheme.primary),
                  title: const Text('发消息', style: TextStyle(fontSize: 15)),
                  trailing: const Icon(Icons.chevron_right, size: 18, color: AppTheme.textTertiary),
                  onTap: _sendMsg,
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: AppTheme.textSecondary),
                  title: const Text('设置备注', style: TextStyle(fontSize: 15)),
                  trailing: const Icon(Icons.chevron_right, size: 18, color: AppTheme.textTertiary),
                  onTap: _setRemark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('删除好友'),
                content: const Text('删除后将从双方好友列表移除。'),
                actions: [
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
                  TextButton(onPressed: () {
                    Navigator.of(context).pop();
                    _delete();
                  }, child: const Text('删除', style: TextStyle(color: AppTheme.danger))),
                ],
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.danger,
              side: const BorderSide(color: AppTheme.divider),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('删除好友'),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('加入黑名单'),
                content: const Text('拉黑后将无法收到对方消息，同时解除好友关系。'),
                actions: [
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
                  TextButton(onPressed: () {
                    Navigator.of(context).pop();
                    _block();
                  }, child: const Text('拉黑', style: TextStyle(color: AppTheme.danger))),
                ],
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.danger,
              side: const BorderSide(color: AppTheme.divider),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('加入黑名单'),
          ),
        ],
      ),
    );
  }
}
