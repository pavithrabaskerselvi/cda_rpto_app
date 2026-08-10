import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../config/vault_categories.dart';
import '../../models/vault_document_model.dart';
import '../../providers/vault_provider.dart';
import '../../services/cloudinary_upload_service.dart';

/// Shows every document uploaded under one Vault category, live via
/// VaultProvider.watchCategory. Reached from VaultHomeScreen by tapping
/// a folder tile. The FAB lets the user pick a file and upload it
/// straight into this category via CloudinaryUploadService + Firestore.
class VaultCategoryScreen extends StatefulWidget {
  final VaultCategory category;

  const VaultCategoryScreen({super.key, required this.category});

  @override
  State<VaultCategoryScreen> createState() => _VaultCategoryScreenState();
}

class _VaultCategoryScreenState extends State<VaultCategoryScreen> {
  final _cloudinary = CloudinaryUploadService();
  bool _isUploading = false;

  VaultCategory get category => widget.category;

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true, // needed so `bytes` is populated on web too
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'jpg', 'jpeg', 'png'],
    );

    if (result == null || result.files.isEmpty) return;

    final picked = result.files.single;
    final bytes = picked.bytes;
    if (bytes == null) {
      _showError('Could not read "${picked.name}" — please try again.');
      return;
    }

    setState(() => _isUploading = true);

    try {
      final secureUrl = await _cloudinary.uploadPdf(
        bytes: bytes,
        fileName: picked.name,
        folder: 'rpto_vault/${category.key}',
      );

      final extension = picked.extension ?? _extensionFrom(picked.name);
      final userEmail = FirebaseAuth.instance.currentUser?.email ?? 'unknown';

      if (!mounted) return;
      await context.read<VaultProvider>().addDocument(
        categoryKey: category.key,
        fileName: picked.name,
        url: secureUrl,
        extension: extension,
        size: bytes.length,
        uploadedBy: userEmail,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${picked.name}" uploaded')),
      );
    } on CloudinaryUploadException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Upload failed: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  String _extensionFrom(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot == -1 || dot == fileName.length - 1) return '';
    return fileName.substring(dot + 1).toLowerCase();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.coral),
    );
  }

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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: category.color,
        onPressed: _isUploading ? null : _pickAndUpload,
        icon: _isUploading
            ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        )
            : const Icon(Icons.upload_file, color: Colors.white),
        label: Text(
          _isUploading ? 'Uploading...' : 'Add File',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
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
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final doc = docs[index];
              return _VaultDocTile(
                doc: doc,
                color: category.color,
                onDelete: () => vault.deleteDocument(doc.id, category.key),
                onRename: (newName) => vault.renameDocument(doc.id, newName),
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
  final ValueChanged<String> onRename;

  const _VaultDocTile({
    required this.doc,
    required this.color,
    required this.onDelete,
    required this.onRename,
  });

  Future<void> _viewFile(BuildContext context) async {
    final uri = Uri.tryParse(doc.url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This file has no valid link.')),
      );
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the file.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _viewFile(context),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
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
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
                onSelected: (value) {
                  switch (value) {
                    case 'view':
                      _viewFile(context);
                      break;
                    case 'rename':
                      _showRenameDialog(context);
                      break;
                    case 'delete':
                      _confirmDelete(context);
                      break;
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'view',
                    child: Row(
                      children: [
                        Icon(Icons.open_in_new, size: 18, color: AppColors.textPrimary),
                        SizedBox(width: 10),
                        Text('View'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18, color: AppColors.textPrimary),
                        SizedBox(width: 10),
                        Text('Rename'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 18, color: AppColors.coral),
                        SizedBox(width: 10),
                        Text('Delete', style: TextStyle(color: AppColors.coral)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: doc.fileName);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename file'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'File name',
            border: OutlineInputBorder(),
          ),
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