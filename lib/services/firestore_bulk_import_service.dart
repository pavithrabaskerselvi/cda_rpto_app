import 'package:cloud_firestore/cloud_firestore.dart';

/// Thrown for genuine Firestore failures (permission, network, etc).
/// Expected outcomes like "no student found" or "duplicate skipped" are
/// returned as normal values, not exceptions.
class FirestoreImportException implements Exception {
  final String message;
  final Object? cause;

  FirestoreImportException(this.message, {this.cause});

  @override
  String toString() => 'FirestoreImportException: $message';
}

/// Result of a single name lookup.
class StudentMatch {
  final String studentId;
  final String studentName;

  const StudentMatch({required this.studentId, required this.studentName});
}

enum ImportSaveStatus { created, duplicateSkipped }

/// Result of attempting to save one uploaded document URL.
class ImportSaveResult {
  final ImportSaveStatus status;
  final String? documentId; // set for both created and duplicateSkipped

  const ImportSaveResult({required this.status, this.documentId});
}

/// FirestoreBulkImportService
/// ----------------------------
/// Firestore-only side of the bulk import pipeline. Takes an already
/// uploaded secure URL (produced elsewhere, e.g. CloudinaryUploadService)
/// and:
///   - resolves a folder/student name to an existing student record
///   - writes it into the "documents" collection, matching the shape
///     already used by DocumentService
///   - refuses to create a second record for the same student + file
///   - keeps an uploadedAt/lastSeenAt timestamp current either way
///
/// ASSUMPTIONS:
///   - "students" collection has a "name" field.
///   - "documents" collection fields match DocumentService: ownerId,
///     ownerType, docType, fileName, secureUrl, status, uploadedAt.
///   - Duplicate = same ownerId + fileName already present in
///     "documents". If your real schema needs docType included in the
///     duplicate key too, extend the query in [_findExisting].
class FirestoreBulkImportService {
  final FirebaseFirestore _firestore;

  FirestoreBulkImportService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _studentsRef => _firestore.collection('students');
  CollectionReference get _documentsRef => _firestore.collection('documents');

  /// Finds a student whose stored name matches [rawName] once both are
  /// normalized (case-insensitive, leading numbering like "01." or "01)"
  /// stripped, whitespace collapsed). Returns null if no student matches.
  ///
  /// Loads the full students collection once per call. Callers doing many
  /// lookups in one import run should cache/reuse results themselves.
  Future<StudentMatch?> findStudentByName(String rawName) async {
    final QuerySnapshot snapshot;
    try {
      snapshot = await _studentsRef.get();
    } catch (e) {
      throw FirestoreImportException(
        'Failed to load students collection.',
        cause: e,
      );
    }

    final target = _normalize(rawName);
    if (target.isEmpty) return null;

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final name = data['name'] as String? ?? '';
      if (_normalize(name) == target) {
        return StudentMatch(studentId: doc.id, studentName: name);
      }
    }

    return null;
  }

  /// Saves one uploaded document URL for a student.
  ///
  /// - If a document with the same [studentId] + [fileName] already
  ///   exists, no new record is created; instead its uploadedAt/lastSeenAt
  ///   timestamp is refreshed and [ImportSaveStatus.duplicateSkipped] is
  ///   returned.
  /// - Otherwise a new "documents" record is created with a fresh
  ///   uploadedAt timestamp and [ImportSaveStatus.created] is returned.
  Future<ImportSaveResult> saveUploadedDocument({
    required String studentId,
    required String docType,
    required String fileName,
    required String secureUrl,
  }) async {
    final existingId = await _findExisting(
      studentId: studentId,
      fileName: fileName,
    );

    if (existingId != null) {
      await _touchTimestamp(existingId);
      return ImportSaveResult(
        status: ImportSaveStatus.duplicateSkipped,
        documentId: existingId,
      );
    }

    try {
      final docRef = await _documentsRef.add({
        'ownerId': studentId,
        'ownerType': 'student',
        'docType': docType,
        'fileName': fileName,
        'secureUrl': secureUrl,
        'status': 'pending',
        'uploadedAt': FieldValue.serverTimestamp(),
      });
      return ImportSaveResult(
        status: ImportSaveStatus.created,
        documentId: docRef.id,
      );
    } catch (e) {
      throw FirestoreImportException(
        'Failed to save document record for "$fileName".',
        cause: e,
      );
    }
  }

  // ---- helpers ------------------------------------------------------

  Future<String?> _findExisting({
    required String studentId,
    required String fileName,
  }) async {
    try {
      final snapshot = await _documentsRef
          .where('ownerId', isEqualTo: studentId)
          .where('fileName', isEqualTo: fileName)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      return snapshot.docs.first.id;
    } catch (e) {
      throw FirestoreImportException(
        'Failed to check for duplicate "$fileName".',
        cause: e,
      );
    }
  }

  Future<void> _touchTimestamp(String documentId) async {
    try {
      await _documentsRef.doc(documentId).update({
        'uploadedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw FirestoreImportException(
        'Failed to update timestamp for existing document "$documentId".',
        cause: e,
      );
    }
  }

  String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceFirst(RegExp(r'^\d+\s*[.)-]?\s*'), '') // strip "01. "/"01) "
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}