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
