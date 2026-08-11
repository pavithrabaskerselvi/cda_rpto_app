import 'package:flutter/material.dart';
import '../models/analytics_summary_model.dart';

/// Card shell + a simple bar chart for a list of TrendPoint (month label +
/// value). No fl_chart dependency — plain CustomPainter, matching
/// kpi_card.dart's sparkline approach. Swap the painter for fl_chart later
/// if the project already depends on it.
class TrendChartCard extends StatelessWidget {
  final String title;
  final List<TrendPoint> points;
  final Color barColor;
  final String Function(double)? valueFormatter; // e.g. currency formatting

  const TrendChartCard({
    super.key,
    required this.title,
    required this.points,
    required this.barColor,
    this.valueFormatter,
  });

  bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
  Color _surface(BuildContext c) =>
      _isDark(c) ? const Color(0xFF0F1B2E) : const Color(0xFFFFFFFF);
  Color _textPrimary(BuildContext c) =>
      _isDark(c) ? Colors.white : const Color(0xFF0B1220);
  Color _textSecondary(BuildContext c) =>
      _isDark(c) ? Colors.white70 : const Color(0xFF5B6472);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface(context),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: _textPrimary(context),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          if (points.isEmpty)
            SizedBox(
              height: 120,
              child: Center(
                child: Text('No data yet', style: TextStyle(color: _textSecondary(context))),
              ),
            )
          else
            SizedBox(
              height: 140,
              child: CustomPaint(
                size: Size.infinite,
                painter: _BarChartPainter(
                  points: points,
                  barColor: barColor,
                  labelColor: _textSecondary(context),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<TrendPoint> points;
  final Color barColor;
  final Color labelColor;

  _BarChartPainter({
    required this.points,
    required this.barColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final maxVal = points.map((p) => p.value).fold<double>(0, (a, b) => a > b ? a : b);
    final chartHeight = size.height - 20; // reserve space for labels
    final barCount = points.length;
    final gap = 8.0;
    final barWidth = (size.width - gap * (barCount - 1)) / barCount;

    final barPaint = Paint()..color = barColor;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < barCount; i++) {
      final point = points[i];
      final heightRatio = maxVal == 0 ? 0 : point.value / maxVal;
      final barHeight = chartHeight * heightRatio;
      final x = i * (barWidth + gap);
      final y = chartHeight - barHeight;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        const Radius.circular(4),
      );
      canvas.drawRRect(rect, barPaint);

      textPainter.text = TextSpan(
        text: point.label,
        style: TextStyle(color: labelColor, fontSize: 10),
      );
      textPainter.layout(minWidth: barWidth, maxWidth: barWidth);
      textPainter.paint(canvas, Offset(x, chartHeight + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.barColor != barColor;
}
