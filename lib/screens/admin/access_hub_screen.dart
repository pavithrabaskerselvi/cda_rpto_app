// lib/screens/admin/access_hub_screen.dart
//
// Single entry point that groups the three admin-only facilities that
// used to be separate dashboard tiles: Instructor Access, Access
// Requests, and Live Activity. This screen does NOT duplicate their
// logic — it simply routes to the existing, untouched screens:
//   EmployeeAccessScreen, AdminNotificationsScreen, ActivityFeedScreen
//
// Styled to match the RPTO Vault home screen: Plus Jakarta Sans font,
// CompanyColors light/dark palette, and the same teal-gradient
// SliverAppBar header.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../config/theme_colors.dart';
import '../../providers/theme_provider.dart';
import 'employee_access_screen.dart';
import 'admin_notifications_screen.dart';
import 'activity_feed_screen.dart';

class AccessHubScreen extends StatelessWidget {
  const AccessHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final c = CompanyColors.of(isDark);

    // Plus Jakarta Sans applied page-wide, matching the RPTO Vault screen —
    // every Text widget here inherits it automatically.
    final jakartaTheme = GoogleFonts.plusJakartaSansTextTheme(Theme.of(context).textTheme);

    final items = <({IconData icon, String title, String subtitle, Color color, Widget Function() builder})>[
      (
      icon: Icons.badge_outlined,
      title: 'Instructor Access',
      subtitle: 'Grant, revoke or manage instructor account access',
      color: AppColors.teal,
      builder: () => const EmployeeAccessScreen(),
      ),
      (
      icon: Icons.mark_email_unread_outlined,
      title: 'Access Requests',
      subtitle: 'Review and approve pending access requests',
      color: AppColors.amber,
      builder: () => const AdminNotificationsScreen(),
      ),
      (
      icon: Icons.bolt_outlined,
      title: 'Live Activity',
      subtitle: 'Real-time feed of who is doing what',
      color: AppColors.blue,
      builder: () => const ActivityFeedScreen(),
      ),
    ];

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: jakartaTheme,
        primaryTextTheme: jakartaTheme,
      ),
      child: Scaffold(
        backgroundColor: c.background,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: c.background,
              pinned: true,
              expandedHeight: 130,
              elevation: 0,
              iconTheme: IconThemeData(color: c.textPrimary),
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
                title: Text(
                  'Access Hub',
                  style: GoogleFonts.plusJakartaSans(
                    color: c.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                background: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [c.accent.withValues(alpha: 0.35), c.background],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      _AccessHubTile(
                        icon: items[i].icon,
                        title: items[i].title,
                        subtitle: items[i].subtitle,
                        color: items[i].color,
                        colors: c,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => items[i].builder()),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccessHubTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final CompanyColors colors;
  final VoidCallback onTap;

  const _AccessHubTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      color: colors.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colors.textSecondary.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}