import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_text_field.dart';

// NOTE: If your project's `lib/config/constants.dart` already defines
// kNavy / kTeal / kSurface, delete these locals and import that file
// instead so this screen shares the exact tokens as login_screen.dart.
const _kNavy = Color(0xFF050A14);
const _kSurface = Color(0xFF0F1B2E);
const _kTeal = Color(0xFF14B8A6);

// Raw branch values stored in Firestore ('users/{uid}.branch') stay
// 'Branch 1' / 'Branch 2' — this is what the reports module's
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

  String _selectedRole = 'admin';
  final List<Map<String, dynamic>> _roles = [
    {'value': 'admin', 'label': 'Admin', 'icon': Icons.shield_outlined},
    {'value': 'instructor', 'label': 'Instructor', 'icon': Icons.badge_outlined},
    {'value': 'student', 'label': 'Student', 'icon': Icons.school_outlined},
  ];

  String? _selectedBranch;
  final List<String> _branches = ['Branch 1', 'Branch 2'];

  bool _obscurePassword = true;
  bool _isLoading = false;

  late final AnimationController _entranceCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
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

  bool get _requiresBranch => _selectedRole != 'admin';

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
    _ambientCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.coral,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
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

    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kNavy,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          _AmbientBackground(controller: _ambientCtrl),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 90, 24, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ---------- Header ----------
                    _FadeSlideIn(
                      animation: _stagger(0.0, 0.5),
                      child: Center(
                        child: Container(
                          width: 76,
                          height: 76,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [_kTeal, Color(0xFF0D9488)],
                            ),
                            boxShadow: [
                              BoxShadow(color: _kTeal.withValues(alpha: 0.4), blurRadius: 26, spreadRadius: 1),
                            ],
                          ),
                          child: const Icon(Icons.person_add_alt_1_rounded, size: 32, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _FadeSlideIn(
                      animation: _stagger(0.05, 0.55),
                      child: const Center(
                        child: Text(
                          'JOIN CDA RPTO',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _FadeSlideIn(
                      animation: _stagger(0.08, 0.58),
                      child: const Center(
                        child: Text(
                          'Set up your training account in a few steps',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ---------- Section: Personal details ----------
                    _FadeSlideIn(
                      animation: _stagger(0.12, 0.6),
                      child: _sectionLabel(Icons.person_outline_rounded, 'Personal details'),
                    ),
                    const SizedBox(height: 12),
                    _FadeSlideIn(
                      animation: _stagger(0.15, 0.62),
                      child: _GlowField(
                        focusNode: _nameFocus,
                        child: CustomTextField(
                          controller: _nameController,
                          label: 'Full Name',
                          validator: (value) => (value == null || value.isEmpty) ? 'Name required' : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _FadeSlideIn(
                      animation: _stagger(0.18, 0.65),
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
                    const SizedBox(height: 28),
                    Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                    const SizedBox(height: 24),

                    // ---------- Section: Security ----------
                    _FadeSlideIn(
                      animation: _stagger(0.22, 0.68),
                      child: _sectionLabel(Icons.lock_outline_rounded, 'Security'),
                    ),
                    const SizedBox(height: 12),
                    _FadeSlideIn(
                      animation: _stagger(0.25, 0.7),
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
                    const SizedBox(height: 6),
                    _FadeSlideIn(
                      animation: _stagger(0.27, 0.72),
                      child: const Text(
                        'Use at least 6 characters',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                    const SizedBox(height: 24),

                    // ---------- Section: Role ----------
                    _FadeSlideIn(
                      animation: _stagger(0.3, 0.75),
                      child: _sectionLabel(Icons.badge_outlined, 'Your role'),
                    ),
                    const SizedBox(height: 12),
                    _FadeSlideIn(
                      animation: _stagger(0.33, 0.78),
                      child: Row(
                        children: _roles.map((role) {
                          final isSelected = _selectedRole == role['value'];
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _selectedRole = role['value'];
                                if (!_requiresBranch) _selectedBranch = null;
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOut,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: isSelected ? _kTeal.withValues(alpha: 0.12) : _kSurface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected ? _kTeal : Colors.white.withValues(alpha: 0.08),
                                    width: isSelected ? 1.6 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [BoxShadow(color: _kTeal.withValues(alpha: 0.25), blurRadius: 14, offset: const Offset(0, 4))]
                                      : [],
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      role['icon'],
                                      color: isSelected ? _kTeal : AppColors.textSecondary,
                                      size: 24,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      role['label'],
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected ? Colors.white : AppColors.textSecondary,
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
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOut,
                      alignment: Alignment.topCenter,
                      child: _requiresBranch
                          ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 20),
                          _FadeSlideIn(
                            animation: _stagger(0.36, 0.8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'BRANCH',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.6,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  decoration: BoxDecoration(
                                    color: _kSurface,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      isExpanded: true,
                                      value: _selectedBranch,
                                      hint: const Text('Select branch', style: TextStyle(color: AppColors.textSecondary)),
                                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _kTeal),
                                      dropdownColor: _kSurface,
                                      borderRadius: BorderRadius.circular(14),
                                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                                      items: _branches.map((branch) {
                                        return DropdownMenuItem<String>(
                                          value: branch, // raw value stays 'Branch 1' / 'Branch 2'
                                          child: Row(
                                            children: [
                                              const Icon(Icons.apartment_rounded, size: 16, color: _kTeal),
                                              const SizedBox(width: 8),
                                              Text(_kBranchLabels[branch] ?? branch),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) => setState(() => _selectedBranch = val),
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
                    const SizedBox(height: 32),

                    _FadeSlideIn(
                      animation: _stagger(0.4, 0.85),
                      child: _CreateAccountButton(isLoading: _isLoading, onPressed: _handleRegister),
                    ),
                    const SizedBox(height: 14),

                    _FadeSlideIn(
                      animation: _stagger(0.45, 0.9),
                      child: Center(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: RichText(
                            text: const TextSpan(
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
                              children: [
                                TextSpan(text: 'Already have an account?  '),
                                TextSpan(text: 'Login', style: TextStyle(color: _kTeal, fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                        ),
                      ),
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

  Widget _sectionLabel(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _kTeal),
        const SizedBox(width: 8),
        Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// Deep-navy background with slow-breathing teal glow, matching login_screen.dart.
/// ---------------------------------------------------------------------------
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
              left: -100,
              child: _glow(_kTeal.withValues(alpha: 0.14), 300),
            ),
            Positioned(
              bottom: -160 - (t * 20),
              right: -120,
              child: _glow(_kTeal.withValues(alpha: 0.08), 320),
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

/// ---------------------------------------------------------------------------
/// Fade + slide-up wrapper driven by an outer stagger animation.
/// ---------------------------------------------------------------------------
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

/// ---------------------------------------------------------------------------
/// Wraps a CustomTextField with an animated glowing teal border on focus.
/// ---------------------------------------------------------------------------
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

/// ---------------------------------------------------------------------------
/// Primary CTA with gradient fill, press-scale feedback, and a spinner swap.
/// ---------------------------------------------------------------------------
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
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: widget.isLoading
                  ? [_kTeal.withValues(alpha: 0.5), const Color(0xFF0D9488).withValues(alpha: 0.5)]
                  : const [_kTeal, Color(0xFF0D9488)],
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
            'CREATE ACCOUNT',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}