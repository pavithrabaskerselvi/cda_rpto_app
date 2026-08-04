import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// TODO: point this to wherever your app decides Admin/Instructor/Student
// routing after splash — usually an AuthGate widget in main.dart.
// import '../auth/login_screen.dart';
//
// If your RPTO app actually uses Firebase Auth + role-based routing like
// CDA Inventory does, swap the `_finish()` body below for something like:
//
//   final user = FirebaseAuth.instance.currentUser;
//   if (user == null) {
//     Navigator.pushReplacementNamed(context, '/login');
//     return;
//   }
//   final roleInfo = await AuthService.getCurrentUserRoleAndProfile();
//   ... same pattern as CDA Inventory's SplashScreen._checkLogin() ...

// NOTE: If your project's `lib/config/constants.dart` already defines
// kNavy / kTeal / kSurface, delete these locals and import that file
// instead so this screen shares the exact tokens as login/register screens.
const _kNavy = Color(0xFF050A14);
const _kSurface = Color(0xFF0F1B2E);
const _kTeal = Color(0xFF14B8A6);
const _kBlue = Color(0xFF2F6FED);
const _kGreen = Color(0xFF22C55E);

// Hero drone/skyline photo, already baked with the "REAL-TIME PERMISSION /
// RPTO / TAKEOFF OPERATIONS" wordmark on it (per the asset you added).
// Path must match EXACTLY what's registered under `flutter: assets:` in
// pubspec.yaml.
const _kHeroImageAssetPath = 'lib/assets/images/splash_screen.png';

class SplashScreen extends StatefulWidget {
  /// Called once the splash animation finishes. Wire this to Navigator
  /// .pushReplacement(...) to your AuthGate / LoginScreen in main.dart,
  /// e.g. onFinished: () => Navigator.pushReplacement(context,
  /// MaterialPageRoute(builder: (_) => const AuthGate())).
  final VoidCallback? onFinished;

  const SplashScreen({super.key, this.onFinished});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Artwork entrance (fade + Ken-Burns slow zoom).
  late final AnimationController _entranceCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  )..forward();
  late final Animation<double> _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
      .animate(CurvedAnimation(
    parent: _entranceCtrl,
    curve: const Interval(0.0, 0.45, curve: Curves.easeIn),
  ));
  late final Animation<double> _zoomAnimation = Tween<double>(begin: 1.06, end: 1.0)
      .animate(CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic));

  // Twinkling star / particle field over the sky.
  late final AnimationController _starsCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();
  late final List<_Star> _stars =
  List.generate(36, (i) => _Star.random(math.Random(i * 97)));

  // Radar sweep rotation — one full rotation every 2.2s.
  late final AnimationController _sweepCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  // Expanding "ping" ring every 1.6s.
  late final AnimationController _pingCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  // Overall load progress — drives the status label, % readout, and the
  // radar's "locked on" state once it reaches 100%.
  late final AnimationController _progressCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  late final Animation<double> _progressAnimation = CurvedAnimation(
    parent: _progressCtrl,
    curve: Curves.easeInOut,
  );

  Timer? _navTimer;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _progressCtrl.forward();
    });
    _navTimer = Timer(const Duration(milliseconds: 2800), _finish);
  }

  void _finish() {
    if (!mounted) return;
    widget.onFinished?.call();
    // Fallback if no callback was provided — replace with your real route.
    // Navigator.of(context).pushReplacement(
    //   MaterialPageRoute(builder: (_) => const LoginScreen()),
    // );
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _entranceCtrl.dispose();
    _starsCtrl.dispose();
    _sweepCtrl.dispose();
    _pingCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  String _statusLabel(double progress) {
    if (progress < 0.25) return 'INITIALIZING RPTO SYSTEM';
    if (progress < 0.55) return 'SCANNING AIRSPACE';
    if (progress < 0.85) return 'PRE-FLIGHT READY';
    return 'CLEARED FOR TAKEOFF';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _kNavy,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Hero artwork — Ken-Burns zoom + fade-in. On phone-shaped
          // screens (portrait, narrow) we fill edge-to-edge with `cover`.
          // On much wider windows (desktop browser, tablet landscape) we
          // switch to `contain` so `cover` doesn't chop the top/bottom of
          // the artwork off. This is what keeps it correctly sized on
          // every phone, no matter how tall/short the screen is. ────────
          AnimatedBuilder(
            animation: _entranceCtrl,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.scale(scale: _zoomAnimation.value, child: child),
              );
            },
            child: Image.asset(
              _kHeroImageAssetPath,
              fit: (size.width / size.height) < 0.85 ? BoxFit.cover : BoxFit.contain,
              alignment: Alignment.center,
              width: size.width,
              height: size.height,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_kSurface, _kNavy],
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.flight_takeoff_rounded, size: 90, color: _kTeal),
                  ),
                );
              },
            ),
          ),

          // ── 2. Twinkling star field over the sky ───────────────────────
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _starsCtrl,
              builder: (context, _) {
                return CustomPaint(
                  painter: _StarFieldPainter(stars: _stars, time: _starsCtrl.value),
                );
              },
            ),
          ),

          // ── 3. Top strapline ────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: const _TopStrapline(),
              ),
            ),
          ),

          // ── 4. Thin bottom scrim — only shades the strip behind the
          // radar/loading readout, not the artwork above it. ─────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: size.height * 0.14,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _kNavy.withValues(alpha: 0.0),
                      _kNavy.withValues(alpha: 0.82),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── 5. Radar-scanner loading indicator, pinned to the bottom
          // safe-area edge. ────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      AnimatedBuilder(
                        animation:
                        Listenable.merge([_sweepCtrl, _pingCtrl, _progressCtrl]),
                        builder: (context, _) {
                          return SizedBox(
                            width: 32,
                            height: 32,
                            child: CustomPaint(
                              painter: _RadarPainter(
                                sweepAngle: _sweepCtrl.value * 2 * math.pi,
                                pingProgress: _pingCtrl.value,
                                lockedOn: _progressAnimation.value >= 1.0,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      AnimatedBuilder(
                        animation: _progressCtrl,
                        builder: (context, _) {
                          final pct = (_progressAnimation.value * 100).round();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${_statusLabel(_progressAnimation.value)}...',
                                style: GoogleFonts.orbitron(
                                  color: Colors.white70,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '$pct%',
                                style: GoogleFonts.orbitron(
                                  color: _kTeal,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Small letter-spaced strapline above the hero image: "LEARN · INNOVATE ·
/// FLY".
/// ---------------------------------------------------------------------------
class _TopStrapline extends StatelessWidget {
  const _TopStrapline();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'LEARN   ·   INNOVATE   ·   FLY',
        style: GoogleFonts.orbitron(
          color: Colors.white70,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 2.0,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  RADAR PAINTER
//  Circular scanner: grid rings, rotating sweep beam, expanding ping ring,
//  and a locked-on blip once loading completes. Themed with RPTO's teal.
// ═══════════════════════════════════════════════════════════════════════════
class _RadarPainter extends CustomPainter {
  final double sweepAngle;
  final double pingProgress;
  final bool lockedOn;

  const _RadarPainter({
    required this.sweepAngle,
    required this.pingProgress,
    required this.lockedOn,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [_kSurface, _kNavy],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = _kTeal.withValues(alpha: 0.18);
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, radius * i / 3, gridPaint);
    }
    canvas.drawLine(center - Offset(radius, 0), center + Offset(radius, 0), gridPaint);
    canvas.drawLine(center - Offset(0, radius), center + Offset(0, radius), gridPaint);

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));
    canvas.translate(center.dx, center.dy);
    canvas.rotate(sweepAngle);
    final sweepRect = Rect.fromCircle(center: Offset.zero, radius: radius);
    canvas.drawArc(
      sweepRect,
      0,
      math.pi / 2.4,
      true,
      Paint()
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: math.pi / 2.4,
          colors: [
            _kTeal.withValues(alpha: 0.55),
            _kTeal.withValues(alpha: 0.0),
          ],
        ).createShader(sweepRect),
    );
    canvas.restore();

    final pingRadius = radius * pingProgress;
    canvas.drawCircle(
      center,
      pingRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = _kTeal.withValues(alpha: (1 - pingProgress) * 0.8),
    );

    canvas.drawCircle(
      center,
      radius - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.white.withValues(alpha: 0.18),
    );

    final blipColor = lockedOn
        ? _kGreen
        : Color.lerp(_kBlue, _kTeal, (math.sin(sweepAngle) + 1) / 2)!;
    canvas.drawCircle(center, 4, Paint()..color = blipColor);
    canvas.drawCircle(
      center,
      8,
      Paint()
        ..color = blipColor.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) =>
      old.sweepAngle != sweepAngle ||
          old.pingProgress != pingProgress ||
          old.lockedOn != lockedOn;
}

// ═══════════════════════════════════════════════════════════════════════════
//  STAR FIELD PAINTER — subtle twinkling particles drifting over the sky
// ═══════════════════════════════════════════════════════════════════════════
class _Star {
  final double x;
  final double y;
  final double size;
  final double phase;
  final double speed;

  _Star(this.x, this.y, this.size, this.phase, this.speed);

  factory _Star.random(math.Random r) {
    return _Star(
      r.nextDouble(),
      r.nextDouble() * 0.6,
      0.8 + r.nextDouble() * 1.6,
      r.nextDouble() * 2 * math.pi,
      0.6 + r.nextDouble() * 0.8,
    );
  }
}

class _StarFieldPainter extends CustomPainter {
  final List<_Star> stars;
  final double time;

  _StarFieldPainter({required this.stars, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final t = time * 2 * math.pi;
    for (final star in stars) {
      final twinkle = (math.sin(t * star.speed + star.phase) + 1) / 2;
      final opacity = 0.15 + twinkle * 0.55;
      canvas.drawCircle(
        Offset(star.x * size.width, star.y * size.height),
        star.size,
        Paint()..color = Colors.white.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarFieldPainter old) => old.time != time;
}