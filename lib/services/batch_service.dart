import 'package:cloud_firestore/cloud_firestore.dart';

import 'access_control_service.dart';

/// BatchService
/// ASSUMPTIONS:
///   collection: "batches"
///   fields: { name, companyId, startDate, endDate,
///     instructorIds (List<String>), studentIds (List<String>),
///     status ('upcoming' | 'ongoing' | 'completed'), createdAt }
class BatchService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _ref = _firestore.collection('batches');

  static Future<String?> addBatch(Map<String, dynamic> data) async {
    try {
      data['createdAt'] = DateTime.now().toIso8601String();
      data['studentIds'] ??= <String>[];
      data['instructorIds'] ??= <String>[];
      await _ref.add(data);
      await AccessControlService.logCurrentUserAction(
        action: 'batch_created',
        detail: 'Created batch "${data['name'] ?? ''}"',
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<Map<String, dynamic>?> getBatch(String batchId) async {
    final doc = await _ref.doc(batchId).get();
    if (!doc.exists) return null;
    return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
  }

  static Stream<List<Map<String, dynamic>>> streamBatches({
    String? companyId,
    String? status,
  }) {
    Query query = _ref;
    if (companyId != null) {
      query = query.where('companyId', isEqualTo: companyId);
    }
    if (status != null) query = query.where('status', isEqualTo: status);

    return query
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs
        .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
        .toList());
  }

  static Future<String?> updateBatch(
      String batchId, Map<String, dynamic> data) async {
    try {
      await _ref.doc(batchId).update(data);
      await AccessControlService.logCurrentUserAction(
        action: 'batch_updated',
        detail: 'Updated batch (id: $batchId)',
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<String?> deleteBatch(String batchId) async {
    try {
      await _ref.doc(batchId).delete();
      await AccessControlService.logCurrentUserAction(
        action: 'batch_deleted',
        detail: 'Deleted batch (id: $batchId)',
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<String?> addStudentToBatch(
      String batchId, String studentId) async {
    try {
      await _ref.doc(batchId).update({
        'studentIds': FieldValue.arrayUnion([studentId]),
      });
      await AccessControlService.logCurrentUserAction(
        action: 'batch_student_added',
        detail: 'Added a student to batch (id: $batchId)',
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<String?> removeStudentFromBatch(
      String batchId, String studentId) async {
    try {
      await _ref.doc(batchId).update({
        'studentIds': FieldValue.arrayRemove([studentId]),
      });
      await AccessControlService.logCurrentUserAction(
        action: 'batch_student_removed',
        detail: 'Removed a student from batch (id: $batchId)',
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<String?> addInstructorToBatch(
      String batchId, String instructorId) async {
    try {
      await _ref.doc(batchId).update({
        'instructorIds': FieldValue.arrayUnion([instructorId]),
      });
      await AccessControlService.logCurrentUserAction(
        action: 'batch_instructor_added',
        detail: 'Added an instructor to batch (id: $batchId)',
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
