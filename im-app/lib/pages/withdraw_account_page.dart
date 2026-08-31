import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_config.dart';
import '../l10n/app_locale.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/app_dialogs.dart';

/// 提现收款方式绑定页（一人只能绑定一种，账号唯一）微信风格：
///   微信：微信收款码图片 + 收款姓名
///   支付宝：收款码图片 + 支付宝账号 + 姓名
///   银行卡：卡号 + 开户银行 + 银行卡姓名
/// 接口：GET/PUT /api/v1/wallet/withdraw-account（服务端按 accountType 校验必填）。
class WithdrawAccountPage extends StatefulWidget {
  const WithdrawAccountPage({super.key});

  @override
  State<WithdrawAccountPage> createState() => _WithdrawAccountPageState();
}

class _WithdrawAccountPageState extends State<WithdrawAccountPage> {
  final _api = ApiClient.instance;
  final _picker = ImagePicker();

  // 微信
  final _wechatNameCtrl = TextEditingController();
  // 支付宝
  final _alipayAccountCtrl = TextEditingController();
  final _alipayNameCtrl = TextEditingController();
  // 银行卡
  final _bankCardCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _bankAccNameCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  int _type = 1; // 1微信 2支付宝 3银行卡
  String _wechatQrUrl = ''; // 已绑定的微信收款码（服务端 URL）
  String _alipayQrUrl = ''; // 已绑定的支付宝收款码
  String? _wechatQrPath; // 本地新选的收款码（提交时上传替换）
  String? _alipayQrPath;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _wechatNameCtrl.dispose();
    _alipayAccountCtrl.dispose();
    _alipayNameCtrl.dispose();
    _bankCardCtrl.dispose();
    _bankNameCtrl.dispose();
    _bankAccNameCtrl.dispose();
    super.dispose();
  }

  String _absUrl(String u) {
    if (u.isEmpty) return u;
    if (u.startsWith('http')) return u;
    return '${AppConfig.instance.apiBase}$u';
  }

  Future<void> _load() async {
    Map<String, dynamic> wa = {};
    try {
      final r = await _api.get('/api/v1/wallet/withdraw-account');
      if ((r.data['code'] as num?)?.toInt() == 0) {
        wa = (r.data['data'] as Map<String, dynamic>? ?? {});
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _type = (wa['accountType'] as num?)?.toInt() ?? 1;
        _wechatNameCtrl.text = (wa['wechatName'] ?? '').toString();
        _wechatQrUrl = (wa['wechatQrcodeUrl'] ?? '').toString();
        _alipayAccountCtrl.text = (wa['alipayAccount'] ?? '').toString();
        _alipayNameCtrl.text = (wa['alipayName'] ?? '').toString();
        _alipayQrUrl = (wa['alipayQrcodeUrl'] ?? '').toString();
        _bankCardCtrl.text = (wa['bankCardNo'] ?? '').toString();
        _bankNameCtrl.text = (wa['bankName'] ?? '').toString();
        _bankAccNameCtrl.text = (wa['bankAccountName'] ?? '').toString();
        _loading = false;
      });
    }
  }

  Future<void> _pickQr(bool isWechat) async {
    try {
      final x = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 90);
      if (x != null && mounted) {
        setState(() {
          if (isWechat) {
            _wechatQrPath = x.path;
          } else {
            _alipayQrPath = x.path;
          }
        });
      }
    } catch (_) {}
  }

  /// 上传收款码图（有新选图才传），返回最终 URL（文档约定目录 pay/qrcodes）
  Future<String> _uploadQrIfNeeded(String localPath, String oldUrl) async {
    if (localPath.isEmpty) return oldUrl;
    final name = 'qrcode_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final up = await _api.uploadFile(localPath, name, dir: 'pay/qrcodes');
    return (up['url'] ?? '').toString();
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context).t;
    // 前端先按类型校验必填（与服务端对齐：收款码为建议上传，非必填）
    switch (_type) {
      case 1:
        if (_wechatNameCtrl.text.trim().isEmpty) {
          AppDialogs.toast(context, t('wdNeedWechat'));
          return;
        }
        break;
      case 2:
        if (_alipayAccountCtrl.text.trim().isEmpty ||
            _alipayNameCtrl.text.trim().isEmpty) {
          AppDialogs.toast(context, t('wdNeedAlipay'));
          return;
        }
        break;
      case 3:
        if (_bankCardCtrl.text.trim().isEmpty ||
            _bankNameCtrl.text.trim().isEmpty ||
            _bankAccNameCtrl.text.trim().isEmpty) {
          AppDialogs.toast(context, t('wdNeedBank'));
          return;
        }
        break;
    }
    setState(() => _saving = true);
    try {
      final wechatQr =
          await _uploadQrIfNeeded(_wechatQrPath ?? '', _wechatQrUrl);
      final alipayQr =
          await _uploadQrIfNeeded(_alipayQrPath ?? '', _alipayQrUrl);
      // 未选中类型的字段传空，服务端会清理
      final r = await _api.put('/api/v1/wallet/withdraw-account', data: {
        'accountType': _type,
        'wechatQrcodeUrl': _type == 1 ? wechatQr : '',
        'wechatName': _type == 1 ? _wechatNameCtrl.text.trim() : '',
        'alipayQrcodeUrl': _type == 2 ? alipayQr : '',
        'alipayAccount': _type == 2 ? _alipayAccountCtrl.text.trim() : '',
        'alipayName': _type == 2 ? _alipayNameCtrl.text.trim() : '',
        'bankCardNo': _type == 3 ? _bankCardCtrl.text.trim() : '',
        'bankName': _type == 3 ? _bankNameCtrl.text.trim() : '',
        'bankAccountName': _type == 3 ? _bankAccNameCtrl.text.trim() : '',
      });
      final body = r.data as Map<String, dynamic>;
      if ((body['code'] as num?)?.toInt() == 0) {
        if (!mounted) return;
        AppDialogs.toast(context, t('wdSaveOk'));
        Navigator.of(context).pop();
      } else {
        if (!mounted) return;
        AppDialogs.toast(
            context, '${t('wdSaveFailed')}：${body['message'] ?? ''}');
      }
    } catch (_) {
      if (mounted) AppDialogs.toast(context, t('wdSaveFailed'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    final scheme = Theme.of(context).colorScheme;
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(t('wdBindTitle'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      // 深色模式回退主题纯黑背景，浅色保持微信灰
      backgroundColor:
          scheme.brightness == Brightness.dark ? null : const Color(0xFFEDEDED),
      appBar: AppBar(
          title: Text(t('wdBindTitle'),
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          // 绑定提示（白底卡）
          _card(
              child: Row(children: [
            Icon(Icons.info_outline, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
                child: Text(t('wdHint'),
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant))),
          ])),
          const SizedBox(height: 12),
          // 绑定类型（白底列表单选）
          _card(
              padding: EdgeInsets.zero,
              child: Column(children: [
                _typeRow(1, Icons.chat_rounded, t('wdMethodWechat')),
                Divider(height: 1, indent: 14, color: scheme.outlineVariant),
                _typeRow(2, Icons.payment_outlined, t('wdMethodAlipay')),
                Divider(height: 1, indent: 14, color: scheme.outlineVariant),
                _typeRow(3, Icons.account_balance_outlined, t('wdMethodBank')),
              ])),
          const SizedBox(height: 12),
          // 按类型渲染表单
          if (_type == 1) ...[
            _qrCard(title: t('wdWechatQrcode')),
            const SizedBox(height: 12),
            _card(
                padding: EdgeInsets.zero,
                child: _rowInput(t('wdWechatName'), _wechatNameCtrl)),
          ],
          if (_type == 2) ...[
            _qrCard(title: t('wdAlipayQrcode')),
            const SizedBox(height: 12),
            _card(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  _rowInput(t('wdAlipayAccount'), _alipayAccountCtrl,
                      keyboard: TextInputType.emailAddress),
                  Divider(height: 1, indent: 14, color: scheme.outlineVariant),
                  _rowInput(t('wdAlipayName'), _alipayNameCtrl),
                ])),
          ],
          if (_type == 3)
            _card(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  _rowInput(t('wdBankCardNo'), _bankCardCtrl,
                      keyboard: TextInputType.number),
                  Divider(height: 1, indent: 14, color: scheme.outlineVariant),
                  _rowInput(t('wdBankName'), _bankNameCtrl),
                  Divider(height: 1, indent: 14, color: scheme.outlineVariant),
                  _rowInput(t('wdBankAccountName'), _bankAccNameCtrl),
                ])),
          const SizedBox(height: 24),
          // 保存按钮（微信橙）
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFA9D3B),
                disabledBackgroundColor: const Color(0xFFF7C9A0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(t('wdSave'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  /// 收款码上传卡：标题 + 居中方框（预览已绑图/新选图，点击选图）
  Widget _qrCard({required String title}) {
    final t = AppLocalizations.of(context).t;
    final scheme = Theme.of(context).colorScheme;
    final isWechat = _type == 1;
    final localPath = isWechat ? _wechatQrPath : _alipayQrPath;
    final serverUrl = isWechat ? _wechatQrUrl : _alipayQrUrl;
    Widget? preview;
    if (localPath != null) {
      preview = Image.file(File(localPath), fit: BoxFit.cover);
    } else if (serverUrl.isNotEmpty) {
      preview = Image.network(_absUrl(serverUrl), fit: BoxFit.cover);
    }
    return _card(
        child: Column(children: [
      Text(title, style: TextStyle(fontSize: 15, color: scheme.onSurface)),
      const SizedBox(height: 10),
      GestureDetector(
        onTap: () => _pickQr(isWechat),
        child: Container(
          width: 130,
          height: 130,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: scheme.outlineVariant,
                width: 1,
                strokeAlign: BorderSide.strokeAlignInside),
          ),
          child: preview != null
              ? preview
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined,
                        size: 32, color: scheme.onSurfaceVariant),
                    const SizedBox(height: 6),
                    Text(t('wdPickQrcode'),
                        style: TextStyle(
                            fontSize: 11, color: scheme.onSurfaceVariant)),
                  ],
                ),
        ),
      ),
    ]));
  }

  /// 绑定类型单选行（微信风格：左图标 + 名称 + 右圆形单选）
  Widget _typeRow(int type, IconData icon, String label) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _type == type;
    return InkWell(
      onTap: () => setState(() => _type = type),
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

  /// 白底行式输入（无描边、无灰底填充、isCollapsed 防裁剪，左标签右输入）
  Widget _rowInput(String label, TextEditingController ctrl,
      {TextInputType? keyboard}) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          SizedBox(
              width: 100,
              child: Text(label,
                  style: TextStyle(fontSize: 14, color: scheme.onSurface))),
          Expanded(
            child: TextField(
              controller: ctrl,
              keyboardType: keyboard,
              style: TextStyle(fontSize: 15, color: scheme.onSurface),
              decoration: const InputDecoration(
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
