import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Same upload service DroneBulkImportController already uses — adjust
// the method name below if yours differs for non-PDF files.
import 'package:cda_rpto/services/cloudinary_upload_service.dart';

import '../../config/theme.dart';
import '../../config/vault_categories.dart';
import '../../providers/vault_provider.dart';

enum _ImportItemStatus { pending, uploading, success, failed }

class _ImportItem {
  final PlatformFile file;
  _ImportItemStatus status;
  String? errorMessage;

  _ImportItem({required this.file, this.status = _ImportItemStatus.pending, this.errorMessage});
}

/// Bulk-add screen for RPTO Vault: pick a category once, multi-select
/// files, then upload the whole batch in one go — instead of adding
/// files one at a time from VaultCategoryScreen.
///
/// Usage:
/// ```dart
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => const VaultBulkImportScreen(),
/// ));
/// // or pre-select a category, e.g. coming from VaultCategoryScreen:
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => VaultBulkImportScreen(initialCategoryKey: category.key),
/// ));
/// // or pre-select a category AND a subfolder inside it, e.g. coming
/// // from VaultFolderBrowserScreen:
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => VaultBulkImportScreen(
///     initialCategoryKey: category.key,
///     folderPath: '03-02-2026/CHECKLIST',
///   ),
/// ));
/// ```
class VaultBulkImportScreen extends StatefulWidget {
  final String? initialCategoryKey;
  // Subfolder within the category to upload into, '' for the category
  // root. Only meaningful for categories with supportsSubfolders: true.
  final String folderPath;

  const VaultBulkImportScreen({super.key, this.initialCategoryKey, this.folderPath = ''});

  @override
  State<VaultBulkImportScreen> createState() => _VaultBulkImportScreenState();
}

class _VaultBulkImportScreenState extends State<VaultBulkImportScreen> {
  final _cloudinary = CloudinaryUploadService();

  late VaultCategory _selectedCategory;
  final List<_ImportItem> _items = [];

  bool _isPicking = false;
  bool _isUploading = false;
  bool _cancelRequested = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategoryKey != null
        ? VaultCategories.byKey(widget.initialCategoryKey!)
        : VaultCategories.all.first;
  }

  int get _succeeded => _items.where((i) => i.status == _ImportItemStatus.success).length;
  int get _failed => _items.where((i) => i.status == _ImportItemStatus.failed).length;
  int get _processed => _succeeded + _failed;

  Future<void> _pickFiles() async {
    setState(() => _isPicking = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.any,
      );
      if (result == null) return;

      setState(() {
        _items
          ..clear()
          ..addAll(result.files.map((f) => _ImportItem(file: f)));
      });
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _startUpload() async {
    if (_items.isEmpty || _isUploading) return;

    setState(() {
      _isUploading = true;
      _cancelRequested = false;
    });

    final uploadedBy = FirebaseAuth.instance.currentUser?.email ??
        FirebaseAuth.instance.currentUser?.uid ??
        'unknown';
    final vault = context.read<VaultProvider>();

    for (final item in _items) {
      if (_cancelRequested) break;
      if (item.status == _ImportItemStatus.success) continue;
      if (item.file.bytes == null) {
        setState(() {
          item.status = _ImportItemStatus.failed;
          item.errorMessage = 'Could not read file bytes';
        });
        continue;
      }

      setState(() => item.status = _ImportItemStatus.uploading);

      try {
        final secureUrl = await _cloudinary.uploadPdf(
          bytes: item.file.bytes!,
          fileName: item.file.name,
          folder: widget.folderPath.isEmpty
              ? 'rpto_vault/${_selectedCategory.key}'
              : 'rpto_vault/${_selectedCategory.key}/${widget.folderPath}',
        );

        await vault.addDocument(
          categoryKey: _selectedCategory.key,
          fileName: item.file.name,
          url: secureUrl,
          extension: item.file.extension ?? '',
          size: item.file.size,
          uploadedBy: uploadedBy,
          folderPath: widget.folderPath,
        );

        setState(() => item.status = _ImportItemStatus.success);
      } on CloudinaryUploadException catch (e) {
        setState(() {
          item.status = _ImportItemStatus.failed;
          item.errorMessage = e.message;
        });
      } catch (e) {
        setState(() {
          item.status = _ImportItemStatus.failed;
          item.errorMessage = 'Upload failed: $e';
        });
      }
    }

    if (mounted) setState(() => _isUploading = false);
  }

  void _cancel() {
    setState(() => _cancelRequested = true);
  }

  void _retryFailed() {
    for (final item in _items) {
      if (item.status == _ImportItemStatus.failed) {
        item.status = _ImportItemStatus.pending;
        item.errorMessage = null;
      }
    }
    _startUpload();
  }

  IconData _statusIcon(_ImportItemStatus status) {
    switch (status) {
      case _ImportItemStatus.pending:
        return Icons.schedule;
      case _ImportItemStatus.uploading:
        return Icons.cloud_upload_outlined;
      case _ImportItemStatus.success:
        return Icons.check_circle;
      case _ImportItemStatus.failed:
        return Icons.error_outline;
    }
  }

  Color _statusColor(_ImportItemStatus status) {
    switch (status) {
      case _ImportItemStatus.pending:
        return AppColors.textMuted;
      case _ImportItemStatus.uploading:
        return AppColors.blue;
      case _ImportItemStatus.success:
        return AppColors.green;
      case _ImportItemStatus.failed:
        return AppColors.coral;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
        title: const Text('Bulk Import to Vault', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          if (widget.folderPath.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _selectedCategory.color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _selectedCategory.color.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.folder_outlined, size: 18, color: _selectedCategory.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Uploading into: ${_selectedCategory.label} / ${widget.folderPath}',
                      style: TextStyle(
                        color: _selectedCategory.color,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ---- Category picker ----
          Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<VaultCategory>(
              initialValue: _selectedCategory,
              decoration: InputDecoration(
                labelText: 'Category',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: VaultCategories.all
                  .map((c) => DropdownMenuItem(
                value: c,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(c.icon, size: 18, color: c.color),
                    const SizedBox(width: 8),
                    Text(c.label),
                  ],
                ),
              ))
                  .toList(),
              // Locked once a specific subfolder was pre-selected — the
              // folderPath only makes sense for that one category.
              onChanged: (_isUploading || widget.folderPath.isNotEmpty)
                  ? null
                  : (c) => setState(() => _selectedCategory = c!),
            ),
          ),

          // ---- Pick files button ----
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isUploading || _isPicking ? null : _pickFiles,
                icon: _isPicking
                    ? const SizedBox(
                    width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.attach_file),
                label: Text(_items.isEmpty ? 'Choose Files' : 'Choose Different Files'),
              ),
            ),
          ),

          if (_items.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    '${_items.length} file${_items.length == 1 ? '' : 's'} selected',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const Spacer(),
                  if (_processed > 0)
                    Text(
                      '$_processed / ${_items.length} processed',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // ---- File list ----
          Expanded(
            child: _items.isEmpty
                ? const Center(
              child: Text(
                'Pick a category, then choose files to import.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
                : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final item = _items[index];
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: Icon(_statusIcon(item.status), color: _statusColor(item.status)),
                    title: Text(
                      item.file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    subtitle: item.errorMessage != null
                        ? Text(
                      item.errorMessage!,
                      style: const TextStyle(fontSize: 11, color: AppColors.coral),
                    )
                        : null,
                    trailing: item.status == _ImportItemStatus.uploading
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : null,
                  ),
                );
              },
            ),
          ),

          // ---- Bottom action bar ----
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_isUploading)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _cancel,
                        child: const Text('Cancel'),
                      ),
                    )
                  else if (_failed > 0 && _processed == _items.length)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _retryFailed,
                        icon: const Icon(Icons.refresh),
                        label: Text('Retry $_failed Failed'),
                      ),
                    ),
                  if (_isUploading || (_failed > 0 && _processed == _items.length))
                    const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_items.isEmpty || _isUploading) ? null : _startUpload,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        _isUploading
                            ? 'Uploading… ($_processed/${_items.length})'
                            : 'Upload ${_items.length} File${_items.length == 1 ? '' : 's'}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}