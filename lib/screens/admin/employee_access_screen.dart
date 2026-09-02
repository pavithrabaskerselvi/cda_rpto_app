// lib/screens/admin/employee_access_screen.dart
//
// Admin screen listing every instructor/student account with controls to
// grant viewer/editor access, reject/revoke access, or delete the profile.
// Styled to match RPTO Vault / Company Details: Plus Jakarta Sans font
// and the CompanyColors light/dark palette.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../config/theme_colors.dart';
import '../../providers/theme_provider.dart';
import '../../models/user_role_model.dart';
import '../../services/access_control_service.dart';

class EmployeeAccessScreen extends StatelessWidget {
  const EmployeeAccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final c = CompanyColors.of(isDark);
    final jakartaTheme = GoogleFonts.plusJakartaSansTextTheme(Theme.of(context).textTheme);
    final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: jakartaTheme,
        primaryTextTheme: jakartaTheme,
      ),
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          title: Text(
            'Instructor Access',
            style: GoogleFonts.plusJakartaSans(
              color: c.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          backgroundColor: c.background,
          elevation: 0,
          iconTheme: IconThemeData(color: c.textPrimary),
        ),
        body: StreamBuilder<List<AppUserAccess>>(
          stream: AccessControlService.watchManagedUsers(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(color: c.accent),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Failed to load users.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(color: c.textSecondary),
                ),
              );
            }

            final users = snapshot.data ?? const <AppUserAccess>[];
            if (users.isEmpty) {
              return Center(
                child: Text(
                  'No instructor accounts yet.',
                  style: GoogleFonts.plusJakartaSans(color: c.textSecondary),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: users.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return _UserCard(user: users[index], adminUid: adminUid, colors: c);
              },
            );
          },
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final AppUserAccess user;
  final String adminUid;
  final CompanyColors colors;

  const _UserCard({required this.user, required this.adminUid, required this.colors});

  Color get _statusColor {
    switch (user.accessStatus) {
      case AccessStatus.approved:
        return colors.success;
      case AccessStatus.rejected:
        return colors.danger;
      case AccessStatus.pending:
        return colors.gold;
    }
  }

  Future<void> _setLevel(BuildContext context, AccessLevel level) async {
    await AccessControlService.setAccessLevel(
      targetUid: user.uid,
      level: level,
      adminUid: adminUid,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user.name}: access set to ${accessLevelToString(level)}')),
      );
    }
  }

  Future<void> _reject(BuildContext context) async {
    await AccessControlService.rejectAccess(
      targetUid: user.uid,
      adminUid: adminUid,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user.name}: access revoked')),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Delete profile?', style: GoogleFonts.plusJakartaSans(color: colors.textPrimary)),
        content: Text(
          'This removes ${user.name}\'s Firestore profile. It does NOT delete '
              'their login account — do that from the Firebase console if needed.',
          style: GoogleFonts.plusJakartaSans(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: colors.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await AccessControlService.deleteUserProfile(user.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.borderSubtle.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: colors.accent.withValues(alpha: 0.15),
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                  style: GoogleFonts.plusJakartaSans(color: colors.accent, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name.isEmpty ? '(no name)' : user.name,
                      style: GoogleFonts.plusJakartaSans(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      user.email,
                      style: GoogleFonts.plusJakartaSans(color: colors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  accessStatusToString(user.accessStatus).toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(color: _statusColor, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Chip(label: user.role.toUpperCase(), color: colors.gold, colors: colors),
              if (user.branch.isNotEmpty)
                _Chip(label: user.branch, color: colors.accent, colors: colors),
              _Chip(
                label: 'Access: ${accessLevelToString(user.accessLevel)}',
                color: colors.accent,
                colors: colors,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'Viewer',
                  color: colors.accent,
                  onTap: () => _setLevel(context, AccessLevel.viewer),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _ActionButton(
                  label: 'Editor',
                  color: colors.accent,
                  onTap: () => _setLevel(context, AccessLevel.editor),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _ActionButton(
                  label: 'Revoke',
                  color: colors.danger,
                  onTap: () => _reject(context),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: Icon(Icons.delete_outline, color: colors.textSecondary),
                onPressed: () => _confirmDelete(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final CompanyColors colors;
  const _Chip({required this.label, required this.color, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: GoogleFonts.plusJakartaSans(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _ActionButton({required this.label, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}