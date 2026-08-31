import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_locale.dart';
import '../services/wallet_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_dialogs.dart';

/// 转账页（微信风格）
/// 单聊直接进入；群聊先选收款人再进入（带 peerName/peerId）
/// 返回 payload：{amount, note, toUserId, toName}
class TransferPage extends StatefulWidget {
  final String peerName;
  final String? peerId; // 群转账时为所选收款人
  const TransferPage({super.key, required this.peerName, this.peerId});

  @override
  State<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _focus = FocusNode();

  double get _amount => double.tryParse(_amountCtrl.text.trim()) ?? 0;

  // ===== 余额（B-19：转账前必须校验，不能让 0 余额转出去）=====
  double _balance = 0;
  bool _balanceLoading = true;

  bool get _overBalance => !_balanceLoading && _amount > _balance;
  bool get _canSubmit => _amount > 0 && !_overBalance;

  String _fmt(double v) {
    final s = v.toStringAsFixed(2);
    return s.endsWith('.00') ? v.toStringAsFixed(0) : s;
  }

  @override
  void initState() {
    super.initState();
    _amountCtrl.addListener(() => setState(() {}));
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    await WalletStore.instance.refresh();
    if (!mounted) return;
    setState(() {
      _balance = WalletStore.instance.balance;
      _balanceLoading = false;
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? null
          : const Color(0xFFEDEDED),
      appBar: AppBar(
        title: Text(t('transferTitle'),
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: context.cs.onSurface)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 收款人卡片
          Container(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            decoration: BoxDecoration(
              color: context.cs.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                      color: Color(0xFFF5A623), shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(
                      widget.peerName.isEmpty
                          ? '?'
                          : widget.peerName.characters.first,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t('transferTo', {'name': widget.peerName}),
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: context.cs.onSurface)),
                      const SizedBox(height: 3),
                      Text(
                          widget.peerId == null || widget.peerId!.isEmpty
                              ? t('transferSingleChat')
                              : t('transferGroupChat'),
                          style: TextStyle(
                              fontSize: 12,
                              color: context.cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                const Icon(Icons.verified_user,
                    size: 18, color: Color(0xFF34A853)),
                const SizedBox(width: 4),
                Text(t('transferVerified'),
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF34A853))),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // 转账金额卡（微信风格：白底大字输入）
          Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            decoration: BoxDecoration(
              color: context.cs.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('transferAmountLabel'),
                    style: TextStyle(
                        fontSize: 13, color: context.cs.onSurfaceVariant)),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('¥',
                        style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: context.cs.onSurface)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _amountCtrl,
                        focusNode: _focus,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d{0,6}\.?\d{0,2}$')),
                        ],
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: context.cs.onSurface),
                        decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            hintText: '0.00',
                            hintStyle: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFC8C8C8))),
                      ),
                    ),
                  ],
                ),
                Divider(height: 24, color: context.cs.outlineVariant),
                // 可用余额 + 超额提示（B-19）
                Row(
                  children: [
                    Text(
                      _balanceLoading
                          ? t('transferBalanceLoading')
                          : t('transferAvailableBalance',
                              {'amount': _fmt(_balance)}),
                      style: TextStyle(
                          fontSize: 12, color: context.cs.onSurfaceVariant),
                    ),
                    const Spacer(),
                    if (_overBalance)
                      Text(t('transferInsufficient'),
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.danger,
                              fontWeight: FontWeight.w600)),
                  ],
                ),
                // B-22：转账发出后金额冻结，对方 24 小时未收款自动退回
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    t('transferFreezeNotice'),
                    style: TextStyle(
                        fontSize: 12, color: context.cs.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _noteCtrl,
                  maxLength: 10,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                      hintText: t('transferNoteHint'),
                      hintStyle:
                          TextStyle(fontSize: 14, color: Color(0xFFB8B8B8)),
                      border: InputBorder.none,
                      counterText: '',
                      isDense: true,
                      contentPadding: EdgeInsets.zero),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // 转账按钮（金额有效才可点）
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: _canSubmit ? _submit : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFA9D3B),
                disabledBackgroundColor: const Color(0xFFF7C9A0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(t('transferSubmit'),
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(t('transferConfirmNotice'),
                style: TextStyle(
                    fontSize: 12, color: context.cs.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final t = AppLocalizations.of(context).t;
    if (_amount <= 0) {
      AppDialogs.toast(context, t('transferInvalidAmount'));
      return;
    }
    // 交叉验证第一道：提交前再确认一次余额（后端发消息时还会再校验一次）
    if (_balanceLoading) {
      AppDialogs.toast(context, t('transferReadingBalance'));
      return;
    }
    if (_amount > _balance) {
      AppDialogs.toast(context,
          t('transferBalanceInsufficient', {'amount': _fmt(_balance)}));
      return;
    }
    Navigator.pop(context, {
      'amount': _amount,
      'note': _noteCtrl.text.trim(),
      'toUserId': widget.peerId ?? '',
      'toName': widget.peerName,
    });
  }
}
