import 'package:cloud_firestore/cloud_firestore.dart';

/// One uploaded file living inside the RPTO Vault module.
/// Stored in the top-level Firestore collection 'vault_documents'.
class VaultDocument {
  final String id;
  final String categoryKey; // see VaultCategories, e.g. 'audit_files'
  final String fileName;
  final String url; // secure URL returned by CloudinaryUploadService
  final String extension;
  final int size; // bytes
  final String uploadedBy; // uid or display name
  final DateTime uploadedAt;

  const VaultDocument({
    required this.id,
    required this.categoryKey,
    required this.fileName,
    required this.url,
    required this.extension,
    required this.size,
    required this.uploadedBy,
    required this.uploadedAt,
  });

  factory VaultDocument.fromMap(Map<String, dynamic> map, String documentId) {
    return VaultDocument(
      id: documentId,
      categoryKey: map['categoryKey'] ?? '',
      fileName: map['fileName'] ?? '',
      url: map['url'] ?? '',
      extension: map['extension'] ?? '',
      size: map['size'] ?? 0,
      uploadedBy: map['uploadedBy'] ?? '',
      uploadedAt: map['uploadedAt'] != null
          ? (map['uploadedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  factory VaultDocument.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VaultDocument.fromMap(data, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'categoryKey': categoryKey,
      'fileName': fileName,
      'url': url,
      'extension': extension,
      'size': size,
      'uploadedBy': uploadedBy,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
    };
  }
}
