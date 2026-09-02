import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'register_screen.dart';

// ---------------------------------------------------------------------
// BRIGHT / PREMIUM palette for this screen only. Kept local (not pulled
// from AppColors in config/theme.dart) because AppColors is the app's
// dark-navy system used everywhere else -- this screen intentionally
// breaks from it to match the bright sky/drone/tower background photo.
// ---------------------------------------------------------------------
const _kAccent = Color(0xFF185FA5); // primary blue (buttons, links, focus)
const _kAccentDark = Color(0xFF0C447C); // deep navy-blue (headings, icons)
const _kAccentSoft = Color(0xFFE6F1FB); // pale blue fill (field bg, chips)
const _kCard = Colors.white;
const _kTextDark = Color(0xFF0B2540);
const _kTextMuted = Color(0xFF6B7A90);
const _kSuccess = Color(0xFF1F9D5A);
const _kError = Color(0xFFD64545);
const _kBgFallback = Color(0xFFDDEEFC);

// Path to the login background photo. Must match EXACTLY what's
// registered under `flutter: assets:` in pubspec.yaml. Drop the new
// sky/drone/CDA-RPTO-tower photo in at this path (replacing the old
// dark one) -- it already carries the header/logo/title, so the card
// below only needs the form itself.
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
  bool _rememberMe = true;

  String _selectedRole = 'Admin';
  final List<_RoleOption> _roles = const [
    _RoleOption('Admin', Icons.shield_moon_rounded),
    _RoleOption('Instructor', Icons.flight_class_rounded),
    _RoleOption('Student', Icons.school_rounded),
  ];

  late final AnimationController _entranceCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

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

    // Stored role is always lowercase (see AuthService.register), so
    // compare case-insensitively against the capitalized labels used by
    // the role picker on this screen.
    final actualRole = (userDoc.data()?['role'] as String? ?? '').trim();

    if (actualRole.toLowerCase() != _selectedRole.toLowerCase()) {
      setState(() => _isLoading = false);
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      _showSnack('Role mismatch: your account is registered as "$actualRole".', isError: true);
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
    // Login is done here — AuthGate (main.dart) picks up the
    // authStateChanges event that just fired, loads this user's access
    // record, and routes to Dashboard / PendingApprovalScreen depending
    // on their accessStatus. Nothing else to do on this screen.
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showSnack('Enter your email above first, then tap "Forgot password?"', isError: true);
      return;
    }

    final error = await AuthService.sendPasswordResetEmail(email);
    if (!mounted) return;

    if (error != null) {
      _showSnack(error, isError: true);
    } else {
      _showSnack('Password reset link sent to $email');
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? _kError : _kSuccess,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Keyboard visibility: when it's open we shrink the top spacer band
    // so the card gets pushed up into the visible area above the
    // keyboard, instead of staying pinned at its normal position and
    // getting covered by the keyboard.
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: _kBgFallback,
      // MUST be true (the default). This lets the Scaffold's body height
      // actually shrink when the keyboard opens, which is what makes the
      // FittedBox(scaleDown) + proportional bands below recalculate and
      // keep the fields visible above the keyboard instead of hidden
      // behind it.
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const _PhotoBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Reserve the screen as PROPORTIONAL bands that mirror the
                // photo's own composition, instead of a fixed pixel offset.
                //
                // topFlex fixes exactly where the card's TOP edge sits
                // (as a % of available height) when the keyboard is
                // closed. The remaining space below is one single
                // Expanded band holding the card top-aligned, so making
                // the card taller only extends it further DOWN into what
                // used to be empty bottom space -- it can never push
                // upward past topFlex.
                //
                // When the keyboard is open, topFlex collapses way down
                // (46 -> 6) so the card slides up near the top of the
                // now-shrunk viewport instead of staying at its normal
                // resting position and getting covered by the keyboard.
                // remainderFlex grows to match, giving FittedBox as much
                // room as possible to render the card above the keyboard.
                final topFlex = keyboardOpen ? 6 : 46;
                final remainderFlex = 100 - topFlex;

                return SizedBox(
                  height: constraints.maxHeight,
                  child: Column(
                    children: [
                      Expanded(flex: topFlex, child: const SizedBox.shrink()),
                      Expanded(
                        flex: remainderFlex,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                          child: Align(
                            // topCenter (not Center) is what pins the card's
                            // top edge in place.
                            alignment: Alignment.topCenter,
                            // No scrolling on this screen: FittedBox scales
                            // the card down to fit the remaining band on
                            // short screens (or whenever the keyboard has
                            // eaten into the available height) instead of
                            // scrolling or overflowing. Scale never exceeds
                            // 1.0 because BoxFit.scaleDown never enlarges.
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.topCenter,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 360),
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
                                  rememberMe: _rememberMe,
                                  onRememberChanged: (v) => setState(() => _rememberMe = v),
                                  onForgotPassword: _handleForgotPassword,
                                  isLoading: _isLoading,
                                  onLogin: _handleLogin,
                                  stagger: _stagger,
                                  onRegisterTap: () async {
                                    final registered = await Navigator.push<bool>(
                                      context,
                                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                                    );
                                    if (registered == true && mounted) {
                                      _showSnack('Registration successful! Please log in to continue.');
                                    }
                                  },
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

/// Full-bleed background photo with just enough of a soft white wash at
/// the very bottom to keep the card's drop shadow and the helipad ground
/// from competing for attention -- the photo itself stays bright.
class _PhotoBackground extends StatelessWidget {
  const _PhotoBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
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
                  colors: [_kBgFallback, _kAccentSoft],
                ),
              ),
            );
          },
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x00FFFFFF),
                Color(0x1AFFFFFF),
                Color(0x40FFFFFF),
              ],
              stops: [0.5, 0.75, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

/// The premium white login card -- pulled out to its own widget purely so
/// the proportional-band layout above stays readable.
///
/// UPDATED: removed the "or continue with" divider + Google/Microsoft
/// social sign-in row entirely (those providers weren't wired up to
/// anything yet). The card now goes straight from the Login button to
/// the "Don't have an account? Register" link.
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
  final bool rememberMe;
  final ValueChanged<bool> onRememberChanged;
  final VoidCallback onForgotPassword;
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
    required this.rememberMe,
    required this.onRememberChanged,
    required this.onForgotPassword,
    required this.isLoading,
    required this.onLogin,
    required this.stagger,
    required this.onRegisterTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FadeSlideIn(
              animation: stagger(0.1, 0.6),
              child: const Text(
                'Welcome back',
                style: TextStyle(color: _kTextDark, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 2),
            _FadeSlideIn(
              animation: stagger(0.12, 0.62),
              child: const Text(
                'Login to continue your journey',
                style: TextStyle(color: _kTextMuted, fontSize: 11),
              ),
            ),
            const SizedBox(height: 14),
            _FadeSlideIn(
              animation: stagger(0.2, 0.7),
              child: _RoleDropdown(
                roles: roles,
                selected: selectedRole,
                onChanged: onRoleChanged,
              ),
            ),
            const SizedBox(height: 10),
            _FadeSlideIn(
              animation: stagger(0.3, 0.8),
              child: _BrightField(
                focusNode: emailFocus,
                controller: emailController,
                label: 'Email',
                hint: 'Enter your email',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Email required';
                  if (!value.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
            ),
            const SizedBox(height: 10),
            _FadeSlideIn(
              animation: stagger(0.35, 0.85),
              child: _BrightField(
                focusNode: passwordFocus,
                controller: passwordController,
                label: 'Password',
                hint: 'Enter your password',
                icon: Icons.lock_outline_rounded,
                obscureText: obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: _kTextMuted,
                    size: 20,
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
            const SizedBox(height: 6),
            _FadeSlideIn(
              animation: stagger(0.4, 0.9),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () => onRememberChanged(!rememberMe),
                    borderRadius: BorderRadius.circular(6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Checkbox(
                            value: rememberMe,
                            onChanged: (v) => onRememberChanged(v ?? true),
                            activeColor: _kAccent,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Remember me', style: TextStyle(color: _kTextMuted, fontSize: 13)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: onForgotPassword,
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(color: _kAccent, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _FadeSlideIn(
              animation: stagger(0.5, 0.95),
              child: _LoginButton(isLoading: isLoading, onPressed: onLogin),
            ),
            const SizedBox(height: 14),
            _FadeSlideIn(
              animation: stagger(0.6, 1.0),
              child: Center(
                child: TextButton(
                  onPressed: onRegisterTap,
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(color: _kTextMuted, fontSize: 13),
                      children: [
                        TextSpan(text: "Don't have an account?  "),
                        TextSpan(
                          text: 'Register',
                          style: TextStyle(color: _kAccent, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
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
          'Login as',
          style: TextStyle(color: _kTextMuted, fontSize: 11, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: _kAccentSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<String>(
              initialValue: selected,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _kAccent, size: 20),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(12),
              style: const TextStyle(color: _kTextDark, fontSize: 13, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: roles.map((role) {
                return DropdownMenuItem<String>(
                  value: role.label,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(role.icon, size: 16, color: _kAccentDark),
                      const SizedBox(width: 8),
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

/// Bright, pill-filled text field with a leading icon -- matches the
/// login card's light aesthetic. Kept local to this screen rather than
/// reusing the app-wide CustomTextField, which is styled for the app's
/// dark InputDecorationTheme.
class _BrightField extends StatelessWidget {
  final FocusNode focusNode;
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType keyboardType;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  const _BrightField({
    required this.focusNode,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.suffixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final isFocused = focusNode.hasFocus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _kTextMuted, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: _kAccentSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isFocused ? _kAccent : Colors.transparent, width: 1.2),
          ),
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            obscureText: obscureText,
            keyboardType: keyboardType,
            validator: validator,
            style: const TextStyle(color: _kTextDark, fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: _kTextMuted, fontSize: 12),
              prefixIcon: Icon(icon, size: 18, color: _kAccentDark),
              suffixIcon: suffixIcon,
              filled: false,
              border: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              errorStyle: const TextStyle(color: _kError, fontSize: 10.5),
            ),
          ),
        ),
      ],
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
            offset: Offset(0, (1 - animation.value) * 16),
            child: child,
          ),
        );
      },
    );
  }
}

class _LoginButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _LoginButton({required this.isLoading, required this.onPressed});

  @override
  State<_LoginButton> createState() => _LoginButtonState();
}

class _LoginButtonState extends State<_LoginButton> {
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
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: widget.isLoading ? _kAccent.withValues(alpha: 0.6) : _kAccent,
            boxShadow: [
              BoxShadow(color: _kAccent.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 6)),
            ],
          ),
          child: widget.isLoading
              ? const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
          )
              : const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.login_rounded, color: Colors.white, size: 16),
              SizedBox(width: 6),
              Text(
                'Login',
                style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}