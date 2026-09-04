import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_locale.dart';
import '../services/call_service.dart';
import '../services/keep_alive_service.dart';
import '../services/push_service.dart';
import '../services/sound_service.dart';
import '../services/unread_store.dart';
import '../services/friend_req_store.dart';
import '../services/wallet_store.dart';
import '../services/ws_service.dart';
import '../theme/app_theme.dart';
import 'chat_list_page.dart';
import 'contacts_page.dart';
import 'discover_page.dart';
import 'me_page.dart';

/// 底部 4 Tab（消息 / 通讯录 / 发现 / 我的）—— 对齐 ChatPulse 参考图
/// 白色底栏、顶部细线、active=#007AFF 蓝、inactive=#999999 灰
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;

  late final List<Widget> _pages;
  VoidCallback? _offFriend;

  @override
  void initState() {
    super.initState();
    // B-24：监听前后台切换——WS 断了、或推送没收到时，切回前台兜底拉一次余额
    WidgetsBinding.instance.addObserver(this);
    _pages = <Widget>[
      const ChatListPage(),
      const ContactsPage(),
      const DiscoverPage(),
      const MePage(),
    ];
    FriendReqStore.instance.refresh();
    _offFriend = GlobalWs.instance.onFriend((_) {
      FriendReqStore.instance.refresh();
      // 需求：被添加好友提示音
      SoundService.instance.playFriendAdded();
    });
    GlobalWs.instance.ensureConnected();
    // 通话信令：登录后挂上全局监听（来电可在任意页面弹出）
    CallService.instance.attach();
    // Android 保活前台服务：申请通知权限 + 电池优化白名单并启动服务
    //（启动 App 时必经页面，所有登录入口都覆盖）
    unawaited(KeepAliveService.instance.start());
    // 极光推送：绑定 alias = 用户 ID（覆盖启动自动登录/登录/注册/扫码四条入口）
    unawaited(PushService.instance.start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _offFriend?.call();
    super.dispose();
  }

  /// App 切回前台：补拉余额与好友申请数。
  /// 主链路是服务端 WS 推送（B-24），这里只是兜底——
  /// 覆盖「WS 断开」「推送丢失」「用户在 PC 后台改完再拿起手机」几种情况。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(WalletStore.instance.refresh());
    FriendReqStore.instance.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    return Scaffold(
      // IndexedStack 保活 4 个 tab：切换时不销毁/重建页面，
      // 修复「快速点'我的'先闪'未登录'再加载头像昵称」「发现页每次切 tab 都重新加载」。
      // 代价是 4 页 initState 在进入首页时并发执行一次（各自拉一次接口），可接受。
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
              top: BorderSide(
                  color: context.cs.onSurface.withValues(alpha: 0.08),
                  width: 0.5)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                _tab(0, Icons.chat_bubble_outline, Icons.chat_bubble_rounded,
                    t('home')),
                _tab(1, Icons.contacts_outlined, Icons.contacts_rounded,
                    t('contacts')),
                _tab(2, Icons.explore_outlined, Icons.explore_rounded,
                    t('discover')),
                _tab(3, Icons.person_outline, Icons.person_rounded, t('me')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 切 Tab。切到"我的"（index 3）时顺手拉一次余额 ——
  /// 后台给用户加了余额，用户不用杀 App 重进就能看到（B-20）。
  void _onTabTap(int i) {
    setState(() => _index = i);
    if (i == 3) WalletStore.instance.refresh();
  }

  Widget _tab(int i, IconData iconOff, IconData iconOn, String label) {
    final active = i == _index;
    return Expanded(
      child: InkWell(
        onTap: () => _onTabTap(i),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                // 需求1："消息" tab 未读红点（ChatListPage 拉会话列表后上报总数）
                if (i == 0)
                  ValueListenableBuilder<int>(
                    valueListenable: UnreadStore.instance.total,
                    builder: (_, unread, __) => Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(active ? iconOn : iconOff,
                            size: 24,
                            color: active
                                ? AppTheme.primary
                                : context.cs.onSurfaceVariant),
                        if (unread > 0)
                          Positioned(
                            right: -7,
                            top: -7,
                            child: _badge(unread),
                          ),
                      ],
                    ),
                  )
                else
                  Icon(active ? iconOn : iconOff,
                      size: 24,
                      color: active
                          ? AppTheme.primary
                          : context.cs.onSurfaceVariant),
                if (i == 1)
                  ValueListenableBuilder<int>(
                    valueListenable: FriendReqStore.instance.count,
                    builder: (_, c, __) => c > 0
                        ? Positioned(
                            right: -7,
                            top: -7,
                            child: _badge(c),
                          )
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: active
                        ? AppTheme.primary
                        : context.cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _badge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: AppTheme.unreadBadge,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(count > 99 ? '99+' : '$count',
          style: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
    );
  }
}
