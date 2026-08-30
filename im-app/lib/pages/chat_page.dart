import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_client.dart';
import '../services/conversation_service.dart';
import '../services/ws_service.dart';
import '../theme/app_theme.dart';
import 'conv_settings_page.dart';
import 'video_call_page.dart';
import 'voice_call_page.dart';

/// 消息本地状态
enum MsgStatus { sending, sent, read, failed }

class ChatMsg {
  final String? msgId;
  final String clientMsgId;
  final String senderId;
  final int type; // 1 文本 / 2 图片 / 3 文件 / 8 红包 / 9 转账
  String content;
  bool recalled;
  String? replyTo;
  int? seq;
  String? createdAt;
  String? deliveryState; // sent / read（单聊对方已读标记）
  MsgStatus status;

  ChatMsg({
    this.msgId,
    required this.clientMsgId,
    required this.senderId,
    required this.type,
    required this.content,
    this.recalled = false,
    this.replyTo,
    this.seq,
    this.createdAt,
    this.deliveryState,
    this.status = MsgStatus.sent,
  });

  factory ChatMsg.fromServer(Map<String, dynamic> m) => ChatMsg(
        msgId: m['msgId']?.toString(),
        clientMsgId: m['clientMsgId']?.toString() ?? '',
        senderId: m['senderId']?.toString() ?? '',
        type: (m['type'] as num?)?.toInt() ?? 1,
        content: m['content']?.toString() ?? '',
        recalled: m['recalled'] == true,
        replyTo: m['replyTo']?.toString(),
        seq: (m['seq'] as num?)?.toInt(),
        createdAt: m['createdAt']?.toString(),
        deliveryState: m['deliveryState']?.toString(),
      );

  /// 是否为有效引用（后端 replyTo 为 0/空时不算引用）
  bool get hasReply {
    final r = replyTo;
    return r != null && r.isNotEmpty && r != '0';
  }
}

/// 聊天页（对齐 Aura Messaging 设计稿图 4/5/6/7）
/// 顶栏 + 置顶条 + 消息列表 + 浮动↓按钮 + 输入栏 + 4×2 抽屉 + 长按全屏遮罩
class ChatPage extends StatefulWidget {
  final ConvItem conv;
  final String myId;
  const ChatPage({super.key, required this.conv, required this.myId});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _svc = ConversationService();
  final _api = ApiClient.instance;
  final _input = TextEditingController();
  final _scroll = ScrollController();

  List<ChatMsg> _msgs = [];
  WsService? _ws;
  bool _loading = true;
  int _lastSeq = 0;
  bool _showJumpBtn = false; // 是否显示"↓"按钮

  // 群功能
  List<Map<String, dynamic>> _members = [];
  final Set<String> _mentionIds = {};
  ChatMsg? _quoteMsg;

  // 长按全屏遮罩状态
  ChatMsg? _longPressedMsg;

  bool get isGroup => (widget.conv.conversation['type'] as num?)?.toInt() == 2;

  @override
  void initState() {
    super.initState();
    _init();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    final pos = _scroll.position;
    if (!pos.hasContentDimensions) return;
    final farFromBottom = pos.maxScrollExtent - pos.pixels > 100;
    if (mounted && farFromBottom != _showJumpBtn) {
      setState(() => _showJumpBtn = farFromBottom);
    }
  }

  Future<void> _init() async {
    await _loadHistory();
    await _connectWs();
    _reportRead();
    if (isGroup) _loadMembers();
  }

  /// 上报已读（取列表最后一条已收 msgId；失败忽略）
  Future<void> _reportRead() async {
    if (_msgs.isEmpty) return;
    final last = _msgs.last;
    if (last.msgId == null) return;
    try {
      await _svc.markRead(widget.conv.id, last.msgId!);
    } catch (_) {}
  }

  Future<void> _loadMembers() async {
    try {
      final list = await _svc.members(widget.conv.id);
      if (mounted) setState(() => _members = list);
    } catch (_) {}
  }

  Future<void> _loadHistory() async {
    try {
      final list = await _svc.history(widget.conv.id);
      if (mounted) {
        setState(() {
          _msgs = list.map(ChatMsg.fromServer).toList();
          // 需求3：历史消息里自己发的、deliveryState=read → 标为已读
          for (final x in _msgs) {
            if (x.senderId == widget.myId && x.deliveryState == 'read') {
              x.status = MsgStatus.read;
            }
          }
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _connectWs() async {
    try {
      final token = await _api.readToken();
      if (token == null) return;
      _ws = WsService(
          onMessage: (m) => _handleWs(m),
          onRecall: (m) {
            // 撤回通知：本地把对应消息标为 recalled
            if (!mounted) return;
            final id = m['msgId']?.toString();
            if (id == null) return;
            setState(() {
              for (final x in _msgs) {
                if (x.msgId == id) x.recalled = true;
              }
            });
          },
          onRead: (m) {
            // 对方已读：把本地自己发的对应消息标为已读
            if (!mounted) return;
            final convId = m['conversationId']?.toString();
            if (convId != widget.conv.id) return;
            final msgId = m['msgId']?.toString();
            if (msgId == null) return;
            setState(() {
              for (final x in _msgs) {
                if (x.msgId == msgId && x.senderId == widget.myId) {
                  x.status = MsgStatus.read;
                }
              }
            });
          },
          onReconnected: () {
            // 重连后做一次补拉
            _svc.sync(widget.conv.id, _lastSeq).then((list) {
              if (list.isEmpty || !mounted) return;
              final added = list.map(ChatMsg.fromServer).toList();
              added.sort((a, b) => (a.seq ?? 0).compareTo(b.seq ?? 0));
              setState(() => _msgs.addAll(added));
              _scrollToBottom();
            });
          });
      _ws!.connect(token);
    } catch (_) {}
  }

  void _handleWs(Map<String, dynamic> m) {
    final convId = m['conversationId']?.toString();
    if (convId != widget.conv.id) return;
    final msg = ChatMsg.fromServer(m);
    final seqNow = msg.seq ?? 0;
    if (seqNow > _lastSeq) _lastSeq = seqNow;
    if (mounted) {
      setState(() {
        // 幂等去重
        if (_msgs.any((x) => x.clientMsgId.isNotEmpty && x.clientMsgId == msg.clientMsgId)) return;
        _msgs.add(msg);
        _msgs.sort((a, b) => (a.seq ?? 0).compareTo(b.seq ?? 0));
      });
      _scrollToBottom();
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();

    // 本地乐观插入
    final clientMsgId = _uuid();
    final q = _quoteMsg;
    setState(() => _quoteMsg = null);
    final local = ChatMsg(
      clientMsgId: clientMsgId,
      senderId: widget.myId,
      type: 1,
      content: text,
      status: MsgStatus.sending,
      replyTo: q?.msgId,
    );
    setState(() => _msgs.add(local));
    _scrollToBottom();

    try {
      final resp = await _svc.send(widget.conv.id, text, clientMsgId: clientMsgId);
      setState(() {
        final idx = _msgs.indexWhere((x) => x.clientMsgId == clientMsgId);
        if (idx >= 0) {
          _msgs[idx] = ChatMsg.fromServer(resp);
          final seqNow = (resp['seq'] as num?)?.toInt() ?? 0;
          if (seqNow > 0) _lastSeq = max(_lastSeq, seqNow);
          _msgs.sort((a, b) => (a.seq ?? 0).compareTo(b.seq ?? 0));
        }
      });
    } catch (_) {
      setState(() {
        final idx = _msgs.indexWhere((x) => x.clientMsgId == clientMsgId);
        if (idx >= 0) _msgs[idx].status = MsgStatus.failed;
      });
    }
  }

  void _retry(ChatMsg m) async {
    final i = _msgs.indexOf(m);
    if (i < 0) return;
    setState(() => _msgs[i].status = MsgStatus.sending);
    try {
      final resp = await _svc.send(widget.conv.id, m.content, clientMsgId: m.clientMsgId);
      if (!mounted) return;
      setState(() {
        if (i >= 0) _msgs[i] = ChatMsg.fromServer(resp);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (i >= 0) _msgs[i].status = MsgStatus.failed;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(_scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    });
  }

  String _uuid() => DateTime.now().microsecondsSinceEpoch.toString() +
      '-' + Random().nextInt(99999).toString();

  String _time(String? iso) {
    if (iso == null) return '';
    DateTime? dt;
    try {
      dt = DateTime.parse(iso);
    } catch (_) {
      return '';
    }
    if (dt == null) return '';
    final now = DateTime.now();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '$h:$m';
    }
    return '${dt.month}/${dt.day} $h:$m';
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _ws?.close();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _openSettings() async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => ConvSettingsPage(conv: widget.conv)));
    if (changed == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  /// 需求11：发起语音/视频通话（TRTC，单聊）
  void _openCall(String type) {
    if (isGroup) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('暂仅支持单聊通话')));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => type == 'video'
            ? VideoCallPage(
                peerName: widget.conv.conversationName,
                convId: widget.conv.id)
            : VoiceCallPage(
                peerName: widget.conv.conversationName,
                convId: widget.conv.id)));
  }

  void _pickMention() async {
    if (_members.isEmpty) await _loadMembers();
    if (!mounted) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('选择@成员',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            ListTile(
              leading: const CircleAvatar(
                  backgroundColor: AppTheme.surface, child: Icon(Icons.group)),
              title: const Text('@所有人', style: TextStyle(fontSize: 15)),
              onTap: () => Navigator.of(context).pop('@所有人'),
            ),
            ..._members.map((m) => ListTile(
                  leading: CircleAvatar(
                      backgroundColor: AppTheme.surface,
                      child: Text(
                          (m['nickname']?.toString().characters.first ?? '?'),
                          style: const TextStyle(color: AppTheme.primary))),
                  title: Text(m['nickname']?.toString() ?? '',
                      style: const TextStyle(fontSize: 15)),
                  onTap: () => Navigator.of(context).pop(m['nickname']?.toString() ?? ''),
                )),
          ],
        ),
      ),
    );
    if (picked != null && picked.isNotEmpty) {
      final cur = _input.text;
      final insertion = '@$picked ';
      _input.text = cur + insertion;
      _input.selection = TextSelection.collapsed(offset: _input.text.length);
    }
  }

  // ====== 长按消息：全屏高亮 + 回复模式（图 7）======
  void _showLongPressOverlay(ChatMsg m) {
    if (m.recalled || m.msgId == null) return;
    setState(() => _longPressedMsg = m);
    HapticFeedback.lightImpact();
  }

  void _closeLongPressOverlay() {
    setState(() => _longPressedMsg = null);
  }

  /// 撤回
  Future<void> _recall(ChatMsg m) async {
    _closeLongPressOverlay();
    if (m.msgId == null) return;
    final ok = await _svc.recall(m.msgId!);
    if (!mounted) return;
    if (ok) {
      setState(() => m.recalled = true);
      _toast('已撤回');
    } else {
      _toast('撤回失败（超过2分钟或无权限）');
    }
  }

  /// 复制
  void _copy(ChatMsg m) {
    _closeLongPressOverlay();
    Clipboard.setData(ClipboardData(text: m.content));
    _toast('已复制');
  }

  /// 收藏
  Future<void> _favorite(ChatMsg m) async {
    _closeLongPressOverlay();
    if (m.msgId == null) return;
    final ok = await _svc.favoriteAdd(widget.conv.id, m.msgId!);
    _toast(ok ? '已收藏' : '收藏失败');
  }

  /// 引用
  void _quote(ChatMsg m) {
    _closeLongPressOverlay();
    setState(() => _quoteMsg = m);
  }

  /// 转发（占位：以后接好友选择器）
  void _forward(ChatMsg m) {
    _closeLongPressOverlay();
    _toast('选择转发对象（V2.0 上线）');
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final pinnedContent =
        widget.conv.conversation['pinnedMsgContent']?.toString() ?? '';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // ===== 顶栏 =====
            _topBar(),
            // ===== 置顶消息条 =====
            if (pinnedContent.isNotEmpty) _pinnedBar(pinnedContent),
            // ===== 消息列表 + 浮动↓按钮 =====
            Expanded(
              child: Stack(
                children: [
                  _loading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                          itemCount: _msgs.length,
                          itemBuilder: (_, i) {
                            final m = _msgs[i];
                            return _MsgRow(
                              msg: m,
                              colors: _bubbleColors,
                              myId: widget.myId,
                              isMine: m.senderId == widget.myId,
                              highlighted: _longPressedMsg?.clientMsgId == m.clientMsgId,
                              onLongPress: () => _showLongPressOverlay(m),
                              timeText: _time(m.createdAt),
                              onRetry: m.status == MsgStatus.failed
                                  ? () => _retry(m)
                                  : null,
                            );
                          },
                        ),
                  // ===== 浮动↓按钮 =====
                  if (_showJumpBtn)
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: _JumpToBottomBtn(
                        onTap: _scrollToBottom,
                      ),
                    ),
                ],
              ),
            ),
            // ===== 输入栏 =====
            _InputBar(
              controller: _input,
              quoteMsg: _quoteMsg,
              onClearQuote: () => setState(() => _quoteMsg = null),
              onSend: _send,
              onMention: isGroup ? _pickMention : null,
              onCall: (type) => _openCall(type),
            ),
          ],
        ),
      ),
      // ===== 长按全屏遮罩 =====
      bottomSheet: _longPressedMsg == null
          ? null
          : _LongPressOverlay(
              msg: _longPressedMsg!,
              convName: widget.conv.conversationName,
              myId: widget.myId,
              colors: _bubbleColors,
              onClose: _closeLongPressOverlay,
              onCopy: () => _copy(_longPressedMsg!),
              onQuote: () => _quote(_longPressedMsg!),
              onRecall: () => _recall(_longPressedMsg!),
              onFavorite: () => _favorite(_longPressedMsg!),
              onForward: () => _forward(_longPressedMsg!),
              onSend: (text) {
                // 回复：直接复用普通 send，replyTo 携带
                _sendReply(text, _longPressedMsg!);
                _closeLongPressOverlay();
              },
            ),
    );
  }

  Future<void> _sendReply(String text, ChatMsg replyTo) async {
    final clientMsgId = _uuid();
    final local = ChatMsg(
      clientMsgId: clientMsgId,
      senderId: widget.myId,
      type: 1,
      content: text,
      status: MsgStatus.sending,
      replyTo: replyTo.msgId,
    );
    setState(() => _msgs.add(local));
    _scrollToBottom();
    try {
      final resp = await _svc.send(widget.conv.id, text, clientMsgId: clientMsgId);
      setState(() {
        final idx = _msgs.indexWhere((x) => x.clientMsgId == clientMsgId);
        if (idx >= 0) {
          _msgs[idx] = ChatMsg.fromServer(resp);
          _msgs.sort((a, b) => (a.seq ?? 0).compareTo(b.seq ?? 0));
        }
      });
    } catch (_) {
      setState(() {
        final idx = _msgs.indexWhere((x) => x.clientMsgId == clientMsgId);
        if (idx >= 0) _msgs[idx].status = MsgStatus.failed;
      });
    }
  }

  /// 顶栏：← 返回 + 居中（标题 + 在线状态） + 右侧 ··· 三点
  Widget _topBar() {
    // 在线状态：从会话数据读取（后端 peerOnline + peerOnlineDev）
    final isGroupType = isGroup;
    final peerOnline = widget.conv.peerOnline;
    final peerDev = widget.conv.peerOnlineDev;
    final hasMobile = peerDev.any((d) => d == 'ios' || d == 'android');
    final statusText = isGroupType
        ? ''
        : (peerOnline ? (hasMobile ? '手机在线' : '电脑在线') : '离线');
    return Container(
      decoration: const BoxDecoration(
          color: AppTheme.background,
          border: Border(bottom: BorderSide(color: AppTheme.divider, width: 0.5))),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.chevron_left, size: 28, color: AppTheme.textPrimary),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(widget.conv.conversationName,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
                if (statusText.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(statusText,
                      style: TextStyle(
                          fontSize: 11,
                          color: peerOnline ? AppTheme.primary : AppTheme.textTertiary)),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: _openSettings,
            icon: const Icon(Icons.more_horiz, size: 24, color: AppTheme.textPrimary),
          ),
        ],
      ),
    );
  }

  /// 置顶消息条
  Widget _pinnedBar(String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      color: AppTheme.pinnedBar,
      child: Row(
        children: [
          const Icon(Icons.push_pin, size: 14, color: AppTheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '置顶消息：$content',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  static const _bubbleColors = [
    Color(0xFF0088CC), Color(0xFF6ACCFF), Color(0xFF7B61FF),
    Color(0xFF00B42A), Color(0xFFFF7D00), Color(0xFFBA1A1A),
  ];
}

// ======================= 消息行（支持多种类型气泡 + 长按高亮） =======================

class _MsgRow extends StatelessWidget {
  final ChatMsg msg;
  final List<Color> colors;
  final String myId;
  final bool isMine;
  final bool highlighted;
  final VoidCallback onLongPress;
  final String timeText;
  final VoidCallback? onRetry;

  const _MsgRow({
    required this.msg,
    required this.colors,
    required this.myId,
    required this.isMine,
    required this.highlighted,
    required this.onLongPress,
    required this.timeText,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colorIdx = msg.senderId.hashCode.abs() % colors.length;
    final senderColor = colors[colorIdx];
    // 小助手（虚拟 uid -1）头像显示"助"
    final senderText = msg.senderId == '-1'
        ? '助'
        : (msg.senderId.length > 6
            ? msg.senderId.substring(msg.senderId.length - 2)
            : msg.senderId);

    Widget bubble;
    switch (msg.type) {
      case 2: // 图片
        bubble = _ImageGridBubble(urls: _parseImages(msg.content));
        break;
      case 3: // 文件
        bubble = _FileBubble(name: msg.content);
        break;
      case 8: // 红包
        bubble = const _RedPacketBubble();
        break;
      case 9: // 转账
        bubble = _TransferBubble(amount: msg.content);
        break;
      default:
        if (msg.recalled) {
          bubble = Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: const Text('消息已撤回',
                style: TextStyle(fontSize: 13, color: AppTheme.textTertiary)),
          );
        } else {
          bubble = Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMine ? AppTheme.primary : Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusBubble),
              border: isMine ? null : Border.all(color: AppTheme.divider, width: 0.5),
              boxShadow: [
                if (highlighted)
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 0),
                  ),
              ],
            ),
            constraints: const BoxConstraints(maxWidth: 280),
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (msg.hasReply)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isMine ? Colors.white24 : const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('引用了一条消息',
                        style: TextStyle(fontSize: 12, color: AppTheme.textTertiary)),
                  ),
                Text(msg.content,
                    style: TextStyle(
                        fontSize: 15,
                        color: isMine ? Colors.white : AppTheme.textPrimary)),
              ],
            ),
          );
        }
    }

    final bubbleWidget = GestureDetector(
      onLongPress: msg.recalled ? null : onLongPress,
      child: bubble,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMine) ...[
            _avatar(senderColor, senderText),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                bubbleWidget,
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (timeText.isNotEmpty)
                      Text(timeText,
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textTertiary)),
                    if (isMine) ...[
                      const SizedBox(width: 6),
                      if (msg.status == MsgStatus.sending)
                        const SizedBox(
                          width: 12, height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.textTertiary),
                        )
                      else if (msg.status == MsgStatus.read)
                        const Text('已读',
                            style: TextStyle(
                                fontSize: 11, color: AppTheme.textTertiary))
                      else if (msg.status == MsgStatus.sent)
                        const Icon(Icons.check, size: 13, color: AppTheme.textTertiary)
                      else if (msg.status == MsgStatus.failed)
                        InkWell(
                          onTap: onRetry,
                          child: const Icon(Icons.error_outline,
                              size: 14, color: AppTheme.danger),
                        ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isMine) ...[
            const SizedBox(width: 8),
            _avatar(senderColor, senderText),
          ],
        ],
      ),
    );
  }

  Widget _avatar(Color color, String text) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(text,
          style: const TextStyle(
              fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)),
    );
  }

  // 图片 bubble 用 content 当作 URL 列表（多 URL 用 | 分隔）
  List<String> _parseImages(String content) {
    final parts = content.split('|').where((s) => s.trim().isNotEmpty).toList();
    if (parts.isNotEmpty) return parts;
    // 没真实数据，按设计稿渲染 4 张占位 + 第 5 张 +N
    return const [];
  }
}

// ============================== 各种消息气泡 widget ==============================

class _RedPacketBubble extends StatelessWidget {
  const _RedPacketBubble();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusBubble),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.redPacket, AppTheme.redPacketDark],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.card_giftcard, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('恭喜发财，大吉大利',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                      SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.check_circle, size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text('已领取',
                            style: TextStyle(fontSize: 12, color: Colors.white)),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: const Color(0xFFFEEAEA),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Text('微信红包',
                style: TextStyle(fontSize: 12, color: Color(0xFFB23B3B))),
          ),
        ],
      ),
    );
  }
}

class _TransferBubble extends StatelessWidget {
  final String amount;
  const _TransferBubble({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusBubble),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.transfer, AppTheme.transferDark],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.currency_yen, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('转账给您',
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text(
                        amount.isEmpty ? '¥ 500.00' : '¥ $amount',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: const Color(0xFFFFE9CE),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('微信转账',
                    style: TextStyle(fontSize: 12, color: Color(0xFFB57017))),
                Text('已被接收',
                    style: TextStyle(fontSize: 12, color: Color(0xFFB57017))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageGridBubble extends StatelessWidget {
  final List<String> urls;
  const _ImageGridBubble({required this.urls});

  @override
  Widget build(BuildContext context) {
    // 设计稿：4 张缩略图网格 + 第 5 张角标 +N
    final shown = (urls.isEmpty ? List.generate(5, (_) => '') : urls).take(5).toList();
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.divider, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        childAspectRatio: 1,
        children: List.generate(shown.length.clamp(1, 4), (i) {
          final url = shown[i];
          return Stack(
            fit: StackFit.expand,
            children: [
              // 缩略图（真实接 MinIO 时改为 Image.network；当前没数据，使用占位）
              Container(
                color: const Color(0xFFE9ECEF),
                alignment: Alignment.center,
                child: url.isEmpty
                    ? const Icon(Icons.photo, color: AppTheme.textTertiary, size: 28)
                    : null,
              ),
              if (i == 3 && shown.length > 4)
                Container(
                  color: Colors.black.withOpacity(0.45),
                  alignment: Alignment.center,
                  child: Text(
                    '+${shown.length - 4}',
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _FileBubble extends StatelessWidget {
  final String name;
  const _FileBubble({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusBubble),
        border: Border.all(color: AppTheme.divider, width: 0.5),
      ),
      constraints: const BoxConstraints(maxWidth: 240),
      child: Row(
        children: [
          const Icon(Icons.description, size: 28, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name.isEmpty ? '文件' : name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

// ========================== 浮动↓按钮 ==========================

class _JumpToBottomBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _JumpToBottomBtn({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.keyboard_arrow_down,
            size: 28, color: AppTheme.textSecondary),
      ),
    );
  }
}

// =========================== 输入栏（语音 / + / 表情 / 输入） ===========================

class _InputBar extends StatefulWidget {
  final TextEditingController controller;
  final ChatMsg? quoteMsg;
  final VoidCallback onClearQuote;
  final VoidCallback onSend;
  final VoidCallback? onMention;
  final ValueChanged<String>? onCall; // 需求11：语音/视频通话（TRTC）

  const _InputBar({
    required this.controller,
    required this.quoteMsg,
    required this.onClearQuote,
    required this.onSend,
    this.onMention,
    this.onCall,
  });

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  bool _drawerOpen = false;
  bool _emojiOpen = false;
  bool _hasText = false;
  bool _voiceMode = false; // 语音模式：输入框变"按住说话"

  static const _emojis = ['😀','😄','😁','😂','😊','😍','🥰','😘','😎','🤔','😅','😭','😡','👍','👏','🙏','💪','🎉','❤️','💙','🔥','✨','✅','👀','🙌','🤝','🌹','🎁','🍵','☕','📌','💡'];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final has = widget.controller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  void _toggleDrawer() {
    setState(() {
      _drawerOpen = !_drawerOpen;
      _emojiOpen = false;
    });
    if (_drawerOpen) FocusScope.of(context).unfocus();
  }

  void _toggleEmoji() {
    setState(() {
      _emojiOpen = !_emojiOpen;
      _drawerOpen = false;
    });
    if (_emojiOpen) FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.background,
        border: Border(top: BorderSide(color: AppTheme.divider, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 引用条
          if (widget.quoteMsg != null)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.format_quote, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '引用：${widget.quoteMsg!.content}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ),
                  InkWell(
                    onTap: widget.onClearQuote,
                    child: const Icon(Icons.close,
                        size: 16, color: AppTheme.textTertiary),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Row(
              children: [
                // 语音模式切换：mic → 键盘（需求2：切换后按钮本身也要变）
                IconButton(
                  onPressed: () => setState(() => _voiceMode = !_voiceMode),
                  icon: Icon(_voiceMode ? Icons.keyboard_alt_outlined : Icons.mic_none,
                      size: 24,
                      color: _voiceMode ? AppTheme.primary : AppTheme.textSecondary),
                ),
                // 语音模式：输入框变"按住说话"按钮
                if (_voiceMode)
                  Expanded(
                    child: GestureDetector(
                      onTapDown: (_) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('正在录音…（语音消息 V2.0 上线）')));
                      },
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(21),
                        ),
                        alignment: Alignment.center,
                        child: const Text('按住说话',
                            style: TextStyle(
                                fontSize: 14, color: AppTheme.textSecondary)),
                      ),
                    ),
                  )
                else
                  Expanded(
                // 输入框
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: TextField(
                        controller: widget.controller,
                        minLines: 1,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: '发消息...',
                          hintStyle: TextStyle(
                              color: AppTheme.textTertiary, fontSize: 14),
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 10, horizontal: 0),
                        ),
                        onSubmitted: (_) => widget.onSend(),
                      ),
                    ),
                  ),
                // 需求2：有内容 → 右侧变发送按钮；无内容 → 表情 + +（语音模式只留 mic 切换）
                if (!_voiceMode && _hasText)
                  IconButton(
                    onPressed: widget.onSend,
                    icon: const Icon(Icons.send_rounded,
                        size: 24, color: AppTheme.primary),
                  )
                else if (!_voiceMode) ...[
                  IconButton(
                    onPressed: _toggleEmoji,
                    icon: Icon(
                        _emojiOpen
                            ? Icons.keyboard_alt_outlined
                            : Icons.emoji_emotions_outlined,
                        size: 24,
                        color: AppTheme.textSecondary),
                  ),
                  IconButton(
                    onPressed: _toggleDrawer,
                    icon: Icon(
                        _drawerOpen ? Icons.add_circle : Icons.add_circle_outline,
                        size: 26,
                        color: AppTheme.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          // emoji 面板
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: _emojiOpen
                ? Container(
                    height: 200,
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: GridView.count(
                      crossAxisCount: 8,
                      children: _emojis.map((e) => InkWell(
                        onTap: () {
                          widget.controller.text += e;
                          _onTextChanged();
                        },
                        child: Center(
                            child: Text(e, style: const TextStyle(fontSize: 22))),
                      )).toList(),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          // 输入抽屉
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: _drawerOpen ? _PlusDrawer(
              onMention: widget.onMention,
              onItem: (name) {
                setState(() => _drawerOpen = false);
                // 需求11：语音/视频通话入口（TRTC）→ 交由 ChatPage 导航
                if (name == '语音通话') {
                  widget.onCall?.call('voice');
                } else if (name == '视频通话') {
                  widget.onCall?.call('video');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$name（V2.0 上线）')));
                }
              },
            ) : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _PlusDrawer extends StatelessWidget {
  final VoidCallback? onMention;
  final ValueChanged<String> onItem;
  const _PlusDrawer({this.onMention, required this.onItem});

  @override
  Widget build(BuildContext context) {
    final items = <_DrawerItem>[
      _DrawerItem('相册', Icons.photo_outlined),
      _DrawerItem('文件', Icons.folder_outlined),
      _DrawerItem('红包', Icons.card_giftcard),
      _DrawerItem('转账', Icons.currency_yen),
      _DrawerItem('语音通话', Icons.phone_outlined),
      _DrawerItem('视频通话', Icons.videocam_outlined),
      _DrawerItem('名片', Icons.person_outline),
      _DrawerItem('收藏', Icons.star_outline),
    ];
    return Container(
      color: AppTheme.background,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 18,
        crossAxisSpacing: 14,
        childAspectRatio: 0.95,
        children: items.map((it) => InkWell(
          onTap: () => onItem(it.label),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(it.icon,
                    size: 28,
                    color: it.label == '红包' || it.label == '转账'
                        ? AppTheme.primary
                        : AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(it.label,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
        )).toList(),
      ),
    );
  }
}

class _DrawerItem {
  final String label;
  final IconData icon;
  const _DrawerItem(this.label, this.icon);
}

// ===================== 长按消息全屏遮罩（图 7：模糊 + 高亮 + 回复输入） =====================

class _LongPressOverlay extends StatefulWidget {
  final ChatMsg msg;
  final String convName;
  final String myId;
  final List<Color> colors;
  final VoidCallback onClose;
  final VoidCallback onCopy;
  final VoidCallback onQuote;
  final VoidCallback onRecall;
  final VoidCallback onFavorite;
  final VoidCallback onForward;
  final ValueChanged<String> onSend;

  const _LongPressOverlay({
    required this.msg,
    required this.convName,
    required this.myId,
    required this.colors,
    required this.onClose,
    required this.onCopy,
    required this.onQuote,
    required this.onRecall,
    required this.onFavorite,
    required this.onForward,
    required this.onSend,
  });

  @override
  State<_LongPressOverlay> createState() => _LongPressOverlayState();
}

class _LongPressOverlayState extends State<_LongPressOverlay> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.msg;
    final isMine = m.senderId == widget.myId;
    final color = widget.colors[m.senderId.hashCode.abs() % widget.colors.length];

    return Stack(
      fit: StackFit.expand,
      children: [
        // 背景遮罩 + BackdropFilter 模糊（H5 支持 BackdropFilter）
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(color: Colors.black.withOpacity(0.55)),
            ),
          ),
        ),
        // 高亮气泡（居中偏上）
        Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusBubble),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.3),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (m.hasReply)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F7FA),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('引用了一条消息',
                              style: TextStyle(
                                  fontSize: 12, color: AppTheme.textTertiary)),
                        ),
                      Text(m.content.isEmpty ? '[消息]' : m.content,
                          style: const TextStyle(
                              fontSize: 15, color: AppTheme.textPrimary)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (m.createdAt != null)
                  const SizedBox.shrink(),
              ],
            ),
          ),
        ),
        // 顶部操作：复制 / 引用 / 收藏 / 撤回 / 转发（紧贴高亮气泡上方/下方）
        Positioned(
          top: 60,
          right: 20,
          child: _overlayAction(Icons.close, widget.onClose),
        ),
        // 操作行（在气泡上下方一排）
        Positioned(
          top: MediaQuery.of(context).size.height * 0.55,
          left: 0,
          right: 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 14,
              runSpacing: 12,
              children: [
                _actionChip(Icons.copy, '复制', widget.onCopy),
                _actionChip(Icons.format_quote, '引用', widget.onQuote),
                _actionChip(Icons.star_outline, '收藏', widget.onFavorite),
                if (isMine || true)
                  _actionChip(Icons.undo, '撤回', widget.onRecall),
                _actionChip(Icons.forward, '转发', widget.onForward),
              ],
            ),
          ),
        ),
        // 底部：回复输入栏
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppTheme.divider, width: 0.5)),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.add_circle_outline,
                        size: 26, color: AppTheme.textSecondary),
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: TextField(
                        controller: _input,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: '回复 ${widget.convName}...',
                          hintStyle: const TextStyle(
                              fontSize: 14, color: AppTheme.textTertiary),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
                        ),
                        onSubmitted: (v) {
                          if (v.trim().isEmpty) return;
                          widget.onSend(v.trim());
                        },
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.emoji_emotions_outlined,
                        size: 24, color: AppTheme.textSecondary),
                  ),
                  IconButton(
                    onPressed: () {
                      final v = _input.text.trim();
                      if (v.isEmpty) return;
                      widget.onSend(v);
                    },
                    icon: const Icon(Icons.send_rounded,
                        size: 26, color: AppTheme.primary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _overlayAction(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: AppTheme.textPrimary),
      ),
    );
  }

  Widget _actionChip(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppTheme.textPrimary),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
