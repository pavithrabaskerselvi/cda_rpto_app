import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/analytics_summary_model.dart';
import '../../services/analytics_service.dart';
import '../../widgets/circle_kpi_card.dart';
import '../../widgets/trend_chart_card.dart';

/// Enrollment trend + Active/Completed/Dropped breakdown, using
/// StudentModel.status directly from the students collection.
class StudentAnalyticsScreen extends StatefulWidget {
  const StudentAnalyticsScreen({super.key});

  @override
  State<StudentAnalyticsScreen> createState() => _StudentAnalyticsScreenState();
}

class _StudentAnalyticsScreenState extends State<StudentAnalyticsScreen> {
  List<TrendPoint> _enrollmentTrend = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final trend = await AnalyticsService.fetchEnrollmentTrend();
    if (!mounted) return;
    setState(() {
      _enrollmentTrend = trend;
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
        title: Text('Student Analytics',
            style: TextStyle(color: _textPrimary(context), fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('students').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: teal));
          }
          final docs = snapshot.data!.docs;
          int active = 0, completed = 0, dropped = 0;
          final byBatch = <String, int>{};
          final byState = <String, int>{};

          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] ?? '';
            if (status == 'Active') active++;
            if (status == 'Completed') completed++;
            if (status == 'Dropped') dropped++;

            final batchName = (data['batchName'] ?? '') as String;
            if (batchName.isNotEmpty) {
              byBatch[batchName] = (byBatch[batchName] ?? 0) + 1;
            }
            final state = (data['state'] ?? '') as String;
            if (state.isNotEmpty) {
              byState[state] = (byState[state] ?? 0) + 1;
            }
          }

          final total = docs.length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ---- Active / Completed / Dropped — premium circle stats ----
              CircleKpiRow(
                cards: [
                  CircleKpiCard(
                    label: 'Active',
                    value: '$active',
                    icon: Icons.play_circle_fill_rounded,
                    accentColor: const Color(0xFF2ECC71),
                  ),
                  CircleKpiCard(
                    label: 'Completed',
                    value: '$completed',
                    icon: Icons.verified_rounded,
                    accentColor: const Color(0xFF1E5FC8),
                  ),
                  CircleKpiCard(
                    label: 'Dropped',
                    value: '$dropped',
                    icon: Icons.cancel_rounded,
                    accentColor: const Color(0xFFE74C3C),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _loading
                  ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(color: teal)),
              )
                  : TrendChartCard(
                title: 'Enrollment Trend (last 6 months)',
                points: _enrollmentTrend,
                barColor: const Color(0xFF2ECC71),
              ),
              const SizedBox(height: 20),
              Text('Students per Batch',
                  style: TextStyle(
                      color: _textPrimary(context), fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: _surface(context),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: byBatch.entries.map((e) {
                    final pct = total == 0 ? 0.0 : e.value / total;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(e.key, style: TextStyle(color: _textPrimary(context))),
                              Text('${e.value}',
                                  style: TextStyle(color: _textSecondary(context))),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 6,
                              backgroundColor: teal.withValues(alpha: 0.12),
                              color: teal,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              if (byState.isNotEmpty) ...[
                Text('Students by State',
                    style: TextStyle(
                        color: _textPrimary(context), fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: byState.entries
                      .map((e) => Chip(
                    backgroundColor: _surface(context),
                    label: Text('${e.key}: ${e.value}',
                        style: TextStyle(color: _textPrimary(context), fontSize: 12)),
                  ))
                      .toList(),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}