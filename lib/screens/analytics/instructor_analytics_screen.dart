import 'package:flutter/material.dart';
import '../../models/analytics_summary_model.dart';
import '../../services/analytics_service.dart';
import '../../widgets/kpi_card.dart';

/// Batch count + student count per instructor — a simple leaderboard,
/// ranked by student count (heaviest workload first).
class InstructorAnalyticsScreen extends StatefulWidget {
  const InstructorAnalyticsScreen({super.key});

  @override
  State<InstructorAnalyticsScreen> createState() => _InstructorAnalyticsScreenState();
}

class _InstructorAnalyticsScreenState extends State<InstructorAnalyticsScreen> {
  List<InstructorWorkload> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await AnalyticsService.fetchInstructorWorkload();
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
    return Scaffold(
      backgroundColor: _bg(context),
      appBar: AppBar(
        backgroundColor: _bg(context),
        title: Text('Instructor Analytics',
            style: TextStyle(color: _textPrimary(context), fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: teal))
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          KpiCard(
            label: 'Total Instructors',
            value: '${_rows.length}',
            icon: Icons.badge_rounded,
            accentColor: const Color(0xFF9B59B6),
          ),
          const SizedBox(height: 20),
          Text('Workload Leaderboard',
              style: TextStyle(
                  color: _textPrimary(context), fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (_rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                  child:
                  Text('No instructors yet', style: TextStyle(color: _textSecondary(context)))),
            )
          else
            ...List.generate(_rows.length, (i) {
              final row = _rows[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _surface(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: teal.withValues(alpha: 0.14),
                      child: Text('${i + 1}',
                          style: const TextStyle(color: teal, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(row.instructorName,
                          style: TextStyle(
                              color: _textPrimary(context), fontWeight: FontWeight.w600)),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${row.batchCount} batches',
                            style: TextStyle(color: _textSecondary(context), fontSize: 12)),
                        Text('${row.studentCount} students',
                            style: TextStyle(color: teal, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
