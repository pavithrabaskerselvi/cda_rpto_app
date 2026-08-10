import 'package:flutter/material.dart';

class VaultCategory {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  final List<String> matchTokens;

  const VaultCategory({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.matchTokens,
  });
}

class VaultCategories {
  VaultCategories._();

  static const List<VaultCategory> all = [
    VaultCategory(
      key: 'maintenance_log',
      label: 'Maintenance Log',
      icon: Icons.build_outlined,
      color: Color(0xFFC97A08),
      matchTokens: ['maintenance', 'maintanence'],
    ),
    VaultCategory(
      key: 'audit_files',
      label: 'Audit Files',
      icon: Icons.fact_check_outlined,
      color: Color(0xFF6D28D9),
      matchTokens: ['audit'],
    ),
    VaultCategory(
      key: 'course_material',
      label: 'Course Material',
      icon: Icons.menu_book_outlined,
      color: Color(0xFF0F9E93),
      matchTokens: ['course material'],
    ),
    VaultCategory(
      key: 'invoices',
      label: 'Invoices',
      icon: Icons.receipt_long_outlined,
      color: Color(0xFF15803D),
      matchTokens: ['invoice'],
    ),
    VaultCategory(
      key: 'manuals',
      label: 'Manuals',
      icon: Icons.description_outlined,
      color: Color(0xFF0F9E93),
      matchTokens: ['manual'],
    ),
    VaultCategory(
      key: 'roles',
      label: 'Roles & Responsibilities',
      icon: Icons.badge_outlined,
      color: Color(0xFFE0454B),
      matchTokens: ['roles', 'responsibilit'],
    ),
    VaultCategory(
      key: 'formats',
      label: 'Formats',
      icon: Icons.grid_view_outlined,
      color: Color(0xFFC97A08),
      matchTokens: ['format'],
    ),
    VaultCategory(
      key: 'question_bank',
      label: 'Question Bank',
      icon: Icons.quiz_outlined,
      color: Color(0xFF6D28D9),
      matchTokens: ['question bank', 'question'],
    ),
    VaultCategory(
      key: 'course_ppts',
      label: 'Course PPTs',
      icon: Icons.slideshow_outlined,
      color: Color(0xFF15803D),
      matchTokens: ['ppt', 'course ppts'],
    ),
    VaultCategory(
      key: 'tpm',
      label: 'TPM',
      icon: Icons.precision_manufacturing_outlined,
      color: Color(0xFF0F9E93),
      matchTokens: ['tpm'],
    ),
    VaultCategory(
      key: 'rpto_books',
      label: 'RPTO Books',
      icon: Icons.library_books_outlined,
      color: Color(0xFFE0454B),
      matchTokens: ['rpto books'],
    ),
    VaultCategory(
      key: 'rpto_files',
      label: 'RPTO Files',
      icon: Icons.folder_special_outlined,
      color: Color(0xFFC97A08),
      matchTokens: ['rpto files'],
    ),
  ];

  static VaultCategory classify(String rawFolderName) {
    final normalized = rawFolderName.toLowerCase().trim();
    for (final category in all) {
      for (final token in category.matchTokens) {
        if (normalized.contains(token)) return category;
      }
    }
    return all.last;
  }

  static VaultCategory byKey(String key) {
    return all.firstWhere((c) => c.key == key, orElse: () => all.last);
  }
}