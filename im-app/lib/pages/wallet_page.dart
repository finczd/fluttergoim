import 'package:flutter/material.dart';

import '../l10n/app_locale.dart';
import '../services/wallet_store.dart';
import 'bill_page.dart';
import 'recharge_page.dart';
import 'withdraw_page.dart';
import '../theme/app_theme.dart';

/// 零钱 / 我的钱包（余额 + 交易记录）
/// 数据源统一走 WalletStore（后端 user.balance），与"我的"页共享同一份缓存，
/// 避免出现两个页面余额不一致（B-20）。
class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  bool _loading = true;
  double _balance = 0;
  double _frozen = 0;
  List<Map<String, dynamic>> _records = [];

  VoidCallback? _onStoreChanged;

  @override
  void initState() {
    super.initState();
    _load();
    // B-24：余额变动现在是服务端 WS 主动推的，本页不能只认进页面时的那次快照，
    // 否则后台加了钱、红包被人领走时页面还停在旧值。跟着 WalletStore 走即可。
    _onStoreChanged = () {
      if (!mounted) return;
      setState(() {
        _balance = WalletStore.instance.balance;
        _frozen = WalletStore.instance.frozen;
        _records = WalletStore.instance.records;
      });
    };
    WalletStore.instance.balanceNotifier.addListener(_onStoreChanged!);
    WalletStore.instance.frozenNotifier.addListener(_onStoreChanged!);
  }

  @override
  void dispose() {
    final cb = _onStoreChanged;
    if (cb != null) {
      WalletStore.instance.balanceNotifier.removeListener(cb);
      WalletStore.instance.frozenNotifier.removeListener(cb);
    }
    super.dispose();
  }

  /// 每次进页面都强刷一次（不等缓存），保证后台调整过的余额能立刻看到（B-20）
  Future<void> _load() async {
    await WalletStore.instance.refresh();
    if (!mounted) return;
    setState(() {
      _balance = WalletStore.instance.balance;
      _frozen = WalletStore.instance.frozen;
      _records = WalletStore.instance.records;
      _loading = false;
    });
  }

  String _fmt(double v) {
    final s = v.toStringAsFixed(2);
    return s.endsWith('.00') ? v.toStringAsFixed(0) : s;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    final records = _records;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(t('walletTitle'),
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: context.cs.onSurface)),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const BillPage())),
            icon: Icon(Icons.receipt_long_outlined,
                size: 18, color: context.cs.onSurface),
            label: Text(t('walletBill'),
                style: TextStyle(fontSize: 14, color: context.cs.onSurface)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 余额卡
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF5A623), Color(0xFFF7C77E)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF5A623).withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('walletAvailableBalance'),
                    style:
                        const TextStyle(fontSize: 13, color: Colors.white70)),
                const SizedBox(height: 8),
                Text('¥ ${_fmt(_balance)}',
                    style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                const SizedBox(height: 10),
                // 冻结金额（B-22）：发出的红包/转账还没被领走的部分，24h 未领自动退回
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_clock,
                          size: 14, color: Colors.white70),
                      const SizedBox(width: 6),
                      Text(t('walletFrozen'),
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white70)),
                      Text('¥ ${_fmt(_frozen)}',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                      const Spacer(),
                      Text(t('walletAutoRefund'),
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white70)),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(t('walletRecordHint'),
                    style:
                        const TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            ),
          ),
          // 充值 / 提现（离线人工审核通道，后台充值订单/提现审核）
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const RechargePage())),
                    icon: const Icon(Icons.account_balance_wallet_outlined,
                        size: 18),
                    label: Text(t('walletRecharge')),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF5A623),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const WithdrawPage())),
                    icon: const Icon(Icons.savings_outlined, size: 18),
                    label: Text(t('walletWithdraw')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF5A623),
                      side: const BorderSide(color: Color(0xFFF5A623)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(t('walletTransactions'),
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.cs.onSurface)),
          const SizedBox(height: 8),
          if (records.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 56),
              decoration: BoxDecoration(
                color: context.cs.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 48,
                      color:
                          context.cs.onSurfaceVariant.withValues(alpha: 0.5)),
                  const SizedBox(height: 10),
                  Text(t('walletNoRecords'),
                      style: TextStyle(
                          fontSize: 13, color: context.cs.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text(t('walletRecordAuto'),
                      style: TextStyle(
                          fontSize: 11, color: context.cs.onSurfaceVariant)),
                ],
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: context.cs.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < records.length; i++) ...[
                    _recordRow(records[i]),
                    if (i != records.length - 1)
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

  Widget _recordRow(Map<String, dynamic> r) {
    // 后端流水：amount 正=入账 负=支出；title/typeName/createdAt 已格式化
    final amount = (r['amount'] as num?)?.toDouble() ?? 0;
    final income = amount >= 0;
    final title = (r['title'] ?? r['typeName'] ?? '').toString();
    final createdAt = (r['createdAt'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color:
                  (income ? const Color(0xFFE9564E) : const Color(0xFFF5A623))
                      .withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              income ? Icons.south_west : Icons.north_east,
              size: 18,
              color: income ? const Color(0xFFE9564E) : const Color(0xFFF5A623),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        TextStyle(fontSize: 15, color: context.cs.onSurface)),
                Text(createdAt,
                    style: TextStyle(
                        fontSize: 12, color: context.cs.onSurfaceVariant)),
              ],
            ),
          ),
          Text(
            '${income ? '+' : '-'}¥${_fmt(amount.abs())}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: income ? const Color(0xFF34A853) : context.cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
