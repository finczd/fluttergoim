import 'package:flutter/material.dart';
import '../l10n/app_locale.dart';
import '../theme/app_theme.dart';

/// ChatPulse 风格统一弹窗与提示
class AppDialogs {
  AppDialogs._();

  /// 圆角 AlertDialog（确认/警告）
  static Future<bool?> confirm(
    BuildContext context, {
    required String title,
    String? message,
    String? cancelText,
    String? confirmText,
    bool danger = false,
  }) {
    final cancel = cancelText ?? AppLocalizations.instance.t('dialogsCancel');
    final ok = confirmText ?? AppLocalizations.instance.t('dialogsConfirm');
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: context.cs.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: context.cs.onSurface)),
              if (message != null && message.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: context.cs.onSurfaceVariant)),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _TextBtn(
                      label: cancel,
                      onTap: () => Navigator.of(ctx).pop(false),
                      filled: false,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TextBtn(
                      label: ok,
                      onTap: () => Navigator.of(ctx).pop(true),
                      filled: true,
                      danger: danger,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 带多行输入的圆角弹窗（如编辑群公告）
  static Future<String?> input(
    BuildContext context, {
    required String title,
    String? hint,
    String? initialValue,
    int maxLines = 4,
    int? maxLength,
    String? cancelText,
    String? confirmText,
  }) async {
    final cancel = cancelText ?? AppLocalizations.instance.t('dialogsCancel');
    final ok = confirmText ?? AppLocalizations.instance.t('dialogsSave');
    final controller = TextEditingController(text: initialValue ?? '');
    return showDialog<String?>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: context.cs.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: context.cs.onSurface)),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: TextField(
                  controller: controller,
                  maxLines: maxLines,
                  maxLength: maxLength,
                  style: TextStyle(fontSize: 14, color: context.cs.onSurface),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(
                        fontSize: 14, color: context.cs.onSurfaceVariant),
                    border: InputBorder.none,
                    counterStyle: TextStyle(
                        fontSize: 12, color: context.cs.onSurfaceVariant),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _TextBtn(
                      label: cancel,
                      onTap: () => Navigator.of(ctx).pop(null),
                      filled: false,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TextBtn(
                      label: ok,
                      onTap: () {
                        Navigator.of(ctx).pop(controller.text.trim());
                      },
                      filled: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 底部圆角菜单（列表项）
  static Future<void> actionSheet(
    BuildContext context, {
    String? title,
    required List<DialogAction> actions,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x80000000),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: context.cs.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (title != null && title.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Text(title,
                            style: TextStyle(
                                fontSize: 13,
                                color: context.cs.onSurfaceVariant)),
                      ),
                    ..._separated(
                      actions.map<Widget>((a) => InkWell(
                            onTap: () {
                              Navigator.of(ctx).pop();
                              a.onTap();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  if (a.icon != null) ...[
                                    Icon(a.icon,
                                        size: 22,
                                        color: a.danger
                                            ? AppTheme.danger
                                            : AppTheme.primary),
                                    const SizedBox(width: 14),
                                  ],
                                  Expanded(
                                    child: Text(a.label,
                                        style: TextStyle(
                                            fontSize: 16,
                                            color: a.danger
                                                ? AppTheme.danger
                                                : context.cs.onSurface)),
                                  ),
                                ],
                              ),
                            ),
                          )),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: context.cs.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                width: double.infinity,
                child: InkWell(
                  onTap: () => Navigator.of(ctx).pop(),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(AppLocalizations.of(ctx).t('dialogsCancel'),
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: context.cs.onSurface)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 统一 SnackBar
  static void toast(BuildContext context, String text) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content:
          Text(text, style: const TextStyle(fontSize: 14, color: Colors.white)),
      backgroundColor: const Color(0xFF333333),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      duration: const Duration(seconds: 2),
      elevation: 0,
    ));
  }

  static List<Widget> _separated(Iterable<Widget> children) {
    final list = children.toList();
    if (list.length < 2) return list;
    final out = <Widget>[list.first];
    for (var i = 1; i < list.length; i++) {
      out.add(Divider(height: 1, color: AppTheme.divider));
      out.add(list[i]);
    }
    return out;
  }
}

class _TextBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool filled;
  final bool danger;
  const _TextBtn({
    required this.label,
    required this.onTap,
    this.filled = true,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: filled
              ? (danger ? AppTheme.danger : AppTheme.primary)
              : Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: filled ? Colors.white : context.cs.onSurface)),
      ),
    );
  }
}

/// 底部菜单项
class DialogAction {
  final String label;
  final IconData? icon;
  final bool danger;
  final VoidCallback onTap;
  const DialogAction({
    required this.label,
    this.icon,
    this.danger = false,
    required this.onTap,
  });
}
