import 'package:flutter/material.dart';
import '../config/vault_categories.dart';

/// A category tile on the Vault home screen, combined with its live
/// document count from Firestore. Not stored directly — VaultProvider
/// builds one of these per VaultCategory each time it refreshes counts.
class VaultFolder {
  final VaultCategory category;
  final int docCount;
  final DateTime? lastUpdated;

  const VaultFolder({
    required this.category,
    required this.docCount,
    this.lastUpdated,
  });

  String get key => category.key;
  String get label => category.label;
  IconData get icon => category.icon;
  Color get color => category.color;
}
