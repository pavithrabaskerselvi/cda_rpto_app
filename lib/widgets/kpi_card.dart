import 'package:flutter/material.dart';

/// Reusable KPI card: a value, its label, an icon, and an optional
/// %-change vs the previous period. No fl_chart dependency — the
/// sparkline is a tiny custom-painted line so this widget has zero
/// extra package requirements.
class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;
  final double? percentChange; // null hides the change row
  final List<double>? sparklineValues; // null hides the sparkline

  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
    this.percentChange,
    this.sparklineValues,
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
    final isPositive = (percentChange ?? 0) >= 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  color: accentColor.withValues(alpha: 0.14),
                ),
                child: Icon(icon, color: accentColor, size: 17),
              ),
              const Spacer(),
              if (sparklineValues != null && sparklineValues!.length > 1)
                SizedBox(
                  width: 48,
                  height: 20,
                  child: CustomPaint(
                    painter: _SparklinePainter(
                      values: sparklineValues!,
                      color: accentColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: _textPrimary(context),
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: _textSecondary(context), fontSize: 11.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (percentChange != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  size: 13,
                  color: isPositive ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
                ),
                const SizedBox(width: 2),
                Text(
                  '${percentChange!.abs().toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: isPositive ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'vs last period',
                  style: TextStyle(color: _textSecondary(context), fontSize: 11),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;

  _SparklinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final minVal = values.reduce((a, b) => a < b ? a : b);
    final range = (maxVal - minVal).abs() < 0.0001 ? 1 : (maxVal - minVal);

    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final x = size.width * (i / (values.length - 1));
      final normalized = (values[i] - minVal) / range;
      final y = size.height - (normalized * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}