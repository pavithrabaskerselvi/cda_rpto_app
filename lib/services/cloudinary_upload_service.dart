// lib/services/cloudinary_upload_service.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Thrown when a Cloudinary upload fails, including after the retry.
class CloudinaryUploadException implements Exception {
  final String message;
  final int? statusCode;
  final Object? cause;

  CloudinaryUploadException(this.message, {this.statusCode, this.cause});

  @override
  String toString() => 'CloudinaryUploadException: $message'
      '${statusCode != null ? ' (status $statusCode)' : ''}';
}

/// CloudinaryUploadService
/// ------------------------
/// Uploads a single PDF to Cloudinary via an unsigned upload preset and
/// returns the resulting secure URL. Fails fast with a typed exception
/// after one retry attempt.
///
/// ASSUMPTIONS:
///   - Cloud name / upload preset match the existing CloudinaryService
///     configuration (Settings -> Upload -> unsigned preset).
///   - Delete is intentionally not implemented (requires a signed
///     request with the API secret, which must not live in the client).
class CloudinaryUploadService {
  static const String _cloudName = 'vmi67fhz';
  static const String _uploadPreset = 'rpto_unsigned';

  static Uri get _uploadUrl =>
      Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/auto/upload');

  /// Uploads one PDF's raw bytes and returns its Cloudinary secure URL.
  ///
  /// Retries exactly once if the first attempt fails (network error,
  /// non-200 response, or malformed response body). If the retry also
  /// fails, throws a [CloudinaryUploadException].
  Future<String> uploadPdf({
    required Uint8List bytes,
    required String fileName,
    String folder = 'rpto_uploads',
  }) async {
    try {
      return await _attemptUpload(
        bytes: bytes,
        fileName: fileName,
        folder: folder,
      );
    } catch (_) {
      // First attempt failed — retry exactly once.
      try {
        return await _attemptUpload(
          bytes: bytes,
          fileName: fileName,
          folder: folder,
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
  }) async {
    final http.StreamedResponse streamedResponse;
    try {
      final request = http.MultipartRequest('POST', _uploadUrl)
        ..fields['upload_preset'] = _uploadPreset
        ..fields['folder'] = folder
        ..files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: fileName),
        );
      streamedResponse = await request.send();
    } catch (e) {
      throw CloudinaryUploadException(
        'Network error while uploading "$fileName".',
        cause: e,
      );
    }

    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      // Cloudinary error bodies look like: {"error":{"message":"..."}}.
      // Surface that instead of a generic status code so a size-cap
      // rejection reads as "File size too large..." not just "(400)".
      String? cloudinaryMessage;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['error'] is Map) {
          cloudinaryMessage = decoded['error']['message'] as String?;
        }
      } catch (_) {
        // Body wasn't JSON — fall through with no extra detail.
      }

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