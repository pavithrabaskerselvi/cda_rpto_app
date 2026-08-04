import 'package:cloud_firestore/cloud_firestore.dart';

/// StudentService
/// --------------
/// ASSUMPTIONS (adjust to your real schema):
///   collection: "students"
///   fields: {
///     name, email, phone, batchId, companyId,
///     enrollmentDate, status ('active' | 'completed' | 'dropped'),
///     droneHoursLogged, createdAt
///   }
class StudentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _ref = _firestore.collection('students');

  /// Create a new student. Returns null on success, error message on failure.
  static Future<String?> addStudent(Map<String, dynamic> data) async {
    try {
      data['createdAt'] = DateTime.now().toIso8601String();
      await _ref.add(data);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<Map<String, dynamic>?> getStudent(String studentId) async {
    final doc = await _ref.doc(studentId).get();
    if (!doc.exists) return null;
    return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
  }

  static Stream<Map<String, dynamic>?> streamStudent(String studentId) {
    return _ref.doc(studentId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
    });
  }

  static Stream<List<Map<String, dynamic>>> streamStudents({
    String? batchId,
    String? companyId,
    String? status,
  }) {
    Query query = _ref;
    if (batchId != null) query = query.where('batchId', isEqualTo: batchId);
    if (companyId != null) {
      query = query.where('companyId', isEqualTo: companyId);
    }
    if (status != null) query = query.where('status', isEqualTo: status);

    return query.orderBy('name').snapshots().map((snap) => snap.docs
        .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
        .toList());
  }

  static Future<String?> updateStudent(
      String studentId, Map<String, dynamic> data) async {
    try {
      await _ref.doc(studentId).update(data);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<String?> deleteStudent(String studentId) async {
    try {
      await _ref.doc(studentId).delete();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<String?> assignToBatch(
      String studentId, String batchId) async {
    try {
      await _ref.doc(studentId).update({'batchId': batchId});
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Increment logged drone hours (e.g. after a logbook entry is added)
  static Future<String?> addLoggedHours(
      String studentId, double hours) async {
    try {
      await _ref.doc(studentId).update({
        'droneHoursLogged': FieldValue.increment(hours),
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<int> countByStatus(String status) async {
    final snap = await _ref.where('status', isEqualTo: status).count().get();
    return snap.count ?? 0;
  }
}