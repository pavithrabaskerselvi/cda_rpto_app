// lib/screens/auth/pending_approval_screen.dart
//
// Shown instead of the Dashboard when the signed-in user's access is not
// yet approved. Two states:
//   - pending  : first login, admin hasn't acted yet
//   - rejected : admin explicitly denied/revoked access
//
// The only way out is Sign Out — there's no "skip" button on purpose.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../providers/role_provider.dart';

// Cropped from the app's own splash artwork (drone over the city skyline)
// so this screen's hero reads as the same brand, not a stock photo bolted
// on. Must match EXACTLY what's registered under `flutter: assets:` in
// pubspec.yaml.
const _kHeroAssetPath = 'lib/assets/images/pending_approval_hero.png';

class PendingApprovalScreen extends StatefulWidget {
  final bool rejected;
  const PendingApprovalScreen({super.key, this.rejected = false});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen>
    with SingleTickerProviderStateMixin {
  bool _isRefreshing = false;

  late final AnimationController _entranceCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  late final Animation<double> _fade = CurvedAnimation(
    parent: _entranceCtrl,
    curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic),
  );

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.04),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic));

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _isRefreshing = true);
    try {
      await context.read<RoleProvider>().loadFromFirebaseUser(user);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _signOut() async {
    context.read<RoleProvider>().clear();
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final rejected = widget.rejected;
    final statusColor = rejected ? AppColors.coral : AppColors.amber;
    final title = rejected ? 'Access denied' : 'Waiting for approval';
    final message = rejected
        ? 'Your access request was declined by the admin. Contact the RPTO office if you think this is a mistake.'
        : 'Your account is set up. An admin needs to approve your access before you can open the app — you\'ll be able to log in normally right after that.';
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _StatusCard(
                        rejected: rejected,
                        statusColor: statusColor,
                        title: title,
                        message: message,
                        email: email,
                      ),
                      const SizedBox(height: 20),
                      if (!rejected)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _isRefreshing ? null : _refresh,
                            icon: _isRefreshing
                                ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                                : const Icon(Icons.refresh_rounded, size: 18),
                            label: Text(_isRefreshing ? 'Checking…' : 'Check again'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.teal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: _signOut,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        ),
                        child: const Text(
                          'Sign out',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The card itself — hero image, overlapping status medallion, copy, and
/// (for the pending state only) the three-step progress tracker.
class _StatusCard extends StatelessWidget {
  final bool rejected;
  final Color statusColor;
  final String title;
  final String message;
  final String email;

  const _StatusCard({
    required this.rejected,
    required this.statusColor,
    required this.title,
    required this.message,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: statusColor.withValues(alpha: 0.10),
            blurRadius: 40,
            spreadRadius: -6,
          ),
        ],
      ),
      clipBehavior: Clip.none,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- Hero: drone-over-skyline image, fading into the card ----
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                child: Image.asset(
                  _kHeroAssetPath,
                  height: 148,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 148,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.navy, AppColors.surface],
                      ),
                    ),
                  ),
                ),
              ),
              // Gradient fade so the photo blends into the card's surface
              // color instead of ending on a hard edge.
              Container(
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.surface.withValues(alpha: 0.0),
                      AppColors.surface,
                    ],
                  ),
                ),
              ),
              // Status medallion, overlapping the hero/body seam.
              Positioned(
                bottom: -30,
                child: _StatusMedallion(rejected: rejected, color: statusColor),
              ),
            ],
          ),
          const SizedBox(height: 42),

          // ---- Status pill ----
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: statusColor.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    rejected ? 'Access denied' : 'Pending review',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26),
            child: Column(
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13.5,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),

          if (!rejected) ...[
            const SizedBox(height: 26),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 26),
              child: _ProgressTracker(),
            ),
          ],

          const SizedBox(height: 22),
          if (email.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.mail_outline_rounded, size: 16, color: AppColors.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Signed in as $email',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 22),
        ],
      ),
    );
  }
}

/// The circular badge that overlaps the hero image / card body seam.
class _StatusMedallion extends StatelessWidget {
  final bool rejected;
  final Color color;
  const _StatusMedallion({required this.rejected, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: rejected
            ? Icon(Icons.block_rounded, color: color, size: 28)
            : _PulsingIcon(color: color),
      ),
    );
  }
}

/// A gently breathing hourglass icon — the one deliberate motion moment on
/// this screen, signaling "still waiting" without being distracting.
class _PulsingIcon extends StatefulWidget {
  final Color color;
  const _PulsingIcon({required this.color});

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final scale = 1.0 + (_ctrl.value * 0.12);
        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: 0.75 + (_ctrl.value * 0.25),
            child: child,
          ),
        );
      },
      child: Icon(Icons.hourglass_top_rounded, color: widget.color, size: 28),
    );
  }
}

/// Registered → Under review → Approved. A genuine sequence, so a
/// numbered/step tracker earns its place here (unlike a decorative one).
class _ProgressTracker extends StatelessWidget {
  const _ProgressTracker();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildStep(label: 'Registered', filled: true, current: false),
        _buildConnector(filled: true),
        _buildStep(label: 'Under review', filled: true, current: true),
        _buildConnector(filled: false),
        _buildStep(label: 'Approved', filled: false, current: false),
      ],
    );
  }

  Widget _buildStep({required String label, required bool filled, required bool current}) {
    final color = filled ? AppColors.teal : AppColors.textMuted;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? AppColors.teal : Colors.transparent,
            border: Border.all(color: color, width: 1.6),
          ),
          child: current
              ? Center(
            child: Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            ),
          )
              : null,
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: filled ? AppColors.textSecondary : AppColors.textMuted,
            fontSize: 10.5,
            fontWeight: current ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildConnector({required bool filled}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          height: 1.6,
          color: filled ? AppColors.teal.withValues(alpha: 0.5) : AppColors.border,
        ),
      ),
    );
  }
}