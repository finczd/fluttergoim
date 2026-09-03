import 'dart:async';

import 'package:flutter/material.dart';

import '../services/friend_service.dart';
import '../l10n/app_locale.dart';
import '../theme/app_theme.dart';
import '../widgets/app_dialogs.dart';

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
    final t = AppLocalizations.of(context).t;
    final name =
        (u['nickname'] ?? u['account'] ?? t('addFriendUser')).toString();
    final msg = await AppDialogs.input(
      context,
      title: t('addFriendTitle'),
      hint: t('addFriendMsgHint', {'name': name}),
      initialValue: t('addFriendDefaultMsg'),
      maxLines: 3,
      maxLength: 100,
      confirmText: t('addFriendSend'),
    );
    if (msg == null) return;
    final sent = await _svc.request(u['id']?.toString() ?? '', message: msg);
    if (mounted) {
      AppDialogs.toast(
          context, sent ? t('addFriendSent') : t('addFriendSendFailed'));
      if (sent) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(t('addFriendTitle')),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                  hint: t('addFriendSearchHint'), icon: Icons.search),
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
                            size: 64, color: context.cs.onSurfaceVariant),
                        const SizedBox(height: 12),
                        Text(
                            _kw.text.isEmpty
                                ? t('addFriendInputKeyword')
                                : t('addFriendNoUser'),
                            style: TextStyle(
                                color: context.cs.onSurfaceVariant,
                                fontSize: 14)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => Divider(
                        height: 1,
                        indent: 76,
                        endIndent: 16,
                        color: context.cs.outlineVariant),
                    itemBuilder: (_, i) {
                      final u = _results[i];
                      final name =
                          (u['nickname'] ?? u['account'] ?? t('addFriendUser'))
                              .toString();
                      final avatar = (u['avatar'] ?? '').toString();
                      return ListTile(
                        onTap: () => _request(u),
                        // 需求8：搜索结果显示用户头像（无头像回退首字母）
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primary,
                          backgroundImage:
                              avatar.isNotEmpty ? NetworkImage(avatar) : null,
                          child: avatar.isEmpty
                              ? Text(name.isEmpty ? '?' : name.characters.first,
                                  style: const TextStyle(color: Colors.white))
                              : null,
                        ),
                        title: Text(name,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w500)),
                        subtitle: Text(
                            (u['account'] ?? u['email'] ?? u['phone'] ?? '')
                                .toString(),
                            style: TextStyle(
                                fontSize: 12,
                                color: context.cs.onSurfaceVariant)),
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
