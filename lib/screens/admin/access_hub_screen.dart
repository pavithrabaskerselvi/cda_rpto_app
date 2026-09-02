// lib/screens/admin/access_hub_screen.dart
//
// Consolidated entry point for the three admin-only screens
// (Instructor Access / Access Requests / Live Activity), replacing the
// three separate dashboard tiles with one "Access Hub" tile.
//
// Header carries a soft teal-to-white gradient with several small
// X-shaped drones drifting across it on independent diagonal paths —
// each drone has its own direction, speed, size and delay, so the
// motion reads as an elegant ambient flock rather than one repeating
// animation.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../config/routes.dart';
import 'employee_access_screen.dart';
import 'admin_notifications_screen.dart';
import 'activity_feed_screen.dart';

class AccessHubScreen extends StatefulWidget {
  const AccessHubScreen({super.key});

  @override
  State<AccessHubScreen> createState() => _AccessHubScreenState();
}

class _AccessHubScreenState extends State<AccessHubScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _droneController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();

  @override
  void dispose() {
    _droneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F5),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------------- Header: teal-to-white wash + drones ----------------
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 26),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF8FD3C4),
                      Color(0xFFCDE9DE),
                      Color(0xFFF3F6F5),
                    ],
                    stops: [0.0, 0.55, 1.0],
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Ambient flock of X-shaped drones, each drifting its
                    // own diagonal line across the header.
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _droneController,
                        builder: (context, child) {
                          return CustomPaint(
                            painter: _OmniDronePainter(
                              progress: _droneController.value,
                              color: const Color(0xFF0F3D33),
                            ),
                          );
                        },
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Color(0xFF0A2540)),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(height: 4),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            'Access Hub',
                            style: TextStyle(
                              color: Color(0xFF0A2540),
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ---------------- Tiles ----------------
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: Column(
                  children: [
                    _HubTile(
                      icon: Icons.badge_outlined,
                      iconColor: AppColors.teal,
                      title: 'Instructor Access',
                      subtitle: 'Grant, revoke or manage instructor account access',
                      onTap: () => Navigator.pushNamed(context, AppRoutes.employeeAccess),
                    ),
                    const SizedBox(height: 12),
                    _HubTile(
                      icon: Icons.mail_outline_rounded,
                      iconColor: AppColors.amber,
                      title: 'Access Requests',
                      subtitle: 'Review and approve pending access requests',
                      onTap: () => Navigator.pushNamed(context, AppRoutes.adminNotifications),
                    ),
                    const SizedBox(height: 12),
                    _HubTile(
                      icon: Icons.bolt_rounded,
                      iconColor: AppColors.blue,
                      title: 'Live Activity',
                      subtitle: 'Real-time feed of who is doing what',
                      onTap: () => Navigator.pushNamed(context, AppRoutes.activityFeed),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HubTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE3E8E6)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF0A2540),
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- Omni-directional X-shaped drone painter ----------------

/// Each drone follows its own straight diagonal line (start -> end,
/// both given as fractional header coordinates) at its own phase and
/// speed, so several drones can be crossing the header at once from
/// different directions ("flying in all directions") without ever
/// looking mechanically synced.
class _DroneFlightPath {
  final Offset start; // fractional (0..1) of header size
  final Offset end; // fractional (0..1) of header size
  final double phaseOffset; // 0..1, staggers when this drone starts its pass
  final double flightSpan; // fraction of the loop this drone is visible for
  final double scale;

  const _DroneFlightPath({
    required this.start,
    required this.end,
    required this.phaseOffset,
    required this.flightSpan,
    required this.scale,
  });
}

class _OmniDronePainter extends CustomPainter {
  final double progress;
  final Color color;

  _OmniDronePainter({required this.progress, required this.color});

  static const List<_DroneFlightPath> _paths = [
    // Bottom-left -> top-right
    _DroneFlightPath(
      start: Offset(-0.08, 0.95),
      end: Offset(1.08, 0.05),
      phaseOffset: 0.00,
      flightSpan: 0.42,
      scale: 1.15,
    ),
    // Top-left -> bottom-right
    _DroneFlightPath(
      start: Offset(-0.06, 0.10),
      end: Offset(1.05, 0.85),
      phaseOffset: 0.30,
      flightSpan: 0.40,
      scale: 0.85,
    ),
    // Right -> left, gentle upward drift
    _DroneFlightPath(
      start: Offset(1.08, 0.55),
      end: Offset(-0.08, 0.20),
      phaseOffset: 0.55,
      flightSpan: 0.38,
      scale: 1.0,
    ),
    // Bottom-right -> top-left, slow and small (reads as "far away")
    _DroneFlightPath(
      start: Offset(1.05, 0.90),
      end: Offset(0.05, -0.05),
      phaseOffset: 0.75,
      flightSpan: 0.45,
      scale: 0.65,
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final path in _paths) {
      _paintDrone(canvas, size, path);
    }
  }

  void _paintDrone(Canvas canvas, Size size, _DroneFlightPath path) {
    final localProgress = (progress + path.phaseOffset) % 1.0;
    if (localProgress > path.flightSpan) return;

    // Ease-in-out so the drone accelerates out of the corner and settles
    // into the far corner smoothly, instead of moving at constant speed.
    final rawT = localProgress / path.flightSpan;
    final t = rawT < 0.5
        ? 2 * rawT * rawT
        : 1 - math.pow(-2 * rawT + 2, 2) / 2;

    double opacity = 1.0;
    if (rawT < 0.1) {
      opacity = rawT / 0.1;
    } else if (rawT > 0.88) {
      opacity = (1.0 - rawT) / 0.12;
    }
    opacity = opacity.clamp(0.0, 1.0);
    if (opacity <= 0) return;

    final dx = path.start.dx + (path.end.dx - path.start.dx) * t;
    final dy = path.start.dy + (path.end.dy - path.start.dy) * t;
    final center = Offset(size.width * dx, size.height * dy);

    // Heading angle follows the flight direction so the X-shape banks
    // naturally into its own path instead of staying axis-aligned.
    final heading = math.atan2(
      (path.end.dy - path.start.dy) * size.height,
      (path.end.dx - path.start.dx) * size.width,
    );
    // Subtle wing-wobble layered on top of the heading for a livelier,
    // less mechanical glide.
    final wobble = math.sin(t * math.pi * 3) * 0.06;

    _drawXDrone(canvas, center, heading + wobble, path.scale, opacity);
  }

  void _drawXDrone(Canvas canvas, Offset center, double angle, double scale, double opacity) {
    final armPaint = Paint()
      ..color = color.withValues(alpha: 0.85 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * scale
      ..strokeCap = StrokeCap.round;
    final rotorGlowPaint = Paint()
      ..color = color.withValues(alpha: 0.22 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * scale
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final rotorRingPaint = Paint()
      ..color = color.withValues(alpha: 0.8 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1 * scale;
    final bodyGlowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55 * opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    final bodyPaint = Paint()..color = Colors.white.withValues(alpha: 0.95 * opacity);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.scale(scale);

    const armLen = 8.0;
    final armOffsets = [
      const Offset(-armLen, -armLen * 0.7),
      const Offset(armLen, -armLen * 0.7),
      const Offset(-armLen, armLen * 0.7),
      const Offset(armLen, armLen * 0.7),
    ];

    for (final o in armOffsets) {
      canvas.drawLine(Offset.zero, o, armPaint);
    }

    const rotorRadius = 4.4;
    for (final o in armOffsets) {
      canvas.drawCircle(o, rotorRadius, rotorGlowPaint);
      canvas.drawCircle(o, rotorRadius, rotorRingPaint);
    }

    canvas.drawCircle(Offset.zero, 4.0, bodyGlowPaint);
    canvas.drawCircle(Offset.zero, 1.9, bodyPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OmniDronePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}