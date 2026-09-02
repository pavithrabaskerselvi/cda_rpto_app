import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

// ---------------------------------------------------------------------
// BRIGHT / PREMIUM palette -- kept in sync with login_screen.dart so
// both auth screens read as one continuous experience. Local to these
// two screens only; the rest of the app stays on AppColors (dark navy).
// ---------------------------------------------------------------------
const _kAccent = Color(0xFF185FA5);
const _kAccentDark = Color(0xFF0C447C);
const _kAccentSoft = Color(0xFFE6F1FB);
const _kCard = Colors.white;
const _kTextDark = Color(0xFF0B2540);
const _kTextMuted = Color(0xFF6B7A90);
const _kError = Color(0xFFD64545);
const _kBgFallback = Color(0xFFDDEEFC);
const _kFieldBorder = Color(0xFFE2E8F0);

// Same background photo used on login_screen.dart. Must match EXACTLY
// what's registered under `flutter: assets:` in pubspec.yaml.
const _kBgAssetPath = 'lib/assets/images/login_page.png';

// Raw branch values stored in Firestore ('users/{uid}.branch') stay
// 'Branch 1' / 'Branch 2' -- this is what the reports module's
// normalizeBranch()/filterByBranch() logic expects. Only the label shown
// to the user changes here.
const Map<String, String> _kBranchLabels = {
  'Branch 1': 'CDA Admin',
  'Branch 2': 'CDA Ops',
};

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  // 'Admin' is intentionally NOT an option here. There is exactly one
  // admin account (info@chennaidroneacademy.com — see app_admin.dart),
  // provisioned directly, not self-registered. Letting anyone pick
  // "Admin" on this screen was the actual hole that let other email
  // addresses get treated as admin in the app.
  String _selectedRole = 'instructor';
  final List<Map<String, dynamic>> _roles = [
    {'value': 'instructor', 'label': 'Instructor', 'icon': Icons.badge_outlined},
    {'value': 'student', 'label': 'Student', 'icon': Icons.school_outlined},
  ];

  String? _selectedBranch;
  final List<String> _branches = ['Branch 1', 'Branch 2'];

  bool _obscurePassword = true;
  bool _isLoading = false;

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

  // Both remaining self-registration roles (instructor, student) need
  // a branch. Kept as a getter (rather than inlining `true`) in case a
  // role that doesn't need a branch is ever added back.
  bool get _requiresBranch => true;

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(() => setState(() {}));
    _emailFocus.addListener(() => setState(() {}));
    _passwordFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _kError,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
      ),
    );
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (_requiresBranch && _selectedBranch == null) {
      _showSnack('Please select a branch');
      return;
    }

    setState(() => _isLoading = true);

    final error = await AuthService.register(
      name: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
      role: _selectedRole,
    );

    if (!mounted) return;

    if (error != null) {
      setState(() => _isLoading = false);
      _showSnack(error);
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && _requiresBranch) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'branch': _selectedBranch,
      });
    }

    // Firebase signs the newly-created account in automatically. If we
    // leave them signed in here, the root AuthGate (in main.dart) reacts
    // to that auth-state change immediately and routes straight to the
    // Pending Approval screen, skipping Login entirely. Sign back out so
    // AuthGate falls back to LoginScreen, and the user lands on Pending
    // Approval only after they explicitly log in.
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;
    setState(() => _isLoading = false);
    // Return `true` so LoginScreen knows to show a success message.
    Navigator.pop(context, true);
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
      extendBodyBehindAppBar: true,
      // MUST be true (the default). This lets the body height shrink
      // when the keyboard opens so the bands below recalculate and the
      // card moves up above the keyboard instead of getting covered.
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: _kAccentDark),
      ),
      // ---------------------------------------------------------------
      // Proportional-band + FittedBox(scaleDown) approach, matching
      // login_screen.dart. topFlex collapses when the keyboard is open
      // so the card slides up above it instead of getting covered.
      // ---------------------------------------------------------------
      body: Stack(
        children: [
          const _PhotoBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Base ratio (keyboard closed) is 32/68 -- the register
                // card has more fields than the login card, so it gets a
                // bigger band to render closer to its natural 1.0 scale.
                // When the keyboard opens, topFlex collapses to 6 so the
                // (taller) card gets maximum room to scale into above the
                // keyboard instead of being covered by it.
                final topFlex = keyboardOpen ? 6 : 32;
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
                            alignment: Alignment.topCenter,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.topCenter,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 380),
                                child: _RegisterCard(
                                  formKey: _formKey,
                                  stagger: _stagger,
                                  nameController: _nameController,
                                  emailController: _emailController,
                                  passwordController: _passwordController,
                                  nameFocus: _nameFocus,
                                  emailFocus: _emailFocus,
                                  passwordFocus: _passwordFocus,
                                  obscurePassword: _obscurePassword,
                                  onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
                                  roles: _roles,
                                  selectedRole: _selectedRole,
                                  onRoleChanged: (value) => setState(() {
                                    _selectedRole = value;
                                    if (!_requiresBranch) _selectedBranch = null;
                                  }),
                                  requiresBranch: _requiresBranch,
                                  branches: _branches,
                                  selectedBranch: _selectedBranch,
                                  onBranchChanged: (val) => setState(() => _selectedBranch = val),
                                  isLoading: _isLoading,
                                  onRegister: _handleRegister,
                                  onLoginTap: () => Navigator.pop(context),
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

/// The premium white register card -- sized/laid out identically in
/// spirit to _LoginCard in login_screen.dart (Container + rounded
/// corners + Form, no internal scrolling, no bottom-sheet framing) so
/// both cards get scaled to the same band by the parent FittedBox.
class _RegisterCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final Animation<double> Function(double, double) stagger;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final FocusNode nameFocus;
  final FocusNode emailFocus;
  final FocusNode passwordFocus;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
  final List<Map<String, dynamic>> roles;
  final String selectedRole;
  final ValueChanged<String> onRoleChanged;
  final bool requiresBranch;
  final List<String> branches;
  final String? selectedBranch;
  final ValueChanged<String?> onBranchChanged;
  final bool isLoading;
  final VoidCallback onRegister;
  final VoidCallback onLoginTap;

  const _RegisterCard({
    required this.formKey,
    required this.stagger,
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.nameFocus,
    required this.emailFocus,
    required this.passwordFocus,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.roles,
    required this.selectedRole,
    required this.onRoleChanged,
    required this.requiresBranch,
    required this.branches,
    required this.selectedBranch,
    required this.onBranchChanged,
    required this.isLoading,
    required this.onRegister,
    required this.onLoginTap,
  });

  Widget _sectionLabel(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: _kAccentDark),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kTextDark),
        ),
      ],
    );
  }

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
            // ---------- Header ----------
            _FadeSlideIn(
              animation: stagger(0.0, 0.5),
              child: const Text(
                'Join CDA RPTO',
                style: TextStyle(color: _kTextDark, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 2),
            _FadeSlideIn(
              animation: stagger(0.05, 0.55),
              child: const Text(
                'Set up your training account in a few steps',
                style: TextStyle(color: _kTextMuted, fontSize: 11),
              ),
            ),
            const SizedBox(height: 12),

            // ---------- Section: Personal details ----------
            _FadeSlideIn(
              animation: stagger(0.1, 0.58),
              child: _sectionLabel(Icons.person_outline_rounded, 'Personal details'),
            ),
            const SizedBox(height: 6),
            _FadeSlideIn(
              animation: stagger(0.14, 0.6),
              child: _BrightField(
                focusNode: nameFocus,
                controller: nameController,
                label: 'Full name',
                hint: 'Enter your full name',
                icon: Icons.person_outline_rounded,
                validator: (value) => (value == null || value.isEmpty) ? 'Name required' : null,
              ),
            ),
            const SizedBox(height: 8),
            _FadeSlideIn(
              animation: stagger(0.18, 0.63),
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
            const Divider(color: _kFieldBorder, height: 1),
            const SizedBox(height: 10),

            // ---------- Section: Security ----------
            _FadeSlideIn(
              animation: stagger(0.22, 0.66),
              child: _sectionLabel(Icons.lock_outline_rounded, 'Security'),
            ),
            const SizedBox(height: 6),
            _FadeSlideIn(
              animation: stagger(0.26, 0.68),
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
            const SizedBox(height: 3),
            _FadeSlideIn(
              animation: stagger(0.28, 0.7),
              child: const Text(
                'Use at least 6 characters',
                style: TextStyle(fontSize: 9.5, color: _kTextMuted),
              ),
            ),
            const SizedBox(height: 10),
            const Divider(color: _kFieldBorder, height: 1),
            const SizedBox(height: 10),

            // ---------- Section: Role ----------
            _FadeSlideIn(
              animation: stagger(0.3, 0.73),
              child: _sectionLabel(Icons.badge_outlined, 'Your role'),
            ),
            const SizedBox(height: 6),
            _FadeSlideIn(
              animation: stagger(0.33, 0.76),
              child: Row(
                children: roles.map((role) {
                  final isSelected = selectedRole == role['value'];
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onRoleChanged(role['value'] as String),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? _kAccentSoft : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? _kAccent : _kFieldBorder,
                            width: isSelected ? 1.4 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              role['icon'],
                              color: isSelected ? _kAccentDark : _kTextMuted,
                              size: 17,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              role['label'],
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? _kAccentDark : _kTextMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // ---------- Section: Branch (instructor / student only) ----------
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: requiresBranch
                  ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  _FadeSlideIn(
                    animation: stagger(0.36, 0.8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Branch',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _kTextMuted),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: _kAccentSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: selectedBranch,
                              hint: const Text('Select branch', style: TextStyle(color: _kTextMuted, fontSize: 12)),
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _kAccent, size: 20),
                              dropdownColor: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              style: const TextStyle(color: _kTextDark, fontSize: 13, fontWeight: FontWeight.w600),
                              items: branches.map((branch) {
                                return DropdownMenuItem<String>(
                                  value: branch, // raw value stays 'Branch 1' / 'Branch 2'
                                  child: Row(
                                    children: [
                                      const Icon(Icons.apartment_rounded, size: 16, color: _kAccentDark),
                                      const SizedBox(width: 8),
                                      Text(_kBranchLabels[branch] ?? branch),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: onBranchChanged,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
                  : const SizedBox(width: double.infinity),
            ),
            const SizedBox(height: 12),

            _FadeSlideIn(
              animation: stagger(0.4, 0.85),
              child: _CreateAccountButton(isLoading: isLoading, onPressed: onRegister),
            ),
            const SizedBox(height: 6),

            _FadeSlideIn(
              animation: stagger(0.45, 0.9),
              child: Center(
                child: TextButton(
                  onPressed: onLoginTap,
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(color: _kTextMuted, fontSize: 13),
                      children: [
                        TextSpan(text: 'Already have an account?  '),
                        TextSpan(text: 'Login', style: TextStyle(color: _kAccent, fontWeight: FontWeight.w700)),
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

/// ---------------------------------------------------------------------
/// Same bright sky/drone/tower photo as login_screen.dart, so both auth
/// screens feel like one continuous experience. Only a light bottom wash
/// (not a full navy scrim) since the card sits on solid white now.
/// ---------------------------------------------------------------------
class _PhotoBackground extends StatelessWidget {
  const _PhotoBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          _kBgAssetPath,
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

/// ---------------------------------------------------------------------
/// Fade + slide-up wrapper driven by an outer stagger animation.
/// ---------------------------------------------------------------------
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

/// ---------------------------------------------------------------------
/// Bright, pill-filled text field with a leading icon -- same look as
/// login_screen.dart's field, duplicated locally since it's a private
/// widget there.
/// ---------------------------------------------------------------------
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

/// ---------------------------------------------------------------------
/// Primary CTA -- solid blue fill, press-scale feedback, spinner swap.
/// Matches _LoginButton in login_screen.dart.
/// ---------------------------------------------------------------------
class _CreateAccountButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _CreateAccountButton({required this.isLoading, required this.onPressed});

  @override
  State<_CreateAccountButton> createState() => _CreateAccountButtonState();
}

class _CreateAccountButtonState extends State<_CreateAccountButton> {
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
          height: 40,
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
              Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 16),
              SizedBox(width: 6),
              Text(
                'Create account',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}