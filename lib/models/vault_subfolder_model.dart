import 'package:cloud_firestore/cloud_firestore.dart';

/// A user-created subfolder inside a Vault category that supports
/// nesting (currently only 'audit_files'). Stored in the top-level
/// Firestore collection 'vault_subfolders'. Folders are recorded
/// explicitly (rather than inferred from file paths) so an empty
/// folder still shows up before any file is uploaded into it.
class VaultSubfolder {
  final String id;
  final String categoryKey;
  final String name;
  // Slash-joined path of the PARENT folder, '' if this folder sits
  // directly under the category root.
  final String parentPath;
  final DateTime createdAt;
  final String createdBy;

  const VaultSubfolder({
    required this.id,
    required this.categoryKey,
    required this.name,
    required this.parentPath,
    required this.createdAt,
    required this.createdBy,
  });

  /// This folder's own full path, e.g. '03-02-2026/CHECKLIST'.
  String get path => parentPath.isEmpty ? name : '$parentPath/$name';

  factory VaultSubfolder.fromMap(Map<String, dynamic> map, String documentId) {
    return VaultSubfolder(
      id: documentId,
      categoryKey: map['categoryKey'] ?? '',
      name: map['name'] ?? '',
      parentPath: map['parentPath'] ?? '',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      createdBy: map['createdBy'] ?? '',
    );
  }

  factory VaultSubfolder.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VaultSubfolder.fromMap(data, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'categoryKey': categoryKey,
      'name': name,
      'parentPath': parentPath,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
    };
  }
}
