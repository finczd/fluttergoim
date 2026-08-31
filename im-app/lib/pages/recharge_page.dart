import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_config.dart';
import '../l10n/app_locale.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/app_dialogs.dart';
import 'pay_records_page.dart';

/// 充值页（离线人工审核通道）微信风格：
/// 用户选支付方式 → 展示平台收款码/收款账户（银行卡信息可复制）→ 输入金额
/// → 上传支付凭证截图 → 提交；管理后台「充值订单」审核通过后余额自动到账。
/// 接口：im-server recharge_withdraw.go。
class RechargePage extends StatefulWidget {
  const RechargePage({super.key});

  @override
  State<RechargePage> createState() => _RechargePageState();
}

class _RechargePageState extends State<RechargePage> {
  final _api = ApiClient.instance;
  final _amountCtrl = TextEditingController();
  final _txNoCtrl = TextEditingController();
  final _remarkCtrl = TextEditingController();
  final _picker = ImagePicker();

  bool _loading = true;
  bool _submitting = false;
  Map<String, dynamic> _cfg = {};
  int _payMethod = 1; // 1微信 2支付宝 3银行卡
  String? _proofPath; // 本地凭证图路径（提交时上传）

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _txNoCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    Map<String, dynamic> cfg = {};
    try {
      final r = await _api.get('/api/v1/pay/config');
      if ((r.data['code'] as num?)?.toInt() == 0) {
        cfg = (r.data['data'] as Map<String, dynamic>? ?? {});
      }
    } catch (_) {}
    // 默认选中第一个有收款码的方式
    int method = 1;
    if ((cfg['receiveWechatQrcodeUrl'] ?? '').toString().isEmpty &&
        (cfg['receiveAlipayQrcodeUrl'] ?? '').toString().isNotEmpty) {
      method = 2;
    }
    if (mounted) {
      setState(() {
        _cfg = cfg;
        _payMethod = method;
        _loading = false;
      });
    }
  }

  /// 服务端返回的图片 URL 兜底拼 baseUrl
  String _absUrl(String u) {
    if (u.isEmpty) return u;
    if (u.startsWith('http')) return u;
    return '${AppConfig.instance.apiBase}$u';
  }

  String _qrcodeUrl(int method) {
    switch (method) {
      case 1:
        return (_cfg['receiveWechatQrcodeUrl'] ?? '').toString();
      case 2:
        return (_cfg['receiveAlipayQrcodeUrl'] ?? '').toString();
      case 3:
        return (_cfg['receiveBankQrcodeUrl'] ?? '').toString();
    }
    return '';
  }

  Future<void> _pickProof() async {
    try {
      final x = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85);
      if (x != null && mounted) setState(() => _proofPath = x.path);
    } catch (_) {}
  }

  Future<void> _submit() async {
    final t = AppLocalizations.of(context).t;
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount < 0.01) {
      AppDialogs.toast(context, t('rcAmountInvalid'));
      return;
    }
    if (_proofPath == null) {
      AppDialogs.toast(context, t('rcNeedProof'));
      return;
    }
    setState(() => _submitting = true);
    try {
      // 先传凭证图（文档约定目录 pay/proofs）
      final name = 'proof_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final up = await _api.uploadFile(_proofPath!, name, dir: 'pay/proofs');
      final proofUrl = (up['url'] ?? '').toString();
      // 提交充值订单
      final r = await _api.post('/api/v1/wallet/recharge/submit', data: {
        'amount': amount,
        'payMethod': _payMethod,
        'proofImage': proofUrl,
        'payTxNo': _txNoCtrl.text.trim(),
        'remark': _remarkCtrl.text.trim(),
      });
      final body = r.data as Map<String, dynamic>;
      if ((body['code'] as num?)?.toInt() == 0) {
        if (!mounted) return;
        AppDialogs.toast(context, t('rcSubmitOk'));
        _amountCtrl.clear();
        _txNoCtrl.clear();
        _remarkCtrl.clear();
        setState(() => _proofPath = null);
        _load();
      } else {
        if (!mounted) return;
        AppDialogs.toast(
            context, '${t('rcSubmitFailed')}：${body['message'] ?? ''}');
      }
    } catch (_) {
      if (mounted) AppDialogs.toast(context, t('rcSubmitFailed'));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// 复制文本到剪贴板并提示
  Future<void> _copy(String text) async {
    final t = AppLocalizations.of(context).t;
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) AppDialogs.toast(context, t('rcCopied'));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    final scheme = Theme.of(context).colorScheme;
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(t('rcTitle'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final enabled = _cfg['enabled'] == true;
    final tips = (_cfg['rechargeTips'] ?? '').toString();
    final isDark = scheme.brightness == Brightness.dark;
    return Scaffold(
      // 深色模式回退主题纯黑背景，浅色保持微信灰
      backgroundColor: isDark ? null : const Color(0xFFEDEDED),
      appBar: AppBar(
          title: Text(t('rcTitle'),
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const RechargeRecordsPage())),
              child: Text(t('payRecords'),
                  style: TextStyle(fontSize: 15, color: scheme.onSurface)),
            ),
          ]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          if (!enabled)
            _card(
                child: Row(children: [
              Icon(Icons.info_outline,
                  size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(t('rcNotEnabled'),
                      style: TextStyle(
                          fontSize: 13, color: scheme.onSurfaceVariant))),
            ]))
          else ...[
            // 支付方式（微信风格：白底列表单选）
            _card(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  _methodRow(1, Icons.chat_rounded, t('rcPayMethodWechat')),
                  Divider(height: 1, indent: 14, color: scheme.outlineVariant),
                  _methodRow(2, Icons.payment_outlined, t('rcPayMethodAlipay')),
                  Divider(height: 1, indent: 14, color: scheme.outlineVariant),
                  _methodRow(
                      3, Icons.account_balance_outlined, t('rcPayMethodBank')),
                ])),
            const SizedBox(height: 12),
            // 收款码 + 收款账户（银行卡信息可复制）
            _card(
                child: Column(children: [
              Text(
                _payMethod == 1
                    ? t('rcPayMethodWechat')
                    : _payMethod == 2
                        ? t('rcPayMethodAlipay')
                        : t('rcPayMethodBank'),
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface),
              ),
              const SizedBox(height: 12),
              Container(
                width: 180,
                height: 180,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _qrcodeUrl(_payMethod).isNotEmpty
                    ? Image.network(_absUrl(_qrcodeUrl(_payMethod)),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(Icons.qr_code_2,
                            size: 56, color: scheme.onSurfaceVariant))
                    : Icon(Icons.qr_code_2,
                        size: 56, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              Text(t('rcScanTips'),
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              // 银行卡：收款账户信息（每项可复制）
              if (_payMethod == 3) ...[
                const SizedBox(height: 12),
                Divider(height: 1, color: scheme.outlineVariant),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    children: [
                      _copyRow(
                          t('rcBankName'),
                          (_cfg['receiveBankInfo']?['bankName'] ?? '')
                              .toString()),
                      _copyRow(
                          t('rcCardNo'),
                          (_cfg['receiveBankInfo']?['cardNo'] ?? '')
                              .toString()),
                      _copyRow(
                          t('rcPayeeName'),
                          (_cfg['receiveBankInfo']?['accountName'] ?? '')
                              .toString()),
                    ],
                  ),
                ),
              ],
              if (tips.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(tips,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ])),
            const SizedBox(height: 12),
            // 金额（白底行式输入，¥ 在输入左侧）
            _card(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(children: [
                  Text(t('rcAmount'),
                      style: TextStyle(fontSize: 15, color: scheme.onSurface)),
                  const SizedBox(width: 12),
                  Text('¥',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _amountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface),
                      decoration: InputDecoration(
                        hintText: t('rcAmountHint'),
                        hintStyle: TextStyle(
                            fontSize: 15, color: scheme.outlineVariant),
                        filled: false,
                        border: InputBorder.none,
                        isCollapsed: true,
                      ),
                    ),
                  ),
                ])),
            const SizedBox(height: 12),
            // 支付凭证（白底卡：标题 + 上传方框）
            _card(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(t('rcProof'),
                      style: TextStyle(fontSize: 15, color: scheme.onSurface)),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _pickProof,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: scheme.outlineVariant,
                            width: 1,
                            strokeAlign: BorderSide.strokeAlignInside),
                      ),
                      child: _proofPath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(File(_proofPath!),
                                  fit: BoxFit.cover))
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined,
                                    size: 30, color: scheme.onSurfaceVariant),
                                const SizedBox(height: 6),
                                Text(t('rcProofPick'),
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: scheme.onSurfaceVariant)),
                              ],
                            ),
                    ),
                  ),
                ])),
            const SizedBox(height: 12),
            // 单号 + 备注（白底行式）
            _card(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  _rowInput(t('rcTxNo'), _txNoCtrl, t('rcTxNoHint')),
                  Divider(height: 1, indent: 14, color: scheme.outlineVariant),
                  _rowInput(t('rcRemark'), _remarkCtrl, t('rcRemarkHint')),
                ])),
            const SizedBox(height: 24),
            // 提交按钮（微信橙）
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFA9D3B),
                  disabledBackgroundColor: const Color(0xFFF7C9A0),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(t('rcSubmit'),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 支付方式单选行（微信风格：左图标 + 名称 + 右圆形单选）
  Widget _methodRow(int method, IconData icon, String label) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _payMethod == method;
    return InkWell(
      onTap: () => setState(() => _payMethod = method),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Icon(icon,
                size: 22,
                color: selected
                    ? const Color(0xFFFA9D3B)
                    : scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: scheme.onSurface)),
            ),
            _radio(selected),
          ],
        ),
      ),
    );
  }

  /// 圆形单选指示器
  Widget _radio(bool selected) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? const Color(0xFFFA9D3B) : Colors.transparent,
        border: Border.all(
            color: selected ? const Color(0xFFFA9D3B) : scheme.outlineVariant,
            width: selected ? 0 : 1.5),
      ),
      alignment: Alignment.center,
      child: selected
          ? const Icon(Icons.check, size: 13, color: Colors.white)
          : null,
    );
  }

  /// 收款账户信息行：标签 + 值 + 复制按钮
  Widget _copyRow(String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context).t;
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
              width: 76,
              child: Text(label,
                  style:
                      TextStyle(fontSize: 13, color: scheme.onSurfaceVariant))),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface)),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _copy(value),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.copy_rounded,
                    size: 12, color: scheme.onSurfaceVariant),
                const SizedBox(width: 3),
                Text(t('rcCopy'),
                    style: TextStyle(
                        fontSize: 11, color: scheme.onSurfaceVariant)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  /// 白底行式输入（无描边、无灰底填充、isCollapsed 防 hint 裁剪）
  Widget _rowInput(String label, TextEditingController ctrl, String hint) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          SizedBox(
              width: 76,
              child: Text(label,
                  style: TextStyle(fontSize: 14, color: scheme.onSurface))),
          Expanded(
            child: TextField(
              controller: ctrl,
              style: TextStyle(fontSize: 14, color: scheme.onSurface),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle:
                    TextStyle(fontSize: 14, color: scheme.outlineVariant),
                filled: false,
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsetsGeometry? padding}) =>
      Container(
        width: double.infinity,
        padding: padding ?? const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.cs.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: child,
      );
}
