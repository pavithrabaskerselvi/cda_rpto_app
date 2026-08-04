import 'package:cloud_firestore/cloud_firestore.dart';

/// CompanyService
/// ASSUMPTIONS:
///   collection: "companies"
///   fields: { name, address, contactEmail, contactPhone,
///     gstNumber, status ('active' | 'inactive'), createdAt }
class CompanyService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _ref = _firestore.collection('companies');

  static Future<String?> addCompany(Map<String, dynamic> data) async {
    try {
      data['createdAt'] = DateTime.now().toIso8601String();
      await _ref.add(data);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<Map<String, dynamic>?> getCompany(String companyId) async {
    final doc = await _ref.doc(companyId).get();
    if (!doc.exists) return null;
    return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
  }

  static Stream<List<Map<String, dynamic>>> streamCompanies({
    String? status,
  }) {
    Query query = _ref;
    if (status != null) query = query.where('status', isEqualTo: status);

    return query.orderBy('name').snapshots().map((snap) => snap.docs
        .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
        .toList());
  }

  static Future<String?> updateCompany(
      String companyId, Map<String, dynamic> data) async {
    try {
      await _ref.doc(companyId).update(data);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<String?> deleteCompany(String companyId) async {
    try {
      await _ref.doc(companyId).delete();
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}