import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

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

  // Staggered pulse loop that drives the three loading dots.
  late final AnimationController _dotsCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  // Shimmer highlight that runs along the progress bar.
  late final AnimationController _shimmerCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  // Overall load progress — drives the bar fill and the "locked on" color
  // swap (blue/teal -> green) once it reaches 100%.
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
    _dotsCtrl.dispose();
    _shimmerCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
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

          // ── 3. Thin bottom scrim — only shades the strip behind the
          // loading indicator, not the artwork above it. ─────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: size.height * 0.16,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _kNavy.withValues(alpha: 0.0),
                      _kNavy.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── 4. Loading indicator — three staggered, glowing pulse dots
          // paired with a shimmering gradient progress bar underneath.
          // No ring, purely visual, no text. ──────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: Listenable.merge([_dotsCtrl, _progressCtrl]),
                        builder: (context, _) {
                          return _PulseDots(
                            t: _dotsCtrl.value,
                            lockedOn: _progressAnimation.value >= 1.0,
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      AnimatedBuilder(
                        animation: Listenable.merge(
                            [_shimmerCtrl, _progressCtrl]),
                        builder: (context, _) {
                          return _ShimmerProgressBar(
                            progress: _progressAnimation.value,
                            shimmerT: _shimmerCtrl.value,
                            lockedOn: _progressAnimation.value >= 1.0,
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

// ═══════════════════════════════════════════════════════════════════════════
//  PULSE DOTS
//  Three glowing dots that scale/fade in a staggered wave (each offset by
//  a fixed phase), cycling blue -> teal, and swapping to green once
//  loading is complete. Themed with RPTO's teal/blue.
// ═══════════════════════════════════════════════════════════════════════════
class _PulseDots extends StatelessWidget {
  final double t; // looping 0..1
  final bool lockedOn;

  const _PulseDots({required this.t, required this.lockedOn});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final phase = i * 0.22;
        final wave = (math.sin((t + phase) * 2 * math.pi) + 1) / 2; // 0..1
        final scale = 0.55 + wave * 0.55;
        final opacity = 0.35 + wave * 0.65;
        final color = lockedOn ? _kGreen : Color.lerp(_kBlue, _kTeal, wave)!;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: opacity),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: opacity * 0.55),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SHIMMER PROGRESS BAR
//  Rounded track with a gradient fill that grows with progress, plus a
//  soft diagonal shimmer highlight that sweeps across the filled portion.
// ═══════════════════════════════════════════════════════════════════════════
class _ShimmerProgressBar extends StatelessWidget {
  final double progress;
  final double shimmerT;
  final bool lockedOn;

  const _ShimmerProgressBar({
    required this.progress,
    required this.shimmerT,
    required this.lockedOn,
  });

  static const double _width = 120;
  static const double _height = 4;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _width,
      height: _height,
      child: Stack(
        children: [
          // Track.
          Container(
            width: _width,
            height: _height,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(_height),
            ),
          ),
          // Fill.
          ClipRRect(
            borderRadius: BorderRadius.circular(_height),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(
                  height: _height,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: lockedOn
                          ? [_kGreen, _kTeal]
                          : [_kBlue, _kTeal],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (lockedOn ? _kGreen : _kTeal).withValues(alpha: 0.6),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: ShaderMask(
                    blendMode: BlendMode.srcATop,
                    shaderCallback: (rect) {
                      final dx = (shimmerT * 2 - 0.5) * rect.width;
                      return LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.0),
                          Colors.white.withValues(alpha: 0.55),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                        stops: const [0.35, 0.5, 0.65],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        transform: _SlideGradient(dx),
                      ).createShader(rect);
                    },
                    child: const SizedBox.expand(),
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

/// Shifts a gradient horizontally by [dx] logical pixels — used to slide
/// the shimmer highlight across the progress bar fill each frame.
class _SlideGradient extends GradientTransform {
  final double dx;
  const _SlideGradient(this.dx);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(dx, 0, 0);
  }
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