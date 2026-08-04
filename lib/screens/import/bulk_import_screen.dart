import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/bulk_import_controller.dart';
import '../../services/web_folder_picker/web_folder_picker.dart';

/// BulkImportScreen
/// ------------------
/// Pure UI. All scanning/uploading/matching logic lives in
/// [BulkImportController] (obtained via Provider) — this widget only
/// wires buttons to controller calls and renders [BulkImportProgress] /
/// [controller.results] as they change.
///
/// [batchName] is display-only here — it just shows a banner so the
/// admin knows this run is scoped to one batch. The actual filtering
/// happens in [BulkImportController.batchNameFilter], set when the
/// controller was created in routes.dart (must match [batchName] for
/// the banner to be accurate).
///
/// ASSUMPTIONS:
///   - A [BulkImportController] is already supplied above this widget in
///     the tree (see routes.dart) — it is not a ChangeNotifier, so plain
///     `Provider` + `StreamBuilder` is used instead of
///     `ChangeNotifierProvider` + `Consumer`.
///   - Folder selection branches on `kIsWeb`:
///       - Desktop/Mobile: `FilePicker.platform.getDirectoryPath()`
///         directly (a plain OS dialog call, not business logic), then
///         `controller.scanFolder(path)`.
///       - Web: `getDirectoryPath()` is unimplemented on web in
///         file_picker, so we use `pickWebFolderFiles()` (native
///         `webkitdirectory` input, see
///         services/web_folder_picker/) which reads every file's bytes
///         up front and tags each with its relative path, then
///         `controller.scanWebFiles(files)`.
class BulkImportScreen extends StatefulWidget {
  final String? batchName;

  const BulkImportScreen({super.key, this.batchName});

  @override
  State<BulkImportScreen> createState() => _BulkImportScreenState();
}

class _BulkImportScreenState extends State<BulkImportScreen> {
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
          _selectedFolderPath =
          '${files.length} PDF file(s) selected';
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

  void _handleScan(BulkImportController controller) {
    if (kIsWeb) {
      controller.scanWebFiles(_webPickedFiles);
    } else {
      controller.scanFolder(_selectedFolderPath!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.read<BulkImportController>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.batchName == null
              ? 'Bulk Document Import'
              : 'Bulk Import — ${widget.batchName}',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<BulkImportProgress>(
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

            final failedItems = controller.results
                .where((r) => r.status == ImportItemStatus.failed)
                .toList();

            final currentItem = currentFileName == null
                ? null
                : controller.results.firstWhereOrNullSafe(
                  (r) => r.document.documentName == currentFileName,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.batchName != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.filter_alt_outlined),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Scoped to batch "${widget.batchName}" — other '
                                'batch folders under the selected root will be '
                                'skipped.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // --- Action buttons ---
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton.icon(
                      onPressed: (isRunning || _isPicking)
                          ? null
                          : _handleSelectFolder,
                      icon: _isPicking
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Icon(Icons.folder_open),
                      label: const Text('Select Folder'),
                    ),
                    ElevatedButton.icon(
                      onPressed: (isRunning || _selectedFolderPath == null)
                          ? null
                          : () => _handleScan(controller),
                      icon: const Icon(Icons.search),
                      label: const Text('Scan'),
                    ),
                    ElevatedButton.icon(
                      onPressed: (isRunning || total == 0)
                          ? null
                          : () => controller.startUpload(),
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('Upload'),
                    ),
                    OutlinedButton.icon(
                      onPressed: (isRunning || failedCount == 0)
                          ? null
                          : () => controller.retryFailed(),
                      icon: const Icon(Icons.refresh),
                      label: Text('Retry Failed ($failedCount)'),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                if (_selectedFolderPath != null)
                  Text(
                    kIsWeb
                        ? _selectedFolderPath!
                        : 'Folder: $_selectedFolderPath',
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),

                const SizedBox(height: 16),

                // --- Progress bar ---
                LinearProgressIndicator(
                  value: total == 0 ? 0 : processed / total,
                  minHeight: 8,
                ),
                const SizedBox(height: 8),
                Text('$processed / $total processed'),

                const SizedBox(height: 16),

                // --- Live counters ---
                Wrap(
                  spacing: 24,
                  runSpacing: 8,
                  children: [
                    _CounterChip(label: 'Total', value: total),
                    _CounterChip(label: 'Succeeded', value: succeeded),
                    _CounterChip(label: 'Duplicates Skipped', value: duplicates),
                    _CounterChip(label: 'Failed', value: failedCount),
                  ],
                ),

                const SizedBox(height: 16),

                // --- Current student / document ---
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Student: ${currentItem?.document.studentName ?? '-'}',
                        ),
                        const SizedBox(height: 4),
                        Text('Current Document: ${currentFileName ?? '-'}'),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // --- Failed uploads ---
                Text(
                  'Failed Uploads',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: failedItems.isEmpty
                      ? const Center(child: Text('No failed uploads'))
                      : ListView.separated(
                    itemCount: failedItems.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final item = failedItems[index];
                      return ListTile(
                        leading: const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                        ),
                        title: Text(item.document.documentName),
                        subtitle: Text(
                          '${item.document.studentName} • ${item.errorMessage ?? 'Unknown error'}',
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
}

class _CounterChip extends StatelessWidget {
  final String label;
  final int value;

  const _CounterChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label: $value'));
  }
}

/// Small null-safe lookup helper so this file doesn't need the
/// `collection` package just for `firstWhereOrNull`.
extension _FirstWhereOrNull<T> on List<T> {
  T? firstWhereOrNullSafe(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}