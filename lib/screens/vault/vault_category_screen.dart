import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../config/vault_categories.dart';
import '../../models/vault_document_model.dart';
import '../../providers/vault_provider.dart';

/// Shows every document uploaded under one Vault category, live via
/// VaultProvider.watchCategory. Reached from VaultHomeScreen by tapping
/// a folder tile.
class VaultCategoryScreen extends StatelessWidget {
  final VaultCategory category;

  const VaultCategoryScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final vault = context.read<VaultProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: category.color,
        foregroundColor: Colors.white,
        title: Text(category.label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: StreamBuilder<List<VaultDocument>>(
        stream: vault.watchCategory(category.key),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Could not load files: ${snapshot.error}',
                  style: const TextStyle(color: AppColors.coral)),
            );
          }

          final docs = snapshot.data ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_open, color: category.color.withValues(alpha: 0.4), size: 48),
                  const SizedBox(height: 12),
                  const Text('No files yet', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final doc = docs[index];
              return _VaultDocTile(
                doc: doc,
                color: category.color,
                onDelete: () => vault.deleteDocument(doc.id, category.key),
              );
            },
          );
        },
      ),
    );
  }
}

class _VaultDocTile extends StatelessWidget {
  final VaultDocument doc;
  final Color color;
  final VoidCallback onDelete;

  const _VaultDocTile({required this.doc, required this.color, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.insert_drive_file_outlined, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc.fileName,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                const SizedBox(height: 2),
                Text('${doc.extension.toUpperCase()} · ${(doc.size / 1024).toStringAsFixed(0)} KB',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.coral, size: 20),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete file?'),
        content: Text('Remove "${doc.fileName}" from the vault?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete();
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.coral)),
          ),
        ],
      ),
    );
  }
}