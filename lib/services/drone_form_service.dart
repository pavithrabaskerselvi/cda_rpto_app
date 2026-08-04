import 'package:cloud_firestore/cloud_firestore.dart';

/// DroneFormService
/// ASSUMPTIONS:
///   collection: "drone_forms"
///   fields: { formType ('registration'|'rpc_application'|'insurance'|'other'),
///     droneId, studentId, companyId,
///     status ('draft'|'submitted'|'approved'|'rejected'),
///     submittedAt, reviewedBy, reviewNotes,
///     attachmentUrls (List<String>), createdAt }
class DroneFormService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _ref = _firestore.collection('drone_forms');

  static Future<String?> addForm(Map<String, dynamic> data) async {
    try {
      data['createdAt'] = DateTime.now().toIso8601String();
      data['status'] ??= 'draft';
      await _ref.add(data);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<Map<String, dynamic>?> getForm(String formId) async {
    final doc = await _ref.doc(formId).get();
    if (!doc.exists) return null;
    return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
  }

  static Stream<List<Map<String, dynamic>>> streamForms({
    String? droneId,
    String? studentId,
    String? status,
    String? formType,
  }) {
    Query query = _ref;
    if (droneId != null) query = query.where('droneId', isEqualTo: droneId);
    if (studentId != null) {
      query = query.where('studentId', isEqualTo: studentId);
    }
    if (status != null) query = query.where('status', isEqualTo: status);
    if (formType != null) {
      query = query.where('formType', isEqualTo: formType);
    }

    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
        .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
        .toList());
  }

  static Future<String?> updateForm(
      String formId, Map<String, dynamic> data) async {
    try {
      await _ref.doc(formId).update(data);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<String?> submitForm(String formId) async {
    try {
      await _ref.doc(formId).update({
        'status': 'submitted',
        'submittedAt': DateTime.now().toIso8601String(),
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<String?> reviewForm({
    required String formId,
    required bool approved,
    required String reviewedBy,
    String? notes,
  }) async {
    try {
      await _ref.doc(formId).update({
        'status': approved ? 'approved' : 'rejected',
        'reviewedBy': reviewedBy,
        'reviewNotes': notes,
        'reviewedAt': DateTime.now().toIso8601String(),
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<String?> deleteForm(String formId) async {
    try {
      await _ref.doc(formId).delete();
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}