import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

/// StorageService
/// ASSUMPTIONS:
///   - Storage bucket paths look like: "documents/{ownerId}/{fileName}"
///   - Caller is responsible for picking the file (see file_picker_helper.dart)
class StorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload a file. Returns null-error map on success:
  /// { 'downloadUrl': ..., 'storagePath': ... } or throws - caller should
  /// wrap in try/catch to match the rest of the app's error handling.
  static Future<Map<String, String>> uploadFile({
    required String folder,
    required String ownerId,
    required File file,
    String? customFileName,
    void Function(double progress)? onProgress,
  }) async {
    final fileName = customFileName ??
        '${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}';
    final storagePath = '$folder/$ownerId/$fileName';

    final ref = _storage.ref().child(storagePath);
    final uploadTask = ref.putFile(file);

    if (onProgress != null) {
      uploadTask.snapshotEvents.listen((snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress(progress);
      });
    }

    final snapshot = await uploadTask;
    final downloadUrl = await snapshot.ref.getDownloadURL();

    return {
      'downloadUrl': downloadUrl,
      'storagePath': storagePath,
    };
  }

  /// Upload raw bytes (useful for web, where you may not have a File)
  static Future<Map<String, String>> uploadBytes({
    required String folder,
    required String ownerId,
    required List<int> bytes,
    required String fileName,
    String? contentType,
  }) async {
    final storagePath = '$folder/$ownerId/$fileName';
    final ref = _storage.ref().child(storagePath);

    final metadata = contentType != null
        ? SettableMetadata(contentType: contentType)
        : null;

    final uploadTask = ref.putData(Uint8List.fromList(bytes), metadata);
    final snapshot = await uploadTask;
    final downloadUrl = await snapshot.ref.getDownloadURL();

    return {
      'downloadUrl': downloadUrl,
      'storagePath': storagePath,
    };
  }

  static Future<void> deleteFile(String storagePath) async {
    await _storage.ref().child(storagePath).delete();
  }

  static Future<String> getDownloadUrl(String storagePath) {
    return _storage.ref().child(storagePath).getDownloadURL();
  }
}