import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

/// Shared document-upload helper (used by the Zone > Facility module).
///
/// Same Cloudinary cloud + unsigned preset as CloudinaryUploadService, but:
///  * 90 s timeout so the UI can never hang forever
///  * retries without a custom folder if the preset rejects it
///  * retries once on a network error
///  * throws the REAL Cloudinary error message so it can be shown
class DocUploadHelper {
  DocUploadHelper._();

  static const int maxBytes = 10 * 1024 * 1024; // 10 MB
  static const List<String> allowedExtensions = [
    'pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'
  ];

  static const String _cloud = 'vmi67fhz';
  static const String _preset = 'rpto_unsigned';

  /// Opens the file picker (multi-select, bytes loaded for web support).
  static Future<List<PlatformFile>> pickFiles() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );
    if (res == null) return [];
    return res.files;
  }

  /// Uploads one file and returns its secure URL.
  static Future<String> upload({
    required Uint8List bytes,
    required String fileName,
    required String folder,
  }) async {
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$_cloud/auto/upload');

    Future<http.Response> attempt({required bool withFolder}) async {
      final req = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _preset
        ..files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: fileName));
      if (withFolder) req.fields['folder'] = folder;
      final streamed = await req.send().timeout(const Duration(seconds: 90));
      return http.Response.fromStream(streamed);
    }

    http.Response res;
    try {
      res = await attempt(withFolder: true);
    } on TimeoutException {
      throw Exception('Upload timed out - check your internet and try again');
    } catch (_) {
      // one retry on a network blip
      res = await attempt(withFolder: true);
    }

    if (res.statusCode != 200) {
      // Some unsigned presets reject a custom folder - retry without it.
      res = await attempt(withFolder: false);
    }

    if (res.statusCode != 200) {
      var msg = 'status ${res.statusCode}';
      try {
        final j = jsonDecode(res.body);
        if (j is Map && j['error'] is Map) {
          msg = j['error']['message'].toString();
        }
      } catch (_) {}
      throw Exception(msg);
    }

    final url = (jsonDecode(res.body) as Map)['secure_url'];
    if (url is! String || url.isEmpty) {
      throw Exception('Cloudinary did not return a URL');
    }
    return url;
  }
}
