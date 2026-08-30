import 'package:flutter/material.dart';

import '../services/conversation_service.dart';
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
          _results = (data['list'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          _total = (data['total'] as num?)?.toInt() ?? 0;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _preview(Map<String, dynamic> m) {
    final typeMap = {2: '[图片]', 3: '[文件]', 4: '[语音]', 5: '[视频]'};
    return (typeMap[(m['type'] as num?)?.toInt()] ?? '') + (m['content']?.toString() ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '搜索聊天记录',
            border: InputBorder.none,
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
        ),
        actions: [
          TextButton(onPressed: _search, child: const Text('搜索', style: TextStyle(color: AppTheme.primary))),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_searched
              ? const Center(child: Text('输入关键词搜索聊天记录', style: TextStyle(color: AppTheme.textTertiary)))
              : _results.isEmpty
                  ? const Center(child: Text('未找到相关消息', style: TextStyle(color: AppTheme.textTertiary)))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                          child: Text('共 $_total 条相关消息', style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary)),
                        ),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _results.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final m = _results[i];
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.divider),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('会话 #${m['conversationId']}', style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary)),
                                    const SizedBox(height: 4),
                                    Text(_preview(m),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
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
