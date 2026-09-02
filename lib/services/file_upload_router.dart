import 'dart:typed_data';

import 'b2_upload_service.dart';
import 'cloudinary_upload_service.dart';

class FileUploadRouter {
  static const int cloudinaryLimit = 10 * 1024 * 1024;

  final CloudinaryUploadService cloudinary;
  final B2UploadService b2;

  FileUploadRouter({
    required this.cloudinary,
    required this.b2,
  });

  Future<FileUploadResult> upload({
    required Uint8List bytes,
    required String fileName,
    String folder = 'rpto_uploads',
    String contentType = 'application/octet-stream',
    UploadProgressCallback? onProgress,
  }) async {
    if (bytes.isEmpty) {
      throw Exception('File is empty.');
    }

    // 10 MB or less → Cloudinary
    if (bytes.length <= cloudinaryLimit) {
      final url = await cloudinary.uploadPdf(
        bytes: bytes,
        fileName: fileName,
        folder: folder,
        onProgress: onProgress,
      );

      return FileUploadResult(
        storage: FileStorage.cloudinary,
        url: url,
        fileName: fileName,
        size: bytes.length,
      );
    }

    // Above 10 MB → Cloudflare Worker → Backblaze B2
    final result = await b2.uploadFile(
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
      onProgress: onProgress,
    );

    return FileUploadResult(
      storage: FileStorage.backblazeB2,
      url: result.key,
      fileName: result.fileName,
      size: result.size,
      contentType: result.contentType,
    );
  }
}

enum FileStorage {
  cloudinary,
  backblazeB2,
}

class FileUploadResult {
  final FileStorage storage;
  final String url;
  final String fileName;
  final int size;
  final String? contentType;

  const FileUploadResult({
    required this.storage,
    required this.url,
    required this.fileName,
    required this.size,
    this.contentType,
  });

  bool get isCloudinary =>
      storage == FileStorage.cloudinary;

  bool get isBackblazeB2 =>
      storage == FileStorage.backblazeB2;
}

