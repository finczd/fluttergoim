import 'package:flutter/material.dart';

import '../l10n/app_locale.dart';
import '../services/settings_service.dart';

/// 系统设置：开启通知 / 深色模式·浅色模式
class SystemSettingsPage extends StatefulWidget {
  const SystemSettingsPage({super.key});

  @override
  State<SystemSettingsPage> createState() => _SystemSettingsPageState();
}

class _SystemSettingsPageState extends State<SystemSettingsPage> {
  final _settings = AppSettings.instance;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(t('settingsTitle'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  secondary:
                      Icon(Icons.notifications_outlined, color: scheme.primary),
                  title: Text(t('settingsEnableNotifications'),
                      style: TextStyle(fontSize: 15, color: scheme.onSurface)),
                  subtitle: Text(t('settingsNotificationsDesc'),
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant)),
                  value: _settings.notifications,
                  onChanged: (v) => _settings.setNotifications(v),
                ),
                Divider(height: 1, indent: 50, color: scheme.outlineVariant),
                SwitchListTile(
                  secondary: Icon(Icons.dark_mode_outlined,
                      color: scheme.onSurfaceVariant),
                  title: Text(t('settingsDarkMode'),
                      style: TextStyle(fontSize: 15, color: scheme.onSurface)),
                  subtitle: Text(t('settingsDarkModeDesc'),
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant)),
                  value: _settings.dark,
                  onChanged: (v) => _settings.setDark(v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
