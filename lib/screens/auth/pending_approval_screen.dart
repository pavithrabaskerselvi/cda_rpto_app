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

class PendingApprovalScreen extends StatelessWidget {
  final bool rejected;
  const PendingApprovalScreen({super.key, this.rejected = false});

  Future<void> _refresh(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await context.read<RoleProvider>().loadFromFirebaseUser(user);
  }

  Future<void> _signOut(BuildContext context) async {
    context.read<RoleProvider>().clear();
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final color = rejected ? AppColors.coral : AppColors.amber;
    final title = rejected ? 'Access Denied' : 'Waiting for Approval';
    final message = rejected
        ? 'Your access request was declined by the admin.\nContact the RPTO office if you think this is a mistake.'
        : 'Your account is created, but an admin needs to approve\nyour access before you can use the app.\n\nYou\'ll be able to log in normally once approved.';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    rejected ? Icons.block_rounded : Icons.hourglass_top_rounded,
                    color: color,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 32),
                if (!rejected)
                  OutlinedButton.icon(
                    onPressed: () => _refresh(context),
                    icon: const Icon(Icons.refresh_rounded, color: AppColors.teal),
                    label: const Text('Check again', style: TextStyle(color: AppColors.teal)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.teal),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => _signOut(context),
                  child: const Text('Sign out', style: TextStyle(color: AppColors.textSecondary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
