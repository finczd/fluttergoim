import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../l10n/app_locale.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/app_dialogs.dart';
import 'login_page.dart';

/// 账号安全：修改登录密码 / 注销账户
class AccountSecurityPage extends StatefulWidget {
  const AccountSecurityPage({super.key});

  @override
  State<AccountSecurityPage> createState() => _AccountSecurityPageState();
}

class _AccountSecurityPageState extends State<AccountSecurityPage> {
  final _api = ApiClient.instance;

  bool _validPwd(String p) =>
      p.length >= 8 &&
      p.length <= 20 &&
      p.contains(RegExp(r'[a-zA-Z]')) &&
      p.contains(RegExp(r'[0-9]'));

  Widget _field(TextEditingController c, String hint) => TextField(
        controller: c,
        obscureText: true,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: context.cs.onSurfaceVariant),
          filled: true,
          fillColor: Theme.of(context).scaffoldBackgroundColor,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none),
        ),
      );

  Future<void> _changePassword() async {
    final t = AppLocalizations.of(context).t;
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cs.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t('acctSecChangePassword'),
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: context.cs.onSurface)),
              const SizedBox(height: 16),
              _field(oldCtrl, t('acctSecOldPwdHint')),
              const SizedBox(height: 12),
              _field(newCtrl, t('acctSecNewPwdHint')),
              const SizedBox(height: 12),
              _field(confirmCtrl, t('acctSecConfirmPwdHint')),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style:
                      FilledButton.styleFrom(backgroundColor: AppTheme.primary),
                  child: Text(t('acctSecConfirmChange')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    final oldP = oldCtrl.text;
    final newP = newCtrl.text;
    final confirmP = confirmCtrl.text;
    if (newP != confirmP) {
      AppDialogs.toast(context, t('acctSecPwdMismatch'));
      return;
    }
    if (!_validPwd(newP)) {
      AppDialogs.toast(context, t('acctSecPwdInvalid'));
      return;
    }
    try {
      final token = await _api.readToken();
      final r = await _api.dio.put('/api/v1/user/password',
          data: {'oldPassword': oldP, 'newPassword': newP},
          options: Options(headers: {'Authorization': 'Bearer $token'}));
      final code = (r.data as Map)['code'];
      if (code == 0) {
        AppDialogs.toast(context, t('acctSecPwdChanged'));
        if (mounted) Navigator.pop(context);
      } else {
        AppDialogs.toast(
            context,
            ((r.data as Map)['message'] ??
                    AppLocalizations.of(context).t('acctSecChangeFailed'))
                .toString());
      }
    } catch (_) {
      AppDialogs.toast(context, t('acctSecChangeFailedRetry'));
    }
  }

  Future<void> _deleteAccount() async {
    final t = AppLocalizations.of(context).t;
    final yes = await AppDialogs.confirm(
      context,
      title: t('acctSecDeleteAccount'),
      message: t('acctSecDeleteAccountMsg'),
      confirmText: t('acctSecDeleteConfirm'),
      danger: true,
    );
    if (yes != true) return;
    try {
      final token = await _api.readToken();
      final r = await _api.dio.delete('/api/v1/user',
          options: Options(headers: {'Authorization': 'Bearer $token'}));
      final code = (r.data as Map)['code'];
      if (code == 0) {
        await _api.logout();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
          );
        }
        return;
      }
      AppDialogs.toast(
          context,
          ((r.data as Map)['message'] ??
                  AppLocalizations.of(context).t('acctSecDeleteFailed'))
              .toString());
    } catch (_) {
      AppDialogs.toast(context, t('acctSecDeleteFailedRetry'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(t('acctSecTitle'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: context.cs.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                ListTile(
                  leading:
                      const Icon(Icons.lock_outline, color: AppTheme.purple),
                  title: Text(t('acctSecChangePassword'),
                      style: const TextStyle(fontSize: 15)),
                  trailing: Icon(Icons.chevron_right,
                      size: 18, color: context.cs.onSurfaceVariant),
                  onTap: _changePassword,
                ),
                const Divider(height: 1, indent: 50),
                ListTile(
                  leading: const Icon(Icons.delete_forever_outlined,
                      color: AppTheme.danger),
                  title: Text(t('acctSecDeleteAccount'),
                      style: const TextStyle(fontSize: 15, color: AppTheme.danger)),
                  trailing: Icon(Icons.chevron_right,
                      size: 18, color: context.cs.onSurfaceVariant),
                  onTap: _deleteAccount,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
