import 'package:cloud_firestore/cloud_firestore.dart';

/// LogbookService
/// ASSUMPTIONS:
///   collection: "logbook_entries"
///   fields: { studentId, droneId, instructorId, batchId,
///     flightDate, durationMinutes, flightType ('training'|'solo'|'check_ride'),
///     remarks, signedOff (bool), signedOffBy, createdAt }
class LogbookService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _ref =
  _firestore.collection('logbook_entries');

  static Future<String?> addEntry(Map<String, dynamic> data) async {
    try {
      data['createdAt'] = DateTime.now().toIso8601String();
      data['signedOff'] ??= false;
      await _ref.add(data);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<Map<String, dynamic>?> getEntry(String entryId) async {
    final doc = await _ref.doc(entryId).get();
    if (!doc.exists) return null;
    return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
  }

  static Stream<List<Map<String, dynamic>>> streamEntries({
    String? studentId,
    String? droneId,
    String? batchId,
  }) {
    Query query = _ref;
    if (studentId != null) {
      query = query.where('studentId', isEqualTo: studentId);
    }
    if (droneId != null) query = query.where('droneId', isEqualTo: droneId);
    if (batchId != null) query = query.where('batchId', isEqualTo: batchId);

    return query
        .orderBy('flightDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs
        .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
        .toList());
  }

  static Future<String?> updateEntry(
      String entryId, Map<String, dynamic> data) async {
    try {
      await _ref.doc(entryId).update(data);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<String?> signOffEntry(
      String entryId, String signedOffBy) async {
    try {
      await _ref.doc(entryId).update({
        'signedOff': true,
        'signedOffBy': signedOffBy,
        'signedOffAt': DateTime.now().toIso8601String(),
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<String?> deleteEntry(String entryId) async {
    try {
      await _ref.doc(entryId).delete();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Sum total minutes flown by a student (client-side aggregation).
  static Future<double> totalMinutesForStudent(String studentId) async {
    final snap = await _ref.where('studentId', isEqualTo: studentId).get();
    double total = 0;
    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      total += (data['durationMinutes'] as num?)?.toDouble() ?? 0;
    }
    return total;
  }
}