import 'package:cloud_firestore/cloud_firestore.dart';

/// DocumentService
/// ASSUMPTIONS:
///   collection: "documents"
///   fields: { ownerId (studentId or instructorId), ownerType ('student'|'instructor'),
///     docType ('id_proof'|'certificate'|'medical'|'other'),
///     fileName, secureUrl, publicId, resourceType, format,
///     status ('pending'|'verified'|'rejected'),
///     uploadedAt, verifiedBy }
///
/// CHANGED: secureUrl/publicId replace the earlier Firebase-Storage-style
/// storagePath, to match CloudinaryService.uploadFile()'s return shape.
class DocumentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _ref = _firestore.collection('documents');

  /// Save a document record after a successful CloudinaryService upload.
  /// Pass the map returned by CloudinaryService.uploadFile() directly
  /// as [uploadResult].
  static Future<String?> addDocument({
    required String ownerId,
    required String ownerType, // 'student' | 'instructor'
    required String docType, // 'id_proof' | 'certificate' | 'medical' | 'other'
    required String fileName,
    required Map<String, String> uploadResult, // from CloudinaryService
  }) async {
    try {
      await _ref.add({
        'ownerId': ownerId,
        'ownerType': ownerType,
        'docType': docType,
        'fileName': fileName,
        'secureUrl': uploadResult['secureUrl'],
        'publicId': uploadResult['publicId'],
        'resourceType': uploadResult['resourceType'],
        'format': uploadResult['format'],
        'status': 'pending',
        'uploadedAt': DateTime.now().toIso8601String(),
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<Map<String, dynamic>?> getDocument(String documentId) async {
    final doc = await _ref.doc(documentId).get();
    if (!doc.exists) return null;
    return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
  }

  static Stream<List<Map<String, dynamic>>> streamDocuments({
    String? ownerId,
    String? docType,
    String? status,
  }) {
    Query query = _ref;
    if (ownerId != null) query = query.where('ownerId', isEqualTo: ownerId);
    if (docType != null) query = query.where('docType', isEqualTo: docType);
    if (status != null) query = query.where('status', isEqualTo: status);

    return query
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
        .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
        .toList());
  }

  static Future<String?> updateDocument(
      String documentId, Map<String, dynamic> data) async {
    try {
      await _ref.doc(documentId).update(data);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<String?> verifyDocument(
      String documentId, String verifiedBy) async {
    try {
      await _ref.doc(documentId).update({
        'status': 'verified',
        'verifiedBy': verifiedBy,
        'verifiedAt': DateTime.now().toIso8601String(),
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<String?> rejectDocument(String documentId,
      {String? reason}) async {
    try {
      await _ref.doc(documentId).update({
        'status': 'rejected',
        'rejectionReason': reason,
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Deletes the Firestore metadata doc only. The Cloudinary file itself
  /// needs a signed delete - see CloudinaryService.deleteFile() and its
  /// note about needing a backend endpoint.
  static Future<String?> deleteDocument(String documentId) async {
    try {
      await _ref.doc(documentId).delete();
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}