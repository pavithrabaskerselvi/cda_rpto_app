import 'package:flutter/material.dart';
import '../../models/analytics_summary_model.dart';
import '../../services/analytics_service.dart';
import '../../widgets/kpi_card.dart';

/// Students-per-batch + batch status breakdown.
class BatchAnalyticsScreen extends StatefulWidget {
  const BatchAnalyticsScreen({super.key});

  @override
  State<BatchAnalyticsScreen> createState() => _BatchAnalyticsScreenState();
}

class _BatchAnalyticsScreenState extends State<BatchAnalyticsScreen> {
  List<BatchStudentCount> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await AnalyticsService.fetchStudentsPerBatch();
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
  Color _bg(BuildContext c) =>
      _isDark(c) ? const Color(0xFF050A14) : const Color(0xFFF5F7FA);
  Color _surface(BuildContext c) =>
      _isDark(c) ? const Color(0xFF0F1B2E) : const Color(0xFFFFFFFF);
  Color _textPrimary(BuildContext c) =>
      _isDark(c) ? Colors.white : const Color(0xFF0B1220);
  Color _textSecondary(BuildContext c) =>
      _isDark(c) ? Colors.white70 : const Color(0xFF5B6472);
  static const Color teal = Color(0xFF14B8A6);

  @override
  Widget build(BuildContext context) {
    final maxCount = _rows.isEmpty
        ? 1
        : _rows.map((r) => r.studentCount).reduce((a, b) => a > b ? a : b).clamp(1, 999999);
    final totalStudentsInBatches = _rows.fold<int>(0, (sum, r) => sum + r.studentCount);

    return Scaffold(
      backgroundColor: _bg(context),
      appBar: AppBar(
        backgroundColor: _bg(context),
        title: Text('Batch Analytics',
            style: TextStyle(color: _textPrimary(context), fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: teal))
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: KpiCard(
                  label: 'Total Batches',
                  value: '${_rows.length}',
                  icon: Icons.groups_rounded,
                  accentColor: const Color(0xFF1E5FC8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: KpiCard(
                  label: 'Students in Batches',
                  value: '$totalStudentsInBatches',
                  icon: Icons.school_rounded,
                  accentColor: const Color(0xFF2ECC71),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Students per Batch (ranked)',
              style: TextStyle(
                  color: _textPrimary(context), fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (_rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                  child: Text('No batches yet', style: TextStyle(color: _textSecondary(context)))),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: _surface(context),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: List.generate(_rows.length, (i) {
                  final row = _rows[i];
                  final pct = row.studentCount / maxCount;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${i + 1}. ${row.batchName}',
                                style: TextStyle(color: _textPrimary(context))),
                            Text('${row.studentCount}',
                                style: TextStyle(
                                    color: _textSecondary(context), fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct.toDouble(),
                            minHeight: 6,
                            backgroundColor: teal.withValues(alpha: 0.12),
                            color: teal,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}
