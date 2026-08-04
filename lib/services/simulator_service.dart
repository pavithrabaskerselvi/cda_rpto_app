import 'package:cloud_firestore/cloud_firestore.dart';

/// SimulatorService
/// ASSUMPTIONS:
///   collection: "simulator_sessions"
///   fields: { studentId, instructorId, batchId,
///     sessionDate, durationMinutes, simulatorType,
///     score, remarks, createdAt }
class SimulatorService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _ref =
  _firestore.collection('simulator_sessions');

  static Future<String?> addSession(Map<String, dynamic> data) async {
    try {
      data['createdAt'] = DateTime.now().toIso8601String();
      await _ref.add(data);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<Map<String, dynamic>?> getSession(String sessionId) async {
    final doc = await _ref.doc(sessionId).get();
    if (!doc.exists) return null;
    return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
  }

  static Stream<List<Map<String, dynamic>>> streamSessions({
    String? studentId,
    String? batchId,
  }) {
    Query query = _ref;
    if (studentId != null) {
      query = query.where('studentId', isEqualTo: studentId);
    }
    if (batchId != null) query = query.where('batchId', isEqualTo: batchId);

    return query
        .orderBy('sessionDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs
        .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
        .toList());
  }

  static Future<String?> updateSession(
      String sessionId, Map<String, dynamic> data) async {
    try {
      await _ref.doc(sessionId).update(data);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<String?> deleteSession(String sessionId) async {
    try {
      await _ref.doc(sessionId).delete();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Average score across a student's simulator sessions
  static Future<double?> averageScoreForStudent(String studentId) async {
    final snap = await _ref.where('studentId', isEqualTo: studentId).get();
    if (snap.docs.isEmpty) return null;

    double total = 0;
    int count = 0;
    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final score = (data['score'] as num?)?.toDouble();
      if (score != null) {
        total += score;
        count++;
      }
    }
    return count == 0 ? null : total / count;
  }
}