import 'package:flutter/material.dart';

import '../services/conversation_service.dart';
import '../l10n/app_locale.dart';
import '../theme/app_theme.dart';

/// 消息搜索（全局，仅自己参与的会话）
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _svc = ConversationService();
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  int _total = 0;
  bool _searched = false;
  bool _loading = false;

  Future<void> _search() async {
    final kw = _ctrl.text.trim();
    if (kw.isEmpty) return;
    setState(() {
      _loading = true;
      _searched = true;
    });
    try {
      final data = await _svc.searchMessages(kw);
      if (mounted) {
        setState(() {
          _results = (data['list'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>();
          _total = (data['total'] as num?)?.toInt() ?? 0;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _preview(Map<String, dynamic> m) {
    final t = AppLocalizations.of(context).t;
    final typeMap = {
      2: t('searchImage'),
      3: t('searchFile'),
      4: t('searchVoice'),
      5: t('searchVideo')
    };
    return (typeMap[(m['type'] as num?)?.toInt()] ?? '') +
        (m['content']?.toString() ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        titleSpacing: 12,
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          style: TextStyle(fontSize: 15, color: context.cs.onSurface),
          decoration: InputDecoration(
            hintText: t('searchHint'),
            hintStyle:
                TextStyle(fontSize: 15, color: context.cs.onSurfaceVariant),
            isDense: true,
            filled: true,
            fillColor: context.cs.surfaceContainer,
            prefixIcon: Icon(Icons.search,
                size: 20, color: context.cs.onSurfaceVariant),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: BorderSide.none,
            ),
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
        ),
        actions: [
          TextButton(
              onPressed: _search,
              child: Text(t('searchAction'),
                  style: const TextStyle(color: AppTheme.primary))),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_searched
              ? Center(
                  child: Text(t('searchEmptyTip'),
                      style: TextStyle(color: context.cs.onSurfaceVariant)))
              : _results.isEmpty
                  ? Center(
                      child: Text(t('searchNoResults'),
                          style: TextStyle(color: context.cs.onSurfaceVariant)))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                          child: Text(
                              t('searchResultCount', {'count': '$_total'}),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: context.cs.onSurfaceVariant)),
                        ),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _results.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final m = _results[i];
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: context.cs.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: context.cs.outlineVariant),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        t('searchConvLabel',
                                            {'id': '${m['conversationId']}'}),
                                        style: TextStyle(
                                            fontSize: 12,
                                            color:
                                                context.cs.onSurfaceVariant)),
                                    const SizedBox(height: 4),
                                    Text(_preview(m),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: context.cs.onSurface)),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
    );
  }
}
