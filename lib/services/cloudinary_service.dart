import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Handles unsigned uploads to Cloudinary directly from Flutter
/// (web, Android, iOS, desktop — all via bytes, so it works everywhere
/// including Flutter Web where dart:io File is unavailable).
///
/// ASSUMPTIONS — fill these in from your Cloudinary Console:
/// - Settings → Product Environment → Cloud name  → _cloudName
/// - Settings → Upload → Upload presets → your unsigned preset name → _uploadPreset
///
/// Delete is intentionally NOT implemented here: Cloudinary's destroy API
/// requires a signed request (API secret), which must never live in a
/// Flutter client. If you need delete, add a small Cloud Function that
/// does the signed destroy call and have the app call that instead.
class CloudinaryService {
  static const String _cloudName = 'vmi67fhz';
  static const String _uploadPreset = 'rpto_unsigned';
  static Uri get _uploadUrl =>
      Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/auto/upload');

  /// Uploads raw bytes (works on ALL platforms, including Flutter Web
  /// where file_picker only returns PlatformFile.bytes, not a path).
  ///
  /// [bytes]    - the file's raw bytes, e.g. `result.files.single.bytes!`
  /// [fileName] - original file name, e.g. `result.files.single.name`
  /// [folder]   - Cloudinary folder to organize uploads, e.g. 'rpto_students'
  ///
  /// Returns a map with 'secureUrl' and 'publicId' on success, or null on failure.
  static Future<String?> uploadDocument(
      Uint8List bytes,
      String fileName, {
        String folder = 'rpto_uploads',
      }) async {
    try {
      final request = http.MultipartRequest('POST', _uploadUrl)
        ..fields['upload_preset'] = _uploadPreset
        ..fields['folder'] = folder
        ..files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: fileName),
        );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        // Common causes: wrong _uploadPreset name, preset not set to
        // "unsigned", or wrong _cloudName.
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      // If you later need publicId too (e.g. for deletion via a Cloud
      // Function), switch this back to returning a Map and update the
      // screen to read result['secureUrl'] instead of using it directly.
      return data['secure_url'] as String;
    } catch (_) {
      return null;
    }
  }

  /// Convenience overload if you ever have a dart:io File instead of bytes
  /// (e.g. on Android/iOS/desktop where file_picker gives you a real path).
  /// NOT usable on Flutter Web — use [uploadDocument] with bytes there.
  static Future<Map<String, String>?> uploadFile(
      dynamic file, { // typed as dynamic to avoid a dart:io import here
        String folder = 'rpto_uploads',
      }) async {
    throw UnimplementedError(
      'Use uploadDocument(bytes, fileName: ...) instead — '
          'it works on every platform including web.',
    );
  }
}