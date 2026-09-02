import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/call_service.dart';
import '../services/conversation_service.dart';
import '../services/local_notify_service.dart';
import '../services/sound_service.dart';
import '../services/unread_store.dart';
import '../services/ws_service.dart';
import '../l10n/app_locale.dart';
import '../theme/app_theme.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_slidable.dart';
import '../widgets/official_tag.dart';
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
  bool _loading = true;
  String _myId = '';
  String _announcementText = '';
  String _dismissedAnnouncement = ''; // 用户已手动关闭的公告内容（按内容记忆）
  VoidCallback? _wsCancel;

  @override
  void initState() {
    super.initState();
    _load();
    _loadMyId();
    _loadAnnouncement();
    _loadDismissedAnnouncement();
    // 需求7：全局 WS 实时推送 —— 收到新消息立即刷新会话列表（无需手动刷新）
    _wsCancel = GlobalWs.instance.onMessage((m) {
      _load(); // 会话列表整体刷新（含未读、排序、最后消息）
      // 需求：新消息铃声（非自己发送、非通话信令、非通话中）
      final type = (m['type'] as num?)?.toInt();
      final senderId = m['senderId']?.toString() ?? '';
      if (type == 1 &&
          senderId.isNotEmpty &&
          senderId != _myId &&
          CallService.instance.state.value == null) {
        SoundService.instance.playNewMessage();
      }
      // 需求3：App 后台时通知栏本地通知（极光只推离线用户，在线/后台挂 WS 不推）
      _maybeLocalNotify(m);
    });
    GlobalWs.instance.onRecall((_) => _load());
    GlobalWs.instance.ensureConnected();
  }

  @override
  void dispose() {
    _wsCancel?.call();
    super.dispose();
  }

  /// 公告内容来自后台配置（/auth/config → announcement）
  Future<void> _loadAnnouncement() async {
    try {
      final r = await _api.get('/api/v1/auth/config');
      final data = (r.data as Map<String, dynamic>)['data'];
      final text = (data is Map && data['announcement'] != null)
          ? data['announcement'].toString()
          : '';
      if (mounted) setState(() => _announcementText = text);
    } catch (_) {}
  }

  /// 读本地"已关闭公告"记录（重启后仍生效；后台换新公告内容会重新显示）
  Future<void> _loadDismissedAnnouncement() async {
    try {
      final v = await _api.readPref('dismissed_announcement') ?? '';
      if (mounted) setState(() => _dismissedAnnouncement = v);
    } catch (_) {}
  }

  Future<void> _loadMyId() async {
    try {
      final r = await _api.get('/api/v1/user/profile');
      final id =
          ((r.data['data'] as Map<String, dynamic>)['id'])?.toString() ?? '';
      if (mounted && id.isNotEmpty) setState(() => _myId = id);
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      final list = await _svc.list();
      // 需求1：底部"消息"tab 红点 —— 未读总数上报全局 store
      UnreadStore.instance
          .update(list.fold<int>(0, (sum, c) => sum + (c.mute ? 0 : c.unread)));
      if (mounted) {
        setState(() {
          _convs = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// App 处于后台/锁屏时收到新消息 → 发通知栏本地通知。
  /// 前台不发（页内已有铃声 + 红点）；免打扰会话不发；通话信令不发。
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
    if (conv != null && conv.mute) return; // 免打扰会话不通知
    final title =
        (conv?.conversationName ?? '').isNotEmpty ? conv!.conversationName : '新消息';
    final body = (conv?.lastMsgPreview ?? '').isNotEmpty
        ? conv!.lastMsgPreview
        : '你收到一条新消息';
    LocalNotifyService.instance.showMessage(title: title, body: body);
  }

  /// 顶栏 + 按钮：弹出菜单（添加好友 / 创建群聊 / 扫一扫）
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
                  ? const Center(child: CircularProgressIndicator())
                  : _convs.isEmpty
                      ? Center(
                          child: Text(t('chatListEmpty'),
                              style: TextStyle(
                                  color: context.cs.onSurfaceVariant)))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(0, 2, 0, 8),
                          itemCount: _convs.length,
                          itemBuilder: (_, i) => _convItem(_convs[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== 顶栏 =====
  Widget _header() {
    final t = AppLocalizations.of(context).t;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          Text(t('home'),
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: context.cs.onSurface)),
          const Spacer(),
          IconButton(
            onPressed: _showPlusMenu,
            icon: Icon(Icons.add, size: 26, color: context.cs.onSurface),
            splashRadius: 22,
          ),
        ],
      ),
    );
  }

  // ===== 搜索栏（白色填充 + 发丝线描边，与灰色页面背景拉开对比）=====
  Widget _searchBar() {
    final t = AppLocalizations.of(context).t;
    return GestureDetector(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const SearchPage())),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: context.cs.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: context.cs.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.search, size: 20, color: context.cs.onSurfaceVariant),
            SizedBox(width: 8),
            Text(t('chatListSearch'),
                style: TextStyle(
                    fontSize: 14, color: context.cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  // ===== 公告横幅（后台配置 + 跑马灯；用户可手动关闭，按内容记忆——换新公告会重新显示） =====
  Widget _announcement() {
    final text = _announcementText;
    if (text.isEmpty) return const SizedBox.shrink();
    // 用户已关闭过同一条公告 → 不再显示
    if (_dismissedAnnouncement == text) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
          // 跑马灯：文字循环滚动（动画驱动）
          Expanded(
            child: _Marquee(
                text: text,
                style: TextStyle(fontSize: 13, color: context.cs.onSurface)),
          ),
          // 手动关闭按钮
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

  // ===== 会话项（仿微信侧滑：置顶 / 免打扰 / 删除 直接点击执行） =====
  Widget _convItem(ConvItem c) {
    final t = AppLocalizations.of(context).t;
    final isGroup = (c.conversation['type'] as num?)?.toInt() == 2;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: AppSlidable(
        cardColor: c.pinned
            ? AppTheme.primary.withValues(alpha: 0.06)
            : context.cs.surface,
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
            color: c.pinned
                ? AppTheme.primary.withValues(alpha: 0.06)
                : context.cs.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ChatPage(conv: c, myId: _myId)));
              if (mounted) _load();
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
                                  // 小助手官方标识（虚拟 uid -1）
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

  Future<void> _togglePin(ConvItem c) async {
    try {
      await ConversationService().setPin(c.id, !c.pinned);
      _toast(c.pinned
          ? AppLocalizations.of(context).t('chatListUnpinned')
          : AppLocalizations.of(context).t('chatListPinned'));
      _load();
    } catch (e) {
      _toast(AppLocalizations.of(context).t('chatListOpFailed'));
    }
  }

  Future<void> _toggleMute(ConvItem c) async {
    try {
      await ConversationService().setMute(c.id, !c.mute);
      _toast(c.mute
          ? AppLocalizations.of(context).t('chatListNotifyOn')
          : AppLocalizations.of(context).t('chatListMuteOn'));
      _load();
    } catch (e) {
      _toast(AppLocalizations.of(context).t('chatListOpFailed'));
    }
  }

  Future<void> _deleteConv(ConvItem c) async {
    // 单聊通过退出处理（退出后端无对应接口，这里做本地移除）
    setState(() {
      _convs.removeWhere((x) => x.id == c.id);
    });
    _toast(AppLocalizations.of(context).t('chatListDeleted'));
  }

  void _toast(String msg) {
    AppDialogs.toast(context, msg);
  }

  Widget _avatar(ConvItem c, {bool showOnline = true}) {
    final color = AppTheme
        .avatarColors[c.id.hashCode.abs() % AppTheme.avatarColors.length];
    final isGroup = (c.conversation['type'] as num?)?.toInt() == 2;
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(isGroup ? 14 : 24),
              child: c.avatarUrl.isNotEmpty
                  ? Image.network(
                      c.avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _avatarFallback(color, c, isGroup),
                    )
                  : _avatarFallback(color, c, isGroup),
            ),
          ),
          // 单聊头像右下角在线状态点（群聊不显示；对方在线才显示绿点）
          if (!isGroup && showOnline && c.peerOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppTheme.onlineDot, // 在线绿
                  shape: BoxShape.circle,
                  border: Border.all(color: context.cs.surface, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
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
    // 用 LayoutBuilder + TextPainter 测文字宽度
    final tp = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    _textWidth = tp.width;
    _started = true;
    if (_textWidth > 200) _controller.repeat(); // 超出才滚动
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
