import 'package:flutter/material.dart';

import '../l10n/app_locale.dart';
import '../services/moment_service.dart';
import '../theme/app_theme.dart';
import 'pay_ui.dart';

/// 我的账单（交易记录独立页：时间筛选 + 分页加载）
class BillPage extends StatefulWidget {
  const BillPage({super.key});

  @override
  State<BillPage> createState() => _BillPageState();
}

class _BillPageState extends State<BillPage> {
  final _svc = MomentService.instance;
  final _scroll = ScrollController();

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  int _total = 0;
  List<Map<String, dynamic>> _records = [];

  DateTime? _start;
  DateTime? _end;

  @override
  void initState() {
    super.initState();
    _load();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200 &&
          !_loadingMore &&
          _hasMore) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _svc.records(
          start: _start != null ? _fmtDate(_start!) : null,
          end: _end != null ? _fmtDate(_end!) : null);
      if (mounted) {
        setState(() {
          _total = (data['total'] as num?)?.toInt() ?? 0;
          _records = ((data['list'] as List<dynamic>?) ?? [])
              .map((e) => (e as Map).cast<String, dynamic>())
              .toList();
          _page = 1;
          _hasMore = _records.length < _total;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final data = await _svc.records(
          start: _start != null ? _fmtDate(_start!) : null,
          end: _end != null ? _fmtDate(_end!) : null,
          page: _page + 1);
      if (mounted) {
        final more = ((data['list'] as List<dynamic>?) ?? [])
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();
        setState(() {
          _records.addAll(more);
          _page++;
          _hasMore = _records.length < _total;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _pickRange() async {
    final t = AppLocalizations.of(context).t;
    final now = DateTime.now();
    final initial = _start ?? now.subtract(const Duration(days: 30));
    final s = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: now,
      helpText: t('billSelectStartDate'),
    );
    if (s == null || !mounted) return;
    final e = await showDatePicker(
      context: context,
      initialDate: _end ?? now,
      firstDate: s,
      lastDate: now,
      helpText: t('billSelectEndDate'),
    );
    if (!mounted) return;
    setState(() {
      _start = s;
      _end = e; // 可只选开始日期
    });
    _load();
  }

  void _clearRange() {
    setState(() {
      _start = null;
      _end = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context).t;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(t('billTitle'),
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: context.cs.onSurface)),
      ),
      body: Column(
        children: [
          // 时间筛选条
          Container(
            color: context.cs.surface,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                Icon(Icons.filter_alt_outlined,
                    size: 16, color: context.cs.onSurfaceVariant),
                const SizedBox(width: 6),
                InkWell(
                  onTap: _pickRange,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: context.cs.surfaceContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _start == null
                          ? t('billAllTime')
                          : '${_fmtDate(_start!)}${_end != null ? ' ~ ${_fmtDate(_end!)}' : ' ${t('billToNow')}'}',
                      style:
                          TextStyle(fontSize: 13, color: context.cs.onSurface),
                    ),
                  ),
                ),
                if (_start != null) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _clearRange,
                    child: Icon(Icons.close,
                        size: 16, color: context.cs.onSurfaceVariant),
                  ),
                ],
                const Spacer(),
                Text(t('billTotalCount', {'count': '$_total'}),
                    style: TextStyle(
                        fontSize: 12, color: context.cs.onSurfaceVariant)),
              ],
            ),
          ),
          Divider(height: 1, color: context.cs.outlineVariant),
          // 流水列表
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary))
                : _records.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined,
                                size: 48,
                                color: context.cs.onSurfaceVariant
                                    .withValues(alpha: 0.5)),
                            const SizedBox(height: 10),
                            Text(t('billEmpty'),
                                style: TextStyle(
                                    fontSize: 13,
                                    color: context.cs.onSurfaceVariant)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(12),
                        itemCount: _records.length + (_hasMore ? 1 : 0),
                        itemBuilder: (ctx, i) {
                          if (i >= _records.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                  child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppTheme.primary))),
                            );
                          }
                          return _billRow(_records[i]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _billRow(Map<String, dynamic> r) {
    final amount = (r['amount'] as num?)?.toDouble() ?? 0;
    final income = amount >= 0;
    final title = (r['title'] ?? r['typeName'] ?? '').toString();
    final createdAt = (r['createdAt'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.cs.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (income ? const Color(0xFFE9564E) : PayUI.primary)
                  .withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              income ? Icons.south_west : Icons.north_east,
              size: 18,
              color: income ? const Color(0xFFE9564E) : PayUI.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        TextStyle(fontSize: 15, color: context.cs.onSurface)),
                Text(createdAt,
                    style: TextStyle(
                        fontSize: 12, color: context.cs.onSurfaceVariant)),
              ],
            ),
          ),
          Text(
            '${income ? '+' : '-'}¥${_fmtNum(amount.abs())}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: income ? const Color(0xFF34A853) : context.cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  String _fmtNum(double v) {
    final s = v.toStringAsFixed(2);
    return s.endsWith('.00') ? v.toStringAsFixed(0) : s;
  }
}
