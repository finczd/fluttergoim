import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/call_service.dart';
import '../services/conversation_service.dart';
import '../services/local_notify_service.dart';
import '../services/local_store.dart';
import '../services/sound_service.dart';
import '../services/unread_store.dart';
import '../services/user_cache.dart';
import '../services/ws_service.dart';
import '../l10n/app_locale.dart';
import '../theme/app_theme.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_slidable.dart';
import '../widgets/official_tag.dart';
import '../widgets/page_header.dart';
import 'add_friend_page.dart';
import 'chat_page.dart';
import 'new_conversation_page.dart';
import 'scan_qr_login_page.dart';
import 'search_page.dart';

/// 会话列表页（对齐 Aura Messaging 设计稿图 3/4）
/// 顶栏标题 + +号 / surface 搜索栏 / 蓝色公告横幅 / 会话项 / 底栏 4 Tab
class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final _svc = ConversationService();
  final _api = ApiClient.instance;
  List<ConvItem> _convs = [];
  List<dynamic> _convRaw = [];
  bool _loading = true;
  bool _loadFailed = false;
  String _myId = '';
  String _announcementText = '';
  String _dismissedAnnouncement = '';
  VoidCallback? _wsCancel;
  Timer? _convSyncTimer;
  String _openConvId = '';
  void Function(String key)? _corruptSub;

  /// ========== 侧滑菜单显式关闭 ==========
  /// 每个会话一个 GlobalKey：侧滑状态跟随会话身份移动（列表重排不会错配到别的行），
  /// 置顶/免打扰等操作完成后经 currentState?.close() 显式收起菜单。
  final Map<String, GlobalKey<AppSlidableState>> _slideKeys = {};

  @override
  void initState() {
    super.initState();
    _loadCached();
    _load();
    _corruptSub = (key) {
      if (key == 'conv_list' && mounted) _load();
    };
    LocalStore.addCorruptListener(_corruptSub!);
    _loadMyId();
    _loadAnnouncement();
    _loadDismissedAnnouncement();
    _wsCancel = GlobalWs.instance.onMessage((m) {
      _applyIncomingMessage(m);
      final type = (m['type'] as num?)?.toInt();
      final senderId = m['senderId']?.toString() ?? '';
      if (type == 1 &&
          senderId.isNotEmpty &&
          senderId != _myId &&
          CallService.instance.state.value == null) {
        SoundService.instance.playNewMessage();
      }
      _maybeLocalNotify(m);
    });
    GlobalWs.instance.onRecall((_) => _load());
    GlobalWs.instance.ensureConnected();
  }

  @override
  void dispose() {
    _wsCancel?.call();
    _convSyncTimer?.cancel();
    if (_corruptSub != null) LocalStore.removeCorruptListener(_corruptSub!);
    super.dispose();
  }

  Future<void> _loadAnnouncement() async {
    try {
      final cached = await _api.readPref('announcement');
      if (cached != null && cached.isNotEmpty && mounted) {
        setState(() => _announcementText = cached);
      }
    } catch (_) {}
    try {
      final r = await _api.get('/api/v1/auth/config');
      final data = (r.data as Map<String, dynamic>)['data'];
      final text = (data is Map && data['announcement'] != null)
          ? data['announcement'].toString()
          : '';
      if (mounted) setState(() => _announcementText = text);
      unawaited(_api.writePref('announcement', text));
    } catch (_) {}
  }

  Future<void> _loadDismissedAnnouncement() async {
    try {
      final v = await _api.readPref('dismissed_announcement') ?? '';
      if (mounted) setState(() => _dismissedAnnouncement = v);
    } catch (_) {}
  }

  Future<void> _loadMyId() async {
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

  Future<void> _loadCached() async {
    try {
      if (!mounted || _convs.isNotEmpty) return;
      var data = await LocalStore.loadConvList();
      if (data == null || data.isEmpty) {
        final raw = await _api.readPref('convList');
        if (raw == null || raw.isEmpty) return;
        if (!mounted) return;
        try {
          final decoded = jsonDecode(raw);
          data = decoded is List ? decoded : null;
        } catch (_) {
          data = null;
        }
      }
      if (data == null || data.isEmpty || !mounted) return;
      _applyRawList(data);
    } catch (_) {}
  }

  void _applyRawList(List<dynamic> data) {
    setState(() {
      _convRaw = List<dynamic>.from(data);
      _convs = _convRaw
          .whereType<Map>()
          .map((e) => ConvItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      _loading = false;
    });
  }

  Future<void> _load() async {
    try {
      final list = await _svc.list();
      UnreadStore.instance
          .update(list.fold<int>(0, (sum, c) => sum + (c.mute ? 0 : c.unread)));
      if (mounted) {
        setState(() {
          _convs = list;
          _convRaw = List<dynamic>.from(_svc.lastConvRaw);
          // ✅ 移除了 _listRev++：不再强制重建所有行
          // 置顶/免打扰操作已改为局部更新，不需要全局 key 变化
          _loading = false;
        });
      }
      unawaited(LocalStore.saveConvList(_convRaw));
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = _convs.isEmpty;
        });
      }
    }
  }

  /// P0-3：WS 新消息增量更新会话列表。
  void _applyIncomingMessage(Map<String, dynamic> m) {
    if (!mounted || _convs.isEmpty || _convRaw.isEmpty) {
      _load();
      return;
    }
    final convId = m['conversationId']?.toString() ?? '';
    if (convId.isEmpty) {
      _load();
      return;
    }
    if (convId == _openConvId) return;
    final type = (m['type'] as num?)?.toInt() ?? 1;
    if (type == 6 || type == 7) {
      _load();
      return;
    }
    final idx = _convs.indexWhere((c) => c.id == convId);
    if (idx < 0 || idx >= _convRaw.length) {
      _load();
      return;
    }
    final raw = Map<String, dynamic>.from(_convRaw[idx] as Map);
    final senderId = m['senderId']?.toString() ?? '';
    final mine = senderId.isNotEmpty && senderId == _myId;
    raw['lastMessage'] = m;
    if (!mine) {
      final old = (raw['unread'] as num?)?.toInt() ?? 0;
      raw['unread'] = old + 1;
    }
    final item = ConvItem.fromJson(raw);

    final list = List<ConvItem>.from(_convs);
    final raws = List<dynamic>.from(_convRaw);
    list.removeAt(idx);
    raws.removeAt(idx);
    var target = 0;
    if (!item.pinned) {
      while (target < list.length && list[target].pinned) {
        target++;
      }
    }
    list.insert(target, item);
    raws.insert(target, raw);

    setState(() {
      _convs = list;
      _convRaw = raws;
    });
    UnreadStore.instance
        .update(list.fold<int>(0, (sum, c) => sum + (c.mute ? 0 : c.unread)));
    _convSyncTimer?.cancel();
    _convSyncTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) _load();
    });
  }

  void _maybeLocalNotify(Map<String, dynamic> m) {
    final state = WidgetsBinding.instance.lifecycleState;
    if (state == AppLifecycleState.resumed) return;
    final type = (m['type'] as num?)?.toInt();
    final senderId = m['senderId']?.toString() ?? '';
    if (type != 1 || senderId.isEmpty || senderId == _myId) return;
    if (CallService.instance.state.value != null) return;
    final convId = m['conversationId']?.toString() ?? '';
    ConvItem? conv;
    for (final c in _convs) {
      if (c.id == convId) {
        conv = c;
        break;
      }
    }
    if (conv != null && conv.mute) return;
    final title = (conv?.conversationName ?? '').isNotEmpty
        ? conv!.conversationName
        : '新消息';
    final body = (conv?.lastMsgPreview ?? '').isNotEmpty
        ? conv!.lastMsgPreview
        : '你收到一条新消息';
    LocalNotifyService.instance.showMessage(title: title, body: body);
  }

  void _showPlusMenu() {
    final t = AppLocalizations.of(context).t;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x80000000),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(12, 18, 12, 18),
                decoration: BoxDecoration(
                  color: context.cs.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _menuGridItem(
                      icon: Icons.person_add_alt_1,
                      color: AppTheme.primary,
                      title: t('chatListAddFriend'),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context)
                            .push(MaterialPageRoute(
                                builder: (_) => const AddFriendPage()))
                            .then((_) => _load());
                      },
                    ),
                    _menuGridItem(
                      icon: Icons.group_add_outlined,
                      color: AppTheme.green,
                      title: t('chatListCreateGroup'),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context)
                            .push(MaterialPageRoute(
                                builder: (_) =>
                                    NewConversationPage(myId: _myId)))
                            .then((_) => _load());
                      },
                    ),
                    _menuGridItem(
                      icon: Icons.qr_code_scanner,
                      color: AppTheme.orange,
                      title: t('chatListScan'),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const ScanQrLoginPage()));
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: context.cs.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                width: double.infinity,
                child: InkWell(
                  onTap: () => Navigator.of(ctx).pop(),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(t('chatListCancel'),
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: context.cs.onSurface)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuGridItem({
    required IconData icon,
    required Color color,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        width: 86,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 26, color: color),
            ),
            const SizedBox(height: 8),
            Text(title,
                style: TextStyle(
                    fontSize: 13,
                    color: context.cs.onSurface,
                    fontWeight: FontWeight.w500)),
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
            _header(),
            _searchBar(),
            _announcement(),
            Expanded(
              child: _loading
                  ? _buildLoadingView()
                  : _convs.isNotEmpty
                      ? RefreshIndicator(
                          // 下拉手动全量载入：重新拉会话列表（含最新一条消息）
                          color: AppTheme.primary,
                          onRefresh: _load,
                          child: ListView.builder(
                            // 不足一屏也保留下拉刷新能力
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(0, 2, 0, 8),
                            itemCount: _convs.length,
                            itemBuilder: (_, i) => _convItem(_convs[i]),
                          ),
                        )
                      : _loadFailed
                          ? _loadFailedView()
                          : Center(
                              child: Text(t('chatListEmpty'),
                                  style: TextStyle(
                                      color: context.cs.onSurfaceVariant))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loadFailedView() {
    final t = AppLocalizations.of(context).t;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined,
              size: 44, color: context.cs.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(t('chatListLoadFailed'),
              style:
                  TextStyle(fontSize: 14, color: context.cs.onSurfaceVariant)),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () {
              setState(() {
                _loading = true;
                _loadFailed = false;
              });
              _load();
            },
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

  Widget _header() {
    final t = AppLocalizations.of(context).t;
    return PageHeader(
      title: t('home'),
      trailingIcon: Icons.add,
      onTrailingTap: _showPlusMenu,
    );
  }

  Widget _searchBar() {
    final t = AppLocalizations.of(context).t;
    return PageSearchBar(
      hint: t('chatListSearch'),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const SearchPage())),
    );
  }

  Widget _announcement() {
    final text = _announcementText;
    if (text.isEmpty) return const SizedBox.shrink();
    if (_dismissedAnnouncement == text) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      height: 44,
      padding: const EdgeInsets.only(left: 14),
      decoration: BoxDecoration(
        color: context.cs.primaryContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          const Icon(Icons.campaign_outlined,
              size: 18, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: _Marquee(
                text: text,
                style: TextStyle(fontSize: 13, color: context.cs.onSurface)),
          ),
          IconButton(
            onPressed: _dismissAnnouncement,
            icon:
                Icon(Icons.close, size: 18, color: context.cs.onSurfaceVariant),
            splashRadius: 18,
          ),
        ],
      ),
    );
  }

  Future<void> _dismissAnnouncement() async {
    setState(() => _dismissedAnnouncement = _announcementText);
    try {
      await _api.writePref('dismissed_announcement', _announcementText);
    } catch (_) {}
  }

  // ===== 会话项 =====
  Widget _convItem(ConvItem c) {
    final t = AppLocalizations.of(context).t;
    final isGroup = (c.conversation['type'] as num?)?.toInt() == 2;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: AppSlidable(
        convId: c.id,
        // GlobalKey：侧滑状态跟随会话身份移动（列表重排不错配到别的行）；
        // 置顶/免打扰等操作完成后由 _closeSlider 经它显式收起菜单。
        key: _slideKeys.putIfAbsent(c.id, () => GlobalKey<AppSlidableState>()),
        cardColor: _convCardBg(c.pinned),
        actions: [
          SlidableAction(
            icon: Icons.push_pin,
            label: c.pinned ? t('chatListUnpin') : t('chatListPin'),
            color: AppTheme.primary.withValues(alpha: 0.14),
            foregroundColor: AppTheme.primary,
            onTap: () => _togglePin(c),
          ),
          SlidableAction(
            icon: c.mute ? Icons.notifications_active : Icons.notifications_off,
            label: c.mute ? t('chatListUnmute') : t('chatListMute'),
            color: context.cs.outlineVariant,
            foregroundColor: context.cs.onSurface,
            onTap: () => _toggleMute(c),
          ),
          SlidableAction(
            icon: Icons.delete_outline,
            label: t('chatListDelete'),
            color: AppTheme.danger,
            onTap: () => _deleteConv(c),
          ),
        ],
        child: Container(
          decoration: BoxDecoration(
            color: _convCardBg(c.pinned),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            onTap: () async {
              setState(() => _openConvId = c.id);
              await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ChatPage(conv: c, myId: _myId)));
              if (!mounted) return;
              setState(() => _openConvId = '');
              _load();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                children: [
                  _avatar(c, showOnline: !isGroup),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(c.conversationName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: context.cs.onSurface)),
                                  ),
                                  if (c.isAssistant)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 6),
                                      child: OfficialTag(),
                                    ),
                                ],
                              ),
                            ),
                            Text(c.timeText,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: context.cs.onSurfaceVariant)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (c.mute && c.unread == 0)
                              Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(Icons.notifications_off_outlined,
                                    size: 14,
                                    color: context.cs.onSurfaceVariant),
                              )
                            else if (c.pinned)
                              Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(Icons.push_pin,
                                    size: 14,
                                    color: context.cs.onSurfaceVariant),
                              ),
                            Expanded(
                              child: Text(c.lastMsgPreview,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: context.cs.onSurfaceVariant)),
                            ),
                            if (c.unread > 0)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                constraints: const BoxConstraints(
                                    minWidth: 22, minHeight: 22),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.unreadBadge,
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                    c.unread > 99 ? '99+' : '${c.unread}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  //  ✅ 核心修复：置顶/免打扰改为「本地更新」，不再调 _load()
  // ============================================================

  /// 置顶/取消置顶
  ///
  /// 原逻辑：调 _load() → _listRev++ → 全量重建 → 菜单状态错乱
  /// 新逻辑：本地直接更新数据 + setState → key 变化 → AppSlidable 重建 → 菜单自动收起
  Future<void> _togglePin(ConvItem c) async {
    final newPinned = !c.pinned;
    final t = AppLocalizations.of(context).t;

    // 1）先本地更新（立即反映 UI，不触发全量刷新）
    final idx = _convs.indexWhere((x) => x.id == c.id);
    if (idx >= 0 && idx < _convRaw.length) {
      final raw = Map<String, dynamic>.from(_convRaw[idx] as Map);
      raw['pinned'] = newPinned;
      final updated = ConvItem.fromJson(raw);

      setState(() {
        _convs.removeAt(idx);
        _convRaw.removeAt(idx);
        // 置顶的移到最前，取消置顶的插到"置顶块"之后
        var target = 0;
        if (!newPinned) {
          while (target < _convs.length && _convs[target].pinned) {
            target++;
          }
        }
        _convs.insert(target, updated);
        _convRaw.insert(target, raw);
      });
    }

    // 2）显式关闭该行侧滑菜单（按钮 onTap 时 AppSlidable 已自收起一次，这里再兜底）
    _closeSlider(c.id);

    // 3）后台同步到服务端（不需要 await，不阻塞 UI）
    try {
      final ok = await ConversationService().setPin(c.id, newPinned);
      if (!ok) {
        _toast(t('chatListOpFailed'));
        _load(); // 失败回滚：重新拉取正确数据
        return;
      }
      _toast(newPinned ? t('chatListPinned') : t('chatListUnpinned'));
    } catch (e) {
      _toast(t('chatListOpFailed'));
      // 失败回滚：重新拉取正确数据
      _load();
    }
  }

  /// 免打扰/取消免打扰 —— 同理
  Future<void> _toggleMute(ConvItem c) async {
    final newMute = !c.mute;
    final t = AppLocalizations.of(context).t;

    // 1）本地更新单条
    final idx = _convs.indexWhere((x) => x.id == c.id);
    if (idx >= 0 && idx < _convRaw.length) {
      final raw = Map<String, dynamic>.from(_convRaw[idx] as Map);
      raw['mute'] = newMute;
      final updated = ConvItem.fromJson(raw);

      setState(() {
        _convs[idx] = updated;
        _convRaw[idx] = raw;
      });
    }

    // 2）显式关闭该行侧滑菜单（同置顶，操作后兜底收起）
    _closeSlider(c.id);

    // 3）后台同步
    try {
      final ok = await ConversationService().setMute(c.id, newMute);
      if (!ok) {
        _toast(t('chatListOpFailed'));
        _load();
        return;
      }
      _toast(newMute ? t('chatListMuteOn') : t('chatListNotifyOn'));
    } catch (e) {
      _toast(t('chatListOpFailed'));
      _load();
    }
  }

  Future<void> _deleteConv(ConvItem c) async {
    // 删除操作本身已经是局部 setState，不涉及全量刷新
    // AppSlidable 被移除 → 菜单自然不存在了；顺手清掉它的 GlobalKey
    final idx = _convs.indexWhere((x) => x.id == c.id);
    _slideKeys.remove(c.id);
    setState(() {
      _convs.removeWhere((x) => x.id == c.id);
      if (idx >= 0 && idx < _convRaw.length) _convRaw.removeAt(idx);
    });
    _toast(AppLocalizations.of(context).t('chatListDeleted'));
  }

  /// 显式关闭某行的侧滑菜单（置顶/免打扰等操作完成后调用）。
  /// 延后到帧末执行：确保 GlobalKey 对应的 State 已完成重排后的重新挂载。
  void _closeSlider(String id) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _slideKeys[id]?.currentState?.close();
    });
  }

  /// 首次载入态：主色调线性进度条 + 文案（替代原来的灰色转圈）
  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 140,
            child: LinearProgressIndicator(
              minHeight: 4,
              color: AppTheme.primary,
              backgroundColor: Color(0x1A007AFF),
            ),
          ),
          const SizedBox(height: 12),
          Text(AppLocalizations.of(context).t('chatLoadingMsg'),
              style: TextStyle(
                  fontSize: 13, color: context.cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  /// 会话卡背景色。置顶 = surface 向主色调抬 6% 的【不透明】色。
  /// 铁律：不能用半透明色（primary.withValues(alpha:0.06)）——
  /// 侧滑按钮层常驻绘制在卡片底下，半透明卡片会把
  /// 「取消置顶/免打扰/删除」三个按钮直接透出来（视觉上像菜单没关）。
  Color _convCardBg(bool pinned) {
    final surface = context.cs.surface;
    if (!pinned) return surface;
    return Color.lerp(surface, AppTheme.primary, 0.06)!;
  }

  void _toast(String msg) {
    AppDialogs.toast(context, msg);
  }

  Widget _avatar(ConvItem c, {bool showOnline = true}) {
    final color = AppTheme
        .avatarColors[c.id.hashCode.abs() % AppTheme.avatarColors.length];
    final isGroup = (c.conversation['type'] as num?)?.toInt() == 2;
    final avatar = SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(isGroup ? 14 : 24),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned.fill(
                    child: c.avatarUrl.isNotEmpty
                        ? Image.network(
                            c.avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _avatarFallback(color, c, isGroup),
                          )
                        : _avatarFallback(color, c, isGroup),
                  ),
                  if (isGroup)
                    Positioned(
                      right: -19,
                      bottom: 5,
                      width: 60,
                      height: 12,
                      child: Transform.rotate(
                        angle: -math.pi / 4,
                        child: Container(
                          color: AppTheme.primary,
                          alignment: Alignment.center,
                          child: Text(
                              AppLocalizations.of(context)
                                  .t('chatListGroupBadge'),
                              style: const TextStyle(
                                  fontSize: 8,
                                  height: 1,
                                  color: Colors.white)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (!isGroup && showOnline && c.peerOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppTheme.onlineDot,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.cs.surface, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
    return avatar;
  }

  Widget _avatarFallback(Color color, ConvItem c, bool isGroup) {
    return Container(
      color: color,
      alignment: Alignment.center,
      child: Text(
        c.conversationName.isEmpty
            ? AppLocalizations.of(context).t('chatListGroupInitial')
            : c.conversationName.characters.first,
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
      ),
    );
  }
}

/// 跑马灯：文字水平循环滚动（公告横幅用）
class _Marquee extends StatefulWidget {
  final String text;
  final TextStyle style;
  const _Marquee({required this.text, required this.style});

  @override
  State<_Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<_Marquee>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final ScrollController _scroll;
  double _textWidth = 0;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 12))
          ..addListener(() {
            if (_scroll.hasClients) {
              _scroll.jumpTo(_controller.value * _textWidth);
            }
          });
    _scroll = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    if (!mounted || _started) return;
    final tp = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    _textWidth = tp.width;
    _started = true;
    if (_textWidth > 200) _controller.repeat();
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox(
        height: 24,
        child: ListView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 40),
              child: Text(widget.text,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: widget.style),
            ),
          ],
        ),
      ),
    );
  }
}
