// lib/screens/admin/activity_feed_screen.dart
//
// Live "what is everyone doing" feed for the admin. Reads the
// activity_logs collection in real time (StreamBuilder, not a one-time
// fetch), with tabs to filter by who did it.
//
// Only 'login' and admin-approval actions are logged out of the box.
// To make other actions (batch created, student added, drone added,
// vault upload, etc.) show up here too, call
// AccessControlService.logAction(...) from wherever that action
// happens — see the example in access_control_service.dart's doc
// comment, and INTEGRATION.md for concrete call sites in this app.
//
// Styled to match RPTO Vault / Company Details: Plus Jakarta Sans font
// and the CompanyColors light/dark palette.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../config/theme_colors.dart';
import '../../providers/theme_provider.dart';
import '../../models/user_role_model.dart';
import '../../services/access_control_service.dart';

class ActivityFeedScreen extends StatefulWidget {
  const ActivityFeedScreen({super.key});

  @override
  State<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends State<ActivityFeedScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 4, vsync: this);

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
            'Live Activity',
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
            isScrollable: true,
            indicatorColor: c.accent,
            labelColor: c.accent,
            unselectedLabelColor: c.textSecondary,
            labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'All'),
              Tab(text: 'Admin'),
              Tab(text: 'Instructor'),
              Tab(text: 'Student'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _ActivityList(role: null, colors: c),
            _ActivityList(role: 'admin', colors: c),
            _ActivityList(role: 'instructor', colors: c),
            _ActivityList(role: 'student', colors: c),
          ],
        ),
      ),
    );
  }
}

class _ActivityList extends StatelessWidget {
  final String? role;
  final CompanyColors colors;
  const _ActivityList({required this.role, required this.colors});

  @override
  Widget build(BuildContext context) {
    final stream = role == null
        ? AccessControlService.watchActivity()
        : AccessControlService.watchActivityByRole(role: role!);

    return StreamBuilder<List<ActivityLogModel>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: colors.accent),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Failed to load activity.\n${snapshot.error}',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: colors.textSecondary),
            ),
          );
        }

        final logs = snapshot.data ?? const <ActivityLogModel>[];
        if (logs.isEmpty) {
          return Center(
            child: Text('No activity yet.', style: GoogleFonts.plusJakartaSans(color: colors.textSecondary)),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) => _ActivityTile(log: logs[index], colors: colors),
        );
      },
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final ActivityLogModel log;
  final CompanyColors colors;
  const _ActivityTile({required this.log, required this.colors});

  ({IconData icon, Color color}) get _style {
    switch (log.action) {
      case 'login':
        return (icon: Icons.login_rounded, color: colors.accent);
      case 'access_updated':
        return (icon: Icons.verified_user_outlined, color: colors.success);
      case 'access_rejected':
        return (icon: Icons.person_off_outlined, color: colors.danger);
      default:
        return (icon: Icons.bolt_rounded, color: colors.gold);
    }
  }

  Color get _roleColor {
    switch (log.userRole) {
      case 'admin':
        return colors.gold;
      case 'instructor':
        return colors.accent;
      case 'student':
        return colors.success;
      default:
        return colors.textSecondary;
    }
  }

  String _timeAgo(DateTime? time) {
    if (time == null) return '';
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${time.day}/${time.month}/${time.year}';
  }

  @override
  Widget build(BuildContext context) {
    final s = _style;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.borderSubtle.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: s.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(s.icon, color: s.color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        log.userName.isEmpty ? 'Unknown user' : log.userName,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    if (log.userRole.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _roleColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          log.userRole.toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(color: _roleColor, fontSize: 9, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  log.detail.isEmpty ? log.action : log.detail,
                  style: GoogleFonts.plusJakartaSans(color: colors.textSecondary, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _timeAgo(log.createdAt),
            style: GoogleFonts.plusJakartaSans(color: colors.textSecondary.withValues(alpha: 0.7), fontSize: 11),
          ),
        ],
      ),
    );
  }
}