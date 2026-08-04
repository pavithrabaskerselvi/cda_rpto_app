import 'package:flutter/material.dart';

/// A list tile representing a student — used in batch rosters, search
/// results, and admin management screens.
///
/// ASSUMPTIONS (rename fields to match your actual StudentModel):
/// - `photoUrl` optional; falls back to initials avatar.
/// - `batchName` optional subtitle context (e.g. "Batch: CDA-2026-A").
/// - `status` optional (e.g. 'active', 'inactive') shown as a small dot.
class StudentListTile extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final String? batchName;
  final String? email;
  final String? status;
  final VoidCallback? onTap;

  const StudentListTile({
    super.key,
    required this.name,
    this.photoUrl,
    this.batchName,
    this.email,
    this.status,
    this.onTap,
  });

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleParts = [
      if (batchName != null) batchName!,
      if (email != null) email!,
    ];

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundImage:
        photoUrl != null ? NetworkImage(photoUrl!) : null,
        backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
        child: photoUrl == null
            ? Text(
          _initials,
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        )
            : null,
      ),
      title: Text(name),
      subtitle: subtitleParts.isNotEmpty
          ? Text(subtitleParts.join(' • '),
          style: theme.textTheme.bodySmall)
          : null,
      trailing: status != null
          ? Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: status!.toLowerCase() == 'active'
              ? Colors.green
              : Colors.grey,
        ),
      )
          : const Icon(Icons.chevron_right, size: 20),
    );
  }
}