import 'package:flutter/material.dart';

import '../l10n/app_locale.dart';
import '../theme/app_theme.dart';
import 'chat_list_page.dart';
import 'contacts_page.dart';
import 'discover_page.dart';
import 'me_page.dart';

/// 底部 4 Tab（消息/通讯录/发现/我的）—— 对齐设计稿：
/// 顶部细线分隔，active=#0088CC 蓝（图标+文字），inactive=#8E9096 灰
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _pages = [
    ChatListPage(),
    ContactsPage(),
    DiscoverPage(),
    MePage(),
  ];

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.background,
          border: Border(top: BorderSide(color: AppTheme.divider, width: 0.5)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                _tab(0, Icons.chat_bubble_outline, Icons.chat_bubble, t('home')),
                _tab(1, Icons.contacts_outlined, Icons.contacts, t('contacts')),
                _tab(2, Icons.explore_outlined, Icons.explore, t('discover')),
                _tab(3, Icons.person_outline, Icons.person, t('me')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(int i, IconData iconOff, IconData iconOn, String label) {
    final active = i == _index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _index = i),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(active ? iconOn : iconOff,
                size: 24,
                color: active ? AppTheme.primary : AppTheme.textTertiary),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: active ? AppTheme.primary : AppTheme.textTertiary)),
          ],
        ),
      ),
    );
  }
}
