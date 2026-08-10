import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_text_field.dart';
import 'register_screen.dart';

// NOTE: If your project's `lib/config/constants.dart` already defines
// kNavy / kTeal / kCoral / kAmber / kSurface, feel free to delete these
// local constants below and import that file instead so this screen
// shares the exact same tokens as the rest of the RPTO app.
const _kNavy = Color(0xFF050A14);
const _kSurface = Color(0xFF0F1B2E);
const _kTeal = Color(0xFF14B8A6);
const _kCoralFix = Color(0xFFFF6B6B);

// Path to the login background photo. Must match EXACTLY what's
// registered under `flutter: assets:` in pubspec.yaml.
const _kLoginBgAssetPath = 'lib/assets/images/login_page.png';

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
      body: Stack(
        children: [
          _AmbientBackground(controller: _ambientCtrl),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Reserve the screen as PROPORTIONAL bands that mirror the
                // photo's own composition, instead of a fixed pixel offset.
                //
                // topFlex fixes exactly where the card's TOP edge sits
                // (as a % of available height) — this never changes when
                // the card grows. The remaining space below is one single
                // Expanded band holding the card top-aligned, so making
                // the card taller only extends it further DOWN into what
                // used to be empty bottom space — it can never push
                // upward past topFlex.
                //
                // Tune these two numbers to match YOUR photo:
                //   topFlex       -> % taken up by the header/logo/title
                //   remainderFlex -> % left for the card to sit/grow in
                const topFlex = 38;
                const remainderFlex = 62; // was middleFlex(32) + bottomFlex(13)

                return SizedBox(
                  height: constraints.maxHeight,
                  child: Column(
                    children: [
                      Expanded(flex: topFlex, child: const SizedBox.shrink()),
                      Expanded(
                        flex: remainderFlex,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Align(
                            // topCenter (not Center) is what pins the card's
                            // top edge in place while letting it grow downward.
                            alignment: Alignment.topCenter,
                            child: SingleChildScrollView(
                              // If the card is ever too tall for the
                              // remaining band (very short screens, keyboard
                              // open), this lets it scroll instead of
                              // overflowing — it never forces the card
                              // back upward past its fixed top edge.
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 460),
                                child: _LoginCard(
                                  formKey: _formKey,
                                  roles: _roles,
                                  selectedRole: _selectedRole,
                                  onRoleChanged: (role) => setState(() => _selectedRole = role),
                                  emailController: _emailController,
                                  passwordController: _passwordController,
                                  emailFocus: _emailFocus,
                                  passwordFocus: _passwordFocus,
                                  obscurePassword: _obscurePassword,
                                  onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
                                  isLoading: _isLoading,
                                  onLogin: _handleLogin,
                                  stagger: _stagger,
                                  onRegisterTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The glass login card itself — pulled out to its own widget purely so
/// the proportional-band layout above stays readable.
class _LoginCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final List<_RoleOption> roles;
  final String selectedRole;
  final ValueChanged<String> onRoleChanged;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final FocusNode emailFocus;
  final FocusNode passwordFocus;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
  final bool isLoading;
  final VoidCallback onLogin;
  final Animation<double> Function(double, double) stagger;
  final VoidCallback onRegisterTap;

  const _LoginCard({
    required this.formKey,
    required this.roles,
    required this.selectedRole,
    required this.onRoleChanged,
    required this.emailController,
    required this.passwordController,
    required this.emailFocus,
    required this.passwordFocus,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.isLoading,
    required this.onLogin,
    required this.stagger,
    required this.onRegisterTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 32),
      decoration: BoxDecoration(
        color: _kSurface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(color: _kTeal.withValues(alpha: 0.10), blurRadius: 40, spreadRadius: 4),
          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 30, offset: const Offset(0, 12)),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FadeSlideIn(
              animation: stagger(0.2, 0.7),
              child: _RoleDropdown(
                roles: roles,
                selected: selectedRole,
                onChanged: onRoleChanged,
              ),
            ),
            const SizedBox(height: 18),
            _FadeSlideIn(
              animation: stagger(0.3, 0.8),
              child: _GlowField(
                focusNode: emailFocus,
                child: CustomTextField(
                  controller: emailController,
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
            const SizedBox(height: 18),
            _FadeSlideIn(
              animation: stagger(0.35, 0.85),
              child: _GlowField(
                focusNode: passwordFocus,
                child: CustomTextField(
                  controller: passwordController,
                  label: 'Password',
                  obscureText: obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: onToggleObscure,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Password required';
                    if (value.length < 6) return 'Minimum 6 characters';
                    return null;
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            _FadeSlideIn(
              animation: stagger(0.45, 0.95),
              child: _TakeoffButton(
                isLoading: isLoading,
                onPressed: onLogin,
              ),
            ),
            const SizedBox(height: 16),
            _FadeSlideIn(
              animation: stagger(0.55, 1.0),
              child: TextButton(
                onPressed: onRegisterTap,
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
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
          fit: StackFit.expand,
          children: [
            // Full-bleed background photo. Sits at the very bottom of the
            // stack so it never overlaps/competes with the form — the
            // form is always painted on top of it, not beside or into it.
            Image.asset(
              _kLoginBgAssetPath,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (context, error, stackTrace) {
                return const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [_kNavy, _kSurface],
                    ),
                  ),
                );
              },
            ),
            // Light scrim, just enough to keep the photo from looking
            // washed-out white behind light UI chrome — the card itself
            // (not this layer) is what keeps the form readable now.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x33050A14), // ~20% navy
                    Color(0x40050A14), // ~25% navy
                    Color(0x59050A14), // ~35% navy
                  ],
                  stops: [0.0, 0.55, 1.0],
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
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 12),
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
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              ),
              items: roles.map((role) {
                return DropdownMenuItem<String>(
                  value: role.label,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(role.icon, size: 18, color: _kTeal),
                      const SizedBox(width: 10),
                      Text(role.label),
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
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: widget.isLoading
                  ? [_kTeal.withValues(alpha: 0.5), const Color(0xFF0D3894).withValues(alpha: 0.5)]
                  : const [_kTeal, Color(0xFF0D3894)],
            ),
            boxShadow: [
              BoxShadow(color: _kTeal.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: widget.isLoading
              ? const SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
          )
              : const Text(
            'LOGIN',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}