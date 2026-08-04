import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../models/student_document_model.dart';

/// FolderScannerService
/// ---------------------
/// Walks the root folder the admin picks and returns every PDF found.
///
/// Supports two folder shapes, auto-detected by depth:
///   - 2 levels: root -> Student folder -> *.pdf   (e.g. your
///     "6.Student wise folder" with student folders directly inside —
///     no batch grouping)
///   - 3 levels: root -> Batch folder -> Student folder -> *.pdf
///
/// Returns the canonical [StudentDocument] model (see
/// models/student_document_model.dart) — this file does NOT define its
/// own StudentDocument class, to avoid the duplicate-name conflict.
///
/// ASSUMPTIONS:
///   - Desktop: admin picks the root folder via
///     `FilePicker.platform.getDirectoryPath()`, which returns a real
///     filesystem path. We then walk it with dart:io `Directory`.
///   - Web: dart:io is unavailable, and browsers don't expose folder
///     paths — only file contents. The caller must obtain the file list
///     itself (e.g. a `webkitdirectory`-enabled file input) and pass in
///     PlatformFiles whose `identifier` (or `name`) encodes the relative
///     path (e.g. "01. JAGANATHAN/CC.pdf" or "Batch 1/01. JAGANATHAN/CC.pdf").
///     Adjust [_relativePathOf] if your picker exposes this differently.
///   - Only files with a `.pdf` extension (case-insensitive) are read;
///     everything else (`.DS_Store`, `Thumbs.db`, non-PDF files) is
///     silently skipped, not treated as an error.
///   - `documentType` is derived from the filename (see
///     [_classifyDocType]) — adjust the mapping to match your real
///     document categories.
///   - `studentName` is the student folder name with any leading
///     numbering ("01. ", "01) ") stripped; matching against Firestore
///     happens elsewhere (FirestoreBulkImportService), not here.
class FolderScannerService {
  FolderScannerService._();

  /// Entry point for Desktop (Windows/macOS/Linux).
  /// [rootPath] should come from `FilePicker.platform.getDirectoryPath()`.
  static Future<List<StudentDocument>> scanDesktopRoot(
      String rootPath,
      ) async {
    if (kIsWeb) {
      throw UnsupportedError(
        'scanDesktopRoot uses dart:io and cannot run on Flutter Web. '
            'Use scanWebFiles instead.',
      );
    }

    final rootDir = Directory(rootPath);
    if (!await rootDir.exists()) {
      throw ArgumentError('Root folder does not exist: $rootPath');
    }

    final results = <StudentDocument>[];

    final level1Entries =
    await rootDir.list(recursive: false, followLinks: false).toList();
    final level1Dirs = level1Entries.whereType<Directory>().toList();

    // Detect shape: if every level-1 directory's own children are all
    // PDFs (no subdirectories), this is the flat "Student/File.pdf"
    // shape. Otherwise assume "Batch/Student/File.pdf".
    var isFlatStudentShape = true;
    for (final dir in level1Dirs) {
      final children = await dir.list(recursive: false, followLinks: false).toList();
      if (children.any((c) => c is Directory)) {
        isFlatStudentShape = false;
        break;
      }
    }

    if (isFlatStudentShape) {
      // root -> Student folder -> *.pdf
      for (final studentEntry in level1Dirs) {
        final studentFolderName = _lastSegment(studentEntry.path);
        final studentName = _stripLeadingNumbering(studentFolderName);

        final fileEntries =
        await studentEntry.list(recursive: false, followLinks: false).toList();

        for (final fileEntry in fileEntries) {
          if (fileEntry is! File) continue;
          if (!_isPdf(fileEntry.path)) continue;

          final doc = await _readAsStudentDocument(
            fileEntry: fileEntry,
            batchFolderName: null,
            studentFolderName: studentFolderName,
            studentName: studentName,
          );
          if (doc != null) results.add(doc);
        }
      }
      return results;
    }

    // root -> Batch folder -> Student folder -> *.pdf
    for (final batchEntry in level1Dirs) {
      final batchFolderName = _lastSegment(batchEntry.path);

      final studentEntries = await batchEntry
          .list(recursive: false, followLinks: false)
          .toList();

      for (final studentEntry in studentEntries) {
        if (studentEntry is! Directory) continue;
        final studentFolderName = _lastSegment(studentEntry.path);
        final studentName = _stripLeadingNumbering(studentFolderName);

        final fileEntries = await studentEntry
            .list(recursive: false, followLinks: false)
            .toList();

        for (final fileEntry in fileEntries) {
          if (fileEntry is! File) continue;
          if (!_isPdf(fileEntry.path)) continue;

          final doc = await _readAsStudentDocument(
            fileEntry: fileEntry,
            batchFolderName: batchFolderName,
            studentFolderName: studentFolderName,
            studentName: studentName,
          );
          if (doc != null) results.add(doc);
        }
      }
    }

    return results;
  }

  static Future<StudentDocument?> _readAsStudentDocument({
    required File fileEntry,
    required String? batchFolderName,
    required String studentFolderName,
    required String studentName,
  }) async {
    try {
      final bytes = await fileEntry.readAsBytes();
      final fileName = _lastSegment(fileEntry.path);

      return StudentDocument(
        batchName: batchFolderName,
        studentName: studentName,
        studentFolder: studentFolderName,
        documentName: fileName,
        documentType: _classifyDocType(fileName),
        localFile: PlatformFile(
          name: fileName,
          size: bytes.length,
          bytes: bytes,
          path: fileEntry.path,
        ),
        size: bytes.length,
        extension: _extensionOf(fileName),
      );
    } catch (_) {
      // Corrupted/unreadable file: skip it rather than aborting the
      // whole scan. Caller-facing error reporting happens one layer
      // up (upload/orchestration service), not here.
      return null;
    }
  }

  /// Entry point for Flutter Web.
  ///
  /// [pickedFiles] must already contain every file from the picked root
  /// folder, each with bytes loaded (`withData: true` when picking) and
  /// a path-like identifier that preserves the folder structure —
  /// either "01. JAGANATHAN/CC.pdf" (flat) or
  /// "Batch 1/01. JAGANATHAN/CC.pdf" (batched). Both are accepted;
  /// shape is detected per-file by segment count.
  static List<StudentDocument> scanWebFiles(List<PlatformFile> pickedFiles) {
    final results = <StudentDocument>[];

    for (final file in pickedFiles) {
      if (file.bytes == null) continue; // no data loaded, skip
      if (!_isPdf(file.name)) continue;

      final relativePath = _relativePathOf(file);
      final segments =
      relativePath.split('/').where((s) => s.trim().isNotEmpty).toList();

      String? batchFolderName;
      String studentFolderName;
      String fileName;

      if (segments.length == 2) {
        // Student/File.pdf — no batch level.
        studentFolderName = segments[0];
        fileName = segments[1];
      } else if (segments.length == 3) {
        // Batch/Student/File.pdf
        batchFolderName = segments[0];
        studentFolderName = segments[1];
        fileName = segments[2];
      } else {
        continue; // unexpected depth, skip
      }

      results.add(
        StudentDocument(
          batchName: batchFolderName,
          studentName: _stripLeadingNumbering(studentFolderName),
          studentFolder: studentFolderName,
          documentName: fileName,
          documentType: _classifyDocType(fileName),
          localFile: file,
          size: file.size,
          extension: _extensionOf(fileName),
        ),
      );
    }

    return results;
  }

  // ---- helpers ----------------------------------------------------------

  static bool _isPdf(String pathOrName) =>
      pathOrName.toLowerCase().endsWith('.pdf');

  static String _extensionOf(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == fileName.length - 1) return '';
    return fileName.substring(dotIndex + 1).toLowerCase();
  }

  static String _lastSegment(String path) {
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/').where((p) => p.isNotEmpty).toList();
    return parts.isEmpty ? path : parts.last;
  }

  static String _stripLeadingNumbering(String folderName) {
    return folderName
        .trim()
        .replaceFirst(RegExp(r'^\d+\s*[.)-]?\s*'), '') // "01. " / "01) "
        .trim();
  }

  /// Maps a filename to a docType understood by FirestoreBulkImportService
  /// / DocumentService. Adjust to match your real document categories.
  static String _classifyDocType(String fileName) {
    final base = fileName.toLowerCase().replaceAll('.pdf', '').trim();
    switch (base) {
      case 'cc':
        return 'certificate';
      case 'logbook':
        return 'logbook';
      case 'rpc':
        return 'rpc';
      case 'mc':
        return 'medical';
      case 'payment receipt':
        return 'payment_receipt';
      case 'skill test':
        return 'skill_test';
      default:
        return 'other';
    }
  }

  /// Resolves the relative path for a web-picked file. Prefers
  /// `identifier` (the web folder picker stuffs the relative path
  /// there); falls back to `name` if the picker already gives the full
  /// relative path in the name field.
  static String _relativePathOf(PlatformFile file) {
    final candidate = file.identifier ?? file.name;
    return candidate.replaceAll('\\', '/');
  }
}