// lib/widgets/role_gated_widget.dart
//
// Shows [child] only when the current user satisfies the given gate;
// otherwise shows [fallback] (defaults to nothing). Reads RoleProvider,
// so make sure it's registered in main.dart's MultiProvider.
//
// Usage:
//   AdminOnly(child: AdminNavButton())
//   RoleGatedWidget(gate: (r) => r.canEdit, child: EditButton())

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/role_provider.dart';

class RoleGatedWidget extends StatelessWidget {
  final bool Function(RoleProvider role) gate;
  final Widget child;
  final Widget fallback;

  const RoleGatedWidget({
    super.key,
    required this.gate,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  });

  @override
  Widget build(BuildContext context) {
    final role = context.watch<RoleProvider>();
    return gate(role) ? child : fallback;
  }
}

/// Convenience wrapper for the most common case — admin-only UI.
class AdminOnly extends StatelessWidget {
  final Widget child;
  final Widget fallback;

  const AdminOnly({
    super.key,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  });

  @override
  Widget build(BuildContext context) {
    return RoleGatedWidget(
      gate: (r) => r.isAdmin,
      fallback: fallback,
      child: child,
    );
  }
}

/// Convenience wrapper for editor-or-above UI (admin, or an
/// instructor/student who was granted editor access).
class EditorOnly extends StatelessWidget {
  final Widget child;
  final Widget fallback;

  const EditorOnly({
    super.key,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  });

  @override
  Widget build(BuildContext context) {
    return RoleGatedWidget(
      gate: (r) => r.canEdit,
      fallback: fallback,
      child: child,
    );
  }
}

/// Hard gate for an entire ADMIN-ONLY SCREEN (not just a button/tile).
///
/// Wrap this around the widget a route builds — e.g.
///   accessHub: (context) => const AdminOnlyScreen(child: AccessHubScreen()),
///
/// Why this matters: hiding the "Access Hub" tile with [AdminOnly] only
/// stops instructors/students from tapping their way there. On Flutter
/// web (and with deep links generally) anyone can still type the route
/// straight into the address bar, e.g. `#/access-hub`, and land on the
/// real screen with no check at all. This widget re-checks the signed-in
/// user's role at the screen level, every time, so a direct URL visit,
/// a bookmarked link, or a Navigator.pushNamed call from anywhere in the
/// code is blocked the same way the tile is — instead of rendering
/// [child], it shows a plain "Access Restricted" screen.
///
/// Use this on every admin-only screen: AccessHubScreen,
/// EmployeeAccessScreen, AdminNotificationsScreen, ActivityFeedScreen.
class AdminOnlyScreen extends StatelessWidget {
  final Widget child;

  const AdminOnlyScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final role = context.watch<RoleProvider>();

    // While the role is still loading (e.g. straight after a hot
    // restart on web before RoleProvider has re-hydrated), don't flash
    // the admin screen — show a spinner instead of either extreme.
    if (role.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!role.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Restricted')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 56, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'This section is only available to the administrator '
                      'account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.of(context)
                      .popUntil((route) => route.isFirst),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return child;
  }
}