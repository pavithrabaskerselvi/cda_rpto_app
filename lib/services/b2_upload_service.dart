import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class B2UploadException implements Exception {
  final String message;
  final int? statusCode;

  B2UploadException(
      this.message, {
        this.statusCode,
      });

  @override
  String toString() {
    return 'B2UploadException: $message'
        '${statusCode != null ? ' (status $statusCode)' : ''}';
  }
}

typedef B2UploadProgressCallback = void Function(
    int sent,
    int total,
    );

class B2UploadService {
  static const String workerUrl =
      'https://cda-rpto-b2-upload.pavithrabaskerselvi.workers.dev';

  static const int minFileSize = 10 * 1024 * 1024;
  static const int maxFileSize = 100 * 1024 * 1024;

  Future<B2UploadResult> uploadFile({
    required Uint8List bytes,
    required String fileName,
    String contentType = 'application/octet-stream',
    B2UploadProgressCallback? onProgress,
  }) async {
    if (bytes.isEmpty) {
      throw B2UploadException(
        'Cannot upload an empty file.',
      );
    }

    if (bytes.length <= minFileSize) {
      throw B2UploadException(
        'B2 upload is only for files larger than 10 MB.',
      );
    }

    if (bytes.length > maxFileSize) {
      throw B2UploadException(
        'File is larger than the 100 MB Worker limit.',
      );
    }

    final request = http.StreamedRequest(
      'POST',
      Uri.parse(workerUrl),
    );

    request.headers['Content-Type'] = contentType;
    request.headers['X-Filename'] = fileName;
    request.headers['Content-Length'] = bytes.length.toString();
    request.contentLength = bytes.length;

    var sent = 0;

    try {
      const chunkSize = 64 * 1024;

      for (var offset = 0; offset < bytes.length; offset += chunkSize) {
        final end = (offset + chunkSize < bytes.length)
            ? offset + chunkSize
            : bytes.length;

        final chunk = bytes.sublist(offset, end);

        request.sink.add(chunk);

        sent += chunk.length;
        onProgress?.call(sent, bytes.length);
      }

      await request.sink.close();

      final response = await request.send();

      final responseBody = await response.stream.bytesToString();

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        String message = 'Backblaze upload failed.';

        try {
          final decoded =
          jsonDecode(responseBody);

          if (decoded is Map &&
              decoded['error'] is String) {
            message = decoded['error'] as String;
          }
        } catch (_) {}

        throw B2UploadException(
          message,
          statusCode: response.statusCode,
        );
      }

      final decoded =
      jsonDecode(responseBody);

      if (decoded is! Map<String, dynamic>) {
        throw B2UploadException(
          'Invalid response from Cloudflare Worker.',
        );
      }

      if (decoded['ok'] != true) {
        throw B2UploadException(
          decoded['error']?.toString() ??
              'Backblaze upload failed.',
          statusCode: response.statusCode,
        );
      }

      final key = decoded['key'];

      if (key is! String || key.isEmpty) {
        throw B2UploadException(
          'Worker did not return the uploaded file key.',
        );
      }

      return B2UploadResult(
        key: key,
        fileName:
        decoded['filename']?.toString() ??
            fileName,
        size: decoded['size'] is int
            ? decoded['size'] as int
            : bytes.length,
        contentType:
        decoded['contentType']?.toString() ??
            contentType,
      );
    } on B2UploadException {
      rethrow;
    } catch (e) {
      throw B2UploadException(
        'Network error while uploading "$fileName".',
      );
    }
  }
}

class B2UploadResult {
  final String key;
  final String fileName;
  final int size;
  final String contentType;

  const B2UploadResult({
    required this.key,
    required this.fileName,
    required this.size,
    required this.contentType,
  });

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'fileName': fileName,
      'size': size,
      'contentType': contentType,
    };
  }
}