import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_text_field.dart';
import 'register_screen.dart';

const _kNavy = Color(0xFF050A14);
const _kSurface = Color(0xFF0F1B2E);
const _kTeal = Color(0xFF14B8A6);
const _kCoralFix = Color(0xFFFF6B6B);

const _kLogoAssetPath = 'lib/assets/images/logo.webp';

const _kWideBreakpoint = 900.0;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _isLoading = false;

  String _selectedRole = 'Admin';
  final List<_RoleOption> _roles = const [
    _RoleOption('Admin', Icons.shield_moon_rounded),
    _RoleOption('Instructor', Icons.flight_class_rounded),
    _RoleOption('Student', Icons.school_rounded),
  ];

  late final AnimationController _entranceCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  late final AnimationController _ambientCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat(reverse: true);

  Animation<double> _stagger(double start, double end) {
    return CurvedAnimation(
      parent: _entranceCtrl,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(() => setState(() {}));
    _passwordFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _entranceCtrl.dispose();
    _ambientCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final error = await AuthService.login(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (error != null) {
      setState(() => _isLoading = false);
      _showSnack(error, isError: true);
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      return;
    }

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

    if (!mounted) return;

    if (!userDoc.exists) {
      setState(() => _isLoading = false);
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      _showSnack('User profile not found. Contact admin.', isError: true);
      return;
    }

    final actualRole = userDoc.data()?['role'] ?? '';

    if (actualRole != _selectedRole) {
      setState(() => _isLoading = false);
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      _showSnack('Role mismatch: your account is registered as "$actualRole".', isError: true);
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? _kCoralFix : _kTeal,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kNavy,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= _kWideBreakpoint;

          if (isWide) {
            return Row(
              children: [
                const Expanded(flex: 6, child: _HeroPanel()),
                Expanded(
                  flex: 4,
                  child: Container(
                    color: _kNavy,
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                        child: _CardShell(
                          child: _buildFormContent(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return Stack(
            children: [
              _AmbientBackground(controller: _ambientCtrl),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: _buildFormContent(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFormContent() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          _FadeSlideIn(
            animation: _stagger(0.0, 0.5),
            child: _AnimatedLogo(controller: _ambientCtrl),
          ),
          const SizedBox(height: 20),
          _FadeSlideIn(
            animation: _stagger(0.1, 0.6),
            child: _TitleBlock(),
          ),
          const SizedBox(height: 36),
          _FadeSlideIn(
            animation: _stagger(0.2, 0.7),
            child: _RoleDropdown(
              roles: _roles,
              selected: _selectedRole,
              onChanged: (role) => setState(() => _selectedRole = role),
            ),
          ),
          const SizedBox(height: 28),
          _FadeSlideIn(
            animation: _stagger(0.3, 0.8),
            child: _GlowField(
              focusNode: _emailFocus,
              child: CustomTextField(
                controller: _emailController,
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Email required';
                  if (!value.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          _FadeSlideIn(
            animation: _stagger(0.35, 0.85),
            child: _GlowField(
              focusNode: _passwordFocus,
              child: CustomTextField(
                controller: _passwordController,
                label: 'Password',
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Password required';
                  if (value.length < 6) return 'Minimum 6 characters';
                  return null;
                },
              ),
            ),
          ),
          const SizedBox(height: 30),
          _FadeSlideIn(
            animation: _stagger(0.45, 0.95),
            child: _TakeoffButton(
              isLoading: _isLoading,
              onPressed: _handleLogin,
            ),
          ),
          const SizedBox(height: 18),
          _FadeSlideIn(
            animation: _stagger(0.55, 1.0),
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                );
              },
              child: RichText(
                text: const TextSpan(
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
                  children: [
                    TextSpan(text: "Don't have an account?  "),
                    TextSpan(
                      text: 'Register',
                      style: TextStyle(color: _kTeal, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  final Widget child;
  const _CardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Container(
        padding: const EdgeInsets.fromLTRB(36, 40, 36, 32),
        decoration: BoxDecoration(
          color: _kSurface.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _kTeal.withValues(alpha: 0.35), width: 1.4),
          boxShadow: [
            BoxShadow(color: _kTeal.withValues(alpha: 0.12), blurRadius: 40, spreadRadius: 4),
            BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 12)),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// Full HUD-style hero panel matching the reference image:
/// - ALT indicator (top-left)
/// - Dotted circuit/grid pattern (right side)
/// - DGCA badge with stars (top-right)
/// - Teal accent bar + headline (left)
/// - Radar/compass circle with LAT/LONG readout (bottom-left)
/// - Feature icon row (bottom)
class _HeroPanel extends StatelessWidget {
  const _HeroPanel();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 560;
        final headlineSize = isNarrow ? 22.0 : 34.0;
        final subtitleSize = isNarrow ? 12.5 : 14.0;

        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_kNavy, _kSurface],
                  ),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x66000000), Color(0x99050A14)],
                  ),
                ),
              ),

              // Dotted circuit/grid pattern, right edge.
              const Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                width: 140,
                child: IgnorePointer(child: CustomPaint(painter: _CircuitPainter())),
              ),

              // Top-left ALT indicator.
              if (!isNarrow)
                const Positioned(
                  top: 28,
                  left: 32,
                  child: _AltIndicator(),
                ),

              // Top-right DGCA compliant badge (with stars).
              const Positioned(
                top: 28,
                right: 28,
                child: _DgcaBadge(),
              ),

              // Bottom-left headline + subtitle + radar + feature icons.
              Positioned(
                left: 32,
                right: isNarrow ? 32 : 180,
                bottom: 32,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(width: 3, color: _kTeal),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'SAFETY.\nSKILL.',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: headlineSize,
                                  fontWeight: FontWeight.w900,
                                  height: 1.15,
                                ),
                              ),
                              Text(
                                'CERTIFICATION.',
                                style: TextStyle(
                                  color: _kTeal,
                                  fontSize: headlineSize,
                                  fontWeight: FontWeight.w900,
                                  height: 1.15,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.only(left: 17),
                      child: Text(
                        'Building Certified Remote Pilots\nfor a Smarter Tomorrow.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: subtitleSize,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (!isNarrow) ...[
                          const _RadarLocation(),
                          const SizedBox(width: 24),
                        ],
                        Expanded(
                          child: Wrap(
                            spacing: isNarrow ? 12 : 22,
                            runSpacing: 14,
                            children: const [
                              _FeatureIcon(icon: Icons.verified_user_rounded, label: 'Safety\nFirst'),
                              _FeatureIcon(icon: Icons.school_rounded, label: 'DGCA\nCompliant'),
                              _FeatureIcon(icon: Icons.flight_takeoff_rounded, label: 'Professional\nTraining'),
                              _FeatureIcon(icon: Icons.workspace_premium_rounded, label: 'Certified\nPilots'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Top-left "ALT 120m" HUD readout with a tiny signal-bar icon and a
/// thin progress line, matching the reference image.
class _AltIndicator extends StatelessWidget {
  const _AltIndicator();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'ALT',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          Text(
            '120m',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 1.4,
            width: 140,
            color: _kTeal.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(3, (i) {
              return Padding(
                padding: const EdgeInsets.only(right: 5),
                child: Container(
                  width: 22,
                  height: 2.2,
                  color: _kTeal.withValues(alpha: 0.6 - (i * 0.15)),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Bottom-left radar/compass circle with a pulsing ring, a location
/// pin, and a LAT/LONG readout underneath — matching the reference.
class _RadarLocation extends StatefulWidget {
  const _RadarLocation();

  @override
  State<_RadarLocation> createState() => _RadarLocationState();
}

class _RadarLocationState extends State<_RadarLocation> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 84,
          height: 84,
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              return CustomPaint(
                painter: _RadarPainter(progress: _ctrl.value),
                child: const Center(
                  child: Icon(Icons.location_on_rounded, color: _kTeal, size: 22),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            children: const [
              TextSpan(text: 'LAT '),
              TextSpan(text: '13.0827° N', style: TextStyle(color: _kTeal)),
            ],
          ),
        ),
        RichText(
          text: TextSpan(
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            children: const [
              TextSpan(text: 'LONG '),
              TextSpan(text: '80.2707° E', style: TextStyle(color: _kTeal)),
            ],
          ),
        ),
      ],
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double progress;
  const _RadarPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.width / 2;

    final ringPaint = Paint()
      ..color = _kTeal.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawCircle(center, maxRadius * 0.6, ringPaint);
    canvas.drawCircle(center, maxRadius * 0.85, ringPaint..color = _kTeal.withValues(alpha: 0.2));

    // Pulsing outer ring.
    final pulseRadius = maxRadius * (0.5 + progress * 0.5);
    final pulseOpacity = (1 - progress).clamp(0.0, 1.0) * 0.4;
    canvas.drawCircle(
      center,
      pulseRadius,
      Paint()
        ..color = _kTeal.withValues(alpha: pulseOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) => oldDelegate.progress != progress;
}

/// Faint dotted circuit-board pattern along the right edge of the
/// hero panel, matching the reference image's decorative background.
class _CircuitPainter extends CustomPainter {
  const _CircuitPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()..color = _kTeal.withValues(alpha: 0.18);
    final linePaint = Paint()
      ..color = _kTeal.withValues(alpha: 0.12)
      ..strokeWidth = 1;

    final rnd = math.Random(7);
    const spacing = 26.0;

    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        if (rnd.nextDouble() > 0.55) {
          canvas.drawCircle(Offset(x, y), 1.4, dotPaint);
        }
      }
    }

    // A few connecting lines for the "circuit" feel.
    for (int i = 0; i < 6; i++) {
      final startX = rnd.nextDouble() * size.width;
      final startY = rnd.nextDouble() * size.height;
      canvas.drawLine(
        Offset(startX, startY),
        Offset(startX, startY + 40),
        linePaint,
      );
      canvas.drawLine(
        Offset(startX, startY + 40),
        Offset(startX + 20, startY + 40),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CircuitPainter oldDelegate) => false;
}

/// DGCA badge with a ring of small stars top and bottom, matching the
/// reference image's seal-style badge.
///
/// FIX: added `const _DgcaBadge();` constructor — this widget is used
/// inside a `const Positioned(...)` in _HeroPanel, so it MUST have a
/// const constructor or the app won't compile ("The constructor being
/// called isn't a const constructor").
class _DgcaBadge extends StatelessWidget {
  const _DgcaBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.2),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 10,
            child: _starsRow(),
          ),
          const Text(
            'DGCA\nCOMPLIANT',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              height: 1.3,
            ),
          ),
          Positioned(
            bottom: 10,
            child: _starsRow(),
          ),
        ],
      ),
    );
  }

  Widget _starsRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
            (i) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 1.5),
          child: Icon(Icons.star_rounded, size: 7, color: Colors.white70),
        ),
      ),
    );
  }
}

class _FeatureIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureIcon({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _kTeal, size: 22),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _FadeSlideIn extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _FadeSlideIn({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - animation.value) * 18),
            child: child,
          ),
        );
      },
    );
  }
}

class _AmbientBackground extends StatelessWidget {
  final AnimationController controller;
  const _AmbientBackground({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        return Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_kNavy, _kSurface],
                ),
              ),
            ),
            Positioned(
              top: -140 + (t * 20),
              right: -100,
              child: _glow(_kTeal.withValues(alpha: 0.16), 320),
            ),
            Positioned(
              bottom: -160 - (t * 20),
              left: -120,
              child: _glow(_kCoralFix.withValues(alpha: 0.10), 340),
            ),
          ],
        );
      },
    );
  }

  Widget _glow(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 160, spreadRadius: 60)],
      ),
    );
  }
}

class _AnimatedLogo extends StatelessWidget {
  final AnimationController controller;
  const _AnimatedLogo({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final dy = math.sin(controller.value * math.pi) * 6;
        return Transform.translate(
          offset: Offset(0, -dy),
          child: Container(
            height: 116,
            width: 116,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: _kTeal.withValues(alpha: 0.45), blurRadius: 30, spreadRadius: 2),
                BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            padding: const EdgeInsets.all(4),
            child: ClipOval(
              child: Image.asset(
                _kLogoAssetPath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.flight_takeoff_rounded, size: 44, color: _kTeal);
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TitleBlock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'REMOTE PILOT TRAINING ORGANISATION',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'CHENNAI DRONE ACADEMY',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _kTeal,
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.4,
          ),
        ),
      ],
    );
  }
}

class _RoleOption {
  final String label;
  final IconData icon;
  const _RoleOption(this.label, this.icon);
}

class _RoleDropdown extends StatelessWidget {
  final List<_RoleOption> roles;
  final String selected;
  final ValueChanged<String> onChanged;

  const _RoleDropdown({required this.roles, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'LOGIN AS',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<String>(
              value: selected,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _kTeal),
              dropdownColor: _kSurface,
              borderRadius: BorderRadius.circular(14),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              selectedItemBuilder: (context) {
                return roles.map((role) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(role.icon, size: 18, color: _kTeal),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          role.label,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList();
              },
              items: roles.map((role) {
                return DropdownMenuItem<String>(
                  value: role.label,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(role.icon, size: 18, color: _kTeal),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          role.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) onChanged(value);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _GlowField extends StatelessWidget {
  final FocusNode focusNode;
  final Widget child;

  const _GlowField({required this.focusNode, required this.child});

  @override
  Widget build(BuildContext context) {
    final isFocused = focusNode.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: isFocused
            ? [BoxShadow(color: _kTeal.withValues(alpha: 0.28), blurRadius: 18, spreadRadius: 1)]
            : [],
        border: Border.all(
          color: isFocused ? _kTeal.withValues(alpha: 0.7) : Colors.transparent,
          width: 1.4,
        ),
      ),
      child: child,
    );
  }
}

class _TakeoffButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _TakeoffButton({required this.isLoading, required this.onPressed});

  @override
  State<_TakeoffButton> createState() => _TakeoffButtonState();
}

class _TakeoffButtonState extends State<_TakeoffButton> {
  double _scale = 1.0;

  void _setScale(double value) => setState(() => _scale = value);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.isLoading ? null : (_) => _setScale(0.97),
      onTapUp: widget.isLoading ? null : (_) => _setScale(1.0),
      onTapCancel: widget.isLoading ? null : () => _setScale(1.0),
      onTap: widget.isLoading ? null : widget.onPressed,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: widget.isLoading
                  ? [
                _kTeal.withValues(alpha: 0.5),
                const Color(0xFF0D3894).withValues(alpha: 0.5)
              ]
                  : const [_kTeal, Color(0xFF0D3894)],
            ),
            boxShadow: [
              BoxShadow(
                  color: _kTeal.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8)),
            ],
          ),
          child: widget.isLoading
              ? const SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2.4, color: Colors.white),
          )
              : const Text(
            'LOGIN',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}