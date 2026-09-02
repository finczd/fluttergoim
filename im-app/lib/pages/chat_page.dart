import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_locale.dart';
import '../services/api_client.dart';
import '../services/call_service.dart';
import '../services/conversation_service.dart';
import '../services/moment_service.dart';
import '../services/wallet_store.dart';
import '../services/ws_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_dialogs.dart';
import 'conv_settings_page.dart';
import 'group_member_picker_page.dart';
import 'image_viewer_page.dart';
import 'red_packet_detail_page.dart';
import 'red_packet_page.dart';
import 'transfer_page.dart';
import 'video_call_page.dart';
import 'voice_call_page.dart';

/// 消息本地状态
enum MsgStatus { sending, sent, read, failed }

/// 取异常里的**后端原始提示**（去掉 Dart 的 "Exception: " 前缀），失败时兜底用 fallback。
/// 资金类操作（领红包 / 收转账）必须把真实原因告诉用户，不能笼统说"失败了"。
String _errMsg(Object e, String fallback) {
  var s = e.toString().trim();
  if (s.startsWith('Exception:')) s = s.substring('Exception:'.length).trim();
  if (s.startsWith('DioException')) s = fallback; // 网络层错误换成用户能看懂的文案
  return s.isEmpty ? fallback : s;
}

class ChatMsg {
  String? msgId; // 非 final：本地发送成功后由响应回填
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
  final String? scrollToMsgId; // 群置顶消息点击跳转：滚动到该消息
  const ChatPage(
      {super.key, required this.conv, required this.myId, this.scrollToMsgId});

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
  // 零钱：已领取的红包/转账 msgId（本地状态）
  final Set<String> _claimedMoneyIds = {};

  // 长按全屏遮罩状态
  ChatMsg? _longPressedMsg;

  // 头像：我方（profile 拉取）/ 群成员（按 senderId 查 _members）；单聊对方用 conv.avatarUrl
  String _myAvatar = '';

  bool get isGroup => (widget.conv.conversation['type'] as num?)?.toInt() == 2;

  /// 群聊按 senderId 查成员头像（单聊不走这里）
  String _memberAvatar(String senderId) {
    for (final m in _members) {
      final uid = m['userId']?.toString() ?? m['id']?.toString() ?? '';
      if (uid == senderId) return m['avatar']?.toString() ?? '';
    }
    return '';
  }

  String _t(String key, [Map<String, String>? params]) =>
      AppLocalizations.of(context).t(key, params);

  /// 群聊：按 senderId 查成员昵称（小助手固定名；查不到回落短 ID）
  String _senderName(String senderId) {
    if (senderId == '-1') return '小助手';
    for (final m in _members) {
      final uid = m['userId']?.toString() ?? m['id']?.toString() ?? '';
      if (uid == senderId) {
        final n = m['nickname']?.toString() ?? m['remark']?.toString() ?? '';
        if (n.isNotEmpty) return n;
      }
    }
    return senderId.length > 6
        ? '...${senderId.substring(senderId.length - 4)}'
        : senderId;
  }

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
    _loadMyAvatar();
    await _loadHistory();
    await _connectWs();
    _reportRead();
    if (isGroup) _loadMembers();
  }

  /// 我方头像（聊天窗口左右气泡都要显示真实头像）
  Future<void> _loadMyAvatar() async {
    try {
      final r = await _api.get('/api/v1/user/profile');
      final av =
          ((r.data['data'] as Map<String, dynamic>)['avatar'])?.toString() ??
              '';
      if (mounted && av.isNotEmpty) setState(() => _myAvatar = av);
    } catch (_) {}
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
        // 群置顶点击跳转：先滚到底（默认），再滚到目标消息
        final to = widget.scrollToMsgId;
        if (to != null && to.isNotEmpty) {
          _scrollToMsg(to);
        } else {
          _scrollToBottom();
        }
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
            // 重连后做一次补拉（按 msgId/clientMsgId 去重后再合并，
            // 避免 addAll 把本地已有的消息再插一遍 → 整条记录重复）
            _svc.sync(widget.conv.id, _lastSeq).then((list) {
              if (list.isEmpty || !mounted) return;
              final added = list.map(ChatMsg.fromServer).toList();
              added.sort((a, b) => (a.seq ?? 0).compareTo(b.seq ?? 0));
              setState(() {
                for (final m in added) {
                  final dup = _msgs.any((x) =>
                      (m.msgId != null &&
                          m.msgId!.isNotEmpty &&
                          x.msgId == m.msgId) ||
                      (x.clientMsgId.isNotEmpty &&
                          x.clientMsgId == m.clientMsgId));
                  if (!dup) _msgs.add(m);
                }
                _msgs.sort((a, b) => (a.seq ?? 0).compareTo(b.seq ?? 0));
              });
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
        // 幂等去重：msgId 或 clientMsgId 任一命中即跳过。
        // 只按 clientMsgId 判断有漏网场景（服务端/补拉数据不带 clientMsgId 时
        // 永远匹配不上 → 同一条消息被重复插入 → 图片消息显示两张），
        // 所以再按 msgId 兜一层。
        final dup = _msgs.any((x) =>
            (msg.msgId != null &&
                msg.msgId!.isNotEmpty &&
                x.msgId == msg.msgId) ||
            (x.clientMsgId.isNotEmpty && x.clientMsgId == msg.clientMsgId));
        if (dup) return;
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
      final resp =
          await _svc.send(widget.conv.id, text, clientMsgId: clientMsgId);
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
      final resp = await _svc.send(widget.conv.id, m.content,
          clientMsgId: m.clientMsgId);
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

  /// 领取红包（拆红包动画）/ 确认收款 → 记入零钱（微信交互对齐）
  Future<void> _claimMoney(ChatMsg m) async {
    final id = m.msgId;
    // 红包：先查后端详情——已领取过（含重启后状态）或已领完 → 直接进领取详情页
    if (m.type == 8 && id != null && id.isNotEmpty) {
      if (_claimedMoneyIds.contains(id)) {
        if (mounted) {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => RedPacketDetailPage(msgId: id)));
        }
        return;
      }
      try {
        final d = await MomentService.instance.redPacketDetail(id);
        final list = ((d['list'] as List<dynamic>?) ?? []);
        final claimedCnt = (d['claimedCnt'] as num?)?.toInt() ?? 0;
        final count = (d['count'] as num?)?.toInt() ?? 1;
        final claimedByMe =
            list.any((c) => c['userId']?.toString() == widget.myId);
        if (claimedByMe || claimedCnt >= count) {
          _claimedMoneyIds.add(id);
          if (mounted) {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => RedPacketDetailPage(msgId: id)));
          }
          return;
        }
      } catch (_) {}
    }
    if (id != null && _claimedMoneyIds.contains(id)) {
      AppDialogs.toast(context, _t('chatAlreadyClaimed'));
      return;
    }
    Map<String, dynamic> data = {};
    try {
      final j = jsonDecode(m.content);
      if (j is Map) data = j.cast<String, dynamic>();
    } catch (_) {}
    final amount = (data['amount'] as num?)?.toDouble() ??
        (double.tryParse(m.content) ?? 0);
    if (amount <= 0) {
      AppDialogs.toast(context, _t('chatInvalidAmount'));
      return;
    }
    final isRed = m.type == 8;
    if (isRed) {
      // 微信拆红包：封面 → 开（后端分配并入账）→ 金额结果 + 领取详情入口
      final detail = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _RedPacketOpenDialog(msgId: id ?? ''),
      );
      if (detail == null || !mounted) return;
      if (id != null) _claimedMoneyIds.add(id);
      WalletStore.instance.refresh();
      setState(() {});
      return;
    } else {
      // 转账：仅收款人可领
      final toId = (data['toUserId'] ?? '').toString();
      if (toId.isNotEmpty && toId != widget.myId) {
        AppDialogs.toast(context, _t('chatWaitingAccept'));
        return;
      }
      if (toId.isEmpty && m.senderId == widget.myId) {
        AppDialogs.toast(context, _t('chatWaitingAccept'));
        return;
      }
      final claimed = await showDialog<bool>(
        context: context,
        builder: (_) => _TransferConfirmDialog(amount: amount),
      );
      if (claimed != true || !mounted) return;
    }
    if (id != null) _claimedMoneyIds.add(id);
    // 收款改走服务端交叉校验接口（B-21）：金额由服务端按转账消息内容核算，
    // 客户端不再上报金额，也不能靠清缓存反复领同一笔转账。
    final res = await WalletStore.instance.acceptTransfer(id ?? '');
    if (!mounted) return;
    if (res == null) {
      if (id != null) _claimedMoneyIds.remove(id); // 允许重试
      // 用后端真实原因：可能是「超过 24 小时未领取已退回」「已被他人领取」等
      AppDialogs.toast(
          context,
          WalletStore.instance.lastError.isNotEmpty
              ? WalletStore.instance.lastError
              : _t('chatAcceptFailedRetry'));
      return;
    }
    final got = (res['amount'] as num?)?.toDouble() ?? amount;
    final already = res['already'] == true;
    AppDialogs.toast(
        context,
        already
            ? _t('chatTransferClaimedBefore')
            : _t('chatSavedToWalletAmount',
                {'amount': WalletStore.instance.fmt(got)}));
    await WalletStore.instance.refresh();
    setState(() {});
  }

  /// 红包/转账：独立页面（微信群流程对齐）→ 发送 type=8/9
  Future<void> _openMoneyPage(String kind) async {
    final isRed = kind == 'redpacket';
    Map<String, dynamic>? payload;
    if (isRed) {
      payload = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(builder: (_) => RedPacketPage(isGroup: isGroup)),
      );
    } else {
      String peerName = widget.conv.conversationName;
      String? peerId;
      if (isGroup) {
        // 群聊：先选收款人
        if (_members.isEmpty) {
          try {
            _members = await _svc.members(widget.conv.id);
          } catch (_) {}
        }
        final picked = await Navigator.of(context).push<Map<String, dynamic>>(
          MaterialPageRoute(
              builder: (_) =>
                  GroupMemberPickerPage(members: _members, myId: widget.myId)),
        );
        if (picked == null || !mounted) return;
        peerId = picked['id']?.toString();
        peerName = (picked['nickname'] ?? picked['name'] ?? _t('chatMember'))
            .toString();
      }
      payload = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
            builder: (_) => TransferPage(peerName: peerName, peerId: peerId)),
      );
    }
    if (payload == null || !mounted) return;
    final amount = (payload['amount'] as num?)?.toDouble() ?? 0;
    if (amount <= 0) return;

    // 组装消息负载
    final contentData = <String, dynamic>{
      'kind': isRed ? 'redpacket' : 'transfer',
      'amount': amount,
      'note': payload['note'] ?? '',
    };
    if (isRed) {
      contentData['mode'] = payload['mode'] ?? 'normal';
      contentData['count'] = payload['count'] ?? 1;
    } else {
      contentData['toUserId'] = payload['toUserId'] ?? '';
      contentData['toName'] = payload['toName'] ?? '';
    }

    // ===== 交叉验证第一道：发出去之前再查一次真实余额 =====
    // 页面里填金额时看到的余额可能是几十秒前的（后台刚调整过、或刚领了个红包），
    // 所以这里必须重新拉一次再比一次。后端发消息时还会再校验一次（第二道）。
    await WalletStore.instance.refresh();
    if (!mounted) return;
    final need = isRed
        ? ((payload['mode'] == 'lucky')
            ? amount
            : amount * ((payload['count'] as num?)?.toInt() ?? 1))
        : amount;
    final bal = WalletStore.instance.balance;
    if (need > bal) {
      AppDialogs.toast(
          context,
          _t('chatInsufficientBalanceNeed', {
            'need': WalletStore.instance.fmt(need),
            'bal': WalletStore.instance.fmt(bal),
          }));
      return;
    }
    // 发送（本地乐观插入）
    final clientMsgId = _uuid();
    setState(() {
      _msgs.add(ChatMsg(
        clientMsgId: clientMsgId,
        senderId: widget.myId,
        type: isRed ? 8 : 9,
        content: jsonEncode(contentData),
        status: MsgStatus.sending,
      ));
    });
    _scrollToBottom();
    try {
      final resp = await _svc.sendMoney(
          widget.conv.id, isRed ? 8 : 9, contentData,
          clientMsgId: clientMsgId);
      if (!mounted) return;
      setState(() {
        final idx = _msgs.indexWhere((x) => x.clientMsgId == clientMsgId);
        if (idx >= 0) {
          _msgs[idx] = ChatMsg.fromServer(resp);
          final seqNow = (resp['seq'] as num?)?.toInt() ?? 0;
          if (seqNow > 0) _lastSeq = max(_lastSeq, seqNow);
          _msgs.sort((a, b) => (a.seq ?? 0).compareTo(b.seq ?? 0));
        }
      });
      // 扣款已由**后端**在消息落库前原子完成（service.SendMoneyCharge），
      // 前端绝不能再调 debit() 记一次，否则扣两次钱（B-19）。这里只刷新余额。
      WalletStore.instance.refresh();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      final insufficient = msg.contains('余额不足') || msg.contains('4101');
      // 余额不足 / 参数错误：消息根本没发出去，直接撤掉乐观插入的气泡，别留个"失败"在会话里
      setState(() {
        final idx = _msgs.indexWhere((x) => x.clientMsgId == clientMsgId);
        if (idx >= 0) {
          if (insufficient) {
            _msgs.removeAt(idx);
          } else {
            _msgs[idx].status = MsgStatus.failed;
          }
        }
      });
      if (insufficient) {
        AppDialogs.toast(context, _t('chatInsufficientSendFailed'));
      }
      // 兜底：把后端的最新余额拉回来，避免本地还是旧值
      WalletStore.instance.refresh();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(_scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    });
  }

  /// 群置顶消息点击跳转：滚动到指定 msgId
  void _scrollToMsg(String msgId) {
    if (_msgs.isEmpty) return;
    final i = _msgs.indexWhere((m) => m.msgId == msgId);
    if (i < 0) return;
    // 简单估算偏移（按消息条目均高 72 像素），需要精确可改 SliverList/Builder + extent
    final est = (i * 72.0).clamp(0.0, _scroll.position.maxScrollExtent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(est,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  String _uuid() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(99999)}';

  String _time(String? iso) {
    if (iso == null) return '';
    DateTime? dt;
    try {
      dt = DateTime.parse(iso);
    } catch (_) {
      return '';
    }
    final now = DateTime.now();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '$h:$m';
    }
    return '${dt.month}/${dt.day} $h:$m';
  }

  /// 完整时间（消息之间的时间分隔条用）
  String _fullTime(String? iso) {
    if (iso == null) return '';
    DateTime? dt;
    try {
      dt = DateTime.parse(iso).toLocal();
    } catch (_) {
      return '';
    }
    final now = DateTime.now();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '$h:$m';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year &&
        dt.month == yesterday.month &&
        dt.day == yesterday.day) {
      return _t('chatYesterdayAt', {'time': '$h:$m'});
    }
    if (dt.year == now.year) {
      return _t('chatDateThisYear',
          {'month': '${dt.month}', 'day': '${dt.day}', 'time': '$h:$m'});
    }
    return _t('chatDateFull', {
      'year': '${dt.year}',
      'month': '${dt.month}',
      'day': '${dt.day}',
      'time': '$h:$m',
    });
  }

  /// 与上一条间隔超过 5 分钟才显示时间分隔条
  bool _needTimeDivider(int i) {
    if (i == 0) return true;
    final prev = _msgs[i - 1].createdAt;
    final cur = _msgs[i].createdAt;
    if (prev == null || cur == null) return false;
    final a = DateTime.tryParse(prev);
    final b = DateTime.tryParse(cur);
    if (a == null || b == null) return false;
    return b.difference(a).inMinutes.abs() >= 5;
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
    final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => ConvSettingsPage(conv: widget.conv)));
    if (changed == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  /// 需求11：发起语音/视频通话（TRTC，单聊）
  /// 先发 invite 信令，再打开通话页（页面会等对方 accept 才进房）
  Future<void> _openCall(String type) async {
    if (isGroup) {
      AppDialogs.toast(context, _t('chatCallSingleOnly'));
      return;
    }
    if (CallService.instance.state.value != null) {
      AppDialogs.toast(context, _t('chatCallInProgress'));
      return;
    }
    await CallService.instance.startCall(
      convId: widget.conv.id,
      callType: type,
      peerName: widget.conv.conversationName,
      peerAvatar: widget.conv.avatarUrl,
    );
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => type == 'video'
            ? VideoCallPage(
                peerName: widget.conv.conversationName,
                peerAvatar: widget.conv.avatarUrl,
                convId: widget.conv.id)
            : VoiceCallPage(
                peerName: widget.conv.conversationName,
                peerAvatar: widget.conv.avatarUrl,
                convId: widget.conv.id)));
  }

  /// 点击通话气泡：只有 invite 才重新进入通话，hangup/reject 只是历史记录
  void _openCallFromSignal(String content) {
    String action = 'invite';
    var type = 'voice';
    try {
      final map = jsonDecode(content);
      if (map is Map) {
        action = map['action']?.toString() ?? 'invite';
        if (map['callType'] == 'video') type = 'video';
      }
    } catch (_) {}
    if (action != 'invite') return; // 通话记录气泡点击无动作
    _openCall(type);
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(AppLocalizations.of(context).t('chatPickMention'),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            ListTile(
              leading: CircleAvatar(
                  backgroundColor: context.cs.surface,
                  child: Icon(Icons.group)),
              title: Text(_t('chatMentionAll'),
                  style: const TextStyle(fontSize: 15)),
              // pop 出的 '@所有人' 会拼进消息内容发送给服务端，保持原样不做翻译
              onTap: () => Navigator.of(context).pop('@所有人'),
            ),
            ..._members.map((m) => ListTile(
                  leading: CircleAvatar(
                      backgroundColor: context.cs.surface,
                      child: Text(
                          (m['nickname']?.toString().characters.first ?? '?'),
                          style: const TextStyle(color: AppTheme.primary))),
                  title: Text(m['nickname']?.toString() ?? '',
                      style: const TextStyle(fontSize: 15)),
                  onTap: () => Navigator.of(context)
                      .pop(m['nickname']?.toString() ?? ''),
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
      _toast(_t('chatRecalled'));
    } else {
      _toast(_t('chatRecallFailed'));
    }
  }

  /// 复制
  void _copy(ChatMsg m) {
    _closeLongPressOverlay();
    Clipboard.setData(ClipboardData(text: m.content));
    _toast(_t('chatCopied'));
  }

  /// 收藏
  Future<void> _favorite(ChatMsg m) async {
    _closeLongPressOverlay();
    if (m.msgId == null) return;
    final ok = await _svc.favoriteAdd(widget.conv.id, m.msgId!);
    _toast(ok ? _t('chatFavorited') : _t('chatFavoriteFailed'));
  }

  /// 引用
  void _quote(ChatMsg m) {
    _closeLongPressOverlay();
    setState(() => _quoteMsg = m);
  }

  /// 转发（占位：以后接好友选择器）
  void _forward(ChatMsg m) {
    _closeLongPressOverlay();
    _toast(_t('chatForwardComingSoon'));
  }

  /// 置顶/取消置顶消息（群主/管理员；后端已放开所有成员可置顶）
  Future<void> _pinMsg(ChatMsg m) async {
    _closeLongPressOverlay();
    final ok =
        await _svc.setPinMessage(widget.conv.id, m.msgId ?? '0', m.content);
    _toast(ok ? _t('chatPinned') : _t('chatPinFailed'));
    if (ok) {
      setState(() {
        widget.conv.conversation['pinnedMsgContent'] = m.content;
      });
    }
  }

  void _toast(String msg) => AppDialogs.toast(context, msg);

  /// 需求3：从相册选图发送（上传 MinIO → type=2 图片消息）
  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (picked == null) return;
      final up = await ApiClient.instance.uploadFile(
        picked.path,
        picked.name.isEmpty ? 'image.jpg' : picked.name,
      );
      final url = (up['url'] ?? '').toString();
      final clientMsgId = _uuid();
      final local = ChatMsg(
        clientMsgId: clientMsgId,
        senderId: widget.myId,
        type: 2,
        content: url, // 图片 bubble 用 content 存 URL
        status: MsgStatus.sending,
      );
      setState(() {
        _msgs.add(local);
        _scrollToBottom();
      });
      // 发送图片消息（type=2, content=URL）
      final resp =
          await _svc.sendImage(widget.conv.id, url, clientMsgId: clientMsgId);
      if (!mounted) return;
      setState(() {
        final idx = _msgs.indexWhere((m) => m.clientMsgId == clientMsgId);
        if (idx >= 0) {
          // 与文本 _send 一致：整体替换为服务端回显消息（含 msgId/seq/clientMsgId），
          // 并推进 _lastSeq —— 否则 WS 回推/重连补拉会把这条图片消息当新消息
          // 再插一遍，聊天记录里同一张图出现两次。
          _msgs[idx] = ChatMsg.fromServer(resp);
          final seqNow = (resp['seq'] as num?)?.toInt() ?? 0;
          if (seqNow > 0) _lastSeq = max(_lastSeq, seqNow);
          _msgs.sort((a, b) => (a.seq ?? 0).compareTo(b.seq ?? 0));
        }
      });
    } catch (e) {
      _toast(_t('chatImageSendFailed', {'error': e.toString()}));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pinnedContent =
        widget.conv.conversation['pinnedMsgContent']?.toString() ?? '';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 0, vertical: 8),
                          itemCount: _msgs.length,
                          itemBuilder: (_, i) {
                            final m = _msgs[i];
                            return Column(
                              children: [
                                // 距上一条超过 5 分钟 → 居中时间分隔条
                                if (_needTimeDivider(i))
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 10),
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: context.cs.onSurfaceVariant
                                              .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(
                                              AppTheme.radiusSm),
                                        ),
                                        child: Text(
                                          _fullTime(m.createdAt),
                                          style: TextStyle(
                                              fontSize: 11,
                                              color:
                                                  context.cs.onSurfaceVariant),
                                        ),
                                      ),
                                    ),
                                  ),
                                _MsgRow(
                                  msg: m,
                                  colors: _bubbleColors,
                                  myId: widget.myId,
                                  isMine: m.senderId == widget.myId,
                                  senderName: _senderName(m.senderId),
                                  showSenderName: isGroup,
                                  // 头像：单聊（含小助手）用对方会话头像，群聊按成员查
                                  myAvatar: _myAvatar,
                                  peerAvatar: widget.conv.avatarUrl,
                                  senderAvatar: _memberAvatar(m.senderId),
                                  highlighted: _longPressedMsg?.clientMsgId ==
                                      m.clientMsgId,
                                  onLongPress: () => _showLongPressOverlay(m),
                                  timeText: _time(m.createdAt),
                                  onRetry: m.status == MsgStatus.failed
                                      ? () => _retry(m)
                                      : null,
                                  onCallTap: () =>
                                      _openCallFromSignal(m.content),
                                  moneyClaimed:
                                      _claimedMoneyIds.contains(m.msgId),
                                  onMoneyTap: () => _claimMoney(m),
                                ),
                              ],
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
              onPickImage: _pickImage,
              onMoney: (kind) => _openMoneyPage(kind),
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
              onPin: () => _pinMsg(_longPressedMsg!),
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
      final resp =
          await _svc.send(widget.conv.id, text, clientMsgId: clientMsgId);
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
        : (peerOnline
            ? (hasMobile
                ? _t('chatStatusMobileOnline')
                : _t('chatStatusDesktopOnline'))
            : _t('chatStatusOffline'));
    return Container(
      decoration: BoxDecoration(
          color: context.cs.surface,
          border: Border(
              bottom:
                  BorderSide(color: context.cs.outlineVariant, width: 0.5))),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon:
                Icon(Icons.chevron_left, size: 28, color: context.cs.onSurface),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(widget.conv.conversationName,
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: context.cs.onSurface)),
                if (statusText.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(statusText,
                      style: TextStyle(
                          fontSize: 11,
                          color: peerOnline
                              ? AppTheme.primary
                              : context.cs.onSurfaceVariant)),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: _openSettings,
            icon: Icon(Icons.more_horiz, size: 24, color: context.cs.onSurface),
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
      color: context.cs.surfaceContainer,
      child: Row(
        children: [
          const Icon(Icons.push_pin, size: 14, color: AppTheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _t('chatPinnedMsg', {'content': content}),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: context.cs.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  // 头像色板统一走主题，保证与其它页面一致
  static const _bubbleColors = AppTheme.avatarColors;
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
  final VoidCallback? onCallTap; // 通话邀请气泡点击（接听）
  final String senderName; // 群聊显示发送者昵称
  final bool showSenderName;
  final bool moneyClaimed; // 红包/转账已领取
  final VoidCallback? onMoneyTap; // 红包/转账点击领取
  final String myAvatar; // 我方头像 URL
  final String peerAvatar; // 单聊对方头像 URL（含小助手后台配置头像）
  final String senderAvatar; // 群聊该消息发送者头像 URL

  const _MsgRow({
    required this.msg,
    required this.colors,
    required this.myId,
    required this.isMine,
    required this.highlighted,
    required this.onLongPress,
    required this.timeText,
    this.onRetry,
    this.onCallTap,
    this.senderName = '',
    this.showSenderName = false,
    this.moneyClaimed = false,
    this.onMoneyTap,
    this.myAvatar = '',
    this.peerAvatar = '',
    this.senderAvatar = '',
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
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
      case 8: // 红包（content=JSON {kind,amount,note}）
        bubble = _MoneyBubble(
          content: msg.content,
          isRed: true,
          claimed: moneyClaimed,
          onTap: onMoneyTap ?? () {},
        );
        break;
      case 9: // 转账
        bubble = _MoneyBubble(
          content: msg.content,
          isRed: false,
          claimed: moneyClaimed,
          onTap: onMoneyTap ?? () {},
        );
        break;
      case 7: // 通话邀请（TRTC 信令）
        bubble = _CallBubble(
          content: msg.content,
          onTap: onCallTap ?? () {},
        );
        break;
      default:
        if (msg.recalled) {
          bubble = Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(t('chatMsgRecalled'),
                style: TextStyle(
                    fontSize: 13, color: context.cs.onSurfaceVariant)),
          );
        } else {
          bubble = Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMine ? AppTheme.primary : context.cs.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusBubble),
              border: null,
              boxShadow: [
                if (highlighted)
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.18),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          isMine ? Colors.white24 : context.cs.surfaceContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(t('chatQuotedMsg'),
                        style: TextStyle(
                            fontSize: 12, color: context.cs.onSurfaceVariant)),
                  ),
                Text(msg.content,
                    style: TextStyle(
                        fontSize: 15,
                        color: isMine ? Colors.white : context.cs.onSurface)),
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
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
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
                // 群聊：显示发送者昵称
                if (showSenderName && !isMine && !msg.recalled)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(senderName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: context.cs.onSurfaceVariant)),
                  ),
                bubbleWidget,
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (timeText.isNotEmpty)
                      Text(timeText,
                          style: TextStyle(
                              fontSize: 11,
                              color: context.cs.onSurfaceVariant)),
                    if (isMine) ...[
                      const SizedBox(width: 6),
                      if (msg.status == MsgStatus.sending)
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: context.cs.onSurfaceVariant),
                        )
                      else if (msg.status == MsgStatus.read)
                        Text(t('chatRead'),
                            style: TextStyle(
                                fontSize: 11,
                                color: context.cs.onSurfaceVariant))
                      else if (msg.status == MsgStatus.sent)
                        Icon(Icons.check,
                            size: 13, color: context.cs.onSurfaceVariant)
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
    // 真实头像：我方 / 单聊对方（含小助手）/ 群成员，有 URL 就显示；失败回落色块
    // （群聊标记 showSenderName 由父级按 isGroup 传入）
    final url =
        isMine ? myAvatar : (showSenderName ? senderAvatar : peerAvatar);
    if (url.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          url,
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackAvatar(color, text),
        ),
      );
    }
    return _fallbackAvatar(color, text);
  }

  Widget _fallbackAvatar(Color color, String text) {
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

/// 拆红包弹窗（微信交互：封面 → 点击"開" → 后端分配并入账 → 金额结果 + 详情入口）
class _RedPacketOpenDialog extends StatefulWidget {
  final String msgId;
  const _RedPacketOpenDialog({required this.msgId});

  @override
  State<_RedPacketOpenDialog> createState() => _RedPacketOpenDialogState();
}

class _RedPacketOpenDialogState extends State<_RedPacketOpenDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _opening = false; // 请求中
  bool _opened = false; // 动画播放
  double _myAmount = 0;
  String _note = '';
  final _svc = MomentService.instance;

  String _t(String key, [Map<String, String>? params]) =>
      AppLocalizations.of(context).t(key, params);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    if (_opening || _opened || widget.msgId.isEmpty) return;
    setState(() => _opening = true);
    try {
      final detail = await _svc.redPacketClaim(widget.msgId);
      _myAmount = (detail['myAmount'] as num?)?.toDouble() ?? 0;
      _note = (detail['note'] ?? '').toString();
      if (!mounted) return;
      setState(() {
        _opening = false;
        _opened = true;
      });
      _ctrl.forward().whenComplete(() {
        if (mounted) setState(() {});
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _opening = false);
      // 领取失败必须把**后端原因**原样告诉用户（已领完 / 已过期退回 / 旧版本数据…），
      // 不能笼统说一句"已被领完"，更不能假装拆到 ¥0
      AppDialogs.toast(context, _errMsg(e, _t('chatRedPacketGone')));
      Navigator.pop(context, null);
    }
  }

  void _openDetail() {
    Navigator.pop(context, {'claimed': true});
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => RedPacketDetailPage(msgId: widget.msgId)));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    final fmt = WalletStore.instance.fmt(_myAmount);
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 300,
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE9564E), Color(0xFFD6453F)],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.35), blurRadius: 24),
          ],
        ),
        child: !_opened || !_ctrl.isCompleted
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.card_giftcard,
                        color: Color(0xFFFFE08A), size: 30),
                  ),
                  const SizedBox(height: 12),
                  Text(t('chatAppRedPacket'),
                      style: const TextStyle(
                          color: Color(0xFFFFE08A),
                          fontSize: 18,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(_note.isEmpty ? t('chatRedPacketGreeting') : _note,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13)),
                  const SizedBox(height: 26),
                  _opening
                      ? const SizedBox(
                          width: 84,
                          height: 84,
                          child: Center(
                              child: CircularProgressIndicator(
                                  color: Color(0xFFFFE08A))),
                        )
                      : AnimatedBuilder(
                          animation: _ctrl,
                          builder: (ctx, _) {
                            final v = _ctrl.value;
                            return Transform.rotate(
                              angle: v * 6.283,
                              child: Transform.scale(
                                scale: _opened ? 1.0 - v * 0.9 : 1.0,
                                child: Opacity(
                                  opacity: _opened ? 1.0 - v : 1.0,
                                  child: GestureDetector(
                                    onTap: _open,
                                    child: Container(
                                      width: 84,
                                      height: 84,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xFFFFE08A),
                                        boxShadow: [
                                          BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.25),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4)),
                                        ],
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(t('chatOpen'),
                                          style: const TextStyle(
                                              fontSize: 34,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFFD6453F))),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                  const SizedBox(height: 22),
                  Text(_opening ? t('chatClaiming') : t('chatTapToOpen'),
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12)),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Text(t('chatSavedToWallet'),
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 12),
                  Text('¥$fmt',
                      style: const TextStyle(
                          color: Color(0xFFFFE08A),
                          fontSize: 44,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 18),
                  // 领取详情入口（微信：查看领取详情）
                  InkWell(
                    onTap: _openDetail,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(t('chatViewClaimDetail'),
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.85))),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right,
                              size: 16,
                              color: Colors.white.withValues(alpha: 0.85)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // 「知道了」关闭弹窗（已领取，返回 claimed 让会话刷新状态）
                  InkWell(
                    onTap: () => Navigator.pop(context, {'claimed': true}),
                    child: Container(
                      width: double.infinity,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE08A),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      alignment: Alignment.center,
                      child: Text(t('chatOK'),
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFD6453F))),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// 转账收款确认弹窗
class _TransferConfirmDialog extends StatelessWidget {
  final double amount;
  const _TransferConfirmDialog({required this.amount});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    final fmt = WalletStore.instance.fmt(amount);
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: context.cs.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                  color: Color(0xFFF5A623), shape: BoxShape.circle),
              child:
                  const Icon(Icons.currency_yen, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 12),
            Text(t('chatFriendTransfer'),
                style: TextStyle(
                    fontSize: 13, color: context.cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            Text('¥$fmt',
                style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    color: context.cs.onSurface)),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFA9D3B)),
                child: Text(t('chatConfirmAccept'),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 红包/转账气泡（type=8/9，content=JSON {kind,amount,note}）
/// 微信风格：橙黄底白字 + 左侧白色图标块 + 右侧箭头；已领取整体灰化降饱和
/// - 红包：主文案=祝福语，小字=拼手气红包·N个 / 领取红包 / 已领取
/// - 转账：主文案=¥金额，小字=微信转账 / 已收款
class _MoneyBubble extends StatelessWidget {
  final String content;
  final bool isRed;
  final bool claimed;
  final VoidCallback onTap;
  const _MoneyBubble({
    required this.content,
    required this.isRed,
    required this.claimed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    double amount = 0;
    String note = isRed ? t('chatRedPacketGreeting') : '';
    int count = 0;
    String mode = '';
    try {
      final j = jsonDecode(content);
      if (j is Map) {
        amount = (j['amount'] as num?)?.toDouble() ?? 0;
        final n = j['note']?.toString() ?? '';
        if (n.isNotEmpty) note = n;
        count = (j['count'] as num?)?.toInt() ?? 0;
        mode = j['mode']?.toString() ?? '';
      }
    } catch (_) {
      // 兼容旧格式：content 直接是金额
      amount = double.tryParse(content) ?? 0;
    }
    // 微信配色：红包/转账均为橙黄底；已领取灰化（降饱和）
    final bg = claimed
        ? const Color(0xFFD5D2CD)
        : (isRed ? const Color(0xFFFA9D3B) : const Color(0xFFF5A623));
    final iconTint = claimed
        ? const Color(0xFF9E9B96)
        : (isRed ? const Color(0xFFFA9D3B) : const Color(0xFFF5A623));
    // 红包副标题：拼手气红包 · N 个 / 普通红包
    final subtitle = isRed
        ? (count > 1
            ? t('chatRedPacketCount', {
                'type': t(mode == 'lucky'
                    ? 'chatLuckyRedPacket'
                    : 'chatNormalRedPacket'),
                'count': '$count',
              })
            : t('chatNormalRedPacket'))
        : '';
    // 主文案：红包=祝福语（微信不显示金额），转账=金额大字
    final mainText = isRed ? note : '¥${WalletStore.instance.fmt(amount)}';
    // 小字：已领状态 > 副标题 > 操作提示
    final subText = claimed
        ? (isRed ? t('chatClaimed') : t('chatAccepted'))
        : isRed
            ? (subtitle.isNotEmpty ? subtitle : t('chatTapToClaim'))
            : t('chatAppTransfer');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
        child: Row(
          children: [
            // 左侧白色图标块：红包=方形信封，转账=圆形 ¥
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: isRed ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: isRed
                    ? BorderRadius.circular(8)
                    : BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Icon(isRed ? Icons.card_giftcard : Icons.currency_yen,
                  color: iconTint, size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(mainText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: isRed ? 15 : 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(subText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.85))),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                size: 18, color: Colors.white.withValues(alpha: 0.9)),
            const SizedBox(width: 2),
          ],
        ),
      ),
    );
  }
}

/// 通话邀请气泡（TRTC 信令 type=7）
class _CallBubble extends StatelessWidget {
  final String content;
  final VoidCallback onTap;
  const _CallBubble({required this.content, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    // 解析信令：invite=通话邀请，hangup=通话记录（含时长）
    var isVideo = false;
    var action = 'invite';
    var duration = 0;
    try {
      final map = jsonDecode(content);
      if (map is Map) {
        if (map['callType'] == 'video') isVideo = true;
        action = map['action']?.toString() ?? 'invite';
        duration = int.tryParse((map['duration'] ?? 0).toString()) ?? 0;
      }
    } catch (_) {}
    final callType = t(isVideo ? 'chatCallVideo' : 'chatCallVoice');
    final isRecord = action == 'hangup';
    final durText =
        '${(duration ~/ 60).toString().padLeft(2, '0')}:${(duration % 60).toString().padLeft(2, '0')}';
    final Map<String, String> titles = {
      'invite': t('chatCallMissed', {'type': callType}),
      'cancel': t('chatCallCanceled', {'type': callType}),
      'reject': t('chatCallRejected', {'type': callType}),
      'accept': t('chatCallAccepted', {'type': callType}),
      'hangup':
          t('chatCallWithDuration', {'type': callType, 'duration': durText}),
    };
    final title = titles[action] ?? t('chatCallDefault', {'type': callType});
    final Map<String, String> subs = {
      'invite': t('chatTapToAnswer'),
      'cancel': t('chatPeerCanceled'),
      'reject': t('chatPeerRejected'),
      'accept': t('chatCallOngoing'),
      'hangup': t('chatCallLog'),
    };
    final sub = subs[action] ?? t('chatCallFallback');
    final bool isClickable = action == 'invite';
    return InkWell(
      onTap: isClickable ? onTap : null,
      child: Container(
        width: 220,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isRecord ? context.cs.surfaceContainer : context.cs.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusBubble),
        ),
        child: Row(
          children: [
            Icon(
                isClickable
                    ? (isVideo ? Icons.videocam : Icons.call)
                    : (isVideo ? Icons.videocam_outlined : Icons.call_outlined),
                size: 20,
                color: isClickable
                    ? AppTheme.primary
                    : context.cs.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isRecord
                              ? context.cs.onSurfaceVariant
                              : context.cs.onSurface)),
                  const SizedBox(height: 2),
                  Text(sub,
                      style: TextStyle(
                          fontSize: 12, color: context.cs.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageGridBubble extends StatelessWidget {
  final List<String> urls;
  const _ImageGridBubble({required this.urls});

  /// localhost/127.0.0.1 的 MinIO URL 换成当前访问主机（需求2：PC 发的图手机可见）
  static String _fixUrl(String u) {
    if (u.contains('localhost') || u.contains('127.0.0.1')) {
      try {
        final base = Uri.base;
        final host = base.host.isNotEmpty ? base.host : 'localhost';
        return u.replaceAll('localhost', host).replaceAll('127.0.0.1', host);
      } catch (_) {
        return u;
      }
    }
    return u;
  }

  @override
  Widget build(BuildContext context) {
    // 单图：直接渲染一张满宽方图。
    // 不能走 2 列网格 —— 1 张图只占左格，右格留一块空白，看起来像"发了 1 张显示 2 张"。
    if (urls.length == 1) {
      return Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          color: context.cs.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: _buildImageCell(context, urls.first),
      );
    }

    // 无 URL（content 为空的异常图片消息）：单个灰色占位，不再铺 4 个空格子
    if (urls.isEmpty) {
      return Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          color: context.cs.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Container(
          color: const Color(0xFFE9ECEF),
          alignment: Alignment.center,
          child:
              Icon(Icons.photo, color: context.cs.onSurfaceVariant, size: 28),
        ),
      );
    }

    // 多图（≥2 张）：2 列网格 + 第 5 张角标 +N
    final shown = urls.take(5).toList();
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: context.cs.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        childAspectRatio: 1,
        children: List.generate(shown.length.clamp(2, 4), (i) {
          final url = shown[i];
          return Stack(
            fit: StackFit.expand,
            children: [
              _buildImageCell(context, url),
              if (i == 3 && shown.length > 4)
                Container(
                  color: Colors.black.withValues(alpha: 0.45),
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

  /// 图片单元格：真实加载 + 点击看大图 + 加载中/失败占位（单图与网格共用）
  Widget _buildImageCell(BuildContext context, String url) {
    if (url.isEmpty) {
      return Container(
        color: const Color(0xFFE9ECEF),
        alignment: Alignment.center,
        child: Icon(Icons.photo, color: context.cs.onSurfaceVariant, size: 28),
      );
    }
    return GestureDetector(
      // 点击查看大图（全屏预览：双指/双击缩放 + 关闭按钮）
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ImageViewerPage(url: _fixUrl(url)),
        ));
      },
      child: Image.network(
        _fixUrl(url),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: const Color(0xFFE9ECEF),
          alignment: Alignment.center,
          child: Icon(Icons.broken_image_outlined,
              color: context.cs.onSurfaceVariant, size: 24),
        ),
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : Container(
                color: const Color(0xFFE9ECEF),
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
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
        color: context.cs.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusBubble),
      ),
      constraints: const BoxConstraints(maxWidth: 240),
      child: Row(
        children: [
          const Icon(Icons.description, size: 28, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name.isEmpty
                  ? AppLocalizations.of(context).t('chatFileFallback')
                  : name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: context.cs.onSurface),
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
          color: context.cs.surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(Icons.keyboard_arrow_down,
            size: 28, color: context.cs.onSurfaceVariant),
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
  final VoidCallback? onPickImage; // 需求3：相册选图发送
  final ValueChanged<String>? onMoney; // 红包/转账（redpacket / transfer）

  const _InputBar({
    required this.controller,
    required this.quoteMsg,
    required this.onClearQuote,
    required this.onSend,
    this.onMention,
    this.onCall,
    this.onPickImage,
    this.onMoney,
  });

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  bool _drawerOpen = false;
  bool _emojiOpen = false;
  bool _hasText = false;
  bool _voiceMode = false; // 语音模式：输入框变"按住说话"

  static const _emojis = [
    '😀',
    '😄',
    '😁',
    '😂',
    '😊',
    '😍',
    '🥰',
    '😘',
    '😎',
    '🤔',
    '😅',
    '😭',
    '😡',
    '👍',
    '👏',
    '🙏',
    '💪',
    '🎉',
    '❤️',
    '💙',
    '🔥',
    '✨',
    '✅',
    '👀',
    '🙌',
    '🤝',
    '🌹',
    '🎁',
    '🍵',
    '☕',
    '📌',
    '💡'
  ];

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
    final t = AppLocalizations.of(context).t;
    return Container(
      decoration: BoxDecoration(
        color: context.cs.surface,
        border: Border(
            top: BorderSide(color: context.cs.outlineVariant, width: 0.5)),
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
                color: context.cs.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.format_quote,
                      size: 16, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      t('chatQuotePrefix',
                          {'content': widget.quoteMsg!.content}),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13, color: context.cs.onSurfaceVariant),
                    ),
                  ),
                  InkWell(
                    onTap: widget.onClearQuote,
                    child: Icon(Icons.close,
                        size: 16, color: context.cs.onSurfaceVariant),
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
                  icon: Icon(
                      _voiceMode ? Icons.keyboard_alt_outlined : Icons.mic_none,
                      size: 24,
                      color: _voiceMode
                          ? AppTheme.primary
                          : context.cs.onSurfaceVariant),
                ),
                // 语音模式：输入框变"按住说话"按钮
                if (_voiceMode)
                  Expanded(
                    child: GestureDetector(
                      onTapDown: (_) =>
                          AppDialogs.toast(context, t('chatVoiceComingSoon')),
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: context.cs.surfaceContainer,
                          borderRadius: BorderRadius.circular(21),
                        ),
                        alignment: Alignment.center,
                        child: Text(t('chatHoldToTalk'),
                            style: TextStyle(
                                fontSize: 14,
                                color: context.cs.onSurfaceVariant)),
                      ),
                    ),
                  )
                else
                  Expanded(
                    // 输入框
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.cs.surfaceContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: TextField(
                        controller: widget.controller,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: t('chatMessageHint'),
                          hintStyle: TextStyle(
                              color: context.cs.onSurfaceVariant, fontSize: 14),
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
                        color: context.cs.onSurfaceVariant),
                  ),
                  IconButton(
                    onPressed: _toggleDrawer,
                    icon: Icon(
                        _drawerOpen
                            ? Icons.add_circle
                            : Icons.add_circle_outline,
                        size: 26,
                        color: context.cs.onSurfaceVariant),
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
                      children: _emojis
                          .map((e) => InkWell(
                                onTap: () {
                                  widget.controller.text += e;
                                  _onTextChanged();
                                },
                                child: Center(
                                    child: Text(e,
                                        style: const TextStyle(fontSize: 22))),
                              ))
                          .toList(),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          // 输入抽屉
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: _drawerOpen
                ? _PlusDrawer(
                    onMention: widget.onMention,
                    onItem: (name) {
                      setState(() => _drawerOpen = false);
                      // 需求11：语音/视频通话入口（TRTC）→ 交由 ChatPage 导航
                      // 抽屉项按词典 key 匹配（name 为 key，显示文案由 _PlusDrawer 翻译）
                      if (name == 'chatDrawerVoiceCall') {
                        widget.onCall?.call('voice');
                      } else if (name == 'chatDrawerVideoCall') {
                        widget.onCall?.call('video');
                      } else if (name == 'chatDrawerAlbum') {
                        // 需求3：相册选图发送（回调到 ChatPage 统一处理）
                        widget.onPickImage?.call();
                      } else if (name == 'chatDrawerRedPacket') {
                        widget.onMoney?.call('redpacket');
                      } else if (name == 'chatDrawerTransfer') {
                        widget.onMoney?.call('transfer');
                      } else {
                        AppDialogs.toast(
                            context, t('chatComingSoon', {'name': t(name)}));
                      }
                    },
                  )
                : const SizedBox.shrink(),
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
    final t = AppLocalizations.of(context).t;
    // label 存词典 key，显示时翻译；onItem 回传 key 供逻辑匹配
    final items = <_DrawerItem>[
      const _DrawerItem('chatDrawerAlbum', Icons.photo_outlined),
      const _DrawerItem('chatDrawerFile', Icons.folder_outlined),
      const _DrawerItem('chatDrawerRedPacket', Icons.card_giftcard),
      const _DrawerItem('chatDrawerTransfer', Icons.currency_yen),
      const _DrawerItem('chatDrawerVoiceCall', Icons.phone_outlined),
      const _DrawerItem('chatDrawerVideoCall', Icons.videocam_outlined),
      const _DrawerItem('chatDrawerCard', Icons.person_outline),
      const _DrawerItem('chatDrawerFavorite', Icons.star_outline),
    ];
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 18,
        crossAxisSpacing: 14,
        childAspectRatio: 0.95,
        children: items
            .map((it) => InkWell(
                  onTap: () => onItem(it.key),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: context.cs.surface,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Icon(it.icon,
                            size: 28,
                            color: it.key == 'chatDrawerRedPacket' ||
                                    it.key == 'chatDrawerTransfer'
                                ? AppTheme.primary
                                : context.cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 8),
                      Text(t(it.key),
                          style: TextStyle(
                              fontSize: 12,
                              color: context.cs.onSurfaceVariant)),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _DrawerItem {
  final String key; // 词典 key（显示时翻译，逻辑匹配用 key）
  final IconData icon;
  const _DrawerItem(this.key, this.icon);
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
  final VoidCallback onPin;
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
    required this.onPin,
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
    final t = AppLocalizations.of(context).t;
    final m = widget.msg;
    final isMine = m.senderId == widget.myId;
    final color =
        widget.colors[m.senderId.hashCode.abs() % widget.colors.length];

    return Stack(
      fit: StackFit.expand,
      children: [
        // 背景遮罩 + BackdropFilter 模糊（H5 支持 BackdropFilter）
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(color: Colors.black.withValues(alpha: 0.55)),
            ),
          ),
        ),
        // 简洁标题（替代高亮气泡：长按直接显示操作菜单）
        Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 80, 24, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    m.type == 7
                        ? Icons.call_outlined
                        : Icons.mark_chat_unread_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 12),
                Text(t('chatChooseAction'),
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
        // 顶部关闭按钮
        Positioned(
          top: 60,
          right: 20,
          child: _overlayAction(Icons.close, widget.onClose),
        ),
        // 操作行：3×2 卡片网格（复制/引用/收藏/撤回/转发/置顶）
        Positioned(
          top: MediaQuery.of(context).size.height * 0.42,
          left: 0,
          right: 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                        child: _actionChip(
                            Icons.copy, t('chatActionCopy'), widget.onCopy)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _actionChip(Icons.format_quote,
                            t('chatActionQuote'), widget.onQuote)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _actionChip(Icons.star_outline,
                            t('chatActionFavorite'), widget.onFavorite)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                        child: _actionChip(Icons.undo, t('chatActionRecall'),
                            widget.onRecall)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _actionChip(Icons.forward,
                            t('chatActionForward'), widget.onForward)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _actionChip(Icons.push_pin_outlined,
                            t('chatActionPin'), widget.onPin)),
                  ],
                ),
              ],
            ),
          ),
        ),
        // 底部：回复输入栏
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: context.cs.surface,
                border: Border(
                    top: BorderSide(
                        color: context.cs.outlineVariant, width: 0.5)),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: Icon(Icons.add_circle_outline,
                        size: 26, color: context.cs.onSurfaceVariant),
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.cs.surfaceContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: TextField(
                        controller: _input,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText:
                              t('chatReplyHint', {'name': widget.convName}),
                          hintStyle: TextStyle(
                              fontSize: 14, color: context.cs.onSurfaceVariant),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 0),
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
                    icon: Icon(Icons.emoji_emotions_outlined,
                        size: 24, color: context.cs.onSurfaceVariant),
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
          color: Colors.white.withValues(alpha: 0.92),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: context.cs.onSurface),
      ),
    );
  }

  Widget _actionChip(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: context.cs.surface,
      borderRadius: BorderRadius.circular(14),
      elevation: 2,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 68,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: AppTheme.primary),
              const SizedBox(height: 5),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: context.cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}
