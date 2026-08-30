import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/conversation_service.dart';
import '../theme/app_theme.dart';
import 'add_friend_page.dart';
import 'chat_page.dart';
import 'new_conversation_page.dart';
import 'qr_login_page.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
    _loadMyId();
    _loadAnnouncement();
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

  Future<void> _loadMyId() async {
    try {
      final r = await _api.get('/api/v1/user/profile');
      final id = ((r.data['data'] as Map<String, dynamic>)['id'])?.toString() ?? '';
      if (mounted && id.isNotEmpty) setState(() => _myId = id);
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      final list = await _svc.list();
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

  /// 顶栏 + 按钮：弹出菜单（添加好友 / 创建群聊 / 扫一扫）
  void _showPlusMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x80000000), // 半透明遮罩
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _menuItem(
                  icon: Icons.person_add_alt_1,
                  color: AppTheme.primary,
                  title: '添加好友',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const AddFriendPage()))
                        .then((_) => _load());
                  },
                ),
                const Divider(height: 1, color: AppTheme.divider),
                _menuItem(
                  icon: Icons.group_add_outlined,
                  color: AppTheme.primary,
                  title: '创建群聊',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => NewConversationPage(myId: _myId)))
                        .then((_) => _load());
                  },
                ),
                const Divider(height: 1, color: AppTheme.divider),
                _menuItem(
                  icon: Icons.qr_code_scanner,
                  color: AppTheme.primary,
                  title: '扫一扫',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    // 手机端扫 PC 端二维码登录
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const ScanQrLoginPage()));
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required Color color,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 16),
            Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
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
                      ? const Center(
                          child: Text('暂无会话',
                              style: TextStyle(color: AppTheme.textTertiary)))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          const Text('消息',
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary)),
          const Spacer(),
          IconButton(
            onPressed: () => _showPlusMenu(context),
            icon: const Icon(Icons.add,
                size: 26, color: AppTheme.textPrimary),
            splashRadius: 22,
          ),
        ],
      ),
    );
  }

  // ===== 搜索栏（surface 浅灰圆角）=====
  Widget _searchBar() {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SearchPage())),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          children: [
            Icon(Icons.search, size: 18, color: AppTheme.textTertiary),
            SizedBox(width: 8),
            Text('搜索',
                style: TextStyle(fontSize: 14, color: AppTheme.textTertiary)),
          ],
        ),
      ),
    );
  }

  // ===== 公告横幅（后台配置 + 跑马灯） =====
  Widget _announcement() {
    final text = _announcementText;
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppTheme.announcementBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.chat_bubble_outline, size: 16, color: AppTheme.primary),
          const SizedBox(width: 8),
          // 跑马灯：文字循环滚动（动画驱动）
          Expanded(
            child: _Marquee(text: text, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }

  // ===== 会话项 =====
  Widget _convItem(ConvItem c) {
    final isGroup = (c.conversation['type'] as num?)?.toInt() == 2;
    return Dismissible(
      key: ValueKey('conv-${c.id}'),
      direction: DismissDirection.endToStart, // 从右到左滑动
      // 滑动阈值超过 40% 才接受（避免误触）
      dismissThresholds: const {DismissDirection.endToStart: 0.4},
      background: Container(
        color: AppTheme.background,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _slideAction(Icons.push_pin, c.pinned ? '取消置顶' : '置顶',
                AppTheme.primary, () => _togglePin(c)),
            const SizedBox(width: 18),
            _slideAction(c.mute ? Icons.notifications_active : Icons.notifications_off,
                c.mute ? '取消免打扰' : '免打扰', AppTheme.warning, () => _toggleMute(c)),
          ],
        ),
      ),
      confirmDismiss: (dir) async {
        // 滑动后弹菜单选择操作（避免直接消失）
        await _showConvActions(c);
        return false; // 不真的 dismiss
      },
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ChatPage(conv: c, myId: _myId)));
          if (mounted) _load();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                          child: Text(c.conversationName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary)),
                        ),
                        Text(c.timeText,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textTertiary)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (c.mute && c.unread == 0)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.notifications_off_outlined,
                                size: 14, color: Color(0xFFC0C6CF)),
                          )
                        else if (c.pinned)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.push_pin,
                                size: 14, color: AppTheme.textTertiary),
                          ),
                        Expanded(
                          child: Text(c.lastMsgPreview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary)),
                        ),
                        if (c.unread > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            constraints:
                                const BoxConstraints(minWidth: 22, minHeight: 22),
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
    );
  }

  Widget _slideAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }

  /// 滑动后弹出操作菜单（不直接消失）
  Future<void> _showConvActions(ConvItem c) async {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.push_pin, color: AppTheme.primary),
              title: Text(c.pinned ? '取消置顶' : '置顶会话'),
              onTap: () { Navigator.of(ctx).pop(); _togglePin(c); },
            ),
            ListTile(
              leading: Icon(c.mute ? Icons.notifications_active : Icons.notifications_off,
                  color: AppTheme.warning),
              title: Text(c.mute ? '取消免打扰' : '消息免打扰'),
              onTap: () { Navigator.of(ctx).pop(); _toggleMute(c); },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppTheme.danger),
              title: const Text('删除会话', style: TextStyle(color: AppTheme.danger)),
              onTap: () { Navigator.of(ctx).pop(); _deleteConv(c); },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _togglePin(ConvItem c) async {
    try {
      await ConversationService().setPin(c.id, !c.pinned);
      _toast(c.pinned ? '已取消置顶' : '已置顶');
      _load();
    } catch (e) { _toast('操作失败'); }
  }

  Future<void> _toggleMute(ConvItem c) async {
    try {
      await ConversationService().setMute(c.id, !c.mute);
      _toast(c.mute ? '已开启提醒' : '已开启免打扰');
      _load();
    } catch (e) { _toast('操作失败'); }
  }

  Future<void> _deleteConv(ConvItem c) async {
    // 单聊通过退出处理（退出后端无对应接口，这里做本地移除）
    setState(() {
      _convs.removeWhere((x) => x.id == c.id);
    });
    _toast('已删除会话');
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _avatar(ConvItem c, {bool showOnline = true}) {
    final color =
        AppTheme.avatarColors[c.id.hashCode.abs() % AppTheme.avatarColors.length];
    final isGroup = (c.conversation['type'] as num?)?.toInt() == 2;
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(isGroup ? 14 : 24),
              ),
              alignment: Alignment.center,
              child: Text(
                c.conversationName.isEmpty ? '群' : c.conversationName.characters.first,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ),
          // 单聊头像右下角在线状态点（群聊不显示；对方在线才显示绿点）
          if (!isGroup && showOnline && c.peerOnline)
            Positioned(
              right: 0, bottom: 0,
              child: Container(
                width: 12, height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFF00B42A), // 在线绿
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.background, width: 2),
                ),
              ),
            ),
        ],
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
    _controller = AnimationController(
        vsync: this, duration: const Duration(seconds: 12))
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
