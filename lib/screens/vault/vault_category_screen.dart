import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../config/vault_categories.dart';
import '../../models/vault_document_model.dart';
import '../../providers/vault_provider.dart';
import 'vault_bulk_import_screen.dart';

/// Shows every document uploaded under one Vault category, live via
/// VaultProvider.watchCategory. Reached from VaultHomeScreen by tapping
/// a folder tile.
class VaultCategoryScreen extends StatelessWidget {
  final VaultCategory category;

  const VaultCategoryScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final vault = context.read<VaultProvider>();

    // Nunito applied page-wide, matching VaultHomeScreen — every Text
    // widget here (app bar title, file names, sizes, dialogs) inherits it
    // automatically since none of them set an explicit fontFamily.
    final nunitoTheme = GoogleFonts.nunitoTextTheme(Theme.of(context).textTheme);

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: nunitoTheme,
        primaryTextTheme: nunitoTheme,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: category.color,
          foregroundColor: Colors.white,
          title: Text(category.label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: category.color,
          icon: const Icon(Icons.upload_file_outlined),
          label: const Text('Add Files'),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VaultBulkImportScreen(initialCategoryKey: category.key),
              ),
            );
          },
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
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VaultBulkImportScreen(initialCategoryKey: category.key),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: category.color,
                        side: BorderSide(color: category.color.withValues(alpha: 0.5)),
                      ),
                      icon: const Icon(Icons.upload_file_outlined, size: 18),
                      label: const Text('Add Files'),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final doc = docs[index];
                return _VaultDocTile(
                  doc: doc,
                  color: category.color,
                  onDelete: () => vault.deleteDocument(doc.id, category.key),
                  onRename: (newName) => vault.renameDocument(doc.id, category.key, newName),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _VaultDocTile extends StatelessWidget {
  final VaultDocument doc;
  final Color color;
  final VoidCallback onDelete;
  final ValueChanged<String> onRename;

  const _VaultDocTile({
    required this.doc,
    required this.color,
    required this.onDelete,
    required this.onRename,
  });

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
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _viewDoc(context),
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
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
              onSelected: (value) {
                switch (value) {
                  case 'view':
                    _viewDoc(context);
                    break;
                  case 'edit':
                    _renameDialog(context);
                    break;
                  case 'delete':
                    _confirmDelete(context);
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'view',
                  child: Row(children: [
                    Icon(Icons.visibility_outlined, size: 18, color: Colors.black87),
                    SizedBox(width: 8),
                    Text('View'),
                  ]),
                ),
                PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit_outlined, size: 18, color: Colors.black87),
                    SizedBox(width: 8),
                    Text('Rename'),
                  ]),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline, size: 18, color: AppColors.coral),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: AppColors.coral)),
                  ]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _viewDoc(BuildContext context) async {
    final uri = Uri.tryParse(doc.url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open file')),
        );
      }
    }
  }

  void _renameDialog(BuildContext context) {
    final controller = TextEditingController(text: doc.fileName);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename file'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final newName = controller.text.trim();
              Navigator.pop(context);
              if (newName.isNotEmpty && newName != doc.fileName) {
                onRename(newName);
              }
            },
            child: const Text('Save'),
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