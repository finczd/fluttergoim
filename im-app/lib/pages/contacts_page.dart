import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/friend_service.dart';
import '../theme/app_theme.dart';
import 'friend_detail_page.dart';

/// 通讯录：好友列表 + 搜索添加 + 收到的申请
class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  final _svc = FriendService();
  final _api = ApiClient.instance;
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _searchResult = [];
  List<FriendRequest> _requests = [];
  bool _loading = true;
  String _msg = '';
  String _myId = '';

  static const _colors = [Color(0xFF4E8CFF), Color(0xFF7B61FF), Color(0xFFFF7D00), Color(0xFF00B42A), Color(0xFFF53F3F), Color(0xFF14C9C9)];

  @override
  void initState() {
    super.initState();
    _load();
    _loadMyId();
  }

  Future<void> _loadMyId() async {
    try {
      final r = await _api.get('/api/v1/user/profile');
      final id = ((r.data['data'] as Map<String, dynamic>)['id'])?.toString() ?? '';
      if (mounted && id.isNotEmpty) setState(() => _myId = id);
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      final friends = await _svc.list();
      final requests = await _svc.incoming();
      if (mounted) setState(() {
        _friends = friends;
        _requests = requests;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _search(String kw) async {
    if (kw.trim().isEmpty) return;
    final result = await _svc.search(kw.trim());
    setState(() => _searchResult = result);
  }

  Future<void> _addFriend(String toId) async {
    final ok = await _svc.request(toId);
    setState(() => _msg = ok ? '申请已发送' : '发送失败（可能已是好友或已申请）');
  }

  Future<void> _handleReq(String reqId, bool agree) async {
    await _svc.handle(reqId, agree);
    await _load();
  }

  Color _color(String id) => _colors[id.hashCode.abs() % _colors.length];

  String _friendName(Map<String, dynamic> u) => u['nickname']?.toString() ?? u['account']?.toString() ?? '用户';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceContainerLow,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text('通讯录',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.primary)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: '搜索昵称 / 账号 / 手机号',
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.textTertiary),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                ),
                onSubmitted: _search,
              ),
            ),
            if (_msg.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: Text(_msg, style: const TextStyle(fontSize: 12, color: AppTheme.success)),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (_requests.isNotEmpty) ...[
                          _SectionLabel('好友申请 (${_requests.length})'),
                          ..._requests.map((r) => _requestTile(r)),
                          const SizedBox(height: 8),
                        ],
                        if (_searchResult.isNotEmpty) ...[
                          const _SectionLabel('搜索结果'),
                          ..._searchResult.map((u) => _searchTile(u)),
                          const SizedBox(height: 8),
                        ],
                        const _SectionLabel('好友'),
                        if (_friends.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 40),
                            child: Center(
                                child: Text('暂无好友，搜索添加吧', style: TextStyle(color: AppTheme.textTertiary))),
                          )
                        else
                          ..._friends.map((f) => _friendTile(f)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _requestTile(FriendRequest r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 18, backgroundColor: _color(r.fromUser), child: Text('友', style: const TextStyle(color: Colors.white, fontSize: 13))),
          const SizedBox(width: 10),
          Expanded(child: Text('用户 #${r.fromUser}', style: const TextStyle(fontSize: 14))),
          if (r.message.isNotEmpty)
            Expanded(child: Text(r.message, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary))),
          TextButton(onPressed: () => _handleReq(r.id, true), child: const Text('同意', style: TextStyle(color: AppTheme.primary))),
          TextButton(onPressed: () => _handleReq(r.id, false), child: const Text('拒绝', style: TextStyle(color: AppTheme.danger))),
        ],
      ),
    );
  }

  Widget _searchTile(Map<String, dynamic> u) {
    final id = u['id']?.toString() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 18, backgroundColor: _color(id), child: Text(_friendName(u).characters.first, style: const TextStyle(color: Colors.white, fontSize: 13))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_friendName(u), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                Text(u['email']?.toString() ?? u['account']?.toString() ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary)),
              ],
            ),
          ),
          FilledButton.tonal(onPressed: () => _addFriend(id), child: const Text('添加')),
        ],
      ),
    );
  }

  Widget _friendTile(Map<String, dynamic> f) {
    final id = f['id']?.toString() ?? '';
    return InkWell(
      onTap: () async {
        // 好友详情页，返回后刷新列表
        await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => FriendDetailPage(friend: f, myId: _myId)));
        if (mounted) _load();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            CircleAvatar(radius: 18, backgroundColor: _color(id), child: Text(_friendName(f).characters.first, style: const TextStyle(color: Colors.white, fontSize: 13))),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_friendName(f), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  Text(f['email']?.toString() ?? f['account']?.toString() ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppTheme.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
      child: Text(text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textTertiary)),
    );
  }
}
