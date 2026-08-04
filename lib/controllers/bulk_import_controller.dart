import 'dart:async';

import 'package:file_picker/file_picker.dart';

import '../models/student_document_model.dart';
import 'package:cda_rpto/services/cloudinary_upload_service.dart';
import 'package:cda_rpto/services/firestore_bulk_import_service.dart';
import 'package:cda_rpto/services/folder_scanner_service.dart';

enum ImportItemStatus {
  pending,
  uploading,
  matching,
  saving,
  success,
  duplicateSkipped,
  failed,
  cancelled,
}

/// Outcome for a single scanned PDF as it moves through the pipeline.
class BulkImportItemResult {
  final StudentDocument document;
  ImportItemStatus status;
  String? secureUrl;
  String? errorMessage;

  BulkImportItemResult({
    required this.document,
    this.status = ImportItemStatus.pending,
    this.secureUrl,
    this.errorMessage,
  });
}

/// Snapshot emitted after every item is processed (and once after scan).
class BulkImportProgress {
  final int total;
  final int processed;
  final int succeeded;
  final int duplicatesSkipped;
  final int failed;
  final bool isScanning;
  final bool isRunning;
  final bool isCancelled;
  final String? currentFileName;

  const BulkImportProgress({
    required this.total,
    required this.processed,
    required this.succeeded,
    required this.duplicatesSkipped,
    required this.failed,
    required this.isScanning,
    required this.isRunning,
    required this.isCancelled,
    this.currentFileName,
  });
}

/// BulkImportController
/// ----------------------
/// Orchestrates the full pipeline as two explicit steps:
///   1. [scanFolder] / [scanWebFiles] — scan only, populates [results]
///      with pending items, uploads nothing yet. If [batchNameFilter]
///      is set, only files whose batch folder matches it are kept.
///   2. [startUpload] — uploads + matches + saves every pending item
///      from the most recent scan.
///
/// Framework-agnostic (plain Dart, no ChangeNotifier/Widget) — a UI layer
/// listens to [progressStream] and calls [cancel] / [retryFailed] as
/// needed.
class BulkImportController {
  final CloudinaryUploadService _cloudinary;
  final FirestoreBulkImportService _firestore;

  /// If set, only documents whose batch folder name matches this
  /// (case-insensitive, trimmed) survive scanning — everything else is
  /// dropped before it ever reaches [results]. Null/empty = no filter,
  /// every batch folder under the picked root is imported.
  final String? batchNameFilter;

  final _progressController =
  StreamController<BulkImportProgress>.broadcast();
  final List<BulkImportItemResult> _results = [];

  bool _isScanning = false;
  bool _isRunning = false;
  bool _cancelRequested = false;

  BulkImportController({
    CloudinaryUploadService? cloudinaryUploadService,
    FirestoreBulkImportService? firestoreBulkImportService,
    this.batchNameFilter,
  })  : _cloudinary = cloudinaryUploadService ?? CloudinaryUploadService(),
        _firestore =
            firestoreBulkImportService ?? FirestoreBulkImportService();

  Stream<BulkImportProgress> get progressStream => _progressController.stream;
  List<BulkImportItemResult> get results => List.unmodifiable(_results);
  bool get isRunning => _isRunning;
  bool get isScanning => _isScanning;

  /// Step 1 (Desktop): scans [rootPath] and populates [results] as
  /// pending items (filtered to [batchNameFilter] if set). Does not
  /// upload anything.
  Future<void> scanFolder(String rootPath) async {
    _isScanning = true;
    _emitProgress();

    final documents = await FolderScannerService.scanDesktopRoot(rootPath);
    _populateResults(documents);

    _isScanning = false;
    _emitProgress();
  }

  /// Step 1 (Web): scans already-picked files and populates [results] as
  /// pending items (filtered to [batchNameFilter] if set). Does not
  /// upload anything.
  Future<void> scanWebFiles(List<PlatformFile> pickedFiles) async {
    _isScanning = true;
    _emitProgress();

    final documents = FolderScannerService.scanWebFiles(pickedFiles);
    _populateResults(documents);

    _isScanning = false;
    _emitProgress();
  }

  /// Step 2: uploads + matches + saves every item currently
  /// [ImportItemStatus.pending] (i.e. from the last scan, or reset via
  /// [retryFailed]).
  Future<void> startUpload() async {
    if (_isRunning || _results.isEmpty) return;

    _cancelRequested = false;
    _isRunning = true;
    _emitProgress();

    for (final item in _results) {
      if (item.status != ImportItemStatus.pending) continue;
      if (_cancelRequested) {
        item.status = ImportItemStatus.cancelled;
        continue;
      }
      await _processItem(item);
      _emitProgress();
    }

    _isRunning = false;
    _emitProgress();
  }

  /// Signals the running upload to stop after the current file finishes.
  /// Remaining pending items are marked [ImportItemStatus.cancelled].
  void cancel() {
    _cancelRequested = true;
  }

  /// Re-runs only the items currently marked [ImportItemStatus.failed].
  /// No-op if nothing has failed or an upload is already running.
  Future<void> retryFailed() async {
    if (_isRunning) return;

    final failedItems =
    _results.where((r) => r.status == ImportItemStatus.failed).toList();
    if (failedItems.isEmpty) return;

    for (final item in failedItems) {
      item.status = ImportItemStatus.pending;
      item.errorMessage = null;
    }

    await startUpload();
  }

  void dispose() {
    _progressController.close();
  }

  // ---- internal -------------------------------------------------------

  void _populateResults(List<StudentDocument> documents) {
    final filtered = batchNameFilter == null || batchNameFilter!.trim().isEmpty
        ? documents
        : documents
        .where((d) => _normalize(d.batchName) == _normalize(batchNameFilter!))
        .toList();

    _results
      ..clear()
      ..addAll(filtered.map((d) => BulkImportItemResult(document: d)));
  }

  String _normalize(String? value) => (value ?? '').trim().toLowerCase();

  Future<void> _processItem(BulkImportItemResult item) async {
    final doc = item.document;

    // 1. Upload
    item.status = ImportItemStatus.uploading;
    _emitProgress(currentFileName: doc.documentName);

    final String secureUrl;
    try {
      secureUrl = await _cloudinary.uploadPdf(
        bytes: doc.localFile.bytes!,
        fileName: doc.documentName,
        folder: 'rpto_uploads/${doc.batchName}/${doc.studentFolder}',
      );
    } on CloudinaryUploadException catch (e) {
      item.status = ImportItemStatus.failed;
      item.errorMessage = e.message;
      return;
    } catch (e) {
      item.status = ImportItemStatus.failed;
      item.errorMessage = 'Unexpected upload error: $e';
      return;
    }

    item.secureUrl = secureUrl;

    // 2. Match student
    item.status = ImportItemStatus.matching;
    _emitProgress(currentFileName: doc.documentName);

    final StudentMatch? match;
    try {
      match = await _firestore.findStudentByName(doc.studentName);
    } on FirestoreImportException catch (e) {
      item.status = ImportItemStatus.failed;
      item.errorMessage = e.message;
      return;
    }

    if (match == null) {
      item.status = ImportItemStatus.failed;
      item.errorMessage =
      'No matching student found for "${doc.studentName}".';
      return;
    }

    // 3. Save
    item.status = ImportItemStatus.saving;
    _emitProgress(currentFileName: doc.documentName);

    try {
      final saveResult = await _firestore.saveUploadedDocument(
        studentId: match.studentId,
        docType: doc.documentType,
        fileName: doc.documentName,
        secureUrl: secureUrl,
      );
      item.status = saveResult.status == ImportSaveStatus.created
          ? ImportItemStatus.success
          : ImportItemStatus.duplicateSkipped;
    } on FirestoreImportException catch (e) {
      item.status = ImportItemStatus.failed;
      item.errorMessage = e.message;
    }
  }

  void _emitProgress({String? currentFileName}) {
    final succeeded =
        _results.where((r) => r.status == ImportItemStatus.success).length;
    final duplicatesSkipped = _results
        .where((r) => r.status == ImportItemStatus.duplicateSkipped)
        .length;
    final failed =
        _results.where((r) => r.status == ImportItemStatus.failed).length;
    final cancelled =
        _results.where((r) => r.status == ImportItemStatus.cancelled).length;
    final processed = succeeded + duplicatesSkipped + failed + cancelled;

    _progressController.add(
      BulkImportProgress(
        total: _results.length,
        processed: processed,
        succeeded: succeeded,
        duplicatesSkipped: duplicatesSkipped,
        failed: failed,
        isScanning: _isScanning,
        isRunning: _isRunning,
        isCancelled: _cancelRequested,
        currentFileName: currentFileName,
      ),
    );
  }
}