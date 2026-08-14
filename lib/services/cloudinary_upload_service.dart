import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class CloudinaryUploadException implements Exception {
  final String message;
  final int? statusCode;
  final Object? cause;

  CloudinaryUploadException(this.message, {this.statusCode, this.cause});

  @override
  String toString() => 'CloudinaryUploadException: $message'
      '${statusCode != null ? ' (status $statusCode)' : ''}';
}

/// Fires as request bytes are handed off to the network layer.
/// [sent]/[total] are bytes. On Flutter Web this reflects bytes read
/// from the source stream, not confirmed network transfer — the
/// browser's XHR layer buffers before actually sending, so treat it as
/// an approximation, not a byte-accurate transfer meter.
typedef UploadProgressCallback = void Function(int sent, int total);

/// A [http.BaseClient] wrapper that reports byte-level progress as the
/// request body is read, by intercepting BaseRequest.finalize().
class _ProgressClient extends http.BaseClient {
  final http.Client _inner;
  final UploadProgressCallback? onProgress;

  _ProgressClient(this._inner, this.onProgress);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final byteStream = request.finalize();
    final total = request.contentLength ?? 0;
    var sent = 0;

    final tracked = byteStream.transform(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: (chunk, sink) {
          sent += chunk.length;
          if (total > 0) onProgress?.call(sent, total);
          sink.add(chunk);
        },
      ),
    );

    final streamedRequest = http.StreamedRequest(request.method, request.url)
      ..headers.addAll(request.headers)
      ..contentLength = total > 0 ? total : null;

    unawaited(
      tracked.listen(
        streamedRequest.sink.add,
        onDone: streamedRequest.sink.close,
        onError: streamedRequest.sink.addError,
        cancelOnError: true,
      ).asFuture(),
    );

    return _inner.send(streamedRequest);
  }

  @override
  void close() => _inner.close();
}

/// CloudinaryUploadService
/// ------------------------
/// Uploads a single PDF to Cloudinary via an unsigned upload preset and
/// returns the resulting secure URL. Fails fast with a typed exception
/// after one retry attempt.
class CloudinaryUploadService {
  static const String _cloudName = 'vmi67fhz';
  static const String _uploadPreset = 'rpto_unsigned';

  static Uri get _uploadUrl =>
      Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/auto/upload');

  /// Uploads one file's raw bytes and returns its Cloudinary secure
  /// URL. [onProgress] fires repeatedly during the upload with bytes
  /// sent vs. total. Retries exactly once on failure.
  Future<String> uploadPdf({
    required Uint8List bytes,
    required String fileName,
    String folder = 'rpto_uploads',
    UploadProgressCallback? onProgress,
  }) async {
    try {
      return await _attemptUpload(
        bytes: bytes,
        fileName: fileName,
        folder: folder,
        onProgress: onProgress,
      );
    } catch (_) {
      try {
        return await _attemptUpload(
          bytes: bytes,
          fileName: fileName,
          folder: folder,
          onProgress: onProgress,
        );
      } catch (e) {
        final reason = e is CloudinaryUploadException ? e.message : null;
        throw CloudinaryUploadException(
          reason != null
              ? 'Failed to upload "$fileName" after retry: $reason'
              : 'Failed to upload "$fileName" after retry.',
          statusCode: e is CloudinaryUploadException ? e.statusCode : null,
          cause: e,
        );
      }
    }
  }

  Future<String> _attemptUpload({
    required Uint8List bytes,
    required String fileName,
    required String folder,
    UploadProgressCallback? onProgress,
  }) async {
    final http.StreamedResponse streamedResponse;
    final client = _ProgressClient(http.Client(), onProgress);
    try {
      final request = http.MultipartRequest('POST', _uploadUrl)
        ..fields['upload_preset'] = _uploadPreset
        ..fields['folder'] = folder
        ..files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: fileName),
        );
      streamedResponse = await client.send(request);
    } catch (e) {
      throw CloudinaryUploadException(
        'Network error while uploading "$fileName".',
        cause: e,
      );
    } finally {
      client.close();
    }

    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      String? cloudinaryMessage;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['error'] is Map) {
          cloudinaryMessage = decoded['error']['message'] as String?;
        }
      } catch (_) {}

      throw CloudinaryUploadException(
        cloudinaryMessage != null
            ? 'Cloudinary rejected "$fileName": $cloudinaryMessage'
            : 'Cloudinary rejected "$fileName".',
        statusCode: response.statusCode,
        cause: response.body,
      );
    }

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw CloudinaryUploadException(
        'Could not parse Cloudinary response for "$fileName".',
        cause: e,
      );
    }

    final secureUrl = data['secure_url'];
    if (secureUrl is! String || secureUrl.isEmpty) {
      throw CloudinaryUploadException(
        'Cloudinary response for "$fileName" did not contain a secure_url.',
      );
    }

    return secureUrl;
  }
}