import 'package:flutter/material.dart';
import '../../models/analytics_summary_model.dart';
import '../../services/analytics_service.dart';
import '../../widgets/kpi_card.dart';
import '../../widgets/trend_chart_card.dart';

/// Revenue trend + pending dues, reading via AnalyticsService which in
/// turn reads the "fees" collection (from FeeService's fee_model.dart).
/// Only meaningful once the Fee module is actually recording payments.
class FinancialAnalyticsScreen extends StatefulWidget {
  const FinancialAnalyticsScreen({super.key});

  @override
  State<FinancialAnalyticsScreen> createState() => _FinancialAnalyticsScreenState();
}

class _FinancialAnalyticsScreenState extends State<FinancialAnalyticsScreen> {
  List<TrendPoint> _revenueTrend = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final trend = await AnalyticsService.fetchRevenueTrend();
    if (!mounted) return;
    setState(() {
      _revenueTrend = trend;
      _loading = false;
    });
  }

  bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
  Color _bg(BuildContext c) =>
      _isDark(c) ? const Color(0xFF050A14) : const Color(0xFFF5F7FA);
  Color _textPrimary(BuildContext c) =>
      _isDark(c) ? Colors.white : const Color(0xFF0B1220);
  static const Color teal = Color(0xFF14B8A6);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg(context),
      appBar: AppBar(
        backgroundColor: _bg(context),
        title: Text('Financial Analytics',
            style: TextStyle(color: _textPrimary(context), fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<AnalyticsSummaryModel>(
        stream: AnalyticsService.streamOverviewSummary(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: teal));
          }
          final s = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: KpiCard(
                      label: 'Total Revenue',
                      value: '₹${s.totalRevenue.toStringAsFixed(0)}',
                      icon: Icons.currency_rupee_rounded,
                      accentColor: const Color(0xFF2ECC71),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: KpiCard(
                      label: 'Pending Dues',
                      value: '₹${s.totalDue.toStringAsFixed(0)}',
                      icon: Icons.pending_actions_rounded,
                      accentColor: const Color(0xFFE74C3C),
                    ),
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
                title: 'Revenue Trend (last 6 months)',
                points: _revenueTrend,
                barColor: const Color(0xFFFFB020),
              ),
            ],
          );
        },
      ),
    );
  }
}
