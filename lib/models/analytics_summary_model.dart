/// AnalyticsSummaryModel
/// A plain, in-memory computed rollup — NOT a Firestore document.
/// Built by AnalyticsService from live counts across students, batches,
/// instructors, drones, simulators, and fees. No fromMap/toMap since
/// nothing here is ever stored.
class AnalyticsSummaryModel {
  final int totalStudents;
  final int activeStudents;
  final int completedStudents;
  final int droppedStudents;

  final int totalBatches;
  final int ongoingBatches;
  final int upcomingBatches;
  final int completedBatches;

  final int totalInstructors;
  final int activeInstructors;

  final int totalDrones;
  final int totalSimulators;

  final double totalRevenue; // sum of amountPaid across all fee docs
  final double totalDue; // sum of (totalCourseFee - paid) per student, latest known total

  const AnalyticsSummaryModel({
    required this.totalStudents,
    required this.activeStudents,
    required this.completedStudents,
    required this.droppedStudents,
    required this.totalBatches,
    required this.ongoingBatches,
    required this.upcomingBatches,
    required this.completedBatches,
    required this.totalInstructors,
    required this.activeInstructors,
    required this.totalDrones,
    required this.totalSimulators,
    required this.totalRevenue,
    required this.totalDue,
  });

  factory AnalyticsSummaryModel.empty() => const AnalyticsSummaryModel(
    totalStudents: 0,
    activeStudents: 0,
    completedStudents: 0,
    droppedStudents: 0,
    totalBatches: 0,
    ongoingBatches: 0,
    upcomingBatches: 0,
    completedBatches: 0,
    totalInstructors: 0,
    activeInstructors: 0,
    totalDrones: 0,
    totalSimulators: 0,
    totalRevenue: 0,
    totalDue: 0,
  );

  double get completionRate =>
      totalStudents == 0 ? 0 : (completedStudents / totalStudents) * 100;

  double get dropoutRate =>
      totalStudents == 0 ? 0 : (droppedStudents / totalStudents) * 100;
}

/// One point on an enrollment/revenue trend line — month label + value.
class TrendPoint {
  final String label; // e.g. "Jan", "Feb"
  final double value;
  const TrendPoint(this.label, this.value);
}

/// Students-per-batch row, used by Batch Analytics for a bar chart/table.
class BatchStudentCount {
  final String batchId;
  final String batchName;
  final int studentCount;
  const BatchStudentCount(this.batchId, this.batchName, this.studentCount);
}

/// Batch count per instructor, used by Instructor Analytics.
class InstructorWorkload {
  final String instructorId;
  final String instructorName;
  final int batchCount;
  final int studentCount;
  const InstructorWorkload(
      this.instructorId, this.instructorName, this.batchCount, this.studentCount);
}
