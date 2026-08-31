import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_locale.dart';
import '../services/wallet_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_dialogs.dart';

/// 发红包页（独立页面，微信流程对齐）
/// - 单聊：普通红包（留言默认"恭喜发财，大吉大利"）
/// - 群聊：拼手气红包 / 普通红包 二选一 + 个数
/// 返回 payload：{mode:'lucky'|'normal', amount, count, note}
class RedPacketPage extends StatefulWidget {
  final bool isGroup;
  const RedPacketPage({super.key, required this.isGroup});

  @override
  State<RedPacketPage> createState() => _RedPacketPageState();
}

class _RedPacketPageState extends State<RedPacketPage> {
  String _mode = 'lucky'; // lucky 拼手气 / normal 普通
  final _amountCtrl = TextEditingController();
  final _countCtrl = TextEditingController();
  final _noteCtrl = TextEditingController(text: '恭喜发财，大吉大利');

  double get _amount => double.tryParse(_amountCtrl.text.trim()) ?? 0;
  int get _count => int.tryParse(_countCtrl.text.trim()) ?? 1;

  // ===== 余额（B-19：发红包前必须校验，不能让 0 余额发出去）=====
  double _balance = 0;
  bool _balanceLoading = true;

  /// 本次将从零钱扣除的总额（必须与后端 service.moneyMsgAmount 算法一致）：
  /// - 拼手气：填的就是总金额 → 扣 amount
  /// - 普通红包：填的是单个金额 → 扣 amount × count
  double get _total {
    final a = _amount;
    if (a <= 0) return 0;
    final isLucky = widget.isGroup && _mode == 'lucky';
    if (isLucky) return a;
    final c = widget.isGroup ? _count : 1;
    return a * (c < 1 ? 1 : c);
  }

  bool get _overBalance => !_balanceLoading && _total > _balance;

  @override
  void initState() {
    super.initState();
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
    _countCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    // 合计文案：拼手气=总金额；普通=单个金额×个数
    final totalText = widget.isGroup && _mode == 'normal' && _count > 1
        ? t('redPacketNormalTotal', {
            'total': _fmt(_amount * _count),
            'single': _fmt(_amount),
            'count': '$_count',
          })
        : '¥${_fmt(_amount)}${widget.isGroup && _mode == 'lucky' && _count > 1 ? t('redPacketLuckyCount', {
                'count': '$_count'
              }) : ''}';
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? null
          : const Color(0xFFEDEDED),
      appBar: AppBar(
        title: Text(
            widget.isGroup ? t('redPacketTitleGroup') : t('redPacketTitle'),
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: context.cs.onSurface)),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 12),
        children: [
          // 顶部金币装饰（微信发红包页风格）
          Container(
            color: context.cs.surface,
            padding: const EdgeInsets.symmetric(vertical: 22),
            child: Center(
              child: Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFE9564E), Color(0xFFD6453F)],
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: Color(0x33E9564E),
                        blurRadius: 12,
                        offset: Offset(0, 4)),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.currency_yen,
                    color: Color(0xFFFFE08A), size: 32),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // 群聊：红包类型切换（微信风格分段选择）
          if (widget.isGroup) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: context.cs.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    _modeTab(
                        t('redPacketLucky'), t('redPacketLuckyDesc'), 'lucky'),
                    _modeTab(t('redPacketNormal'), t('redPacketNormalDesc'),
                        'normal'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          // 表单：金额 / 个数 / 留言（微信白底行式）
          Container(
            color: context.cs.surface,
            child: Column(
              children: [
                _field(
                  label: widget.isGroup && _mode == 'lucky'
                      ? t('redPacketTotalAmount')
                      : t('redPacketSingleAmount'),
                  suffix: t('rpUnitYuan'),
                  child: TextField(
                    controller: _amountCtrl,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d{0,6}\.?\d{0,2}$')),
                    ],
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: context.cs.onSurface),
                    decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: '0.00',
                        hintStyle: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: context.cs.outlineVariant)),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                Divider(
                    height: 1, indent: 14, color: context.cs.outlineVariant),
                if (widget.isGroup) ...[
                  _field(
                    label: t('redPacketCountLabel'),
                    suffix: t('rpUnitCount'),
                    child: TextField(
                      controller: _countCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: t('redPacketCountHint')),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  Divider(
                      height: 1, indent: 14, color: context.cs.outlineVariant),
                ],
                _field(
                  label: t('redPacketNoteLabel'),
                  child: TextField(
                    controller: _noteCtrl,
                    maxLength: 25,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: t('redPacketNoteHint'),
                        counterText: ''),
                  ),
                ),
              ],
            ),
          ),
          // 冻结提示 + 余额（B-19/B-22）
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              t('redPacketFreezeNotice', {'amount': _fmt(_total)}),
              style:
                  TextStyle(fontSize: 12, color: context.cs.onSurfaceVariant),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Row(
              children: [
                Text(
                  _balanceLoading
                      ? t('redPacketBalanceLoading')
                      : t('redPacketAvailableBalance',
                          {'amount': _fmt(_balance)}),
                  style: TextStyle(
                      fontSize: 12, color: context.cs.onSurfaceVariant),
                ),
                const Spacer(),
                if (_overBalance)
                  Text(t('redPacketInsufficient'),
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.danger,
                          fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // 微信橙「塞钱进红包」按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _canSend ? _submit : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFA9D3B),
                  disabledBackgroundColor: const Color(0xFFF7C9A0),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(t('redPacketSendButton'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(totalText,
                style: TextStyle(
                    fontSize: 13, color: context.cs.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }

  Widget _modeTab(String title, String sub, String mode) {
    final active = _mode == mode;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _mode = mode),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFFA9D3B) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: active ? Colors.white : context.cs.onSurface)),
              Text(sub,
                  style: TextStyle(
                      fontSize: 10,
                      color: active
                          ? Colors.white.withValues(alpha: 0.85)
                          : context.cs.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }

  /// 微信行式表单：左侧标签 + 中间输入 + 右侧单位
  Widget _field(
      {required String label, required Widget child, String? suffix}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
      constraints: const BoxConstraints(minHeight: 52),
      child: Row(
        children: [
          SizedBox(
              width: 72,
              child: Text(label,
                  style: TextStyle(fontSize: 14, color: context.cs.onSurface))),
          Expanded(child: child),
          if (suffix != null)
            Text(suffix,
                style: TextStyle(
                    fontSize: 14, color: context.cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  bool get _canSend => _total > 0 && !_overBalance;

  void _submit() {
    final t = AppLocalizations.of(context).t;
    if (_amount <= 0) {
      AppDialogs.toast(context, t('redPacketInvalidAmount'));
      return;
    }
    if (widget.isGroup && _count < 1) {
      AppDialogs.toast(context, t('redPacketCountRequired'));
      return;
    }
    // 交叉验证第一道：提交前再确认一次余额（后端发消息时还会再校验一次）
    if (_balanceLoading) {
      AppDialogs.toast(context, t('redPacketReadingBalance'));
      return;
    }
    if (_total > _balance) {
      AppDialogs.toast(context,
          t('redPacketBalanceInsufficient', {'amount': _fmt(_balance)}));
      return;
    }
    Navigator.pop(context, {
      'mode': widget.isGroup ? _mode : 'normal',
      'amount': _amount,
      'count': widget.isGroup ? _count : 1,
      'note':
          _noteCtrl.text.trim().isEmpty ? '恭喜发财，大吉大利' : _noteCtrl.text.trim(),
    });
  }

  String _fmt(double v) {
    final s = v.toStringAsFixed(2);
    return s.endsWith('.00') ? v.toStringAsFixed(0) : s;
  }
}
