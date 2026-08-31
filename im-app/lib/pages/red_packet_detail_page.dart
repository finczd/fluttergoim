import 'package:flutter/material.dart';

import '../l10n/app_locale.dart';
import '../services/moment_service.dart';
import '../theme/app_theme.dart';

/// 红包领取详情页（微信风格：红包封面信息 + 领取列表 + 已领 x/y 个）
class RedPacketDetailPage extends StatefulWidget {
  final String msgId;
  const RedPacketDetailPage({super.key, required this.msgId});

  @override
  State<RedPacketDetailPage> createState() => _RedPacketDetailPageState();
}

class _RedPacketDetailPageState extends State<RedPacketDetailPage> {
  final _svc = MomentService.instance;
  bool _loading = true;
  Map<String, dynamic> _detail = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await _svc.redPacketDetail(widget.msgId);
      if (mounted) {
        setState(() {
          _detail = d;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(num? v) {
    final d = (v ?? 0).toDouble();
    final s = d.toStringAsFixed(2);
    return s.endsWith('.00') ? d.toStringAsFixed(0) : s;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    final note =
        (_detail['note'] ?? t('redPacketDetailDefaultNote')).toString();
    final senderName =
        (_detail['senderName'] ?? t('redPacketDetailDefaultSender')).toString();
    final senderAvatar = (_detail['senderAvatar'] ?? '').toString();
    final claimedCnt = (_detail['claimedCnt'] as num?)?.toInt() ?? 0;
    final count = (_detail['count'] as num?)?.toInt() ?? 1;
    final claimedSum = (_detail['claimedSum'] as num?)?.toDouble() ?? 0;
    final mode = (_detail['mode'] ?? 'normal').toString();
    final totalAmount = (_detail['totalAmount'] as num?)?.toDouble() ?? 0;
    final list = ((_detail['list'] as List<dynamic>?) ?? [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
    // 资金包状态（B-22）：1进行中 2已领完 3已过期退回 4已关闭（旧版本遗留数据）
    final status = (_detail['status'] as num?)?.toInt() ?? 0;
    final expireAt = (_detail['expireAt'] ?? '').toString();
    final remain =
        (totalAmount - claimedSum) < 0 ? 0.0 : (totalAmount - claimedSum);

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? null
          : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(t('redPacketDetailTitle'),
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: context.cs.onSurface)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE9564E)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 红包封面信息（微信风格：橙红头部 + 领取摘要）
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFE9564E), Color(0xFFD6453F)],
                    ),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(14)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              shape: BoxShape.circle,
                            ),
                            clipBehavior: Clip.antiAlias,
                            alignment: Alignment.center,
                            child: senderAvatar.isNotEmpty
                                ? Image.network(senderAvatar,
                                    width: 44,
                                    height: 44,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                        Icons.person,
                                        color: Colors.white,
                                        size: 22))
                                : Text(
                                    senderName.isEmpty
                                        ? '?'
                                        : senderName.characters.first,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                                t('redPacketDetailFrom', {'name': senderName}),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(note,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14)),
                      const SizedBox(height: 12),
                      // 微信风格：红包总额金色大字
                      Text('¥${_fmt(totalAmount)}',
                          style: const TextStyle(
                              color: Color(0xFFFFE08A),
                              fontSize: 30,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      Text(
                        mode == 'lucky'
                            ? t('redPacketDetailLuckySummary', {
                                'amount': _fmt(totalAmount),
                                'count': '$count'
                              })
                            : t('redPacketDetailNormalSummary', {
                                'amount': _fmt(totalAmount),
                                'count': '$count'
                              }),
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // 领取摘要条
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFDF0EF),
                    borderRadius:
                        BorderRadius.vertical(bottom: Radius.circular(14)),
                  ),
                  child: Text(
                    _summaryText(
                        status: status,
                        claimedCnt: claimedCnt,
                        count: count,
                        claimedSum: claimedSum,
                        remain: remain),
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(fontSize: 13, color: Color(0xFFB23B3B)),
                  ),
                ),
                // 进行中：提示过期时间，让用户知道钱什么时候退回
                if (status == 1 && expireAt.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      t('redPacketDetailExpireNotice', {'time': expireAt}),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12, color: context.cs.onSurfaceVariant),
                    ),
                  ),
                const SizedBox(height: 12),
                // 领取列表
                Container(
                  decoration: BoxDecoration(
                    color: context.cs.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: list.isEmpty
                      ? Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: Center(
                              child: Text(t('redPacketDetailNobodyClaimed'),
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: context.cs.onSurfaceVariant))),
                        )
                      : Column(
                          children: [
                            for (var i = 0; i < list.length; i++) ...[
                              _claimRow(list[i]),
                              if (i != list.length - 1)
                                Divider(
                                    height: 1,
                                    indent: 16,
                                    color: context.cs.outlineVariant),
                            ],
                          ],
                        ),
                ),
              ],
            ),
    );
  }

  /// 领取摘要文案：区分「抢光 / 进行中 / 已过期退回 / 旧数据已关闭」
  String _summaryText({
    required int status,
    required int claimedCnt,
    required int count,
    required double claimedSum,
    required double remain,
  }) {
    final t = AppLocalizations.of(context).t;
    if (status == 3) {
      return remain > 0
          ? t('redPacketDetailExpiredPartial', {'amount': _fmt(remain)})
          : t('redPacketDetailExpiredFull');
    }
    if (status == 4) {
      return t('redPacketDetailLegacyClosed');
    }
    if (claimedCnt >= count) {
      return t('redPacketDetailAllClaimed',
          {'amount': _fmt(claimedSum), 'count': '$count'});
    }
    return t('redPacketDetailClaimedSummary', {
      'claimed': '$claimedCnt',
      'total': '$count',
      'amount': _fmt(claimedSum)
    });
  }

  Widget _claimRow(Map<String, dynamic> r) {
    final t = AppLocalizations.of(context).t;
    final name = (r['userName'] ?? t('redPacketDetailDefaultUser')).toString();
    final avatar = (r['avatar'] ?? '').toString();
    final amount = (r['amount'] as num?)?.toDouble() ?? 0;
    final time = (r['createdAt'] ?? '').toString();
    final best = r['seq'] == 1 &&
        (_detail['mode'] ?? '') == 'lucky' &&
        (_detail['claimedCnt'] as num? ?? 0) >= 1;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
                color: Color(0xFFE9564E), shape: BoxShape.circle),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            child: avatar.isNotEmpty
                ? Image.network(avatar,
                    width: 38,
                    height: 38,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Text(name.characters.first,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)))
                : Text(name.characters.first,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style:
                        TextStyle(fontSize: 15, color: context.cs.onSurface)),
                Text(time,
                    style: TextStyle(
                        fontSize: 12, color: context.cs.onSurfaceVariant)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('¥${_fmt(amount)}',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB23B3B))),
              if (best)
                Text(t('redPacketDetailBestLuck'),
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFFF5A623))),
            ],
          ),
        ],
      ),
    );
  }
}
