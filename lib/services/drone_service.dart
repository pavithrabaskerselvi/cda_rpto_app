import 'package:cloud_firestore/cloud_firestore.dart';

/// DroneService
/// ASSUMPTIONS:
///   collection: "drones"
///   fields: { model, registrationNumber (UIN), manufacturer, category
///     ('nano'|'micro'|'small'|'medium'|'large'), companyId,
///     status ('active'|'maintenance'|'retired'),
///     totalFlightHours, lastServiceDate, createdAt }
class DroneService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _ref = _firestore.collection('drones');

  static Future<String?> addDrone(Map<String, dynamic> data) async {
    try {
      data['createdAt'] = DateTime.now().toIso8601String();
      data['totalFlightHours'] ??= 0.0;
      await _ref.add(data);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<Map<String, dynamic>?> getDrone(String droneId) async {
    final doc = await _ref.doc(droneId).get();
    if (!doc.exists) return null;
    return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
  }

  /// Look up a drone by its registration number (UIN) rather than doc id
  static Future<Map<String, dynamic>?> getDroneByRegistration(
      String registrationNumber) async {
    final snap = await _ref
        .where('registrationNumber', isEqualTo: registrationNumber)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final d = snap.docs.first;
    return {'id': d.id, ...d.data() as Map<String, dynamic>};
  }

  static Stream<List<Map<String, dynamic>>> streamDrones({
    String? companyId,
    String? status,
  }) {
    Query query = _ref;
    if (companyId != null) {
      query = query.where('companyId', isEqualTo: companyId);
    }
    if (status != null) query = query.where('status', isEqualTo: status);

    return query.orderBy('model').snapshots().map((snap) => snap.docs
        .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
        .toList());
  }

  static Future<String?> updateDrone(
      String droneId, Map<String, dynamic> data) async {
    try {
      await _ref.doc(droneId).update(data);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<String?> deleteDrone(String droneId) async {
    try {
      await _ref.doc(droneId).delete();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<String?> addFlightHours(String droneId, double hours) async {
    try {
      await _ref.doc(droneId).update({
        'totalFlightHours': FieldValue.increment(hours),
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<String?> setStatus(String droneId, String status) async {
    try {
      await _ref.doc(droneId).update({'status': status});
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}