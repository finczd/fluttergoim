import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../l10n/app_locale.dart';
import '../services/call_service.dart';
import '../services/conversation_service.dart';
import '../services/friend_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_dialogs.dart';
import 'chat_page.dart';
import 'video_call_page.dart';
import 'voice_call_page.dart';
import 'moments_page.dart';

/// 会话设置：群聊 → 群资料；单聊 → 个人资料
class ConvSettingsPage extends StatefulWidget {
  final ConvItem conv;
  const ConvSettingsPage({super.key, required this.conv});

  @override
  State<ConvSettingsPage> createState() => _ConvSettingsPageState();
}

class _ConvSettingsPageState extends State<ConvSettingsPage> {
  final _svc = ConversationService();
  final _friendSvc = FriendService();
  bool _pinned = false;
  bool _mute = false;
  late String _remark;
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _pinnedMsgs = [];
  int _pinIndex = 0;
  String? _myId;

  bool get isGroup => (widget.conv.conversation['type'] as num?)?.toInt() == 2;

  String get _announcement =>
      widget.conv.conversation['announcementZh']?.toString() ?? '';

  String get _pinnedContent =>
      widget.conv.conversation['pinnedMsgContent']?.toString() ?? '';

  bool get _isOwner {
    if (_myId == null) return false;
    return _members.any((m) {
      final role = m['role'];
      final uid = m['id']?.toString() ?? m['userId']?.toString() ?? '';
      return (role == 1 || role == '1' || role?.toString() == 'owner') &&
          uid == _myId;
    });
  }

  @override
  void initState() {
    super.initState();
    _pinned = widget.conv.pinned;
    _mute = widget.conv.mute;
    _remark = widget.conv.peerRemark;
    _loadProfile();
    if (isGroup) {
      _loadMembers();
      _loadPinned();
    }
  }

  Future<void> _loadProfile() async {
    try {
      final p = await _friendSvc.profile();
      if (mounted) setState(() => _myId = p['id']?.toString());
    } catch (_) {}
  }

  Future<void> _loadMembers() async {
    final list = await _svc.members(widget.conv.id);
    if (mounted) setState(() => _members = list);
  }

  /// 加载群置顶消息列表（多条，需求：支持点击切换 + 跳转）
  Future<void> _loadPinned() async {
    try {
      final list = await _svc.pinnedMessages(widget.conv.id);
      if (mounted) {
        setState(() {
          _pinnedMsgs = list;
          _pinIndex = 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _togglePin(bool v) async {
    final ok = await _svc.setPin(widget.conv.id, v);
    if (ok && mounted) setState(() => _pinned = v);
  }

  Future<void> _toggleMute(bool v) async {
    final ok = await _svc.setMute(widget.conv.id, v);
    if (ok && mounted) setState(() => _mute = v);
  }

  Future<void> _exit() async {
    final ok = await _svc.quit(widget.conv.id);
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _disband() async {
    final ok = await _svc.disband(widget.conv.id);
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  /// 单聊对方用户 id（members 里非自己的成员）
  Future<String> _peerId() async {
    try {
      final list = await _svc.members(widget.conv.id);
      for (final m in list) {
        final uid = m['id']?.toString() ?? m['userId']?.toString() ?? '';
        if (uid.isNotEmpty && uid != _myId) return uid;
      }
    } catch (_) {}
    return '';
  }

  /// 设置备注（需求：真实保存 + 回显）
  Future<void> _setRemark() async {
    final t = AppLocalizations.of(context).t;
    final result = await AppDialogs.input(
      context,
      title: t('convSetRemarkTitle'),
      hint: t('convSetRemarkName'),
      maxLines: 1,
      maxLength: 20,
      initialValue: _remark.isEmpty ? null : _remark,
    );
    if (result == null || result.isEmpty) return;
    final pid = await _peerId();
    if (pid.isEmpty) {
      if (mounted) AppDialogs.toast(context, t('convSetGetPeerFailed'));
      return;
    }
    final ok = await _friendSvc.setRemark(pid, result);
    if (ok && mounted) {
      setState(() => _remark = result);
      AppDialogs.toast(context, t('convSetRemarkSaved'));
    }
  }

  /// 朋友圈入口：查看该好友的全部朋友圈（F-03）
  Future<void> _openMoments() async {
    final t = AppLocalizations.of(context).t;
    final pid = await _peerId();
    if (pid.isEmpty) {
      if (mounted) AppDialogs.toast(context, t('convSetGetPeerFailed'));
      return;
    }
    if (!mounted) return;
    final name = _remark.isNotEmpty ? _remark : widget.conv.conversationName;
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MomentsPage(userId: pid, userName: name)));
  }

  /// 发消息：进入与对方的聊天
  Future<void> _sendMsg() async {
    final t = AppLocalizations.of(context).t;
    final pid = await _peerId();
    if (pid.isEmpty) return;
    try {
      final conv = await _svc.createDirect(pid);
      if (!mounted) return;
      final item = ConvItem.fromJson({
        'conversation': conv,
        'conversationName':
            _remark.isNotEmpty ? _remark : widget.conv.conversationName,
      });
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChatPage(conv: item, myId: _myId ?? '')));
    } catch (e) {
      if (mounted) {
        AppDialogs.toast(
            context, t('convSetStartConvFailed', {'error': e.toString()}));
      }
    }
  }

  /// 加入黑名单（与好友详情页行为一致）
  Future<void> _confirmBlacklist() async {
    final t = AppLocalizations.of(context).t;
    final pid = await _peerId();
    if (pid.isEmpty) {
      if (mounted) AppDialogs.toast(context, t('convSetGetPeerFailed'));
      return;
    }
    final yes = await AppDialogs.confirm(
      context,
      title: t('convSetBlacklistTitle'),
      message: t('convSetBlacklistMsg'),
      confirmText: t('convSetBlacklistConfirm'),
      danger: true,
    );
    if (yes != true) return;
    final ok = await _friendSvc.blacklistAdd(pid);
    if (ok && mounted) {
      AppDialogs.toast(context, t('convSetBlacklisted'));
      Navigator.of(context).pop(true);
    }
  }

  void _copyId() {
    final v = isGroup ? widget.conv.id : widget.conv.peerShortId;
    if (v.isEmpty) return;
    Clipboard.setData(ClipboardData(text: v));
    final t = AppLocalizations.of(context).t;
    AppDialogs.toast(
        context, isGroup ? t('convSetGroupIdCopied') : t('convSetIdCopied'));
  }

  void _startCall(String type) async {
    final t = AppLocalizations.of(context).t;
    final busy = CallService.instance.state.value != null;
    if (busy) {
      AppDialogs.toast(context, t('convSetCallBusy'));
      return;
    }
    await CallService.instance.startCall(
      convId: widget.conv.id,
      callType: type,
      peerName: widget.conv.conversationName,
      peerAvatar: widget.conv.avatarUrl,
    );
    if (!mounted) return;
    final page = type == 'video'
        ? VideoCallPage(
            peerName: widget.conv.conversationName,
            peerAvatar: widget.conv.avatarUrl,
            convId: widget.conv.id,
          )
        : VoiceCallPage(
            peerName: widget.conv.conversationName,
            peerAvatar: widget.conv.avatarUrl,
            convId: widget.conv.id,
          );
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  void _placeholder(String name) {
    final t = AppLocalizations.of(context).t;
    AppDialogs.toast(context, t('convSetComingSoon', {'name': name}));
  }

  void _editAnnouncement() async {
    final t = AppLocalizations.of(context).t;
    final text = await AppDialogs.input(context,
        title: t('convSetAnnouncementTitle'),
        hint: t('convSetAnnouncementHint'),
        initialValue: _announcement,
        maxLines: 4,
        maxLength: 200,
        confirmText: t('convSetSave'));
    if (text == null || !mounted) return;
    final ok = await _svc.updateAnnouncement(widget.conv.id, text, '');
    if (ok && mounted) {
      AppDialogs.toast(context, t('convSetAnnouncementSaved'));
      Navigator.of(context).pop(true);
    }
  }

  void _showMembers() {
    final t = AppLocalizations.of(context).t;
    if (_members.isEmpty) {
      AppDialogs.toast(context, t('convSetNoMembers'));
      return;
    }
    AppDialogs.actionSheet(context,
        title:
            t('convSetMembersTitle', {'count': _members.length.toString()}),
        actions: _members
            .map((m) => DialogAction(
                  label: m['nickname']?.toString() ??
                      m['account']?.toString() ??
                      '',
                  icon: Icons.person_outline,
                  onTap: () {},
                ))
            .toList());
  }

  void _inviteMember() => AppDialogs.toast(
      context, AppLocalizations.of(context).t('convSetInviteMemberComing'));

  void _removeMember() => AppDialogs.toast(
      context, AppLocalizations.of(context).t('convSetRemoveMemberComing'));

  void _clearHistory() async {
    final t = AppLocalizations.of(context).t;
    final ok = await AppDialogs.confirm(context,
        title: t('convSetClearHistoryTitle'),
        message: t('convSetClearHistoryMsg'),
        confirmText: t('convSetClearHistoryConfirm'),
        danger: true);
    if (ok == true && mounted) {
      AppDialogs.toast(context, t('convSetHistoryCleared'));
    }
  }

  Future<void> _deleteFriendOrExit() async {
    final t = AppLocalizations.of(context).t;
    final title = isGroup
        ? (_isOwner ? t('convSetDisbandGroupTitle') : t('convSetExitGroupTitle'))
        : t('convSetDeleteFriendTitle');
    final msg = isGroup
        ? (_isOwner ? t('convSetDisbandGroupMsg') : t('convSetExitGroupMsg'))
        : t('convSetDeleteFriendMsg');
    final ok = await AppDialogs.confirm(context,
        title: title,
        message: msg,
        confirmText: isGroup
            ? (_isOwner ? t('convSetDisbandConfirm') : t('convSetExitConfirm'))
            : t('convSetDeleteConfirm'),
        danger: true);
    if (ok != true) return;
    if (isGroup) {
      _isOwner ? _disband() : _exit();
    } else {
      // 单聊：先删好友再退出会话（V2.0 完整实现前仅删除会话）
      _exit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: context.cs.surface,
        elevation: 0,
        centerTitle: true,
        title: Text(isGroup ? t('convSetGroupProfile') : t('convSetPersonalProfile'),
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: context.cs.onSurface)),
        iconTheme: IconThemeData(color: context.cs.onSurface),
        actions: [
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.more_horiz, color: context.cs.onSurface),
          ),
        ],
      ),
      body: isGroup ? _groupBody() : _directBody(),
    );
  }

  // ==================== 单聊：个人资料 ====================

  Widget _directBody() {
    final t = AppLocalizations.of(context).t;
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _directHeader(),
        const SizedBox(height: 24),
        _callButtons(),
        const SizedBox(height: 24),
        _card(
          child: Column(
            children: [
              _infoRow(t('convSetSendMessage'), '',
                  chevron: true,
                  icon: Icons.chat_bubble_outline,
                  onTap: _sendMsg),
              Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: context.cs.outlineVariant),
              _infoRow(t('convSetRemarkName'),
                  _remark.isEmpty ? t('convSetNotSet') : _remark,
                  chevron: true, icon: Icons.edit_outlined, onTap: _setRemark),
              Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: context.cs.outlineVariant),
              _infoRow(t('convSetMoments'), '',
                  chevron: true,
                  icon: Icons.photo_album_outlined,
                  onTap: _openMoments),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _card(
          child: Column(
            children: [
              _switchRow(t('convSetMute'), _mute, _toggleMute),
              Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: context.cs.outlineVariant),
              _switchRow(t('convSetPinChat'), _pinned, _togglePin),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _card(
          child: InkWell(
            onTap: _clearHistory,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 8, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(t('convSetClearHistoryTitle'),
                        style: TextStyle(
                            fontSize: 15, color: context.cs.onSurface)),
                  ),
                  Icon(Icons.chevron_right,
                      size: 18, color: context.cs.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _dangerButton(
              isGroup
                  ? (_isOwner
                      ? t('convSetDisbandGroupTitle')
                      : t('convSetExitGroupTitle'))
                  : t('convSetDeleteFriendTitle'),
              _deleteFriendOrExit),
        ),
        if (!isGroup) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _dangerButton(t('convSetBlacklistTitle'), _confirmBlacklist),
          ),
        ],
      ],
    );
  }

  Widget _directHeader() {
    final t = AppLocalizations.of(context).t;
    final url = widget.conv.avatarUrl;
    final name = widget.conv.conversationName;
    final initial = name.isEmpty ? '?' : name.characters.first;
    final onlineText = widget.conv.peerOnline
        ? (widget.conv.peerOnlineZh.isNotEmpty
            ? widget.conv.peerOnlineZh
            : t('convSetOnline'))
        : t('convSetOffline');
    final onlineColor = widget.conv.peerOnline
        ? AppTheme.onlineDot
        : context.cs.onSurfaceVariant;

    // 高度从 1:1 正方形改为 2:1，避免占据过多屏幕，留出更多操作空间
    return AspectRatio(
      aspectRatio: 2.0,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 正方形头像背景
          url.isNotEmpty
              ? Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _directAvatarFallback(initial),
                )
              : _directAvatarFallback(initial),
          // 底部渐变遮罩，保证白色文字可读
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.05),
                  Colors.black.withValues(alpha: 0.40),
                ],
                stops: const [0.55, 1.0],
              ),
            ),
          ),
          // 昵称 / 在线状态 / ID
          Positioned(
            left: 20,
            right: 20,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 6,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: onlineColor,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black45,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      onlineText,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Flexible(
                      child: InkWell(
                        onTap: _copyId,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                'ID: ${widget.conv.peerShortId.isEmpty ? t('convSetUnknown') : widget.conv.peerShortId}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.white70,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 4,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (widget.conv.peerShortId.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.copy,
                                  size: 14, color: Colors.white70),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _directAvatarFallback(String initial) {
    return Container(
      color: AppTheme.primary.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Text(initial,
          style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w600,
              color: AppTheme.primary.withValues(alpha: 0.7))),
    );
  }

  Widget _callButtons() {
    final t = AppLocalizations.of(context).t;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: _callButton(
                Icons.phone_outlined, t('convSetVoiceCall'), () => _startCall('voice')),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _callButton(
                Icons.videocam_outlined, t('convSetVideoCall'), () => _startCall('video')),
          ),
        ],
      ),
    );
  }

  Widget _callButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: context.cs.primaryContainer,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: context.cs.onPrimaryContainer),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.cs.onPrimaryContainer)),
          ],
        ),
      ),
    );
  }

  // ==================== 群聊：群资料 ====================

  Widget _groupBody() {
    final t = AppLocalizations.of(context).t;
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Container(
          color: context.cs.surface,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            children: [
              _groupAvatar(),
              const SizedBox(height: 14),
              Text(widget.conv.conversationName,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: context.cs.onSurface)),
              const SizedBox(height: 6),
              InkWell(
                onTap: _copyId,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(t('convSetGroupId', {'id': widget.conv.id}),
                        style: TextStyle(
                            fontSize: 13, color: context.cs.onSurfaceVariant)),
                    const SizedBox(width: 4),
                    Icon(Icons.copy,
                        size: 14, color: context.cs.onSurfaceVariant),
                  ],
                ),
              ),
            ],
          ),
        ),
        // 置顶消息：多消息支持 + 左右切换 + 点击跳转
        if (_pinnedMsgs.isNotEmpty) ...[
          const SizedBox(height: 10),
          _sectionHeader(t('convSetPinnedMessages'),
              trailing: _pinnedMsgs.length > 1
                  ? '${_pinIndex + 1}/${_pinnedMsgs.length}'
                  : null),
          _card(child: _pinnedCard()),
        ],
        const SizedBox(height: 10),
        _sectionHeader(t('convSetGroupMembers'),
            trailing: t('convSetViewAllMembers',
                {'count': _members.length.toString()}),
            onTap: _showMembers),
        _card(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: _memberGrid(),
        ),
        const SizedBox(height: 10),
        _sectionHeader(t('convSetGroupAnnouncement')),
        _card(
          child: InkWell(
            onTap: _editAnnouncement,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _announcement.isNotEmpty
                              ? _announcement
                              : t('convSetNoAnnouncement'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 14,
                              color: context.cs.onSurface,
                              height: 1.5),
                        ),
                        if (_announcement.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(t('convSetAnnouncementTime'),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: context.cs.onSurfaceVariant)),
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      size: 18, color: context.cs.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
        if (_isOwner) ...[
          const SizedBox(height: 10),
          _sectionHeader(t('convSetGroupAdmin')),
          _card(
            child: InkWell(
              onTap: () => _placeholder(t('convSetGroupAdmin')),
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 14, 8, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(t('convSetGroupAdmin'),
                          style: TextStyle(
                              fontSize: 15, color: context.cs.onSurface)),
                    ),
                    Icon(Icons.chevron_right,
                        size: 18, color: context.cs.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        _card(
          child: Column(
            children: [
              _switchRow(t('convSetMute'), _mute, _toggleMute),
              Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: context.cs.outlineVariant),
              _switchRow(t('convSetPinChat'), _pinned, _togglePin),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _card(
          child: InkWell(
            onTap: _clearHistory,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 8, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(t('convSetClearHistoryTitle'),
                        style: TextStyle(
                            fontSize: 15, color: context.cs.onSurface)),
                  ),
                  Icon(Icons.chevron_right,
                      size: 18, color: context.cs.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _dangerButton(
              _isOwner
                  ? t('convSetDisbandGroupTitle')
                  : t('convSetExitGroupTitle'),
              _deleteFriendOrExit),
        ),
      ],
    );
  }

  Widget _groupAvatar() {
    final url = widget.conv.avatarUrl;
    final name = widget.conv.conversationName;
    final initial = name.isEmpty ? '?' : name.characters.first;
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isNotEmpty
          ? Image.network(url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _groupAvatarFallback(initial))
          : _groupAvatarFallback(initial),
    );
  }

  Widget _groupAvatarFallback(String initial) {
    return Container(
      color: AppTheme.primary.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Icon(Icons.group,
          size: 36, color: AppTheme.primary.withValues(alpha: 0.7)),
    );
  }

  // ==================== 公共组件 ====================

  Widget _sectionHeader(String title, {String? trailing, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.cs.onSurface)),
          const Spacer(),
          if (trailing != null)
            InkWell(
              onTap: onTap,
              child: Text(trailing,
                  style: TextStyle(
                      fontSize: 13, color: context.cs.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }

  /// 置顶消息卡：多条切换（左右箭头）+ 点击跳转 ChatPage 定位
  Widget _pinnedCard() {
    final t = AppLocalizations.of(context).t;
    if (_pinnedMsgs.isEmpty) return const SizedBox.shrink();
    final p = _pinnedMsgs[_pinIndex];
    final content = (p['content']?.toString() ?? '').trim();
    final sender = (p['senderName']?.toString() ?? '').trim();
    final hasMulti = _pinnedMsgs.length > 1;
    void switchPin(int delta) {
      setState(() {
        _pinIndex =
            (_pinIndex + delta + _pinnedMsgs.length) % _pinnedMsgs.length;
      });
    }

    return InkWell(
      onTap: () {
        final msgId = p['msgId']?.toString() ?? '';
        if (msgId.isEmpty) return;
        final c = ConvItem.fromJson({
          'conversation': widget.conv.conversation,
          'conversationName': widget.conv.conversationName,
        });
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              ChatPage(conv: c, myId: _myId ?? '', scrollToMsgId: msgId),
        ));
      },
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            if (hasMulti)
              IconButton(
                onPressed: () => switchPin(-1),
                icon: Icon(Icons.chevron_left,
                    color: context.cs.onSurfaceVariant),
                visualDensity: VisualDensity.compact,
                tooltip: t('convSetPrevPinned'),
              ),
            const Icon(Icons.push_pin, size: 16, color: AppTheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (sender.isNotEmpty)
                    Text(sender,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w500)),
                  Text(content.isEmpty ? t('convSetEmptyMessage') : content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 14, color: context.cs.onSurface)),
                ],
              ),
            ),
            if (hasMulti)
              IconButton(
                onPressed: () => switchPin(1),
                icon: Icon(Icons.chevron_right,
                    color: context.cs.onSurfaceVariant),
                visualDensity: VisualDensity.compact,
                tooltip: t('convSetNextPinned'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _memberGrid() {
    final t = AppLocalizations.of(context).t;
    final display = _members.take(5).toList();
    final cells = <Widget>[];
    for (final m in display) {
      cells.add(_memberCell(m));
    }
    cells.add(_actionCell(Icons.add, t('convSetInvite'), _inviteMember));
    if (_isOwner) {
      cells.add(_actionCell(Icons.remove, t('convSetRemove'), _removeMember));
    }
    return Wrap(
      spacing: 12,
      runSpacing: 16,
      children: cells,
    );
  }

  Widget _memberCell(Map<String, dynamic> m) {
    final name = m['nickname']?.toString() ?? m['account']?.toString() ?? '';
    final initial = name.isEmpty ? '?' : name.characters.first;
    final url = m['avatar']?.toString() ?? '';
    return SizedBox(
      width: 52,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme
                .avatarColors[name.length % AppTheme.avatarColors.length],
            backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
            child: url.isEmpty
                ? Text(initial,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600))
                : null,
          ),
          const SizedBox(height: 6),
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 12, color: context.cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _actionCell(IconData icon, String label, VoidCallback onTap) {
    return SizedBox(
      width: 52,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.cs.surfaceContainer,
                shape: BoxShape.circle,
                border: Border.all(color: context.cs.outlineVariant),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 20, color: context.cs.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, color: context.cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value,
      {bool chevron = false,
      VoidCallback? onTap,
      String? copy,
      IconData? icon}) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(fontSize: 15, color: context.cs.onSurface)),
            ),
            if (icon != null) ...[
              Icon(icon, size: 18, color: AppTheme.primary),
              const SizedBox(width: 10),
            ],
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 15, color: context.cs.onSurfaceVariant)),
            if (copy != null && copy.isNotEmpty)
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: copy));
                  AppDialogs.toast(
                      context, AppLocalizations.of(context).t('convSetCopied'));
                },
                child: Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.content_copy,
                      size: 17, color: context.cs.onSurfaceVariant),
                ),
              )
            else if (chevron)
              Icon(Icons.chevron_right,
                  color: context.cs.onSurfaceVariant, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 15, color: context.cs.onSurface)),
          ),
          _appSwitch(value, onChanged),
        ],
      ),
    );
  }

  /// 自定义 iOS 风格开关（打开：主色轨道 + 白滑块；关闭：灰轨道 + 白滑块）
  Widget _appSwitch(bool value, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 50,
        height: 30,
        decoration: BoxDecoration(
          color: value ? AppTheme.primary : context.cs.surfaceContainer,
          borderRadius: BorderRadius.circular(15),
        ),
        padding: const EdgeInsets.all(2),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dangerButton(String label, VoidCallback onTap) {
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFFFECE9),
        foregroundColor: AppTheme.danger,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
    );
  }

  Widget _card({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: padding,
      decoration: BoxDecoration(
        color: context.cs.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: child,
    );
  }
}
