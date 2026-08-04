import 'package:cloud_firestore/cloud_firestore.dart';

/// InstructorService
/// ASSUMPTIONS:
///   collection: "instructors"
///   fields: { name, email, phone, licenseNumber, companyId,
///     specialization, assignedBatchIds (List<String>),
///     status ('active' | 'inactive'), createdAt }
class InstructorService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _ref = _firestore.collection('instructors');

  static Future<String?> addInstructor(Map<String, dynamic> data) async {
    try {
      data['createdAt'] = DateTime.now().toIso8601String();
      await _ref.add(data);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<Map<String, dynamic>?> getInstructor(
      String instructorId) async {
    final doc = await _ref.doc(instructorId).get();
    if (!doc.exists) return null;
    return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
  }

  static Stream<List<Map<String, dynamic>>> streamInstructors({
    String? companyId,
    String? status,
  }) {
    Query query = _ref;
    if (companyId != null) {
      query = query.where('companyId', isEqualTo: companyId);
    }
    if (status != null) query = query.where('status', isEqualTo: status);

    return query.orderBy('name').snapshots().map((snap) => snap.docs
        .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
        .toList());
  }

  static Future<String?> updateInstructor(
      String instructorId, Map<String, dynamic> data) async {
    try {
      await _ref.doc(instructorId).update(data);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<String?> deleteInstructor(String instructorId) async {
    try {
      await _ref.doc(instructorId).delete();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<String?> assignBatch(
      String instructorId, String batchId) async {
    try {
      await _ref.doc(instructorId).update({
        'assignedBatchIds': FieldValue.arrayUnion([batchId]),
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<String?> unassignBatch(
      String instructorId, String batchId) async {
    try {
      await _ref.doc(instructorId).update({
        'assignedBatchIds': FieldValue.arrayRemove([batchId]),
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}