import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../config/theme_colors.dart';
import '../../providers/theme_provider.dart';
import '../../controllers/drone_bulk_import_controller.dart';
import '../../services/web_folder_picker/web_folder_picker.dart';

/// DroneBulkImportScreen
/// ------------------------
/// Pure UI over [DroneBulkImportController] (supplied via Provider —
/// see routes.dart). Reached two ways:
///   - Drone Details -> "Bulk Import Documents" for one drone: pick
///     that drone's Drive folder directly (its immediate children ARE
///     the category folders, e.g. "1.SMALL").
///   - Drone List -> "Bulk Import" across many drones: pick a root
///     folder containing one subfolder per drone.
class DroneBulkImportScreen extends StatefulWidget {
  final String? droneName; // display only, set in single-drone mode

  const DroneBulkImportScreen({super.key, this.droneName});

  @override
  State<DroneBulkImportScreen> createState() => _DroneBulkImportScreenState();
}

class _DroneBulkImportScreenState extends State<DroneBulkImportScreen> {
  String? _selectedFolderPath;
  List<PlatformFile> _webPickedFiles = [];
  bool _isPicking = false;

  Future<void> _handleSelectFolder() async {
    setState(() => _isPicking = true);
    try {
      if (kIsWeb) {
        final files = await pickWebFolderFiles();
        if (files.isEmpty) return;
        setState(() {
          _webPickedFiles = files;
          _selectedFolderPath = '${files.length} file(s) selected';
        });
        return;
      }

      final path = await FilePicker.platform.getDirectoryPath();
      if (path == null) return;
      setState(() {
        _selectedFolderPath = path;
        _webPickedFiles = [];
      });
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  void _handleScan(DroneBulkImportController controller) {
    if (kIsWeb) {
      controller.scanWebFiles(_webPickedFiles);
    } else {
      controller.scanFolder(_selectedFolderPath!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.read<DroneBulkImportController>();
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final c = CompanyColors.of(isDark);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        iconTheme: IconThemeData(color: c.textPrimary),
        title: Text(
          widget.droneName == null
              ? 'Bulk Import — Drones'
              : 'Bulk Import — ${widget.droneName}',
          style: GoogleFonts.plusJakartaSans(
              color: c.textPrimary, fontWeight: FontWeight.w700),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<DroneImportProgress>(
          stream: controller.progressStream,
          builder: (context, snapshot) {
            final progress = snapshot.data;
            final isRunning = progress?.isRunning ?? false;
            final total = progress?.total ?? 0;
            final processed = progress?.processed ?? 0;
            final succeeded = progress?.succeeded ?? 0;
            final duplicates = progress?.duplicatesSkipped ?? 0;
            final failedCount = progress?.failed ?? 0;
            final currentFileName = progress?.currentFileName;
            final currentCategory = progress?.currentCategory;

            final failedItems = controller.results
                .where((r) => r.status == DroneImportItemStatus.failed)
                .toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        controller.isSingleDroneMode
                            ? Icons.folder_special_outlined
                            : Icons.account_tree_outlined,
                        color: c.accent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          controller.isSingleDroneMode
                              ? "Pick this drone's folder — its subfolders (Insurance, COC, Photos...) get imported straight into this drone's Attachments."
                              : 'Pick the root folder — each subfolder should be one drone, matched by drone name or serial number.',
                          style: GoogleFonts.plusJakartaSans(
                              color: c.textSecondary, fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: c.accent, foregroundColor: c.background),
                      onPressed:
                      (isRunning || _isPicking) ? null : _handleSelectFolder,
                      icon: _isPicking
                          ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.folder_open),
                      label: const Text('Select Folder'),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: c.accent,
                          side: BorderSide(color: c.accent)),
                      onPressed: (isRunning ||
                          (_selectedFolderPath == null &&
                              _webPickedFiles.isEmpty))
                          ? null
                          : () => _handleScan(controller),
                      icon: const Icon(Icons.search),
                      label: const Text('Scan'),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: c.gold, foregroundColor: c.background),
                      onPressed:
                      (isRunning || total == 0) ? null : () => controller.startUpload(),
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('Upload'),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: c.danger,
                          side: BorderSide(color: c.danger)),
                      onPressed: (isRunning || failedCount == 0)
                          ? null
                          : () => controller.retryFailed(),
                      icon: const Icon(Icons.refresh),
                      label: Text('Retry Failed ($failedCount)'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_selectedFolderPath != null)
                  Text(
                    kIsWeb ? _selectedFolderPath! : 'Folder: $_selectedFolderPath',
                    style: GoogleFonts.plusJakartaSans(
                        color: c.textSecondary, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : processed / total,
                    minHeight: 8,
                    backgroundColor: c.surface,
                    valueColor: AlwaysStoppedAnimation(c.accent),
                  ),
                ),
                const SizedBox(height: 8),
                Text('$processed / $total processed',
                    style: GoogleFonts.plusJakartaSans(
                        color: c.textSecondary, fontSize: 12.5)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _counterChip(c, 'Total', total, c.accent),
                    _counterChip(c, 'Succeeded', succeeded, c.success),
                    _counterChip(c, 'Duplicates', duplicates, c.gold),
                    _counterChip(c, 'Failed', failedCount, c.danger),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: c.surface, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Current Category: ${currentCategory ?? '-'}',
                          style: GoogleFonts.plusJakartaSans(
                              color: c.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('Current File: ${currentFileName ?? '-'}',
                          style: GoogleFonts.plusJakartaSans(
                              color: c.textSecondary, fontSize: 12.5)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('Failed Uploads',
                    style: GoogleFonts.plusJakartaSans(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
                const SizedBox(height: 8),
                Expanded(
                  child: failedItems.isEmpty
                      ? Center(
                      child: Text('No failed uploads',
                          style: GoogleFonts.plusJakartaSans(
                              color: c.textSecondary)))
                      : ListView.separated(
                    itemCount: failedItems.length,
                    separatorBuilder: (_, __) =>
                        Divider(color: c.borderSubtle.withValues(alpha: 0.15)),
                    itemBuilder: (context, index) {
                      final item = failedItems[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.error_outline, color: c.danger),
                        title: Text(item.document.documentName,
                            style: GoogleFonts.plusJakartaSans(
                                color: c.textPrimary, fontSize: 13.5)),
                        subtitle: Text(
                          '${item.document.category} • ${item.errorMessage ?? 'Unknown error'}',
                          style: GoogleFonts.plusJakartaSans(
                              color: c.textSecondary, fontSize: 12),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _counterChip(CompanyColors c, String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text('$label: $value',
          style: GoogleFonts.plusJakartaSans(
              color: color, fontWeight: FontWeight.w600, fontSize: 12.5)),
    );
  }
}