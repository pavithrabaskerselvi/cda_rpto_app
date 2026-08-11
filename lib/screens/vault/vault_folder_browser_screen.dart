import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../config/vault_categories.dart';
import '../../models/vault_document_model.dart';
import '../../models/vault_subfolder_model.dart';
import '../../providers/vault_provider.dart';
import 'vault_bulk_import_screen.dart';

/// Generic, any-depth folder browser for Vault categories flagged with
/// VaultCategory.supportsSubfolders (now every category — same New
/// Folder + Add Files flow everywhere in the RPTO Vault).
/// Pushed onto itself recursively as the user drills into subfolders —
/// each push just carries a deeper [folderPath].
class VaultFolderBrowserScreen extends StatelessWidget {
  final VaultCategory category;
  // '' means we're showing the folders/files right under the category
  // root (e.g. the date folders under Audit Files).
  final String folderPath;

  const VaultFolderBrowserScreen({
    super.key,
    required this.category,
    this.folderPath = '',
  });

  String get _title => folderPath.isEmpty ? category.label : folderPath.split('/').last;

  @override
  Widget build(BuildContext context) {
    final vault = context.read<VaultProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: category.color,
        foregroundColor: Colors.white,
        title: Text(_title, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: category.color,
        icon: const Icon(Icons.add),
        label: const Text('Add'),
        onPressed: () => _showAddSheet(context, vault),
      ),
      body: StreamBuilder<List<VaultSubfolder>>(
        stream: vault.watchSubfolders(category.key, folderPath),
        builder: (context, folderSnap) {
          if (folderSnap.hasError) {
            return _StreamErrorView(error: folderSnap.error, color: category.color);
          }
          final subfolders = folderSnap.data ?? [];

          return StreamBuilder<List<VaultDocument>>(
            stream: vault.watchCategoryPath(category.key, folderPath),
            builder: (context, fileSnap) {
              if (fileSnap.hasError) {
                return _StreamErrorView(error: fileSnap.error, color: category.color);
              }
              final loading = folderSnap.connectionState == ConnectionState.waiting ||
                  fileSnap.connectionState == ConnectionState.waiting;
              if (loading && subfolders.isEmpty && (fileSnap.data ?? []).isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              final files = fileSnap.data ?? [];

              if (subfolders.isEmpty && files.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder_open, color: category.color.withValues(alpha: 0.4), size: 48),
                      const SizedBox(height: 12),
                      const Text('Empty folder', style: TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => _showAddSheet(context, vault),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: category.color,
                          side: BorderSide(color: category.color.withValues(alpha: 0.5)),
                        ),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Folder or Files'),
                      ),
                    ],
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                children: [
                  for (final folder in subfolders)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _FolderTile(
                        folder: folder,
                        color: category.color,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VaultFolderBrowserScreen(
                                category: category,
                                folderPath: folder.path,
                              ),
                            ),
                          );
                        },
                        onDelete: () => _confirmDeleteFolder(context, vault, folder),
                      ),
                    ),
                  for (final doc in files)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _FileTile(
                        doc: doc,
                        color: category.color,
                        onDelete: () => vault.deleteDocument(doc.id, category.key),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _showAddSheet(BuildContext context, VaultProvider vault) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(Icons.create_new_folder_outlined, color: category.color),
                title: const Text('New Folder'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _promptNewFolder(context, vault);
                },
              ),
              ListTile(
                leading: Icon(Icons.upload_file_outlined, color: category.color),
                title: const Text('Add Files'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VaultBulkImportScreen(
                        initialCategoryKey: category.key,
                        folderPath: folderPath,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _promptNewFolder(BuildContext context, VaultProvider vault) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('New Folder'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Folder name'),
            onSubmitted: (_) => _createFolder(dialogContext, context, vault, controller.text),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            TextButton(
              onPressed: () => _createFolder(dialogContext, context, vault, controller.text),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createFolder(
      BuildContext dialogContext,
      BuildContext screenContext,
      VaultProvider vault,
      String name,
      ) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final createdBy = FirebaseAuth.instance.currentUser?.email ??
        FirebaseAuth.instance.currentUser?.uid ??
        'unknown';

    bool ok = false;
    Object? error;
    try {
      ok = await vault.createSubfolder(
        categoryKey: category.key,
        parentPath: folderPath,
        name: trimmed,
        createdBy: createdBy,
      );
    } catch (e) {
      error = e;
    }

    if (dialogContext.mounted) Navigator.pop(dialogContext);

    if (error != null && screenContext.mounted) {
      showDialog(
        context: screenContext,
        builder: (_) => AlertDialog(
          title: const Text('Could not create folder'),
          content: SelectableText(error.toString(), style: const TextStyle(fontSize: 12)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(screenContext), child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    if (!ok && screenContext.mounted) {
      ScaffoldMessenger.of(screenContext).showSnackBar(
        SnackBar(content: Text('A folder named "$trimmed" already exists here'), backgroundColor: AppColors.coral),
      );
    }
  }

  void _confirmDeleteFolder(BuildContext context, VaultProvider vault, VaultSubfolder folder) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete folder?'),
        content: Text(
          'Delete "${folder.name}"? This only removes the empty folder — '
              'make sure it has no files or subfolders left inside first.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              vault.deleteSubfolder(folder.id);
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.coral)),
          ),
        ],
      ),
    );
  }
}

class _FolderTile extends StatelessWidget {
  final VaultSubfolder folder;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _FolderTile({
    required this.folder,
    required this.color,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
              child: Icon(Icons.folder, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                folder.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.coral, size: 20),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _StreamErrorView extends StatelessWidget {
  final Object? error;
  final Color color;

  const _StreamErrorView({required this.error, required this.color});

  @override
  Widget build(BuildContext context) {
    final message = error.toString();
    // Firestore's "failed-precondition" error for a missing composite
    // index embeds a direct https://console.firebase.google.com/... link
    // that auto-creates the exact index this query needs. Surface the
    // raw message (instead of swallowing it) so that link is visible and
    // selectable — copy it into a browser tab to fix this in one click.
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: AppColors.coral, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Could not load this folder',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            SelectableText(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileTile extends StatelessWidget {
  final VaultDocument doc;
  final Color color;
  final VoidCallback onDelete;

  const _FileTile({required this.doc, required this.color, required this.onDelete});

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