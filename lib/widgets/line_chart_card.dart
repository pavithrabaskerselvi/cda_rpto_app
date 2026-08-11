import 'package:flutter/material.dart';
import '../models/analytics_summary_model.dart';

/// Card shell + a premium-styled line chart (smooth line, gradient area
/// fill under the curve, dot markers) for a list of TrendPoint (month
/// label + value). Plain CustomPainter, no fl_chart dependency — matches
/// kpi_card.dart / pie_chart_card.dart's approach.
class LineChartCard extends StatelessWidget {
  final String title;
  final List<TrendPoint> points;
  final Color lineColor;
  final String Function(double)? valueFormatter;

  const LineChartCard({
    super.key,
    required this.title,
    required this.points,
    required this.lineColor,
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
    final latest = points.isEmpty ? null : points.last;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isDark(context) ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFEDF1F7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDark(context) ? 0.25 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: _textPrimary(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (latest != null)
                Text(
                  valueFormatter != null
                      ? valueFormatter!(latest.value)
                      : latest.value.toStringAsFixed(0),
                  style: TextStyle(
                    color: lineColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (points.isEmpty)
            SizedBox(
              height: 140,
              child: Center(
                child: Text('No data yet', style: TextStyle(color: _textSecondary(context))),
              ),
            )
          else
            SizedBox(
              height: 150,
              child: CustomPaint(
                size: Size.infinite,
                painter: _LineChartPainter(
                  points: points,
                  lineColor: lineColor,
                  labelColor: _textSecondary(context),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<TrendPoint> points;
  final Color lineColor;
  final Color labelColor;

  _LineChartPainter({
    required this.points,
    required this.lineColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final maxVal = points.map((p) => p.value).fold<double>(0, (a, b) => a > b ? a : b);
    final minVal = points.map((p) => p.value).fold<double>(maxVal, (a, b) => a < b ? a : b);
    final range = (maxVal - minVal).abs() < 0.0001 ? 1 : (maxVal - minVal);

    const labelSpace = 20.0;
    final chartHeight = size.height - labelSpace;
    final count = points.length;
    final stepX = count > 1 ? size.width / (count - 1) : 0;

    final offsets = <Offset>[];
    for (int i = 0; i < count; i++) {
      final x = count > 1 ? i * stepX : size.width / 2;
      final normalized = (points[i].value - minVal) / range;
      final y = chartHeight - (normalized * (chartHeight - 12)) - 4;
      offsets.add(Offset(x.toDouble(), y));
    }

    // Smooth path through the points (simple quadratic smoothing between
    // consecutive midpoints) so the line reads as a curve, not a zig-zag.
    final linePath = Path();
    if (offsets.isNotEmpty) {
      linePath.moveTo(offsets.first.dx, offsets.first.dy);
      for (int i = 0; i < offsets.length - 1; i++) {
        final p0 = offsets[i];
        final p1 = offsets[i + 1];
        final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
        linePath.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
      }
      linePath.lineTo(offsets.last.dx, offsets.last.dy);
    }

    // Gradient area fill under the curve — the "premium" touch.
    final areaPath = Path.from(linePath)
      ..lineTo(offsets.last.dx, chartHeight)
      ..lineTo(offsets.first.dx, chartHeight)
      ..close();

    final areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [lineColor.withValues(alpha: 0.28), lineColor.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, chartHeight));
    canvas.drawPath(areaPath, areaPaint);

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    // Dot markers with a soft glow, plus month labels underneath.
    final dotGlowPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final dotPaint = Paint()..color = Colors.white;
    final dotRingPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < offsets.length; i++) {
      final o = offsets[i];
      canvas.drawCircle(o, 5.5, dotGlowPaint);
      canvas.drawCircle(o, 3.2, dotPaint);
      canvas.drawCircle(o, 3.2, dotRingPaint);

      final labelWidth = count > 1 ? stepX.toDouble() : size.width;
      final labelX = (o.dx - labelWidth / 2).clamp(0, size.width - labelWidth);
      textPainter.text = TextSpan(
        text: points[i].label,
        style: TextStyle(color: labelColor, fontSize: 10),
      );
      textPainter.textAlign = TextAlign.center;
      textPainter.layout(minWidth: labelWidth, maxWidth: labelWidth);
      textPainter.paint(canvas, Offset(labelX.toDouble(), chartHeight + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.lineColor != lineColor;
}