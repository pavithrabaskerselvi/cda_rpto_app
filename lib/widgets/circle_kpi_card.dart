import 'package:flutter/material.dart';

/// Compact, premium circular KPI stat — a glowing gradient ring with the
/// icon + value inside, and the label underneath. Built to sit several-in-a
/// row without ever wrapping to a new line, unlike the old boxy KpiCard.
class CircleKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;
  final double diameter;

  const CircleKpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
    this.diameter = 64,
  });

  bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
  Color _textSecondary(BuildContext c) =>
      _isDark(c) ? Colors.white60 : const Color(0xFF5B6472);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                accentColor.withValues(alpha: 1.0),
                accentColor.withValues(alpha: 0.55),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.28),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.40),
                blurRadius: 16,
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: diameter * 0.20),
                SizedBox(height: diameter * 0.03),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: diameter * 0.19,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _textSecondary(context),
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Wraps a row of [CircleKpiCard]s in a subtle premium glass panel so the
/// whole stat strip reads as one cohesive component instead of loose circles
/// floating on the page background.
class CircleKpiRow extends StatelessWidget {
  final List<CircleKpiCard> cards;

  const CircleKpiRow({super.key, required this.cards});

  bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
  Color _surface(BuildContext c) =>
      _isDark(c) ? const Color(0xFF0F1B2E) : const Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        color: _surface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isDark(context)
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFEDF1F7),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: cards,
      ),
    );
  }
}