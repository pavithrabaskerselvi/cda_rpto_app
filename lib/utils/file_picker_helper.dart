import 'package:file_picker/file_picker.dart';

/// Wraps the `file_picker` package with app-specific defaults.
///
/// IMPORTANT: Returns PlatformFile (with .bytes and .name), NOT a dart:io
/// File. This is required for Flutter Web support, where file paths don't
/// exist — only in-memory bytes are available. Using `withData: true`
/// forces file_picker to load bytes on every platform (mobile/desktop
/// normally give you a path instead, but we want bytes everywhere for a
/// single upload code path via CloudinaryService.uploadDocument()).
class FilePickerHelper {
  FilePickerHelper._(); // static-only class

  /// Picks a single document: pdf, jpg, png, doc, docx.
  /// Returns null if the user cancels.
  static Future<PlatformFile?> pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
      allowMultiple: false,
      withData: true, // forces .bytes to be populated on all platforms
    );
    if (result == null || result.files.single.bytes == null) return null;
    return result.files.single;
  }

  /// Picks a single image only (e.g. profile photo).
  static Future<PlatformFile?> pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return null;
    return result.files.single;
  }

  /// Picks multiple documents at once.
  static Future<List<PlatformFile>> pickMultipleDocuments() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return [];
    return result.files.where((f) => f.bytes != null).toList();
  }

  /// Returns file size in a human-readable string, e.g. "2.3 MB".
  static String formatFileSize(PlatformFile file) {
    final bytes = file.size;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Basic extension check, e.g. before allowing upload.
  static bool isAllowedExtension(PlatformFile file, List<String> allowed) {
    final ext = (file.extension ?? '').toLowerCase();
    return allowed.map((e) => e.toLowerCase()).contains(ext);
  }
}