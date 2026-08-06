import 'dart:async';

import 'package:file_picker/file_picker.dart';

import '../models/drone_document_model.dart';
import 'package:cda_rpto/services/cloudinary_upload_service.dart';
import 'package:cda_rpto/services/firestore_drone_bulk_import_service.dart';
import 'package:cda_rpto/services/drone_folder_scanner_service.dart';

enum DroneImportItemStatus {
  pending,
  uploading,
  matching,
  saving,
  success,
  duplicateSkipped,
  failed,
  cancelled,
}

/// Outcome for a single scanned file as it moves through the pipeline.
class DroneImportItemResult {
  final DroneDocument document;
  DroneImportItemStatus status;
  String? secureUrl;
  String? errorMessage;

  DroneImportItemResult({
    required this.document,
    this.status = DroneImportItemStatus.pending,
    this.secureUrl,
    this.errorMessage,
  });
}

class DroneImportProgress {
  final int total;
  final int processed;
  final int succeeded;
  final int duplicatesSkipped;
  final int failed;
  final bool isScanning;
  final bool isRunning;
  final bool isCancelled;
  final String? currentFileName;
  final String? currentCategory;

  const DroneImportProgress({
    required this.total,
    required this.processed,
    required this.succeeded,
    required this.duplicatesSkipped,
    required this.failed,
    required this.isScanning,
    required this.isRunning,
    required this.isCancelled,
    this.currentFileName,
    this.currentCategory,
  });
}

/// DroneBulkImportController
/// ----------------------------
/// Same two-step pipeline as BulkImportController (scan, then upload),
/// adapted for drone document folders. Two usage modes, chosen by
/// whether [singleDroneId] is set:
///
///   - SINGLE-DRONE: launch with [singleDroneId]/[singleDroneName] set
///     (from Drone Details -> "Bulk Import Documents"). The picked
///     root is expected to directly contain category folders
///     ("Root/Category/File", exactly like Drive's
///     "13. DRONE DETAILS > 1.SMALL"), and every file is saved to that
///     one drone.
///   - MULTI-DRONE: launch with no single-drone target (from Drone
///     List -> "Bulk Import"). The picked root should contain one
///     folder per drone, each with category subfolders
///     ("Root/DroneFolder/Category/File"); the drone folder name is
///     matched against droneName/serialNumber in Firestore.
class DroneBulkImportController {
  final CloudinaryUploadService _cloudinary;
  final FirestoreDroneBulkImportService _firestore;

  final String? singleDroneId;
  final String? singleDroneName;

  final _progressController =
  StreamController<DroneImportProgress>.broadcast();
  final List<DroneImportItemResult> _results = [];

  bool _isScanning = false;
  bool _isRunning = false;
  bool _cancelRequested = false;

  DroneBulkImportController({
    CloudinaryUploadService? cloudinaryUploadService,
    FirestoreDroneBulkImportService? firestoreDroneBulkImportService,
    this.singleDroneId,
    this.singleDroneName,
  })  : _cloudinary = cloudinaryUploadService ?? CloudinaryUploadService(),
        _firestore = firestoreDroneBulkImportService ??
            FirestoreDroneBulkImportService();

  Stream<DroneImportProgress> get progressStream => _progressController.stream;
  List<DroneImportItemResult> get results => List.unmodifiable(_results);
  bool get isRunning => _isRunning;
  bool get isScanning => _isScanning;
  bool get isSingleDroneMode => singleDroneId != null;

  Future<void> scanFolder(String rootPath) async {
    _isScanning = true;
    _emitProgress();

    final documents = await DroneFolderScannerService.scanDesktopRoot(rootPath);
    _populateResults(documents);

    _isScanning = false;
    _emitProgress();
  }

  Future<void> scanWebFiles(List<PlatformFile> pickedFiles) async {
    _isScanning = true;
    _emitProgress();

    final documents = DroneFolderScannerService.scanWebFiles(pickedFiles);
    _populateResults(documents);

    _isScanning = false;
    _emitProgress();
  }

  Future<void> startUpload() async {
    if (_isRunning || _results.isEmpty) return;

    _cancelRequested = false;
    _isRunning = true;
    _emitProgress();

    for (final item in _results) {
      if (item.status != DroneImportItemStatus.pending) continue;
      if (_cancelRequested) {
        item.status = DroneImportItemStatus.cancelled;
        continue;
      }
      await _processItem(item);
      _emitProgress();
    }

    _isRunning = false;
    _emitProgress();
  }

  void cancel() {
    _cancelRequested = true;
  }

  Future<void> retryFailed() async {
    if (_isRunning) return;

    final failedItems =
    _results.where((r) => r.status == DroneImportItemStatus.failed).toList();
    if (failedItems.isEmpty) return;

    for (final item in failedItems) {
      item.status = DroneImportItemStatus.pending;
      item.errorMessage = null;
    }

    await startUpload();
  }

  void dispose() {
    _progressController.close();
  }

  // ---- internal -------------------------------------------------------

  void _populateResults(List<DroneDocument> documents) {
    _results
      ..clear()
      ..addAll(documents.map((d) => DroneImportItemResult(document: d)));
  }

  Future<void> _processItem(DroneImportItemResult item) async {
    final doc = item.document;

    // 1. Upload
    item.status = DroneImportItemStatus.uploading;
    _emitProgress(currentFileName: doc.documentName, currentCategory: doc.category);

    final String secureUrl;
    try {
      secureUrl = await _cloudinary.uploadPdf(
        bytes: doc.localFile.bytes!,
        fileName: doc.documentName,
        folder:
        'drone_uploads/${doc.droneFolder ?? singleDroneName ?? 'unassigned'}/${doc.category}',
      );
    } on CloudinaryUploadException catch (e) {
      item.status = DroneImportItemStatus.failed;
      item.errorMessage = e.message;
      return;
    } catch (e) {
      item.status = DroneImportItemStatus.failed;
      item.errorMessage = 'Unexpected upload error: $e';
      return;
    }

    item.secureUrl = secureUrl;

    // 2. Resolve which drone this belongs to
    item.status = DroneImportItemStatus.matching;
    _emitProgress(currentFileName: doc.documentName, currentCategory: doc.category);

    late final String droneId;
    if (singleDroneId != null) {
      droneId = singleDroneId!;
    } else {
      if (doc.droneFolder == null) {
        item.status = DroneImportItemStatus.failed;
        item.errorMessage = 'No drone folder found for "${doc.documentName}".';
        return;
      }
      final DroneMatch? match;
      try {
        match = await _firestore.findDroneByName(doc.droneFolder!);
      } on DroneImportException catch (e) {
        item.status = DroneImportItemStatus.failed;
        item.errorMessage = e.message;
        return;
      }
      if (match == null) {
        item.status = DroneImportItemStatus.failed;
        item.errorMessage = 'No matching drone found for "${doc.droneFolder}".';
        return;
      }
      droneId = match.droneId;
    }

    // 3. Save
    item.status = DroneImportItemStatus.saving;
    _emitProgress(currentFileName: doc.documentName, currentCategory: doc.category);

    try {
      final saveResult = await _firestore.saveUploadedDocument(
        droneId: droneId,
        categoryKey: doc.categoryKey,
        fileName: doc.documentName,
        secureUrl: secureUrl,
      );
      item.status = saveResult.status == DroneImportSaveStatus.created
          ? DroneImportItemStatus.success
          : DroneImportItemStatus.duplicateSkipped;
    } on DroneImportException catch (e) {
      item.status = DroneImportItemStatus.failed;
      item.errorMessage = e.message;
    }
  }

  void _emitProgress({String? currentFileName, String? currentCategory}) {
    final succeeded =
        _results.where((r) => r.status == DroneImportItemStatus.success).length;
    final duplicatesSkipped = _results
        .where((r) => r.status == DroneImportItemStatus.duplicateSkipped)
        .length;
    final failed =
        _results.where((r) => r.status == DroneImportItemStatus.failed).length;
    final cancelled =
        _results.where((r) => r.status == DroneImportItemStatus.cancelled).length;
    final processed = succeeded + duplicatesSkipped + failed + cancelled;

    _progressController.add(
      DroneImportProgress(
        total: _results.length,
        processed: processed,
        succeeded: succeeded,
        duplicatesSkipped: duplicatesSkipped,
        failed: failed,
        isScanning: _isScanning,
        isRunning: _isRunning,
        isCancelled: _cancelRequested,
        currentFileName: currentFileName,
        currentCategory: currentCategory,
      ),
    );
  }
}