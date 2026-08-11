import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/analytics_summary_model.dart';
import '../models/fee_model.dart';

/// AnalyticsService
/// Static class, same style as batch_service.dart / fee_service.dart.
/// Reads existing collections (students, batches, instructors, drones,
/// simulators, fees) and computes rollups client-side — no new Firestore
/// writes, no new collections except what other modules already created.
class AnalyticsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Combines snapshots from every collection Analytics needs into one
  /// summary. Rebuilds whenever any source collection changes.
  static Stream<AnalyticsSummaryModel> streamOverviewSummary() {
    return _firestore.collection('students').snapshots().asyncMap((studentsSnap) async {
      final batchesSnap = await _firestore.collection('batches').get();
      final instructorsSnap = await _firestore.collection('instructors').get();
      final dronesSnap = await _firestore.collection('drones').get();
      final simsSnap = await _firestore.collection('simulators').get();
      final feesSnap = await _firestore.collection('fees').get();

      int active = 0, completed = 0, dropped = 0;
      for (final doc in studentsSnap.docs) {
        final status = (doc.data()['status'] ?? '') as String;
        if (status == 'Active') active++;
        if (status == 'Completed') completed++;
        if (status == 'Dropped') dropped++;
      }

      int ongoing = 0, upcoming = 0, batchCompleted = 0;
      for (final doc in batchesSnap.docs) {
        final status = (doc.data()['status'] ?? '') as String;
        if (status == 'Ongoing') ongoing++;
        if (status == 'Upcoming') upcoming++;
        if (status == 'Completed') batchCompleted++;
      }

      int activeInstructors = 0;
      for (final doc in instructorsSnap.docs) {
        if ((doc.data()['status'] ?? '') == 'Active') activeInstructors++;
      }

      double totalRevenue = 0;
      final feesByStudent = <String, List<FeeModel>>{};
      for (final doc in feesSnap.docs) {
        final fee = FeeModel.fromMap(doc.data(), doc.id);
        totalRevenue += fee.amountPaid;
        feesByStudent.putIfAbsent(fee.studentId, () => []).add(fee);
      }
      double totalDue = 0;
      for (final entry in feesByStudent.entries) {
        final payments = entry.value;
        final totalCourseFee = payments.first.totalCourseFee; // repeated on each doc
        final paid = payments.fold<double>(0, (sum, p) => sum + p.amountPaid);
        final due = totalCourseFee - paid;
        if (due > 0) totalDue += due;
      }

      return AnalyticsSummaryModel(
        totalStudents: studentsSnap.docs.length,
        activeStudents: active,
        completedStudents: completed,
        droppedStudents: dropped,
        totalBatches: batchesSnap.docs.length,
        ongoingBatches: ongoing,
        upcomingBatches: upcoming,
        completedBatches: batchCompleted,
        totalInstructors: instructorsSnap.docs.length,
        activeInstructors: activeInstructors,
        totalDrones: dronesSnap.docs.length,
        totalSimulators: simsSnap.docs.length,
        totalRevenue: totalRevenue,
        totalDue: totalDue,
      );
    });
  }

  /// Monthly enrollment counts for the last [months] months, oldest first —
  /// for Student Analytics' enrollment trend chart.
  static Future<List<TrendPoint>> fetchEnrollmentTrend({int months = 6}) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - (months - 1), 1);
    final snap = await _firestore
        .collection('students')
        .where('enrollmentDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .get();

    final counts = <String, int>{};
    final labels = <String>[];
    for (int i = months - 1; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i, 1);
      final label = _monthLabel(m);
      labels.add(label);
      counts[label] = 0;
    }

    for (final doc in snap.docs) {
      final ts = doc.data()['enrollmentDate'] as Timestamp?;
      if (ts == null) continue;
      final d = ts.toDate();
      final label = _monthLabel(DateTime(d.year, d.month, 1));
      if (counts.containsKey(label)) counts[label] = counts[label]! + 1;
    }

    return labels.map((l) => TrendPoint(l, counts[l]!.toDouble())).toList();
  }

  /// Monthly revenue for the last [months] months, oldest first — for
  /// Financial Analytics' revenue trend chart.
  static Future<List<TrendPoint>> fetchRevenueTrend({int months = 6}) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - (months - 1), 1);
    final snap = await _firestore
        .collection('fees')
        .where('paymentDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .get();

    final totals = <String, double>{};
    final labels = <String>[];
    for (int i = months - 1; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i, 1);
      final label = _monthLabel(m);
      labels.add(label);
      totals[label] = 0;
    }

    for (final doc in snap.docs) {
      final ts = doc.data()['paymentDate'] as Timestamp?;
      final amount = (doc.data()['amountPaid'] ?? 0).toDouble();
      if (ts == null) continue;
      final d = ts.toDate();
      final label = _monthLabel(DateTime(d.year, d.month, 1));
      if (totals.containsKey(label)) totals[label] = totals[label]! + amount;
    }

    return labels.map((l) => TrendPoint(l, totals[l]!)).toList();
  }

  /// Students-per-batch, for Batch Analytics.
  static Future<List<BatchStudentCount>> fetchStudentsPerBatch() async {
    final batchesSnap = await _firestore.collection('batches').get();
    final studentsSnap = await _firestore.collection('students').get();

    final countByBatch = <String, int>{};
    for (final doc in studentsSnap.docs) {
      final batchId = (doc.data()['batchId'] ?? '') as String;
      if (batchId.isEmpty) continue;
      countByBatch[batchId] = (countByBatch[batchId] ?? 0) + 1;
    }

    return batchesSnap.docs.map((doc) {
      final data = doc.data();
      return BatchStudentCount(
        doc.id,
        data['batchName'] ?? '',
        countByBatch[doc.id] ?? 0,
      );
    }).toList()
      ..sort((a, b) => b.studentCount.compareTo(a.studentCount));
  }

  /// Batch count + student count per instructor, for Instructor Analytics.
  static Future<List<InstructorWorkload>> fetchInstructorWorkload() async {
    final instructorsSnap = await _firestore.collection('instructors').get();
    final batchesSnap = await _firestore.collection('batches').get();
    final studentsSnap = await _firestore.collection('students').get();

    final batchCountByInstructor = <String, int>{};
    final batchIdsByInstructor = <String, Set<String>>{};
    for (final doc in batchesSnap.docs) {
      final instructorId = (doc.data()['instructorId'] ?? '') as String;
      if (instructorId.isEmpty) continue;
      batchCountByInstructor[instructorId] =
          (batchCountByInstructor[instructorId] ?? 0) + 1;
      batchIdsByInstructor.putIfAbsent(instructorId, () => {}).add(doc.id);
    }

    final studentCountByBatch = <String, int>{};
    for (final doc in studentsSnap.docs) {
      final batchId = (doc.data()['batchId'] ?? '') as String;
      if (batchId.isEmpty) continue;
      studentCountByBatch[batchId] = (studentCountByBatch[batchId] ?? 0) + 1;
    }

    return instructorsSnap.docs.map((doc) {
      final data = doc.data();
      final batchIds = batchIdsByInstructor[doc.id] ?? {};
      final studentCount =
      batchIds.fold<int>(0, (sum, bId) => sum + (studentCountByBatch[bId] ?? 0));
      return InstructorWorkload(
        doc.id,
        data['name'] ?? '',
        batchCountByInstructor[doc.id] ?? 0,
        studentCount,
      );
    }).toList()
      ..sort((a, b) => b.studentCount.compareTo(a.studentCount));
  }

  static String _monthLabel(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[d.month - 1];
  }
}
