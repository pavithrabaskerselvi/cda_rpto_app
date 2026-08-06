import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../config/drone_document_categories.dart';
import '../models/drone_document_model.dart';

/// DroneFolderScannerService
/// ---------------------------
/// Walks the root folder the admin picks and returns every real file
/// found (any extension — this folder holds photos, PDFs, warranty
/// cards etc., not just PDFs).
///
/// Supports two folder shapes, auto-detected by depth — same idea as
/// FolderScannerService for students:
///   - 2 levels: root -> Category folder -> files   (single drone —
///     the root IS that drone's folder, e.g. "1.SMALL")
///   - 3 levels: root -> Drone folder -> Category folder -> files
///     (many drones under one root)
///
/// Returns [DroneDocument] (see models/drone_document_model.dart).
///
/// ASSUMPTIONS:
///   - Desktop: admin picks the root folder via
///     `FilePicker.platform.getDirectoryPath()`.
///   - Web: caller obtains the file list itself (webkitdirectory input,
///     see services/web_folder_picker/) and passes in PlatformFiles
///     whose `identifier` encodes the relative path.
///   - Hidden/system files (.DS_Store, Thumbs.db, desktop.ini) are
///     silently skipped.
///   - The category (Drive folder name) is classified into a
///     DroneDocCategories key via [DroneDocCategories.classify] —
///     update that file's matchTokens if a real folder isn't being
///     recognised.
class DroneFolderScannerService {
  DroneFolderScannerService._();

  /// Entry point for Desktop (Windows/macOS/Linux).
  static Future<List<DroneDocument>> scanDesktopRoot(String rootPath) async {
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

    final results = <DroneDocument>[];

    final level1Entries =
    await rootDir.list(recursive: false, followLinks: false).toList();
    final level1Dirs = level1Entries.whereType<Directory>().toList();

    // Detect shape: if every level-1 directory's own children are all
    // files (no subdirectories), this is the flat "Category/File"
    // shape (single drone). Otherwise assume "Drone/Category/File".
    var isFlatCategoryShape = true;
    for (final dir in level1Dirs) {
      final children = await dir.list(recursive: false, followLinks: false).toList();
      if (children.any((c) => c is Directory)) {
        isFlatCategoryShape = false;
        break;
      }
    }

    if (isFlatCategoryShape) {
      // root -> Category folder -> files
      for (final categoryEntry in level1Dirs) {
        final categoryFolderName = _lastSegment(categoryEntry.path);
        final category = DroneDocCategories.classify(categoryFolderName);

        final fileEntries =
        await categoryEntry.list(recursive: false, followLinks: false).toList();
        for (final fileEntry in fileEntries) {
          if (fileEntry is! File) continue;
          if (_isIgnored(fileEntry.path)) continue;

          final doc = await _readAsDroneDocument(
            fileEntry: fileEntry,
            droneFolderName: null,
            categoryFolderName: categoryFolderName,
            categoryKey: category.key,
          );
          if (doc != null) results.add(doc);
        }
      }
      return results;
    }

    // root -> Drone folder -> Category folder -> files
    for (final droneEntry in level1Dirs) {
      final droneFolderName = _lastSegment(droneEntry.path);

      final categoryEntries =
      await droneEntry.list(recursive: false, followLinks: false).toList();
      for (final categoryEntry in categoryEntries) {
        if (categoryEntry is! Directory) continue;
        final categoryFolderName = _lastSegment(categoryEntry.path);
        final category = DroneDocCategories.classify(categoryFolderName);

        final fileEntries =
        await categoryEntry.list(recursive: false, followLinks: false).toList();
        for (final fileEntry in fileEntries) {
          if (fileEntry is! File) continue;
          if (_isIgnored(fileEntry.path)) continue;

          final doc = await _readAsDroneDocument(
            fileEntry: fileEntry,
            droneFolderName: droneFolderName,
            categoryFolderName: categoryFolderName,
            categoryKey: category.key,
          );
          if (doc != null) results.add(doc);
        }
      }
    }

    return results;
  }

  static Future<DroneDocument?> _readAsDroneDocument({
    required File fileEntry,
    required String? droneFolderName,
    required String categoryFolderName,
    required String categoryKey,
  }) async {
    try {
      final bytes = await fileEntry.readAsBytes();
      final fileName = _lastSegment(fileEntry.path);

      return DroneDocument(
        droneFolder: droneFolderName,
        category: categoryFolderName,
        categoryKey: categoryKey,
        documentName: fileName,
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
      // whole scan.
      return null;
    }
  }

  /// Entry point for Flutter Web.
  ///
  /// [pickedFiles] must already contain every file from the picked root
  /// folder, each with bytes loaded (`withData: true` when picking) and
  /// a path-like identifier that preserves the folder structure —
  /// either "INSURANCE/policy.pdf" (flat, single drone) or
  /// "DRN-001/INSURANCE/policy.pdf" (multi-drone). Both are accepted;
  /// shape is detected per-file by segment count.
  static List<DroneDocument> scanWebFiles(List<PlatformFile> pickedFiles) {
    final results = <DroneDocument>[];

    for (final file in pickedFiles) {
      if (file.bytes == null) continue; // no data loaded, skip
      if (_isIgnored(file.name)) continue;

      final relativePath = _relativePathOf(file);
      final segments =
      relativePath.split('/').where((s) => s.trim().isNotEmpty).toList();

      String? droneFolderName;
      String categoryFolderName;
      String fileName;

      if (segments.length == 2) {
        // Category/File.ext — no drone level (single-drone import).
        categoryFolderName = segments[0];
        fileName = segments[1];
      } else if (segments.length == 3) {
        // Drone/Category/File.ext
        droneFolderName = segments[0];
        categoryFolderName = segments[1];
        fileName = segments[2];
      } else {
        continue; // unexpected depth, skip
      }

      final category = DroneDocCategories.classify(categoryFolderName);

      results.add(
        DroneDocument(
          droneFolder: droneFolderName,
          category: categoryFolderName,
          categoryKey: category.key,
          documentName: fileName,
          localFile: file,
          size: file.size,
          extension: _extensionOf(fileName),
        ),
      );
    }

    return results;
  }

  // ---- helpers ----------------------------------------------------------

  static bool _isIgnored(String pathOrName) {
    final name = _lastSegment(pathOrName).toLowerCase();
    return name == '.ds_store' ||
        name == 'thumbs.db' ||
        name == 'desktop.ini' ||
        name.startsWith('.');
  }

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

  /// Resolves the relative path for a web-picked file. Prefers
  /// `identifier` (the web folder picker stuffs the relative path
  /// there); falls back to `name` if the picker already gives the full
  /// relative path in the name field.
  static String _relativePathOf(PlatformFile file) {
    final candidate = file.identifier ?? file.name;
    return candidate.replaceAll('\\', '/');
  }
}