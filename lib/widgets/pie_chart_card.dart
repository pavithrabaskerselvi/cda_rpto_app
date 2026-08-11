import 'package:flutter/material.dart';

/// One slice of a [PieChartCard] — a label, its value, and the color used
/// for both the donut slice and the legend dot.
class PieSlice {
  final String label;
  final double value;
  final Color color;

  const PieSlice({required this.label, required this.value, required this.color});
}

/// Card shell + a donut chart with a legend, in the same premium card style
/// as KpiCard / LineChartCard. Plain CustomPainter, no fl_chart dependency.
class PieChartCard extends StatelessWidget {
  final String title;
  final List<PieSlice> slices;
  final String? centerLabel; // e.g. total count shown in the donut hole

  const PieChartCard({
    super.key,
    required this.title,
    required this.slices,
    this.centerLabel,
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
    final total = slices.fold<double>(0, (a, s) => a + s.value);

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
          Text(
            title,
            style: TextStyle(
              color: _textPrimary(context),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          if (total <= 0)
            SizedBox(
              height: 120,
              child: Center(
                child: Text('No data yet', style: TextStyle(color: _textSecondary(context))),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 300;
                final donut = SizedBox(
                  width: 128,
                  height: 128,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(128, 128),
                        painter: _DonutPainter(slices: slices, total: total),
                      ),
                      if (centerLabel != null)
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              centerLabel!,
                              style: TextStyle(
                                color: _textPrimary(context),
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Total',
                              style: TextStyle(color: _textSecondary(context), fontSize: 11),
                            ),
                          ],
                        ),
                    ],
                  ),
                );

                final legend = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: slices.map((s) {
                    final pct = total == 0 ? 0 : (s.value / total) * 100;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: s.color),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s.label,
                              style: TextStyle(color: _textPrimary(context), fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${s.value.toStringAsFixed(0)} (${pct.toStringAsFixed(0)}%)',
                            style: TextStyle(
                              color: _textSecondary(context),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );

                if (isNarrow) {
                  return Column(
                    children: [
                      Center(child: donut),
                      const SizedBox(height: 16),
                      legend,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    donut,
                    const SizedBox(width: 20),
                    Expanded(child: legend),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<PieSlice> slices;
  final double total;

  _DonutPainter({required this.slices, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    const strokeWidth = 20.0;
    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    double startAngle = -90 * (3.1415926535 / 180);
    for (final slice in slices) {
      if (slice.value <= 0) continue;
      final sweep = (slice.value / total) * 2 * 3.1415926535;
      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.slices != slices || oldDelegate.total != total;
}