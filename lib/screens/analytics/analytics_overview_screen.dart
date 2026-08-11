import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/analytics_summary_model.dart';
import '../../services/analytics_service.dart';
import '../../widgets/circle_kpi_card.dart';
import '../../widgets/line_chart_card.dart';
import '../../widgets/pie_chart_card.dart';
import '../../widgets/insight_alert_tile.dart';
import 'student_analytics_screen.dart';
import 'batch_analytics_screen.dart';
import 'instructor_analytics_screen.dart';
import 'financial_analytics_screen.dart';

/// Main Analytics entry screen — premium gradient header (with the
/// signature flying X-drone animation), KPI row, a student-status donut
/// chart, enrollment/revenue line charts, insights, and drill-down links.
/// Reads live from AnalyticsService.
class AnalyticsOverviewScreen extends StatefulWidget {
  const AnalyticsOverviewScreen({super.key});

  @override
  State<AnalyticsOverviewScreen> createState() => _AnalyticsOverviewScreenState();
}

class _AnalyticsOverviewScreenState extends State<AnalyticsOverviewScreen>
    with SingleTickerProviderStateMixin {
  List<TrendPoint> _enrollmentTrend = [];
  List<TrendPoint> _revenueTrend = [];
  bool _loadingTrends = true;

  // Drives the drone that periodically flies across the header.
  late AnimationController _droneController;

  @override
  void initState() {
    super.initState();
    _loadTrends();

    // One flight every 7s, matching the dashboard's pacing so it reads as
    // the same signature motif across the app.
    _droneController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
  }

  Future<void> _loadTrends() async {
    final enrollment = await AnalyticsService.fetchEnrollmentTrend();
    final revenue = await AnalyticsService.fetchRevenueTrend();
    if (!mounted) return;
    setState(() {
      _enrollmentTrend = enrollment;
      _revenueTrend = revenue;
      _loadingTrends = false;
    });
  }

  @override
  void dispose() {
    _droneController.dispose();
    super.dispose();
  }

  bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
  Color _bg(BuildContext c) =>
      _isDark(c) ? const Color(0xFF050A14) : const Color(0xFFF5F7FA);
  Color _textPrimary(BuildContext c) =>
      _isDark(c) ? Colors.white : const Color(0xFF0B1220);

  // Premium palette — deep navy-to-royal gradient header (matches the
  // dashboard's HUD styling) with teal/gold accents used throughout.
  static const Color teal = Color(0xFF14B8A6);
  static const Color gold = Color(0xFFFFB020);
  static const Color droneColor = Color(0xFF4FC3F7);
  static const List<Color> _headerGradient = [Color(0xFF0A1628), Color(0xFF1B3B7A)];

  List<InsightAlertTile> _buildInsights(AnalyticsSummaryModel s) {
    final insights = <InsightAlertTile>[];

    if (s.droppedStudents > 0) {
      insights.add(InsightAlertTile(
        message: '${s.droppedStudents} student${s.droppedStudents == 1 ? '' : 's'} marked as dropped',
        severity: InsightSeverity.warning,
      ));
    }
    if (s.totalDue > 0) {
      insights.add(InsightAlertTile(
        message: '₹${s.totalDue.toStringAsFixed(0)} in fees still pending across all students',
        severity: InsightSeverity.warning,
      ));
    }
    if (s.upcomingBatches > 0) {
      insights.add(InsightAlertTile(
        message: '${s.upcomingBatches} batch${s.upcomingBatches == 1 ? '' : 'es'} upcoming, not yet started',
        severity: InsightSeverity.info,
      ));
    }
    if (s.completionRate >= 80) {
      insights.add(InsightAlertTile(
        message: 'Completion rate is strong at ${s.completionRate.toStringAsFixed(1)}%',
        severity: InsightSeverity.info,
      ));
    }
    if (insights.isEmpty) {
      insights.add(const InsightAlertTile(
        message: 'No alerts right now — everything looks steady.',
        severity: InsightSeverity.info,
      ));
    }
    return insights;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg(context),
      body: StreamBuilder<AnalyticsSummaryModel>(
        stream: AnalyticsService.streamOverviewSummary(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: _headerGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Center(child: CircularProgressIndicator(color: teal)),
            );
          }
          final s = snapshot.data!;

          return RefreshIndicator(
            color: teal,
            onRefresh: _loadTrends,
            child: CustomScrollView(
              slivers: [
                // ---- Premium gradient header with flying X-drone ----
                SliverToBoxAdapter(
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 14, 20, 26),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: _headerGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Flying drone: sweeps left-to-right across the header,
                        // banking slightly, fading in/out at the edges. Clipped
                        // so it always stays fully inside this header band, even
                        // while the page scrolls.
                        Positioned.fill(
                          child: ClipRect(
                            child: AnimatedBuilder(
                              animation: _droneController,
                              builder: (context, child) {
                                return CustomPaint(
                                  painter: _FlyingDronePainter(
                                    progress: _droneController.value,
                                    color: droneColor,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => Navigator.of(context).maybePop(),
                                  child: const Padding(
                                    padding: EdgeInsets.only(right: 10),
                                    child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                                  ),
                                ),
                                const Expanded(
                                  child: Text(
                                    'Analytics',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF2ECC71)),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'LIVE',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Padding(
                              padding: EdgeInsets.only(left: 32),
                              child: Text(
                                'Academy performance overview',
                                style: TextStyle(color: Color(0xFFC7D2E8), fontSize: 12.5),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ---- Body content, overlapping the header slightly for a layered feel ----
                SliverToBoxAdapter(
                  child: Transform.translate(
                    offset: const Offset(0, -14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                      decoration: BoxDecoration(
                        color: _bg(context),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                      ),
                      // Full width now — no more ConstrainedBox/Center capping
                      // the content to 640px, so the layout stretches to
                      // fill the whole screen on every viewport size.
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ---- KPI row — 4 premium circle stats, one line ----
                          CircleKpiRow(
                            cards: [
                              CircleKpiCard(
                                label: 'Students',
                                value: '${s.totalStudents}',
                                icon: Icons.school_rounded,
                                accentColor: const Color(0xFF2ECC71),
                              ),
                              CircleKpiCard(
                                label: 'Active',
                                value: '${s.ongoingBatches}',
                                icon: Icons.groups_rounded,
                                accentColor: const Color(0xFFFF6B6B),
                              ),
                              CircleKpiCard(
                                label: 'Complete',
                                value: '${s.completionRate.toStringAsFixed(0)}%',
                                icon: Icons.verified_rounded,
                                accentColor: const Color(0xFF1E5FC8),
                              ),
                              CircleKpiCard(
                                label: 'Revenue',
                                value: '₹${s.totalRevenue.toStringAsFixed(0)}',
                                icon: Icons.currency_rupee_rounded,
                                accentColor: gold,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // ---- Student status donut chart ----
                          PieChartCard(
                            title: 'Student Status Breakdown',
                            centerLabel: '${s.totalStudents}',
                            slices: [
                              PieSlice(label: 'Active', value: s.activeStudents.toDouble(), color: const Color(0xFF2ECC71)),
                              PieSlice(label: 'Completed', value: s.completedStudents.toDouble(), color: const Color(0xFF1E5FC8)),
                              PieSlice(label: 'Dropped', value: s.droppedStudents.toDouble(), color: const Color(0xFFE74C3C)),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // ---- Batch status donut chart ----
                          PieChartCard(
                            title: 'Batch Status Breakdown',
                            centerLabel: '${s.totalBatches}',
                            slices: [
                              PieSlice(label: 'Ongoing', value: s.ongoingBatches.toDouble(), color: teal),
                              PieSlice(label: 'Upcoming', value: s.upcomingBatches.toDouble(), color: gold),
                              PieSlice(label: 'Completed', value: s.completedBatches.toDouble(), color: const Color(0xFF1E5FC8)),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // ---- Trend line charts ----
                          _loadingTrends
                              ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(child: CircularProgressIndicator(color: teal)),
                          )
                              : Column(
                            children: [
                              LineChartCard(
                                title: 'Enrollment Trend (last 6 months)',
                                points: _enrollmentTrend,
                                lineColor: const Color(0xFF2ECC71),
                              ),
                              const SizedBox(height: 16),
                              LineChartCard(
                                title: 'Revenue Trend (last 6 months)',
                                points: _revenueTrend,
                                lineColor: gold,
                                valueFormatter: (v) => '₹${v.toStringAsFixed(0)}',
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // ---- Insights ----
                          Text(
                            'Insights',
                            style: TextStyle(
                              color: _textPrimary(context),
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ..._buildInsights(s),
                          const SizedBox(height: 20),

                          // ---- Drill-down links ----
                          Text(
                            'Detailed Analytics',
                            style: TextStyle(
                              color: _textPrimary(context),
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _AnalyticsLinkTile(
                            icon: Icons.school_rounded,
                            label: 'Student Analytics',
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const StudentAnalyticsScreen())),
                          ),
                          _AnalyticsLinkTile(
                            icon: Icons.groups_rounded,
                            label: 'Batch Analytics',
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const BatchAnalyticsScreen())),
                          ),
                          _AnalyticsLinkTile(
                            icon: Icons.badge_rounded,
                            label: 'Instructor Analytics',
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const InstructorAnalyticsScreen())),
                          ),
                          _AnalyticsLinkTile(
                            icon: Icons.currency_rupee_rounded,
                            label: 'Financial Analytics',
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const FinancialAnalyticsScreen())),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AnalyticsLinkTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AnalyticsLinkTile({required this.icon, required this.label, required this.onTap});

  bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
  Color _surface(BuildContext c) =>
      _isDark(c) ? const Color(0xFF0F1B2E) : const Color(0xFFFFFFFF);
  Color _textPrimary(BuildContext c) =>
      _isDark(c) ? Colors.white : const Color(0xFF0B1220);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _surface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isDark(context) ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFEDF1F7),
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF14B8A6)),
        title: Text(label, style: TextStyle(color: _textPrimary(context))),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

// ---------------- Flying drone painter (header signature animation) ----------------

/// Draws a single glowing blue quadcopter drone — X-arm frame with circular
/// "targeting" rotor rings and a lit-up center body — sweeping left-to-right
/// across the header. Kept confined to the header's own bounds (the caller
/// wraps this in a ClipRect) so it never draws outside the band or looks
/// like it's floating loose over the page while scrolling.
class _FlyingDronePainter extends CustomPainter {
  final double progress;
  final Color color;

  _FlyingDronePainter({required this.progress, required this.color});

  static const double _laneY = 0.24;
  static const double _scale = 1.7;
  static const double _flightSpan = 0.55;

  @override
  void paint(Canvas canvas, Size size) {
    final localProgress = progress % 1.0;
    if (localProgress > _flightSpan) return;

    final t = localProgress / _flightSpan; // 0..1 across this flight

    // Fade in over the first 12%, hold, fade out over the last 15%.
    double opacity = 1.0;
    if (t < 0.12) {
      opacity = t / 0.12;
    } else if (t > 0.85) {
      opacity = (1.0 - t) / 0.15;
    }
    opacity = opacity.clamp(0.0, 1.0);
    if (opacity <= 0) return;

    // Flight path kept within the header's own width (with a small margin)
    // — combined with the caller's ClipRect this keeps the drone fully
    // on-screen at all times.
    final dx = 0.04 + t * 0.92;
    final dy = _laneY + 0.05 * math.sin(t * math.pi);
    final center = Offset(size.width * dx, size.height * dy);

    // Slight banking tilt as it "flies".
    final tilt = math.sin(t * math.pi) * 0.12;

    final armPaint = Paint()
      ..color = color.withValues(alpha: 0.9 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * _scale
      ..strokeCap = StrokeCap.round;
    final rotorGlowPaint = Paint()
      ..color = color.withValues(alpha: 0.25 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * _scale
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final rotorRingPaint = Paint()
      ..color = color.withValues(alpha: 0.85 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3 * _scale;
    final crosshairPaint = Paint()
      ..color = color.withValues(alpha: 0.6 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9 * _scale;
    final bodyGlowPaint = Paint()
      ..color = color.withValues(alpha: 0.5 * opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final bodyPaint = Paint()..color = Colors.white.withValues(alpha: 0.95 * opacity);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(tilt);
    canvas.scale(_scale);

    const armLen = 9.0;
    final armOffsets = [
      const Offset(-armLen, -armLen * 0.75),
      const Offset(armLen, -armLen * 0.75),
      const Offset(-armLen, armLen * 0.75),
      const Offset(armLen, armLen * 0.75),
    ];

    // Arms from center to each rotor — this draws the X shape.
    for (final o in armOffsets) {
      canvas.drawLine(Offset.zero, o, armPaint);
    }

    // Rotor rings: outer glow + crisp ring + crosshair.
    const rotorRadius = 5.0;
    for (final o in armOffsets) {
      canvas.drawCircle(o, rotorRadius, rotorGlowPaint);
      canvas.drawCircle(o, rotorRadius, rotorRingPaint);
      canvas.drawLine(o + const Offset(-rotorRadius, 0), o + const Offset(rotorRadius, 0), crosshairPaint);
      canvas.drawLine(o + const Offset(0, -rotorRadius), o + const Offset(0, rotorRadius), crosshairPaint);
    }

    // Glowing center body.
    canvas.drawCircle(Offset.zero, 4.5, bodyGlowPaint);
    canvas.drawCircle(Offset.zero, 2.2, bodyPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FlyingDronePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}