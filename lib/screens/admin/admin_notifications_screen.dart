// lib/screens/admin/admin_notifications_screen.dart
//
// Tabbed Pending / Approved / Rejected view of access-request
// notifications, with Approve/Reject actions on pending cards.
// Styled to match RPTO Vault / Company Details: Plus Jakarta Sans font
// and the CompanyColors light/dark palette.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../config/theme_colors.dart';
import '../../providers/theme_provider.dart';
import '../../models/user_role_model.dart';
import '../../services/access_control_service.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
  TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final c = CompanyColors.of(isDark);
    final jakartaTheme = GoogleFonts.plusJakartaSansTextTheme(Theme.of(context).textTheme);

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: jakartaTheme,
        primaryTextTheme: jakartaTheme,
      ),
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          title: Text(
            'Access Requests',
            style: GoogleFonts.plusJakartaSans(
              color: c.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          backgroundColor: c.background,
          elevation: 0,
          iconTheme: IconThemeData(color: c.textPrimary),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: c.accent,
            labelColor: c.accent,
            unselectedLabelColor: c.textSecondary,
            labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Pending'),
              Tab(text: 'Approved'),
              Tab(text: 'Rejected'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _NotificationList(status: AccessStatus.pending, colors: c),
            _NotificationList(status: AccessStatus.approved, colors: c),
            _NotificationList(status: AccessStatus.rejected, colors: c),
          ],
        ),
      ),
    );
  }
}

class _NotificationList extends StatelessWidget {
  final AccessStatus status;
  final CompanyColors colors;
  const _NotificationList({required this.status, required this.colors});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminNotificationModel>>(
      stream: AccessControlService.watchNotifications(status: status),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: colors.accent),
          );
        }
        final items = snapshot.data ?? const <AdminNotificationModel>[];
        if (items.isEmpty) {
          return Center(
            child: Text(
              'No ${status.name} requests.',
              style: GoogleFonts.plusJakartaSans(color: colors.textSecondary),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final n = items[index];
            return status == AccessStatus.pending
                ? _PendingCard(notification: n, colors: colors)
                : _ReadOnlyCard(notification: n, colors: colors);
          },
        );
      },
    );
  }
}

class _PendingCard extends StatefulWidget {
  final AdminNotificationModel notification;
  final CompanyColors colors;
  const _PendingCard({required this.notification, required this.colors});

  @override
  State<_PendingCard> createState() => _PendingCardState();
}

class _PendingCardState extends State<_PendingCard> {
  bool _busy = false;
  AccessLevel _grantLevel = AccessLevel.viewer;

  Future<void> _resolve(bool approve) async {
    final adminUid = FirebaseAuth.instance.currentUser?.uid;
    if (adminUid == null) return;
    setState(() => _busy = true);
    try {
      await AccessControlService.resolveNotification(
        notification: widget.notification,
        approve: approve,
        grantedLevel: _grantLevel,
        adminUid: adminUid,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve
                ? '${widget.notification.userName} approved (${accessLevelToString(_grantLevel)})'
                : '${widget.notification.userName} rejected'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notification;
    final c = widget.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(n.userName.isEmpty ? n.userEmail : n.userName,
              style: GoogleFonts.plusJakartaSans(color: c.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(n.message, style: GoogleFonts.plusJakartaSans(color: c.textSecondary, fontSize: 13)),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('Grant:', style: GoogleFonts.plusJakartaSans(color: c.textSecondary, fontSize: 12)),
              const SizedBox(width: 8),
              DropdownButton<AccessLevel>(
                value: _grantLevel,
                dropdownColor: c.surface,
                style: GoogleFonts.plusJakartaSans(color: c.textPrimary),
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: AccessLevel.viewer, child: Text('Viewer')),
                  DropdownMenuItem(value: AccessLevel.editor, child: Text('Editor')),
                ],
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _grantLevel = v ?? AccessLevel.viewer),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _busy ? null : () => _resolve(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: c.success,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Approve'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _resolve(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.danger,
                    side: BorderSide(color: c.danger),
                  ),
                  child: const Text('Reject'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyCard extends StatelessWidget {
  final AdminNotificationModel notification;
  final CompanyColors colors;
  const _ReadOnlyCard({required this.notification, required this.colors});

  @override
  Widget build(BuildContext context) {
    final color = notification.status == AccessStatus.approved
        ? colors.success
        : colors.danger;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.borderSubtle.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(
            notification.status == AccessStatus.approved
                ? Icons.check_circle_outline
                : Icons.cancel_outlined,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.userName.isEmpty
                      ? notification.userEmail
                      : notification.userName,
                  style: GoogleFonts.plusJakartaSans(color: colors.textPrimary, fontWeight: FontWeight.w600),
                ),
                Text(notification.message,
                    style: GoogleFonts.plusJakartaSans(color: colors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}