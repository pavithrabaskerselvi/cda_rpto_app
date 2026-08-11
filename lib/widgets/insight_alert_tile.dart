import 'package:flutter/material.dart';

enum InsightSeverity { info, warning, critical }

/// One row in the Insights/Alerts section — e.g. "12 students have
/// attendance below 75%". Purely presentational; the caller decides
/// what text/severity to pass based on computed AnalyticsSummaryModel
/// values.
class InsightAlertTile extends StatelessWidget {
  final String message;
  final InsightSeverity severity;
  final VoidCallback? onTap;

  const InsightAlertTile({
    super.key,
    required this.message,
    this.severity = InsightSeverity.info,
    this.onTap,
  });

  bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
  Color _surface(BuildContext c) =>
      _isDark(c) ? const Color(0xFF0F1B2E) : const Color(0xFFFFFFFF);
  Color _textPrimary(BuildContext c) =>
      _isDark(c) ? Colors.white : const Color(0xFF0B1220);

  Color _severityColor() {
    switch (severity) {
      case InsightSeverity.critical:
        return const Color(0xFFE74C3C);
      case InsightSeverity.warning:
        return const Color(0xFFFFB020);
      case InsightSeverity.info:
        return const Color(0xFF14B8A6);
    }
  }

  IconData _severityIcon() {
    switch (severity) {
      case InsightSeverity.critical:
        return Icons.error_rounded;
      case InsightSeverity.warning:
        return Icons.warning_amber_rounded;
      case InsightSeverity.info:
        return Icons.info_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _severityColor();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: _surface(context),
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Row(
          children: [
            Icon(_severityIcon(), color: color, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: _textPrimary(context), fontSize: 13.5),
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, color: color, size: 18),
          ],
        ),
      ),
    );
  }
}
