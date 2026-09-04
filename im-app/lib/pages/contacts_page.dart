import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/conversation_service.dart';
import '../services/friend_service.dart';
import '../services/user_cache.dart';
import '../services/ws_service.dart';
import '../services/friend_req_store.dart';
import '../l10n/app_locale.dart';
import '../theme/app_theme.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/official_tag.dart';
import 'add_friend_page.dart';
import 'chat_page.dart';
import 'conv_settings_page.dart';
import 'my_groups_page.dart';
import 'new_friends_page.dart';

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
  List<Map<String, dynamic>> _filteredFriends = [];
  List<FriendRequest> _requests = [];
  String _assistantAvatar = ''; // 后台配置的小助手头像（通讯录官方入口显示）
  bool _loading = true;
  bool _loadFailed = false; // 好友列表加载失败（无缓存数据时显示"重新加载"，不再误显"暂无好友"）
  bool _searching = false;
  final String _msg = '';
  String _myId = '';
  VoidCallback? _wsCancel;

  // 头像色板统一走主题，保证与其它页面一致
  static const _colors = AppTheme.avatarColors;

  @override
  void initState() {
    super.initState();
    _loadCached();
    _load();
    _loadMyId();
    _loadAssistantAvatar();
    // 需求6：被添加好友 → WS friend 事件 → 刷新申请列表（红点）
    _wsCancel = GlobalWs.instance.onFriend((_) {
      _load();
    });
    GlobalWs.instance.ensureConnected();
  }

  /// 先渲染本地缓存的好友/申请/助手头像，网络回来后覆盖刷新。
  /// 解决切到通讯录时整页菊花等待的问题。
  Future<void> _loadCached() async {
    try {
      final raw = await _api.readPref('contacts');
      if (raw != null && raw.isNotEmpty && mounted && _friends.isEmpty) {
        final data = jsonDecode(raw);
        if (data is Map) {
          setState(() {
            _friends =
                ((data['friends'] as List?) ?? []).whereType<Map>().map((e) {
              final m = <String, dynamic>{};
              e.forEach((k, v) => m[k.toString()] = v);
              return m;
            }).toList();
            _requests = ((data['requests'] as List?) ?? [])
                .whereType<Map>()
                .map(
                    (e) => FriendRequest.fromJson(Map<String, dynamic>.from(e)))
                .toList();
            _assistantAvatar = data['assistantAvatar']?.toString() ?? '';
            if (_friends.isNotEmpty || _requests.isNotEmpty) _loading = false;
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _wsCancel?.call();
    super.dispose();
  }

  Future<void> _loadMyId() async {
    // 进程内缓存命中直接用（一次登录会话只拉一次 /user/profile）
    final cached = UserCache.myId;
    if (cached != null && cached.isNotEmpty) {
      if (mounted) setState(() => _myId = cached);
      return;
    }
    try {
      final r = await _api.get('/api/v1/user/profile');
      final d = (r.data['data'] as Map<String, dynamic>?);
      UserCache.setMyProfile(d ?? {});
      final id = d?['id']?.toString() ?? '';
      if (mounted && id.isNotEmpty) setState(() => _myId = id);
    } catch (_) {}
  }

  /// 小助手头像：后台「智能小助手」配置（/auth/config 下发 assistantAvatar）
  Future<void> _loadAssistantAvatar() async {
    try {
      final r = await _api.get('/api/v1/auth/config');
      final data = (r.data as Map<String, dynamic>)['data'];
      final av =
          (data is Map ? data['assistantAvatar'] : null)?.toString() ?? '';
      if (mounted) setState(() => _assistantAvatar = av);
      await _api.writePref('assistantAvatar', av);
    } catch (_) {}
  }

  Future<void> _load() async {
    List<Map<String, dynamic>>? friends;
    try {
      friends = await _svc.list();
    } catch (_) {
      // 好友列表失败：有数据（缓存/上次结果）则保留并提示；首进无数据显示重试态
      if (mounted) {
        setState(() => _loading = false);
        if (_friends.isEmpty && _requests.isEmpty) {
          setState(() => _loadFailed = true);
        } else {
          AppDialogs.toast(
              context, AppLocalizations.of(context).t('contactsRefreshFailed'));
        }
      }
      return;
    }
    var requests = <FriendRequest>[];
    var reqFailed = false;
    try {
      requests = await _svc.incoming();
    } catch (_) {
      reqFailed = true; // 申请列表失败不拖累好友展示
    }
    if (mounted) {
      setState(() {
        _friends = friends ?? [];
        if (!reqFailed) _requests = requests;
        _loading = false;
        _loadFailed = false;
      });
      // 好友/申请/助手头像一并落缓存，下次进页首帧直出
      unawaited(_api.writePref(
          'contacts',
          jsonEncode({
            'friends': friends,
            'requests': (reqFailed ? _requests : requests)
                .map((r) => {
                      'id': r.id,
                      'fromUser': r.fromUser,
                      'message': r.message,
                      'status': r.status,
                    })
                .toList(),
            'assistantAvatar': _assistantAvatar,
          })));
    }
  }

  /// 失败态手动重试
  void _retryLoad() {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    _load();
  }

  /// 本地过滤通讯录好友（按昵称 / 账号 / 手机号）
  void _filter(String kw) {
    final q = kw.trim().toLowerCase();
    setState(() {
      _searching = q.isNotEmpty;
      if (q.isEmpty) {
        _filteredFriends = [];
        return;
      }
      _filteredFriends = _friends.where((f) {
        final name = _friendName(f).toLowerCase();
        final account = (f['account']?.toString() ?? '').toLowerCase();
        final phone = (f['phone']?.toString() ?? '').toLowerCase();
        final sid = (f['shortId']?.toString() ?? '').toLowerCase();
        return name.contains(q) ||
            account.contains(q) ||
            phone.contains(q) ||
            sid.contains(q);
      }).toList();
    });
  }

  Future<void> _handleReq(String reqId, bool agree) async {
    await _svc.handle(reqId, agree);
    await _load();
    // 审批后主动刷新全局申请数：被申请方收不到 friend.accepted WS 事件，
    // 不主动刷则底部"通讯录"tab 红点要等杀进程重进才消失
    FriendReqStore.instance.refresh();
  }

  Color _color(String id) => _colors[id.hashCode.abs() % _colors.length];

  String _friendName(Map<String, dynamic> u) {
    final r = u['remark']?.toString() ?? '';
    if (r.isNotEmpty) return r;
    return u['nickname']?.toString() ??
        u['account']?.toString() ??
        AppLocalizations.of(context).t('contactsUser');
  }

  void _goAddFriend() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AddFriendPage()));
  }

  /// 需求10：打开小助手会话（小助手虚拟 uid=-1，后端固定名"小助手"）
  Future<void> _openAssistant() async {
    try {
      final convSvc = ConversationService();
      // 先找会话列表里已存在的小助手会话
      final list = await convSvc.list();
      final assistant = list.where((c) => c.conversationName == '小助手').toList();
      if (assistant.isNotEmpty) {
        await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ChatPage(conv: assistant.first, myId: _myId)));
        return;
      }
      // 没有则创建单聊（-1 = 小助手）
      final conv = await convSvc.createDirect('-1');
      final item = ConvItem.fromJson({
        'conversation': conv,
        'conversationName': '小助手',
      });
      await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ChatPage(conv: item, myId: _myId)));
    } catch (_) {
      if (mounted)
        AppDialogs.toast(context,
            AppLocalizations.of(context).t('contactsAssistantUnavailable'));
    }
  }

  Widget _divider() =>
      Divider(height: 1, indent: 52, color: context.cs.outlineVariant);

  Widget _funcRow(
      IconData icon, String title, int count, Color color, VoidCallback onTap,
      {bool official = false, String avatarUrl = ''}) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              alignment: Alignment.center,
              // 小助手：显示后台配置的头像（加载失败回落机器人图标）
              child: avatarUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      child: Image.network(
                        avatarUrl,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Icon(icon, size: 22, color: color),
                      ),
                    )
                  : Icon(icon, size: 22, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: official
                  // 小助手等官方入口：标题后带「官方」标识
                  ? Row(
                      children: [
                        Text(title,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: context.cs.onSurface)),
                        const SizedBox(width: 6),
                        const OfficialTag(),
                      ],
                    )
                  : Text(title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: context.cs.onSurface)),
            ),
            if (count > 0)
              Container(
                margin: const EdgeInsets.only(right: 8),
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.danger,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(count > 99 ? '99+' : '$count',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            Icon(Icons.chevron_right,
                size: 18, color: context.cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶栏：标题 + 添加好友入口
            Row(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 8, 0),
                  child: Text(t('contactsTitle'),
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: context.cs.onSurface)),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    onPressed: _goAddFriend,
                    icon: Icon(Icons.person_add_alt_1,
                        size: 26, color: context.cs.onSurface),
                    splashRadius: 22,
                  ),
                ),
              ],
            ),
            // 搜索框：与首页搜索栏同款样式（surface 底色 + radiusMd 圆角、去描边、
            // 同边距/高度/图标/文字），保持实时本地过滤能力（可输入 + 清除按钮）。
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: context.cs.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search,
                        size: 20, color: context.cs.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        style: TextStyle(fontSize: 14, color: context.cs.onSurface),
                        decoration: InputDecoration(
                          hintText: t('contactsSearchHint'),
                          hintStyle: TextStyle(
                              fontSize: 14, color: context.cs.onSurface),
                          isDense: true,
                          // 关键：全局主题 inputDecorationTheme 设了 filled:true + 灰色 fillColor，
                          // 这里搜索框背景由外层 Container 提供，必须显式 opt-out 否则文字后面会有一道灰条
                          filled: false,
                          fillColor: Colors.transparent,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          suffixIcon: _searchCtrl.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: Icon(Icons.close,
                                      size: 18,
                                      color: context.cs.onSurfaceVariant),
                                  onPressed: () => setState(() {
                                    _searchCtrl.clear();
                                    _searching = false;
                                    _filteredFriends = [];
                                  }),
                                ),
                        ),
                        onChanged: _filter,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _loadFailed
                      ? _buildLoadFailed()
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                          children: [
                            // 设计稿功能区：新朋友 / 群聊 / 小助手（需求8/9/10）
                            Padding(
                              padding: EdgeInsets.zero,
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                // 微信式：卡片靠「白卡 vs 灰底」的明度差区分，不描边
                                decoration: BoxDecoration(
                                  color: context.cs.surface,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  children: [
                                    // 需求8：新朋友 → 申请记录列表（通过/拒绝）
                                    _funcRow(
                                        Icons.person_add_alt_1,
                                        t('contactsNewFriends'),
                                        _requests.length,
                                        AppTheme.orange, () async {
                                      await Navigator.of(context).push(
                                          MaterialPageRoute(
                                              builder: (_) =>
                                                  const NewFriendsPage()));
                                      if (mounted) _load();
                                      // 从新朋友页返回后同步底部 tab 红点
                                      FriendReqStore.instance.refresh();
                                    }),
                                    _divider(),
                                    // 需求9：群聊 → 我的群聊列表
                                    _funcRow(
                                        Icons.groups_rounded,
                                        t('contactsGroupChats'),
                                        0,
                                        AppTheme.green, () {
                                      Navigator.of(context).push(
                                          MaterialPageRoute(
                                              builder: (_) =>
                                                  MyGroupsPage(myId: _myId)));
                                    }),
                                    _divider(),
                                    // 需求10：系统公告 → 小助手（带官方标识 + 后台配置头像）
                                    _funcRow(
                                        Icons.smart_toy_outlined,
                                        t('contactsAssistant'),
                                        0,
                                        AppTheme.cyan,
                                        _openAssistant,
                                        official: true,
                                        avatarUrl: _assistantAvatar),
                                  ],
                                ),
                              ),
                            ),

                            if (_msg.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(_msg,
                                    style: const TextStyle(
                                        fontSize: 12, color: AppTheme.success)),
                              ),

                            if (!_searching && _requests.isNotEmpty) ...[
                              _SectionLabel(t('contactsFriendRequests',
                                  {'count': '${_requests.length}'})),
                              ..._requests.map((r) => _requestTile(r)),
                              const SizedBox(height: 8),
                            ],
                            if (_searching) ...[
                              _SectionLabel(t('contactsSearchResults',
                                  {'count': '${_filteredFriends.length}'})),
                              if (_filteredFriends.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 56),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.search_off,
                                            size: 56,
                                            color: context.cs.onSurfaceVariant
                                                .withValues(alpha: 0.5)),
                                        const SizedBox(height: 12),
                                        Text(t('contactsNoMatch'),
                                            style: TextStyle(
                                                color:
                                                    context.cs.onSurfaceVariant,
                                                fontSize: 14)),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                ..._filteredFriends.map((f) => _friendTile(f)),
                            ] else ...[
                              _SectionLabel(t('contactsFriends',
                                  {'count': '${_friends.length}'})),
                              if (_friends.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 56),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.group_outlined,
                                            size: 56,
                                            color: context.cs.onSurfaceVariant
                                                .withValues(alpha: 0.5)),
                                        const SizedBox(height: 12),
                                        Text(t('contactsEmptyFriends'),
                                            style: TextStyle(
                                                color:
                                                    context.cs.onSurfaceVariant,
                                                fontSize: 14)),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                ..._friends.map((f) => _friendTile(f)),
                            ],
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  /// 好友列表加载失败：显示"重新加载"，不再误显"暂无好友"
  Widget _buildLoadFailed() {
    final t = AppLocalizations.of(context).t;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined,
              size: 48, color: context.cs.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(t('contactsLoadFailed'),
              style:
                  TextStyle(fontSize: 14, color: context.cs.onSurfaceVariant)),
          const SizedBox(height: 14),
          TextButton(
            onPressed: _retryLoad,
            child: Text(t('contactsRetry'),
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  Widget _requestTile(FriendRequest r) {
    final t = AppLocalizations.of(context).t;
    // 优先用后端注入的申请人昵称/账号，兜底到 ID（避免只显示一串数字）
    final name = r.fromUserName.isNotEmpty
        ? r.fromUserName
        : (r.fromUserAccount.isNotEmpty
            ? r.fromUserAccount
            : t('contactsUserWithId', {'id': r.fromUser}));
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 4, 0, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.cs.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _avatarOf(name, r.fromUser, size: 42, url: r.fromUserAvatar),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: context.cs.onSurface)),
                if (r.message.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(r.message,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: context.cs.onSurfaceVariant)),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _handleReq(r.id, true),
            style: TextButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
            ),
            child:
                Text(t('contactsAgree'), style: const TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => _handleReq(r.id, false),
            style: TextButton.styleFrom(
              backgroundColor: context.cs.surfaceContainer,
              foregroundColor: context.cs.onSurfaceVariant,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
            ),
            child:
                Text(t('contactsReject'), style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  /// 统一头像：优先网络头像，失败回落到首字色块
  Widget _avatarOf(String name, String seed, {double size = 44, String? url}) {
    final color = _color(seed);
    final initial = name.isEmpty
        ? AppLocalizations.of(context).t('contactsUser').characters.first
        : name.characters.first;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: (url != null && url.isNotEmpty)
          ? Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _avatarBlock(size, color, initial),
            )
          : _avatarBlock(size, color, initial),
    );
  }

  Widget _avatarBlock(double size, Color color, String initial) {
    return Container(
      width: size,
      height: size,
      color: color,
      alignment: Alignment.center,
      child: Text(initial,
          style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
    );
  }

  Widget _friendTile(Map<String, dynamic> f) {
    final id = f['id']?.toString() ?? '';
    final name = _friendName(f);
    return InkWell(
      onTap: () async {
        // 需求：资料页统一——通讯录点开好友与聊天窗口共用 ConvSettingsPage 单聊布局
        try {
          final convSvc = ConversationService();
          final conv = await convSvc.createDirect(id);
          // createDirect 返回的会话对象不带对方头像，资料页头图会空成首字母
          // （聊天窗口路径会话列表自带 avatar 所以正常）→ 用通讯录行的好友头像兜底
          final av = f['avatar']?.toString() ?? '';
          if (av.isNotEmpty &&
              (conv['avatar'] == null || conv['avatar'].toString().isEmpty)) {
            conv['peerAvatar'] = av;
          }
          final online = f['online'] == true;
          final item = ConvItem.fromJson({
            'conversation': conv,
            'conversationName': name,
            'peerShortId': f['shortId']?.toString() ?? '',
            'peerVipShortId': f['vipShortId'] == true,
            'peerRemark': f['remark']?.toString() ?? '',
            'peerOnline': online,
            'peerOnlineDev': f['onlineDevice'] ?? [],
          });
          if (!mounted) return;
          await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ConvSettingsPage(conv: item)));
          if (mounted) _load();
        } catch (_) {
          if (mounted)
            AppDialogs.toast(context,
                AppLocalizations.of(context).t('contactsOpenProfileFailed'));
        }
      },
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        margin: const EdgeInsets.fromLTRB(0, 4, 0, 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.cs.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Row(
          children: [
            _avatarOf(name, id, url: f['avatar']?.toString()),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: context.cs.onSurface)),
                  const SizedBox(height: 2),
                  Text(f['account']?.toString() ?? 'ID $id',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, color: context.cs.onSurfaceVariant)),
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
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
      child: Text(text,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.cs.onSurfaceVariant)),
    );
  }
}
