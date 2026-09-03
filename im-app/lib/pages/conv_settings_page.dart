import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:image_picker/image_picker.dart';

import '../l10n/app_locale.dart';
import '../services/api_client.dart';
import '../services/call_service.dart';
import '../services/conversation_service.dart';
import '../services/friend_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_dialogs.dart';
import 'chat_page.dart';
import 'group_manage_page.dart';
import 'group_members_page.dart';
import 'group_qr_page.dart';
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
  // 单聊对方靓号信息（从成员接口自取，覆盖所有进入路径的显示一致性）
  String _peerShortId = '';
  bool _peerVip = false;
  // 群聊管理相关
  bool _uploadingAvatar = false;
  bool _privacyOn = false; // 老服务端兼容：成员接口报 4006 时置位
  Map<String, dynamic> _groupSettings = {}; // 群设置（普通成员可读，判断成员隐私）
  String _avatarOverride = ''; // 群主刚上传的头像（本地立即生效，不等列表刷新）
  String _nameOverride = ''; // 群主刚改的群名（本地立即生效）

  bool get isGroup => (widget.conv.conversation['type'] as num?)?.toInt() == 2;

  String get _groupName =>
      _nameOverride.isNotEmpty ? _nameOverride : widget.conv.conversationName;

  String get _avatarUrl =>
      _avatarOverride.isNotEmpty ? _avatarOverride : widget.conv.avatarUrl;

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

  /// 群主或管理员（成员管理操作用）
  bool get _isManager {
    if (_myId == null) return false;
    return _members.any((m) {
      final role = (m['role'] as num?)?.toInt() ?? 3;
      final uid = m['id']?.toString() ?? m['userId']?.toString() ?? '';
      return uid == _myId && (role == 1 || role == 2);
    });
  }

  /// 成员隐私开启且我是普通成员：最多显示 2 排成员预览，不可查看全部
  bool get _privacyLimited =>
      !_isManager && (_groupSettings['privacyEnabled'] == true || _privacyOn);

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
      _loadGroupSettings();
    }
  }

  /// 群设置（普通成员也可读）：判断成员隐私是否开启
  Future<void> _loadGroupSettings() async {
    try {
      final s = await _svc.groupSettings(widget.conv.id);
      if (mounted) setState(() => _groupSettings = s);
    } catch (_) {}
  }

  Future<void> _loadProfile() async {
    try {
      final p = await _friendSvc.profile();
      if (mounted) {
        setState(() => _myId = p['id']?.toString());
        // 单聊：从成员接口自取对方靓号信息（会话列表/通讯录/新会话等
        // 各入口构造的 ConvItem 不一定带 peerShortId，这里兜底保证显示一致）
        if (!isGroup) await _loadDirectPeer();
      }
    } catch (_) {}
  }

  Future<void> _loadDirectPeer() async {
    try {
      final list = await _svc.members(widget.conv.id);
      for (final m in list) {
        final uid = m['id']?.toString() ?? m['userId']?.toString() ?? '';
        if (uid.isNotEmpty && uid != _myId) {
          if (!mounted) return;
          setState(() {
            _peerShortId = m['shortId']?.toString() ?? '';
            _peerVip = m['vipShortId'] == true;
          });
          return;
        }
      }
    } catch (_) {}
  }

  Future<void> _loadMembers() async {
    try {
      final list = await _svc.members(widget.conv.id);
      if (mounted) {
        setState(() {
          _members = list;
          _privacyOn = false;
        });
      }
    } on ApiException catch (e) {
      // 4006：群主开启成员隐私 → 普通成员显示隐私提示而不是报错
      if (e.code == 4006 && mounted) {
        setState(() {
          _members = [];
          _privacyOn = true;
        });
      }
    } catch (_) {}
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

  /// 单聊对方的 shortId：优先会话数据，缺失时用成员接口自取值兜底
  String get _resolvedPeerShortId => widget.conv.peerShortId.isNotEmpty
      ? widget.conv.peerShortId
      : _peerShortId;

  void _copyId() {
    final v = isGroup ? widget.conv.id : _resolvedPeerShortId;
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

  /// 查看全部成员 → 群成员页（管理：邀请/移除/禁言/设管理员）
  Future<void> _showMembers() async {
    await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => GroupMembersPage(conv: widget.conv)));
    if (mounted) _loadMembers();
  }

  /// 群聊管理页（群主：二维码进群/成员隐私/全员禁言/允许邀请/管理员）
  Future<void> _openGroupManage() async {
    await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => GroupManagePage(conv: widget.conv)));
    if (mounted) _loadMembers();
  }

  /// 群主上传群头像：相册选图 → 上传 → 更新会话
  Future<void> _changeGroupAvatar() async {
    if (_uploadingAvatar) return;
    final t = AppLocalizations.of(context).t;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() => _uploadingAvatar = true);
    try {
      final up = await ApiClient.instance.uploadFile(
        picked.path,
        picked.name.isEmpty ? 'group_avatar.jpg' : picked.name,
        dir: 'avatar/',
      );
      final url = (up['url'] ?? '').toString();
      if (url.isEmpty) throw Exception('upload failed');
      await _svc.updateGroupInfo(widget.conv.id, avatar: url);
      // 回写会话对象：返回会话列表/聊天页立即可见
      widget.conv.conversation['avatar'] = url;
      if (mounted) {
        setState(() => _avatarOverride = url);
        AppDialogs.toast(context, t('groupAvatarUpdated'));
      }
    } catch (_) {
      if (mounted) AppDialogs.toast(context, t('groupAvatarUpdateFailed'));
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  /// 群主修改群名（双语同值，App 内单语言展示）
  Future<void> _editGroupName() async {
    final t = AppLocalizations.of(context).t;
    final result = await AppDialogs.input(
      context,
      title: t('groupRenameTitle'),
      hint: t('groupRenameHint'),
      maxLines: 1,
      maxLength: 32,
      initialValue: _nameOverride.isNotEmpty
          ? _nameOverride
          : widget.conv.conversationName,
    );
    if (result == null || result.trim().isEmpty) return;
    final name = result.trim();
    try {
      await _svc.updateGroupInfo(widget.conv.id, name: name);
      widget.conv.conversation['nameZh'] = name;
      widget.conv.conversation['nameEn'] = name;
      if (mounted) {
        setState(() => _nameOverride = name);
        AppDialogs.toast(context, t('groupRenameSaved'));
      }
    } catch (_) {
      if (mounted) AppDialogs.toast(context, t('groupRenameFailed'));
    }
  }

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
        ? (_isOwner
            ? t('convSetDisbandGroupTitle')
            : t('convSetExitGroupTitle'))
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
        title: Text(
            isGroup ? t('convSetGroupProfile') : t('convSetPersonalProfile'),
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
    // 卡片间距统一为 10（与群聊资料页一致），不再 24/10 混用
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _directHeader(),
        const SizedBox(height: 10),
        _callButtons(),
        const SizedBox(height: 10),
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
              padding: EdgeInsets.fromLTRB(16, 14, 16, 14),
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
        const SizedBox(height: 10),
        // 危险操作：合并为一张卡片的居中红字行（微信式），
        // 替换原来两个堆叠的浅红大按钮——硬编码浅红底在深色模式下尤其突兀
        _card(
          child: Column(
            children: [
              _dangerRow(
                  isGroup
                      ? (_isOwner
                          ? t('convSetDisbandGroupTitle')
                          : t('convSetExitGroupTitle'))
                      : t('convSetDeleteFriendTitle'),
                  _deleteFriendOrExit),
              if (!isGroup) ...[
                Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: context.cs.outlineVariant),
                _dangerRow(t('convSetBlacklistTitle'), _confirmBlacklist),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _directHeader() {
    final t = AppLocalizations.of(context).t;
    final url = widget.conv.avatarUrl;
    final name = widget.conv.conversationName;
    final initial = name.isEmpty ? '?' : name.characters.first;
    // 对方是否靓号（服务端预留池校验，随会话/成员数据下发）
    final shortId = _resolvedPeerShortId;
    final isVipPeer =
        (widget.conv.peerVipShortId || _peerVip) && shortId.isNotEmpty;
    // 在线显示在线+设备；离线且有最近上线记录 → 显示"最近上线 xx"
    final onlineText = widget.conv.peerOnline
        ? (widget.conv.peerOnlineZh.isNotEmpty
            ? widget.conv.peerOnlineZh
            : t('convSetOnline'))
        : _lastSeenText();
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
                              // 靓号好友只显示「靓ID：xxx」徽标，不再重复显示普通 ID
                              child: isVipPeer
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: const Color(0xFFE5484D),
                                            width: 1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        t('vipIdBadge', {'id': shortId}),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    )
                                  : Text(
                                      'ID: ${shortId.isEmpty ? t('convSetUnknown') : shortId}',
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
                            if (shortId.isNotEmpty) ...[
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

  /// 离线状态文案：有最近上线记录显示"最近上线 xx"，否则回退"离线"
  String _lastSeenText() {
    final t = AppLocalizations.of(context).t;
    final dt = DateTime.tryParse(widget.conv.lastLoginAt);
    if (dt == null) return t('convSetOffline');
    final diff = DateTime.now().difference(dt);
    final time = diff.inMinutes < 1
        ? t('timeJustNow')
        : diff.inMinutes < 60
            ? t('timeMinAgo', {'n': '${diff.inMinutes}'})
            : diff.inHours < 24
                ? t('timeHourAgo', {'n': '${diff.inHours}'})
                : diff.inDays < 7
                    ? t('timeDayAgo', {'n': '${diff.inDays}'})
                    : '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    return t('convSetLastSeen', {'time': time});
  }

  Widget _callButtons() {
    final t = AppLocalizations.of(context).t;
    // 一张卡片承载两个圆形操作，视觉成组、不散
    return _card(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          Expanded(
            child: _callButton(Icons.phone_outlined, t('convSetVoiceCall'),
                () => _startCall('voice')),
          ),
          Expanded(
            child: _callButton(Icons.videocam_outlined, t('convSetVideoCall'),
                () => _startCall('video')),
          ),
        ],
      ),
    );
  }

  Widget _callButton(IconData icon, String label, VoidCallback onTap) {
    // 圆形浅色底图标 + 下方小字（与「我的」页大按钮同款语言），替代色块/描边按钮
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 24, color: AppTheme.primary),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: context.cs.onSurface)),
        ],
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            children: [
              // 群头像：群主可点击更换（相册选图上传）
              _groupAvatar(),
              const SizedBox(height: 14),
              // 群名：群主可点击修改
              InkWell(
                onTap: _isOwner ? _editGroupName : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(_groupName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: context.cs.onSurface)),
                    ),
                    if (_isOwner) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.edit_outlined,
                          size: 15, color: context.cs.onSurfaceVariant),
                    ],
                  ],
                ),
              ),
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
        // 成员区：隐私开启时普通成员最多 2 排预览（多余不显示、不可查看全部）
        _membersSection(),
        const SizedBox(height: 10),
        _sectionHeader(t('convSetGroupAnnouncement')),
        _card(
          child: InkWell(
            onTap: _editAnnouncement,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
        // 群二维码（全体成员可见，分享扫码进群）
        const SizedBox(height: 10),
        _sectionHeader(t('groupQrSection')),
        _card(
          child: InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => GroupQrPage(conv: widget.conv))),
            child: Padding(
              // 与群管理/清空记录等行完全一致的结构，保证箭头像素级对齐
              padding: EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Icon(Icons.qr_code_2, size: 26, color: AppTheme.primary),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(t('groupQrRow'),
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
        if (_isOwner) ...[
          const SizedBox(height: 10),
          _sectionHeader(t('convSetGroupAdmin')),
          _card(
            child: InkWell(
              onTap: _openGroupManage,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 14, 16, 14),
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
              padding: EdgeInsets.fromLTRB(16, 14, 16, 14),
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
        const SizedBox(height: 10),
        _card(
          child: _dangerRow(
              _isOwner
                  ? t('convSetDisbandGroupTitle')
                  : t('convSetExitGroupTitle'),
              _deleteFriendOrExit),
        ),
      ],
    );
  }

  Widget _groupAvatar() {
    final url = _avatarUrl;
    final name = _groupName;
    final initial = name.isEmpty ? '?' : name.characters.first;
    return InkWell(
      onTap: _isOwner ? _changeGroupAvatar : null,
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          Container(
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
          ),
          // 群主可换头像：右下角相机角标（上传中转菊花）
          if (_isOwner)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: context.cs.surface.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: _uploadingAvatar
                    ? const SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.photo_camera_outlined,
                        size: 15, color: context.cs.onSurfaceVariant),
              ),
            ),
        ],
      ),
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

  /// 成员区：隐私开启时普通成员最多 2 排预览（无查看全部入口）
  Widget _membersSection() {
    final t = AppLocalizations.of(context).t;
    final limited = _privacyLimited;
    // 老服务端兼容：隐私模式下成员接口报 4006 → 列表为空，显示提示卡片
    if (limited && _members.isEmpty) {
      return Column(
        children: [
          _sectionHeader(t('convSetGroupMembers')),
          _card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline,
                      size: 18, color: context.cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(t('groupPrivacyHint'),
                      style: TextStyle(
                          fontSize: 14, color: context.cs.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        limited
            ? _sectionHeader(t('convSetGroupMembers'))
            : _sectionHeader(t('convSetGroupMembers'),
                trailing: t('convSetViewAllMembers',
                    {'count': _members.length.toString()}),
                onTap: _showMembers),
        _card(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: _memberGrid(),
        ),
      ],
    );
  }

  Widget _memberGrid() {
    final t = AppLocalizations.of(context).t;
    final limited = _privacyLimited;
    return LayoutBuilder(builder: (context, constraints) {
      const spacing = 12.0;
      final width = constraints.maxWidth;
      // 每格 52 宽 + 12 间距：按卡片实际宽度动态算列数，让每排铺满卡片（不留斜边）
      final cols = ((width + spacing) / (52 + spacing)).floor().clamp(1, 20);
      final cellW = (width - spacing * (cols - 1)) / cols;
      // 资料页固定最多 2 排预览（隐私模式多余不显示；普通模式点"查看全部"进成员页）
      final maxShow = cols * 2;
      // 邀请/移除格子也占位，成员格子数 = 2排总格数 - 功能格数，保证总数不超 2 排
      final actionCount = (!limited ? 1 : 0) + (!limited && _isManager ? 1 : 0);
      final memberMax = (maxShow - actionCount).clamp(0, _members.length);
      final cells = <Widget>[];
      var shown = 0;
      for (final m in _members) {
        if (shown >= memberMax) break;
        cells.add(_memberCell(m, cellW));
        shown++;
      }
      if (!limited) {
        cells.add(_actionCell(Icons.add, t('convSetInvite'), _showMembers,
            width: cellW));
        if (_isManager) {
          cells.add(_actionCell(Icons.remove, t('convSetRemove'), _showMembers,
              width: cellW));
        }
      }
      return Wrap(
        spacing: spacing,
        runSpacing: 16,
        children: cells,
      );
    });
  }

  Widget _memberCell(Map<String, dynamic> m, double width) {
    final t = AppLocalizations.of(context).t;
    final name = m['nickname']?.toString() ?? m['account']?.toString() ?? '';
    final initial = name.isEmpty ? '?' : name.characters.first;
    final url = m['avatar']?.toString() ?? '';
    final role = (m['role'] as num?)?.toInt() ?? 3;
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
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
              // 群主标识：头像右上角小角标
              if (role == 1)
                Positioned(
                  top: -3,
                  right: -6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.orange,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: Theme.of(context).colorScheme.surface,
                          width: 1),
                    ),
                    child: Text(t('groupRoleOwner'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
            ],
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

  Widget _actionCell(IconData icon, String label, VoidCallback onTap,
      {double width = 52}) {
    return SizedBox(
      // 与成员格同宽（cellW），保证同排内头像圆心/文字中心像素级对齐
      width: width,
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

  /// 危险操作行：surface 底 + 居中红字（微信「删除联系人」样式）。
  /// 不自带上边距，由调用处用 _card 包裹并控制间距；
  /// 深浅色都走主题色，避免硬编码浅红底在深色模式下突兀。
  Widget _dangerRow(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppTheme.danger)),
      ),
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
