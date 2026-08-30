import 'dart:async';

import 'package:flutter/material.dart';

import '../services/friend_service.dart';
import '../theme/app_theme.dart';

/// 添加好友：搜索用户 + 发送申请
class AddFriendPage extends StatefulWidget {
  const AddFriendPage({super.key});

  @override
  State<AddFriendPage> createState() => _AddFriendPageState();
}

class _AddFriendPageState extends State<AddFriendPage> {
  final _kw = TextEditingController();
  final _svc = FriendService();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _kw.dispose();
    super.dispose();
  }

  void _onChange(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _doSearch(v));
  }

  Future<void> _doSearch(String kw) async {
    if (kw.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);
    try {
      final r = await _svc.search(kw.trim());
      if (mounted) setState(() => _results = r);
    } catch (e) {
      if (mounted) setState(() => _results = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _request(Map<String, dynamic> u) async {
    final msgCtl = TextEditingController(text: '你好，我是 ChatPulse 用户，希望能加你为好友');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加好友'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('向 ${u['nickname'] ?? u['account'] ?? '用户'} 发送好友申请',
                style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: msgCtl,
              maxLines: 3,
              maxLength: 100,
              decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: '验证消息',
                  isDense: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('发送'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final sent = await _svc.request(u['id']?.toString() ?? '', message: msgCtl.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(sent ? '申请已发送' : '发送失败（可能已是好友）')));
      if (sent) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('添加好友'),
        backgroundColor: AppTheme.background,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _kw,
              onChanged: _onChange,
              decoration: AppTheme.authInput(
                  hint: '输入账号 / 昵称 / 手机号 / 邮箱', icon: Icons.search),
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_search_outlined,
                            size: 64, color: AppTheme.textTertiary),
                        const SizedBox(height: 12),
                        Text(_kw.text.isEmpty ? '输入关键字搜索用户' : '未找到相关用户',
                            style: const TextStyle(
                                color: AppTheme.textTertiary, fontSize: 14)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const Divider(
                        height: 1, indent: 76, endIndent: 16, color: AppTheme.divider),
                    itemBuilder: (_, i) {
                      final u = _results[i];
                      final name = (u['nickname'] ?? u['account'] ?? '用户').toString();
                      return ListTile(
                        onTap: () => _request(u),
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primary,
                          child: Text(
                              name.isEmpty ? '?' : name.characters.first,
                              style: const TextStyle(color: Colors.white)),
                        ),
                        title: Text(name,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w500)),
                        subtitle: Text(
                            (u['account'] ?? u['email'] ?? u['phone'] ?? '').toString(),
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textTertiary)),
                        trailing: const Icon(Icons.person_add_alt_1,
                            color: AppTheme.primary, size: 20),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
